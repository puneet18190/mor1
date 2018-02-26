# -*- encoding : utf-8 -*-
# Mainly Cron and Login actions.
class CallcController < ApplicationController
  require 'digest/sha1'
  require 'ipaddr'
  require 'csv'
  require 'scripts/migrate_sms_tariffs'
  include ApplicationHelper
  include UtilityHelper

  layout :mobile_standard

  before_filter :check_localization, except: [:pay_subscriptions, :monthly_actions, :monthly_actions_balance]
  before_filter :authorize, except: [:login, :try_to_login, :pay_subscriptions, :monthly_actions, :forgot_password,
                                     :monthly_actions_balance, :admin_ip_access]
  before_filter :find_registration_owner, only: [:signup_start, :signup_end]
  skip_before_filter :redirect_callshop_manager, only: [:logout]
  before_filter :check_users_count, only: [:signup_start, :signup_end]

  @@monthly_action_balance_cooldown = 2.hours
  @@monthly_action_cooldown = 2.hours
  @@daily_action_cooldown = 2.hours
  @@hourly_action_cooldown = 20.minutes

  def index
    action = session[:usertype] ? :login : :logout
    redirect_to(action: action) && (return false)
  end

  def login
    @show_login, @u = params[:shl].to_s.to_i, params[:u].to_s
    flash[:notice] = _('session_expired') if params[:session_expired]

    @owner = params[:id] ? User.where(uniquehash: params[:id]).first : User.where(id: 0).first
    @owner_id, @defaulthash = @owner ? [@owner.id, @owner.get_hash] : [0, '']
    @allow_register = allow_register?(@owner)

    session[:login_id] = @owner_id

    flags_to_session(@owner)

    # do some house cleaning
    global_check

    if Confline.get_value('Show_logo_on_register_page', @owner_id).to_s == ''
      Confline.set_value('Show_logo_on_register_page', 1, @owner_id)
    end

    @page_title, @page_icon = _('Login'), 'key.png'

    if session[:login] == true
      (redirect_to :root) && (return false)
    end

    set_time

    if Confline.get_value('Show_logo_on_register_page', @owner_id).to_i == 1
      session[:logo_picture], session[:version], session[:copyright_title] = Confline.get_logo_details(@owner_id)
    else
      session[:logo_picture], session[:version], session[:copyright_title] = [''] * 3
    end

    if request.env['HTTP_X_MOBILE_GATEWAY']
      respond_to do |format|
        format.wml { render 'login.wml.builder' }
      end
    end
  end

  def try_to_login
    session[:layout_t] = params[:layout_t].to_s if params[:layout_t]

    unless params['login']
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    @username = params['login']['username'].to_s
    @psw = params['login']['psw'].to_s
    @type = 'user'
    @login_ok = false
    allow_login_by_email = Confline.get_value('Allow_login_by_email', 0).to_i

    if allow_login_by_email == 1
      @user = User.where('((LENGTH(users.username) > 0 AND users.username = ?) OR (LENGTH(addresses.email) > 0 AND addresses.email = ?)) AND users.password = ?', @username, @username, Digest::SHA1.hexdigest(@psw))
                  .joins('LEFT JOIN addresses ON addresses.id = users.address_id').first
    else
      @user = User.where(username: @username, password: Digest::SHA1.hexdigest(@psw)).first
    end

    request_remote_ip = request.remote_ip
    if Confline.get_value('admin_login_with_approved_ip_only ', 0).to_i == 1 && @user.try(:usertype).to_s == 'admin'
      iplocation = Iplocation.admin_ip_find_or_create(request_remote_ip)

      if Iplocation.where(approved: 1).size <= 1
        iplocation.approve
      elsif iplocation.approved.to_i == 0
        if Confline.get_value('Email_Sending_Enabled', 0).to_i == 1
          iplocation.admin_ip_send_email_authorization
          flash[:notice] = "UNAUTHORIZED IP ADDRESS. System Admin received email with request to authorize your IP: #{iplocation.ip}"
        else
          flash[:notice] = "UNAUTHORIZED IP ADDRESS. Your IP: #{iplocation.ip} is not authorized to access this account"
        end
        redirect_to(action: :login, id: @user.uniquehash, u: @username) && (return false)
      end
    end

    if @user.try(:owner) && @user.not_blocked_and_in_group
      @login_ok = true
      renew_session(@user)
      store_url
    end

    session[:login] = @login_ok

    if @login_ok
      session[:login_ip] = request_remote_ip
      add_action(session[:user_id], 'login', request.env["REMOTE_ADDR"].to_s)

      @user.mark_logged_in
      bad_psw = ((params['login']['psw'].to_s == 'admin') && (@user.id == 0)) ? _('ATTENTION!_Please_change_admin_password_from_default_one_Press')+ " <a href='#{Web_Dir}/users/edit/0'> #{_('Here')} </a> " + _('to_do_this') : ''
      flash[:notice] = bad_psw if !bad_psw.blank?
      request_user_agent = request.env['HTTP_USER_AGENT']
      cookies['_session_id'] = {value: cookies['_session_id'], expires: 48.hours.from_now}
      if (request_user_agent) && (request_user_agent.match('iPhone') || request_user_agent.match('iPod'))
        flash[:status] = _('login_successfully')
        redirect_to(action: 'main_for_pda') && (return false)
      else
        flash[:status] = _('login_successfully')
        if (group = current_user.usergroups.includes(:group).where("usergroups.gusertype = 'manager' AND groups.grouptype = 'callshop'").references(:group).first) && (current_user.usertype != 'admin')
          session[:cs_group] = group
          session[:lang] = Translation.where(id: group.group.translation_id).first.short_name
          redirect_to(controller: :callshop, action: :show, id: group.group_id) && (return false)
        else
          (redirect_to :root) && (return false)
        end
      end
    else
      add_action_second(0, 'bad_login', @username.to_s, request.env["REMOTE_ADDR"].to_s)

      us = User.where(id: session[:login_id]).first
      u_hash = us ? us.uniquehash : ''
      flash[:notice] = _('bad_login')
      show_login = Action.disable_login_check(request.env["REMOTE_ADDR"].to_s).to_i == 0 ? 1 : 0
      redirect_to(action: :login, id: u_hash, shl: show_login, u: @username) && (return false)
    end
  end

  def main_for_pda
    @page_title, @user = _('Start_page'), User.where(id: session[:user_id]).first
    @username = @user.full_name
  end

  def logout
    add_action(session[:user_id], 'logout', '')
    user = User.where(id: session[:user_id]).first

    if user
      user.mark_logged_out
      owner = user.owner
      user_id = user.id
    end

    owner ||= User.where(id: 0).first
    owner_id = owner.try(:id) || 0
    owner_id = user_id if user && (reseller? || partner?)
    session[:login] = false
    session.destroy
    flash[:status] = _('logged_off')

    if Confline.get_value('Logout_link', owner_id).to_s.blank?
      if user.try(:is_reseller?) || user.try(:is_partner?)
        id = user.get_hash
      elsif owner.try(:get_hash)
        id = owner.get_hash
      end

      redirect_to action: 'login', id: id
    elsif user.try(:is_reseller?) || user.try(:is_partner?)
      redirect_to get_logout_link(user_id), id: user.get_hash
    else
      redirect_to get_logout_link(owner_id)
    end
  end

  def forgot_password
    email = to_utf(params[:email])
    if email.present?
      @r, @st = User.recover_password(email)

      flash[:notice_forgot] = @r.dup and @r.clear if @r.include?(_('Email_not_sent_because_bad_system_configurations'))
    end
    render layout: false
  end

  def main
    @show_currency_selector = 1
    redirect_to(action: :login) && (return false) unless session[:user_id]

    dont_be_so_smart if params[:dont_be_so_smart]

    @page_title = _('Start_page')
    session[:layout_t] = 'full'
    @user = User.includes(:tax).where(id: session[:user_id]).first

    redirect_to(action: :logout) && (return false) unless @user

    session[:integrity_check] = current_user.integrity_recheck_user
    session[:integrity_check] = Server.integrity_recheck if session[:integrity_check].to_i == 0
    session[:integrity_check] = Device.integrity_recheck_devices if session[:integrity_check].to_i == 0
    @username = nice_user(@user)

    if session[:usertype] == 'reseller'
      reseller = User.where(id: session[:user_id]).first
      reseller.check_default_user_conflines
    end

    @show_gateways = ((admin? || payment_gateway_active?) && !partner?) ? true : false

    @pp_enabled = session[:paypal_enabled]
    @wm_enabled = session[:webmoney_enabled]
    @vouch_enabled = session[:vouchers_enabled]
    @lp_enabled = session[:linkpoint_enabled]
    @cp_enabled = session[:cyberplat_enabled]

    @ob_enabled = session[:ouroboros_enabled]
    @ob_link_name = session[:ouroboros_name]
    @ob_link_url = session[:ouroboros_url]
    @ob_enabled = 0 if @user.owner_id > 0 # do not show for reseller users
    @paysera_enabled = session[:paysera_enabled]
    @addresses = Phonebook.where(user_id: session[:user_id]).all

    @engine = ::GatewayEngine.find(:enabled, {:for_user => current_user.id}).enabled_by(current_user.owner_id)
    @enabled_engines = @engine.gateways

    if request.env["HTTP_X_MOBILE_GATEWAY"]
      @notice = params[:sms_notice].to_s
      respond_to do |format|
        format.wml { render 'main.wml.builder' }
      end
    end
  end

  def show_quick_stats
    @page_title = _('Quick_stats') if Confline.get_value('Hide_quick_stats').to_i == 1

    @ex = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])

    @user = User.includes(:tax).where(id: session[:user_id]).try(:first)

    redirect_to(action: :logout) && (return false) unless @user

    time_now = Time.now.in_time_zone(@user.try(:time_zone))
    year = time_now.year.to_s
    month = time_now.month.to_s
    day = time_now.day.to_s

    month_t = "#{year}-#{good_date(month)}"
    last_day = last_day_of_month(year, good_date(month))
    day_t = "#{year}-#{good_date(month)}-#{good_date(day)}"
    session[:callc_main_stats_options] ? options = session[:callc_main_stats_options] : options = {}

    @quick_stats = @user.quick_stats(month_t, last_day, day_t, current_user_id)
    options[:quick_stats] = @quick_stats
    options[:time] = Time.now + 2.minutes

    session[:callc_main_stats_options] = options
  end

  def main_quick_stats
    @ex = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])

    @user = User.includes(:tax).where(id: session[:user_id]).try(:first)

    time_now = Time.now.in_time_zone(@user.try(:time_zone))
    year = time_now.year.to_s
    month = time_now.month.to_s
    day = time_now.day.to_s

    month_t = "#{year}-#{good_date(month)}"
    last_day = last_day_of_month(year, good_date(month))
    day_t = "#{year}-#{good_date(month)}-#{good_date(day)}"
    session[:callc_main_stats_options] ? options = session[:callc_main_stats_options] : options = {}

    @quick_stats = @user.quick_stats(month_t, last_day, day_t, current_user_id)
    options[:quick_stats] = @quick_stats
    options[:time] = Time.now + 2.minutes

    session[:callc_main_stats_options] = options
    render layout: false
  end

  def quick_stats_active_calls
    @active_calls = "#{Activecall.count_for_user(current_user)} / #{Activecall.count_for_user(current_user, true)}"
    render layout: false
  end

  def quick_stats_technical_info
    @servers = Server.all_quick_stats
    @es_sync = EsQuickStatsTechnicalInfo.get_data
    @es_sync[:tooltip] = "<b>#{_('MySQL_Calls')}:</b> #{@es_sync[:mysql]}<br/><b>#{_('Elasticsearch_Calls')}:</b> #{@es_sync[:es]}"

    render layout: false
  end

  def user_settings
    @user = User.where(id: session[:user_id]).first
  end

  def ranks
    # counting month_normative for 1 user which was counted most time ago
    user = User.order('month_plan_updated ASC').first
    user.months_normative(Time.now.strftime('%Y-%m'))
    @users = User.where(usertype: 'user', show_in_realtime_stats: '1').all
    @new_calls_today = Hash.new
    @total_billsec = 0
    @total_calls = 0
    @total_missed_not_processed = 0
    @total_new_calls = 0

    @users.each do |user|
      @ranks_type = params[:id]

      if @ranks_type == 'duration'
        calls_billsec = 0
        calls_billsec = user.total_duration('answered', today, today) + user.total_duration('answered_inc', today, today)
        @new_calls_today[user.id] = calls_billsec
        @total_billsec += calls_billsec
        @ranks_title = _('most_called_users')
        @ranks_col1 = _('time')
        @ranks_col2 = _('Calls')
      end
    end

    @user = @new_calls_today.sort { |a, b| b[1]<=>a[1] }

    @data_sec = []
    @avg_call_time = []
    @missed_not_processed = []
    @left_till_normative = [] # till normative
    @class_of_normative = [] # class of normative
    @percentage_of_normative = [] # percentage of normative
    @new_calls_today = [] # new calls

    @user.each do |a|
      if @ranks_type == 'duration'
        user = User.where(id: a[0]).first
        @data_sec[a[0]] = user.total_calls('answered', today, today) + user.total_calls('answered_inc', today, today)
        @missed_not_processed[a[0]] = user.total_calls('missed_not_processed', '2000-01-01', today)
        @total_missed_not_processed += @missed_not_processed[a[0]]
        @total_calls += @data_sec[a[0]]

        @avg_call_time[a[0]] = (@data_sec[a[0]] != 0) ? (a[1] / @data_sec[a[0]]) : 0

        normative = user.calltime_normative.to_d * 3600
        @left_till_normative[a[0]] = normative - a[1]
        @class_of_normative[a[0]] = 'red'

        @percentage_of_normative[a[0]] = (normative == 0) ? 0 : @percentage_of_normative[a[0]] = ((1 - (@left_till_normative[a[0]] / normative)) * 100).to_i

        # user has not started
        if a[1] == 0
          @left_till_normative[a[0]] = 0
          @class_of_normative[a[0]] = 'black'
        end

        # user has finished
        if @left_till_normative[a[0]] < 0
          @left_till_normative[a[0]] = a[1] - normative
          @class_of_normative[a[0]] = 'black'
        end

        @new_calls_today[a[0]] = user.new_calls(Time.now.strftime('%Y-%m-%d')).size
        @total_new_calls += @new_calls_today[a[0]]
      end
    end

    @avg_billsec = 0
    @avg_billsec = @total_billsec / @total_calls if @total_calls > 0

    render(layout: false)
  end

  def show_ranks
    @page_title = _('Statistics')
    render(layout: 'layouts/realtime_stats')
  end

  def realtime_stats
    @page_title = _('Realtime')

    if params[:rt]
      if params[:rt][:calltime_per_day]
        session[:time_to_call_per_day] = params[:rt][:calltime_per_day]
      end
    else
      if !session[:time_to_call_per_day]
        session[:time_to_call_per_day] = 3.0
      end
    end

    @ttcpd = session[:time_to_call_per_day]
  end

  def global_settings
    @page_title = _('global_settings')
    cond = 'exten = ? AND context = ? AND priority IN (2, 3) AND appdata like ?'
    ext = Extline.where(cond, '_X.', 'mor', 'TIMEOUT(response)%').first
    @timeout_response = (ext ? ext.appdata.gsub('TIMEOUT(response)=', '').to_i : 20)
    ext = Extline.where(cond, '_X.', 'mor', 'TIMEOUT(digit)%').first
    @timeout_digit = (ext ? ext.appdata.gsub('TIMEOUT(digit)=', '').to_i : 10)
    @translations = Translation.order('position ASC').all
  end

  def global_settings_save
    Confline.set_value('Load_CSV_From_Remote_Mysql', params[:load_csv_from_remote_mysql].to_i, 0)
    redirect_to(action: :global_settings) && (return false)
  end

  def reconfigure_globals
    @page_title = _('global_settings')
    @type = params[:type]

    if @type == 'devices'
      @devices = Device.where('user_id > 0').all
      for dev in @devices
        access = configure_extensions(dev.id, {current_user: current_user})
        return false if !access
      end
    end

    reconfigure_outgoing_extensions if @type == 'outgoing_extensions'
  end

  def global_change_timeout
    if Extline.update_timeout(params[:timeout_response].to_i, params[:timeout_digit].to_i)
      flash[:status] = _('Updated')
    else
      flash[:notice] = _('Invalid values')
    end
    redirect_to(action: :global_settings) && (return false)
  end

  def global_change_fax_path_setup
    if Confline.set_value('Fax2Email_Folder', params[:fax2email_folder].to_s, 0)
      flash[:status] = _('Updated')
    else
      flash[:notice] = _('Invalid values')
    end
    redirect_to(action: :global_settings) && (return false)
  end

  def global_set_tz
    if Confline.get_value('System_time_zone_ofset_changed').to_i == 0
      sql = "UPDATE users SET time_zone = '#{ActiveSupport::TimeZone[Time.now.utc_offset/3600].name}';"
      ActiveRecord::Base.connection.execute(sql)
      Confline.set_value('System_time_zone_ofset_changed', 1)
      flash[:status] = _('Time_zone_for_users_set_to') + " #{ActiveSupport::TimeZone[Time.now.utc_offset/3600].name} "
    else
      flash[:notice] = _('Global_Time_zone_set_replay_is_dont_allow')
    end
    redirect_to(action: :global_settings) && (return false)
  end

  def set_tz_to_users
    User.all.each do |user|
      begin
        Time.zone = user.time_zone
        user.time_zone = ActiveSupport::TimeZone[Time.zone.now.utc_offset().hour.to_d + params[:add_time].to_d].name
        user.save
      rescue => e
      end
    end

    flash[:status] = _('Time_zone_for_users_add_value') + " + #{params[:add_time].to_d} "
    redirect_to(action: :global_settings) && (return false)
  end

  def signup_start
    @page_title, @page_icon = _('Sign_up'), 'signup.png'
    @countries = Direction.order('name ASC').all
    @agreement = Confline.get('Registration_Agreement', @owner.id)

    Confline.load_recaptcha_settings

    if Confline.get_value('reCAPTCHA_enabled').to_i == 1
      configs = Recaptcha.configuration
      unless RecaptchaVerificator.verify_keys(configs.public_key, configs.private_key)
        flash[:notice] = _('configuration_error_contact_system_admin')
        redirect_to(controller: :callc, action: :login) && (return false)
      end
    end

    if Confline.get_value('Show_logo_on_register_page', @owner.id).to_i == 1
      session[:logo_picture], session[:version], session[:copyright_title] = Confline.get_logo_details(@owner.id)
    end
    @vat_necessary = Confline.get_value("Registration_Enable_VAT_checking").to_i == 1 && Confline.get_value("Registration_allow_vat_blank").to_i == 0
  end

  def signup_end
    @page_title, @page_icon = _('Sign_up'), 'signup.png'

    # error checking
    keys = [
      :username,
      :password,
      :password2,
      :device_type,
      :first_name,
      :last_name,
      :client_id,
      :vat_number,
      :address,
      :postcode,
      :city,
      :county,
      :state,
      :country_id,
      :phone,
      :mob_phone,
      :fax,
      :email
    ]

    keys.each { |key| session["reg_#{key}".to_sym] = params[key] }
    reg_ip= request.remote_ip

    owner = User.where(uniquehash: params[:id]).first

    if !params[:id] || !owner
      reset_session
      dont_be_so_smart
      redirect_to(action: :login) && (return false)
    end
    show_debug = true
    if show_debug
      File.open('/tmp/new_log.txt', 'a+') {|file| file.write("\n Start #{Time.now}") }
    end
    notice = User.validate_from_registration(params, owner.id)

    # checkin reseller users quantity
    if owner && (owner.usertype == 'reseller')
      limit_it = (User.where(owner_id: owner.id).size >= 2)
      allow_reseller = case owner.own_providers
                         when 0
                           !reseller_active?
                         when 1
                           !reseller_pro_active?
                         else
                           true
                       end
      if limit_it && allow_reseller
        if owner.id == 0
          if reseller_pro_active?
            notice = _('resellers_pro_restriction')
          else
            notice = _('resellers_restriction')
          end
        else
          notice = _('reseller_users_restriction')
        end
      end
    end

    capt = true
    if Confline.get_value('reCAPTCHA_enabled').to_i == 1
      usern = User.new
      capt = verify_recaptcha(usern) ? true : (false; notice = _('Please_enter_captcha'))
    end

    if show_debug
      File.open('/tmp/new_log.txt', 'a+') { |f| f.write("\n End #{Time.now}") }
    end

    if capt && !notice || notice.blank?
      reset_session

      if Confline.get_value('Show_logo_on_register_page', @owner.id).to_i == 1
        session[:logo_picture], session[:version], session[:copyright_title] = Confline.get_logo_details(@owner.id)
      end

      @user, @send_email_to_user, @device, notice_create = User.create_from_registration(params, @owner, reg_ip, DeviceFreeExtension.take_extension, new_device_pin(), random_password(12), next_agreement_number)
      unless @user
        flash[:notice] = _('configuration_error_contact_system_admin')
        redirect_to(action: :signup_start, id: params[:id]) && (return false)
      end

      session[:reg_owner_id] = @user.owner_id

      if !notice_create
        flash[:status] = _('Registration_successful')
        Thread.new { configure_extensions(@device.id, {current_user: @owner}); ActiveRecord::Base.connection.close }
      else
        flash[:notice] = notice_create
      end
    else
      flash[:notice] = notice
      redirect_to(action: :signup_start, id: params[:id]) && (return false)
    end
  end

  # Secret method for Admin. Updates ALL devices (mimics plain submit).
  #   Client issue #12650
  def renew_devices
    unless admin?
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
    Device.all.try(:each) { |device| device.adjust_for_api(device.device_type) }
  end

  # cronjob runs every hour
  # 0 * * * * wget -o /dev/null -O /dev/null http://localhost/billing/callc/hourly_actions
  def hourly_actions
    # backups_hourly_cronjob
    if active_heartbeat_server
      periodic_action('hourly', @@hourly_action_cooldown) do
        # check/make auto backup
        Backup.backups_hourly_cronjob(session[:user_id])
        # ==================== send balance warning email for users ===========
        MorLog.my_debug('Starting checking for balance warning', 1)
        User.check_users_balance
        send_balance_warning
        MorLog.my_debug('Ended checking for balance warning', 1)

        if payment_gateway_active?
          if Confline.get_value('ideal_ideal_enabled').to_i == 1
            MorLog.my_debug('Starting iDeal check')
            payments = Payment.where(paymenttype: 'ideal_ideal', completed: 0, pending_reason: 'waiting_response').all
            MorLog.my_debug("Found #{payments.size} waiting payments")
            # There may be possibe to do some caching if performance becomes an issue.
            if payments.size > 0
              begin
                payments.each do |payment|
                  gateway = GatewayEngine.find(:first, { engine: 'ideal', gateway: 'ideal', for_user: payment.user_id })
                    .enabled_by(payment.owner_id).query # This is cacheable
                  success, message = gateway.check_response(payment)
                  MorLog.my_debug("#{success ? 'Done' : 'Fail'} : #{message}")
                end
              rescue ActiveProcessor::GatewayEngineError
                MorLog.my_debug('There are old pending ideal payments, remove them!')
              end
            end
            MorLog.my_debug('Ended iDeal check')
          end
        end
        # ==================== Cron actions ===================================
        CronAction.do_jobs
        # ==================== Devices  =======================================
        check_devices_for_accountcode
        DeviceFreeExtension.insert_free_extensions
        #======================== Servers =====================================
        inform_admin_for_low_space_servers

        # ==================== System time offset =============================
        # ==================== System time offset update users ================
        update_timezone_offsets
        # ==================== Send Invoices generated by Core ================
        # As for now, cron generates invoices only for Admin scope (Simple Users/Resellers)
        # So this method will not include actions with Partners/Resellers users
        send_generated_invoices
        # ==================== Dynamic Flat-Rate extend period time ===========
        Subscription.dynamic_flatrate_extend_period_for_all
        # ==================== Pay Subscriptions ==============================
        # Pay ONLY Dynamic Flat-Rate subscriptions
        pay_dynamic_flatrate_subscriptions
      end
    else
      MorLog.my_debug('Backup not made because this server has different IP than Heartbeat IP from Conflines')
    end
  end

  # cronjob runs every midnight
  # 0 0 * * * wget -o /dev/null -O /dev/null http://localhost/billing/callc/daily_actions
  def daily_actions
    if active_heartbeat_server # to be sure to run this only once per day
      periodic_action('daily', @@daily_action_cooldown) do
        # ==================== get Currency rates from yahoo.com ==============
        update_currencies
        # ==================== Update Daily Currencies from Currencies ========
        daily_currencies = DailyCurrency.where(added: Time.now.strftime('%F')).first || DailyCurrency.new
        daily_currencies.currencies_update
        daily_currencies.save
        # ==================== delete old files ===============================
        delete_files_after_csv_import
        system('rm -f /tmp/get_tariff_*') #delete tariff export zip files

        # ==================== block users if necessary =======================
        block_users
        block_users_conditional

        # ==================== pay subscriptions ==============================
        @time = Time.now - 1.day
        pay_subscriptions(@time.year.to_i, @time.month.to_i, @time.day.to_i, 'is_a_day')
      end
    end
  end

  # cronjob runs every 1st day of month
  # 0 * * * * wget -o /dev/null -O /dev/null http://localhost/billing/callc/monthly_actions
  def monthly_actions
    if active_heartbeat_server
      periodic_action('monthly', @@monthly_action_cooldown) do
        # ==================== count/deduct subscriptions =====================
        year = Time.now.year.to_i
        month = Time.now.month.to_i - 1

        if month == 0
          year -= 1
          month = 12
        end

        my_debug("Counting subscriptions for: #{year} #{month}")
        pay_subscriptions(year, month)
      end
    end
  end

  def monthly_actions_balance
    if active_heartbeat_server
      periodic_action('monthly_balance', @@monthly_action_balance_cooldown) do
        year = Time.now.year.to_i
        month = Time.now.month.to_i - 1

        if month == 0
          year -= 1
          month = 12
        end

        my_debug("Saving balances for users for: #{year} #{month}")
        save_user_balances(year, month)
      end
    end
  end

  def periodic_action(type, cooldown)
    db_time = Time.now.to_s(:db)
    MorLog.my_debug "#{db_time} - #{type} actions starting sleep"
    sleep(rand * 10)
    MorLog.my_debug "#{db_time} - #{type} actions starting sleep end"
    begin
      time_set = Time.parse(Confline.get_value("#{type}_actions_cooldown_time"))
    rescue ArgumentError
      time_set = Time.now - 1.year
    end
    current_time = Time.now
    unless time_set && (time_set + cooldown > current_time)
      Confline.set_value("#{type}_actions_cooldown_time", current_time.to_s(:db))
      MorLog.my_debug "#{type} actions starting"
      yield
      MorLog.my_debug "#{type} actions finished"
    else
      MorLog.my_debug("#{cooldown} has not passed since last run of #{type.upcase}_ACTIONS")
      render(text: 'Too fast')
    end
  end

  def pay_subscriptions_test
    if session[:usertype] == 'admin' && !params[:year].blank? && !params[:month].blank?
      a = pay_subscriptions(params[:year], params[:month])
      return false if !a
    else
      render(text: 'NO!')
    end
  end

  def test_pdf_generation
    pdf = Prawn::Document.new(size: 'A4', layout: :portrait)
    pdf.font("#{Prawn::BASEDIR}/data/fonts/DejaVuSans.ttf")

    # ---------- Company details ----------
    pdf.text(session[:company], {left: 40, size: 23})
    pdf.text(Confline.get_value('Invoice_Address1'), {left: 40, size: 12})
    pdf.text(Confline.get_value('Invoice_Address2'), {left: 40, size: 12})
    pdf.text(Confline.get_value('Invoice_Address3'), {left: 40, size: 12})
    pdf.text(Confline.get_value('Invoice_Address4'), {left: 40, size: 12})

    # ----------- Invoice details ----------
    pdf.fill_color('DCDCDC')
    pdf.draw_text(_('INVOICE'), {at: [330, 700], size: 26})
    pdf.fill_color('000000')
    pdf.draw_text(_('Date') + ': ' + 'invoice.issue_date.to_s', {at: [330, 685], size: 12})
    pdf.draw_text(_('Invoice_number') + ': ' + 'invoice.number.to_s', {at: [330, 675], size: 12})

    pdf.image(Actual_Dir + '/public/images/rails.png')
    pdf.text('Test Text : ąčęėįšųūž_йцукенгшщз')
    pdf.render

    flash[:status] = _('Pdf_test_pass')
    (redirect_to :root) && (return false)
  end

  def global_change_confline
    if params[:heartbeat_ip]
      case params[:heartbeat_ip]
      when Resolv::IPv4::Regex || Resolv::IPv6::Regex
        Confline.set_value('Heartbeat_IP', params[:heartbeat_ip].to_s.strip)
        flash[:status] = 'Heartbeat IP successfully set'
      else
        flash[:notice] = 'Heartbeat IP was not set </br>'
        flash[:notice] << '* Heartbeat IP value missing/invalid'
      end
    end
    redirect_to(action: :global_settings) && (return false)
  end

  def additional_modules
    @page_title = _('Additional_modules')
  end

  def additional_modules_save
    ccl, ccl_old, first_srv, def_asterisk, reseller_server,
        @resellers_devices = Confline.additional_modules_save_assign(params)

    if ccl.to_s != ccl_old.to_s and params[:indirect].to_i == 1
      @sd = ServerDevice.all
      @sp = Serverprovider.all

      if ccl.to_i == 0
        # Assign all fax/virtual devices to only one default asterisk server from carrier class setting
        assign_all_devices_to_one_asterisk
        # Assign all Reseller SIP Providers to asterisk server from reseller settings
        Serverprovider.assign_sip_to_one_asterisk

        Confline.additional_modules_save_no_ccl(ccl, @sd, @sp, @resellers_devices, def_asterisk, reseller_server)

        flash[:status] = _('Settings_saved')

        # removing session so that users couldn't use addons.
        Rails.cache.clear
        reset_session
        redirect_to(action: :additional_modules) && (return true)
      elsif ccl.to_i == 1
        ip = params[:ip_address]
        host = params[:host]
        # Assign all fax/virtual devices to all asterisk servers via server_devices table
        assign_all_devices_to_all_asterisk
        # Assign all SIP (IPAuth) Providers to all asterisk servers
        Serverprovider.assign_sip_to_all_asterisk

        if ip.blank? || !check_ip_validity(ip) || !Server.where(server_ip: ip).size.zero?
          flash[:notice] = _('Incorrect_Server_IP')
          redirect_to(action: :additional_modules) && (return false)
        elsif host.blank? || !check_hostname_validity(host) || !Server.where(hostname: host).size.zero?
          flash[:notice] = _('Incorrect_Host')
          redirect_to(action: :additional_modules) && (return false)
        else
          old_id = Server.select('MAX(id) AS last_old_id').first.try(:last_old_id).to_i
          new_id = old_id.to_i + 1

          created_server = Server.new(server_ip: ip, hostname: host, server_type: 'sip_proxy', comment: 'SIP Proxy', active: 0)
          if created_server.save &&
              (Device.where(name: "mor_server_#{new_id}")
              .update_all(nat: 'yes', allow: 'alaw;g729;ulaw;g723;g726;gsm;ilbc;lpc10;speex;adpcm;slin;g722'))

            @sd = Confline.additional_modules_save_with_ccl(@sd, @sp, created_server, ccl)
          else
            created_server_errors_values = created_server.errors.values.first
            flash[:notice] = _(created_server_errors_values.first, "mor_server_#{created_server.id}") if created_server_errors_values
            redirect_to(action: :additional_modules) && (return false)
          end
        end
      else
        flash[:notice] = _('additional_modules_fail')
        redirect_to(action: :additional_modules) && (return false)
      end
    end

    # removing session so that users couldn't use addons.
    Rails.cache.clear
    reset_session

    flash[:status] = _('Settings_Saved')
    redirect_to(action: :additional_modules)
  end

  def inform_admin_for_low_space_servers
    MorLog.my_debug('Checking Servers free space')
    servers_with_space_exceeded = Server.where("hdd_free_space < #{server_free_space_limit} AND server_type <> 'sip_proxy'").pluck(:id)

    if servers_with_space_exceeded.present?
      servers_with_space_exceeded.each do |server_with_no_space|
        server = Server.where(id: server_with_no_space).first
        MorLog.my_debug('Found Servers with exceeded space limit')
        MorLog.my_debug('Preparing email to send for admin')
        admin_id = 0
        admin = User.where(id: admin_id).first
        email_template = Email.where(name: 'server_low_free_space', owner_id: admin_id).first
        email_from = Confline.get_value('Email_from', admin_id).to_s
        variables = Email.email_variables(admin, nil, { hdd_free_space: server.hdd_free_space,
                                                        server_id: server.id, server_ip: server.server_ip })
        if Confline.get_value('Email_Sending_Enabled', 0).to_i == 1
          smtp_server = Confline.get_value('Email_Smtp_Server', admin_id).to_s.strip
          smtp_user = Confline.get_value('Email_Login', admin_id).to_s.strip
          smtp_pass = Confline.get_value('Email_Password', admin_id).to_s.strip
          smtp_port = Confline.get_value('Email_Port', admin_id).to_s.strip
          smtp_connection =  "'#{smtp_server.to_s}:#{smtp_port.to_s}'"
          smtp_connection << " -xu '#{smtp_user}' -xp '#{smtp_pass}'" if smtp_user.present?

          to = admin.try(:email).to_s
          email_body = nice_email_sent(email_template, variables)

          begin
						system_call = ApplicationController::send_email_dry(
            email_from.to_s, to.to_s, email_body,
            email_template.subject.to_s, '', smtp_connection,
            email_template[:format])

            if defined?(NO_EMAIL) and NO_EMAIL.to_i == 1
              # Do nothing
            else
              a = system(system_call)
              status = 'Email sent' if a
            end
          rescue
            MorLog.my_debug(status)
          end
        else
          MorLog.my_debug('Email sending disabled')
        end
        MorLog.my_debug(status)
      end
    else
      MorLog.my_debug('Servers have enough free space')
    end
  end

  def migrate_sms_tariffs
    unless admin?
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
    migrated = SmsTariffsMigrator.migrate
    if migrated.to_i < 0
      flash[:notice] = _('Cannot_perform_migration')
    else
      flash[:status] = "#{_('SMS_Tariffs_migrated')}: #{migrated.to_i}"
    end
  end

  def admin_ip_access
    ip = Iplocation.where(uniquehash: params[:id].to_s, approved: 0).first

    if Confline.get_value_default_on('admin_login_with_approved_ip_only ', 0).to_i == 1 && ip.present?
      if params[:block_ip].present?
        ip.block_ip
        message = "IP: #{ip.ip} was successfully blocked."
      else
        ip.approve
        message = "IP: #{ip.ip} was successfully authorized."
      end
      flash[:status] = message
    else
      dont_be_so_smart
    end
    (redirect_to :root) && (return false)
  end

  private

  # IP validation
  def check_ip_validity(ip = nil)
    regexp = /^\b(?![0.]*$)(?:25[0-5]|(?:2[0-4]|1\d|[1-9])?\d)(?:\.(?:25[0-5]|(?:2[0-4]|1\d|[1-9])?\d)){3}\b$/
    regexp.match(ip) ? true : false
  end

  # Hostname validation
  def check_hostname_validity(hostname = nil)
    regexp = /(^(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:[.](?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}$)|(^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)+([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])$)$/
    regexp.match(hostname) ? true : false
  end

  def assign_all_devices_to_all_asterisk
    asterisk_servers = Server.where(server_type: :asterisk).pluck(:id)
    all_devices = Device.where(device_type: [:fax, :virtual]).pluck(:id)

    asterisk_servers.each do |server_id|
      all_devices.each do |device_id|
        unless ServerDevice.where(server_id: server_id, device_id: device_id).first
          server_device = ServerDevice.new_relation(server_id, device_id)
          server_device.save
        end
      end
    end
  end

  def assign_all_devices_to_one_asterisk
    first_asterisk_server = Server.where(server_type: :asterisk).order(id: :asc).first.try(:id).to_i

    asterisk_server = Server.where(id: Confline.get_value('Default_asterisk_server').to_i).first.try(:id) ||
        first_asterisk_server
    reseller_asterisk_server = Server.where(id: Confline.get_value('Resellers_server_id').to_i).first.try(:id) ||
        first_asterisk_server

    all_devices = Device.where(device_type: [:fax, :virtual])

    ServerDevice.where(device_id: all_devices).destroy_all
    all_devices.each do |device|
      device_id = device.id
      server_to_assign = device.try(:user).try(:owner).try(:usertype).to_s == 'reseller' ?
          reseller_asterisk_server : asterisk_server

      server_device = ServerDevice.new_relation(server_to_assign, device_id)
      server_device.save

      device.update_attribute(:server_id, server_to_assign)
    end
  end

  def check_devices_for_accountcode
    retry_lock_error(3) { ActiveRecord::Base.connection.execute('UPDATE devices set accountcode = id WHERE accountcode = 0;') }
  end

  # if Heartbeat IP is set, check if current server IP is same as Heartbeat IP
  def active_heartbeat_server
    heartbeat_ip = Confline.get_value('Heartbeat_IP').to_s
    remote_ip = `ip -o -f inet addr show | grep "#{heartbeat_ip}/"`

    if !heartbeat_ip.blank? && (remote_ip.to_s.length == 0)
      render(text: 'Heartbeat IP incorrect') && (return false)
    end

    return true
  end

  # saves users balances at the end of the month
  # to use them in future in invoices
  # to show users how much they owe to system owner
  def save_user_balances(year, month)
    @year = year.to_i
    @month = month.to_i

    date = "#{@year.to_s}-#{@month.to_s}"

    if months_between(Time.mktime(@year, @month, '01').to_date, Time.now.to_date) < 0
      render(text: 'Date is in future') && (return false)
    end

    users = User.all

    # check all users for actions, if action not present - create new one and save users balance
    users.each do |user|
      old_action = Action.where(data: date, user_id: user.id).first
      if !old_action
        MorLog.my_debug("Creating new action user_balance_at_month_end for user with id: #{user.id}, balance: #{user.raw_balance}")
        Action.add_action_hash(user, {action: 'user_balance_at_month_end', data: date, data2: user.raw_balance.to_s, data3: Currency.get_default.name})
      else
        MorLog.my_debug("Action user_balance_at_month_end for user with id: #{user.id} present already, balance: #{old_action.data2}")
      end
    end
  end

  def pay_dynamic_flatrate_subscriptions
    # Select Dynamic Flat Rates subscriptions whose flatrate_data period_start/end are between now
    dynamic_subscriptions = Subscription.active_dynamic_flatrates.to_a

    # Remove already paid for this period subscriptions
    dynamic_subscriptions.delete_if { |subscription| Action.where(target_type: 'subscription', action: 'subscription_paid', target_id: subscription.id, data: "#{subscription.period_start.strftime('%Y-%m-%d %H:%M:%S')} - #{subscription.period_end.strftime('%Y-%m-%d %H:%M:%S')}").present? }

    # Pay subscriptions
    dynamic_subscriptions.each do |subscription|
      user = User.where(id: subscription.user_id).first
      subscription_price = subscription.try(:service).try(:price)

      next if user.blank? || subscription_price.blank?

      # Deduct money from user
      user.balance = user.balance.to_f - subscription_price.to_f
      user.save

      # Create Payment
      Payment.subscription_payment(user, subscription_price)

      # Create Action
      Action.create(user_id: user.id, target_id: subscription.id, target_type: 'subscription', date: Time.now, action: 'subscription_paid', data: "#{subscription.period_start.strftime('%Y-%m-%d %H:%M:%S')} - #{subscription.period_end.strftime('%Y-%m-%d %H:%M:%S')}", data2: subscription_price)
    end
  end

  def pay_subscriptions(year, month, day = nil, is_a_day = nil)
    email_body, email_body_reseller = [], []
    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)

    @year = year.to_i
    @month = month.to_i
    @day = day ? day.to_i : 1
    send = false

    if !day && (months_between(Time.mktime(@year, @month, @day).to_date, Time.now.to_date) < 0)
      render(text: 'Date is in future') && (return false)
    end

    email_body << "Charging for subscriptions.\nDate: #{@year}-#{@month}\n"
    email_body_reseller << "========================================\nSubscriptions of Reseller's Users"

    @users = User.includes(:tax, :subscriptions).where('blocked != 1 AND subscriptions.id IS NOT NULL').references(:subscriptions).order('users.owner_id ASC').all
    generation_time = Time.now
    doc.subscriptions() {
      doc.year(@year)
      doc.month(@month)
      doc.day(@day) if day
      @users.each_with_index { |user, index|
        user_time = Time.now
        subscriptions = user.pay_subscriptions(@year, @month, day, is_a_day)
        if subscriptions.size > 0
          doc.user(username: user.username, user_id: user.id, first_name: user.first_name, balance: user.balance, user_type: user.user_type) {
            send = true
            email_body << "#{index+1} User: #{nice_user(user)}(#{user.username}):" if user.owner_id.to_i == 0
            email_body_reseller << "#{index+1} User: #{nice_user(user)}(#{user.username}):" if user.owner_id.to_i != 0
            doc.blocked('true') if user.blocked.to_i == 1
            email_body << '  User was blocked.' if (user.blocked.to_i == 1) && (user.owner_id.to_i == 0)
            email_body_reseller <<  '  User was blocked.' if (user.blocked.to_i == 1) && (user.owner_id.to_i != 0)
            subscriptions.each { |sub_hash|
              email_body << "  Service: #{sub_hash[:subscription].service.name} - #{nice_number(sub_hash[:price])}"
              doc.subscription {
                doc.service(sub_hash[:subscription].service.name)
                doc.price(nice_number(sub_hash[:price]))
              }
            }
            email_body << '' if user.owner_id.to_i == 0
            email_body_reseller <<  '' if user.owner_id.to_i != 0
            doc.balance_left(nice_number(user.balance))
          }
        end

        logger.debug "User time: #{Time.now - user_time}"
      }
      email_body += email_body_reseller if email_body_reseller && (email_body_reseller.size.to_i > 0)
      if send
        email_time = Time.now
        email = Email.new(body: email_body.join("\n"), subject: 'subscriptions report', format: 'plain', id: 'subscriptions report')
        status = EmailsController::send_email(email, Confline.get_value('Email_from', 0), [User.where(id: 0).first], {owner: 0})
        doc.status(status.gsub('<br>', ''))
        logger.debug("Email took: #{Time.now - email_time}")
      end
    }
    logger.debug("Generation took: #{Time.now - generation_time}")

    if session[:usertype] == 'admin'
      render(xml: out_string)
    else
      render(text: '')
    end
  end

  def delete_files_after_csv_import
    MorLog.my_debug('delete_files_after_csv_import', 1)
    select = []
    select << 'SELECT table_name'
    select << 'FROM   INFORMATION_SCHEMA.TABLES'
    select << "WHERE  table_schema = 'mor' AND"
    select << "       table_name like 'import%' AND"
    select << '       create_time < ADDDATE(NOW(), INTERVAL -1 DAY);'
    if (tables = ActiveRecord::Base.connection.select_all(select.join(' ')))
      tables.each do |table|
        MorLog.my_debug("Found table : #{table['table_name']}", 1)
        Tariff.clean_after_import(table['table_name'])
      end
    end
  end

  def update_currencies
    begin
      Currency.transaction do
        my_debug('Trying to update currencies')
        notice = Currency.update_currency_rates
        if notice
          my_debug('Currencies updated')
        else
          my_debug('Currencies NOT updated. Yahoo closed the connection before the transaction was completed.')
        end
      end
    rescue => e
      my_debug(e)
      my_debug('Currencies NOT updated')
      return false
    end
  end

  def backups_hourly_cronjob
    redirect_to(controller: :backups, action: :backups_hourly_cronjob)
  end

  def block_users
    date = Time.now.strftime('%Y-%m-%d')
    User.where(block_at: date).update_all(blocked: 1)
    my_debug('Users for blocking checked')
  end

  def block_users_conditional
    day = Time.now.day
    users = User.where("block_at_conditional = '#{day}' AND balance < 0 AND postpaid = 1 AND block_conditional_use = '1'").all
    users.each { |user| user.update_attribute(:blocked, 1) if Invoice.where(user_id: user, paid: 0).present? }
    my_debug('Users for conditional blocking checked')
  end

  def send_balance_warning
    # set it for yourself
    enable_debug = 1
    debug_enabled = (enable_debug == 1)
    administrator = User.where(id: 0).first
    users = User.includes(:address).where("warning_email_active = 1 AND " +
                                            "((((warning_email_sent = 0) OR (warning_email_sent_admin = 0) OR (warning_email_sent_manager = 0)) " +
                                            "AND warning_email_hour = -1) " +
                                          "OR " +
                                            "(warning_email_hour != -1) " +
                                          ") AND ( " +
                                            "(balance < warning_email_balance) OR " +
                                            "(balance < warning_email_balance_admin) OR " +
                                            "(balance < warning_email_balance_manager) " +
                                          ")").references(:address).all
    if users.size.to_i > 0
      users.each do |user|

        # simple user warning balance email
        email_to_address = nice_warning_email(user)

        num = num_admin = num_manager = ''
        manager = User.where(id: user.responsible_accountant_id).first
        user_owner_admin = (user.owner_id == 0)
        email_hour = user.warning_email_hour

        user_current_time    = user.time_now_in_tz.hour
        admin_current_time   = administrator.time_now_in_tz.hour
        manager_current_time = manager ? manager.time_now_in_tz.hour : 0

        if debug_enabled && (email_hour == user_current_time ||
          email_hour == admin_current_time || email_hour == manager_current_time)

          MorLog.my_debug("Need to send warning_balance email to: #{user.id} #{user.username} #{email_to_address}")
        end

        user_owner_id = user.owner.is_partner? ? 0 : user.owner_id.to_i
        email = Email.where(name: 'warning_balance_email', owner_id: user_owner_id).first
        local_user_email = Email.where(name: 'warning_balance_email_local', owner_id: 0).first

        unless email
          owner = user.owner

          if owner.usertype == 'reseller'
            owner.check_reseller_emails
            email = Email.where(name: 'warning_balance_email', owner_id: user.owner_id).first
          end
        end

        variables = email_variables(user)
        # admin warning balance email
        admin_email = nice_warning_email(administrator)

        begin
          email_from = Confline.get_value('Email_from', user_owner_id).to_s
          email_sent_string = _('Email_sent')
          old_email_sent, old_email_sent_admin, old_email_sent_manager  = user.warning_email_sent,
                                                                          user.warning_email_sent_admin,
                                                                          user.warning_email_sent_manager

          if (user.balance < user.warning_email_balance) && ((user.warning_email_sent.to_i != 1 && email_hour == -1) ||
                       (email_hour == user_current_time))
            variables[:user_email] = email_to_address
            num = send_balance_warning_email(email, email_from, user, variables)
          end

          if ((user.balance < user.warning_email_balance_admin) && ((user.warning_email_sent_admin.to_i != 1 && email_hour == -1) ||
                        (email_hour == admin_current_time))) && user_owner_admin
            variables[:user_email] = admin_email
            num_admin = send_balance_warning_email(local_user_email, email_from, administrator, variables)
          end

          if manager.present? && user_owner_admin && (
            (user.balance < user.warning_email_balance_manager) && ((user.warning_email_sent_manager.to_i != 1 && email_hour == -1) ||
                        (email_hour == manager_current_time)))
            acc_email = nice_warning_email(manager)
            variables[:user_email] = acc_email
            num_manager = send_balance_warning_email(local_user_email, email_from, manager, variables)
          end

          if (num.to_s == email_sent_string)
            Action.add_action_hash(user.owner_id, {action: 'warning_balance_send', target_type: email_to_address,
              target_id: user.id, data: user.id, data2: email.id})

            if debug_enabled
              MorLog.my_debug("warning_balance_sent: #{user.id} #{user.username}, to user: #{email_to_address}")
            end

            user.warning_email_sent = 1
          end

          if (num_admin.to_s == email_sent_string) && user_owner_admin
            Action.add_action_hash(user.owner_id, {action: 'warning_balance_send', target_type: admin_email,
              target_id: 0, data: user.id, data2: email.id})

            if debug_enabled
              MorLog.my_debug("warning_balance_sent: #{user.id} #{user.username}, to admin: #{admin_email}")
            end

            user.warning_email_sent_admin = 1
          end

          if (num_manager.to_s == email_sent_string) && user_owner_admin

            Action.add_action_hash(user.owner_id, {action: 'warning_balance_send', target_type: acc_email,
              target_id: manager.id, data: user.id, data2: email.id})

            if debug_enabled
              MorLog.my_debug("warning_balance_sent: #{user.id} #{user.username}, to manager: #{acc_email}")
            end

            user.warning_email_sent_manager = 1
          end

          user.save

          if debug_enabled
            email_not_sent_string = _('email_not_sent')

            if num.to_s == email_not_sent_string
              MorLog.my_debug('Email could not be sent for USER')
            end

            if num_admin.to_s == email_not_sent_string && user_owner_admin
              MorLog.my_debug('Email could not be sent for ADMIN')
            end

            if num_manager.to_s == email_not_sent_string && user_owner_admin
              MorLog.my_debug('Email could not be sent for MANAGER')
            end

            if email_hour == -1
              if old_email_sent == user.warning_email_sent && old_email_sent == 1
                MorLog.my_debug('Email was already sent to USER')
              end

              if old_email_sent_admin == user.warning_email_sent_admin && old_email_sent_admin == 1 && user_owner_admin
                MorLog.my_debug('Email was already sent to ADMIN')
              end

              if old_email_sent_manager == user.warning_email_sent_manager && old_email_sent_manager == 1 && user_owner_admin
                MorLog.my_debug('Email was already sent to MANAGER')
              end
            end
          end
        rescue => exception
          if debug_enabled
            MorLog.my_debug("warning_balance email not sent to: #{user.id} #{user.username} #{email_to_address}, because: #{exception.message.to_s}")
          end

          Action.new(user_id: user.owner_id, target_id: user.id, target_type: 'user', date: Time.now.to_s(:db),
            action: 'error', data: 'Cant_send_email', data2: exception.message.to_s).save
        end
      end
    else
      if debug_enabled
        MorLog.my_debug('No users to send warning email balance')
      end
    end

    MorLog.my_debug('Sent balance warning action finished')
  end

  def find_registration_owner
    unless params[:id] && (@owner = User.where(uniquehash: params[:id]).first)
      dont_be_so_smart
      redirect_to(action: 'login') && (return false)
    end

    if Confline.get_value('Registration_enabled', @owner.id).to_i == 0
      dont_be_so_smart
      redirect_to(action: 'login', id: @owner.uniquehash) && (return false)
    end
  end

  def check_users_count
    owner = User.where(uniquehash: params[:id]).first
    allow_reseller = case owner.own_providers
                       when 0
                         !reseller_active?
                       when 1
                         !reseller_pro_active?
                       else
                         true
                     end
    if owner && (owner.usertype == 'reseller') && allow_reseller && (User.where(owner_id: owner.id).size >= 2)
      flash[:notice] = _('Registration_is_unavailable')
      redirect_to(action: "login/#{params[:id]}") && (return false)
    end
  end

  def send_balance_warning_email(email, email_from, user, variables)
    user_owner_id = user.owner.is_partner? ? 0 : user.owner_id.to_i
    status = _('email_not_sent')

    if Confline.get_value('Email_Sending_Enabled', 0).to_i == 1
      smtp_server = Confline.get_value('Email_Smtp_Server', user_owner_id).to_s.strip
      smtp_user = Confline.get_value('Email_Login', user_owner_id).to_s.strip
      smtp_pass = Confline.get_value('Email_Password', user_owner_id).to_s.strip
      smtp_port = Confline.get_value('Email_Port', user_owner_id).to_s.strip

      smtp_connection =  "'#{smtp_server}:#{smtp_port}'"
      smtp_connection << " -xu '#{smtp_user}' -xp '#{smtp_pass}'" if smtp_user.present?

      to = variables[:user_email]
      email_body = nice_email_sent(email, variables)

      begin
        if user.not_blocked_and_in_group
  	      system_call = ApplicationController::send_email_dry(email_from.to_s, to.to_s, email_body, email.subject.to_s, '', smtp_connection, email[:format])

          unless (defined?(NO_EMAIL) && (NO_EMAIL.to_i == 1))
            status = _('Email_sent') if system(system_call)
          end
        end
      rescue
        return status
      end
    else
      status = _('Email_disabled')
    end
    status
  end

  def update_timezone_offsets
    timezones = ActiveSupport::TimeZone.all
    timezones.each do |timezone|
      find_timezone_by_name = Timezone.where("zone = \"#{timezone.name}\"").first
      tz_to_db = find_timezone_by_name.blank? ? Timezone.new : find_timezone_by_name
      tz_to_db.zone = timezone.name
      tz_to_db.offset = Time.now.in_time_zone("#{timezone.name}").utc_offset
      tz_to_db.save
    end
  end

  def allow_register?(owner)
    if owner
      less_than_two_users_owned = User.where(owner_id: owner).size < 2
      allow_reseller = case owner.try(:own_providers)
                         when 0
                           reseller_active?
                         when 1
                           reseller_pro_active?
                         else
                           false
                       end
      is_admin = (owner.try(:usertype) == 'admin')

      return less_than_two_users_owned || allow_reseller || is_admin
    else
      return false
    end
  end

  def set_time
    now = Time.now

    session[:year_from] = session[:year_till] = now.year
    session[:month_from] = session[:month_till] = now.month
    session[:day_from] = session[:day_till] = now.day

    session[:hour_from] = 0
    session[:minute_from] = 0

    session[:hour_till] = 23
    session[:minute_till] = 59
  end

  def get_logout_link(user_id)
    logout_link = Confline.get_value('Logout_link', user_id).to_s
    ((logout_link.include?('http') ? '' : 'http://') + logout_link)
  end

  def send_generated_invoices
    @invoices = Invoice.where(send_email: 1).all
    @default_currency_name = Currency.where(id: 1).first.name
    @invoice_owner = User.where(id: 0).first
    nice_numer_digits = Confline.get_value('Nice_Number_Digits')
    @nice_numer_digits = (nice_numer_digits.to_s.length) > 0 ? nice_numer_digits : 2
    @invoices.each do |invoice|
      user_invoice = invoice.user
      next if user_invoice.owner_id != 0
      attach = []
      prepaid = invoice.invoice_type.to_s == 'prepaid' ? 'Prepaid_' : ''
      invoice_type = user_invoice.send_invoice_types.to_i
      correct_owner_id = @invoice_owner.id

      if invoice_type.to_i != 0 && (user_invoice.email).length > 0
        invoice_type -= if invoice_type >= 512
                          xlsx = {
                            file: export_invoice_to_xlsx(invoice),
                            content_type: 'application/octet-stream',
                            filename: "#{_('invoice_xlsx')}.xlsx"
                          }
                          attach << xlsx
                          512
                        else
                          0
                        end
        if !(user_invoice.postpaid == 0 && invoice.invoicedetails.first.try(:name).to_s == 'Manual Payment')
          if (invoice_type % 2) == 1
            invoice_type = Confline.get_value("#{prepaid}Invoice_default", correct_owner_id).to_i
          end
          invoice_type -= if invoice_type >= 256
                            calls_cvs = {
                              file: get_prepaid_user_calls_csv(user_invoice, invoice),
                              content_type: 'text/csv',
                              filename: "#{_('Calls')}.csv"
                            }
                            attach << calls_cvs
                            256
                          else
                            0
                          end
          invoice_type -= if invoice_type >= 128
                            csv = {
                              file: generate_invoice_by_cid_csv(invoice, user_invoice),
                              content_type: 'text/csv',
                              filename: "#{_('Invoice_by_CallerID_csv')}.csv"
                            }
                            attach << csv
                            128
                          else
                            0
                          end
          invoice_type -= if invoice_type >= 64
                            csv = {
                              file: generate_invoice_destinations_csv(invoice, user_invoice),
                              content_type: 'text/csv',
                              filename: "#{_('Invoice_destinations_csv')}.csv"
                            }
                            attach << csv
                            64
                          else
                            0
                          end
          invoice_type -= if invoice_type >= 32
                            pdf = {
                              file: generate_invoice_by_cid_pdf(invoice, user_invoice),
                              content_type: 'application/pdf',
                              filename: "#{_('Invoice_by_CallerID_pdf')}.pdf"
                            }
                            attach << pdf
                            32
                          else
                            0
                          end
          invoice_type -= if invoice_type >= 16
                            csv = {
                              file: generate_invoice_detailed_csv(invoice, user_invoice),
                              content_type: 'text/csv',
                              filename: "#{_('Invoice_detailed_csv')}.csv"
                            }
                            attach << csv
                            16
                          else
                            0
                          end
          invoice_type -= if invoice_type >= 8
                            pdf = {
                              file: generate_invoice_detailed_pdf(invoice, user_invoice),
                              content_type: 'application/pdf',
                              filename: "#{_('Invoice_detailed_pdf')}.pdf"
                            }
                            attach << pdf
                            8
                          else
                            0
                          end
        end
        invoice_type -= if invoice_type >= 4
                          csv = {
                            file: generate_invoice_csv(invoice, user_invoice),
                            content_type: 'text/csv',
                            filename: "#{_('Invoice_csv')}.csv"
                          }
                          attach << csv
                          4
                        else
                          0
                        end
        if invoice_type >= 2
          pdf = {
            file: generate_invoice_pdf(invoice, user_invoice),
            content_type: 'application/pdf',
            filename: "#{_('Invoice_pdf')}.pdf"
          }
          attach << pdf
        end

        email = Email.where(name: 'invoices', owner_id: user_invoice.owner_id).first
        variables = Email.email_variables(user_invoice)
        email.body = nice_email_sent(email, variables)
        email_from = Confline.get_value('Email_from', correct_owner_id)

        if EmailsController.send_invoices(email, user_invoice.email.to_s, email_from, attach, invoice.number.to_s) == 'true'
          invoice.sent_email = 1
          invoice.send_email = 0
          invoice.save
        end
      end
    end
  end

  def generate_invoice_pdf(invoice, user)
    idetails = invoice.invoicedetails
    @invoices_status = user.get_invoices_status
    status = (@invoices_status[0] == 2)

    type = (user.postpaid.to_i == 1 || invoice.user.owner_id != 0) ? 'postpaid' : 'prepaid'

    dc = user.currency.name

    global_decimal = Confline.get_value('Global_Number_Decimal').to_s
    change_decimal = global_decimal.to_s == '.' ? false : true

    pdf, arr_t = invoice.
        generate_simple_pdf(@invoice_owner, dc, nice_invoice_number_digits(type), change_decimal, global_decimal, 1)

    filename = invoice.filename(type, 'pdf')

    return pdf.render
  end

  def generate_invoice_csv(invoice, user)
    @invoices_status = user.get_invoices_status
    status = (@invoices_status[1] == 4)

    sep, dec = user.csv_params
    global_decimal = Confline.get_value('Global_Number_Decimal').to_s
    change_decimal = global_decimal.to_s == '.' ? false : true
    nice_number_hash  = {change_decimal: change_decimal, global_decimal: global_decimal}

    dc = user.currency.name
    ex = invoice.exchange_rate(@default_currency_name, dc, @invoice_owner)

    csv_string = ["number#{sep}user_id#{sep}period_start#{sep}period_end#{sep}issue_date#{sep}price (#{dc})#{sep}price_with_tax (#{dc})#{sep}accounting_number"]
    csv_string << "#{invoice.number.to_s}#{sep}" +
        "#{nice_user(user)}#{sep}" +
        "#{nice_date(invoice.period_start, 0)}#{sep}" +
        "#{nice_date(invoice.period_end, 0)}#{sep}" +
        "#{nice_date(invoice.issue_date)}#{sep}" +
        "#{invoice.nice_invoice_number(invoice.converted_price(ex), nice_number_hash).to_s.gsub(".", dec).to_s}#{sep}" +
        "#{invoice.nice_invoice_number(invoice.converted_price_with_vat(ex), nice_number_hash).to_s.gsub(".", dec).to_s}#{sep}" +
        "#{user.accounting_number}"

    #  my_debug csv_string
    prepaid, prep = if invoice.invoice_type.to_s == 'prepaid' and user.owner_id == 0
      ['Prepaid_', 'prepaid']
    else
      ['', 'postpaid']
    end

    filename = invoice.filename(prep, 'csv', nil, dc)

    return csv_string.join("\n")
  end

  def get_prepaid_user_calls_csv(user, invoice)
    # CSV and decimal separators
    sep, dec = user.csv_params

    # Spare the function calls and get the visuals only once
    time_format = Confline.get_value('time_format', user.owner.id) || Confline.get_value('time_format', 0)
    hide_dst_end = user.hide_destination_end

    # Expost Call data on file (spare RAM)
    filename = invoice.generate_prepaid_csv

    # CSV header
    csv = "#{_('Date')}#{sep}#{_('Called_from')}#{sep}#{_('Called_to')}#{sep}#{_('Destination')}"\
      "#{sep}#{_('Duration')}#{sep}#{_('Price')} (#{_(session[:default_currency].to_s)})\n"

    # Date: 0, Source: 1, Destination: 2, Duration: 3, User price: 4, Destination name: 5
    CSV.foreach(filename) do |row|
      csv << "#{nice_date_time(row[0])}#{sep}#{row[1]}#{sep}"\
        "#{hide_dst_for_user(user, 'csv', row[2], hide_dst_end)}#{sep}"\
        "#{row[5]}#{sep}#{nice_time(row[3], false, time_format)}#{sep}"\
        "#{nice_number(row[4]).to_s.sub('.', dec)}\n"
    end

    csv

  rescue Errno::ENOENT
    MorLog.my_debug("ERROR: Prepaid Invoice File was not found!")
    return nil
  rescue Errno::EACCES
    MorLog.my_debug("ERROR: Prepaid Invoice File cannot be accessed!")
    return nil
  ensure
    # Remove the temporal file
    system "rm -rf #{filename}"
  end

  def generate_invoice_by_cid_csv(invoice, user)
    dc = user.currency.name
    ex = invoice.exchange_rate(@default_currency_name, dc, @invoice_owner)
    sep, dec = user.csv_params

    up, rp, pp = user.get_price_calculation_sqls
    zero_calls_sql = user.invoice_zero_calls_sql
    user_price = SqlExport.replace_price(up, { ex: ex })
    csv_s = []
    sql = "SELECT calls.src,
                  SUM(#{user_price}) as 'price',
                  COUNT(calls.id) AS calls_size,
                  CONCAT(devices.device_type, '/', devices.extension, ' (', SUBSTRING_INDEX(SUBSTRING_INDEX(devices.callerid, '<', -1), '>', 1), ')') AS nice_src_device
           FROM calls
           JOIN devices ON (calls.src_device_id = devices.id OR calls.dst_device_id = devices.id) #{SqlExport.left_join_reseler_providers_to_calls_sql}
           WHERE calls.card_id = 0 AND devices.user_id = #{user.id} AND calls.calldate
                 BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59'
                 AND calls.disposition = 'ANSWERED' AND billsec > 0 #{zero_calls_sql} GROUP BY calls.src;"

    cids = Call.find_by_sql(sql)

    if cids != []
      csv_s<< "CallerID/Device details#{sep}price(#{dc})#{sep}calls#{sep}"

      cids.each { |ci|
        csv_s << "#{ci.src} / #{ci.nice_src_device}" + sep.to_s + ci.price.to_d.to_s.gsub('.', dec).to_s + sep + ci.calls_size.to_i.to_s
      }
    end

    csv_s.join("\n")
  end

  def generate_invoice_destinations_csv(invoice, user)
    idetails = invoice.invoicedetails

    dc = user.currency.name
    ex = invoice.exchange_rate(@default_currency_name, dc, @invoice_owner)
    sep, dec = user.csv_params

    billsec_cond = Confline.get_value('Invoice_user_billsec_show', @invoice_owner.id).to_i == 1 ? 'user_billsec' : 'billsec'
    up, rp, pp = user.get_price_calculation_sqls
    user_price = SqlExport.replace_price(up, { ex: ex })

    csv_string = ["Invoice NO.:#{sep} #{invoice.number.to_s}"]
    csv_string << ''
    csv_string << "Invoice Date:#{sep} #{nice_date(invoice.period_start)} - #{nice_date(invoice.period_end)}"
    csv_string << ''
    csv_string << "Due Date:#{sep} #{nice_date(invoice.issue_date)}"
    csv_string << ''
    csv_string << ''

    sub = 0
    calls_to_dids_translation = _('Calls_To_Dids')

    idetails.each { |id|
      id_name = id.name

      if (id_name != 'Calls') && (id_name != calls_to_dids_translation)
        sub = 1
      end
    }

    if idetails
      if sub.to_i == 1
        csv_string << "services#{sep}price\n"
      end

      idetails.each { |id|
        id_name = id.name

        if id_name != 'Calls'
          if id.invdet_type > 0
            if id.quantity
              qt = id.quantity
              tp = qt * id.converted_price(ex) if id.converted_price(ex)
            else
              qt = ''
              tp = id.converted_price(ex)
            end
            csv_string << "#{nice_inv_name(id_name)}#{sep}#{nice_number(tp).to_s.gsub(".", dec).to_s}"
          elsif id_name == _('Did_owner_cost')
            qt = id.quantity
            tp = id.converted_price(ex) if id.converted_price(ex)
            csv_string << "#{nice_inv_name(id_name)}#{sep}#{nice_number(tp).to_s.gsub(".", dec).to_s}"
          elsif id_name == calls_to_dids_translation
            qt = id.quantity
            tp = id.converted_price(ex)
            csv_string << "#{nice_inv_name(id_name)}#{sep}#{nice_number(tp).to_s.gsub(".", dec).to_s}"
          elsif id_name == _('SMS')
            qt = id.quantity
            tp = id.converted_price(ex)
            csv_string << "#{nice_inv_name(id_name)}#{sep}#{nice_number(tp).to_s.gsub(".", dec).to_s}"
          end
        end
      }
    end
    csv_string << ''

    csv_string << _('Minimal_Charge_for_Calls') + " (#{dc})" + sep + nice_number(user.converted_minimal_charge(ex).to_d) if user.minimal_charge_enabled?

    csv_string << ''


    show_zero_calls = user.invoice_zero_calls.to_i
    if show_zero_calls == 0
      zero_calls_sql = " AND #{up} > 0 "
    else
      zero_calls_sql = ''
    end


    sql = "SELECT destinations.id, destinations.prefix as 'prefix', dir.name as 'country', destinations.name as 'dg_name', MAX(#{SqlExport.replace_price('calls.user_rate', { ex: ex })}) as 'rate', sum(IF(DISPOSITION='ANSWERED',1,0)) AS 'answered', Count(*) as 'all_calls', SUM(IF(DISPOSITION='ANSWERED',calls.#{billsec_cond},0)) as 'billsec', SUM(IF(DISPOSITION='ANSWERED',#{SqlExport.replace_price(pp, { ex: ex })},0)) as 'selfcost', SUM(IF(DISPOSITION='ANSWERED',#{user_price},0)) as 'price'  FROM calls
          JOIN devices ON (calls.src_device_id = devices.id OR calls.dst_device_id = devices.id)
          LEFT JOIN destinations ON (destinations.prefix = calls.prefix)
          LEFT JOIN directions as dir ON (destinations.direction_code = dir.code)
          #{SqlExport.left_join_reseler_providers_to_calls_sql}
          where calls.card_id = 0 AND devices.user_id = '#{user.id}' and calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59' #{zero_calls_sql} AND LENGTH(calls.prefix) > 0
          group by destinations.id, calls.user_rate ORDER BY destinations.direction_code ASC, destinations.id ASC"

    res = ActiveRecord::Base.connection.select_all(sql)

    if res != []
      csv_string << "country#{sep}rate#{sep}ASR %#{sep}calls#{sep}ACD#{sep}billsec#{sep}Sum"
    end
    res.each do |result|
      id = result['id'].to_s
      country = result['country'].to_s
      rate = result['rate'].to_s
      calls = result['answered']
      calls_dec = calls.to_d
      prefix = result['prefix'].to_s
      billsec = result['billsec'].to_s
      price = result['price'].to_s

      if calls.to_s.to_i > 0
        asr = (calls_dec / result['all_calls'].to_d) * 100
        acd = (result['billsec'].to_d / calls_dec).to_d
        country = country.to_s if idetails
        csv_string << "#{country + ' ' + prefix.to_s }#{sep}#{rate.to_s.gsub('.', dec).to_s}#{sep}#{nice_number(asr).to_s.gsub('.', dec).to_s}#{sep}#{calls.to_i}#{sep}#{nice_number(acd).to_s.gsub('.', dec).to_s}#{sep}#{billsec.to_i}#{sep}#{nice_number(price).to_s.gsub('.', dec).to_s}"
      else
        asr, acd = [0, 0]
      end
    end

    csv_string.join("\n")
  end

  def generate_invoice_by_cid_pdf(invoice, user)
    dc = user.currency.name
    ex = invoice.exchange_rate(@default_currency_name, dc, @invoice_owner)
    global_decimal = Confline.get_value('Global_Number_Decimal', @invoice_owner.id).to_s
    change_decimal = global_decimal.to_s == '.' ? false : true

    type = (user.postpaid.to_i == 1 || user.owner_id != 0) ? 'postpaid' : 'prepaid'
    if type.to_s == 'prepaid'
      decimals = Confline.get_value("Prepaid_Round_finals_to_2_decimals").to_i
    else
      decimals = Confline.get_value("Round_finals_to_2_decimals").to_i
    end
    decimals = (decimals == 1) ? 2 : @nice_numer_digits

    pdf, arr_t = invoice.generate_invoice_by_cid_pdf(@invoice_owner, dc, ex, decimals, change_decimal, global_decimal, false)
    pdf.render
  end

  def generate_invoice_detailed_csv(invoice, user)
    idetails = invoice.invoicedetails
    invoice_type_is_prepaid = (invoice.invoice_type.to_s.downcase == 'prepaid')

    dc = user.currency.name
    ex = invoice.exchange_rate(@default_currency_name, dc, @invoice_owner)
    sep, dec = user.csv_params

    owner = @invoice_owner.id
    prepaid = (invoice_type_is_prepaid && owner == 0) ? 'Prepaid_' : ''

    up, rp, pp = user.get_price_calculation_sqls
    billsec_cond = Confline.get_value("Invoice_user_billsec_show", owner).to_i == 1 ? 'user_billsec' : 'billsec'
    user_price = SqlExport.replace_price(up, { ex: ex })
    reseller_price = SqlExport.replace_price(rp, { ex: ex })
    partner_price = SqlExport.replace_price('calls.partner_price', { ex: ex })
    did_sql_price = SqlExport.replace_price('calls.did_price', { ex: ex, reference: 'did_price' })
    did_inc_sql_price = SqlExport.replace_price('calls.did_inc_price', { ex: ex, reference: 'did_inc_price' })
    selfcost = SqlExport.replace_price(pp, { ex: ex, reference: 'selfcost' })
    user_rate = SqlExport.replace_price('calls.user_rate', {ex: ex, reference: 'user_rate'})
    min_type = (Confline.get_value("#{prepaid}Invoice_Show_Time_in_Minutes", owner).to_i == 1) ? 1 : 0
    csv_string = []

    sub = 0
    idetails.each { |id| sub = 1 if id.invdet_type > 0 || id.name == _('Did_owner_cost') || id.name == _('SMS') }

    if idetails
      if sub.to_i == 1
        csv_string << "services#{sep}price"
      end

      idetails.each do |id|
        if id.invdet_type > 0
          if id.quantity
            qt = id.quantity
            tp = qt * id.converted_price(ex) if id.price
          else
            qt = ''
            tp = id.converted_price(ex)
          end
          csv_string << "#{nice_inv_name(id.name)}#{sep}#{nice_number(tp).to_s.gsub(".", dec).to_s}"
        elsif (id.name == _('Did_owner_cost')) || (id.name == _('SMS'))
          qt = id.quantity
          tp = id.converted_price(ex) if id.price
          csv_string << "#{nice_inv_name(id.name)}#{sep}#{nice_number(tp).to_s.gsub(".", dec).to_s}"
        end
      end
    end

    csv_string << _('Minimal_Charge_for_Calls') + " (#{dc})" + sep + nice_number(user.converted_minimal_charge(ex).to_d) if user.minimal_charge_enabled?
    show_zero_calls = user.invoice_zero_calls.to_i
    zero_calls_sql = (show_zero_calls == 0) ? " AND #{up} > 0 " : ''
    invoice_period_start, invoice_period_end = [invoice.period_start, invoice.period_end]

    sql = "SELECT #{user_rate}, destinationgroups.id, destinationgroups.flag as 'dg_flag', destinationgroups.name as 'dg_name',  COUNT(*) as 'calls', SUM(#{billsec_cond}) as 'billsec', #{selfcost}, SUM(#{user_price}) as 'price', dids.did as 'to_did' " +
        "FROM calls "+
        "LEFT JOIN dids on calls.did_id = dids.id AND dids.did = calls.dst "+
        "LEFT JOIN devices ON (calls.src_device_id = devices.id)
        LEFT JOIN destinations ON (destinations.prefix = calls.prefix)  "+
        "LEFT JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) #{SqlExport.left_join_reseler_providers_to_calls_sql}"+
        "WHERE calls.calldate BETWEEN '#{invoice_period_start} 00:00:00' AND '#{invoice_period_end} 23:59:59' AND calls.disposition = 'ANSWERED' " +
        " AND devices.user_id = '#{user.id}' AND calls.card_id = 0  #{zero_calls_sql}" +
        "GROUP BY destinationgroups.id, to_did, calls.user_rate "+
        "ORDER BY destinationgroups.name ASC"

    user_is_reseller = user.is_reseller?

    if user_is_reseller || user.is_partner?
      price, owner_id_sql = user_is_reseller ? [reseller_price, 'calls.reseller_id'] : [partner_price, 'calls.partner_id']

      reseller_select = "SELECT calls.dst,  COUNT(*) as 'count_calls', SUM(#{billsec_cond}) as 'sum_billsec', #{selfcost}, SUM(#{price}) as 'price', #{user_rate}  " +
          "FROM calls "+
          "#{SqlExport.left_join_reseler_providers_to_calls_sql} LEFT JOIN destinations ON (destinations.prefix = calls.prefix) LEFT JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) "+
          "WHERE calls.calldate BETWEEN '#{invoice_period_start} 00:00:00' AND '#{invoice_period_end} 23:59:59' AND calls.disposition = 'ANSWERED' " +
          " AND (#{owner_id_sql} = '#{user.id}' ) #{zero_calls_sql}" +
          "GROUP BY destinationgroups.id, calls.user_rate "+
          "ORDER BY destinationgroups.name ASC"
      result_on_reseller_select = ActiveRecord::Base.connection.select_all(reseller_select)
    end

    res = ActiveRecord::Base.connection.select_all(sql)

    if res != []
      csv_string << "number#{sep}accounting_number#{sep}country#{sep}type#{sep}rate#{sep}calls#{sep}billsec#{sep}price (#{dc})"
    end

    res && res.each do |result|
      country = ( !result['to_did'].to_s.blank?) ? _('Calls_To_Dids') : result['dg_name']
      calls = result['calls']
      billsec = result['billsec']
      rate = result['user_rate']
      price = result['price']
      csv_string << "#{invoice.number.to_s}#{sep}#{user.accounting_number.to_s.blank? ? ' ' : user.accounting_number.to_s}#{sep}#{country}#{sep}#{rate}#{sep}#{calls}#{sep}#{billsec}#{sep}#{nice_number(price).to_s.gsub('.', dec).to_s}"
    end

    req_user = user

    if user_is_reseller || (user.is_partner? && result_on_reseller_select)
      csv_string << "\n" + _('Calls_from_users') + ":"
      csv_string << "#{_('DID')}#{sep}#{_('Calls')}#{sep}#{_('Total_time')}#{sep}#{_('Price')}(#{dc})"
      result_on_reseller_select.each do |result|
        csv_string << "#{hide_dst_for_user(req_user, 'csv', result["dst"].to_s)}#{sep}#{result["count_calls"].to_s}#{sep}#{invoice_nice_time(result["sum_billsec"], min_type)}#{sep}#{nice_number(result['price']).to_s.gsub('.', dec).to_s}"
      end
    end

    csv_string.join("\n")
  end

  def generate_invoice_detailed_pdf(invoice, user)
    type = ((user.postpaid.to_i == 1) || (user.owner_id != 0)) ? 'postpaid' : 'prepaid'
    dc = user.currency.name
    global_decimal = Confline.get_value('Global_Number_Decimal', @invoice_owner.id).to_s
    change_decimal = global_decimal.to_s == '.' ? false : true
    pdf, arr_t = invoice.generate_invoice_detailed_pdf(@invoice_owner, dc, nice_invoice_number_digits(type), change_decimal, global_decimal, 1, false)

    pdf.render
  end

  def export_invoice_to_xlsx(invoice)
    require 'templateXL/x6_invoice_template'

    invoice_number = invoice.number
    inv_user_owner = @invoice_owner
    inv_user_owner.create_xlsx_conflines_if_not_exists
    inv_user_owner_id = @invoice_owner.id
    templates_name_ending = @invoice_owner.is_admin? ? '' : '_' + inv_user_owner_id.to_s
    template_path = "#{Actual_Dir}/public/invoice_templates/default#{templates_name_ending}.xlsx"
    file_path = "/tmp/mor/invoices/#{invoice_number}.xlsx"

    if File.exists?(file_path)
      data = File.open(file_path).try(:read)
      return data
    else
      invoice_template = TemplateXL::X6InvoiceTemplate.new(template_path, file_path, inv_user_owner_id)
      invoice_template.invoice, invoice_template.invoicedetails = invoice.copy_for_xslx
      invoice_template.generate

      invoice_template.save

      return invoice_template.content
    end
  end

  def nice_warning_email(user)
    user.warning_balance_email.blank? ? user.get_email_to_address.to_s : user.warning_balance_email
  end
end
