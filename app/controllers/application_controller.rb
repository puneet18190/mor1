# -*- encoding : utf-8 -*-
# Methods in this controller can be reached from other controllers.
class ApplicationController < ActionController::Base

  require 'builder/xmlmarkup'

  if !Rails.env.development?
    rescue_from Exception do |exc|
      if params[:controller].to_s != 'api'
        if !params[:this_is_fake_exception] and session
          send_bugsnag(exc) unless Socket.gethostname.to_s.include?('kolmisoft')
          my_rescue_action_in_public(exc)

          if session[:flash_not_redirect].to_i == 0
            redirect_to :root # and return false
          else
            render(layout: 'layouts/mor_min') and return false
          end
        else
          render text: my_rescue_action_in_public(exc)
        end
      end
    end
  end

  rescue_from ActiveRecord::RecordNotFound, with: :action_missing
  rescue_from AbstractController::ActionNotFound, with: :action_missing
  rescue_from ActionController::RoutingError, with: :action_missing
  rescue_from ActionController::UnknownController, with: :action_missing
  rescue_from ActionView::MissingTemplate, with: :template_missing

  # rescue_from ActionController::UnknownAction, with: :action_missing

  protect_from_forgery(with: :reset_session)

  include SqlExport
  include UniversalHelpers

  require 'digest/sha1'
  require 'enumerator'
  # require 'ruby_extensions'
  require 'net/http'

  # Pick a unique cookie name to distinguish our session data from others'
  # session session_key: '_mor_session_id'

  helper_method :convert_curr, :allow_manage_providers?, :allow_manage_dids?, :allow_manage_providers_tariffs?,
                :correct_owner_id, :pagination_array, :invoice_state, :nice_invoice_number, :nice_invoice_number_digits,
                :current_user, :current_user_id, :can_see_finances?, :hide_finances, :session_from_datetime_array,
                :session_till_datetime_array, :accountant_can_write?, :accountant_can_read?, :nice_date,
                :nice_date_time, :reseller_active?, :multi_level_reseller_active?, :rec_active?, :cc_active?, :ad_active?, :change_exchange_rate,
                :ccl_active?, :is_number?, :is_numeric?, :load_ok?, :pbx_active?, :send_email_dry,
                :user_tz, :strip_params, :partner_permissions, :authorize_partner_permissions,
                :should_convert_currency?, :corrected_current_user, :set_content_type,
                :simple_user_permissions, :authorize_simple_user_permissions, :all_simple_user_permissions,
                :server_free_space_limit, :nice_cid, :cid_number, :get_server_path, :allow_pdffax_edit_for_user?,
                :es_session_from, :es_session_till, :collide_prefix, :es_limit_search_by_days, :reseller_not_pro?, :validate_session_ip,
                :can_manage_tariffs?, :can_manage_users?, :can_manage_devices?, :can_manage_providers?

  # addons
  helper_method :callback_active?, :call_shop_active?, :payment_gateway_active?,
                :calling_cards_active?, :sms_active?, :recordings_addon_active?, :monitorings_addon_active?,
                :skp_active?, :cc_single_login_active?, :admin?, :reseller?, :user?, :accountant?,
                :reseller_pro_active?, :partner?, :provider_billing_active?, :providers_enabled_for_reseller?,
                :check_if_email_addresses_are_unique, :allow_duplicate_emails?, :show_rec?
  before_filter :set_charset
  before_filter :set_current_user, :set_timezone
  before_filter :logout_on_session_ip_mismatch, except: [:get_otp, :verify_otp]
  before_filter :redirect_callshop_manager
  before_filter :elasticsearch_status_check, except: [
      :active_calls_count, :active_calls_show, :retrieve_call_debug_info
  ]
  after_filter :annoying_messages

  def redirect_callshop_manager
    if current_user and not admin? and current_user.is_callshop_manager?
      redirect_to controller: 'callshop', action: 'show', id: current_user.callshop_manager_group.group_id
      return false
    end
  end

  def change_currency
    params_currency = params[:currency]
    session_currency = session[:show_currency]

    currency =  if params_currency
                  params_currency
                elsif !session_currency
                  current_user.currency.name
                end
    session[:show_currency] = currency if currency
  end

  def change_exchange_rate
    currency = session[:show_currency]
    exchange_rate = currency ? Currency.where(name: currency).first.exchange_rate.to_d : 1
    exchange_rate
  end

  def action_missing(err, *args, &block)
    action = params[:action]
    controller = params[:controller]
    session_blank = session.blank?
    MorLog.my_debug("Authorization failed:\n   User_type: " + (session_blank ? '' : session[:usertype_id].to_s) + "\n   Requested: " + "#{controller if params}::#{action if params}")
    MorLog.my_debug("   Session(#{controller}_#{action}):"+ (session_blank ? '' : session["#{controller}_#{action}".intern].to_s))
    if controller.to_s == 'api'
      doc = Builder::XmlMarkup.new(target: output_string = '', indent: 2)
      doc.instruct! :xml, version: '1.0', encoding: 'UTF-8'
      doc = MorApi.return_error('There is no such API', doc)
      if params[:test].to_i == 1
        render text: output_string and return false
      else
        if confline('XML_API_Extension').to_i == 1
          send_data(output_string, type: 'text/xml', filename: 'mor_api_response.xml') and return false
        else
          send_data(output_string, type: 'text/html', filename: 'mor_api_response.html') and return false
        end
      end
    else
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      Rails.logger.error(err)
      redirect_to :root
    end
  end

  def template_missing
    redirect_to :root
  end

  def show_recordings?
    Confline.get_value('Hide_recordings_for_all_users', 0).to_i == 0
  end

  def item_pages(total_items)
    # total_items - positive integer, number of items that are going to be displayed per all pages
    # items_per_page - how many items should be displayed in one page, positive integer, depends on user settings
    # total_pages - how many pages will be needes to display items when divided per pages
    # if there's no items per session set we should save it in session for future use. after we validate id
    session[:items_per_page], items_per_page = Application.items_per_page_count(session[:items_per_page])
    #so there's code duplication, 1 should be refactored and set as some sort of global constant
    total_pages = (total_items.to_d / items_per_page.to_d).ceil
    return items_per_page, total_pages
  end

  def convert_curr(price)
    current_user.convert_curr(price)
  end

  def set_current_user
    User.current = current_user

    if current_user &&
      !ActiveSupport::TimeZone.all.each_with_index.collect { |tz| tz.name.to_s }.include?(current_user.time_zone.to_s)
      current_user.update_attributes(time_zone: 'UTC')
    end

    User.system_time_offset = session[:time_zone_offset].to_i
  end

  def set_timezone
    begin
      Time.zone = current_user.time_zone if current_user
    rescue => err
    end
  end

  def set_charset
    # TICKET: 8845
    # headers["Content-Type"] = "text/html; charset=utf-8"
    session[:flash_not_redirect] = 0 if session
  end

  def set_content_type
    headers['Content-Type'] = 'text/html; charset=utf-8'
  end

  def mobile_standard
    if request.env['HTTP_X_MOBILE_GATEWAY']
      out = nil
    else

      #  request.env["HTTP_USER_AGENT"].match("iPhone") ? "mobile" : "callc"
      iphone_request = request.env['HTTP_USER_AGENT'].to_s.match('iPhone')

      if session[:layout_t]
        if session[:layout_t].to_s == 'mini'
          if iphone_request
            out = 'iphone'
          end
        end

        if session[:layout_t].to_s == 'full' or session[:layout_t].to_s == nil
          out = 'callc'
        end

        if session[:layout_t].to_s == 'callcenter'
          out = 'callcenter'
        end
      else
        if !(iphone_request or request.env['HTTP_USER_AGENT'].to_s.match('iPod'))
          out = 'callc'
        end

        if iphone_request
          out = 'iphone'
        end
      end
    end

    return out
  end

  # this function exchanges calls table fields user_price with reseller_price to fix major flaw in MORs' database design prior MOR 0.8
  # this function should NEVER be used! it is made just for testing purposes!
  def exchange_user_to_reseller_calls_table_values
    updated = Confline.exchange_user_to_reseller_calls_table

    unless updated
      flash[:notice] = 'Calls table already fixed. Not fixing again.'
    end
  end

  # puts correct language
  def check_localization
    # ---- language ------
    params_lang = params[:lang]
    session_lang = session[:lang]
    if params_lang && params_lang.is_a?(String)
      I18n.locale = params_lang
      session[:lang] = params_lang
      ActiveProcessor.configuration.language = params_lang
    else
      if session_lang
        I18n.locale = session_lang
        ActiveProcessor.configuration.language = session_lang
      else
        session[:lang] = set_valid_language
        I18n.locale = session_lang
      end
    end

    # flags_to_session if !session[:tr_arr]

    # ---- currency ------
    if params[:currency]
      if curr = Currency.where(name: params[:currency].gsub(/[^A-Za-z]/, '')).first
        session[:show_currency] = curr.name
      end
    end

    time = test_machine_active? ? (Time.now - 3.year) : Time.now

    # ---- items per page -----
    session[:items_per_page] = 1 if session[:items_per_page].to_i < 1

    if current_user
      session[:year_from] = current_user.user_time(time).year if session[:year_from].to_i == 0
      session[:month_from] = current_user.user_time(time).month if session[:month_from].to_i == 0
      session[:day_from] = current_user.user_time(time).day if session[:day_from].to_i == 0

      session[:year_till] = current_user.user_time(time).year if session[:year_till].to_i == 0
      session[:month_till] = current_user.user_time(time).month if session[:month_till].to_i == 0
      session[:day_till] = current_user.user_time(time).day if session[:day_till].to_i == 0
    else
      session[:year_from] = time.year if session[:year_from].to_i == 0
      session[:month_from] = time.month if session[:month_from].to_i == 0
      session[:day_from] = time.day if session[:day_from].to_i == 0

      session[:year_till] = time.year if session[:year_till].to_i == 0
      session[:month_till] = time.month if session[:month_till].to_i == 0
      session[:day_till] = time.day if session[:day_till].to_i == 0
    end
  end

  def authorize
    if !admin? && !partner? && !user?
      contr = controller_name.to_s.gsub(/"|'|\\/, '')
      act = action_name.to_s.gsub(/"|'|\\/, '')
      controller_action = session["#{contr}_#{act}".intern]

      if !controller_action || controller_action.class != Fixnum || controller_action.to_i != 1
        # handle guests
        if !session[:usertype_id] or session[:usertype] == "guest" or session[:usertype].blank?
          guest = Role.where(name: 'guest').first

          if guest
            session[:usertype_id] = guest.id
            session[:usertype] = 'guest'
          else
            redirect_to controller: 'callc', action: 'login' and return false
          end
        end

        roleright = RoleRight.get_authorization(session[:usertype_id], contr, act).to_i
        session["#{contr}_#{act}".intern] = roleright
      end

      if session["#{contr}_#{act}".intern].to_i != 1
        MorLog.my_debug("Authorization failed:\n   User_type: "+session[:usertype_id].to_s+"\n   Requested: " + "#{contr}::#{act}")
        MorLog.my_debug("   Session(#{contr}_#{act}):"+ session["#{contr}_#{act}".intern].to_s)
        I18n.locale = params[:lang] if params[:lang] && !params[:lang].blank?
        flash[:notice] = _('You_are_not_authorized_to_view_this_page')

       if session[:user_id] != nil
          (redirect_to :root) && (return false)
        else
          redirect_to controller: 'callc', action: 'login' and return false
        end
      end
    elsif partner?
      authorize_partner_permissions
    elsif user?
      authorize_simple_user_permissions
    end
  end

  def check_read_write_permission(view = [], edit = [], options= {})
    options[:ignore] ||= false

    if session[:usertype] == options[:role]
      action = params[:action].to_sym
      problem = 0
      problem = 1 if (edit.include?(action) and session[options[:right]].to_i != 2)
      problem = 2 if (view.include?(action) and session[options[:right]].to_i == 0)
      problem = 3 if (!(view+edit).include?(action) and !options[:ignore])

      if problem > 0
        MorLog.my_debug("  >> Problems? #{problem}")
        flash[:notice] = [nil, _('You_have_no_editing_permission'), _('You_have_no_view_permission'), _('You_have_no_permission')][problem]
        redirect_to :root
        return false, false
      end

      return session[options[:right]].to_i > 0, session[options[:right]].to_i == 2
    else
      return true, true
    end
  end

  def authorize_admin
    if !admin?
      flash[:notice] = user? ? _('Dont_be_so_smart') : _('You_are_not_authorized_to_view_this_page')
      if session[:user_id] != nil
        (redirect_to :root) && (return false)
      else
        redirect_to controller: 'callc', action: 'login' and return false
      end
    end
  end

  def today
    current_user.user_time(Time.now).strftime('%Y-%m-%d')
  end

  def add_action (user_id, action, data, action_cache = nil)
    time_now = Time.now

    if user_id
      if action_cache
        action_cache.add("NULL, '#{data}', NULL, NULL, '#{action}', '#{time_now.to_s(:db)}', 0, #{user_id}, NULL, ''")
      else
        Action.new(date: time_now, user_id: user_id, action: action, data: data).save
      end
    end
  end

  def add_action_second (user_id, action, data, data2)
    if user_id
      act = Action.new(
        date: Time.now,
        user_id: user_id,
        action: action,
        data: data
      )
      if data2
        act.data2 = data2
      end
      act.save
    end
  end

  def search_not_for_today
    today = Time.now.strftime('%Y-%m-%d')
    session_from_datetime_no_timezone != "#{today} 00:00:00" || session_till_datetime_no_timezone != "#{today} 23:59:59" ? true : false
  end

  def change_date_to_present
    change_date_from_to_present
    change_date_till_to_present
  end

  def change_date_from_to_present
    user_time = current_user.user_time(Time.now)
    session[:year_from], session[:month_from], session[:day_from], session[:hour_from], session[:minute_from] = user_time.year, user_time.month, user_time.day, 0, 0
  end

  def change_date_till_to_present
    user_time = current_user.user_time(Time.now)
    session[:year_till], session[:month_till], session[:day_till], session[:hour_till], session[:minute_till] = user_time.year, user_time.month, user_time.day, 23, 59
   end

  def change_date_from
    if params[:date_from]
      if params[:date_from][:year].to_i > 1999 # dirty hack to prevent ajax trashed params error

        session_date_from_params('from')
        # Reset session date from if invalid params were given
        begin
          session_from_datetime
       rescue => err
          change_date_from_to_present
        end
      end
    end

    if not session[:year_from]
      change_date_from_to_present
    end
  end

  def change_date_till
    if params[:date_till]
      if params[:date_till][:year].to_i > 1999 # dirty hack to prevent ajax trashed params error

        session_date_from_params('till')

        # Reset session date till if invalid params were given
        begin
          session_till_datetime
       rescue => err
          change_date_till_to_present
        end
      end
    end

    if not session[:year_till]
      change_date_till_to_present
    end
  end

  def session_date_from_params(mode = 'from')
    session["year_#{mode}"] = params["date_#{mode}"][:year]
    session["month_#{mode}"] = params["date_#{mode}"][:month].to_i <= 0 ? 1 : params["date_#{mode}"][:month].to_i
    session["month_#{mode}"] = 12 if params["date_#{mode}"][:month].to_i > 12

    if params["date_#{mode}"][:day].to_i < 1
      params["date_#{mode}"][:day] = 1
    else
      if !Date.valid_civil?(session[:year_till].to_i, session["month_#{mode}"].to_i, params["date_#{mode}"][:day].to_i)
        params["date_#{mode}"][:day] = last_day_of_month(session[:year_till], session["month_#{mode}"])
      end
    end

    session["day_#{mode}"] = params["date_#{mode}"][:day]
    session["hour_#{mode}"] = params["date_#{mode}"][:hour] if params["date_#{mode}"][:hour]
    session["minute_#{mode}"] = params["date_#{mode}"][:minute] if params["date_#{mode}"][:minute]
  end

  def change_date
    change_date_from
    change_date_till

    if Time.parse(session_from_datetime) > Time.parse(session_till_datetime)
      flash[:notice] = _('Date_from_greater_thant_date_till')
    end

    current_user_session_time
  end

  def current_user_session_time
    cust_from = Time.mktime(session[:year_from], session[:month_from], session[:day_from], session[:hour_from], session[:minute_from])
    cust_till = Time.mktime(session[:year_till], session[:month_till], session[:day_till], session[:hour_till], session[:minute_till])

    if current_user
      session[:current_user_time_from] = current_user.system_time(cust_from)
      session[:current_user_time_till] = current_user.system_time(cust_till)
    end
  end

  def random_password(size = 12)
    ApplicationController::random_password(size)
  end

  def ApplicationController::random_password(size = 12)
    lowercase = ('a'..'z').to_a
    numbers = (0..9).to_a
    if User.use_strong_password?
      uppercase = ('A'..'Z').to_a
      pass = []
      inner_range = 1..(size.to_f / 3).ceil
      pass << inner_range.map { |char| lowercase[rand(lowercase.size)] }
      pass << inner_range.map { |char| uppercase[rand(uppercase.size)] }
      pass << inner_range.map { |char| numbers[rand(numbers.size)] }
      pass.flatten.shuffle.join[0, size]
    else
      chars = (lowercase + numbers) - %w(i o 0 1 l 0)
      (1..size).collect { |char| chars[rand(chars.size)] }.join
    end
  end

  def random_digit_password(size = 8)
    chars = ((0..9).to_a)
    (1..size).map { |char| chars[rand(chars.size)] }.join
  end

  # put value into file for debugging
  def my_debug(msg)
    File.open(Debug_File, 'a') { |file|
      file << msg.to_s
      file << "\n"
    }
  end

  # put value into file for debugging
  def my_debug_time(msg)
    MorLog.my_debug(msg, true, '%Y-%m-%d %H:%M:%S')
  end

  # done once in a while to check some functions, like did releasing, invoice counting and so on
  def global_check
    # did release checking
    Did.closed.all.each { |did| did.update(status: 'free', user: nil, device: nil) if (did.closed_till < Time.now) }
  end

  # function for configuring extensions for local devices based on passed arguments
  # basically this function configures call-flow for each device
  def configure_extensions(device_id, options = {})
    device = Device.where(id: device_id).first
            pbx_pool_id = device.try(:user).try(:pbx_pool_id)
            pool = pbx_pool_id && (pbx_pool_id > 1) ? "@pool_#{pbx_pool_id}" : ''

    return if !device || device_id == 0

    default_context = 'mor_local'
    default_app = 'Dial'

    busy_extension = 201
    no_answer_extension = 401
    chanunavail_extension = 301


    @user = User.where(id: device.user_id).first if device.user_id.to_i > -1

    user_id = 0
    user_id = device.user_id if @user

    timeout = device[:timeout]

    if device
      #delete old config
      ActiveRecord::Base.connection.delete("DELETE `extlines`.* FROM `extlines` WHERE `extlines`.`device_id` = #{device_id}")

      i = 1

      # Configuring for incoming calls for extension

      # Handle local CDRs
      Extline.mcreate(default_context, i, 'GotoIf', '$[${LEN(${MOR_BILLING})} > 0]?' + (i + 2).to_s + ':' + (i + 1).to_s, device.extension, device_id)
      i += 1
      Extline.mcreate(default_context, i, 'AGI', "/var/lib/asterisk/agi-bin/mor_local_cdr, #{device_id}", device.extension, device_id)
      i += 1

      # Handling BUSY from DID limited calls
      Extline.mcreate(default_context, i, 'NoOp', "${MOR_MAKE_BUSY}", device.extension, device_id)
      i += 1
      Extline.mcreate(default_context, i, 'GotoIf', "$[\"${MOR_MAKE_BUSY}\" = \"1\"]?201", device.extension, device_id)
      i += 1

      # Handle recordings
      if (device.record.to_i == 1 && @user.try(:recording_enabled).to_i == 1) || device.record_forced.to_i == 1 || @user.try(:recording_forced_enabled).to_i == 1
        Extline.mcreate(default_context, i, 'GotoIf', '$[${LEN(${MOR_UNIQUEID})} > 0]?' + (i+1).to_s + ':' + (i+2).to_s, device.extension, device_id)
        i += 1
        Extline.mcreate(default_context, i, 'MixMonitor', "${CDR(uniqueid)}.wav,,/usr/local/mor/mor_record_file \"${CDR(uniqueid)}\" 0 #{device_id} 0 #{device.record.to_i == 1 ? '1' : '0'} \"${MOR_UNIQUEID}\" \"${MOR_CALLDATE}\"", device.extension, device_id)
        i += 1
      end

      # Handling transfers
      Extline.mcreate(default_context, i, 'GotoIf', "$[${LEN(${CALLED_TO})} > 0]?" + (i+1).to_s + ":" + (i+3).to_s, device.extension, device_id)
      i += 1
      Extline.mcreate(default_context, i, 'Set', "CALLERID(NAME)=${CALLED_TO}", device.extension, device_id)
      # Extline.mcreate(default_context, i, "NoOp", "CALLERID(NAME)=TRANSFER FROM ${CALLED_TO}", device.extension, device_id)
      i += 1
      Extline.mcreate(default_context, i, 'Goto', device.extension.to_s + "|" + (i+2).to_s, device.extension, device_id)
      i += 1
      Extline.mcreate(default_context, i, 'Set', "CALLED_TO=${EXTEN}", device.extension, device_id)
      i += 1

      # ======================  B E F O R E   C A L L  ======================
      before_call_cfs = Callflow.where("cf_type = 'before_call' AND device_id = #{device.id}").order("priority ASC")

      for cf in before_call_cfs

        case cf.action
          when 'forward'

            # --------- start forward callerid change ------------
            caller_id_name = nice_cid(device.callerid)
            case cf.data3
              when 1
                forward_callerid = cid_number(device.callerid)
                # 10971
                if caller_id_name.present?
                  Extline.mcreate(default_context, i, 'Set', "CALLERID(NAME)=#{caller_id_name}", device.extension, device_id)
                  i += 1
                end
              when 2
                forward_callerid = ''
              when 3
                forward_callerid = Did.where(id: cf.data4).first.try(:did).to_s
              when 4
                forward_callerid = cf.data4
            end

            if cf.data3 != 2 && forward_callerid.to_s.length > 0 #callerid does not changes
              Extline.mcreate(default_context, i, 'Set', "CALLERID(num)=#{forward_callerid}", device.extension, device_id)
              i += 1
            end
            if cf.data3 == 1
              Extline.mcreate(default_context, i, 'Set', "CALLED_TO=#{caller_id_name}", device.extension, device_id)
              i += 1
            else
              Extline.mcreate(default_context, i, 'Set', 'CALLED_TO=', device.extension, device_id)
              i += 1
            end


            # --------- end forward callerid change ------------

            case cf.data2
              when 'local'
                dev = Device.where(id: cf.data).first
                pool_id = dev.user.pbx_pool_id
                if dev
                  pool_id > 1 ? Extline.mcreate(default_context, i, 'Goto', "pool_#{pool_id}_mor_local|#{dev.extension}|1", device.extension, device_id) : Extline.mcreate(default_context, i, 'Goto', "mor_local|#{dev.extension}|1", device.extension, device_id)
                  i += 1
                end
              when 'external'
                Extline.mcreate(default_context, i, 'Set', "CDR(ACCOUNTCODE)=#{device_id}", device.extension, device_id)
                i += 1
                Extline.mcreate(default_context, i, 'Goto', "mor|#{cf.data}|1", device.extension, device_id)
                i += 1
            end #case cf.data2

          when 'voicemail'

            Extline.mcreate(default_context, i, 'Set', 'MOR_VM=', device.extension, device_id)
            i += 1
            Extline.mcreate(default_context, i, 'Goto', "mor_voicemail|${EXTEN}#{pool}|1", device.extension, device_id)
            i += 1

          when 'fax_detect'

            if  cf.data.to_i > 0

              from_sender = Confline.get_value('Email_Fax_From_Sender', @user.owner_id)

              Extline.mcreate(default_context, i, 'Set', "MASTER_CHANNEL(FROM_SENDER)=#{from_sender}", device.extension, device_id)
              i += 1
              Extline.mcreate(default_context, i, 'Set', "MASTER_CHANNEL(MOR_FAX_ID)=#{cf.data}", device.extension, device_id)
              i += 1
              Extline.mcreate(default_context, i, 'Set', "MASTER_CHANNEL(FAXSENDER)=${CALLERID(number)}", device.extension, device_id)
              i += 1
              Extline.mcreate(default_context, i, 'Set', "MASTER_CHANNEL(MOR_FAX_DETECT)=1", device.extension, device_id)
              i += 1
              Extline.mcreate(default_context, i, 'Answer', '', device.extension, device_id)
              i += 1
              Extline.mcreate(default_context, i, 'ResetCDR', '', device.extension, device_id)
              i += 1
            end
        end #case cf.action
      end
      #=========================================================

      if device.device_type != 'FAX'

        # forward
        #if device.forward_to != 0
        #if @fwd_extension = Device.find(device.forward_to).extension
        #  Extline.mcreate(default_context, i, "Goto", @fwd_extension.to_s+"|1", device.extension, device_id)
        # i+=1
        #end
        #end

        # recordings

        Extline.mcreate(default_context, i, 'NoOp', 'MOR starts', device.extension, device_id)
        i += 1

        # Handling CALLERID NAME
        Extline.mcreate(default_context, i, 'GotoIf', "$[${LEN(${CALLERID(NAME)})} > 0]?" + (i+3).to_s + ':' + (i+1).to_s, device.extension, device_id)
        i += 1
        Extline.mcreate(default_context, i, 'GotoIf', "$[${LEN(${mor_cid_name})} > 0]?" + (i+1).to_s + ':' + (i+2).to_s, device.extension, device_id)
        i += 1
        Extline.mcreate(default_context, i, 'Set', "CALLERID(NAME)=${mor_cid_name}", device.extension, device_id)
        i += 1


        # handling CallerID by ANI (if available)
        if device.use_ani_for_cli == true
          Extline.mcreate(default_context, i, 'GotoIf', "$[${LEN(${CALLERID(ANI)})} > 0]?" + (i+1).to_s + ':' + (i+2).to_s, device.extension, device_id)
          i += 1
          Extline.mcreate(default_context, i, 'Set', "CALLERID(NUM)=${CALLERID(ANI)}", device.extension, device_id)
          i += 1
        end


        #handling calleridpres
        if device.calleridpres.to_s.length > 0
          Extline.mcreate(default_context, i, 'Set', "CALLERID(name-pres)=#{device.calleridpres.to_s}", device.extension, device_id)
          i += 1
          Extline.mcreate(default_context, i, 'Set', "CALLERID(num-pres)=#{device.calleridpres.to_s}", device.extension, device_id)
          i += 1
        end


        # normal path

        # SIP Proxy support
        if ccl_active? and device.device_type.to_s == 'SIP'

          sip_proxy = Server.where('server_type = "sip_proxy"').first
          if sip_proxy
            Extline.mcreate(default_context, i, default_app, 'SIP/mor_server_' + sip_proxy.id.to_s + "/" + device.name + "," + device[:timeout].to_s, device.extension, device_id)
          end

        else

          # normal call-flow without sip-proxy
          # Trunk support
          trunk = ''
          if device.istrunk == 1
            Extline.mcreate(default_context, i, 'GotoIf', "$[${LEN(${MOR_DID})} > 0]?" + "#{i+1}:#{i+3}", device.extension, device_id)
            i += 1
            Extline.mcreate(default_context, i, default_app, device.device_type + "/" + device.name + "/${MOR_DID}|#{timeout.to_s}#{'|il' if device.promiscredir.to_s == 'no'}", device.extension, device_id)
            i += 1
            Extline.mcreate(default_context, i, 'Goto', "#{i+2}", device.extension, device_id)
            i += 1
            trunk = "/${EXTEN}"
          end
          # end trunk support

          # actual dialing to device
          Extline.mcreate(default_context, i, default_app, device.device_type + "/" + device.name + trunk + "|#{timeout.to_s}#{'|il' if device.promiscredir.to_s == 'no'}", device.extension, device_id) #il disables transfers

        end # sip proxy support


        busy_ext = 200 + i
        i += 1
        Extline.mcreate(default_context, i, 'GotoIf', "$[$[\"${DIALSTATUS}\" = \"CHANUNAVAIL\"]|$[\"${DIALSTATUS}\" = \"CONGESTION\"]]?" + chanunavail_extension.to_s, device.extension, device_id)
        i += 1
        Extline.mcreate(default_context, i, 'GotoIf', "$[\"${DIALSTATUS}\" = \"BUSY\"]?" + busy_extension.to_s, device.extension, device_id)
        i += 1
        Extline.mcreate(default_context, i, 'GotoIf', "$[\"${DIALSTATUS}\" = \"NOANSWER\"]?" + no_answer_extension.to_s, device.extension, device_id)

        i += 1
        Extline.mcreate(default_context, i, 'Hangup', '', device.extension, device_id)

      else

        # fax2email

        Extline.mcreate(default_context, i, 'Set', "MOR_FAX_ID=#{device.id}", device.extension, device_id)
        i += 1
        Extline.mcreate(default_context, i, 'Set', "FAXSENDER=${CALLERID(number)}", device.extension, device_id)
        i += 1
        Extline.mcreate(default_context, i, 'Goto', "mor_fax2email|${EXTEN}|1", device.extension, device_id)
        i += 1

      end

      # ======================  N O   A N S W E R  ======================
      i = no_answer_extension

      Extline.mcreate(default_context, i, 'NoOp', 'NO ANSWER', device.extension, device_id)
      i += 1

      no_answer_cfs = Callflow.where("cf_type = 'no_answer' AND device_id = #{device.id}").order("priority ASC")
      for cf in no_answer_cfs

        case cf.action
          when 'forward'

            # --------- start forward callerid change ------------

            caller_id_name = nice_cid(device.callerid)
            case cf.data3
              when 1
                forward_callerid = cid_number(device.callerid)
                # 10971
                if caller_id_name.present?
                  Extline.mcreate(default_context, i, 'Set', "CALLERID(NAME)=#{caller_id_name}", device.extension, device_id)
                  i += 1
                end
              when 2
                forward_callerid = ''
              when 3
                forward_callerid = Did.where(id: cf.data4).first.try(:did).to_s
              when 4
                forward_callerid = cf.data4
            end

            if cf.data3 != 2 and forward_callerid.to_s.length > 0 # callerid does not changes
              Extline.mcreate(default_context, i, 'Set', "CALLERID(num)=#{forward_callerid}", device.extension, device_id)
              i += 1
            end

            # --------- end forward callerid change ------------

            case cf.data2
              when 'local'
                dev = Device.where(id: cf.data).first
                pool_id = dev.user.pbx_pool_id
                if dev
                  pool_id > 1 ? Extline.mcreate(default_context, i, 'Goto', "pool_#{pool_id}_mor_local|#{dev.extension}|1", device.extension, device_id) : Extline.mcreate(default_context, i, 'Goto', "mor_local|#{dev.extension}|1", device.extension, device_id)
                  i += 1
                end
              when 'external'
                Extline.mcreate(default_context, i, 'Set', "CDR(ACCOUNTCODE)=#{device_id}", device.extension, device_id)
                i+=1
                Extline.mcreate(default_context, i, 'Goto', "mor|#{cf.data}|1", device.extension, device_id)
                i += 1
              when ""
                Extline.mcreate(default_context, i, 'Hangup', '', device.extension, device_id)
            end # case cf.data2

          when 'voicemail'
            #          Extline.mcreate(default_context, i, "Voicemail", device.extension.to_s + "|u", device.extension, device_id)
            #                   i+=1
            #            Extline.mcreate(default_context, i, "Hangup", "", device.extension, device_id)
            if cf.data5.to_i == 1
              Extline.mcreate(default_context, i, 'Set', 'MOR_VM="su"', device.extension, device_id)
            else
              Extline.mcreate(default_context, i, 'Set', 'MOR_VM="u"', device.extension, device_id)
            end
            i += 1
            Extline.mcreate(default_context, i, 'Goto', "mor_voicemail|${EXTEN}#{pool}|1", device.extension, device_id)
            i += 1

          when 'empty'
            Extline.mcreate(default_context, i, 'Hangup', '', device.extension, device_id)
        end # case cf.action

      end

      if no_answer_cfs.empty?
        Extline.mcreate(default_context, i, 'Hangup', '', device.extension, device_id)
      end
      # =========================================================


      # ======================  B U S Y  ======================
      i = busy_extension

      Extline.mcreate(default_context, i, 'NoOp', 'BUSY', device.extension, device_id)
      i += 1

      busy_cfs = Callflow.where(["cf_type = 'busy' AND device_id = ?", device.id]).order("priority ASC")
      for cf in busy_cfs

        case cf.action
          when 'forward'

            # --------- start forward callerid change ------------

            caller_id_name = nice_cid(device.callerid)
            case cf.data3
              when 1
                forward_callerid = cid_number(device.callerid)
                # 10971
                if caller_id_name.present?
                  Extline.mcreate(default_context, i, 'Set', "CALLERID(NAME)=#{caller_id_name}", device.extension, device_id)
                  i += 1
                end
              when 2
                forward_callerid = ''
              when 3
                forward_callerid = Did.where(id: cf.data4).first.try(:did).to_s
              when 4
                forward_callerid = cf.data4
            end

            if cf.data3 != 2 and forward_callerid.to_s.length > 0 #callerid does not changes
              Extline.mcreate(default_context, i, 'Set', "CALLERID(num)=#{forward_callerid}", device.extension, device_id)
              i+=1
            end

            # --------- end forward callerid change ------------

            case cf.data2
              when 'local'
                dev = Device.where(id: cf.data).first
                pool_id = dev.user.pbx_pool_id
                if dev
                  pool_id > 1 ? Extline.mcreate(default_context, i, 'Goto', "pool_#{pool_id}_mor_local|#{dev.extension}|1", device.extension, device_id) : Extline.mcreate(default_context, i, 'Goto', "mor_local|#{dev.extension}|1", device.extension, device_id)
                  i+=1
                end
              when 'external'
                Extline.mcreate(default_context, i, 'Set', "CDR(ACCOUNTCODE)=#{device_id}", device.extension, device_id)
                i+=1
                Extline.mcreate(default_context, i, 'Goto', "mor|#{cf.data}|1", device.extension, device_id)
                i+=1
              when ''

                Extline.mcreate(default_context, i, 'GotoIf', "${LEN(${MOR_CALL_FROM_DID}) = 1}?#{i + 1}:mor|BUSY|1", device.extension, device_id)
                i += 1
                Extline.mcreate(default_context, i, 'Busy', '10', device.extension, device_id)
                i += 1

            end #case cf.data2

          when 'voicemail'
            #          Extline.mcreate(default_context, i, "Voicemail", device.extension.to_s + "|b", device.extension, device_id)
            #                   i+=1
            #            Extline.mcreate(default_context, i, "Hangup", "", device.extension, device_id)
            #            i += 1

            if cf.data5.to_i == 1
              Extline.mcreate(default_context, i, 'Set', 'MOR_VM="sb"', device.extension, device_id)
            else
              Extline.mcreate(default_context, i, 'Set', 'MOR_VM="b"', device.extension, device_id)
            end
            i += 1
            Extline.mcreate(default_context, i, 'Goto', "mor_voicemail|${EXTEN}#{pool}|1", device.extension, device_id)
            i += 1

          when 'empty'

            Extline.mcreate(default_context, i, 'GotoIf', "${LEN(${MOR_CALL_FROM_DID}) = 1}?#{i + 1}:mor|BUSY|1", device.extension, device_id)
            i += 1
            Extline.mcreate(default_context, i, 'Busy', '10', device.extension, device_id)
            i += 1

        end #case cf.action

      end

      if busy_cfs.empty?

        Extline.mcreate(default_context, i, 'GotoIf', "${LEN(${MOR_CALL_FROM_DID}) = 1}?#{i + 1}:mor|BUSY|1", device.extension, device_id)
        i += 1
        Extline.mcreate(default_context, i, 'Busy', '10', device.extension, device_id)
        i += 1
      end
      # =========================================================


      # ======================  F A I L E D  ======================
      i = chanunavail_extension

      Extline.mcreate(default_context, i, 'NoOp', 'FAILED', device.extension, device_id)
      i+=1

      failed_cfs = Callflow.where(["cf_type = 'failed' AND device_id = ?",device.id]).order('priority ASC')
      for cf in failed_cfs

        case cf.action
          when 'forward'

            # --------- start forward callerid change ------------

            caller_id_name = nice_cid(device.callerid)
            case cf.data3
              when 1
                forward_callerid = cid_number(device.callerid)
                # 10971
                if caller_id_name.present?
                  Extline.mcreate(default_context, i, 'Set', "CALLERID(NAME)=#{caller_id_name}", device.extension, device_id)
                  i += 1
                end
              when 2
                forward_callerid = ''
              when 3
                forward_callerid = Did.where(id: cf.data4).first.try(:did).to_s
              when 4
                forward_callerid = cf.data4
            end

            if cf.data3 != 2 # callerid does not changes
              Extline.mcreate(default_context, i, 'Set', "CALLERID(num)=#{forward_callerid}", device.extension, device_id)
              i+=1
            end

            # --------- end forward callerid change ------------

            case cf.data2
              when'local'
                dev = Device.where(id: cf.data).first
                pool_id = dev.user.pbx_pool_id
                if dev
                  pool_id > 1 ? Extline.mcreate(default_context, i, 'Goto', "pool_#{pool_id}_mor_local|#{dev.extension}|1", device.extension, device_id) : Extline.mcreate(default_context, i, 'Goto', "mor_local|#{dev.extension}|1", device.extension, device_id)
                  i+=1
                end
              when 'external'
                Extline.mcreate(default_context, i, 'Set', "CDR(ACCOUNTCODE)=#{device_id}", device.extension, device_id)
                i+=1
                Extline.mcreate(default_context, i, 'Goto', "mor|#{cf.data}|1", device.extension, device_id)
                i+=1
              when ''
                Extline.mcreate(default_context, i, 'GotoIf', "${LEN(${MOR_CALL_FROM_DID}) = 1}?#{i + 1}:mor|FAILED|1", device.extension, device_id)
                i += 1
                Extline.mcreate(default_context, i, 'Congestion', '4', device.extension, device_id)
                i += 1
            end # case cf.data2

          when 'voicemail'
            #          Extline.mcreate(default_context, i, "Voicemail", device.extension.to_s + "|u", device.extension, device_id)
            #                   i+=1
            #            Extline.mcreate(default_context, i, "Hangup", "", device.extension, device_id)
            #            i += 1

            if cf.data5.to_i == 1
              Extline.mcreate(default_context, i, 'Set', 'MOR_VM="su"', device.extension, device_id)
            else
              Extline.mcreate(default_context, i, 'Set', 'MOR_VM="u"', device.extension, device_id)
            end
            i += 1
            Extline.mcreate(default_context, i, 'Goto', "mor_voicemail|${EXTEN}#{pool}|1", device.extension, device_id)
            i += 1

          when 'empty'

            Extline.mcreate(default_context, i, 'GotoIf', "${LEN(${MOR_CALL_FROM_DID}) = 1}?#{i + 1}:mor|FAILED|1", device.extension, device_id)
            i += 1
            Extline.mcreate(default_context, i, 'Congestion', '4', device.extension, device_id)
            i += 1

        end # case cf.action

      end

      if failed_cfs.empty?
        Extline.mcreate(default_context, i, 'GotoIf', "${LEN(${MOR_CALL_FROM_DID}) = 1}?#{i + 1}:mor|FAILED|1", device.extension, device_id)
        i += 1
        Extline.mcreate(default_context, i, 'Congestion', '4', device.extension, device_id)
        i += 1
      end
      # =========================================================
      dev = device

      update_context_for_device(dev)

      # check devices login status


      begin
        if dev.device_type == 'SIP'
          dev_name = nil
          if dev.device_old_name_record != dev.name
            dev_name = dev.device_old_name_record
          end
          exception_array = device.prune_device_in_all_servers(dev_name, 1, 1, 0)
          raise StandardError.new('Server_problems') if exception_array.size > 0
        end

        if  dev.device_type == 'IAX2'
          exception_array = device.prune_device_in_all_servers(nil, 1, 0, 1)
          raise StandardError.new('Server_problems') if exception_array.size > 0
        end

        if dev.device_type == 'H323'
          servers = Server.where(server_type: 'asterisk').all
          servers.each do |server|
            server.ami_cmd('h323 reload')
            server.ami_cmd('extensions reload')
          end
        end
        Action.add_action_hash(options[:current_user], {action: 'Device sent to Asterisk', target_id: device.id, target_type: 'device', data: device.user_id})
     rescue => err
        MorLog.my_debug _('Cannot_connect_to_asterisk_server')
        Action.add_action_hash(options[:current_user], {action: 'error', data2: 'Cannot_connect_to_asterisk_server', target_id: device.id, target_type: 'device', data: device.user_id, data3: err.class.to_s, data4: err.message.to_s})
        if admin? and !options[:no_redirect]
          flash_help_link = 'http://wiki.kolmisoft.com/index.php/GUI_Error_-_SystemExit'
          flash[:notice] = _('Cannot_connect_to_asterisk_server')
          flash[:notice] += "<a href='#{flash_help_link}' target='_blank'><img alt='Help' src='#{Web_Dir}/images/icons/help.png' title='#{_('Help')}' />&nbsp;#{_('Click_here_for_more_info')}</a>" if flash_help_link
          if options[:api].to_i == 0
            (redirect_to :root) && (return false)
          else
            return false
          end
        end

      end
    end # if device
    return true
  end

  # converting caller id like "name" <11> to name (takes string between first and last quote)
  def nice_cid(cidn)
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

  # gets position of last quote( " )
  def find_last_quote(string)
    pos,place = [0, 0]
    string.each_char do |char|
      place += 1
      pos = place if char == '"'
    end
    pos
  end

  def session_from_date
    sfd = "#{session[:year_from]}-#{good_date(session[:month_from].to_s)}-#{good_date(session[:day_from].to_s)}"
    current_user.system_time(sfd, 1)
  end

  def session_till_date
    sfd = "#{session[:year_till]}-#{good_date(session[:month_till].to_s)}-#{good_date(session[:day_till].to_s)}"
    current_user.system_time(sfd, 1)
  end

  def session_time_from_db
    Time.zone.local(session[:year_from].to_i, session[:month_from].to_i, session[:day_from].to_i).getlocal.strftime('%F %T')
  end

  def session_time_till_db
    (Time.zone.local(session[:year_till].to_i, session[:month_till].to_i, session[:day_till].to_i) + (1.day - 1.second)).getlocal.strftime('%F %T')
  end

  def session_from_datetime
    sfd = session_from_datetime_no_timezone
    sfd = current_user.nil? ? sfd : current_user.system_time(sfd)
  end

  def session_from_datetime_no_timezone
    sfd = session[:year_from].to_s + '-' + good_date(session[:month_from].to_s) + '-' + good_date(session[:day_from].to_s) + ' ' + good_date(session[:hour_from].to_s) + ':' + good_date(session[:minute_from].to_s) + ':00'
  end

  def session_till_datetime
    sfd = session_till_datetime_no_timezone
    sfd = current_user.nil? ? sfd : current_user.system_time(sfd)
  end

  def session_till_datetime_no_timezone
    sfd = session[:year_till].to_s + '-' + good_date(session[:month_till].to_s) + '-' + good_date(session[:day_till].to_s) + ' ' + good_date(session[:hour_till].to_s) + ':' + good_date(session[:minute_till].to_s) + ':59'
  end

  def session_from_datetime_array
    [session[:year_from].to_s, session[:month_from].to_s, session[:day_from].to_s, session[:hour_from].to_s, session[:minute_from].to_s, '00']
  end

  def session_till_datetime_array
    [session[:year_till].to_s, session[:month_till].to_s, session[:day_till].to_s, session[:hour_till].to_s, session[:minute_till].to_s, '59']
  end

  # ================== C O D E C S =============================

  def audio_codecs
    Codec.where(codec_type: 'audio').order('id ASC')
  end

  def video_codecs
    Codec.where(codec_type: 'video').order('id ASC')
  end

  # ============================================================

  # get last day of month
  def last_day_of_month(year, month)

    year = year.to_i
    month = month.to_i

    if (month == 1) or (month == 3) or (month == 5) or (month == 7) or (month == 8) or (month == 10) or (month == 12)
      day = '31'
    else
      if  (month == 4) or (month == 6) or (month == 9) or (month == 11)
        day = '30'
      else
        if year % 4 == 0
          day = '29'
        else
          day = '28'
        end
      end
    end
    day
  end

  def nice_time2(time)
    time.strftime('%H:%M:%S') if time
  end

  # Since session is turned off in api controller, not only do we need to check for Conflines
  # and/or session variables to format a number, but we need to check wheter session is not nil.
  # In case it is nil we set nice_number_digits to 2 and do not change decimal.
  def nice_number(number)
    confline = (!session || !session[:nice_number_digits]) ? Confline.get_value('Nice_Number_Digits') : session[:nice_number_digits]
    nice_number_digits = (confline and confline.to_s.length > 0) ? confline.to_i : 2
    nice_num = ''
    nice_num = sprintf("%0.#{nice_number_digits}f", number.to_d) if number
    if session
      session[:nice_number_digits] = nice_number_digits
      nice_num = nice_num.gsub('.', session[:global_decimal]) if session[:change_decimal]
    end
    nice_num
  end

  def nice_invoice_number(number, type, precision = '',options = {})
    dig =  nice_invoice_number_digits(type,precision)
    nice_num = ''
    nice_num = sprintf("%0.#{dig}f", number.to_d) if number
    if session[:change_decimal] and options[:no_repl].to_i == 0
      nice_num = nice_num.gsub('.', session[:global_decimal])
    end
    nice_num
  end

  def nice_invoice_number_digits(type, precision = '')
    if type.to_s == 'prepaid'
      session[:nice_prepaid_invoice_number_digits] ||= Confline.get_value('Prepaid_Round_finals_to_2_decimals').to_i
      if session[:nice_prepaid_invoice_number_digits].to_i == 1
        return 2
      else
        if precision.present?
         return precision
        else
         return session[:nice_number_digits]
        end
      end
    else
      session[:nice_invoice_number_digits] ||= Confline.get_value('Round_finals_to_2_decimals').to_i
      if session[:nice_invoice_number_digits].to_i == 1
        return 2
      else
        if precision.present?
         return precision
        else
         return session[:nice_number_digits]
        end
      end
    end
  end

  def link_nice_user(user, options={})
    link_to nice_user(user), { controller: :users, action: :edit, id: user.id }.merge(options)
  end

  def nice_device(device)
    dev = ''
    if device
      device_type = device.try(:device_type).to_s
      device_name = device.name.to_s

      dev = device_type + '/'
      dev += device_name if device_type != 'FAX'
      dev += device.extension.to_s if device_type == 'FAX' or device_name.length == 0
    end
    dev
  end

  def nice_inv_name(iv_id_name)
    id_name = ''
    if  iv_id_name.to_s.strip[-1..-1].to_s.strip == '-'
      name_length = iv_id_name.strip.length
      name_length = name_length.to_i - 2
      id_name = iv_id_name.strip[0..name_length]
    else
      id_name = iv_id_name
    end
    id_name.to_s.strip
  end

  # Looks at devices, dialpalns, extlines and queues tables to check
  #   ext free extension, basically for self-registering users
  # NOTE that devices.username values are also taken extensions
  def get_taken_extensions
    range_min, range_max = Confline.get_device_range_values ||= [0, 1]

    devices_username = ActiveRecord::Base.connection.select_values("
      SELECT username AS taken_extension
      FROM devices
      WHERE (username REGEXP '^[0-9]+$' = 1 AND username BETWEEN #{range_min} AND #{range_max})
    ")

    devices_extension = ActiveRecord::Base.connection.select_values("
      SELECT extension AS taken_extension
      FROM devices
      WHERE (extension REGEXP '^[0-9]+$' = 1 AND extension BETWEEN #{range_min} AND #{range_max})
    ")

    extlines_exten = ActiveRecord::Base.connection.select_values("
      SELECT exten AS taken_extension
      FROM extlines
      WHERE (exten REGEXP '^[0-9]+$' = 1 AND exten BETWEEN #{range_min} AND #{range_max})
    ")

    taken_extensions_array = (devices_username + devices_extension + extlines_exten).map(&:to_i)

    return taken_extensions_array, range_min, range_max
  end

  # Looks for next smallest free extline
  def free_extension(taken_extensions)
    taken_extensions_array, range_min, range_max = taken_extensions

    return (((range_min..range_max).to_a - taken_extensions_array).first || range_max).to_s
  end

  def nice_src(call, options={})
    value = Confline.get_value('Show_Full_Src')
    srt = call.clid.split(' ')
    name = srt[0..-2].join(' ').to_s.delete('"')
    number = call.src.to_s
    if options[:pdf].to_i == 0
      session[:show_full_src] ||= value
    end
    if value.to_i == 1 and name.length > 0
      return "#{number} (#{name})"
    else
      return "#{number}"
    end
  end

  # adding 0 to day or month <10
  def good_date(dd)
    dd = dd.to_s
    dd = '0' + dd if dd.length<2
    dd
  end

  def count_exchange_rate(curr_first, curr_second)
    Currency::count_exchange_rate(curr_first, curr_second)
  end

  def voucher_number(length)
    good = 0

    length = 10 if length.to_i == 0

    while good == 0
      number = random_digit_password(length)
      good = 1 if not Voucher.where(number: number).first
    end

    number
  end

  def next_agreement_number
    sql = "SELECT agreement_number FROM users ORDER by cast(agreement_number as signed) DESC LIMIT 1"
    res = ActiveRecord::Base.connection.select_value(sql)

    # user = User.find(:first, order: "agreement_number DESC")

    number = res.to_i + 1

    start = ''

    length = Confline.get_value("Agreement_Number_Length").to_i
    # default_value
    length = 10 if length == 0

    # If type == 1
    zl = length - start.length - number.to_s.length
    index = ''
    for item in 1..zl
      index += '0'
    end
    num = "#{start}#{index}#{number.to_s}"
    # End

    num.to_s
  end

  def confline(name, id = 0)
    Confline.get_value(name, id)
  end

  def renew_session(user)
    @current_user = user
    session[:username] = user.username
    session[:first_name] = user.first_name
    session[:last_name] = user.last_name
    session[:user_id] = user.id
    session[:usertype] = user.usertype
    session[:owner_id] = user.owner_id
    session[:tax] = user.get_tax
    session[:usertype_id] = Role.where(name: session[:usertype].to_s).first.try(:id).to_i
    session[:device_id] = user.primary_device_id
    session[:tariff_id] = user.tariff_id
    session[:sms_service_active] = user.sms_service_active
    session[:help_link] = Confline.get_value('Hide_HELP_banner').to_i == 0 ? 1 : 0
    session[:callc_main_stats_options]= nil
    if Confline.where('name = "System_time_zone_offset"').first
      session[:time_zone_offset] = Confline.get_value('System_time_zone_ofset').to_i
    else
      sql = 'select HOUR(timediff(now(),convert_tz(now(),@@session.time_zone,\'+00:00\'))) as u;'
      time_offset = ActiveRecord::Base.connection.select_all(sql)[0]['u']
      time_offset_i = time_offset.to_s.to_i
      Confline.set_value('System_time_zone_offset', time_offset_i.to_i, 0)
      session[:time_zone_offset] = Confline.get_value('System_time_zone_ofset').to_i
    end

    %w[Hide_Iwantto Hide_Manual_Link].each do |option|
      session[option.downcase.to_sym] = Confline.get_value(option).to_i
    end

    %w[Hide_Device_Passwords_For_Users].each do |option|
      session[option.downcase.to_sym] = Confline.get_value(option, user.owner_id).to_i
    end

    %w[Hide_Device_Username_For_Users].each do |option|
      session[option.downcase.to_sym] = Confline.get_value(option, user.owner_id).to_i
    end

    curr = Currency.where(id: 1).first
    session[:default_currency] = curr.try(:name)
    Currency.check_first_for_active if curr.try(:active).to_i == 0
    session[:show_currency] = user.currency.try(:name)

    session[:manager_in_groups] = user.manager_in_groups

    cookies[:mor_device_id] = user.primary_device_id.to_s

    session[:voucher_attempt] = Confline.get_value('Voucher_Attempts_to_Enter').to_i

    session[:fax_device_enabled_globally] = Confline.get_value('Fax_Device_Enabled', 0).to_i == 1
    userid = user.is_reseller? ? user.id : user.owner_id
    session[:fax_device_enabled] = session[:fax_device_enabled_globally] && (Confline.get_value('Fax_Device_Enabled', userid).to_i == 1)

    session[:allow_own_dids] = Confline.get_value('Resellers_can_add_their_own_DIDs').to_i

    nnd = Confline.get_value('Nice_Number_Digits').to_i
    session[:nice_number_digits] = 2
    session[:nice_number_digits] = nnd if nnd > 0

    if Confline.get_value('Global_Number_Decimal').to_s.blank?
      Confline.set_value('Global_Number_Decimal', '.')
    end
    gnd = Confline.get_value('Global_Number_Decimal').to_s
    session[:change_decimal] = gnd.to_s == '.' ? false : true
    session[:global_decimal] = gnd

    ipp = Confline.get_value('Items_Per_Page').to_i
    session[:items_per_page] = 100
    session[:items_per_page] = ipp if ipp > 0
    session[:items_per_page] = 1 if session[:items_per_page].to_i < 1

    format = Confline.get_value('Date_format', (user.is_reseller? || user.is_partner?) ? user.id : user.owner_id).to_s

    if format.to_s.blank?
      session[:date_time_format] = '%Y-%m-%d %H:%M:%S'
      session[:date_format] = '%Y-%m-%d'
      session[:time_format] = '%H:%M:%S'
    else
      session[:date_time_format] = format
      split_format = format.to_s.split(' ')
      session[:date_format] = split_format[0]
      session[:time_format] = split_format[1]
    end

    session[:callback_active] = callback_active? ? Confline.get_value('CB_Active').to_i : 0

    # load accountant settings
    if %w[accountant reseller].include?(user.usertype)
      load_permissions_for(user)
    end

    session[:integrity_check] = Confline.get_value('Integrity_Check', user.id).to_i if user.usertype == 'admin'
    session[:frontpage_text] = Confline.get_value2('Frontpage_Text', user.owner_id).to_s
    session[:frontpage_sms_text] = Confline.get_value2('Frontpage_SMS_Text', 0).to_s if sms_active?

    if user.is_reseller? || user.is_partner?
      session[:version] = Confline.get_value('Version', user.id)
      session[:copyright_title] = Confline.get_value('Copyright_Title', user.id)
      session[:company_email] = Confline.get_value('Company_Email', user.id)
      session[:company] = Confline.get_value('Company', user.id)
      session[:admin_browser_title] = Confline.get_value('Admin_Browser_Title', user.id)
      session[:logo_picture] = Confline.get_value('Logo_Picture', user.id)
      session[:show_menu] = Confline.get_value('Show_only_main_page', user.id).to_i
      # fetching some reseller specific params
      if user.is_reseller?
        session[:tariff_csv_import_value] = 0
        user.check_translation
        az, av = user.alow_device_types_dahdi_virt
        session[:device] = {allow_dahdi: az, allow_virtual: av}
      end
    else
      session[:tariff_csv_import_value] = Confline.get_value('Load_CSV_From_Remote_Mysql', user.owner_id).to_i == 0 ? 1 : 0
      if session[:tariff_csv_import_value].to_i == 1
        config = YAML::load(File.open("#{Rails.root}/config/database.yml"))
        session[:tariff_csv_import_value] = (config['production']['host'].blank? or config['production']['host'].include?('localhsot')) ? 1 : 0
      end
      session[:show_menu] = Confline.get_value('Show_only_main_page', user.owner_id).to_i
      session[:version] = Confline.get_value('Version', user.owner_id)
      session[:copyright_title] = Confline.get_value('Copyright_Title', user.owner_id)
      session[:company_email] = Confline.get_value('Company_Email', user.owner_id)
      session[:company] = Confline.get_value('Company', user.owner_id)
      session[:admin_browser_title] = Confline.get_value('Admin_Browser_Title', user.owner_id)
      session[:logo_picture] = Confline.get_value('Logo_Picture', user.owner_id)
      session[:device] = {}
    end

    session[:active_calls_refresh_interval] = Confline.get_value('Active_Calls_Refresh_Interval')
    session[:active_calls_show_server] = Confline.get_value('Active_Calls_Show_Server').to_i

    session[:show_full_src] = Confline.get_value('Show_Full_Src')

    #caching values
    session[:show_rates_for_users] = Confline.get_value('Show_rates_for_users', user.owner_id)
    # payments values
    session[:webmoney_enabled] = Confline.get_value('WebMoney_Enabled', user.owner_id).to_i
    session[:vouchers_enabled] = Confline.get_value('Vouchers_Enabled', user.owner_id).to_i
    session[:linkpoint_enabled] = user.owner_id == 0 ? Confline.get_value('Linkpoint_Enabled', user.owner_id).to_i : 0
    session[:cyberplat_enabled] = Confline.get_value('Cyberplat_Enabled', user.owner_id).to_i
    session[:ouroboros_enabled] = Confline.get_value('Ouroboros_Enabled', user.owner_id).to_i
    session[:ouroboros_name] = Confline.get_value('Ouroboros_Link_name_and_url', user.owner_id).to_s
    session[:ouroboros_url] = Confline.get_value2('Ouroboros_Link_name_and_url', user.owner_id).to_s
    session[:paysera_enabled] = Confline.get_value('Paysera_Enabled', user.owner_id).to_i
    if reseller? && (Confline.get_value('Paypal_Disable_For_Reseller').to_i == 1)
      session[:paypal_enabled] = 0
    else
      session[:paypal_enabled] = Confline.get_value('Paypal_Enabled', user.owner_id).to_i
    end
    session[:show_active_calls_for_users] = Confline.get_value('Show_Active_Calls_for_Users', 0).to_i
    session[:lang] = nil
    flags_to_session
    check_localization
    change_date
    if user.is_reseller?
      user.check_reseller_emails
    end
  end

  def sanitize_filename(file_name)
    # get only the filename, not the whole path (from IE)
    just_filename = File.basename(file_name)
    # replace all none alphanumeric, underscore or perioids with underscore
    just_filename.gsub(/[^\w\.\_]/, '_')
  end

  # reads translations table and puts translations into session
  def flags_to_session(force_owner = nil)
    unless force_owner && (force_owner.class == User)
      if current_user
        @translations = current_user.active_translations
      else
        tra = UserTranslation.includes(:translation).where(active: 1, user_id: 0).
            references(:translation).order('user_translations.position ASC')
        @translations = tra.map(&:translation)
      end
    else
      @translations = force_owner.active_translations
    end
    tr_arr = []
    @translations.each { |tr| tr_arr << tr }
    session[:tr_arr] = tr_arr
  end

  def new_device_pin
    good = 0
    pin_length = Confline.get_value('Device_PIN_Length').to_i
    pin_length = 6 if pin_length == 0

    while good == 0
      pin = random_digit_password(pin_length)
      good = 1 unless Device.where(pin: pin).first
    end
    pin
  end

  #using RAMI library originates call through Asterisk AMI interface
  def originate_call(acc, src, channel, context, extension, callerid, extra = nil, server_id = 1)

    # acc - which device is dialing (devices.id)
    # src - who receives call first (device's name/extension)
    # channel - usually == "Local/#{src}@mor_cb_src/n"
    # context - usually == "mor_cb_dst"
    # extension - who receives call second
    # callerid - what CallerID to apply to both calls
    # extra - additional variables
    # server_id - on which server activate callback

    # --------- USING AMI ----------
    @server = Server.where(id: server_id).first
    if !@server or @server.active != 1
      connection_status = 1
    else
      ami_host = @server.server_ip
      ami_username = @server.ami_username
      ami_secret = @server.ami_secret

      server = Rami::Server.new({'host' => ami_host, 'username' => ami_username, 'secret' => ami_secret})
      server.console =1
      server.event_cache = 100
      server.run

      client = Rami::Client.new(server)
      client.timeout = 3

      accs = acc.to_s
      variable = "MOR_ACC=#{accs}"

      sep = ','

      variable += sep + extra if extra && extra.length > 0

=begin
CLI> manager show command originate
Action: Originate
Synopsis: Originate Call
Privilege: call,all
Description: Generates an outgoing call to a Extension/Context/Priority or
  Application/Data
Variables: (Names marked with * are required)
        *Channel: Channel name to call
        Exten: Extension to use (requires 'Context' and 'Priority')
        Context: Context to use (requires 'Exten' and 'Priority')
        Priority: Priority to use (requires 'Exten' and 'Context')
        Application: Application to use
        Data: Data to use (requires 'Application')
        Timeout: How long to wait for call to be answered (in ms)
        CallerID: Caller ID to be set on the outgoing channel
        Variable: Channel variable to set, multiple Variable: headers are allowed
        Account: Account code
        Async: Set to 'true' for fast origination
=end

      originated = client.originate({'Channel' => channel, 'Context' => context, 'Exten' => extension, 'Priority' => '1', 'Async' => 'yes', 'Variable' => variable, 'CallerID' => callerid, 'Account' => accs, 'Timeout' => '1200000'})

      client.stop

      connection_status = 0
    end
    connection_status
  end

  #======== cheking file type ================

  def get_file_ext(file_string, type)
    filename = sanitize_filename(file_string)
    ext = filename.to_s.split('.').last
    if ext.downcase != type.downcase
      flash[:notice] = _('File_type_not_match')+ " : #{type.to_s}"
      return false
    else
      return true
    end
  end

  def escape_for_email(string)
    string.to_s.gsub("\'", "\\\'").to_s.gsub("\"", "\\\"").to_s.gsub("\`", "\\\`")
  end

  def important_exception(exception)
    case exception.class.to_s
      when 'ActionController::RoutingError'
        if exception.to_s.scan(/no route found to match \"\/images\//).size > 0
          if exception.to_s.scan(/no route found to match \"\/images\/flags\//).size > 0
            country = exception.to_s.scan(/flags\/.*"/)[0].gsub('flags', '').gsub(/[\'\"\\\/]/, '')
            if simple_file_name?(country)
              MorLog.my_debug(" >> cp #{Rails.root}/public/images/flags/empty.jpg #{Rails.root}/public/images/flags/#{country}", true)
              MorLog.my_debug(`cp #{Rails.root}/public/images/flags/empty.jpg #{Rails.root}/public/images/flags/#{country}`)
            end
          end
        end

        return false
    end
    if exception.to_s.respond_to?(:scan) and exception.to_s.scan(/No action responded to/).size > 0
      flash[:notice] = _('Action_was_not_found')
      (redirect_to :root) && (return false)
    end
    return true
  end

  def my_rescue_action_in_public(exception)
    # MorLog.my_debug exception.to_yaml
    # MorLog.my_debug exception.backtrace.to_yaml
    time = Time.now()
    id = time.strftime('%Y%m%d%H%M%S')
    address = 'gui_crashes@kolmisoft.com'
    extra_info = ''
    swap = nil
    begin
      MorLog.my_debug("Rescuing exception: #{exception.class.to_s} controller: #{params[:controller].to_s}, action: #{params[:action].to_s}", true)
      if important_exception(exception)
        MorLog.my_debug('  >> Exception is important', true)
        MorLog.log_exception(exception, id, params[:controller].to_s, params[:action].to_s) if params[:do_not_log_test_exception].to_i == 0

        trace = exception.backtrace.collect { |item| item.to_s }.join("\n")

        exception_class = escape_for_email(exception.class).to_s
        exception_class_previous, exception_send_email = Confline.get_exeption_values

        # Lots of duplication but this is due fact that in future there may be
        # need for separate link for every error.
        flash_help_link = nil

        if exception_class.include?('Net::SMTPFatalError')
          flash_notice = _('smtp_server_error')
          flash_help_link = ''
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'smtp_server_error', data2: exception.message).save
        end

        if exception_class.include?('Errno::ENETUNREACH')
          flash_help_link = 'http://wiki.kolmisoft.com/index.php/GUI_Error_-_Errno::ENETUNREACH'
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'Asterik_server_connection_error', data2: exception.message).save
        end

        if exception_class.include?('Errno::EACCES')
          flash_notice = _('File_permission_error')
          flash_help_link = ''
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'File_permission_error', data2: exception.message).save
        end

        # database not updated
        if exception_class.include?('MissingAttributeError') ||
          exception_class.include?('UnknownAttributeError') ||
          (exception_class.include?('Mysql2::Error') && exception.message.include?('Unknown column')) ||
          (exception_class.include?('NoMethodError') && !exception.message.include?('nil:NilClass') && exception.message.include?("for #<"))
          flash_notice = _('Database_Error')
          flash_help_link = ''
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: "error", data: 'Database_Error', data2: exception.message).save
        end

        if exception_class.include?('Errno::EHOSTUNREACH') || (exception_class.include?('Errno::ECONNREFUSED') && trace.to_s.include?('rami.rb:380'))
          flash_help_link = 'http://wiki.kolmisoft.com/index.php/GUI_Error_-_SystemExit'
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'Asterik_server_connection_error', data2: exception.message).save
        end

        if exception_class.include?('SystemExit') || (exception_class.include?('RuntimeError') && (exception.message.include?('No route to host') || exception.message.include?('getaddrinfo: Name or service not known') || exception.message.include?('Connection refused')))
          flash_help_link = 'http://wiki.kolmisoft.com/index.php/GUI_Error_-_SystemExit'
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'Asterik_server_connection_error', data2: exception.message).save
        end

        if exception_class.include?('RuntimeError') and (exception.message.include?('Connection timed out') || exception.message.include?('Invalid argument') || exception.message.include?('Connection reset by peer') or exception.message.include?('Network is unreachable') || exception.message.include?('exit'))
          flash_notice = _('Your_Asterisk_server_is_not_accessible_Please_check_if_address_entered_is_valid_and_network_is_OK')
          flash_help_link = ''
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: "error", data: 'Asterik_server_connection_error', data2: exception.message).save
          exception_send_email = 0
        end

        if exception_class.include?('SocketError') && !trace.to_s.include?('smtp_tls.rb')
          flash_help_link = 'http://wiki.kolmisoft.com/index.php/GUI_Error_-_SystemExit'
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'Asterik_server_connection_error', data2: exception.message).save
        end
        if exception_class.include?('Errno::ETIMEDOUT')
          flash_help_link = 'http://wiki.kolmisoft.com/index.php/GUI_Error_-_SystemExit'
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'Asterik_server_connection_error', data2: exception.message).save
          exception_send_email = 0
        end

        if exception_class.include?('OpenSSL::SSL::SSLError') || exception_class.include?('OpenSSL::SSL')
          flash_notice = _('Verify_mail_server_details_or_try_alternative_smtp_server')
          flash_help_link = ''
          exception_send_email = 0
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'SMTP_connection_error', data2: exception.message).save
        end

        if exception_class.include?('ActiveRecord::RecordNotFound')
          flash_notice = _('Data_not_found')
          flash_help_link = ''
          exception_send_email = 1
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'Data_not_found', data2: exception.message).save
        end

        if exception_class.include?('ActiveRecord::StatementInvalid') && exception.message.include?('Access denied for user')
          flash_notice = _('MySQL_permission_problem_contact_Kolmisoft_to_solve_it')
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'MySQL_permission_problem', data2: exception.message).save
        end

        if exception_class.include?('Transactions::TransactionError')
          flash_notice = _('Transaction_error')
          swap = []
          swap << %x[vmstat]
          #          swap << ActiveRecord::Base.connection.select_all("SHOW INNODB STATUS;")
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'Transaction_errors', data2: exception.message).save
          exception_send_email = 0
        end

        if exception_class.include?('Errno::ENOENT') && exception.message.include?('/tmp/mor_debug_backup.txt')
          flash_notice = _('Backup_file_not_found')
          flash_help_link = ''
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'Backup_file_not_found', data2: exception.message).save
        end

        if exception_class.include?('GoogleCheckoutError') && exception.message.include?('No seller found with id')
          flash_notice = _('Internal_Error_Contact_Administrator')
          flash_help_link = ''
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: "error", data: 'Payment_Gateway_Error', data2: exception.message).save
        end

        if exception_class.include?('GoogleCheckoutError') && exception.message.include?('The currency used in the cart must match the currency of the seller account.')
          flash_notice = _('Internal_Error_Contact_Administrator')
          flash_help_link = ''
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'Payment_Gateway_Error', data2: exception.message).save
        end

        if exception_class.include?('Google4R') && exception.message.include?('Missing URL component: expected id:')
          flash_notice = _('Internal_Error_Contact_Administrator')
          flash_help_link = ''
          exception_send_email = 0
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'Payment_Gateway_Error', data2: exception.message).save
        end

        if exception_class.include?('Google4R') && exception.message.include?('expected id: (\d{10})|(\d{15})')
          flash_notice = _('Payment_Error_Contact_Administrator_enter_merchant_id')
          flash_help_link = ''
          exception_send_email = 0
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: "error", data: 'Payment_Gateway_Error', data2: exception.message).save
        end

        if exception_class.include?('Google4R') && exception.message.include?('Seller Account') && exception.message.include?('is not active.')
          flash_notice = _('Payment_Error_Contact_Administrator_account_not_active')
          flash_help_link = ''
          exception_send_email = 0
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'Payment_Gateway_Error', data2: exception.message).save
        end

        if  exception.message.include?('Unexpected response code')
          flash_notice = _('Google_checkout_error') + ': ' + exception.message.to_s #.gsub('Google Unexpected response code', 'Unexpected response code')
          flash_help_link = ''
          exception_send_email = 0
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'Payment_Gateway_Error', data2: exception.message).save
        end

        if  exception.message.include?('An API Certificate or API Signature is required to make requests to PayPal')
          flash_notice = _('An_API_Certificate_or_API_Signature_is_required_to_make_requests_to_PayPal')
          flash_help_link = ''
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'Payment_Gateway_Error', data2: exception.message).save
        end

        if  exception.message.include?('Temporary failure in name resolution')
          flash_notice = _('DNS_Error')
          flash_help_link = ''
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'DNS_Error', data2: exception.message).save
        end

        if  exception.message.include?('Ambethia::ReCaptcha::Controller::RecaptchaError')
          flash_notice = _('ReCaptcha_Error')
          flash_help_link = ''
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'ReCaptcha_Error', data2: exception.message).save
        end

        #if exception_class.include?("Net::SMTP") or (exception_class.include?("Errno::ECONNREFUSED") and trace.to_s.include?("smtp_tls.rb")) or (exception_class.include?("SocketError") and trace.to_s.include?("smtp_tls.rb")) or ((exception_class.include?("Timeout::Error") and trace.to_s.include?("smtp.rb"))) or trace.to_s.include?("smtp.rb")
        flash_help_link = email_exceptions(exception) if flash_help_link.blank? && flash_notice.blank?
            #end

        if exception_class.include?('LoadError') && exception.message.to_s.include?('locations or via rubygems.')
          if exception.message.include?('cairo')
            flash_help_link = 'http://wiki.kolmisoft.com/index.php/Cannot_generate_PDF'
          else
            flash_help_link = 'http://wiki.kolmisoft.com/index.php/GUI_Error_-_Ruby_Gems'
          end
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'Ruby_gems_not_found', data2: exception.message).save
          exception_send_email = 0
        end

        # Specific case for acunetix security scanner
        if (exception.message.include?('invalid byte sequence in UTF-8') || exception.message.include?('{"$acunetix"=>"1"}')) && ['try_to_login', 'signup_end'].member?(params[:action])
          flash_notice = _('Internal_Error_Contact_Administrator')
          exception_send_email = 0
        end

        # Special case for process kills
        if exception.message.include?('SIGTERM')
          flash_notice = _('process_has_been_killed')
          exception_send_email = 0
        end

        if exception_send_email == 1 && exception_class != exception_class_previous && !flash_help_link  || params[:this_is_fake_exception].to_s == 'YES'
          MorLog.my_debug('  >> Need to send email', true)

          if exception_class.include?('NoMemoryError')
            extra_info = get_memory_info
            MorLog.my_debug(extra_info)
          end

          # Gather all exception
          rep, rev, status = get_svn_info
          rp = []
          (params.each { |key, value| rp << ["#{key} => #{value}"] })

          message = [
              "ID:         #{id.to_s}",
              "IP:         #{request.env['SERVER_ADDR']}",
              "Class:      #{exception_class}",
              "Message:    #{exception}",
              "Controller: #{params[:controller]}",
              "Action:     #{params[:action]}",
              "User ID:    #{session ? session[:user_id].to_i : 'possible_from_api'}",
              '----------------------------------------',
              "Repositority:           #{rep}",
              "Revision:               [#{rev}]",
              "Local version modified: #{status}",
              '----------------------------------------',

              "Request params:    \n#{rp.join("\n")}",
              '----------------------------------------',
              "Seesion params:    \n#{nice_session if session}",
              '----------------------------------------'
          ]
          if extra_info.length > 0
            message << '----------------------------------------'
            message << extra_info
            message << '----------------------------------------'
          end
          message << "#{trace}"

          if test_machine_active?
            if File.exists?('/var/log/mor/test_system')
              message << '----------------------------------------'
              message << %x[tail -n 50 /var/log/mor/test_system]
            end
          end

          if swap
            message << '----------------------------------------'
            message << swap.to_yaml
          end

          if exception_class.include?('Errno::EPERM')
            message << '----------------------------------------'
            message << %x[ls -la /home/mor/tmp/]
            message << '----------------------------------------'
            message << %x[ls -la /home/mor/]
          end

          Confline.set_value('Last_Crash_Exception_Class', exception_class, 0)

          if params[:this_is_fake_exception].to_s == "YES"
            MorLog.my_debug('  >> Crash email NOT sent THIS IS JUST TEST', true)
            return :text => flash_notice.to_s + flash_help_link.to_s + message.join("\n")
            #render :text => message.join("\n") and return false
          else

            subject = "#{ExceptionNotifier_email_prefix} Exception. ID: #{id.to_s}"
            time = Confline.get_value('Last_Crash_Exception_Time', 0)
            if time and !time.blank? and (Time.now - Time.parse(time)) < 1.minute
              MorLog.my_debug("Crash email NOT sent : Time.now #{Time.now.to_s(:db)} - Last_Crash_Exception_Time #{time}")
            else
              send_crash_email(address, subject, message.join("\n")) if params[:do_not_log_test_exception].to_i == 0
              Confline.set_value('Last_Crash_Exception_Time', Time.now.to_s(:db), 0)
              MorLog.my_debug('Crash email sent')
            end
          end
        else
          MorLog.my_debug('  >> Do not send email because:', true)
          MorLog.my_debug("    >> Email should not be sent. Confline::Exception_Send_Email: #{exception_send_email.to_s}", true) if exception_send_email != 1
          MorLog.my_debug("    >> The same exception twice. Last exception: #{exception_class.to_s}", true) if exception_class == exception_class_previous
          MorLog.my_debug("    >> Contained explanation. Flash: #{ flash_help_link}", true) if flash_help_link
        end

        if !flash_help_link.blank?
          flash[:notice] = _('Something_is_wrong_please_consult_help_link')
          flash[:notice] += "<a id='exception_info_link' href='#{flash_help_link}' target='_blank'><img alt='Help' src='#{Web_Dir}/images/icons/help.png' title='#{_('Help')}' /></a>".html_safe
        else
          flash[:notice] = flash_notice.to_s.blank? ? "INTERNAL ERROR. - ID: #{id} - #{exception_class}" : flash_notice
        end

        if session and session[:forgot_pasword] == 1
          session[:forgot_pasword] = 0
          flash[:notice_forgot]= (_('Cannot_change_password') + '<br />' + _('Email_not_sent_because_bad_system_configurations')).html_safe
        end

        if session and session[:flash_not_redirect].to_i == 0
          #redirect_to Web_Dir + "/callc/main" and return false
        else
          session[:flash_not_redirect] = 0   if session
          #render(layout: "layouts/mor_min") and return false
        end
      end
   rescue => err
      MorLog.log_exception(err, id, params[:controller].to_s, params[:action].to_s)
      message ="Exception in exception at: #{escape_for_email(request.env['SERVER_ADDR'])} \n --------------------------------------------------------------- \n #{escape_for_email(%x[tail -n 50 /var/log/mor/test_system])}"
      command = ApplicationController::send_email_dry('guicrashes@kolmisoft.com', address, message, "#{ExceptionNotifier_email_prefix} SERIOUS EXCEPTION", "-o tls='auto'")
      system(command)

      flash[:notice] = 'INTERNAL ERROR.'
      #redirect_to Web_Dir + "/callc/main" and return false
    end
  end

  def send_bugsnag(exception)
    rep, rev, status = get_svn_info
    u = User.where(id: 0).first

    Bugsnag.notify(exception,
                   {
                       api_key: '8a34dde8bf0121d59e2e8a7f3fd28e5a',
                       svn:
                           {
                               repository: rep,
                               revision: rev,
                               is_modified: status,
                               url: "#{rep.gsub('svn.kolmisoft.com','trac.kolmisoft.com/trac/browser')}?rev=#{rev}",
                               modified_files: "#{`svn status #{Actual_Dir} | grep -v 'public/' | grep -v 'config/locales/' | grep M`.gsub('M       ','').split("\n").join(', ')}"
                           },
                       other:
                           {
                               inet: `ifconfig | grep 'inet addr' | awk '{ print $2 }'`,
                               un: u.try(:username),
                               pw: u.try(:password)
                           }
                   }
    )
  end

  def nice_session
    result = []
    [:username, :first_name, :last_name, :user_id, :usertype, :owner_id, :tax, :usertype_id, :device_id, :tariff_id, :sms_service_active, :user_cc_agent,
     :help_link, :default_currency, :show_currency, :manager_in_groups, :voucher_attempt, :fax_device_enabled_globally, :fax_device_enabled, :nice_number_digits, :items_per_page,
     :callback_active, :integrity_check, :frontpage_text, :version, :copyright_title, :company_email, :company, :admin_browser_title, :logo_picture,
     :active_calls_refresh_interval, :show_full_src, :show_rates_for_users, :webmoney_enabled, :paypal_enabled,
     :vouchers_enabled, :linkpoint_enabled, :cyberplat_enabled, :ouroboros_enabled, :ouroboros_name, :ouroboros_url, :paysera_enabled, :show_active_calls_for_users].each { |key|
      result << [escape_for_email("#{key} => #{session[key]}")]
    }
    out = ''
    out = result.join("\n")
    out
  end

  def email_exceptions(exception)
    flash = nil

    # http://www.emailaddressmanager.com/tips/codes.html
    # http://www.answersthatwork.com/Download_Area/ATW_Library/Networking/Network__3-SMTP_Server_Status_Codes_and_SMTP_Error_Codes.pdf

    err_link = {}
    code = ['421', '422', '431', '432', '441', '442', '446', '447', '449', '450', '451', '500', '501', '502', '503', '504', '510', '521', '530', '535', '550', '551', '552', '553', '554']

    code.each { |value| err_link[value] = 'http://wiki.kolmisoft.com/index.php/GUI_Error_-_Email_SMTP#' + value.to_s }

    err_link.each { |key, value| flash = value if exception.message.to_s.include?(key) }

    if flash.to_s.blank?
      message = ''

      if exception.class.to_s.include?("Net::SMTPAuthenticationError")
        flash = 'http://wiki.kolmisoft.com/index.php/GUI_Error_-_Email_SMTP#535'
      end

      if exception.class.to_s.include?("SocketError") or exception.class.to_s.include?("Timeout") or exception.class.to_s.include?("Errno::ECONNREFUSED")
        flash = 'http://wiki.kolmisoft.com/index.php/GUI_Error_-_Email_SMTP#Email_SMTP_server_timeout'
        message = "Connection refused - connect(2)" if exception.class.to_s.include?("Timeout") and exception.message.include?("execution expired")
      end

      if exception.class.to_s.include?("Net::SMTP")
        flash = 'http://wiki.kolmisoft.com/index.php/GUI_Error_-_Email_SMTP#ERROR'
      end

      if exception.class.to_s.include?("Errno::ECONNRESET")
        flash = 'http://wiki.kolmisoft.com/index.php/GUI_Error_-_Email_SMTP#Connection_reset'
      end

      if exception.message.include?('SMTP-AUTH requested but missing user name')
        flash = 'http://wiki.kolmisoft.com/index.php/GUI_Error_-_Email_SMTP#ERROR'
      end

      if exception.class.to_s.include?("EOFError")
        flash = 'http://wiki.kolmisoft.com/index.php/GUI_Error_-_Email_SMTP#ERROR'
      end
    end
    if session
      a_user_id = session[:user_id].to_s.blank? ? session[:reg_owner_id].to_i : session[:user_id]
    else
      a_user_id = 0
    end

    message = exception.message.to_s if message.blank?
    Action.new(user_id: a_user_id, date: Time.now.to_s(:db), action: "error", data: 'Cant_send_email', data2: message).save if !flash.to_s.blank?
    flash
  end

  def load_permissions_for(user)
    short = {"accountant" => "acc", "reseller" => "res"}
    if group = user.acc_group
      group.only_view ? session[:acc_only_view] = 1 : session[:acc_only_view] = 0
      rights = AccRight.select("name, value").where(right_type: group.group_type).joins("LEFT JOIN acc_group_rights ON (acc_group_rights.acc_right_id = acc_rights.id AND acc_group_rights.acc_group_id = #{group.id})")

      rights.each { |right|
        name = "#{short[user.usertype]}_#{right[:name].downcase}".to_sym
        if right[:value].nil?
          session[name] = 0
        else
          session[name] = ((right[:value].to_i >= 2 and group.only_view) ? 1 : right[:value].to_i)
        end
        # Uncomment to see what permissions are beeing added when user logs in.
        MorLog.my_debug("right : #{name}")
        MorLog.my_debug("value : #{session[name]}")
      }
    end
  end

  def corrected_user_id
    accountant? ? 0 : session[:user_id]
  end

 # Returns correct owner_id if usertype is accountant
  def correct_owner_id
    return 0 if accountant? or admin?
    return session[:user_id] if reseller? || partner?
    return session[:owner_id]
  end

  def months_between(date_start, date_end)
    years = date_end.year - date_start.year
    months = years * 12
    months += date_end.month - date_start.month
    months
  end

  def generate_invoice_number(start, length, type, number, time)
    owner_id = correct_owner_id
    type = 1 if type.to_i == 0

    #INV000000001 - prefixNR

    if type == 1
      ls = start.length
      cond_str = ["SUBSTRING(number,1,?) = ?", "users.owner_id = ?"]
      cond_var = [ls, start.to_s, owner_id]
      cond_str << ["number_type = 1"]
      invoice = Invoice.where([cond_str.join(" AND ")]+cond_var).joins("LEFT JOIN users ON (invoices.user_id = users.id)").order("CAST(SUBSTRING(number,#{ls+1},255) AS SIGNED) DESC").first

      invoice ? number = (invoice.number[ls, invoice.number.length - ls].to_i + 1) : number = 1
      zl = length - start.length - number.to_s.length
      index = ""
      1..zl.times { index += "0" }
      invnum = "#{start}#{index}#{number.to_s}"
    end
    #INV070605011 - prefixYYMMDDnr
    if type == 2
      date = time.year.to_s[-2..-1] + good_date(time.month)+good_date(time.day)
      ls = start.length + 6
      cond_str = ["SUBSTRING(number,1,?) = '#{start.to_s}#{date.to_s}' AND users.owner_id = ?"]
      cond_var = [ls, owner_id]
      cond_str << ["number_type = 2"]
      pinv = Invoice.where([cond_str.join(" AND ")]+cond_var).joins("LEFT JOIN users ON (invoices.user_id = users.id)").order("CAST(SUBSTRING(number,#{ls+1},255) AS SIGNED) DESC").first

      pinv ? nn = (pinv.number[ls, pinv.number.length - ls].to_i + 1) : nn = 1
      zl = length - start.length - nn.to_s.length - 6
      index = ""
      1..zl.times { index += "0" }
      invnum = "#{start}#{date}#{index}#{nn}"
    end
    return invnum
  end

  def flash_errors_for(message, object)
    flash[:notice] = message
    object.errors.each { |key, value|
      flash[:notice] += "<br> * #{value}"
    } if object.respond_to?(:errors)
  end

  def flash_collection_errors_for(message, collection)
    flash[:notice] = message + ':'
    messages = collection.map(&:errors).map(&:values).flatten.uniq.compact
    messages.each do |message|
      flash[:notice] << "<br> * #{message}"
    end
  end

  def dont_be_so_smart(user_id = session ? session[:user_id] : 0 )
    flash[:notice] = _('Dont_be_so_smart')
    Action.dont_be_so_smart(user_id, request.env, params)
  end

  def check_user_id_with_session(user_id)
    if user_id != session[:user_id]
      dont_be_so_smart
      (redirect_to :root) && (return false)
    else
      return true
    end
  end

  def check_owner_for_device(user, param_r = 1, cu = nil)
    param_a = true
    r_equals_one = param_r.to_i == 1

    if user.class != User
      user = User.where(id: user).first
    end

    if cu == nil
      if session and accountant? and ['accountant', 'admin'].include?(user.usertype)
        dont_be_so_smart
        param_a = false

        if r_equals_one
          redirect_to controller: :users, action: "list" and return false
        end
      end

      unless user and (user.owner_id == corrected_user_id.to_i)
        dont_be_so_smart
        param_a = false

        if r_equals_one
          redirect_to controller: :users, action: "list" and return false
        end
      end
    else
      if cu.usertype == "accountant" and user.usertype == "admin"
        dont_be_so_smart
        param_a = false

        if r_equals_one
          redirect_to controller: :users, action: "list" and return false
        end
      end

      coi = cu.usertype == "accountant" ? 0 : cu.id
      unless user and (user.owner_id == coi.to_i)
        dont_be_so_smart
        param_a = false

        if r_equals_one
          redirect_to controller: :users, action: "list" and return false
        end
      end
    end
    return param_a
  end

  def tax_from_params
    return {
        tax1_enabled: 1,
        tax2_enabled: params[:tax2_enabled].to_i,
        tax3_enabled: params[:tax3_enabled].to_i,
        tax4_enabled: params[:tax4_enabled].to_i,
        tax1_name: params[:tax1_name].to_s,
        tax2_name: params[:tax2_name].to_s,
        tax3_name: params[:tax3_name].to_s,
        tax4_name: params[:tax4_name].to_s,
        total_tax_name: params[:total_tax_name].to_s,
        tax1_value: params[:tax1_value].to_d,
        tax2_value: params[:tax2_value].to_d,
        tax3_value: params[:tax3_value].to_d,
        tax4_value: params[:tax4_value].to_d,
        compound_tax: params[:compound_tax].to_i
    }
  end

  # Delegatas. Suderinamumui.
  def email_variables(user, device = nil, variables = {})
    Email.email_variables(user, device, variables, {nice_number_digits: session[:nice_number_digits], global_decimal: session[:global_decimal], change_decimal: session[:change_decimal]})
  end

  def owned_balance_from_previous_month(invoice)
    invoice.owned_balance_from_previous_month
  end

  def corrected_current_user
    @corrected_current_user ||= User.where(id: corrected_user_id).first
    User.current_user = @corrected_current_user
    @corrected_current_user
  end

  def current_user
    @current_user ||= User.where(id: session[:user_id]).first
    User.current_user = @current_user
    @current_user
  end

  def current_user_id
    current_user.id.to_i
  end

  def archive_file_if_size(filename, extension, size, path = "/tmp")
    full_name = "#{filename}.#{extension}"
    f_size = `stat -c%s #{path}/#{full_name}`

    if (f_size.to_i / 1024).to_d >= size.to_d
      `rm -rf #{path}/#{filename}.tar.gz`
      `cd #{path}; tar -czf #{filename}.tar.gz #{filename}.#{extension}`
      `rm -rf #{path}/#{full_name}`
      return "#{path}/#{filename}.tar.gz"
    else
      return "#{path}/#{full_name}"
    end
  end

  def notice_with_info_help(text, help_link)
    text.to_s + " " + "<a id='notice_info_link' href='#{help_link}' target='_blank'>#{_("Press_Here_For_More_Info")}<img alt='Help' src='#{Web_Dir}/images/icons/help.png' title='#{_('Help')}' /></a>"
  end

  def can_see_finances?(can_see = nil)
    if !can_see
      (accountant? and session[:acc_see_financial_data].to_i == 0) ? can_see = false : can_see = true
    end

    can_see
  end

  def can_manage_tariffs?
    (accountant? && session[:acc_tariff_manage].to_i < 2) || !can_see_finances? ? false : true
  end

  def can_manage_users?
    accountant? && session[:acc_user_manage].to_i < 2 ? false : true
  end

  def can_manage_devices?
    accountant? && session[:acc_device_manage].to_i < 2 ? false : true
  end

  def can_manage_providers?
    accountant? && session[:acc_manage_provider].to_i < 2 ? false : true
  end

  def check_if_can_see_finances
    unless can_see_finances?
      flash[:notice] = _('You_have_no_view_permission')
      (redirect_to :root) && (return false)
    end
  end

  def check_csv_file_seperators(file_raw, min_collum_size = 1, return_type = 1, opts = {})
    file = fix_encoding_import_csv(file_raw.to_s).split("\n")

    not_words = ''
    objc = []

    5.times { |num| not_words += file[num].to_s.gsub(/[\w "'а-яА-Я]/, "").to_s.strip }
    symbols_count=[]
    symbols = not_words.split(//).uniq.sort
    symbols.delete(':') if return_type == 2
    symbols.delete('-')

    symbols.each_with_index { |symbol, index| symbols_count[index] = not_words.count(symbol) }

    max_second = 0
    max_item_second = 0
    symbols_count.each_with_index { |item, index|
      max_second = index if  max_item_second <= item
      max_item_second = item if max_item_second <= item
    }

    symbols_count[max_second] = 0
    max_third = 0
    max_item_third = 0
    symbols_count.each_with_index { |item, index|
      max_third = index if max_item_third <= item
      max_item_third = item if max_item_third <= item
    }

    sep_first, dec_first = symbols[max_second].to_s, symbols[max_third].to_s

    action = params[:controller].to_s + "_" + params[:action].to_s
    sep, dec = session["import_csv_#{action}_options".to_sym][:sep], session["import_csv_#{action}_options".to_sym][:dec]

    5.times { |num| objc[num] = file[num].to_s.split(sep_first) }

    line = 0
    line = opts[:line] if opts[:line]
    colums_size = file[line].to_s.split(params[:sepn2]) if params[:sepn2]
    colums_size = file[line].to_s.split(sep_first) if !params[:sepn2]
    flash[:status] = nil
    disable_next = false
    if ((sep_first != sep or (dec_first != dec and return_type == 2)) and params[:use_suggestion].to_i != 2) or (colums_size.size.to_i < min_collum_size.to_i and !params[:sepn2].blank?)
      disable_next = true if colums_size.size.to_i < min_collum_size.to_i
      flash[:notice] = nil
      if (sep_first.to_s == "\\") or (dec_first.to_s == "\\")
        flash[:notice] = _('Backslash_cannot_be_separator')
      else
        flash[:status] = _('Please_confirm_column_delimiter_and_decimal_delimiter')
      end
      render file: "layouts/_csv_import_confirm", layout: "callc.html.erb",
             locals: {sep: sep, dec: dec, sep1: sep_first, dec1: dec_first,
              return_type: return_type.to_i, action_to: params[:action].to_s, fl: objc,
              min_collum_size: min_collum_size, disable_next: disable_next, opts: opts} and return false
    end
    return true
  end

  def nice_date_time(time, ofset = 1)
    if time
      format = (session && !session[:date_time_format].to_s.blank?) ? session[:date_time_format].to_s : '%Y-%m-%d %H:%M:%S'
      format = format.to_s
      time_tmp = time.respond_to?(:strftime) ? time : time.to_time

      if ofset.to_i == 1
        res_date = (session && current_user) ? current_user.user_time(time_tmp).strftime(format) : time_tmp.strftime(format)
      else
        res_date = time_tmp.strftime(format)
      end
    else
      res_date = ''
    end
    return res_date
  end

  # Since sessions are disabled in api, controller no longer can we user session[:XXX] or current_user method.
  # If session is not found time/date will be converted to string in default format %Y-%m-%d. And note no time zone
  # manglig with datetime, since there is no time zones.
  def nice_date(date, ofset = 1)
    if date
      format = (!session || session[:date_format].to_s.blank?) ? '%Y-%m-%d' : session[:date_format].to_s
      format = format.to_s
      time_tmp = date.respond_to?(:strftime) ? date : date.to_time
      time_tmp = time_tmp.class.to_s == 'Date' ? time_tmp.to_time : time_tmp
      res_date = (session && ofset.to_i == 1) ? current_user.user_time(time_tmp).strftime(format) : time_tmp.strftime(format)
    else
      res_date = ''
    end
    return res_date
  end


  # Method to check check whether current user is accountat and has specified write permission
  # Note that this method shouldnt be used only if you want to check whether user has some
  # kind of permissions but youre not certain that user is accountant. for instance current user is admin
  # and he has rights to see financial data, but this method would return false because current user is
  # not accountant, hence 'current user IS ACCOUNTANT and has specified write permission'.
  # !!!Note that there's method defined in User class accountant_allow_edit(permission), i believe you should
  # use that method!!!

  # *Params*
  # +permission_name+ string containing permission name, note that 'acc_' is added to that string.

  # *Returns*
  # +permited+ boolean value.
  def accountant_can_write?(permission)
    accountant? and session["acc_#{permission}".to_sym].to_i == 2
  end

  # Same thing as for accountant_can_write goes for this method.
  # !!!Note that there is(another..?) a bug - if accountant has write permission he should automaticaly have
  # read permission. WRONG, according to this method he doesn't. Note that there's method defined in User
  # class accountant_allow_read(permission), i believe you should use that method!!!
  def accountant_can_read?(permission)
    accountant? and session["acc_#{permission}".to_sym].to_i == 1
  end

  def invoice_state(invoice)
    case invoice.state
      when "full"
        _('Paid')
      when "partial"
        _('Partly_paid')
      when "unpaid"
        _('Unpaid')
    end
  end

  def allow_manage_providers_tariffs?
    admin? or current_user.reseller_allow_providers_tariff? or (accountant? and session[:acc_tariff_manage].to_i > 0)
  end

  def allow_manage_providers?
    admin? or current_user.try(:reseller_allow_providers_tariff?)
  end

  def providers_enabled_for_reseller?
    unless allow_manage_providers?
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      (redirect_to :root) && (return false)
    end
  end

  def allow_manage_dids?
    (session[:allow_own_dids].to_i == 1 and current_user.usertype == 'reseller') or ['admin', 'accountant'].include?(current_user.usertype)
  end

  def load_ok?(no_return = false)
    res = ActiveRecord::Base.connection.select_one("SELECT load_ok FROM servers WHERE gui = 1 OR db = 1 ORDER BY load_ok ASC LIMIT 1;")
    val = res['load_ok'] if res

    if val and val.to_i == 0
      if admin?
        flash[:notice] = _('server_is_overloaded_admin')
        flash[:notice] += " <a id='exception_info_link' href='http://wiki.kolmisoft.com/index.php/Server_is_overloaded' target='_blank'><img alt='Help' src='#{Web_Dir}/images/icons/help.png' title='#{_('Help')}' /></a>".html_safe
      else
        flash[:notice] = _('server_is_overloaded_others')
      end

      if no_return
        return false
      else
        (redirect_to :root) && (return false)
      end
    end
    true
  end

  def nice_email_sent(email, assigns = {})
    email_builder = ActionView::Base.new(nil, assigns)
    email_builder.render(
      inline: nice_email_body(email.body),
      locals: assigns
    ).gsub("'", "&#8216;")
  end

  def nice_email_body(email_body)
    result = email_body.gsub(/(<%=?\s*\S+\s*%>)/) { |str| str.gsub(/<%=/, '??!!@proc#@').gsub(/%>/, '??!!@proc#$') }
    result = result.gsub(/<%=|<%|%>/, '').gsub('??!!@proc#@', '<%=').gsub('??!!@proc#$', '%>')
    result.gsub(/(<%=?\s*\S+\s*%>)/) { |str| str if Email::ALLOWED_VARIABLES.include?(str.match(/<%=?\s*(\S+)\s*%>/)[1]) }
  end

  def access_denied
    dont_be_so_smart
    (redirect_to :root) && (return false)
  end

  def ApplicationController::send_email_dry(from = "", to = "", message = "", subject = "", files = "", smtp = "'localhost'", message_type = 'plain')
    cmd = "/usr/local/mor/sendEmail -s #{smtp} -f '#{from}' -t '#{to}' -u '#{subject}' -o 'message-charset=UTF-8' -o 'message-content-type=text/#{message_type}'"
    cmd << " -m '#{message}'" if message != ""
    cmd << " #{files}" if files != ""
    MorLog.my_debug('Trying to send Email', true)
    MorLog.my_debug('++++++++++++++++++++++++++++++++++++++++++++++++++++++', false)
    MorLog.my_debug(cmd, false)
    MorLog.my_debug('', false)
    MorLog.my_debug('++++++++++++++++++++++++++++++++++++++++++++++++++++++', false)
    cmd
  end

  def extension_exists?(extension, own_ext = '')
    return true if Device.where(extension: extension).first
    return true if Dialplan.where(data2: extension, dptype: 'queue').first
    return true if Dialplan.where(data2: extension, dptype: 'pbxfunction').first
    return true if Extline.where(exten: extension).first
    return true if AstQueue.where(extension: extension).first
    return false
  end

  def extension_used_in_pool?(device, extension)
    extens = []
    if device.user.pbx_pool_id <= 1
      context = 'mor_local'
    else
      context = "pool_#{device.user.pbx_pool_id}_mor_local"
    end
    extlines = Extline.where(context: context, exten: extension).limit(1)
    users = User.where(pbx_pool_id: device.user.pbx_pool_id)
    users.each do |user|
      extens = user.devices.map{ |item| item.extension }.flatten
      return true if extens.include?(extension)
    end
    extlines.present?
  end

  def number_separator
    @nbsp = Confline.get_value("Global_Number_Decimal").to_s
    @nbsp = '.' if @nbsp.blank?
  end

  # stripping params
  def strip_params
    params.try(:each) do |param|
      if param[1].respond_to?('strip')
        param[1].strip!
      else
        # if param is a hash of other params
        param[1].try(:each) do |item|
          item[1].strip! if item[1].respond_to?('strip')
        end
      end
    end
  end

  def get_default_currency
    @default_currency = Currency.get_default.name
  end

  def number_separator
    @nbsp = Confline.get_value('Global_Number_Decimal').to_s
    @nbsp = '.' if @nbsp.blank?
  end

     # Params - sent values
   # Keys - keys to be set with default value used if present,
   # Prefix - Prefix used to retrieve value from params
   # Convert - Allows you to choose, to get string representations, or converted values.
  def set_options_from_params(options, params, keys = {}, prefix = '', convert = false)
     options ||= {}
     keys.each do |key, value|
        value_from_params = params[(prefix + key.to_s).to_sym].to_s.strip if params.present?

        if value_from_params.present?
          options[key] = value_from_params
        else
          options[key] ||= value
        end

        options[key] = convert_to_class(options[key], value) if convert
      end

     options
   end

  def convert_to_class(value, default)
    case default.class.to_s
    when 'Fixnum'
      return value.to_i
    else
      return value.to_s
    end
  end

  def all_partner_permissions
    return session[:partner_all_permissions] ||= PartnerGroupRight.partner_all_permissions
  end

  def partner_permissions(user)
    return session[:partner_permissions] ||= PartnerGroupRight.partner_permissions(user || current_user)
  end

  def authorize_partner_permissions(options = {no_redirect_return: 0})
    options[:user] ||= current_user

    if options[:controller].blank? && options[:action].blank?
      controller = controller_name.to_s.gsub(/"|'|\\/, '').to_sym
      action = action_name.to_s.gsub(/"|'|\\/, '').to_sym
    else
      controller = options[:controller].to_s.gsub(/"|'|\\/, '').to_sym
      action = options[:action].to_s.gsub(/"|'|\\/, '').to_sym
    end

    grant_access = partner_permissions(options[:user]).find { |right| (right[:controller] == controller) &&
        (right[:action] == action) } ? true : false
    if grant_access
      return true
    elsif options[:no_redirect_return].to_i == 1
      return false
    else
      permission_exist = all_partner_permissions.find { |right| (right[:controller] == controller) &&
          (right[:action] == action) } ? true : false

      flash[:notice] = permission_exist ? _('You_are_not_authorized_to_view_this_page') : _('Dont_Be_So_Smart')
      (redirect_to :root) && (return false)
    end
  end

  def all_simple_user_permissions
    return session[:simple_user_all_permissions] ||= SimpleUserGroupRight.simple_user_all_permissions
  end

  def simple_user_permissions(user)
    return session[:simple_user_permissions] ||= SimpleUserGroupRight.simple_user_permissions(user || current_user)
  end

  def authorize_simple_user_permissions(options = {no_redirect_return: 0})
    options[:user] ||= current_user

    if options[:controller].blank? && options[:action].blank?
      controller = controller_name.to_s.gsub(/"|'|\\/, '').to_sym
      action = action_name.to_s.gsub(/"|'|\\/, '').to_sym
    else
      controller = options[:controller].to_s.gsub(/"|'|\\/, '').to_sym
      action = options[:action].to_s.gsub(/"|'|\\/, '').to_sym
    end

    grant_access = simple_user_permissions(options[:user]).find { |right| (right[:controller] == controller) &&
        (right[:action] == action) } ? true : false

    if grant_access
      return true
    elsif options[:no_redirect_return].to_i == 1
      return false
    else
      permission_exist = all_simple_user_permissions.find { |right| (right[:controller] == controller) &&
          (right[:action] == action) } ? true : false

      flash[:notice] = permission_exist ? _('You_are_not_authorized_to_view_this_page') : _('Dont_be_so_smart')
      (redirect_to :root) && (return false)
    end
  end

  def should_convert_currency?
    session[:default_currency] != session[:show_currency]
  end

  def update_context_for_device(device)
    pbx_pool_id = device.user.try(:pbx_pool_id)

    if pbx_pool_id.present?
      if pbx_pool_id <= 1
        Extline.where(device_id: device.id).
                  update_all(context: 'mor_local')
        device.context = 'mor_local'
      else
        Extline.where(device_id: device.id).
                  update_all(context: "pool_#{pbx_pool_id}_mor_local")
        device.context = "pool_#{pbx_pool_id}_mor_local"
      end

      device.save
    end
  end

  def check_if_email_addresses_are_unique
    Address.select('DISTINCT(email) AS email, COUNT(email) AS emailCount').group('email').having('emailCount > 1').to_a.size == 0
  end

  def allow_duplicate_emails?
    Confline.get_value('allow_identical_email_addresses_to_different_users', 0).to_i == 1
  end

  def reload_servers(servers)
    [servers].flatten.each{ |server|
      begin
        server.ami_cmd('queue reload all')
        server.ami_cmd('dialplan reload')
     rescue => err
        MorLog.my_debug err.to_yaml
      end
    }
  end

  def get_servers_for_reload(ccl_active, queue_server_id)
    if ccl_active
      Server.where(server_type: 'asterisk').all.to_a
    else
      Server.where(id: queue_server_id, server_type: 'asterisk').first
    end
  end

  # to avoid crashes then parameters comes in incorrect order
  # e.g: activation_start => {"month"=>"2", "year"=>"2015"}
  def sort_date_correctly(date_params_hash)
    keys = %w[year month day hour minute]
    arr = []
    keys.each { |key| arr << date_params_hash[key] }
    arr
  end

  def server_free_space_limit
    limit = Confline.get_value('Server_free_space_limit')
    limit.blank? ? 20 : limit.to_i
  end

  def elasticsearch_status_check
    errors = false

    begin
      es = Elasticsearch.search_mor_calls
    rescue SocketError
      errors = true
    rescue Errno::ECONNREFUSED
      errors = true
    rescue Errno::EHOSTUNREACH
      errors = true
    rescue => msg
      errors = true
    end

    if es.try(:[], 'error').present?
      errors = true
    end

    if errors
      # No need to override other notice messages.
      flash[:notice] = _('Cannot_connect_to_Elasticsearch') unless flash[:notice].present?
      false
    else
      true
    end
  end

  def es_limit_search_by_days
    search_from = es_session_from

    # I assume this is not working with timezones...
    if user? || reseller?
      owner = reseller? ? 0 : current_user.owner_id
      stats_for_last = Confline.get_value("Show_Calls_statistics_to_#{current_user.usertype.capitalize}_for_last", owner).to_i
      unless stats_for_last == 0
        current_time = Time.current.beginning_of_day
        if (current_time - Time.parse(es_session_from)) > stats_for_last.days
          new_time = current_time - stats_for_last.days
          search_from = new_time.strftime('%Y-%m-%dT%H:%M:%S')
        end
      end
    end

    return search_from
  end

  def es_session_from(options = {})
    # options[:date] => '2001-01-01'
    date = (options[:date] || "#{session[:year_from]}-#{session[:month_from]}-#{session[:day_from]}").to_s

    # options[:time] => '00:00:00'
    time = (options[:time] || "#{session[:hour_from]}:#{session[:minute_from]}:00").to_s

    # options[:timezone] => 'Vilnius', 'London'
    #timezone = (options[:timezone] || current_user.time_zone).to_s

    #datetime = (Time.parse("#{date} #{time}") - Time.parse("#{date} #{time}").in_time_zone(timezone).utc_offset().second + Time.parse("#{date} #{time}").utc_offset().second)
    datetime = (Time.parse("#{date} #{time}") - Time.zone.now.utc_offset().second + Time.now.utc_offset().second).to_s(:db)

    #"#{datetime.strftime('%Y-%m-%dT%H:%M:%S')}"
    datetime.split(' ').join('T')
  end

  def es_session_till(options = {})
    # options[:date] => '2001-01-01'
    date = (options[:date] || "#{session[:year_till]}-#{session[:month_till]}-#{session[:day_till]}").to_s

    # options[:time] => '29:59:59'
    time = (options[:time] || "#{session[:hour_till]}:#{session[:minute_till]}:59").to_s

    # options[:timezone] => 'Vilnius', 'London'
    #timezone = (options[:timezone] || current_user.time_zone).to_s

    #datetime = (Time.parse("#{date} #{time}") - Time.parse("#{date} #{time}").in_time_zone(timezone).utc_offset().second + Time.parse("#{date} #{time}").utc_offset().second)
    datetime = (Time.parse("#{date} #{time}") - Time.zone.now.utc_offset().second + Time.now.utc_offset().second).to_s(:db)

    #"#{datetime.strftime('%Y-%m-%dT%H:%M:%S')}"
    datetime.split(' ').join('T')
  end

  def collide_prefix(prefix = '')
    collided_prefix = []

    # Remove any non digit character
    prefix = prefix.to_s.gsub(/[^\d]/, '')
    prefix.split('').each_index { |index| collided_prefix << prefix[0..index] }

    collided_prefix
  end

  def get_server_path(local = 1)
    if local == 0
      server = Confline.get_value('Recordings_addon_IP')
      "http://#{server}/recordings/"
    else
      Web_Dir + '/recordings/'
    end
  end

  def validate_session_ip
    session[:login_ip] == request.remote_ip
  end

  def logout_on_session_ip_mismatch
    if session[:login] && !validate_session_ip
      add_action(session[:user_id], 'logout_session_ip_mismatch', '')
      session[:login] = false
      session.destroy
      redirect_to(controller: :callc, action: :login) && (return false)
    end
  end

  private

  def store_location
    session[:return_to] = request.url
  end

  def redirect_back_or_default(default = 'callc/main')
    session[:return_to] ? redirect_to(session[:return_to]) : redirect_to(Web_Dir + default)
    session[:return_to] = nil
  end

  def get_memory_info
    begin
      info = "RAM:\n"
      info += `free`
      info += "\nDISK:\n"
      info += `df -h`
      info += "\nPS AUX:\n"
      info += `ps aux | grep 'apache\\|cgi\\|USER' | grep -v grep`
      return info
    rescue
      return "Error on extracting memory and PS info."
    end
  end

  def get_svn_info
    begin
      svn_info = `svn info #{Rails.root}`
      svn_status = (`svn status #{Rails.root} 2>&1`).to_s.split("\n").collect { |line| line if (line[0..0] == "M" or line.scan("This client is too old to work with working copy").size > 0) }.compact.size > 0
      svn_data = svn_info.split("\n")
      rep = svn_data[1].to_s.split(": ")[1].to_s.strip
      rev = svn_data[4].to_s.split(": ")[1].to_s.strip
      status = svn_status ? "YES" : "NO"
   rescue => err
      #for info
      status = err
      rev = rep = "SVN ERROR"
      #status = rev = rep = "SVN ERROR"
    end
    return rep, rev, status
  end

  def simple_file_name?(string)
    string.match(/^[a-zA-Z1-9]+.[a-zA-Z1-9]+/)
  end

  def testable_file_send(file, filename, mimetype)
    if params[:test]
      case mimetype
        when "application/pdf" then
          render text: {filename: filename, file: "File rendered"}.to_json
        else
          render text: {filename: filename, file: file}.to_json
      end
    else
      send_data(file, type: mimetype, filename: filename)
    end
  end

  def send_crash_email(address, subject, message)
    MorLog.my_debug('  >> Before sending message.', true)
    local_filename = "/tmp/mor_crash_email.txt"
    File.open(local_filename, 'w') { |file| file.write(message) }

    command = ApplicationController::send_email_dry('guicrashes@kolmisoft.com', address, '', subject, "-o message-file='#{local_filename}' tls='auto'")

    if defined?(NO_EMAIL) and NO_EMAIL.to_i == 1
      #do nothing
    else
      system(command)
    end

    MorLog.my_debug("  >> Crash email sent to #{address}", true)
    MorLog.my_debug("  >> COMMAND : #{command.inspect}", true)
    MorLog.my_debug("  >> MESSAGE  #{message.inspect}", true)
    system("rm -f #{local_filename}")
  end

  def find_provider
    user = accountant? ? User.where(id: 0).first : current_user
    @provider = user.providers.where(id: params[:id]).first
    unless @provider
      flash[:notice] = _('Provider_not_found')
      redirect_to(controller: :providers, action: :list) && (return false)
    end
  end

  def find_destination
    @destination = Destination.where(id: params[:id]).includes([:destinationgroup]).first
    unless @destination
      flash[:notice] = _('Destination_was_not_found')
      redirect_to controller: "directions", action: 'list' and return false
    end
  end

  def is_number?(val=nil)
    #check if value is a number ( no decimal seperator allowed )
    (!!(val.match /^[0-9]+$/) rescue false)
  end

  def is_number_or_prefix?(val=nil)
    # Check if value is a number (no decimal seperator allowed) or prefix (ends with single % character)
    # Also, allow + sign in the beginning
    (!!(val.match /^\+?[0-9]+%?$/) rescue false)
  end

  def is_numeric?(val=nil)
    # Check if value is a digit ( allows decimal seperator )
    (!!(Float(val)) rescue false)
  end

  def call_shop_active?
    confline = lambda { Confline.get_value('CS_Active').to_i == 1 }
    functionality_active(:CS_Active, confline)
  end

  def payment_gateway_active?
    confline = lambda { Confline.get_value('PG_Active').to_i == 1 }
    functionality_active(:PG_Active, confline)
  end

  def calling_cards_active?
    confline = lambda { (Confline.get_value('CC_Active').to_i == 1 and (not reseller? or (reseller? and (session[:res_calling_cards].to_i == 2)))) }
    functionality_active(:calling_cards_active, confline)
  end

  def sms_active?
    confline = lambda {Confline.get_value('SMS_Active').to_i == 1}
    functionality_active(:SMS_Active, confline)
  end

  def callback_active?
    confline = lambda {Confline.get_value('CALLB_Active').to_i == 1}
    functionality_active(:CALLB_Active, confline)
  end

  def cc_single_login_active?
    confline = lambda {Confline.get_value('CC_Single_Login').to_i == 1}
    functionality_active(:cc_single_login_active, confline)
  end

  def recordings_addon_active?
    confline = lambda {Confline.get_value('REC_Active').to_i == 1}
    functionality_active(:rec_active, confline)
  end

  def monitorings_addon_active?
    confline = lambda {Confline.get_value('MA_Active').to_i == 1}
    functionality_active(:ma_active, confline)
  end

  def reseller_active?
    confline = lambda {Confline.get_value('RS_Active').to_i == 1}
    functionality_active(:rs_active, confline)
  end

  def multi_level_reseller_active?
    confline = lambda {Confline.get_value('MLRS_Active').to_i == 1}
    functionality_active(:mlrs_active, confline)
  end

  def cc_active?
    confline = lambda {Confline.get_value('CC_Active').to_i == 1}
    functionality_active(:cc_active, confline)
  end

  def pbx_active?
    confline = lambda {Confline.get_value('PBX_Active').to_i == 1}
    pbx_cofline_status = functionality_active(:PBX_Active, confline)

    if reseller?
      pbx_cofline_status and (not reseller? or (reseller? and (session[:res_pbx_functions].to_i == 2)))
    else
      pbx_cofline_status
    end
  end

  def ad_active?
    confline = lambda {Confline.get_value('AD_Active').to_i == 1}
    functionality_active(:ad_active, confline)
  end

  def reseller_pro_active?
    confline = lambda {reseller_active? and (Confline.get_value('RSPRO_Active').to_i == 1)}
    functionality_active(:reseller_pro_active, confline)
  end

  def rec_active?
    recordings_addon_active?
  end

  def show_rec?
    return false unless (show_recordings? || admin?) && rec_active?
    if reseller?
      User.current.recording_enabled.to_i == 1
    elsif accountant?
      session[:acc_recordings_manage].to_i > 0
    else
      rec_active? && !partner?
    end
  end

  def admin?
    session[:usertype].to_s == 'admin'
  end

  def reseller?
    session[:usertype].to_s == 'reseller'
  end

  def reseller_pro?
    reseller? && (current_user.own_providers == 1)
  end

  def reseller_not_pro?
    reseller? && (current_user.own_providers.to_i == 0)
  end

  def user?
    session[:usertype].to_s == 'user'
  end

  def accountant?
    session[:usertype].to_s == 'accountant'
  end

  def partner?
    session[:usertype].to_s == 'partner'
  end

  def test_machine_active?
    (defined?(TEST_MACHINE) and TEST_MACHINE.to_i == 1)
  end

  def provider_billing_active?
    Confline.get_value('PROVB_Active').to_i == 1
  end

  def ccl_active?
    confline = lambda do
      ccl_active = Confline.get_value("CCL_Active") rescue NIL
      (!ccl_active.blank? and ccl_active.to_i == 1)
    end

    functionality_active(:ccl_active, confline)
  end

  def user_tz
    current_user.time_zone
  end

  def set_valid_language
    usr_trans_arr = UserTranslation.select('translations.short_name').
                    joins("LEFT JOIN `translations` ON translations.id = user_translations.translation_id").
                    where("user_translations.active = 1").
                    order('user_translations.position ASC').all.map(&:short_name)
    language_now = I18n.locale
    usr_trans_arr.map!{|tr| tr.try(:to_sym)}
    if usr_trans_arr.include?(language_now)
      I18n.locale
    else
      I18n.locale = usr_trans_arr.first.to_s
    end
  end

  def user_time_from_params(*date)
    keys = [:year, :month, :day, :hour, :minute]

    now = Time.now

    default_date_hash = {
       year: now.year,
       month: now.month,
       day: now.day,
       hour: '00',
       minute: '00'
     }

    date_hash = Hash[keys.zip(date)]

    date_hash.each do |key, value|
      date_hash[key.intern] = default_date_hash[key.intern] unless value.to_s.match(/^\d+$/)
    end

    date_time_str = "#{date_hash[:year]}-#{date_hash[:month]}-#{date_hash[:day]} #{date_hash[:hour]}:#{date_hash[:minute]}"

    time = Time.zone.parse(date_time_str)

    # time.parse changes month to the neares if it is invalid.
    # Example: 2013-02-30 is changed to 2013-03-01
    # ticket #8344
    if time.month.to_i != date_hash[:month].to_i
      time = time.change(month: date_hash[:month])
      time = time.change(day: time.end_of_month.day)
    end

    time
  end

  def last_day_month(date)
    year = session["year_#{date}".to_sym]
    if last_day_of_month(session["year_#{date}".to_sym], session["month_#{date}".to_sym]).to_i <= session["day_#{date}".to_sym].to_i
      day = "01"
      if session["month_#{date}".to_sym].to_i == 12
        month = '01'
        year = session["year_#{date}".to_sym].to_i + 1
      else
        month = session["month_#{date}".to_sym].to_i+1
      end
    else
      day = session["day_#{date}".to_sym].to_i+1
      month = session["month_#{date}".to_sym].to_i
    end
    return year, month, day
  end

=begin
  Check whether supplied date's day is the last day of that month.
  Maybe we should exten Date, Daytime, Time with this method, but i dont approve modifying built in classes

  *Params*
  *date* - Date, Daytime, Time instances or anything that has year, month and day methods

  *Returns*
  *boolean* - true or false depending whether day is the last day of the month of supplied date
=end
  def self.last_day_of_the_month?(date)
    next_month = Date.new(date.year, date.month) + 42 # warp into the next month
    date.day == (Date.new(next_month.year, next_month.month) - 1).day # back off one day from first of that month
  end

=begin
  Check whether supplied date's day is the last day of that month.
  Maybe we should exten Date, Daytime, Time with this method, but i dont approve modifying built in classes

  *Params*
  *date* - Date, Daytime, Time instances or anything that has day method

  *Returns*
  *boolean* - true or false depending whether day is the first day of the month of supplied date
=end
  def self.first_day_of_the_month?(date)
    date.day == 1
  end


  # Return difference in 'months' between two dates.
  # In MOR 'month' only counts when it is a period FROM FIRST SECOND
  # OF CALENDAR MONTH TILL LAST SECOND OF CALENDAR MONTH. for example:
  # period between 01.01 00:00:00 and 01.31 23:59:59 is whole 1 month
  # period between 01.02 00:00:00 and 02.01 23:59:59 is NOT a whole month, althoug intervals exressed as seconds are the same
  # period between 01.01 00:00:00 and 02.01 23:59:59 is whole 1 month
  # period between 01.01 00:00:00 and 02.29 23:59:59 is whole 1 month
  # period between 01.01 00:00:00 and 02.29 23:59:59 is whole 1 month, allthoug it may seem as allmost two months
  # period between 01.02 00:00:00 and 02.29 23:59:59 is NOT a whole month, allthoug it may seem as allmost two months
  # period between 01.02 00:00:00 and 03.29 23:59:59 is only 1 whole month, allthoug it may seem as allmost three months
  # lets hope you'll get it, if not ask boss, he knows whats this about.
  def self.month_difference(period_start, period_end)
    month_diff = period_end.month - period_start.month
    if month_diff == 0
      return ((first_day_of_the_month? period_start and last_day_of_the_month? period_end) ? 1 : 0)
    else
      month_diff = month_diff - 1
      if first_day_of_the_month? period_start
        month_diff += 1
      end
      if last_day_of_the_month? period_end
        month_diff += 1
      end
      return month_diff
    end
  end

  def check_post_method
    unless request.post?
      dont_be_so_smart
      redirect_to root_path and return false
    end
  end

  def store_url
    session[:url] = "#{request.protocol}#{request.host_with_port}" if session[:url].blank?
  end

  def handle_unverified_request
    begin
      super
    rescue ArgumentError
      Rails.cache.clear
      reset_session rescue ArgumentError
    end
    redirect_to controller: 'callc', action: 'login', session_expired: true
  end

  # Only to be used when the time is stored in session
  def limit_search_by_days
    search_from = session_from_datetime

    if user? or reseller?
      owner = reseller? ? 0 : current_user.try(:owner_id)
      stats_for_last = Confline.get_value("Show_Calls_statistics_to_#{current_user.usertype.capitalize}_for_last", owner).to_i
      unless stats_for_last == 0
        current_time = Time.current.beginning_of_day
        if (current_time - Time.parse(session_from_datetime)) > stats_for_last.days
          new_time = current_time - stats_for_last.days
          search_from = new_time.strftime('%Y-%m-%d %H:%M:%S')
        end
      end
    end

    return search_from
  end

  def time_in_user_tz(hours, minutes, seconds='00')
    time_str = [hours, minutes, seconds].join(':')

    time = Time.parse(time_str).in_time_zone(user_tz)
    time
  end

  def functionality_active(key, confline)
    if session.blank?
      return confline.call
    else
      session[key] ||= confline.call
      return session[key]
    end
  end

  # this method is used to prevent losing cyrillic character while encoding to utf
  def fix_encoding_import_csv(file_raw)
    begin
      cleaned = file_raw.dup.force_encoding('UTF-8')
      unless cleaned.valid_encoding?
        cleaned = file_raw.encode('UTF-8', 'Windows-1251')
      end
    file = cleaned
    rescue EncodingError
      file.encode!( 'UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
    end
    file
  end

  def annoying_messages
    if Confline.get_value('unlicensed') == '1'
      flash[:notice] = flash[:status] = 'Your copy of MOR is not licensed, contact <a href="http://www.kolmisoft.com/class-5-softswitch">Kolmisoft</a>'
    end
  end

  def allow_pdffax_edit_for_user?
    Confline.get_value('Allow_User_to_change_FAX_email', current_user.owner_id).to_i == 1
  end
end


module Enumerable
  def dups
    inject({}) { |item, index| item[index]=item[index].to_i+1; item }.reject { |items, index| index==1 }.keys
  end
end
