# -*- encoding : utf-8 -*-
module UniversalHelpers

  def nice_user_from_data(username, first_name, last_name, options = {})
    nu = (username.to_s).html_safe
    nu = (first_name.to_s + " " + last_name.to_s).html_safe if first_name.to_s.length + last_name.to_s.length > 0
    if options[:link] and options[:user_id]
      nu = link_to nu, :controller => "users", :action => "edit", :id => options[:user_id].to_i
    end
    nu
  end

  #  def nice_date(date)
  #    date.strftime("%Y-%m-%d") if date
  #  end
  #
  #  def nice_date_time(time)
  #    time.strftime("%Y-%m-%d %H:%M:%S") if time
  #  end

  def disk_space_usage(folder)
    # This one retrieves remaining space in KB
    space = `df -P '#{folder}' | awk '{print $4}' | tail -n 1`
  end

  def disk_space_usage_percent(folder)
    # This one used to retrieve remaining space in percent
    space = `df -P '#{folder}' | grep -o "[0-9]*%"`
  end

  def add_contition_and_param(value, search_value, search_string, conditions, condition_params)
    if !value.blank?
      conditions << search_string
      condition_params << search_value
    end
  end

  def add_contition_and_param_like(value, search_value, search_string, conditions, condition_params)
    if !value.blank?
      conditions << search_string
      condition_params << search_value.to_s
    end
  end

  def add_integer_contition_and_param(value, search_value, search_string, conditions, condition_params)
    if !value.blank?
      conditions << search_string
      condition_params << q(search_value.to_s.gsub(',', '.'))
    end
  end

  def add_integer_contition_and_param_not_negative(value, search_value, search_string, conditions, condition_params)
    if !value.blank? and value.to_i != -1
      conditions << search_string
      condition_params << q(search_value.to_s.gsub(',', '.'))
    end
  end

  def add_contition_and_param_not_all(value, search_value, search_string, conditions, condition_params)
    if value.to_s != _('All')
      conditions << search_string
      condition_params << search_value
    end
  end

  def nice_user(user)
    if user
      nice_name = "#{user.first_name} #{user.last_name}"
      nice_name = user.username.to_s if nice_name.length < 2
      return nice_name
    end
    return ''
  end

  def clear_options(options)
    options.each { |key, value|
      if key.to_s.scan(/^s_.*/).size > 0
        options[key] = nil
      end
    }
    return options
  end

=begin
 Loads file to local file system using mysql.
 *Params*
 +filename+ - required param. File name +without+ extension and path.
 +extension+ - file extension. Default - csv
 +path+ - path to file. Default - /tmp/
 *Return*
 +filename+ if load is successful.
 +nil+ - if no file is loaded.
=end

  def load_file_through_database(filename, extension = "csv", path = "/tmp/")
    full_file_path = "#{q(path)}#{q(filename)}.#{q(extension)}"
    logger.debug("  >> load_file_through_database(#{filename})")
    file = ActiveRecord::Base.connection.execute("select LOAD_FILE('#{full_file_path}')") #.fetch_row()[0]
    if file.first[0]
      File.open(full_file_path, 'w') { |f| f.write(file.first[0].force_encoding("UTF-8").encode("UTF-8", :invalid => :replace, :undef => :replace, :replace => "?")) }
      logger.debug("  >> load_file_through_database = file")
      return filename
    else
      logger.debug("  << load_file_through_database = nil")
      return nil
    end
  end

=begin rdoc
 Santitizes params for sql input.
