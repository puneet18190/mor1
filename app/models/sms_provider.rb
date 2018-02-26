# -*- encoding : utf-8 -*-
# SMS Providers
class SmsProvider < ActiveRecord::Base
  attr_protected

  extend UniversalHelpers
  require 'enumerator'
  require 'net/https'
  require 'uri'

  belongs_to :tariff

  SMS_ALLOWED_VARIABLES = %w[SRC DST MSG USRFIRSTNAME USRLASTNAME CALLERID]

  before_save :validate_prov

  def validate_prov
    unless self.sms_provider_domain !~ /(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/
      errors.add(:sms_provider_domain, _('Domain_has_to_be_valid'))
      return false
    end
    self.must_have_valid_variables if self.api?
    self.uri_parse_ok if self.api?
  end

  def self.find_providers_by_lcr(lcr_id, number, user)
    time = user.time_now_in_tz
    daytype = Day.daytype(user.time_now_in_tz)
    sql = "
      SELECT B.*
        FROM (
          SELECT
            sms_providers.id AS providers_id,
            provider_type,
            rates.prefix AS prefix,
            ratedetails.rate AS price,
            currencies.exchange_rate AS e_rate,
            sms_lcrproviders.priority AS priority
          FROM sms_providers
            JOIN sms_lcrproviders ON (sms_lcrproviders.sms_provider_id = sms_providers.id
              AND sms_lcrproviders.sms_lcr_id = '#{lcr_id}' AND sms_lcrproviders.active = 1)
            JOIN tariffs ON (sms_providers.tariff_id = tariffs.id)
            JOIN rates ON (rates.tariff_id = tariffs.id AND rates.prefix IN (#{split_number(number).join(',')})
              AND (rates.effective_from <= NOW() OR rates.effective_from IS NULL))
            JOIN ratedetails ON (rates.id = ratedetails.rate_id) AND daytype != '#{daytype}'
            LEFT JOIN currencies ON (currencies.name = tariffs.currency)
            ORDER BY LENGTH(rates.prefix) DESC, rates.effective_from DESC
          ) AS B
        JOIN sms_lcrs ON (sms_lcrs.id = '#{lcr_id}')
        GROUP BY B.providers_id
        ORDER BY IF (sms_lcrs.order = 'priority', B.priority, B.price / B.e_rate) ASC
    "
    ActiveRecord::Base.connection.select_all(sql)
  end

  def test_login
    out = ''
    begin
      log = self.connect_to_clickatell
      if log[0].to_s == 'ERR:'
        out = "<img title='Error' src='#{Web_Dir}/images/icons/cross.png' alt='Error' id='test_err_#{self.id}'/>"
      else
        out = "<img title='Ok' src='#{Web_Dir}/images/icons/check.png' alt='Ok' id='test_ok_#{self.id}'/>"
      end
    rescue => e
      MorLog.log_exception(e, Time.now.to_i, 'sms', 'providers')
      out = "<img title='Error' src='#{Web_Dir}/images/icons/cross.png' alt='Error' id='test_err_#{self.id}'/>"
    end

    return out
  end


  def send_sms_clickatell(sms, options={})
    log = self.connect_to_clickatell
    if log[0].to_s == 'ERR:'
      if log[1].to_s.gsub(/,/, '').to_i <= 7
        sms.status_code = "0" + log[1].to_s.gsub(/,/, '')
      else
        sms.status_code = log[1].to_s.gsub(/,/, '')
      end
      sms.user_rate = 0
      sms.user_price = 0
      sms.reseller_rate = 0
      sms.reseller_price = 0
      sms.provider_rate = 0
      sms.provider_price = 0
    else
      string = ""
      string += "&from=#{self.sms_from}" if !self.sms_from.blank?
      if options[:unicode].to_i != 0
        string += "&unicode=1"
        mtext = CGI.escape(options[:message].to_s.strip.unpack("U*").collect { |s| ("0"*3+ s.to_i.to_s(16))[-4..-1] }.join(""))
      else
        mtext= CGI.escape(options[:message].to_s.strip)
      end
      message_id = Net::HTTP.get_response("api.clickatell.com", "/http/sendmsg?api_id=#{self.api_id.to_s.strip}&password=#{self.password.to_s.strip}&user=#{self.login.to_s.strip}&to=#{options[:to].to_s.strip}&callback=3&concat=#{options[:sms_numbers].to_s}&text=#{mtext}#{string}")
      code = message_id.body.split(" ")
      if code[0].to_s == 'ERR:'
        if code[1].to_s.gsub(/,/, '').to_i <= 7
          sms.status_code = "0" + code[1].to_s.gsub(/,/, '').to_s
        else
          sms.status_code = code[1].to_s.gsub(/,/, '').to_s
        end
      else
        sms.clickatell_message_id = code[1].to_s
        sms.status_code = "0"
      end
    end
    sms.save
    #MorLog.my_debug "http://api.clickatell.com/http/sendmsg?api_id=#{self.api_id.to_s.strip}&password=#{self.password.to_s.strip}&user=#{self.login.to_s.strip}&to=#{options[:to].to_s.strip}&callback=3&concat=#{options[:sms_numbers].to_s.to_s}&text=#{mtext}#{string}"
    #return sms.sms_status_code_tip
  end

  def send_sms_api(sms, user, options={})
    #puts "sending send_sms_api" + options[:src]
    if options[:unicode].to_i != 0
      mtext = CGI.escape(options[:message].to_s.strip.unpack("U*").collect { |s| ("0"*3+ s.to_i.to_s(16))[-4..-1] }.join(""))
    else
      mtext = CGI.escape(options[:message].to_s.strip)
    end

    pr_device = user.primary_device
    cli = !options[:src].blank? ? options[:src].to_s : (pr_device ? CGI.escape(pr_device.callerid.to_s) : '')
    first_name = CGI.escape(user.first_name.to_s)
    last_name =  CGI.escape(user.last_name.to_s)
    # HTTP/SSL
    uri = URI.parse(nice_url(options[:to], mtext, (!options[:src].blank? ? options[:src].to_s : 'src'), first_name, last_name, cli.to_s))
    http = Net::HTTP.new(uri.host, uri.port)
    uri.scheme.to_s.downcase == 'https' ? http.use_ssl = true : http.use_ssl = false
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    code = response.body.force_encoding('UTF-8')
    Action.add_action_hash(user, {:action => 'SMS_api_response', :data2=>nice_url(options[:to], mtext, (!options[:src].blank? ? options[:src].to_s : 'src'), first_name, last_name, cli.to_s)})

    if code.include?(email_good_keywords)
      sms.status_code = 0
      sms.freze_user_balance_for_sms(user, sms.user_price)

      if user.owner_id != 0
        sms.freze_user_balance_for_sms(user.owner, sms.reseller_price)
      end
    else
      sms.status_code = 6
      sms.provider_rate = sms.provider_price = sms.user_rate = sms.user_price = 0
    end

    sms.save
  end


  def send_sms_email(sms, user, options={})
    email = Email.where(["name = 'sms'"]).first
    unless email
      email = Email.new({:name => "sms", :template => 1, :format => "html", :owner_id => 0, :body => "", :subject => "", :date_created => Time.now().to_s(:db)})
      email.save
    end
    opt = options.merge({:email_to_address => options[:to].strip + self.sms_provider_domain.strip, :sms_id => sms.id, :email_from_user => user, :owner => user.owner_id})
    to = []
    to << user
    Email.send_email(email, to, Confline.get_value("Email_from"), "sms_email_sent", opt)
    if self.wait_for_good_email.to_i != 1 and self.wait_for_bad_email.to_i != 1
      user.frozen_balance = user.frozen_balance.to_d - Email.nice_number(options[:user_price].to_d).to_d
      user.save
      if options[:reseller] == 1
        user_r = sms.reseller
        user_r.frozen_balance = user_r.frozen_balance.to_d - Email.nice_number(options[:reseller_price].to_d).to_d
        user_r.save
      end
    end
    sms.status_code = 0
    sms.save
    #return sms.sms_status_code_tip
  end

  def send_sms_smpp(sms, user, options = {})
    username = self.login.to_s
    psw = self.password.to_s
    dst_number = options[:to].to_s
    server = self.server.to_s
    port = self.port.to_s
    msg_text = options[:message].to_s
    encoding = self.encoding.to_s
    transfer_method = self.transfer_method.to_s
    if options[:src].to_s.strip.present?
      src = options[:src].to_s.strip
    else
      src_number = cid_number(user.primary_device.try(:callerid))
      src = src_number.present? ? src_number : SmsProvider.nice_cid(user.primary_device.try(:callerid))
    end

    MorLog.my_debug('SMPP SMS SENDING', 1)
    MorLog.my_debug("-u #{username} -p #{psw} -n #{dst_number} -d #{server}:#{port} -m #{msg_text} -s #{src} -e #{encoding} -t #{transfer_method}",1)

    smppcli = `/usr/local/mor/smppcli -u #{username} -p #{psw} -n #{dst_number} -d #{server}:#{port} -m "#{msg_text}" -s "#{src}" -e #{encoding} -t #{transfer_method}`

    sms.status_code = handle_smppcli_response(smppcli)

    # sets zero to sms object values because sms was not sent
    # class.method == class.send(:method)
    # class.send('method'+'=', value) == class.method = value
    if sms.status_code != 0
      %w[user_rate user_price reseller_rate reseller_price provider_rate provider_price].each do |var|
        sms.send(var+'=', 0)
      end
    end

    sms.save
    MorLog.my_debug('SMPP SMS SENDING DONE', 1)
  end

  def connect_to_clickatell
    begin
      sms_url = URI.parse("http://api.clickatell.com/http/auth?api_id=#{self.api_id}&password=#{self.password}&user=#{self.login}")
      if sms_url.respond_to?(:request_uri)
        login = Net::HTTP.get_response(sms_url)
        log = login.body.split(" ")
      else
        MorLog.my_debug("SMS bad url : api.clickatell.com/http/auth?api_id=#{self.api_id}&password=#{self.password}&user=#{self.login}", 1)
        log = []
        log[0] = 'ERR:'
      end
    rescue => e
      MorLog.log_exception(e, Time.now.to_i, 'sms', 'providers')
      log = []
      log[0] = 'ERR:'
    end
    log
  end

  def api?
    provider_type.to_s == 'api'
  end

  def must_have_valid_variables

    login.scan(/<%=?(\s*\S+\s*)%>|<%[^=]?[0-9a-zA-Z +=]*%>/).flatten.each do |var|
      unless !var.blank? and SMS_ALLOWED_VARIABLES.include?(var.strip)
        errors.add(:api, _('invalid_variable'))
        return false
      end
    end
  end

  def uri_parse_ok
    begin
      uri = URI.parse(nice_url('dst', 'msg', 'src', 'first_name', 'last_name', 'cli'))
      http = Net::HTTP.new(uri.host, uri.port)
      uri.scheme.to_s.downcase == 'https' ? http.use_ssl = true : http.use_ssl = false
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)
      response.body
    rescue => e
      errors.add(:api, _('invalid_url'))
      return false
    end
  end

  def nice_url(dst, msg, src, first_user, last_user, cli)
    # strip name and leave num
    cli_num = ((result = cli.match(/.*%3C(.*)%3E.*/)) ? result[1] : ((true if Float(cli) rescue false) ? cli : ""))
    login.gsub(/<%= DST %>/, dst).gsub(/<%= MSG %>/, msg).gsub(/<%= SRC %>/, src).gsub(/<%= USRFIRSTNAME %>/, first_user).gsub(/<%= USRLASTNAME %>/, last_user).gsub(/<%= CALLERID %>/, cli_num).strip
  end

  def self.create_by_params(params)
    sms_prov = SmsProvider.new(params[:provider].each_value(&:strip!))
    if sms_prov.api?
      sms_prov.login = params[:api_string].to_s
      sms_prov.email_good_keywords = params[:api_good_keywords].to_s
    end
    sms_prov.priority = 1
    sms_prov
  end

  def set_wait_for_email(params)
    self.attributes = params[:provider].each_value(&:strip!)
    if params[:provider][:wait_for_good_email]
      self.wait_for_good_email = params[:provider][:wait_for_good_email]
    else
      self.wait_for_good_email = 0
    end
    self.email_good_keywords = params[:provider][:email_good_keywords] if params[:provider][:email_good_keywords]
    if params[:provider][:wait_for_bad_email]
      self.wait_for_bad_email = params[:provider][:wait_for_bad_email]
    else
      self.wait_for_bad_email = 0
    end
    if self.api?
      self.login = params[:api_string].to_s
      self.email_good_keywords = params[:api_good_keywords].to_s
    end
  end

  # converting caller id like "name" <11> to name (takes string between first and last quote)
  def self.nice_cid(cidn)
    if cidn.present? && cidn[0] == '"' # checking if cidname has name ("" are mandatory)
      pos = find_last_quote(cidn)
      cidn[1..pos - 2]
    else
      ''
    end
  end

  # converting caller id like "name" <11> to 11
  def cid_number(cid)
    less_index = cid.try(:index, '<')
    more_index = cid.try(:index, '>')

    if less_index && more_index
      cid[less_index + 1, more_index - less_index - 1]
    else
      ''
    end
  end

  def self.find_last_quote(string)
    pos,place = [0, 0]
    string.each_char do |char|
      place += 1
      pos = place if char == '"'
    end
    pos
  end

  private

  # takes SMPPCLI response and checks if sms was sent successfully
  def handle_smppcli_response(response)
    MorLog.my_debug('+-+-+-+-+-+-+-+-+-+-+', 1)
    MorLog.my_debug("#{response}", 1)
    MorLog.my_debug('+-+-+-+-+-+-+-+-+-+-+', 1)
    response_split = response.split("\n")
    status_lines = []
    response_split.each do |line|
      next unless line.include?('command_status')
      code = line.gsub!(' ','').split('command_status')[1][1..8]
      status_lines << code unless code.to_s == '00000000'
    end

    unless status_lines.empty?
      return status_lines.first.to_s
    end

    unless response.include?('ESME_ROK')
      return 'FFFFFFFF'
    end

    0
  end
end
