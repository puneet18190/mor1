# -*- encoding : utf-8 -*-
# Device managing.
class DevicesController < ApplicationController
  layout 'callc'
  before_filter :access_denied, only: [:user_device_edit], :if => lambda { session[:user_id] and not user? }
  before_filter :check_post_method, only: [:create, :update]
  before_filter :check_localization
  before_filter :authorize, except: [:pdffaxemail_add, :pdffaxemail_new, :pdffaxemail_edit, :pdffaxemail_update, :pdffaxemail_destroy]
  before_filter :find_email, only: [:pdffaxemail_edit, :pdffaxemail_update, :pdffaxemail_destroy]
  before_filter :find_fax_device, only: [:pdffaxemail_add, :pdffaxemail_new]
  before_filter :find_device, only: [:destroy, :device_edit, :device_update, :device_extlines, :device_dids,
    :try_to_forward_device, :device_all_details, :callflow, :callflow_edit, :user_device_edit, :user_device_update,
    :erase_ipaddr_fullcontact]
  before_filter :find_cli, only: [:change_email_callback_status, :change_email_callback_status_device, :cli_delete,
    :cli_user_delete, :cli_device_delete, :cli_edit, :cli_update, :cli_device_edit, :cli_user_edit, :cli_device_update,
    :cli_user_update]
  before_filter :verify_params, only: [:create]
  before_filter :check_callback_addon, only: [:change_email_callback_status, :change_email_callback_status_device]
  before_filter :find_provider, only: [:user_device_edit]
  before_filter :check_with_integrity, only: [:create, :device_update, :device_edit, :show_devices]
  before_filter :check_pbx_addon, only: [:callflow, :callflow_edit]
  before_filter :load_cli_params, only: [:cli_new, :cli_add]
  before_filter :erase_ipaddr_fullcontact, only: [:device_update]
  before_filter :set_action_for_pdffaxemail, only: [:pdffaxemail_new, :pdffaxemail_update, :pdffaxemail_destroy]
  before_filter :authorize_pdffaxemail, only: [:pdffaxemail_add, :pdffaxemail_new, :pdffaxemail_edit, :pdffaxemail_update, :pdffaxemail_destroy]

  before_filter(except: [:device_edit, :device_update]) { |method|
    view = [:device_clis, :clis, :cli_edit]
    edit = [:cli_new, :cli_add, :clis_banned_status, :cli_device_add, :change_email_callback_status,
      :change_email_callback_status_device, :cli_delete, :cli_device_delete, :cli_update]
    allow_read, allow_edit = method.check_read_write_permission(view, edit, { role: 'accountant',
      right:  :acc_user_manage, ignore: true })
    method.instance_variable_set :@allow_read, allow_read
    method.instance_variable_set :@allow_edit, allow_edit
    true
  }

  before_filter { |method|
    view = [:index, :new, :edit, :device_edit, :show_devices, :device_extlines, :device_dids, :forwards,
      :group_forwards, :cli_edit, :device_clis, :clis, :device_all_details, :default_device, :get_user_devices]
    edit = [:create, :destroy, :device_update, :device_forward, :try_to_forward_device, :cli_new, :cli_add,
      :cli_device_add, :change_email_callback_status, :clis_banned_status, :change_email_callback_status_device,
      :cli_delete, :cli_device_delete, :cli_update, :cli_device_edit, :cli_device_update, :pdffaxemail_add,
      :pdffaxemail_new, :pdffaxemail_edit, :pdffaxemail_update, :pdffaxemail_destroy, :default_device_update,
      :assign_provider]
    allow_read, allow_edit = method.check_read_write_permission(view, edit, { role: 'accountant',
      right: :acc_device_manage, ignore: true })
    method.instance_variable_set :@allow_read, allow_read
    method.instance_variable_set :@allow_edit, allow_edit
    true
  }

  def index
    redirect_to action: 'user_devices' and return false
  end

  def new
    @page_title, @page_icon = [_('New_device'), 'add.png']
    @ccl_active = ccl_active?

    if reseller?
      reseller = User.where(id: session[:user_id]).first
      reseller.check_reseller_conflines
    end

    @user = User.where(id: params[:user_id]).first
    user = @user

    unless user
      flash[:notice] = _('User_was_not_found')
      redirect_to action: 'index' and return false
    end

    if ['admin', 'accountant', 'reseller'].include?(user.usertype)
      flash[:notice] = _('Deprecated_functionality') +
        " <a href='http://wiki.kolmisoft.com/index.php/Deprecated_functionality' target='_blank'><img alt='Help' " +
        "src='#{Web_Dir}/images/icons/help.png'/></a>".html_safe
      (redirect_to :root) && (return false)
    end

    check_owner_for_device(user)
    check_for_accountant_create_device

    device_type = Confline.get_value('Default_device_type', correct_owner_id)
    @device = Device.new(device_type: device_type, pin: new_device_pin)
    @devicetypes = Devicetype.load_types('dahdi' => allow_dahdi?, 'Virtual' => allow_virtual?)
    @device_type = device_type ||= 'SIP'
    @audio_codecs, @video_codecs = [audio_codecs, video_codecs]
    @devgroups = user.devicegroups
    @ip_first, @mask_first, @ip_second, @mask_second, @ip_third, @mask_third = @device.perims_split
    device_qualify = @device.qualify
    @qualify_time = (device_qualify == 'no') ? 2000 : device_qualify
    @pdffaxemails = []
    @new_device = true
    @fax_enabled = session[:fax_device_enabled]
  end

  def create
    sanitize_device_params_by_accountant_permissions
    user = User.where(id: params[:user_id]).includes(:address).first

    unless user
      flash[:notice] = _('User_was_not_found')
      redirect_to action: 'index' and return false
    end

    session_device = session[:device]
    session_device_pin = session_device[:pin] if session_device
    params[:device][:pin] = session_device_pin if session_device_pin
    notice, par = Device.validate_before_create(current_user, user, params, allow_dahdi?, allow_virtual?)

    if !notice.blank?
      flash[:notice] = notice
      (redirect_to :root) && (return false)
    end

    fextension = DeviceFreeExtension.take_extension
    par_device = par[:device]
    device = user.create_default_device({ device_ip_authentication_record: par[:ip_authentication].to_i,
      description: par_device[:description], device_type: par_device[:device_type],
      dev_group: par_device[:devicegroup_id], free_ext: fextension, secret: random_password(12),
      username: fextension, pin: par_device[:pin] })

    @sip_proxy_server = Server.where("server_type = 'sip_proxy'").first
    device.set_server(device, ccl_active?, @sip_proxy_server, reseller?)
    device.set_ports(params[:port])
    device.adjust_insecurities(ccl_active?, params)
    device.comment = params[:device][:comment] if params[:device]

    device_id = device.id
    if device.save
      device.create_server_relations(device, @sip_proxy_server, ccl_active?)
      flash[:status] = device.check_callshop_user(_('device_created'))
      conf_extensions = configure_extensions(device_id, { current_user: current_user, api: 1 })
      # no need to create extensions, prune peers, etc when device is created, because user goes to edit window
      # and all these actions are done in device_update
      device.send_email_device_changes_announcement
    else
      flash_errors_for(_('device_was_not_created'), device)
      redirect_to controller: 'devices', action: 'show_devices', id: user.id and return false
    end

    redirect_to controller: 'devices', action: 'device_edit', id: device_id and return false
  end

  def edit
    @user = User.where(id: params[:id]).first

    unless @user
      flash[:notice] = _('User_was_not_found')
      redirect_to action: :index and return false
    end

    @ccl_active = ccl_active?
  end

  # in before filter : device (:find_device)
  def destroy
    @return_controller, @return_action = ['devices', 'show_devices']
    set_return_controller
    set_return_action

    device_user_id = @device.user_id
    return false unless check_owner_for_device(device_user_id)

    notice = @device.validate_before_destroy(current_user, @allow_edit)

    if !notice.blank?
      flash[:notice] = notice
      redirect_to controller: @return_controller, action: @return_action, id: device_user_id and return false
    else
      @device.destroy_all
    end

    flash[:status] = _('device_deleted')
    redirect_to controller: @return_controller, action: @return_action, id: device_user_id
  end

  def show_devices
    devices_title_and_icon
    @help_link = 'http://wiki.kolmisoft.com/index.php/Devices'

    @user = User.where(['id = ? AND (owner_id = ? or users.id = ?)', params[:id], correct_owner_id, current_user_id])
                .includes(:devices).first
    user = @user

    unless user.try :is_user?
      flash[:notice] = _('User_not_found')
      (redirect_to :root) && (return false)
    end

    dev_owner = check_owner_for_device(user)
    return false unless dev_owner

    @return_controller, @return_action = ['users', 'list']
    set_return_controller
    set_return_action

    set_page_and_devices_for_it(user.devices)

    @provdevices = Device.
      where(["devices.user_id = '-1' AND providers.user_id = ? AND providers.hidden = 0", current_user_id]).
      joins('JOIN providers ON (providers.device_id = devices.id)').order('providers.name')

    store_location
  end

  # in before filter : device (:find_device)
  def device_edit
    @page_title, @page_icon = [_('device_settings'), 'edit.png']
    set_return_controller
    set_return_action

    if reseller?
      reseller = User.where(id: session[:user_id]).first
      reseller.check_reseller_conflines
    end

    @user = @device.user
    return false unless check_owner_for_device(@user)

    if @device.name.to_s.match(/\Amor_server_\d+\z/)
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    @device_type = @device.device_type
    device_type = @device_type
    @device_trunk = @device.trunk

    set_cid_name_and_number

    @server_devices = []
    @device.server_devices.each { |dev| @server_devices[dev.server_id] = 1 }

    @device_dids_numbers = @device.dids_numbers
    @device_cids = @device.cid_number
    @device_caller_id_number = @device.device_caller_id_number

    get_number_pools
    load_devicetypes

    @audio_codecs = @device.codecs_order('audio')
    @video_codecs = @device.codecs_order('video')
    @devgroups = @user.devicegroups
    get_locations
    @dids = @device.dids
    @all_dids = Did.forward_dids_for_select

    #-------multi server support------

    @asterisk_servers = Server.where("server_type = 'asterisk'").order('id ASC')
    @sip_proxy_server = [Server.where("server_type = 'sip_proxy'").first]

    set_servers(device_type)

    #------ permits --------
    @ip_first, @mask_first, @ip_second, @mask_second, @ip_third, @mask_third = @device.perims_split

    #------ advanced --------
    set_qualify_time
    @extension = @device.extension
    @fax_enabled = session[:fax_device_enabled]
    @pdffaxemails = @device.pdffaxemails
    @global_tell_balance = Confline.get_value('Tell_Balance').to_i
    @global_tell_time = Confline.get_value('Tell_Time').to_i

    #TP/OP related
    get_tariffs
    @routing_algorithms = [[_('LCR'), 'lcr'], [_('Quality'), 'quality'], [_('Profit'), 'profit'],
      [_('weight'), 'weight'], [_('Percent'), 'percent']]

    set_voicemail_variables(@device)

    render :device_edit_h323 if device_type == "H323"
  end

  # in before filter : device (:find_device)
  def device_update
    unless @allow_edit
      flash[:notice] = _('You_have_no_editing_permission')
      (redirect_to :root) && (return false)
    end

    unless params[:device]
      (redirect_to :root) && (return false)
    end

    # if higher than zero -> do not update device
    device_update_errors = 0

    change_pin = !(accountant? && session[:acc_device_pin].to_i != 2)
    change_opt_first = !(accountant? && session[:acc_device_edit_opt_1].to_i != 2)
    change_opt_second = !(accountant? && session[:acc_device_edit_opt_2].to_i != 2)
    change_opt_third = !(accountant? && session[:acc_device_edit_opt_3].to_i != 2)
    change_opt_fourth = !(accountant? && session[:acc_device_edit_opt_4].to_i != 2)

    return false unless check_owner_for_device(@device.user)
    @device_old = @device.dup
    @device.set_old_name

    params[:device][:description] = params[:device][:description].to_s.strip
    device_type = @device.device_type

    if ['SIP', 'IAX2'].include?(device_type)
      if params[:ip_authentication_dynamic].to_i > 0
        params[:dynamic_check]  = (params[:ip_authentication_dynamic].to_i == 2) ? 1 : 0
        params[:ip_authentication] = (params[:ip_authentication_dynamic].to_i == 1) ? 1 : 0
      else
        @device.username.blank? ? params[:ip_authentication] = 1 :  params[:dynamic_check] = 1
      end
    end

    device_type_is_sip = (device_type == 'SIP')
    device_type_is_H323 = (device_type == 'H323')
    device_type_is_iax = (device_type == 'IAX2')
    device_type_not_virtual = (device_type != 'Virtual')
    device_type_not_fax = (device_type != 'FAX')
    params[:ip_authentication] = 1 if device_type_is_H323

    load_devicetypes

    @devicetypes = @devicetypes.map { |devtipe| devtipe.name }
    @devicetypes << 'FAX'

    unless @devicetypes.include?(params[:device][:device_type].to_s)
      params[:device][:device_type] = device_type
    end

    if params[:add_to_servers].blank? &&
        params[:device][:server_id].blank? &&
        !reseller? && device_type != 'FAX' &&
        !([:SIP, :IAX2, :Virtual].include?(device_type.try(:to_sym)) && ccl_active?)

      @device.errors.add(:add_to_servers_error, _('Please_select_server'))
      device_update_errors += 1
    end

    #============multi server support===========
    @asterisk_servers = Server.where("server_type = 'asterisk'").order('id ASC')
    @sip_proxy_server = [Server.where("server_type = 'sip_proxy'").first]

    set_servers(device_type)

    #========= Reseller device server ==========

    if reseller?
      if ccl_active? and params[:device][:device_type] == "SIP" # and params[:dynamic_check] == 1
        params[:add_to_servers] = @sip_proxy_server
      else
        first_srv = Server.first.id
        def_asterisk = Confline.get_value('Resellers_server_id').to_i
        if def_asterisk.to_i == 0
          def_asterisk = first_srv
        end
        params[:device][:server_id] = def_asterisk
      end
    end
    #===========================================

    change_pin == true ? params[:device][:pin]=params[:device][:pin].to_s.strip : params[:device][:pin] = @device.pin
    unless (accountant? and session[:acc_user_create_opt_7].to_i != 2) # can accountant change call_limit?
      if params[:call_limit]
        params[:device][:call_limit] = params[:call_limit].to_s.strip
        if params[:call_limit].to_i < 0
          params[:device][:call_limit] = 0
        end
      end
    end
    if !ccl_active?
      @device.server_id = params[:device][:server_id] if params[:device] && params[:device][:server_id]
    end

    #========================== check input ============================================

    #because block_callerid input may be disabled and it will not be sent in
    #params and setter will not be triggered and value from enabled wouldnt be
    #set to disabled, so i we have to set it here. you may call it a little hack
    params[:device][:block_callerid] = 0 if params[:block_callerid_enable].to_s == 'no'

    if device_type_not_virtual
      if params[:device][:extension]
        params[:device][:extension] = change_opt_first ? params[:device][:extension].to_s.strip : @device.extension
      end

      params[:device][:timeout] = params[:device_timeout].to_s.strip
    end

    device_is_dahdi = @device.is_dahdi?
    not_new_device = !@new_device

    if not_new_device && device_type_not_virtual
      set_params_device_name(change_opt_second)

      unless device_is_dahdi
        params[:device][:secret] = change_opt_second ? params[:device][:secret].to_s.strip : @device.secret
      end
    end

    if not_new_device && device_type_not_fax
      device_callerid = @device.callerid

      if change_opt_third
        params[:cid_number] = params[:cid_number].to_s.strip
        params[:device_caller_id_number] = params[:device_caller_id_number].to_i
      else
        params[:device_caller_id_number] = 1
        params[:cid_number] = cid_number(device_callerid)
      end

      params[:cid_name] = change_opt_fourth ? params[:cid_name].to_s.strip : nice_cid(device_callerid)

      if device_type_not_virtual
        unless device_is_dahdi
          params[:host] = params[:host].to_s.strip
          params[:port] = params[:port].to_s.strip if @device.host != 'dynamic'

          if ccl_active? and device_type_is_sip # and (@device.host == "dynamic" or @device.host.blank?)
            qualify = 2000
            params[:qualify] = 'no'
            params[:qualify_time] = qualify
          else
            qualify =  params[:qualify_time].to_s.strip.to_i
            qualify = 2000 unless params[:qualify_time]

            if qualify < 500
              @device.errors.add(:qualify, _('qualify_must_be_greater_than_500'))
              device_update_errors += 1
            end

            params[:qualify_time] = qualify
          end
        end

        params[:callgroup]=params[:callgroup].to_s.strip
        params[:pickupgroup]=params[:pickupgroup].to_s.strip

        if @device.voicemail_box
          params[:vm_email] = params[:vm_email].to_s.strip
          params[:vm_psw] = params[:vm_psw].to_s.strip
        end

        unless device_is_dahdi
          [:ip_first, :ip_second, :ip_third, :mask_first, :mask_second, :mask_third].each do |var|
            params[var] = params[var].to_s.strip
          end

          if device_type_is_sip
            params[:fromuser]=params[:fromuser].to_s.strip if params[:fromuser]
            params[:fromdomain]=params[:fromdomain].to_s.strip if params[:fromdomain]
            params[:custom_sip_header] = params[:custom_sip_header].to_s.strip if params[:custom_sip_header]
          end
        end
      end

      params[:device][:tell_rtime_when_left]=params[:device][:tell_rtime_when_left].to_s.strip
      params[:device][:repeat_rtime_every]=params[:device][:repeat_rtime_every].to_s.strip
      params[:device][:qf_tell_time] = params[:device][:qf_tell_time].to_i
      params[:device][:qf_tell_balance] = params[:device][:qf_tell_balance].to_i
    end

    #============================= end  ============================================================

    recording_email = params[:device][:recording_email]

    if params[:device][:recording_to_email].to_i == 1 && recording_email.to_s.length == 0
      @device.errors.add(:recording_to_email_error, _('Recordings_email_should_be_set_when_send_recordings_to_email_is_YES'))
      device_update_errors += 1
    end

    if recording_email.present? && !Email.address_validation(recording_email)
      @device.errors.add(:recording_to_email_error, _('Recordings_email_not_valid'))
      device_update_errors += 1
    end


    params_device_name = params[:device][:name].to_s
    if params_device_name.scan(/[^\w\.\@\$\-]/).compact.size > 0
      @device.errors.add(:device_name_error, _('Device_username_must_consist_only_of_digits_and_letters'))
      device_update_errors += 1
    end

    if %w[anonymous unknown].include?(params_device_name.downcase)
      @device.errors.add(:device_name_error, _('Device_username_not_allowed'))
      device_update_errors += 1
    end

    @device, device_update_errors = Device.validate_ip_address_format(params, @device, device_update_errors, prov = 0)

    #ticket 5055. ip auth or dynamic host must checked
    if params[:dynamic_check].to_i != 1 and params[:ip_authentication].to_i != 1 and ['SIP', 'IAX2'].include?(device_type)
      if params[:host].to_s.strip.blank?
        @device.errors.add(:dynamic_check_error, _('Must_set_either_ip_auth_either_dynamic_host'))
        device_update_errors += 1
      else
        params[:ip_authentication] = '1'
      end
    end

    new_extension = params[:device][:extension]
    if new_extension != @device_old.extension
      if extension_exists?(new_extension, @device_old.extension) && extension_used_in_pool?(@device, new_extension)
        @device.errors.add(:extension_error, _('Extension_is_used'))
        device_update_errors += 1
      end
    end
      #pin
      if (Device.where(["id != ? AND pin = ?", @device.id, params[:device][:pin]]).first and params[:device][:pin].to_s != "")
        @device.errors.add(:pin_is_used_error, _('Pin_is_already_used'))
        device_update_errors += 1
      end
      if params[:device][:pin].to_s.strip.scan(/[^0-9]/).compact.size > 0
        @device.errors.add(:not_numeric_pin_error, _('Pin_must_be_numeric'))
        device_update_errors += 1
      end
      @device.device_ip_authentication_record = params[:ip_authentication].to_i
      params[:device] = params[:device].reject { |key, value| ['extension'].include?(key.to_s) } if current_user.usertype == 'reseller' and Confline.get_value('Allow_resellers_to_change_extensions_for_their_user_devices').to_i == 0

      if (params[:device][:pin].blank?) && (current_user.usertype == 'reseller') && !(Confline.get_value('Allow_resellers_change_device_PIN').to_i == 1)
        params[:device][:pin] = @device.pin
      end

      # Keep default value NULL if parameter value is empty or 0
      params[:device]['session-timers'] = nil if params[:device]['session-timers'].blank?
      params[:device]['session-refresher'] = nil if params[:device]['session-refresher'].blank?
      params[:device]['session-minse'] = nil if params[:device]['session-minse'].to_i == 0
      params[:device]['session-expires'] = nil if params[:device]['session-expires'].to_i == 0

      @device.attributes = params[:device]
      # if reseller and location id == 1, create default location and set new location id
      if @device.location_id == 1 and reseller?
        @device.location_id = Confline.get_value("Default_device_location_id", current_user_id)
        @device.save
      end

      @device.name = '' if @device.name.include?('ipauth') and params[:ip_authentication].to_i == 0
      # do not leave empty name
      if @device.name.to_s.length == 0
        if @device.host.length > 0
          @device.name = @device.extension
        else
          @device.name = random_password(10)
        end
      end

      if params[:process_sipchaninfo].to_s == '1'
        @device.process_sipchaninfo = 1
      else
        @device.process_sipchaninfo = 0
      end

      if params[:ip_authentication].to_s == '1'

        @device.username = ''
        @device.secret = ''
        if !@device.name.include?('ipauth')
          name = @device.generate_rand_name('ipauth', 8)
          while Device.where(['name= ? and id != ?', name, @device.id]).first
            name = @device.generate_rand_name('ipauth', 8)
          end
          @device.name = name
        end
      else
        device_is_virtual = @device.virtual?
        @device.username = @device.name if !device_is_virtual

        if !@device_old.virtual? && device_is_virtual
          @device.check_device_username
        end
      end

      if (device_update_errors == 0) && device_type_not_fax
        @device.update_cid(params[:cid_name], params[:cid_number], true)
        @device.assign_attributes({
          cid_from_dids: params[:device_caller_id_number].to_i == 3 ? 1 : 0,
          control_callerid_by_cids: params[:device_caller_id_number].to_i == 4 ? params[:control_callerid_by_cids].to_i : 0,
          callerid_advanced_control: params[:device_caller_id_number].to_i == 5 ? 1 : 0
        })

        if admin? || reseller?
          @device.callerid_number_pool_id = params[:device_caller_id_number].to_i == 7 ? params[:callerid_number_pool_id].to_i : 0
        end

        if device_type_is_sip
          @device.copy_name_to_number = params[:device_caller_id_number].to_i == 8 ? 1 : 0
        end
      end

      #================ codecs ===================

      @device.update_codecs_with_priority(params[:codec], false) if params[:codec]
      #============= PERMITS ===================
      if params[:mask_first]
        if !Device.validate_permits_ip([params[:ip_first], params[:ip_second], params[:ip_third], params[:mask_first], params[:mask_second], params[:mask_third]])
          @device.errors.add(:allowed_ip_is_not_valid_error, _('Allowed_IP_is_not_valid'))
          device_update_errors += 1
        else
          @device.permit = Device.validate_perims({ ip_first: params[:ip_first], ip_second: params[:ip_second],
            ip_third: params[:ip_third], mask_first: params[:mask_first], mask_second: params[:mask_second],
            mask_third: params[:mask_third]})
        end
      end

      #------ advanced --------

      if params[:qualify] == 'yes'
        @device.qualify = params[:qualify_time]
        @device.qualify == '2000' if @device.qualify.to_i < 500
      else
        @device.qualify = 'no'
      end

      #------- Network related -------
      if not_new_device and device_type_is_H323 and
        params[:host].to_s.strip !~ /^\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b$/
        @device.errors.add(:invalid_ip_address_error, _('Invalid_IP_address'))
        device_update_errors += 1
      end

      @device.host = params[:host]
      @device.host = 'dynamic' if params[:dynamic_check].to_i == 1

      if @device.host != 'dynamic'
        @device.ipaddr = @device.host
      end

      # IAX2 Trunking Mode
      if device_type.downcase == 'iax2'
        @device.trunk = params[:iax2_trunking]
      end

      #ticket #4978, previuosly there was a validation to disallow ports lower than 100
      #we have doubts whether this made any sense. so user now can set port to any positive integer
      @device.port = params[:port] if params[:port]
      not_valid_port = !Device.valid_port?(params[:port], device_type)
      @device.port = Device::DefaultPort['IAX2'] if device_type_is_iax and not_valid_port
      @device.port = Device::DefaultPort['SIP'] if device_type_is_sip and not_valid_port
      @device.port = Device::DefaultPort['H323'] if device_type_is_H323 and not_valid_port

      params_zero_port_eq_one = params[:zero_port].to_i == 1

      @device.proxy_port = ccl_active? && device_type_is_sip && params_zero_port_eq_one ? 0 : @device.port

      @device.port = 0 if params[:port].blank? && device_type_is_H323 && params_zero_port_eq_one

      #------Trunks-------
      @device.istrunk, @device.ani = Device.find_istrunk_and_ani(params[:trunk].to_i)

      if admin? or accountant?
        #------- Groups -------
        @device.callgroup = params[:callgroup]
        @device.pickupgroup = params[:pickupgroup]
      end

      #------- Advanced -------
      @device.fromuser = params[:fromuser]
      @device.fromuser = nil if !params[:fromuser] or params[:fromuser].length < 1

      @device.fromdomain = params[:fromdomain]
      @device.fromdomain = nil if !params[:fromdomain] or params[:fromdomain].length < 1
      @device.grace_time = params[:grace_time]

      @device.custom_sip_header = params[:custom_sip_header].blank? ? '' : params[:custom_sip_header]

      @device.forward_did_id = Did.select('id').where(["did = ?", params[:forward_did].to_s]).first.id rescue -1

      @device.adjust_insecurities(ccl_active?, params)

      # check for errors
      @device.host = 'dynamic' unless @device.host
      @device.transfer = 'no' unless @device.transfer
      @device.canreinvite = 'no' unless @device.canreinvite
      @device.port = '0' unless @device.port
      @device.ipaddr = '' unless @device.ipaddr
      @device[:timeout] = 10 if @device[:timeout].to_i < 10
      @device.tp_tariff_id = params[:device][:tp_tariff_id].to_i

      if params[:vm_email].present?
        if !Email.address_validation(params[:vm_email])
          @device.errors.add(:incorrect_email_error, _('Voice_email_not_valid'))
          device_update_errors += 1
        end
      end

      @device.mailbox = @device.enable_mwi.to_i == 0 && @device.subscribemwi == 'no' ? '' : @device.extension.to_s + '@default'

      ((@device.context) && (@device.op == 1)) ? @device.context = 'm2' : @device.context = 'mor_local'
      if device_update_errors == 0 && @device.save

        # -------------- modify extlines if extension have changed --------
        if @device_old.extension != params[:device][:extension]
          modify_extlines(@device_old.extension)
        end

        #----------server_devices table changes---------
        if ccl_active? && device_type_is_iax
          server_id = Server.where(id: params[:device][:server_id].to_i).first.try(:id)
          device_id = @device.id

          unless ServerDevice.where(server_id: server_id, device_id: device_id).first
            ServerDevice.where(device_id: device_id).destroy_all
            server_device = ServerDevice.new_relation(server_id, device_id)
            server_device.save
          end
        # Ticket #11115 - if SIP device has IP auth, assign all asterisk servers
        elsif ccl_active? && device_type == 'SIP'
          if params[:ip_authentication].to_i == 1
            @device.reassign_device_relation(:asterisk)
          elsif params[:dynamic_check] == 1
            @device.reassign_device_relation(:sip_proxy)
          end
        elsif ccl_active? && !([:FAX, :Virtual].include?(device_type.try(:to_sym)))
          @device.create_server_devices(params[:add_to_servers])
        elsif !ccl_active?
          @device.create_server_devices({ params[:device][:server_id].to_s => '1' })
        end
        # Assign FAX device to all available asterisk servers
        @device.reassign_device_relation(:asterisk) if device_type == 'FAX'

  # ---------------------- VM --------------------
        old_vm = (vm = @device.voicemail_box).dup

        vm.email = params[:vm_email].presence
        deletevm = params[:deletevm].presence
        if !(accountant? && session[:acc_voicemail_password].to_i != 2)
          vm.password = params[:vm_psw]
        end

        if params[:device][:extension]
          params[:device][:extension].gsub!("'", %q(\\\'))
        end

        context = @device.user.pbx_pool_id > 1 ? "pool_#{@device.user.pbx_pool_id}" : "default"
        sql = "UPDATE voicemail_boxes SET context = '#{context}', mailbox = '#{@device.extension}', email = '#{vm.email}', password = '#{vm.password}', `delete` = '#{deletevm}' WHERE uniqueid = #{vm.id}"
        ActiveRecord::Base.connection.update(sql)

        # cleaning asterisk cache when device details changes
        device_old_name, device_old_server = [@device.device_old_name, @device.device_old_server]

        if (@device.name != device_old_name) || (@device.server_id != device_old_server)
          @device.sip_prune_realtime_peer(device_old_name, device_old_server)
        end

        # check_asterisk_status
        server = Server.where(id: @device.server_id).first

        if server.server_type == 'asterisk'
          status_notice = server.check_asterisk_status

          if status_notice.present?
            flash[:notice] = status_notice
            flash[:notice] += "<a href='http://wiki.kolmisoft.com/index.php/GUI_Error_-_SystemExit' target='_blank'><img alt='Help' src='#{Web_Dir}/images/icons/help.png' title='#{_('Help')}' />&nbsp;#{_('Click_here_for_more_info')}</a>" if admin?
            (redirect_to :root) && (return false)
          end
        end

        conf_extensions = configure_extensions(@device.id, { current_user: current_user })
        return false unless conf_extensions
        @devices_to_reconf = Callflow.where(device_id: @device.id, action: :forward, data2: 'local')

        @devices_to_reconf.each { |call_flow|
          call_flow_data = call_flow.data.to_i

          if call_flow_data > 0
            conf_extensions = configure_extensions(call_flow_data, { current_user: current_user })
            return false unless conf_extensions
          end
        }

        flash[:status] = _('phones_settings_updated')
        session_user_id = session[:user_id]

        # actions to report who changed what in device settings
        device_old_pin, device_old_secret, old_vm_password = [@device_old.pin, @device_old.secret, old_vm.password]

        if device_old_pin.to_s.strip != @device.pin.to_s.strip
          Action.add_action_hash(session_user_id, { target_id: @device.id, target_type: 'device',
            action: :device_pin_changed, data: device_old_pin, data2: @device.pin })
        end

        if device_old_secret.to_s.strip != @device.secret.to_s.strip
          Action.add_action_hash(session_user_id, { target_id: @device.id, target_type: 'device',
            action: :device_secret_changed, data: device_old_secret, data2: @device.secret })
        end

        if old_vm_password.to_s.strip != vm.password.to_s.strip
          Action.add_action_hash(session_user_id, { target_id: @device.id, target_type: 'device',
            action: :device_voice_mail_password_changed, data: old_vm_password, data2: vm.password })
        end

        # Reloading reload_sip_keeprt if required
        ip_address = @device.ipaddr.to_s
        old_ip, new_ip = [!!@device_old.ipaddr.to_s.match(/^.*(\/|\-).*$/), !!ip_address.match(/^.*(\/|\-).*$/)]

        if (new_ip && ip_address != @device_old.ipaddr.to_s) || (!new_ip && old_ip) || ip_range_subnet(ip_address)
          @device.reload_sip_keeprt
        end

        @device.send_email_device_changes_announcement

        redirect_to(action: :show_devices, id: @device_old.user_id) && (return false)
      else
        flash_errors_for(_('Device_not_updated'), @device)

        @server_devices = params[:add_to_servers].respond_to?(:keys) ? params[:add_to_servers].keys.map(&:to_i) : []
        @user = @device.user
        @device_type = device_type
        @all_dids = Did.forward_dids_for_select

        @device_dids_numbers = @device.dids_numbers
        @device_cids = params[:cid_number].to_s
        @device_caller_id_number = params[:device_caller_id_number].to_i
        @cid_name = params[:cid_name].to_s.strip
        @cid_number = params[:cid_number].to_s.strip

        @devicetypes  = @device.load_device_types('dahdi' => allow_dahdi?, 'Virtual' => allow_virtual?)
        @audio_codecs = audio_codecs
        @video_codecs = video_codecs

        @devgroups = @device.user.devicegroups
        get_locations

        @dids = @device.dids

        #------ permits --------

        @ip_first, @mask_first, @ip_second, @mask_second, @ip_third, @mask_third = @device.perims_split

        #------ advanced --------
        set_qualify_time

        @extension = @device.extension
        @fax_enabled = session[:fax_device_enabled]
        @pdffaxemails = @device.pdffaxemails

        @device_voicemail_box_email = params[:vm_email].to_s.strip
        @device_voicemail_box_password = params[:vm_psw].to_s.strip
        @device_deletevm = params[:deletevm].to_s.strip
        @device_enable_mwi = params[:device][:enable_mwi].to_i
        @device_subscribemwi = params[:device][:subscribemwi]
        @device_voicemail_active = @device.voicemail_active
        @device_voicemail_box = @device.voicemail_box
        @fullname = params[:vm_fullname].to_s.strip

        get_number_pools

        #TP/OP related
        get_tariffs
        @routing_algorithms = [[_('LCR'), 'lcr'], [_('Quality'), 'quality'], [_('Profit'), 'profit'], [_('weight'), 'weight'], [_('Percent'), 'percent']]

        if device_type_is_H323
          render :device_edit_h323
        else
          render :device_edit
        end
      end
  end

  # in before filter : device (:find_device)
  def device_extlines
    @page_title = _('Ext_lines')
    @page_icon = 'asterisk.png'

    if !@extlines = @device.extlines
      @extlines = nil
    end

    @user = @device.user

    if params[:context] == :show
      render(layout: false)
    end
  end

  # in before filter : device (:find_device)
  def device_dids
    @page_title = _('dids')
    @user = @device.user
    check_owner_for_device(@user)

    if !@dids = @device.dids
      @dids = nil
    end

    if params[:context] == :show
      render(layout: false)
    end
  end

  def device_forward
    @page_title = _('Device_forward')
    @page_icon = 'forward.png'

    if params[:group]
      @group = Group.where(id: params[:group]).first
      @devices = []
      for user in @group.users
        for device in user.devices
          @devices << device
        end
      end
    else
      @devices = Device.where("name not like 'mor_server_%'").order(:extension)
    end

    @device = Device.where(id: params[:id]).first
    @user = @device.user
  end

  # in before filter : device (:find_device)
  def try_to_forward_device
    @fwd_to = params[:select_fwd]
    fwd_to = @fwd_to
    fwd_to_not_zero = (fwd_to != '0')
    can_fwd = true

    device_fwd_to = Device.where(id: fwd_to).first if fwd_to_not_zero || can_fwd
    device_id = @device.id

    if fwd_to_not_zero
      #checking can we forward
      device = device_fwd_to
      device_forward_to = device.forward_to
      device_to_forward = (device_forward_to == device_id)
      can_fwd = false if device_to_forward

      while !(device_forward_to == 0 or device_to_forward)
        device = Device.where(id: device_forward_to).first
        can_fwd = false if device_to_forward
      end
    end

    device_name = _('device') + ' ' + @device.name.to_s + ' '

    if can_fwd
      flash[:status] = device_name
      flash[:status] += fwd_to_not_zero ? (_('forwarded_to') + ' ' + device_fwd_to.name.to_s) : _('forward_removed')

      @device.forward_to = fwd_to
      @device.save

      conf_extensions = configure_extensions(device_id, { current_user: current_user })
      return false unless conf_extensions
    else
      flash[:notice] = device_name + _('not_forwarded_close_circle')
    end

    redirect_to action: :device_forward, id: @device
  end

  def forwards
    @page_title = _('Forwards')
    @page_icon = 'forward.png'
    @devices = Device.where("user_id != 0 AND name not like 'mor_server_%'").order(:name)
  end

  def group_forwards
    @group = Group.where(id: params[:id]).first
    @page_icon = 'forward.png'
    @page_title = _('Forwards') + ': ' + @group.name
    @devices = []

    @group.users.each do |user|
      user.devices.each do |device|
        @devices << device
      end
    end

    render :forwards
  end

  #============ CallerIDs ===============

  def user_device_clis
    @page_title = _('CallerIDs')
    @page_icon = 'cli.png'

    unless user?
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    @user = User.where(id: session[:user_id]).first
    @devices = @user.devices
    @clis = []

    @clis = Callerid.select("callerids.* , devices.user_id , devices.name, devices.device_type, devices.istrunk, ivrs.name as 'ivr_name'").
                     joins("JOIN devices on (devices.id = callerids.device_id)").
                     joins("LEFT JOIN ivrs on (ivrs.id = callerids.ivr_id)").
                     where("devices.user_id = '#{@user.id}'")

    @all_ivrs = Ivr.all
  end

  # in before filter : device (:find_device)
  def device_clis
    redirect_to action: :clis, device_id: params[:id] if params[:id]
  end

  def load_cli_params
    @selected = {
      cli: '',
      device_id: 0,
      user: -1,
      description: '',
      ivr: -1,
      comment: '',
      banned: 0,
    }

    if params[:s_user].to_s == '' || %w[-2 -1].include?(params[:s_user_id].to_s)
      params[:s_user_id] = -1
      params[:device_id] = 0 unless params[:user].present?
    end

    cli = params[:cli]
    device_id = params[:device_id]
    user = params[:s_user_id]
    description = params[:description]
    ivr = params[:ivr]
    comment = params[:comment]
    banned = params[:banned]

    @selected[:cli] = cli if cli
    @selected[:device_id] = device_id if device_id
    @selected[:user] = user if user
    @selected[:description] = description if description
    @selected[:ivr] = ivr if ivr
    @selected[:comment] = comment if comment
    @selected[:banned] = banned if banned
  end

  def cli_new
    @page_title = 'CLI ' + _('Add')
    @page_icon = 'add.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/CLIs'

    correct_current_user_id

    @ivrs = Ivr.select("DISTINCT(callerids.ivr_id), ivrs.name, ivrs.id").
                joins("LEFT JOIN callerids ON (ivrs.id = callerids.ivr_id)").
                where(["ivrs.user_id = ?", @current_user_id])

    @all_ivrs = @ivrs
  end

  def cli_add
    @page_title = 'CLI ' + _('add')
    @page_icon = 'add.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/CLIs'

    correct_current_user_id

    @all_ivrs = Ivr.select("DISTINCT(callerids.ivr_id), ivrs.name, ivrs.id").
                joins("LEFT JOIN callerids ON (ivrs.id = callerids.ivr_id)").
                where(["ivrs.user_id = ?", @current_user_id])
    create_cli
    if flash[:status]
      redirect_to action: :clis
    else
      render :cli_new
    end
  end

  def cli_device_add
    create_cli
    redirect_to action: :clis, id: params[:device_id] and return false
  end

  def cli_user_add
    create_cli
    redirect_to action: :user_device_clis and return false
  end

  def change_email_callback_status
    Callerid.use_for_callback(@cli, params[:email_callback])
    redirect_to action: :clis and return false
  end

  def change_email_callback_status_device
    Callerid.use_for_callback(@cli, params[:email_callback])
    redirect_to action: :clis, id: @cli.device_id and return false
  end

  def cli_delete
    cli_cli = @cli.cli
    @cli.destroy ? flash[:status] = _('CLI_deleted') + ": #{cli_cli}" : flash[:notice] = _('CLI_is_not_deleted') + '<br/>' + '* ' + _('CID_is_assigned_to_Device')
    redirect_to action: :clis and return false
  end

  def cli_user_delete
    cli_cli = @cli.cli
    @cli.destroy
    flash[:status] = _('CLI_deleted') + ": #{cli_cli}"
    redirect_to action: :user_device_clis and return false
  end

  def cli_device_delete
    cli_cli = @cli.cli
    device_id = @cli.device_id
    cli_deleted_status = _('CLI_deleted') + ": #{cli_cli}"

    if @cli.destroy
      flash[:status] = cli_deleted_status
    else
      flash_errors_for(_('CLI_is_not_deleted'), @cli)
    end

    flash[:status] = cli_deleted_status
    redirect_to action: :clis, id: device_id and return false
  end

  def cli_edit
    @page_title = _('CLI_edit')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/CLIs'
    @all_ivrs = Ivr.all
    @device = @cli.device
    #  check_owner_for_device(@device.user)
    @user = @device.user
    user = @user
    session_user_id = session[:user_id].to_i

    unless user && (user.id == session_user_id) || (user.owner_id == session_user_id) ||
      admin? || accountant? || reseller?
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
  end

  def cli_update
    @page_title = _('CLI_edit')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/CLIs'

    @device = @cli.device
    @user = @device.user
    @all_ivrs = Ivr.all

    @cli.assign_attributes(cli_attributes_to_assign)

    @cli.ivr_id = params[:ivr] if params[:ivr]

    if @cli.save
      Callerid.use_for_callback(@cli, params[:email_callback])
      flash[:status] = _('CLI_updated')
      redirect_to action: :clis and return false
    else
      flash_errors_for(_("CLI_not_created"), @cli)
      render :cli_edit
    end

  end

  def cli_device_edit
    @page_title = _('CLI_edit')
    @page_icon = 'edit.png'

    @all_ivrs = Ivr.all
    @device = @cli.device
    @user = @device.user
    user = @user
    session_user_id = session[:user_id].to_i

    unless user && (user.id == session_user_id) || (user.owner_id == session_user_id) ||
      admin? || accountant?
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
  end

  def cli_user_edit
    @page_title = _('CLI_edit')
    @page_icon = 'edit.png'
    @all_ivrs = Ivr.all
    @device = @cli.device
    @user = @device.user
    user = @user
    session_user_id = session[:user_id].to_i

    unless user && (user.id == session_user_id) || (user.owner_id == session_user_id) ||
      admin? || accountant?
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
  end

  def cli_device_update
    cli = @cli
    @cli.assign_attributes(cli_attributes_to_assign)
    @cli.ivr_id = params[:ivr] if params[:ivr] and accountant_can_write?("cli_ivr")
    if @cli.save
      Callerid.use_for_callback(@cli, params[:email_callback])
      flash[:status] = _('CLI_updated')
      redirect_to action: :clis, id: cli.device_id
    else
      flash_errors_for(_("CLI_not_created"), cli)
      redirect_to action: :cli_device_edit, id: cli.id
    end
  end

  def cli_user_update
    params_id = params[:id]

    unless cli = Callerid.where(id: params_id).first
      flash[:notice] = _('Callerid_was_not_found')
      redirect_to action: :index and return false
    end

    cli.assign_attributes(cli_attributes_to_assign)
    cli.ivr_id = params[:ivr] if params[:ivr]

    if cli.save
      Callerid.use_for_callback(cli, params[:email_callback])
      flash[:status] = _('CLI_updated')
      redirect_to action: :user_device_clis and return false
    else
      flash_errors_for(_('CLI_not_created'), cli)
      redirect_to action: :cli_user_edit, id: params_id
    end
  end

  def clis
    @page_title = _('CLIs')
    @page_icon = 'cli.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/CLIs'

    # clear form

    if params[:clear] == 'true'
      @searched = false
      session[:search] = nil
    end

    # order
    @options = session[:cli_list_options] ||= { order_by: 'cli', order_desc: 0 }
    params_order_by, params_order_desc = [params[:order_by], params[:order_desc]]
    @options[:order_by] = params_order_by.to_s if params_order_by
    @options[:order_desc] = params_order_desc.to_i if params_order_desc

    order_by = Device.clis_order_by(@options)

    session[:cli_list_options] = @options

    #search

    @search = session[:search] ||= { cli: '', device: -1, user: -1, banned: -1, email_callback: -1, ivr: -1,
                                     description: '', comment: '' }

    params_device_id = params[:device_id]

    if params_device_id && params[:s_user_id].blank?
      dev = Device.where(id: params_device_id).first
      params[:s_user_id] = dev.user_id if dev
    end

    params_s_user_blank = params[:s_user].blank?

    if params_s_user_blank || %w[-2 -1].include?(params[:s_user_id].to_s)
      params[:s_user_id] = params_s_user_blank ? -1 : -2
      params[:device_id] = -1 unless params[:user_id].present?
    end

    params_s_banned, params_s_ivr, params_s_description, params_s_comment, params_s_email_callback, params_device_id, params_s_cli, params_s_user_id = [params[:s_banned],
      params[:s_ivr], params[:s_description], params[:s_comment], params[:s_email_callback], params[:device_id], params[:s_cli], params[:s_user_id]]

    search_user = @search[:user] = params_s_user_id.to_s.strip if params_s_user_id
    search_user_not_equal_minus_one = (search_user.to_i != -1)
    search_cli = @search[:cli] = params_s_cli.to_s.strip if params_s_cli
    search_device = @search[:device] = params_device_id.to_s.strip if params_device_id
    search_dev_not_equal_minus_one = (search_device.to_i != -1)
    search_banned = @search[:banned] = params_s_banned if params_s_banned
    search_ivr = @search[:ivr] = params_s_ivr if params_s_ivr
    search_description = @search[:description] = params_s_description.to_s.strip if params_s_description
    search_comment = @search[:comment] = params_s_comment.to_s.strip if params_s_comment
    search_email_callback = @search[:email_callback] = params_s_email_callback if params_s_email_callback

    cond = ''
    session[:search] = @search

    if search_user_not_equal_minus_one
      cond += "  AND devices.user_id = '#{search_user}' "

      if search_dev_not_equal_minus_one
        cond += " AND callerids.device_id = '#{search_device}' "
      end
    end

    cond += " AND callerids.cli LIKE '#{search_cli}' " if search_cli && search_cli.length > 0
    cond += " AND callerids.banned =  '#{search_banned}' " if search_banned && search_banned.to_i != -1
    cond += " AND callerids.ivr_id =  '#{search_ivr}' " if search_ivr && search_ivr.to_i != -1
    cond += " AND callerids.description LIKE '#{search_description}%' " if search_description && search_description.length > 0
    cond += " AND callerids.comment LIKE  '#{search_comment}%' " if search_comment && search_comment.length > 0
    cond += " AND callerids.email_callback =  '#{search_email_callback}' " if search_email_callback && search_email_callback.to_i != -1
    cond += " AND users.id =  '#{params[:user_id]}' " if params[:user_id]
    cond += " AND devices.id =  '#{params[:device_id]}' " if params[:device_id].to_i > -1

    correct_current_user_id

    @clis = Callerid.select("callerids.* , devices.user_id , devices.name, devices.extension, devices.device_type, devices.istrunk, ivrs.name as 'ivr_name'").
                     joins("JOIN devices on (devices.id = callerids.device_id)").
                     joins("JOIN users on (users.id = devices.user_id)").
                     joins("LEFT JOIN ivrs on (ivrs.id = callerids.ivr_id)").
                     where("callerids.id > 0 " << cond << " AND users.id = devices.user_id AND users.owner_id = #{@current_user_id}").order(order_by)

    @ivrs = Ivr.select("DISTINCT(callerids.ivr_id), ivrs.name, ivrs.id").
                joins("LEFT JOIN callerids ON (ivrs.id = callerids.ivr_id)").
                where(["ivrs.user_id = ?", @current_user_id])

    @all_ivrs = @ivrs

    @searched = 'true' if cond != ''

    @page = 1
    params_page = params[:page]
    @page = params_page.to_i if params_page

    @total_pages = (@clis.size.to_d / session[:items_per_page].to_d).ceil
    @all_clis = @clis
    @clis = []
    iend = ((session[:items_per_page] * @page) - 1)
    all_clis_size_minus_one = @all_clis.size - 1
    iend = all_clis_size_minus_one if iend > all_clis_size_minus_one

    for cli in ((@page - 1) * session[:items_per_page])..iend
      @clis << @all_clis[cli]
    end
  end

  def clis_banned_status
    @cl = Callerid.where(id: params[:id]).first
    @cl.banned_status
    @cl.save
    redirect_to action: :clis
  end

  def cli_user_devices
    @num = request.raw_post.to_s.gsub("=", "")
    @num = params[:id] if params[:id]
    @include_cli = params[:cli] if params[:cli]
    @devices = Device.where(["user_id = ? AND name not like 'mor_server_%' AND name NOT LIKE 'prov%'", @num]) if @num.to_i != -1
    @search_dev = params[:dev_id] if params[:dev_id]

    if params[:add]
      @add =1
    end

    @did = params[:did].to_i
    render layout: false
  end

  def devices_all
    devices_title_and_icon
    @help_link = "http://wiki.kolmisoft.com/index.php/Devices"

    default_options = {}
    if params[:clean]
      @options = default_options
    else
      if session[:devices_all_options]
        @options = session[:devices_all_options]
      else
        @options = default_options
      end
    end
    #if new param was specified delete it from options,
    #else there might be leaved parameters that were saved in session
    @options.delete(:search_pinless) if params[:s_pinless]
    @options.delete(:search_pin) if params[:s_pin]

    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : @options[:order_desc].to_i
    @options[:order_by], order_by, default = devices_all_order_by(params, @options)

    params[:s_description] ? @options[:search_description] = params[:s_description].to_s : (@options[:search_description] = "" if !@options[:search_description])
    params[:s_extension] ? @options[:search_extension] = params[:s_extension].to_s : (@options[:search_extension] = "" if !@options[:search_extension])
    params[:s_username] ? @options[:search_username] = params[:s_username].to_s : (@options[:search_username] = "" if !@options[:search_username])
    params[:s_host] ? @options[:search_host] = params[:s_host].to_s.strip : (@options[:search_host] = "" if !@options[:search_host])
    @options[:search_cli] = params[:s_cli].to_s if params[:s_cli]

    #if pinless option is selected, than there shouldnt be pin parameter specified.
    #if pin was specified, then there shouldnt be pinless parameter.
    #so just in case we should delete options that shouldnt be there
    if params[:s_pinless]
      @options[:search_pinless] = params[:s_pinless]
      @options.delete(:search_pin)
    else
      pin = params[:s_pin].to_s.strip
      if pin.length > 0
        @options[:search_pin] = pin if pin =~ /^[0-9]+$/
      end
      @options.delete(:search_pinless)
    end

    @options[:search_description].to_s.length + @options[:search_extension].to_s.length+ @options[:search_username].to_s.length + @options[:search_cli].to_s.length > 0 ? @options[:search] = 1 : @options[:search] = 0
    set_options_page
    join = ["LEFT OUTER JOIN users ON users.id = devices.user_id"]
    cond = ["user_id != -1 AND devices.name not like 'mor_server_%' AND hidden = 0"]
    cond_par = []

    #if at least one valid seach option was entered
    #@search should be true
    @search = false

    if @options[:search_description].to_s.length > 0
      cond << "devices.description LIKE ?"
      cond_par << "%"+ @options[:search_description].to_s+"%"
      @search = true
    end

    if @options[:search_extension].to_s.length > 0
      cond << "devices.extension LIKE ?"
      cond_par << @options[:search_extension].to_s+"%"
      @search = true
    end

    if @options[:search_username].to_s.length > 0
      cond << "devices.username LIKE ?"
      cond_par << @options[:search_username].to_s + "%"
      @search = true
    end

    if @options[:search_host].to_s.length > 0
      cond << "devices.ipaddr LIKE ?"
      cond_par << @options[:search_host].to_s + "%"
      @search = true
    end

    if @options[:search_cli].to_s.length > 0
      join << "LEFT OUTER JOIN callerids ON devices.id = callerids.device_id"
      cond << "callerids.cli LIKE ?"
      cond_par << @options[:search_cli].to_s + "%"
      @search = true
    end

    if @options[:search_pinless]
      cond << "(devices.pin is NULL OR devices.pin = ?)"
      cond_par << ""
      @search = true
    else
      if @options[:search_pin]
        cond << "devices.pin LIKE ?"
        cond_par << @options[:search_pin].to_s + "%"
        @search = true
      end
    end

    cond << "accountcode != 0"
    cond << "users.owner_id = ?"
    cond_par << session[:user_id]


    #grouping by device id is needed only when searching by cli. how to work around it withoud duplicating code?
    @total_pages = (Device.joins(join.join(" ")).where([cond.join(" AND ")] + cond_par).group('devices.id').to_a.size.to_d / session[:items_per_page].to_d).ceil
    options_page
    @options[:page] = 1 if @options[:page].to_i < 1

    @devices = Device.select("devices.*, IF(LENGTH(CONCAT(users.first_name, users.last_name)) > 0,CONCAT(users.first_name, users.last_name), users.username) AS 'nice_user'").
                           joins(join.join(" ")).
                           where([cond.join(" AND ")] + cond_par).
                           group('devices.id').
                           order(order_by).
                           offset(session[:items_per_page]*(@options[:page]-1)).
                           limit(session[:items_per_page])

    if default and (session[:devices_all_options] == nil or session[:devices_all_options][:order_by] == nil)
      @options.delete(:order_by)
    end
    session[:devices_all_options] = @options
  end

  # in before filter : device (:find_device)
  def device_all_details
    @page_title = _('Device_details')
    @page_icon = 'view.png'

    @user = @device.user
    check_owner_for_device(@user)
  end

  # ------------------------------- C A L L F L O W ---------------------------
  # in before filter : device (:find_device)
  def callflow
    @page_title, @page_icon = [_('Call_Flow'), 'cog_go.png']
    device_user = @device.user
    session_user_id = session[:user_id]
    # Security
    # If the device belongs to a user which is not owned by admin
    if device_user.present?
      if device_user.owner.id != session_user_id && admin?
        dont_be_so_smart
        redirect_to :root
        return
      end
    end

    if user? || accountant?
      session_manager_in_groups = session[:manager_in_groups]

      if session_manager_in_groups.size == 0
        #simple user
        @user = User.where(id: session_user_id).first

        if user_is_not_device_owner
          dont_be_so_smart
          redirect_to :root
          return
        end
      else
        #group manager
        @user = device_user
        can_check = false

        session_manager_in_groups.each do |group|
          group.users.each do |user|
            can_check = true if user.id == @user.id
          end
        end

        unless can_check
          dont_be_so_smart
          redirect_to :root
          return
        end
      end
    end

    if reseller?
      @user = device_user

      if (@user.owner_id != session_user_id) && (@user.id != session_user_id)
        dont_be_so_smart
        redirect_to :root
        return
      end
    end

    @user = device_user if admin?

    device_id = @device.id
    @before_call_cfs = Callflow.where(cf_type: 'before_call', device_id: device_id).order(:priority)
    @no_answer_cfs = Callflow.where(cf_type: 'no_answer', device_id: device_id).order(:priority)
    @busy_cfs = Callflow.where(cf_type: 'busy', device_id: device_id).order(:priority)
    @failed_cfs = Callflow.where(cf_type: 'failed', device_id: device_id).order(:priority)

    if @before_call_cfs.empty?
      @before_call_cfs << create_empty_callflow(device_id, 'before_call')
    end

    if @no_answer_cfs.empty?
      @no_answer_cfs << create_empty_callflow(device_id, 'no_answer')
    end

    if @busy_cfs.empty?
      @busy_cfs << create_empty_callflow(device_id, 'busy')
    end

    if @failed_cfs.empty?
      @failed_cfs << create_empty_callflow(device_id, 'failed')
    end
  end

  # in before filter : device (:find_device)
  def callflow_edit
    @page_title, @page_icon = [_('Call_Flow'), 'edit.png']
    err = 0
    user_id = @device.user_id
    @user = @device.user
    @users, @devices = [[], []]
    session_user_id = session[:user_id]

    if user? || reseller?
      if ((user_id != session_user_id.to_i) && user?) ||
        (reseller? && ((user_id != current_user_id) && (@user.owner_id != current_user_id)))
        dont_be_so_smart
        (redirect_to :root) && (return false)
      end
    else
      return false unless check_owner_for_device(@user)
    end

    device_id = @device.id
    @dids = Did.where(device_id: device_id)
    @cf_type = params[:cft]
    @fax_enabled = session[:fax_device_enabled]

    whattodo = params[:whattodo]
    params_cf = params[:cf]
    params_s_user_id = params[:s_user_id]
    params_s_user_id = current_user_id if user?
    finded_callflow = Callflow.where(id: params_cf, device_id: @device).first if params_cf

    if !finded_callflow && params_cf
      flash[:notice] = _('Callflow_was_not_found')
      redirect_to action: :index and return false
    end

    case whattodo
    when 'change_action'
      params_cf_action = params[:cf_action]
      finded_callflow.assign_attributes({
        action: params_cf_action,
        data: '',
        data2: '',
        data3: 1
        })
      finded_callflow.save
    when 'change_local_device'
      params_cf_data = params[:cf_data].to_i

      if params_cf_data == 5
        if params[:s_device].present? && params[:s_device].to_s.downcase != 'all'
          finded_callflow.assign_attributes({
            data: params[:s_device].to_i,
            data2: 'local',
            data3: ''
          })
          finded_callflow.save if finded_callflow.data.to_i > 0
        else
          err = 1
        end
      end

      if params_cf_data == 6
        params_ext_number = params[:ext_number].to_s

        params[:s_user] = nil
        params[:s_user_id] = nil
        params_s_user_id = nil

        if params_ext_number.to_i == @device.extension.to_i
          flash[:notice] = _('Devices_callflow_external_number_cant_match_extension')
          redirect_to action: :callflow_edit, id: device_id, cft: @cf_type and return false
        end

        if params_ext_number.blank?
          flash[:notice] = _('Devices_callflow_external_number_cant_be_blank')
          redirect_to action: :callflow_edit, id: device_id, cft: @cf_type and return false
        end

        finded_callflow.assign_attributes({
          data: params_ext_number.strip,
          data2: 'external',
          data3: '',
        })

        finded_callflow.save
      end

      # cf_data3 gets value of caller_id selection
      # 1 - From device
      # 2 - Same as comes - unchanged
      # 3 - From did
      # 4 - Custom

      params_cf_data_third_string = params[:cf_data3].to_s
      params_cf_data_third = params_cf_data_third_string.to_i

      if params_cf_data_third < 5
        finded_callflow.data3 = params_cf_data_third_string

        if params_cf_data_third == 3
          params_did_id = params[:did_id]
          finded_callflow.data4 = params_did_id if params_did_id
        end

        if params_cf_data_third == 4
          params_cf_data_fourth = params[:cf_data4]
          finded_callflow.data4 = params_cf_data_fourth if params_cf_data_fourth.length > 0
        end

        if params_cf_data_third < 3
          finded_callflow.data4 = ''
        end

        finded_callflow.save
      end
    when 'change_fax_device'
      params_devices_id = params[:device_id].to_i
      ringgroup_device = RinggroupsDevice.where(device_id: params_devices_id).first.blank?
        if ringgroup_device
          finded_callflow.assign_attributes({
            data: params_devices_id,
            data2: 'fax'
          })
          finded_callflow.save if finded_callflow.data.to_i > 0
        else
          err = 1
        end
    when 'change_device_timeout'
      value = params[:device_timeout].to_i
      value = 10 if value < 10
      @device[:timeout] = value
      @device.save
    when 'change_skip_intro_message'
      finded_callflow.assign_attributes({
        data5: params[:data5]
      })
      finded_callflow.save
    end

    if err.to_i == 0
      flash[:status] = _('Callflow_updated') if params[:whattodo] and params[:whattodo].length > 0

      @cfs = Callflow.where(cf_type: @cf_type, device_id: device_id).order(:priority)

      if @cfs.blank?
        flash[:notice] = _('Callflow_was_not_found')
        (redirect_to :root) && (return false)
      end

      if !admin? && !accountant?
        session_manager_in_groups = session[:manager_in_groups]

        if user? && (session_manager_in_groups.size == 0)
          #simple user
          @fax_devices = @user.fax_devices
        else
          #group manager or reseller can forward devices to same groups devices
          @fax_devices = Device.includes(:user).where(["(users.owner_id = ? OR users.id = ? ) AND devices.device_type = 'FAX' AND name not like 'mor_server_%'", session_user_id, session_user_id]).references(:user).order(:name)

          set_forward_devices

          session_manager_in_groups.each do |group|
            group.users.each do |user|
              user.devices.each do |device|
                @devices << device unless @devices.include?(device)
              end

              user.fax_devices.each do |fdevice|
                @fax_devices << fdevice unless @fax_devices.include?(fdevice)
              end
            end
          end
        end
      else
        # admin
        @fax_devices = Device.where("user_id != -1 AND device_type = 'FAX' AND name not like 'mor_server_%'")
                             .order(:name)
        set_forward_devices
      end

      @devices = Device.where(user_id: params_s_user_id).all if params_s_user_id.present?

      if params[:whattodo] && params[:whattodo].to_s.length > 0
        conf_extensions = configure_extensions(device_id, { current_user: current_user })
        return false if !conf_extensions
      end
    else
      flash[:notice] = ringgroup_device ? _('Please_select_device') : _('Ring_Group_Device_cannot_be_use_in_Fax_Detect')
      redirect_to action: :callflow_edit, id: device_id, cft: @cf_type, s_user: params[:s_user],
        s_user_id: params_s_user_id and return false
    end
  end

  # ------------------------- User devices --------------

  def user_devices
    devices_title_and_icon

    unless user?
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    @devices = current_user.try(:devices)
  end

  # in before filter : device (:find_device)
  def find_provider
    @provider = Provider.where(device_id: @device.id).first
  end

  def user_device_edit
    @page_title = @provider ? _('Provider_settings') : _('device_settings')
    @page_icon = 'edit.png'
    @user = User.where(id: session[:user_id]).first
    user = @user
    @owner = User.where(id: user.owner_id).first
    user_device_callerid_params if user.allow_change_callerid == 1

    unless user
      flash[:notice] = _('User_was_not_found')
      (redirect_to :index) && (return false)
    end

    @pdffaxemails = allow_pdffax_edit_for_user? ? @device.pdffaxemails : []

    if user_is_not_device_owner || (@device.device_type == 'FAX' && !allow_pdffax_edit_for_user?)
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    @dids = @device.dids
    set_cid_name_and_number
    @curr = current_user.currency
  end

  def user_device_callerid_params
    @device_caller_id_number = @device.device_caller_id_number
    @device_dids_numbers = @device.dids_numbers
  end

  # in before filter : device (:find_device)
  def user_device_update
    @user = User.where(id: session[:user_id]).first
    device = @device
    if user_is_not_device_owner
      dont_be_so_smart
      redirect_to :root
      return false
    end

    update_context_for_device(device)

    update_device_cid
    params_device = params[:device]

    device_record = @device.record.to_i
    @device.assign_attributes({ cid_from_dids: params[:cid_from_dids].to_i,
                                description: params_device[:description],
                                record: params_device[:record].to_i,
                                recording_to_email: params_device[:recording_to_email].to_i,
                                recording_email: params_device[:recording_email],
                                recording_keep: params_device[:recording_keep].to_i
                              })

    if @device.save
      configure_extensions(@device.id, {api: 1}) if device_record != @device.record
      flash[:status] = _('phones_settings_updated')
    else
      flash_errors_for(_('Update_Failed'), @device)
    end

    redirect_to action: :user_devices and return false
  end

  # ------------------ PDF Fax Emails -----------------

  def pdffaxemail_add
    @page_title = _('Add_new_email')
    @page_icon = 'add.png'

    @user = @device.user
  end

  def pdffaxemail_new
    params_new_pdffaxemail = params[:new_pdffaxemail]
    email_address_valid = Email.address_validation(params_new_pdffaxemail)
    device = @device

    if params_new_pdffaxemail && (params_new_pdffaxemail.length > 0) && email_address_valid
      email = Pdffaxemail.new
      email.device, email.email = [device, params_new_pdffaxemail]
      email.save
      flash[:status] = _('New_email_added')
    else
      flash[:notice] = email_address_valid ? _('Please_fill_field') : _('Email_is_not_correct')
    end

    # Variable @pdffax_email_action comes from before_filter set_action_for_pdffaxemail
    redirect_to action: @pdffax_email_action, id: device
  end

  def pdffaxemail_edit
    @page_title = _('Edit_email')
    @page_icon = 'edit.png'

    @device = @email.device
    @user = @device.user
  end

  def pdffaxemail_update
    params_email = params[:email]

    if params_email && (params_email.length > 0) && Email.address_validation(params_email)
      @email.email = params_email
      @email.save
      flash[:status] = _('Email_updated')
    else
      flash[:notice] = _('Email_not_updated')
    end

    # Variable @pdffax_email_action comes from before_filter set_action_for_pdffaxemail
    redirect_to action: @pdffax_email_action, id: @email.device.id
  end

  def pdffaxemail_destroy
    email = @email.email
    device_id = @email.device_id
    @email.destroy

    flash[:status] = _('Email_deleted') + ': ' + email

    # Variable @pdffax_email_action comes from before_filter set_action_for_pdffaxemail
    redirect_to action: @pdffax_email_action, id: device_id
  end

  def default_device
    @page_title = _('Default_device')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Default_device_settings'
    session_user_id = session[:user_id]

    if reseller?
      reseller = User.where(id: session[:user_id]).first
      reseller.check_reseller_conflines
      reseller.check_default_user_conflines
    end

    @device = Confline.get_default_object(Device, correct_owner_id)
    @device.user_id = correct_owner_id
    @devicetypes = Devicetype.load_types('dahdi' => allow_dahdi?, 'Virtual' => allow_virtual?)
    @device_type = Confline.get_value('Default_device_type', session_user_id)
    @global_tell_balance = Confline.get_value('Tell_Balance').to_i
    @global_tell_time = Confline.get_value('Tell_Time').to_i

    select_clause = 'codecs.*,  (conflines.value2 + 0) AS v2'
    where_clause = "conflines.name like 'Default_device_codec%' AND codecs.codec_type = 'audio'"

    if @device_type == 'FAX'
      join_clause_add = " AND owner_id = #{session_user_id}"
      where_clause += " AND codecs.name IN ('alaw', 'ulaw')"
    else
      join_clause_add = ''
      where_clause = ["#{where_clause} AND owner_id = ?", session_user_id]
    end

    join_clause = "LEFT JOIN conflines ON (codecs.name = REPLACE(conflines.name, 'Default_device_codec_', '')" +
      "#{join_clause_add})"

    @audio_codecs = Codec.select(select_clause).joins(join_clause).where(where_clause).order('v2')
    join_clause_add = ''
    @video_codecs = Codec.select(select_clause).joins(join_clause)
                         .where(["conflines.name like 'Default_device_codec%' and codecs.codec_type = 'video' and owner_id = ?", session_user_id])
                         .order('v2')

    @owner = session_user_id

    @device_trunk = Confline.get_value('Default_device_trunk', @owner)
    get_locations
    @default = 1
    @cid_name = Confline.get_value('Default_device_cid_name', session_user_id)
    @cid_number = Confline.get_value('Default_device_cid_number', session_user_id)
    @qualify_time = Confline.get_value('Default_device_qualify', session_user_id)
    ddd = Confline.get_value('Default_setting_device_caller_id_number', session_user_id).to_i
    @device.cid_from_dids = 1 if ddd == 3
    @device.control_callerid_by_cids = 1 if ddd == 4
    @device.callerid_advanced_control = 1 if ddd == 5

    @device_dids_numbers = @device.dids_numbers
    @device_caller_id_number = @device.device_caller_id_number

    #-------multi server support------
    @sip_proxy_server = Server.where("server_type = 'sip_proxy'").limit(1).all
    @servers = Server.where("server_type = 'asterisk'").order('id ASC').all

    #@asterisk_servers = @servers
    @servers = @sip_proxy_server if (@sip_proxy_server.length > 0) && (@device_type == 'SIP')

    #------------ permits ------------

    @ip_first = ''
    @mask_first = ''
    @ip_second = ''
    @mask_second = ''
    @ip_third = ''
    @mask_third = ''

    data = Confline.get_value('Default_device_permits', session_user_id).split(';')

    if data[0]
      permit = data[0].split('/')
      @ip_first = permit[0]
      @mask_first = permit[1]
    end

    if data[1]
      permit = data[1].split('/')
      @ip_second = permit[0]
      @mask_second = permit[1]
    end

    if data[2]
      permit = data[2].split('/')
      @ip_third = permit[0]
      @mask_third = permit[1]
    end
    # @call_limit = confline("Default_device_call_limit")
    @user = User.new(recording_enabled: 1)

    @fax_enabled = session[:fax_device_enabled]

    @device_voicemail_active = Confline.get_value('Default_device_voicemail_active', session_user_id)
    @device_voicemail_box = Confline.get_value('Default_device_voicemail_box', session_user_id)
    @device_voicemail_box_email = Confline.get_value('Default_device_voicemail_box_email', session_user_id)
    @device_voicemail_box_password = Confline.get_value('Default_device_voicemail_box_password', session_user_id)
    @device_deletevm = Confline.get_value('Default_device_delete_vm', session_user_id)
    @fullname = ''
    @device_enable_mwi = Confline.get_value('Default_device_enable_mwi', session_user_id)
    @device_subscribemwi = Confline.get_value('Default_device_subscribemwi', session_user_id)
  end

  def default_device_update
    params_call_limit, params_vm_email = [params[:call_limit], params[:vm_email]]

    if params_call_limit
      params_call_limit = params_call_limit.to_s.strip.to_i
      params_call_limit = 0 if params_call_limit < 0
      params[:call_limit] = params_call_limit
    end

    if params_vm_email.present?
      if !Email.address_validation(params_vm_email)
        flash[:notice] = _('Voice_email_not_valid')
        redirect_to action: :default_device and return false
      end
    end

    session_user_id = session[:user_id]
    params_device = params[:device]
    params_device_device_type = params_device[:device_type]

    Confline.set_value('Default_device_type', params_device_device_type, session_user_id)
    Confline.set_value('Default_device_dtmfmode', params_device[:dtmfmode], session_user_id)
    Confline.set_value('Default_device_works_not_logged', params_device[:works_not_logged], session_user_id)
    Confline.set_value('Default_device_location_id', params_device[:location_id], session_user_id)
    Confline.set_value('Default_device_timeout', params[:device_timeout], session_user_id)

    Confline.set_value('Default_device_call_limit', params_call_limit.to_i, session_user_id)
    Confline.set_value('Default_device_server_id', (reseller? ? Confline.get_value('Resellers_server_id').to_i : params_device[:server_id].to_i), session_user_id) if params_device && params_device[:server_id]
    Confline.set_value('Default_device_cid_name', params[:cid_name], session_user_id)
    Confline.set_value('Default_device_cid_number', params[:cid_number], session_user_id)
    Confline.set_value('Default_setting_device_caller_id_number', params[:device_caller_id_number].to_i, session_user_id)

    Confline.set_value('Default_device_nat', params_device[:nat], session_user_id)

    Confline.set_value('Default_device_voicemail_active', params[:voicemail_active], session_user_id)
    Confline.set_value('Default_device_voicemail_box', 1, session_user_id)
    Confline.set_value('Default_device_voicemail_box_email', params[:vm_email], session_user_id)
    Confline.set_value('Default_device_voicemail_box_password', params[:vm_psw], session_user_id)
    Confline.set_value('Default_device_delete_vm', params[:deletevm], session_user_id)
    Confline.set_value('Default_device_trustrpid', params_device[:trustrpid], session_user_id)
    Confline.set_value('Default_device_sendrpid', params_device[:sendrpid], session_user_id)

    params_device_t38pt_udptl = params_device[:t38pt_udptl]

    if params_device_t38pt_udptl && [:fec, :redundancy, :none].include?(params_device_t38pt_udptl.to_sym)
      params[:device][:t38pt_udptl] = 'yes,' << params_device_t38pt_udptl
    end

    Confline.set_value('Default_device_t38pt_udptl', params[:device][:t38pt_udptl], session_user_id)
    Confline.set_value('Default_device_promiscredir', params_device[:promiscredir], session_user_id)
    Confline.set_value('Default_device_progressinband', params_device[:progressinband], session_user_id)
    Confline.set_value('Default_device_videosupport', params_device[:videosupport], session_user_id)

    Confline.set_value('Default_device_allow_duplicate_calls', params_device[:allow_duplicate_calls], session_user_id)
    Confline.set_value('Default_device_tell_balance', params_device[:tell_balance], session_user_id)
    Confline.set_value('Default_device_tell_time', params_device[:tell_time], session_user_id)
    Confline.set_value('Default_device_tell_rtime_when_left', params_device[:tell_rtime_when_left], session_user_id)
    Confline.set_value('Default_device_repeat_rtime_every', params_device[:repeat_rtime_every], session_user_id)
    Confline.set_value('Default_device_fake_ring', params_device[:fake_ring], session_user_id)
    params_device_language_string = params_device[:language].to_s
    lang = params_device_language_string.blank? ? 'en' : params_device_language_string
    Confline.set_value('Default_device_language', lang, session_user_id)
    Confline.set_value('Default_device_enable_mwi', params_device[:enable_mwi].to_i, session_user_id)
    Confline.set_value('Default_device_subscribemwi', params_device[:subscribemwi], session_user_id)
    Confline.set_value('Default_device_session-timers', params[:device]['session-timers'], session_user_id)
    Confline.set_value('Default_device_session-refresher', params[:device]['session-refresher'], session_user_id)
    Confline.set_value('Default_device_session-minse', params[:device]['session-minse'], session_user_id)
    Confline.set_value('Default_device_session-expires', params[:device]['session-expires'], session_user_id)

    Confline.set_value('Default_device_qf_tell_time', params_device[:qf_tell_time].to_i, session_user_id)
    Confline.set_value('Default_device_qf_tell_balance', params_device[:qf_tell_balance].to_i, session_user_id)
    params_iax2_trunking = params[:iax2_trunking]
    device_type_is_iax_sec = params_device_device_type == 'IAX2'
    Confline.set_value('Default_device_trunk', params_iax2_trunking, session_user_id) if device_type_is_iax_sec && !params_iax2_trunking.blank?

    #============= PERMITS ===================
    params_ip_first = params[:ip_first]
    params_ip_second = params[:ip_second]
    params_mask_first = params[:mask_first]
    if params_mask_first
      if !Device.validate_permits_ip([params_ip_first, params_ip_second, params[:ip_third], params_mask_first, params[:mask_second], params[:mask_third]])
        flash[:notice] = _('Allowed_IP_is_not_valid')
        redirect_to action: :default_device and return false
      else
        Confline.set_value('Default_device_permits', Device.validate_perims({ ip_first: params_ip_first,
          ip_second: params_ip_second, ip_third: params[:ip_third], mask_first: params_mask_first,
          mask_second: params[:mask_second], mask_third: params[:mask_third] }), session_user_id)
      end
    end

    #------ advanced --------
    qualify_time = get_default_device_qualify(params_device)
    if qualify_time.to_i >= 500 || qualify_time == 'no'
      Confline.set_value('Default_device_qualify', qualify_time, session_user_id)
    else
      flash[:notice] = _('qualify_must_be_greater_than_500')
      redirect_to :action => :default_device and return false
    end
    Confline.set_value('Default_device_use_ani_for_cli', params_device[:use_ani_for_cli], session_user_id)
    Confline.set_value('Default_device_encryption', params_device[:encryption], session_user_id) if params_device[:encryption]
    Confline.set_value('Default_device_block_callerid', params_device[:block_callerid].to_i, session_user_id)

    #------- Network related -------
    host = (params[:dynamic_check] == '1') ? 'dynamic' : params[:host]
    Confline.set_value('Default_device_host', host, session_user_id)

    ipaddr = (host != 'dynamic') ? host : ''
    Confline.set_value('Default_device_ipaddr', ipaddr, session_user_id)

    %w[Default_device_regseconds Default_device_canreinvite].each do |name|
      Confline.set_value(name, params_device[:canreinvite], session_user_id)
    end

    Confline.set_value('Default_device_cps_call_limit', params_device[:cps_call_limit].to_i, session_user_id)
    Confline.set_value('Default_device_cps_period', params_device[:cps_period].to_i, session_user_id)

    default_transport = 'udp'
    valid_transport_options = ['tcp', 'udp', 'tcp,udp', 'udp,tcp', 'tls']
    device_transport = params_device[:transport].to_s
    transport = (valid_transport_options.include?(device_transport) ? device_transport.to_s : 'udp')
    Confline.set_value('Default_device_transport', transport, session_user_id)

    #time_limit_per_day can be positive integer or 0 by default
    #it should be entered as minutes and saved as minutes(cause
    #later it wil be assigned to device and device will convert to minutes..:/)
    time_limit_per_day = params_device[:time_limit_per_day].to_i
    time_limit_per_day = 0 if time_limit_per_day < 0
    Confline.set_value('Default_device_time_limit_per_day', time_limit_per_day, session_user_id)

    #----------- Codecs ------------------
    params_codec = params[:codec]
    if device_type_is_iax_sec &&
      (!params_codec || !((params_codec[:alaw].to_i == 1) || (params_codec[:ulaw].to_i == 1)))
      flash[:notice] = _('Fax_device_has_to_have_at_least_one_codec_enabled')
      redirect_to action: :default_device and return false
    end

    Codec.all.each do |codec|
      codec_name = codec.name
      codec_value = params_codec && (params_codec[codec_name] == '1') ? 1 : 0
      Confline.set_value("Default_device_codec_#{codec_name}", codec_value, session_user_id)
    end

    #------Trunks-------
    istrunk, ani = Device.find_istrunk_and_ani(params[:trunk].to_i)

    Confline.set_value('Default_device_istrunk', istrunk, session_user_id)
    Confline.set_value('Default_device_ani', ani, session_user_id)

    #------- Groups -------
    group_error = 0
    params_callgroup = params[:callgroup] ||= nil
    if (0..63).include? params_callgroup.to_i
      Confline.set_value('Default_device_callgroup', params_callgroup, session_user_id)
    else
      flash[:notice] = _('Call_Group_bad_range')
      group_error += 1
    end

    params_pickupgroup = params[:pickupgroup] ||= nil
    if (0..63).include? params_pickupgroup.to_i
      Confline.set_value('Default_device_pickupgroup', params_pickupgroup, session_user_id)
    else
      flash[:notice] = _('Pickup_Group_bad_range')
      group_error += 1
    end

    if group_error > 0
      redirect_to(action: :default_device) && (return false)
    end

    #------- Advanced -------
    params_fromuser = params[:fromuser]
    fromuser = (!params_fromuser || (params_fromuser.length < 1)) ? nil : params_fromuser
    Confline.set_value('Default_device_fromuser', fromuser, session_user_id)

    params_fromdomain = params[:fromdomain]
    fromdomain = (!params_fromdomain || (params_fromdomain.length < 1)) ? nil : params_fromdomain
    Confline.set_value('Default_device_fromdomain', fromdomain, session_user_id)

    Confline.set_value('Default_device_grace_time', params[:grace_time], session_user_id)

    params_custom_sip_header = params[:custom_sip_header]
    Confline.set_value('Default_device_custom_sip_header', params_custom_sip_header, session_user_id) unless params_custom_sip_header.blank?

    Confline.set_value('Default_device_insecure', get_default_device_insecure, session_user_id)
    Confline.set_value('Default_device_calleridpres', params_device[:calleridpres].to_s, session_user_id)
    Confline.set_value('Default_device_change_failed_code_to', params_device[:change_failed_code_to].to_i, session_user_id)
    Confline.set_value('Default_device_anti_resale_auto_answer', params_device[:anti_resale_auto_answer].to_i, session_user_id)

    # recordings
    Confline.set_value('Default_device_record', params_device[:record].to_i, session_user_id)
    Confline.set_value('Default_device_recording_to_email', params_device[:recording_to_email].to_i, session_user_id)
    Confline.set_value('Default_device_recording_keep', params_device[:recording_keep].to_i, session_user_id)
    Confline.set_value('Default_device_record_forced', params_device[:record_forced].to_i, session_user_id)
    Confline.set_value('Default_device_recording_email', params_device[:recording_email].to_s, session_user_id)

    Confline.set_value('Default_device_process_sipchaninfo', params[:process_sipchaninfo].to_i, session_user_id)
    tim_max = params_device[:max_timeout].to_i
    Confline.set_value('Default_device_max_timeout', tim_max.to_i < 0 ? 0 : tim_max, session_user_id)
    Confline.set_value('Default_device_tell_rate', params_device[:tell_rate].to_s, session_user_id)

    flash[:status] = _('Settings_Saved')
    redirect_to action: :default_device and return false
  end

  def assign_provider
    device = Device.includes(:provider)
                   .where(['devices.id = ? AND providers.user_id = ?', params[:provdevice], current_user_id])
                   .references(:provider).first

    if device
      @prov = device.provider
      device.description = @prov.name if @prov
      params_id = params[:id]
      device.user_id = params_id

      if device.save
        prov_id = @prov.id
        # if provider is assigned to user, that connection is saved in "server_devices" table
        @sp = Serverprovider.where(provider_id: prov_id).all
        sip_proxy_serv_id = Server.where(server_type: 'sip_proxy').first.try(:id)
        servers = Server.where(id: [@sp.collect(&:server_id)]) if @sp.present?

        @sp.each do |sp|
          if ccl_active? && (device.device_type == 'SIP')
            server_id = sip_proxy_serv_id
          else
            server_id = servers.select { |serv| serv.id == sp.server_id }.first.try(:id)
          end

          device_id = device.id
          server_dev = ServerDevice.new_relation(server_id, device_id)
          server_dev.save unless ServerDevice.where(server_id: server_dev.server_id, device_id: device_id).first.present?
        end
        # Create extlines when provider (provider's device) is assigned to user. This will allow local calls to this provider.
        configure_extensions(device.id, {current_user: current_user})
        flash[:status] = _('Provider_assigned')
        if Provider.joins(:device).where("providers.password = '#{@prov.password}' AND providers.login = '#{@prov.login}' AND providers.server_ip = '#{@prov.server_ip}' AND providers.port = '#{@prov.port}' AND providers.id != #{prov_id} AND providers.user_id = #{current_user_id} AND devices.user_id != #{params_id}").size > 0
          flash[:notice] = _('Avoid_routing_problems')
        end
      else
        flash_errors_for(_('Device_not_updated'), device)
      end
    else
      flash[:notice] = _('Provider_Not_Found')
    end
    redirect_to action: :show_devices, id: params_id
  end

  def get_user_devices
    @user = request.raw_post.gsub('=', '')

    where_clause = ["users.owner_id = ? AND device_type != 'FAX' AND name not like 'mor_server_%'", correct_owner_id]
    where_clause_sec = (@user == 'all') ? '' : ['user_id = ?', @user]

    @devices = Device.select('devices.*').joins('LEFT JOIN users ON (users.id = devices.user_id)')
                     .where(where_clause).where(where_clause_sec)
    render layout: false
  end

  def ajax_get_user_devices
    owner_id = correct_owner_id
    @user = params[:user_id] if params[:user_id] != -1
    @default = params[:default].to_i if params[:default]
    @fax = params[:fax]
    @add_all = params[:all] ||= false
    @none = params[:none] ||= false
    @add_name = params[:name] ||= false

    if @user != 'all'
      cond = ["users.owner_id = ? AND name not like 'mor_server_%'"]
      var = [owner_id]
      cond, var = [["name not like 'mor_server_%'"], []]
      cond << 'user_id = ?' && var << @user
      cond << "device_type != 'FAX'" if @fax == 'false'
      cond << "name not like 'mor_server_%'" if params[:no_server]
      cond << "user_id > -1" if params[:no_provider]
      @devices = Device.select("devices.*")
                       .joins("LEFT JOIN users ON (users.id = devices.user_id)")
                       .where([cond.join(" AND ")].concat(var))
    else
      @devices = []
    end

    render layout: false
  end

  # A bit duplicate but this is the correct one (so far) implementation fo AJAX finder.
  def get_devices_for_search
    options = {}
    options[:include_did] = params[:did_search].to_i

    if params[:user_id] == 'all'
      @devices = (admin? || accountant?) ? Device.find_all_for_select(nil, options) : Device.find_all_for_select(corrected_user_id, options)
    else
      @user = User.where(id: params[:user_id]).first

      if @user && (admin? || accountant? || (@user.owner_id = corrected_user_id))
        @devices = params[:did_search].to_i == 0 ? @user.devices("device_type != 'FAX'") : @user.devices("device_type != 'FAX'").select('devices.*').joins('JOIN dids ON (dids.device_id = devices.id)').group('devices.id').all
      else
        @devices = []
      end
    end

    render layout: false
  end

  def devicecodecs_sort
    ctype = params[:ctype]
    codec_id = params[:codec_id]
    params_id = params[:id]

    if params_id.to_i > 0
      @device = Device.where(id: params_id).first

      unless @device
        flash[:notice] = _('Device_was_not_found')
        redirect_back_or_default('/callc/main')
        return false
      end
      if codec_id
        if params[:val] == 'true'
          begin
            @device.devicecodecs.new({codec_id: codec_id}).save
          rescue
          end
        else
          pc = Devicecodec.where(device_id: params_id, codec_id: codec_id).first
          pc.destroy if pc
        end
      end

      params["#{ctype}_sortable_list".to_sym].each_with_index do |elem, index|
        item = Devicecodec.where(device_id: params_id, codec_id: elem).first
        if item
          item.priority = index
          item.save
        end
      end
    else
      params["#{ctype}_sortable_list".to_sym].each_with_index do |elem, index|
        codec = Codec.where(id: elem).first
        if codec
          val = params[:val] == 'true' ? 1 : 0
          codec_name = codec.name
          session_user_id = session[:user_id]
          Confline.set_value("Default_device_codec_#{codec_name}", val, session_user_id) if params[:val] && (codec_id.to_i == codec.id)
          Confline.set_value2("Default_device_codec_#{codec_name}", index, session_user_id)
        end
      end
    end
    render layout: false
  end

  def devices_weak_passwords
    @page_title = _('Devices_with_weak_password')
    items_per_page = session[:items_per_page]

    @options = session[:devices_devices_weak_passwords_options] ||= {}
    set_options_page
    @total_pages = (Device.where("LENGTH(secret) < 8 AND LENGTH(username) > 0 AND device_type != 'H323' AND username NOT LIKE 'mor_server_%'").size.to_d / items_per_page.to_d).ceil
    options_page
    @devices = Device.where("LENGTH(secret) < 8 AND LENGTH(username) > 0 AND device_type != 'H323' AND username NOT LIKE 'mor_server_%' AND user_id != -1")
                     .limit(items_per_page)
                     .offset(items_per_page * (@options[:page] - 1))

    session[:devices_devices_weak_passwords_options] = @options
  end

  def insecure_devices
    @page_title = _('Insecure_Devices')
    @options = session[:devices_insecure_devices_options] ||= {}
    set_options_page
    items_per_page = session[:items_per_page].to_d
    where_clause = "host = 'dynamic' AND (insecure = 'port,invite' OR insecure = 'port' OR insecure = 'invite') AND device_type = 'SIP'"

    # When CCL is active, there shouldn't be any insecure devices
    @devices = []
    unless ccl_active?
      @devices = Device.includes(:user).where(where_clause)
    end

    @total_pages = (Device.where(where_clause).size.to_d / items_per_page).ceil

    options_page

    session[:devices_insecure_devices_options] = @options
  end

  private

  # ticket #5014 this logic is more suited to be in controller than in view.
  # About exception - it might occur if device(but not provider's) has no voicemail_box.
  # this would only mean that someone has corruped data.
  def set_voicemail_variables(device)
    begin
      @device_voicemail_active = device.voicemail_active
      @device_voicemail_box = device.voicemail_box
      @device_voicemail_box_email = @device_voicemail_box.email
      @device_voicemail_box_password = @device_voicemail_box.password
      @device_deletevm = @device_voicemail_box[:delete]

      @fullname = @device_voicemail_box.fullname
      @device_enable_mwi = device.enable_mwi
      @device_subscribemwi = device.subscribemwi
    rescue NoMethodError
      flash[:notice] = _('Device_voicemail_box_not_found')
      redirect_to :root
    end
  end

  def create_empty_callflow(device_id, cf_type)
    callflow = Callflow.new({ device_id: device_id, cf_type: cf_type, priority: 1, action: 'empty' })
    callflow.save
    callflow
  end

 # Checks if accountant is allowed to create devices.
  def check_for_accountant_create_device
    if accountant? and session[:acc_device_create] != 2
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
  end

 # Clears values accountant is not allowed to send
  def sanitize_device_params_by_accountant_permissions
    if accountant?
      params_device = params[:device]

      if params_device
        params_device = params_device.except(:pin) if session[:acc_device_pin].to_i != 2
        params_device = params_device.except(:extension) if session[:acc_device_edit_opt_1] != 2
      end

      if (session[:acc_device_edit_opt_2] != 2) && params_device
        params_device = params_device.except(:name)
        params_device = params_device.except(:secret)
      end

      params[:device] = params_device
      params_blank = params.blank?

      params = params.except(:cid_name) if session[:acc_device_edit_opt_3] != 2 && params.present?
      params = params.except(:cid_number) if session[:acc_device_edit_opt_4] != 2 && params.present?
    end

    params
  end

  def devices_all_order_by(params, options)
    order_by = case params[:order_by].to_s
               when 'user'
                 'nice_user'
               when 'acc'
                 'devices.id'
               when 'description'
                 'devices.description'
               when 'pin'
                 'devices.pin'
               when 'type'
                 'devices.device_type'
               when 'extension'
                 'devices.extension'
               when 'username'
                 'devices.name'
               when 'secret'
                 'devices.secret'
               when 'cid'
                 'devices.callerid'
               else
                 default = true
                 options[:order_by] ? options[:order_by] : "nice_user"
    end

    without = order_by
    options[:order_desc].to_i == 1 ? order_by += " DESC" : order_by += " ASC"
    order_by += ', devices.id ASC ' if !order_by.include?('devices.id')
    return without, order_by, default
  end

  def check_pbx_addon
    if !pbx_active?
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      (redirect_to :root) && (return false)
    end
  end

  def find_fax_device
    @device = Device.where(id: params[:id], device_type: 'FAX').first

    unless @device
      flash[:notice] = _('Device_was_not_found')
      redirect_back_or_default('/callc/main')
    end
  end

  def find_device
    unless Device.where(id: params[:id]).size == 1
      flash[:notice] = _('Device_was_not_found')
      redirect_back_or_default('/callc/main')
    else
      @device = Device.where(id: params[:id]).includes(:user, :dids).first
    end
  end

  def find_email
    @email = Pdffaxemail.where(id: params[:id]).first

    unless @email
      flash[:notice] = _('Email_was_not_found')
      redirect_back_or_default('/callc/main')
    end
  end

  def find_cli
    @cli = Callerid.includes(:device).where(id: params[:id]).first
    unless @cli
      flash[:notice] = _('Callerid_was_not_found')
      (redirect_to :root) && (return false)
    else
      check_cli_owner(@cli)
    end
  end

  def check_cli_owner(cli)
    device = cli.device
    user = device.user if device

    unless user && (user.owner_id == correct_owner_id || user.id == session[:user_id])
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
  end

  def verify_params
    unless params[:device]
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
  end

  def check_callback_addon
    unless callback_active?
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
  end

  def create_cli
    cli = Callerid.new(cli: params[:cli], device_id: params[:device_id], comment: params[:comment].to_s,
                       banned: params[:banned].to_i, added_at: Time.now)
    params_description, params_ivr = [params[:description], params[:ivr]]
    cli.description = params_description if params_description
    cli.ivr_id = params_ivr if params_ivr

    if cli.save
      Callerid.use_for_callback(cli, params[:email_callback])
      flash[:status] = _('CLI_created')
    else
      flash_errors_for(_('CLI_not_created'), cli)
    end
  end

  def check_with_integrity
    session[:integrity_check] = Device.integrity_recheck_devices if current_user && current_user.usertype.to_s == 'admin'
  end

  def erase_ipaddr_fullcontact
    params_device = params[:device]

    if params_device && (params_device[:name] != @device.name) && (params[:ip_authentication_dynamic].to_i == 2)
      @device.assign_attributes({ ipaddr: '', fullcontact: nil, reg_status: '' })
      @device.save
    end
  end

  def allow_dahdi?
    session_device = session[:device]
    !reseller? || (session_device && session_device[:allow_dahdi] == true)
  end

  def allow_virtual?
    session_device = session[:device]
    !reseller? || (session_device && session_device[:allow_virtual] == true)
  end

  def set_options_page
    options_page, params_page = [@options[:page], params[:page]]
    params_page ? @options[:page] = params_page.to_i : (@options[:page] = 1 if !options_page || options_page <= 0)
  end

  def options_page
    total_pages = @total_pages.to_i
    @options[:page] = total_pages if (total_pages < @options[:page].to_i) && (total_pages > 0)
  end

  def set_qualify_time
    device_qualify = @device.qualify
    @qualify_time = (device_qualify == 'no') ? 2000 : device_qualify
  end

  def user_is_not_device_owner
    @device.user_id != @user.id
  end

  def set_params_device_name(change_opt_second)
    params_device = params[:device]
    params[:device][:name] = change_opt_second ? params_device[:name].to_s.strip : @device.name
  end

  def correct_current_user_id
    @current_user_id = (current_user.usertype == 'accountant') ? 0 : current_user_id
  end

  def cli_attributes_to_assign
    attributes = { cli: params[:cli],
                   description: params[:description],
                   comment: params[:comment],
                   banned: (params[:banned].to_i == 1 ? 1 : 0)
                 }
  end

  def set_return_action
    params_return_to_action = params[:return_to_action]
    @return_action = params_return_to_action if params_return_to_action
  end

  def set_return_controller
    params_return_to_controller = params[:return_to_controller]
    @return_controller = params_return_to_controller if params_return_to_controller
  end

  def set_cid_name_and_number
    device_callerid = @device.callerid

    if device_callerid
      @cid_name = nice_cid(device_callerid)
      @cid_number = cid_number(device_callerid)
    else
      @cid_name = ''
    end
  end

  def get_number_pools
    if admin? || reseller?
      @number_pools = NumberPool.where(owner_id: current_user_id).order('name ASC').all.collect { |pool| [pool.name, pool.id] }
    end
  end

  def set_servers(device_type)
    @servers = (device_type == 'SIP') && ccl_active? ? @sip_proxy_server : @asterisk_servers
  end

  def load_devicetypes
    @devicetypes = @device.load_device_types('dahdi' => allow_dahdi?, 'Virtual' => allow_virtual?)
  end

  def get_tariffs
    @tariffs = Tariff.tariffs_for_device(current_user_id)
  end

  def get_locations
    @locations = Location.locations_for_device_update(reseller?, correct_owner_id)
  end

  def set_forward_devices
    forward_device = Device.where(id: @cfs.first.data).first

    if forward_device
      forward_device_user = forward_device.user
      @user_fw = forward_device_user.try(:id)
      @devices = forward_device_user.try(:devices) || []
      @nice_user_fw = nice_user(forward_device_user)
    else
      @user_fw = -2
    end
  end

  def devices_title_and_icon
    @page_title = _('Devices')
    @page_icon = 'device.png'
  end

  def update_device_cid
    cid_name, cid_number, cid_number_from_did = [params[:cid_name], params[:cid_number], params[:cid_number_from_did]]
    cid_number_from_did_present = cid_number_from_did.try(:length).to_i > 0
    device_type = @device.device_type

    if (device_type != 'FAX') && (cid_name || cid_number || cid_number_from_did_present)
      cid_num = cid_number_from_did_present ? cid_number_from_did : cid_number
      @device.update_cid(cid_name, cid_num)
      sip = device_type == 'SIP' ? 1 : 0
      iax = device_type == 'IAX2' ? 1 : 0
      @device.prune_device_in_all_servers(nil, 1, sip, iax)
    end
    # CID control by DIDs (CID can be only from the set if DIDs)
    @device.update_cid('', '') if params[:cid_from_dids] == '1'
  end

  def set_page_and_devices_for_it(user_devices)
    session_items_per_page, params_page = [session[:items_per_page].to_i, params[:page].to_i]
    items_per_page = session_items_per_page < 1 ? 1 : session_items_per_page
    total_items = user_devices.length
    total_pages = (total_items.to_d / items_per_page.to_d).ceil
    page_no = params_page < 1 ? 1 : params_page
    page_no = total_pages if total_pages < page_no
    offset = total_pages < 1 ? 0 : items_per_page * (page_no - 1)
    @devices = user_devices.limit(items_per_page).offset(offset)
    @page, @total_pages = [page_no, total_pages]
  end

  def get_default_device_insecure
    params_insecure_port_equal_to_one = (params[:insecure_port] == '1')
    params_insecure_invite_equal_to_one = (params[:insecure_invite] == '1')
    insecure = if params_insecure_port_equal_to_one && !params_insecure_invite_equal_to_one
                 'port'
               elsif params_insecure_port_equal_to_one && params_insecure_invite_equal_to_one
                 'port,invite'
               elsif !params_insecure_port_equal_to_one && params_insecure_invite_equal_to_one
                 'invite'
               else
                 nil
               end
  end

  def get_default_device_qualify(params_device)
    if params[:qualify] == 'yes'
      if ccl_active? && (params_device[:device_type] == 'SIP')
        'no'
      else
        params[:qualify_time]
      end
    else
      'no'
    end
  end

  def modify_extlines(old_ext)
    @device.update_extline_appdata(params[:device][:extension], old_ext)
    queue_agents = QueueAgent.where(device_id: params[:id]).all.to_a
    if queue_agents.size > 0
      used_queues = queue_agents.map(&:queue_id)
      used_queues.each do |queue_id|
        queue = AstQueue.where(id: queue_id).first
        reload_servers(get_servers_for_reload(ccl_active?, queue.server_id)) if queue.present?
      end
    end
    # change callflow
    forwarded_to = Callflow.where(action: 'forward', data2: 'local', data: params[:id]).first
    if forwarded_to.present?
      extlines = Extline.where("appdata like '%#{old_ext},%'").all.to_a
      extlines.each do |ext|
        appdat = ext.appdata.to_s.split(',')
        # appdat size = 2 > without pbx pool, size = 3 with pbx pool ex: pool_2_mor_local,1111,1 and 1111,1
        pos = appdat.size == 2 ? 0 : 1
        appdat[pos] = "#{params[:device][:extension]}"
        new_appdata = appdat.join(',')
        ActiveRecord::Base.connection.update("UPDATE `extlines` SET `appdata` = '#{new_appdata}' WHERE `extlines`.`id` = #{ext.id}")
      end
    end
  end

  def set_action_for_pdffaxemail
    @pdffax_email_action = user? ? 'user_device_edit' : 'device_edit'
  end

  def authorize_pdffaxemail
    if current_user.try(:usertype).to_s == 'user' && Confline.get_value('Allow_User_to_change_FAX_email', current_user.owner_id).to_i != 1
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      (redirect_to :root) && (return false)
    end
  end

  def ip_range_subnet(ip)
    ip.match(/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[0-9]{1,2}$/) || ip.match(/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\-[0-9]{1,3}$/)
  end
end