=end

  def q(str)
    str.class == String ? ActiveRecord::Base.connection.quote_string(str) : str
  end

  def nice_number_with_separator(number, digits = Confline.get_value('Nice_Number_Digits'), decimal = Confline.get_value('Global_Number_Decimal'))
    return _('Infinity') if number == 'inf'

    digits = 2 if digits.to_i == 0
    number ||= 0

    num = sprintf("%.#{digits}f", number.to_f.round(digits.to_i))
    num = num.gsub('.', decimal) unless ['', '.'].include?(decimal.to_s)
    num
  end

  # format time from seconds
  def nice_time(time, show_zeroes = false, format = nil)
    current_user = User.current
    time_format =
      if format
        format
      elsif current_user
        format = Confline.get_value('time_format', current_user.owner.id)
        format = format.present? ? format : Confline.get_value('time_format', 0)
        format
      else
        '%M:%S'
      end
    time = time.to_i
    return '' if time == 0 && !show_zeroes

    if time_format.to_s == '%M:%S'
      h = time / 3600
      m = (time - (3600 * h)) / 60
      s = time - (3600 * h) - (60 * m)
      good_date(m+h*60) + ':' + good_date(s)
    else
      h = time / 3600
      m = (time - (3600 * h)) / 60
      s = time - (3600 * h) - (60 * m)
      good_date(h) + ':' + good_date(m) + ':' + good_date(s)
    end
  end

  def nice_time_with_zeros(time)
    formated_time = nice_time(time)
    formated_time = "00:00:00" if formated_time.blank?
    formated_time
  end


  # format time from seconds
  def invoice_nice_time(time, type)
    if type.to_i == 0
      nice_time(time)
    else
      nice_time_in_minits(time)
    end
  end

  def nice_time_in_minits(time)
    time = time.to_i
    return "" if time == 0
    m = time / 60
    s = time - (60 * m)
    good_date(m) + ":" + good_date(s)
  end

  def nice_time_from_date(date)
    date ? good_date(date.hour) + ":" + good_date(date.min) + ":" + good_date(date.sec) : ""
  end

  # adding 0 to day or month <10
  def good_date(dd)
    dd = dd.to_s
    dd = '0' + dd if dd.length<2
    dd
  end

  def nice_day(string)
    string.to_i < 10 ? "0" + string : string
  end

  def curr_price(price = 0)
    price * User.current.currency.exchange_rate.to_f
  end

  def round_to_cents(amount)
    ((amount.to_f * 100).ceil.to_d / 100)
  end

  def format_money(amount, currency = nil, decimal_digits = 2)
    [sprintf("%0.#{decimal_digits}f", round_to_cents(amount.to_d)), currency].compact.join(" ")
  end

  def floor2(amount, exp = 0)
    multiplier = 10 ** exp
    ((amount * multiplier).floor).to_d/multiplier.to_d
  end

  def page_select_header(page, total_pages, page_select_params = {}, options = {}, return_type = "table")
    page = page.to_i
    letter = 'A'
    letter = page_select_params[:st].upcase if page_select_params.try(:st)
    ret = []
    if total_pages.to_i > 1
      opts= {:id_prefix => "page_", :wrapper => true}.merge(options)

      page_select_params = {} if page_select_params.class != Hash
      keys = [:page]
      page_select_params = page_select_params.reject { |k, v| keys.include?(k || k.to_sym) }
      pstart = page - 10
      pstart = 1 if pstart < 1
      pend = page + 10
      pend = total_pages if pend > total_pages

      back10 = page - 20
      if back10.to_i <= 0
        back10 = 1 if pstart > 1
        back10 = nil if pstart == 1
      end
      forw10 = page + 20
      if forw10 > total_pages
        forw10 = total_pages if pend < total_pages
        forw10 = nil if pend == total_pages
      end

      back100 = page - 100
      if back100.to_i < 0
        back100 = 1 if back10.to_i > 1 if back10
        if (back10.to_i <= 1) or (not back10)
          back100 = nil
        end
      end

      forw100 = page + 100
      if forw100.to_i > total_pages
        forw100 = total_pages if forw10 < total_pages if forw10
        forw100 = nil if forw10 == total_pages or not forw10
      end
      case return_type
        when "table"
          ret = ["<div align='center'>\n<table class='page_title2' width='100%'>\n<tr>"] if opts[:wrapper] == true
          ret << "    <td align = 'center' id='#{opts[:id_prefix]}#{page.to_i}'>"
          ret << " "+link_to("<<", {:action => params[:action], :page => back100, :search_on => params[:search_on]}.merge(page_select_params), {:title => "-100"}) if back100
          ret << " "+link_to("<", {:action => params[:action], :page => back10, :search_on => params[:search_on]}.merge(page_select_params), {:title => "-20"}) if back10
          for p in pstart..pend
            ret << "<b>" if p == page
            ret << " "+link_to(p, {:action => params[:action], :page => p, :st => letter, :search_on => params[:search_on]}.merge(page_select_params))
            ret << "</b> " if p == page
          end
          ret << " "+link_to(">", {:action => params[:action], :page => forw10, :search_on => params[:search_on]}.merge(page_select_params), {:title => "+20"}) if forw10
          ret << " "+link_to(">>", {:action => params[:action], :page => forw100, :search_on => params[:search_on]}.merge(page_select_params), {:title => "+100"}) if forw100
          ret << "   </td>\n</tr>\n</table>\n</div>\n<br>" if opts[:wrapper] == true
        when "div"
          ret = ["<div>"] if opts[:wrapper] == true
          ret << link_to("<<", {:action => params[:action], :page => back100, :search_on => params[:search_on]}.merge(page_select_params), {:title => "-100", :class => "pagination_link"}) if back100
          ret << link_to("<", {:action => params[:action], :page => back10, :search_on => params[:search_on]}.merge(page_select_params), {:title => "-20", :class => "pagination_link"}) if back10
          for p in pstart..pend
            if p == page
              ret << "<span class='current'>#{p}</span>"
            else
              ret << link_to(p, {:action => params[:action], :page => p, :search_on => params[:search_on]}.merge(page_select_params), {:class => "pagination_link"})
            end
          end
          ret << link_to(">", {:action => params[:action], :page => forw10, :search_on => params[:search_on]}.merge(page_select_params), {:title => "+20", :class => "pagination_link"}) if forw10
          ret << link_to(">>", {:action => params[:action], :page => forw100, :search_on => params[:search_on]}.merge(page_select_params), {:title => "+100", :class => "pagination_link"}) if forw100
          ret << "</div>" if opts[:wrapper] == true
        when "array"
          ret << ["&lt;&lt;", back100] if back100
          ret << ["&lt;", back10] if back10
          for p in pstart..pend
            ret << (p == page ? [p, nil] : [p, p])
          end
          ret << ["&gt;", forw10] if forw10
          ret << ["&gt;&gt;", forw100] if forw100
      end
    end
    case return_type
      when 'table' then
        return ret.join("\n").html_safe
      when 'div' then
        return ret.join("\n").html_safe
      when 'array' then
        return ret
    end
    return nil
  end

  # Executes the given block +retries+ times (or forever, if explicitly given nil),
  # catching and retrying SQL Deadlock errors.
  def retry_lock_error(retries = 3, &block)
    yield
    rescue ActiveRecord::StatementInvalid => err
      message = err.message
      if (message =~ /Deadlock found when trying to get lock/ ||
          message =~ /ErrorLock wait timeout exceeded/ || message =~ /Lock wait timeout exceeded/) &&
         (retries.nil? || retries > 0)
        retry_lock_error(retries ? retries - 1 : nil, &block)
      else
        MorLog.my_debug("#{message}")
        message
      end
  end

  def invoice_xlsx_cells_names
    ['inv_number', 'inv_issue_date', 'inv_period_start', 'inv_period_end', 'inv_timezone', 'inv_client_name',
      'inv_client_details1', 'inv_client_details2', 'inv_client_details3', 'inv_client_details4', 'inv_client_details5',
      'inv_client_details7', 'inv_client_details6', 'inv_details_destination_number', 'inv_details_prefix',
      'inv_details_name', 'inv_details_quantity', 'inv_details_total_time', 'inv_details_price', 'inv_price',
      'inv_price_with_vat', 'inv_comment', 'inv_user_clientid', 'inv_user_agreement_number']
  end

  def default_invoice_xlsx_cells
    conflines_names = invoice_xlsx_cells_names + ['inv_debt', 'inv_debt_tax', 'inv_total_amount_due']
    default_values = ['G2', 'G3', 'A7', 'D7', 'G7', 'A2', 'A3', 'B3', 'C3', 'A4', 'B4', 'A5', 'A13', 'B13', 'F13',
      'I13', 'H13', 'J13', 'E25', 'E26', 'D27', 'D12', 'F12', 'I26']
    hash_of_defult_values = Hash[conflines_names.zip default_values]
  end

  def default_formatting_options(user, params = {})
    user = User.first if user.blank?
    options = {}

    number_digits = Confline.get_value('Nice_Number_Digits')
    options[:number_digits] = number_digits.to_i <= 0 ? 2 : number_digits

    number_decimal = Confline.get_value('Global_Number_Decimal').to_s
    options[:number_decimal] = ['.', ',', ';'].include?(number_decimal) ? number_decimal : '.'

    exchange_rate = user.try(:currency).try(:exchange_rate).to_d
    options[:exchange_rate] = exchange_rate == 0 ? 1 : exchange_rate
    if params[:show_currency]
      options[:exchange_rate] = Currency.count_exchange_rate(user.try(:currency), params[:show_currency])
    end

    time_format = Confline.get_value('time_format', user.try(:owner_id).to_i)
    options[:time_format] = time_format.present? ? time_format : Confline.get_value('time_format', 0)
    date_format = Confline.get_value('date_format', user.try(:owner_id).to_i).split(' ')[0]
    options[:date_format] = date_format.present? ?
        date_format.gsub('%Y', 'yyyy').gsub('%m', 'MM').gsub('%d', 'dd') : 'yyyy-MM-dd'

    options[:usertype] = user.try(:usertype).to_s

    options
  end

  def uptime_from_seconds(seconds)
    days = (seconds / 86400).to_s
    time = '%02d:%02d' % [seconds / 3600 % 24, seconds / 60 % 60]
    days << (days == '1' ? ' day' : ' days')
    "#{days}, #{time}"
  end

  def nice_array_with_conditions(array, condition, *var)
    array[0] << condition
    array.push(*var)

    array
  end

  def split_number(number)
    numbers = []
    number.split('').each_with_index { |num, index| numbers << number[0..index] }
    numbers
  end

  # Checks if a given time has already come in a User's time zone
  def usertime_over?(user, time)
    # User time offset from UTC
    user_offset = ActiveSupport::TimeZone[user.time_zone].try(:formatted_offset, false)
    # Convert User time to Server time
    in_server_time = Time.parse(time.strftime('%Y-%m-%d %H:%M:%S') << " #{user_offset}")
    # Check if the time is over
    in_server_time <= Time.now
  end

  def nice_rate_attr(rate_change)
    rate_change.to_s.sub('increment_s', 'increment')
               .sub('ghost_min_perc', 'ghost_percent')
               .sub('price', 'rate')
               .sub('artype', 'type')
  end

  def pretty_rate_change(model_changes)
    cols = []
    olds = []
    news = []

    model_changes.each do |key, val|
      cols << nice_rate_attr(key)
      olds << format_rate_change_pair(key, val[0])
      news << format_rate_change_pair(key, val[1])
    end

    {cols: cols.join('; '), olds: olds.join('; '), news: news.join('; ')}
  end

  def format_rate_change_pair(key, val)
    return nice_number_with_separator(val) if %w(rate connection_fee increment_s ghost_min_perc price).include?(key)

    time_format = Confline.get_value('time_format')
    time_format = '%H:%M:%S' if time_format.blank?
    return val.strftime(time_format) if key == 'end_time'
    return '∞' if key == 'duration' && val.to_s == '-1'

    val
  end

  def hex_to_bytes(hex_str)
    hex_str.to_s.scan(/.{2}/).map { |unit| unit.to_i(16) }.pack('C*')
  end
end
