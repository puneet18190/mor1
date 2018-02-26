# -*- encoding : utf-8 -*-
class SmsMessage < ActiveRecord::Base
  include UniversalHelpers
  attr_accessible :id, :sending_date, :status_code, :provider_id, :provider_rate, :provider_price
  attr_accessible :user_id, :user_rate, :user_price, :reseller_id, :reseller_rate, :reseller_price
  attr_accessible :prefix, :number, :clickatell_message_id, :sms_campaign_id

  belongs_to :reseller, class_name: 'User', foreign_key: 'reseller_id'
  belongs_to :user

  def destination
    Destination.find_by(prefix: prefix)
  end

  def sms_status_code
    status_codes = {
      '0' => 'sent',
      '1' => 'failed',
      '2' => 'failed',
      '3' => 'failed',
      '4' => 'failed',
      '5' => 'failed',
      '6' => 'failed',
      '001' => 'Message unknown',
      '002' => 'Message queued',
      '003' => 'Delivered to gateway',
      '004' => 'Received by recipient',
      '005' => 'Error with message',
      '006' => 'User cancelled message delivery',
      '007' => 'Error delivering message',
      '008' => 'OK',
      '009' => 'Routing error',
      '010' => 'Message expired',
      '011' => 'Message queued for later delivery',
      '012' => 'Out of credit',
      '0001' => 'Authentication failed',
      '0002' => 'Unknown username or password',
      '0003' => 'Session ID expired',
      '0004' => 'Account frozen',
      '0005' => 'Missing session ID',
      '0007' => 'IP Lockdown violation',
      '101' => 'Invalid or missing parameters',
      '102' => 'Invalid user data header',
      '103' => 'Unknown API message ID',
      '104' =>  'Unknown client message ID',
      '105' => 'Invalid destination address',
      '106' => 'Invalid source address',
      '107' => 'Empty message',
      '108' => 'Invalid or missing API ID',
      '109' => 'Missing message ID',
      '110' => 'Error with email message',
      '111' => 'Invalid protocol',
      '112' => 'Invalid message type',
      '113' => 'Maximum message parts exceeded',
      '114' => 'Cannot re message',
      '115' => 'Message expired',
      '116' => 'Invalid Unicode data',
      '120' => 'Invalid delivery time',
      '121' => 'Destination mobile number blocked',
      '122' => 'Destination mobile opted out',
      '123' => 'Invalid Sender ID',
      '201' => 'Invalid batch ID',
      '202' => 'No batch template',
      '301' => 'No credit left',
      '302' => 'Max allowed credit',
      '400' => 'Caller ID is not present in primary device',
      '401' => 'Caller ID cannot be longer than 11 characters',
      '00000001' => 'Message Length is invalid',
      '00000002' => 'Command Length is invalid',
      '00000003' => 'Invalid Command ID',
      '00000004' => 'Incorrect BIND Status for given command',
      '00000005' => 'ESME Already in Bound State',
      '00000006' => 'Invalid Priority Flag',
      '00000007' => 'Invalid Registered Delivery Flag',
      '00000008' => 'System Error',
      '00000011' => 'Cancel SM Failed',
      '00000013' => 'Replace SM Failed',
      '00000014' => 'Message Queue Full',
      '00000015' => 'Invalid Service Type',
      '00000033' => 'Invalid number of destinations',
      '00000034' => 'Invalid Distribution List name',
      '00000040' => 'Destination flag is invalid (submit_multi)',
      '00000042' => 'Invalid ‘submit with replace’ request (i.e. submit_sm with replace_if_present_flag set)',
      '00000043' => 'Invalid esm_class',
      '00000044' => 'Cannot Submit to Distribution List',
      '00000045' => 'submit_sm or submit_multi failed',
      '00000048' => 'Invalid Source address TON',
      '00000049' => 'Invalid Source address NPI',
      '00000050' => 'Invalid Destination address TON',
      '00000051' => 'Invalid Destination address NPI',
      '00000053' => 'Invalid system_type field',
      '00000054' => 'Invalid replace_if_present flag',
      '00000055' => 'Invalid number of messages',
      '00000058' => 'Throttling error',
      '0000000A' => 'Invalid Source Address',
      '0000000B' => 'Invalid Dest Addrress',
      '0000000C' => 'Message ID is invalid',
      '0000000D' => 'Bind Failed',
      '0000000E' => 'Invalid Password',
      '0000000F' => 'Invalid System ID',
      '000000FF' => 'Unknown error',
      'FFFFFFFF' => 'failed'
    }
    status_codes.has_key?(self.status_code.to_s) ? status_codes[self.status_code.to_s] : status_codes['FFFFFFFF']
  end

  def sms_status_code_tip
    status_code_tips = {
      '0' => 'SMS is sent',
      '1' => 'System owner does not have rate for this destination',
      '2' => 'Reseller does not have rate for this destination',
      '3' => 'User does not have rate for this destination',
      '4' => 'Some error from provider',
      '5' => 'Insufficient balance',
      '6' => 'API returns no good keywords',
      '001' => 'The message ID is incorrect or reporting isdelayed.',
      '002' => 'The message could not be delivered and has been queued for attempted redelivery.',
      '003' => 'Delivered to the upstream gateway or network(delivered to the recipient).',
      '004' => 'Confirmation of receipt on the handset of the recipient.',
      '005' => 'There was an error with the message, probably caused by the content of the message itself.',
      '006' => 'The message was terminated by an internal mechanism.',
      '007' => 'An error occurred delivering the message to the handset.',
      '008' => 'Message received by gateway.',
      '009' => 'The routing gateway or network has had an error routing the message.',
      '010' => 'Message has expired before we were able to deliver it to the upstream gateway. No charge applies.',
      '011' => 'Message has been queued at the gateway for delivery at a later time (delayed delivery).',
      '012' => 'The message cannot be delivered due to a lack of funds in your account. Please re-purchase credits.',
      '0001' => 'Authentication failed',
      '0002' => 'Unknown username or password',
      '0003' => 'Session ID expired',
      '0004' => 'Account frozen',
      '0005' => 'Missing session ID',
      '0007' => 'You have locked down the API instance to a specific IP address and then sent from an IP address different to the one you set.',
      '101' => 'Invalid or missing parameters',
      '102' => 'Invalid user data header',
      '103' => 'Unknown API message ID',
      '104' => 'Unknown client message ID',
      '105' => 'Invalid destination address',
      '106' => 'Invalid source address',
      '107' => 'Empty message',
      '108' => 'Invalid or missing API ID',
      '109' => 'This can be either a client message ID or API message ID.',
      '110' => 'Error with email message',
      '111' => 'Invalid protocol',
      '112' => 'Invalid message type',
      '113' => 'The text message component of the message is greater than the permitted 160 characters (70 Unicode characters).',
      '114' => 'This implies that the gateway is not currently routing messages to this network prefix. Please email support@clickatell.com with the mobile number in question.',
      '115' => 'Message expired',
      '116' => 'Invalid Unicode data',
      '120' => 'Invalid delivery time',
      '121' => 'This number is not allowed to receive messages from us and has been put on our block list.',
      '122' => 'Destination mobile opted out',
      '123' => 'A sender ID needs to be registered and validated before it can be successfully used in message sending.',
      '201' => 'Invalid batch ID',
      '202' => 'No batch template',
      '301' => 'No credit left',
      '302' => 'Max allowed credit',
      '400' => 'Caller ID is not present in primary device',
      '401' => 'Caller ID cannot be longer than 11 characters',
      '00000001' => 'Message Length is invalid',
      '00000002' => 'Command Length is invalid',
      '00000003' => 'Invalid Command ID',
      '00000004' => 'Incorrect BIND Status for given command',
      '00000005' => 'ESME Already in Bound State',
      '00000006' => 'Invalid Priority Flag',
      '00000007' => 'Invalid Registered Delivery Flag',
      '00000008' => 'System Error',
      '00000011' => 'Cancel SM Failed',
      '00000013' => 'Replace SM Failed',
      '00000014' => 'Message Queue Full',
      '00000015' => 'Invalid Service Type',
      '00000033' => 'Invalid number of destinations',
      '00000034' => 'Invalid Distribution List name',
      '00000040' => 'Destination flag is invalid (submit_multi)',
      '00000042' => 'Invalid ‘submit with replace’ request (i.e. submit_sm with replace_if_present_flag set)',
      '00000043' => 'Invalid esm_class',
      '00000044' => 'Cannot Submit to Distribution List',
      '00000045' => 'submit_sm or submit_multi failed',
      '00000048' => 'Invalid Source address TON',
      '00000049' => 'Invalid Source address NPI',
      '00000050' => 'Invalid Destination address TON',
      '00000051' => 'Invalid Destination address NPI',
      '00000053' => 'Invalid system_type field',
      '00000054' => 'Invalid replace_if_present flag',
      '00000055' => 'Invalid number of messages',
      '00000058' => 'Throttling error',
      '0000000A' => 'Invalid Source Address',
      '0000000B' => 'Invalid Dest Addrress',
      '0000000C' => 'Message ID is invalid',
      '0000000D' => 'Bind Failed',
      '0000000E' => 'Invalid Password',
      '0000000F' => 'Invalid System ID',
      '000000FF' => 'Unknown error',
      'FFFFFFFF' => 'SMS was not sent'
    }
    status_code_tips.has_key?(self.status_code.to_s) ? status_code_tips[self.status_code.to_s] : status_code_tips['FFFFFFFF']
  end

  def sms_status
    type = nil
    status_code_tip = self.sms_status_code_tip
    type = status_code.to_s == '0' ? :status : :notice
    return status_code_tip, type
  end


  def sms_send(user, user_tariff, number, lcr, sms_numbers, message, options = {})
    time = user.time_now_in_tz
    daytype = Day.daytype(user.time_now_in_tz)
    sql = "
      SELECT * FROM (
        SELECT
          sms_providers.id AS 'providers_id',
          provider_type,
          A.prefix AS 'prefix',
          ratedetails.rate AS price,
          currencies.exchange_rate AS 'e_rate',
          sms_lcrproviders.priority AS priority
        FROM sms_providers
          JOIN sms_lcrproviders ON (sms_lcrproviders.sms_provider_id = sms_providers.id
            AND sms_lcrproviders.sms_lcr_id = '#{lcr.id}' AND sms_lcrproviders.active = 1)
          JOIN tariffs ON (sms_providers.tariff_id = tariffs.id)
          LEFT JOIN rates ON (rates.tariff_id = tariffs.id)
          LEFT JOIN ratedetails ON (rates.id = ratedetails.rate_id) AND daytype != '#{daytype}'
          JOIN (
            SELECT destinations.*
            FROM  destinations
            WHERE destinations.prefix IN (#{split_number(number).join(',')})
            ORDER BY LENGTH(destinations.prefix) DESC
          ) AS A ON (A.prefix = rates.prefix)
          LEFT JOIN currencies ON (currencies.name = tariffs.currency)
          ORDER BY LENGTH(A.prefix) DESC
        ) AS B
        JOIN sms_lcrs ON (sms_lcrs.id = '#{lcr.id}')
        GROUP BY B.providers_id
        ORDER BY IF (sms_lcrs.order = 'priority', B.priority, B.price / B.e_rate) ASC;
    "

    res = options[:smsprovider] || ActiveRecord::Base.connection.select_one(sql)

    self.user_rate = 0
    self.user_price = 0
    self.reseller_rate = 0
    self.reseller_price = 0
    self.provider_rate = 0
    self.provider_price = 0

    if !res || (res && (res['prefix'] == nil || res['prefix'] == ''))
      self.status_code = 1
      self.save
      return false
    end

    prov_type = res['provider_type'].to_s
    prov_api = prov_type.to_s == 'api' ? 1 : 0

    if !user.primary_device.try(:callerid).present? && prov_type == 'smpp'
      self.status_code = '400'
      self.save
      return false
    end

    if SmsProvider.nice_cid(user.primary_device.try(:callerid)).to_s.try(:size) > 11 && prov_type == 'smpp'
      self.status_code = '401'
      self.save
      return false
    end

    unless self.sms_set_rates_and_user(user, sms_numbers, user_tariff, number, prov_api)
      return false
    end


    self.prefix = res['prefix']

    #============================= provider is ok ==============================
    prov_id = res['providers_id']
    prov_rate = res['price'].to_d / res['e_rate'].to_d
    self.provider_id = prov_id
    provider = SmsProvider.find_by(id: prov_id)
    self.provider_rate = prov_rate
    self.provider_price = Email.nice_number(prov_rate * sms_numbers.to_i)
    #===========================================================================

    if prov_type.to_s == 'clickatell'
      provider.send_sms_clickatell(self, { message: message, ms_numbers: sms_numbers, to: number, unicode: options[:sms_unicode].to_i })
    end

    if prov_type.to_s == 'sms_email'
      if user.owner_id == 0
        provider.send_sms_email(self, user, { message: message, sms_numbers: sms_numbers, to: number, user_price: self.user_price.to_d, unicode: options[:sms_unicode].to_i })
      else
        provider.send_sms_email(self, user, { message: message, sms_numbers: sms_numbers, to: number, user_price: self.user_price.to_d, reseller: 1, reseller_price: self.reseller_price.to_d, unicode: options[:sms_unicode].to_i })
      end
    end

    if prov_api == 1
      if options[:src]
        provider.send_sms_api(self, user, { message: message, sms_numbers: sms_numbers, to: number, unicode: options[:sms_unicode].to_i, src: options[:src] })
      else
        provider.send_sms_api(self, user, { message: message, sms_numbers: sms_numbers, to: number, unicode: options[:sms_unicode].to_i })
      end
    end

    if prov_type.to_s == 'smpp'
      provider.send_sms_smpp(self, user, { message: message, to: number, src: options[:src] })
    end

    self.save

    # DO NOT do the billing if a message has failed
    return unless status_code.to_s == '0'

    # Billing a Reseller
    owner_id = user.owner_id
    if owner_id != 0
      reseller = User.find_by(id: owner_id)
      freze_user_balance_for_sms(reseller, reseller_price) if prov_api == 0
    end
    # Billing a User
    freze_user_balance_for_sms(user, user_price) if prov_api == 0
  end


  def sms_set_rates_and_user(user, sms_numbers, user_tariff, number, api = 0)

    if user.owner_id != 0
      reseller = User.find_by(id: user.owner_id)
      reseller_tariff = reseller.sms_tariff

      unless reseller_tariff
        self.status_code = 2
        self.save
        return false
      end

      reseller_rate = SmsMessage.sms_rate(reseller, number)

      unless  reseller_rate
        self.status_code = 2
        self.save
        return false
      end

      r_price = (reseller_rate.price.to_d / Currency.find_by(name: reseller_tariff.currency).exchange_rate.to_d).to_d
      unless check_user_for_sms(reseller, (r_price * sms_numbers).to_d)
        self.status_code = 5
        self.save
        return false
      end
    end

    unless user_tariff || (user.owner_id != 0 && reseller_rate)
      self.status_code = 2
      self.save
      return false
    end

    user_rate = SmsMessage.sms_rate(user, number)

    unless user_rate
      self.status_code = 3
      self.save
      return false
    end

    price = (user_rate.price.to_d / Currency.find_by(name: user_tariff.currency).exchange_rate.to_d).to_d

    unless check_user_for_sms(user, (price * sms_numbers.to_d).to_d)
      self.status_code = 5
      self.save
      return false
    end

    self.user_rate = Email.nice_number(price)
    self.user_price = Email.nice_number(price * sms_numbers).to_d
    if user.owner_id != 0
      self.reseller_id = reseller.id
      self.reseller_rate = Email.nice_number(r_price)
      self.reseller_price = Email.nice_number(r_price * sms_numbers).to_d
    end

    self.save

    return true
  end


  def check_user_for_sms(user, sms_price)
    out = true
    if user.postpaid.to_i == 0
      bal = user.balance.to_d - sms_price.to_d
      if bal.to_d < 0.to_d
        out = false
      end
    else
      bal = user.balance.to_d - sms_price.to_d
      if user.credit.to_i > -1
        if bal.to_d < (-1 * user.credit.to_d)
          out = false
        end
      end
    end
    return out
  end

  def freze_user_balance_for_sms(user, sms_price)
    #  logger.info "freze_user_balance: #{user.id}"
    #  logger.info "before balance :#{user.balance.to_d} , frozen_balance #{user.frozen_balance.to_d} "
    user.balance = user.balance.to_d - sms_price.to_d
    user.frozen_balance = user.frozen_balance.to_d + sms_price.to_d
    user.save
    #   logger.info "after balance :#{user.balance.to_d} , frozen_balance #{user.frozen_balance.to_d} "
  end


  def self.sms_rate(user, number)
    tariff_id = user.sms_tariff.try(:id)
    daytype = Day.daytype(user.time_now_in_tz)
    sql = "
      SELECT
        rates.*,
        rate AS price
      FROM rates
        JOIN (
          SELECT
            prefix
          FROM destinations
          WHERE prefix = SUBSTRING(#{ActiveRecord::Base::sanitize(number)}, 1, LENGTH(destinations.prefix))
          ORDER BY LENGTH(destinations.prefix) DESC
        ) AS A ON (A.prefix = rates.prefix)
      JOIN ratedetails ON (rates.id = ratedetails.rate_id)
      WHERE tariff_id = #{tariff_id} AND (rates.effective_from < NOW() OR rates.effective_from IS NULL)
        AND daytype != '#{daytype}'
      ORDER BY LENGTH(rates.prefix) DESC, rates.effective_from DESC
      LIMIT 1
    "
    rate = Rate.find_by_sql(sql)[0]
  end


  def charge_user
    user = self.user
    # logger.info "charge_user: #{user.id}"
    # logger.info "before balance :#{user.balance.to_d} , frozen_balance #{user.frozen_balance.to_d} "
    user.frozen_balance = user.frozen_balance.to_d - self.user_price.to_d
    owner = user.owner
    if owner.id != 0
      owner.frozen_balance = owner.frozen_balance.to_d - self.reseller_price.to_d
      owner.save
    end
    user.save
    # logger.info "after balance :#{user.balance.to_d} , frozen_balance #{user.frozen_balance.to_d} "
  end


  def return_sms_price_to_user
    user = self.user
    # logger.info "return_user: #{user.id}"
    # logger.info "before balance :#{user.balance.to_d} , frozen_balance #{user.frozen_balance.to_d} "
    user.frozen_balance = user.frozen_balance.to_d - self.user_price.to_d
    user.balance = user.balance.to_d + self.user_price.to_d
    owner = user.owner
    if owner.id != 0
      owner.frozen_balance = owner.frozen_balance.to_d - self.reseller_price.to_d
      owner.balance = owner.balance.to_d + self.reseller_price.to_d
      owner.save
    end
    user.save
    # logger.info "after balance :#{user.balance.to_d} , frozen_balance #{user.frozen_balance.to_d} "
  end

  # converted attributes for user in current user currency
  def user_price
    b = read_attribute(:user_price)
    if User.current and User.current.currency
      b.to_d * User.current.currency.exchange_rate.to_d
    else
      b.to_d
    end
  end

  def user_rate
    b = read_attribute(:user_rate)
    if User.current and User.current.currency
      b.to_d * User.current.currency.exchange_rate.to_d
    else
      b.to_d
    end
  end

  # converted attributes for user in current user currency
  def reseller_price
    b = read_attribute(:reseller_price)
    if User.current and User.current.currency
      b.to_d * User.current.currency.exchange_rate.to_d
    else
      b.to_d
    end
  end

  # converted attributes for user in current user currency
  def provider_price
    b = read_attribute(:reseller_price)
    if User.current and User.current.currency
      b.to_d * User.current.currency.exchange_rate.to_d
    else
      b.to_d
    end
  end

  def self.user_sms_in_period(period_start, period_end, user)
    MorLog.my_debug("start sms", 1)

    period_start = period_start.to_s(:db) if period_start.class == Time or period_start.class == Date
    period_end = period_end.to_s(:db) if period_end.class == Time or period_end.class == Date

    if user.usertype == 'reseller'
      user_id, user_price = User.where(owner_id: user.id).pluck(:id), 'reseller_price'
    else
      user_id, user_price = user.id, 'user_price'
    end

    sms = SmsMessage.select('COUNT(*) AS counted, IFNULL(SUM(' + user_price + '), 0) AS total_sms_price').
                     where('user_price > 0').where(user_id: user_id).
                     where('sending_date BETWEEN ? AND ?', period_start, period_end).all
    total_sms = sms.first.counted
    total_sms_price = sms.first.total_sms_price

    MorLog.my_debug("  Total sms in this period: #{total_sms}", 1)
    MorLog.my_debug("end sms", 1)

    return total_sms, total_sms_price
  end

  def self.get_messages(params, user)
    params_from = params[:from]
    params_till = params[:till]
    # By default from and till must be today
    from = params_from && is_number?(params_from) ? Time.at(params_from.to_i).to_date.to_s(:db) : Time.mktime(Time.now.year, Time.now.month, Time.now.day, 0, 0, 0).to_s(:db)
    till = params_till && is_number?(params_till) ? Time.at(params_till.to_i).to_date.to_s(:db) : Time.mktime(Time.now.year, Time.now.month, Time.now.day, 23, 59, 59).to_s(:db)

    condition = ''
    condition <<  " sending_date BETWEEN '#{from}' AND '#{till}'"

    # Because these params are optional, if they are in incorrect format, they are just ignored
    current_user_id = user.id
    current_is_user = user.is_user?
    if current_is_user
      user_id = current_user_id.to_i
    else
      params_user_id = params[:user_id]
      if params_user_id && is_number?(params_user_id)
        user_id = params_user_id
      end
    end
    condition << " AND user_id = #{user_id}" if user_id.present?

    if user.is_reseller?
      reseller_id = current_user_id.to_i
    else
      params_reseller_id = params[:reseller_id]
      if params_reseller_id && is_number?(params_reseller_id)
        reseller_id = params_reseller_id
      end
    end
    condition << " AND reseller_id = #{reseller_id}" if reseller_id.present? && !current_is_user

    # This is for partner if one day will be needed
    if user.is_partner?
      resellers = User.where("owner_id = #{current_user_id} AND usertype = 'partner'")
      if resellers.present?
        condition << " AND reseller_id IN (#{resellers.join(", ")})"
      else
        return false
      end
    end

    params_status_code = params[:status_code]
    condition << " AND status_code = #{params_status_code}" if params_status_code.present? && is_number?(params_status_code)

    params_provider_id = params[:provider_id]
    condition << " AND provider_id = #{params_provider_id}" if params_provider_id.present? && is_number?(params_provider_id)


    params_prefix = params[:prefix]
    condition << " AND prefix = #{params_prefix}" if params_prefix.present? && is_number?(params_prefix)

    params_number = params[:number]
    condition << " AND number = #{params_number}" if params_number.present? && is_number?(params_number)

    SmsMessage.where(condition)
  end

  def self.is_number?(val=nil)
    (!!(val.match /^[0-9]+$/) rescue false)
  end
end
