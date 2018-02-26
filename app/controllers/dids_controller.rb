# -*- encoding : utf-8 -*-
# DIDs managing.
class DidsController < ApplicationController
  layout 'callc'


  before_filter :private_access_denied, only: [:quickforwarddid_edit], if: -> { !(user? || admin?) }
  before_filter :access_denied, only: [:list, :edit, :update, :new, :create, :destroy], if: -> { User.current.try(:owner).try(:is_partner?) && !current_user.load_dids.present? }
  before_filter :access_denied_user_dids, only: [:did_edit, :did_update], if: -> { !allow_user_assign_did_functionality }
  before_filter :check_post_method, only: [:destroy, :create, :update]
  before_filter :check_localization
  before_filter :authorize

  before_filter :check_user_for_dids, except: [:personal_dids, :quickforwarddids, :quickforwarddid_edit,
    :quickforwarddid_update, :quickforwarddid_destroy, :did_edit, :did_update, :update_did]
  before_filter { |controller|
    view = [:index, :list, :show, :did_rates]
    edit = [:new, :create, :edit, :update, :destroy, :edit_rate, :bulk_management, :confirm_did, :assign_to_dp]
    allow_read, allow_edit = controller.check_read_write_permission(view, edit, {role: "accountant", right: :acc_manage_dids_opt_1, ignore: true})
    controller.instance_variable_set :@allow_read, allow_read
    controller.instance_variable_set :@allow_edit, allow_edit
    true
  }

  before_filter :check_device_presence, only: [:update]
  before_filter :find_dids, only: [:dids_interval_edit, :dids_interval_trunk, :dids_interval_add_to_trunk,
    :dids_interval_rates, :dids_interval_add_to_user, :dids_interval_delete, :dids_interval_assign_dialplan]
  before_filter :find_provider, only: [:create]
  before_filter :check_dids_creation, only: [:new, :create, :confirm_did]
  before_filter :check_did_params, only: [:update]
  before_filter :load_ok?, only: [:summary]
  before_filter :bulk_management, only: [:confirm_did_action]

  def index
    redirect_to action: :list and return false
  end

  # if language was not passed as search parameter, set it to default value 'all'.
  # keep in mind we should refactor, cause 'all' is duplicated in controler and view.
  def list
    current_user_usertype = current_user.usertype
    @page_title = _('DIDs')
    @page_icon = "did.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/DID_Management"
    @iwantto_links = [
        ['Learn_more_about_DIDs', "http://wiki.kolmisoft.com/index.php/MOR_Manual#DIDs"],
        ['Understand_DID_billing', "http://wiki.kolmisoft.com/index.php/DID_Billing"],
        ['Check_DIDs_assigned_to_me', "http://wiki.kolmisoft.com/index.php/Personal_DIDs"],
        ['Configure_DID_to_ring_some_Device', "http://wiki.kolmisoft.com/index.php/Personal_DIDs"],
        ['Forward_DID_to_external_number', "http://wiki.kolmisoft.com/index.php/Forward_DID_to_External_Number"],
        ['Charge_DID_on_a_monthly_basis', 'http://wiki.kolmisoft.com/index.php/How_to_charge_DID_on_a_monthly_basis'],
        ['Block_DID', "http://wiki.kolmisoft.com/index.php/DID_Blocking"]]

    # order
    default_options = {
      page: 1,
      order_by: 'ID',
      order_desc: 1
      }
    params_page = params[:page]
    params_order = params[:order_desc]
    params_order_by = params[:order_by]
    @options = session[:dids_order_by_options] || default_options
    params_page_i = params_page.to_i
    current_user_id = current_user.id

    @options[:page] = params_page_i if params_page

    @options[:order_by] = params_order_by.to_s if params_order_by
    @options[:order_desc] = params_order.to_i if params_order

    order_by = Did.dids_order_by(@options)

    session[:dids_order_by_options] = @options

    #search
    params_clean = params[:clean].to_i
    params_clean_is_one =  params_clean == 1
    session[:dids_search] = 1 if params[:search_on]
    params_page ? @page = params_page_i : @page = 1
    session[:dids_search] = 0 if params_clean_is_one

    if params_clean_is_one or !session[:did_search_options]
      session[:did_search_options] = {s_language: 'all'}
      params[:s_language] = 'all' if !params[:s_language]
    end

    session[:did_search_options] ||= {}
    hide_terminated_dids = Confline.get_value('hide_terminated_dids', current_user_id).to_i
    session[:did_search_options]['s_hide_terminated_dids'] = hide_terminated_dids

    [:search_did, :search_did_owner, :search_provider, :search_dialplan, :search_language, :search_status, :search_user, :search_user_id, :search_device, :search_hide_terminated_dids].each do |param|
      set_search_param(param)
    end
    search_user_id = @search_user_id
    search_user_id_to_i = search_user_id.to_i
    search_did_owner_strip = @search_did_owner.strip

    Confline.set_value('hide_terminated_dids', @search_hide_terminated_dids, current_user_id) unless @search_hide_terminated_dids.to_i == hide_terminated_dids

    @dids = Did.get_dids(current_user, @search_user, @search_user_id, @search_language, @search_did, @search_did_owner, @search_device, @search_provider, @search_dialplan, @search_status, @search_hide_terminated_dids)

    if params[:csv].to_i == 0
      unless current_user_usertype == 'reseller'
        @providers = current_user.load_providers
      end

      @dialplans = Dialplan.where(user_id: current_user_id)

      sql = 'SELECT DISTINCT language FROM dids ORDER by language'
      @languages = ActiveRecord::Base.connection.select_all(sql)

      if search_user_id and search_user_id_to_i.to_s == search_user_id
        @devices = Device.select("id, device_type, extension, name, username").where(["devices.user_id = ? AND name not like 'mor_server_%'", search_user_id_to_i]).order("devices.name ASC")
      else
        @devices = []
      end

      @dids = @dids.having("nice_user like ?", '%'+search_did_owner_strip) if @search_did_owner and search_did_owner_strip.length > 0

      total_dids = @dids.length
      session_items_per_page = session[:items_per_page]
      @total_pages = (total_dids.to_d / session_items_per_page.to_d).ceil
      @page = @total_pages if @page > @total_pages
      @page = 1 if @page < 1

      @show_did_rates = !(session[:usertype] == "accountant" and session[:acc_manage_dids_opt_1] == 0 or reseller?)

      iend = session_items_per_page * (@page-1)

      @dids = @dids.order(order_by).limit(session_items_per_page).offset(iend).all

    else
      @dids = @dids.having("nice_user like ?", '%' + search_did_owner_strip) if @search_did_owner and search_did_owner_strip.length > 0
      @dids = @dids.order(order_by).all

      sep, dec = current_user.csv_params

      csv_string = "DID#{sep}Provider#{sep}Language#{sep}Status#{sep}User/Dial_Plan#{sep}Device#{sep}Call_limit#{sep}Comment\n"
      for did in @dids
        did_user_last_name = did.user.last_name
        did_user_first_name = did.user.first_name
        did_status = did.status
        did_diaplan = did.dialplan

        if did.user_id != 0
          user_d_plan= did_user_first_name + " " + did_user_last_name
        else
          if did.dialplan_id == 0 and did_status != "free"
            user_d_plan = did_user_first_name + " " + did_user_last_name
          else
            user_d_plan = did_diaplan.name if did_diaplan
          end
        end
        csv_string += "#{did.did.to_s}#{sep}#{did.provider.name}#{sep}#{did.language}#{sep}#{did_status.capitalize}#{sep}#{user_d_plan}#{sep}#{nice_device(did.device)}#{sep}#{did.call_limit}#{sep}#{did.comment}\n"
        user_d_plan = ''
      end

      filename = "DIDs.csv"

      if params[:test].to_i == 0
        send_data(csv_string, type: 'text/csv; charset=utf-8; header=present', filename: filename)
      else
        render text: csv_string
      end
    end
  end

  def show
    @did = Did.where(id: params[:id]).first
    unless @did
      flash[:notice]=_('DID_was_not_found')
      redirect_to action: :index and return false
    end
  end

  def new
    @did = Did.new
    @page_title = _('New_did')
    @page_icon = 'add.png'
    @help_link = "http://wiki.kolmisoft.com/index.php/DID_Management#Add_new_DID.28s.29"
    @options = session[:new_dids_creation] || Hash.new(nil)

    if current_user.usertype == 'reseller'
      @providers = current_user.providers.where(['hidden=?', 0]).order("name ASC")
    else
      @providers = Provider.where('hidden = 0 AND user_id = 0').order("name ASC")
    end
    @bulk_form = Forms::Dids::BulkForm.new
  end

  def create_did_rates(did, cache = nil)
    did_id = did.id
    rate_types = ['provider', 'owner', 'incoming']
    if cache
      values = []
      rate_types.each do |type|
        values << "'2000-01-01 23:59:59', 1, '#{type}', 0.0, 0, 0.0, #{did_id}, '2000-01-01 00:00:00'"
      end
      cache.add(values, true)
    else
      rate_types.each do |type|
        Didrate.new(did_id: did_id, rate_type: type).save
      end
    end
  end


 # @provider is set in before_filter
  def create
    provider_id = (current_user.usertype == 'reseller' and current_user.own_providers.to_i == 0) ? Confline.get_value("DID_default_provider_to_resellers").to_i.to_s : params[:provider]
    if params[:amount] == "one" # Create just one did
      @did = Did.new(did: params[:did].to_s.strip, provider_id: provider_id, reseller_id: corrected_user_id)
      if @did.save
        create_did_rates(@did)
        add_action(session[:user_id], 'did_created', @did.id)
        flash[:status] = _('Did_was_successfully_created')
        redirect_to action: 'list'
      else
        flash_errors_for(_('Did_was_not_created'), @did)
        redirect_to action: 'new'
      end
    else
      @file = File.open('/tmp/' + params[:filename].to_s, "wb")
      tname = params[:filename].to_s
      session[:tname] = params[:filename].to_s
      colums ={}
      colums[:colums] = [{name: "did", type: "VARCHAR(50)", default: ''},{name: "f_error", type: "INT(4)", default: 0},{name: "id", type: 'INT(11)', inscrement: ' NOT NULL auto_increment '}]
      begin
        CsvImportDb.load_csv_into_db(tname, '', '.', '', "/tmp/", colums, false)

        @total_numbers, @imported_numbers = Did.insert_dids_from_csv_file(tname,corrected_user_id, provider_id.to_i)


        if @total_numbers.to_i == @imported_numbers.to_i
          flash[:status] = _('DIDs_were_successfully_imported')
          redirect_to action: "list"
        else
          flash[:status] = _('M_out_of_n_dids_imported', @imported_numbers, @total_numbers)
          redirect_to action: "dids_imported", fname: params[:filename].to_s, file_size: @file.size.to_s and return false
        end

      rescue => rescued_error
        MorLog.log_exception(rescued_error, Time.now.to_i, params[:controller], params[:action])
        CsvImportDb.clean_after_import(tname, "/tmp/")
        flash[:notice] = _('MySQL_permission_problem_contact_Kolmisoft_to_solve_it')
        redirect_to action: "new" and return false
      end
    end
  end

  def create_bulk
    bulk_form = Forms::Dids::BulkForm.new(params[:bulk_form])

    unless bulk_form.valid?
      flash_errors_for(_('DIDs_were_not_created'), bulk_form)
      redirect_to action: :new and return false
    end

    factory = Did::BulkFactory.new(bulk_form.attributes)
    factory.fabricate!

    valid_dids = factory.dids_created
    invalid_dids = factory.invalid_dids
    number_of_invalid_dids = invalid_dids.size

    #Error handling logic and all - seems that something was not working before
    if number_of_invalid_dids > 0
      flash_collection_errors_for("#{number_of_invalid_dids} #{ _('DIDs_were_not_created')}", invalid_dids)
    end
    if valid_dids > 0
      flash[:status] = "1 #{_("Did_was_successfully_created")}" if valid_dids == 1
      flash[:status] = "#{valid_dids} #{_('Dids_were_successfully_created')}" if valid_dids > 1
    end
    redirect_to :action => 'list'
  end

  def confirm_did
    @page_title = _('New_did')
    @page_icon = 'add.png'
    @help_link = "http://wiki.kolmisoft.com/index.php/E.164"
    good_params = params.except("file")
    session[:new_dids_creation] = good_params
    @provider = nil
    provider_id = params[:did] ? params[:did][:provider_id] : params[:forms_dids_bulk_form].try(:[], :provider)
    if current_user.usertype == 'reseller'
      provider_id = allow_manage_providers_tariffs? ? provider_id : Confline.get_value("DID_default_provider_to_resellers").to_i.to_s
    end
    @provider = Provider.where(["id=?", provider_id]).first if provider_id

    if !@provider or (current_user.usertype == 'reseller' and @provider and !current_user.providers.where(['hidden=? AND id = ?', 0, @provider.id]).first and @provider.id != Confline.get_value("DID_default_provider_to_resellers").to_i)
      flash[:notice]=_('Provider_was_not_found')
      redirect_to :action => :list and return false
    end
    @amount = params[:amount]
    if @amount == "one"
      @did = params[:did][:did]
      if @did.length < 10 or @did[0..0].to_i == 0
        @notice = _('DID_not_e164_compatible')
      end
    elsif @amount == "amount_interval"
      @start=params[:forms_dids_bulk_form][:start_number].to_s
      @end=params[:forms_dids_bulk_form][:end_number].to_s
      if @start.length != @end.length
        flash[:notice]=_('DIDs_has_to_be_equal_in_length')
        redirect_to :action => :new and return false
      end
      if (@start[0..0].to_i == 0 or @start.length < 10) or (@end[0..0].to_i == 0 or @end.length < 10)
        @notice = _('DID_not_e164_compatible')
      end
    else
      if params[:file]
        @file = params[:file]
        if @file.size > 0
          if !@file.respond_to?(:original_filename) or !@file.respond_to?(:read) or !@file.respond_to?(:rewind)
            flash[:notice] = _('Please_select_file')
            redirect_to :action => "new" and return false
          end
          if get_file_ext(@file.original_filename, "csv") == false
            @file.original_filename
            flash[:notice] = _('Please_select_CSV_file')
            redirect_to :action => "new" and return false
          end
          @file.rewind
          file = @file.read.gsub("\r\n", "\n")
          session[:file_size] = file.size
          session[:filename] = @file.original_filename.to_s
          @tname = CsvImportDb.save_file(session[:file_size].to_i, file, "/tmp/")
          @all_dids = file.split("\n").select { |line| line.to_s.strip.gsub(/\s+/, '') unless line.to_s.strip.blank? }
        else
          flash[:notice] = _('Please_select_file')
          redirect_to :action => "new" and return false
        end
      else
        flash[:notice] = _('Please_upload_file')
        redirect_to :action => "new" and return false
      end
    end
  end


  def edit
    if reseller?
      @did = Did.includes(:user, :dialplan).where(["dids.id = ? AND dids.reseller_id = ?", params[:id], current_user.id]).first
    else
      @did = Did.includes(:user, :dialplan).where(["dids.id = ?", params[:id]]).first
    end

    unless @did
      flash[:notice]=_('DID_was_not_found')
      redirect_to :action => :index and return false
    end
    default_edit_details

    @page_title = _('DID_edit') + ": " + @did.did
    @page_icon = 'edit.png'
    @help_link = "http://wiki.kolmisoft.com/index.php/DID_Management#Settings"

    if current_user.usertype == 'reseller'
      @providers = current_user.providers.where(['hidden=?', 0]).order("name ASC")
    else
      @providers = Provider.where(['hidden=?', 0]).order("name ASC")
    end
    @back_controller = "dids"
    @back_action = "list"
    @back_controller = params[:back_controller] if params[:back_controller]
    @back_action = params[:back_action] if params[:back_action]
    # users
    @did.dialplan_id > 0 ? dp_cond = " AND usertype != 'reseller'" : dp_cond = ""
    @free_users = User.select("id, username, first_name, last_name, #{SqlExport.nice_user_sql}").where((reseller? ? ["hidden = 0 AND owner_id = ?", current_user.id] : "hidden = 0" + dp_cond)).order("nice_user ASC")

    # devices
    @free_devices = []
    if (@did.user)
      @free_devices = @did.user.devices.where(:istrunk => 0)
    end

    # trunks
    sql = "SELECT devices.*, #{SqlExport.nice_user_sql} FROM devices
              left join users on (devices.user_id = users.id)
              where devices.istrunk = 1 and users.owner_id = '#{accountant? ? 0 : session[:user_id]}' ORDER BY nice_user"

    @available_trunks = Device.find_by_sql(sql)

    # assign possible choices what to do with did
    @choice_free = @did.reseller ? (reseller? ? false : true) : false
    @choice_reserved = false
    @choice_active = false
    @choice_closed = false
    @choice_terminated = false

    # QF Rule default values
    @qf_rule_collisions = false
    @rs_rules = false
    @rs_show_dp = false

    @is_reseller = reseller?

    if @is_reseller
      res_scope_rules = QuickforwardsRule.where("'#{@did.did}' REGEXP(concat('^',replace(replace(rule_regexp, '%', ''),'|','|^'))) and user_id in (0,#{current_user.id})")
      @rs_rules = true if res_scope_rules.collect(&:user_id).include?(current_user.id)
      @rs_show_dp = true if res_scope_rules.collect(&:id).include?(current_user.quickforwards_rule_id)
      @qf_rule_collisions = true if res_scope_rules.size.to_i > 0
    else
      @qf_rule_collisions = true if @did.find_qf_rules.to_i > 0
    end

    # DialPlan variables (DID's for dialplan)
    @choice_free_dp = false
    @choice_active_dp = false
    @reseller_can_assing_to_trunk = Confline.get_value('Resellers_Allow_Assign_DID_To_Trunk').to_i == 1

    if @did.status == "free"
      if @did.reseller and !reseller?
        @choice_reserved = false
        @choice_terminated = false
        @choice_free_dp = false
      else
        @choice_reserved = true unless @qf_rule_collisions
        @choice_terminated = true
        @choice_free_dp = true
      end
    end

    if @did.status == "reserved"
      @choice_free = true
      @choice_active = true
    end

    if @did.status == "active"
      @choice_active = true
      @choice_closed = true
      @choice_active_dp = true if @did.dialplan or @did.dialplan_id.to_i > 0
    end

    if @did.status == "closed"
      @choice_free = true
      @choice_active = true
      @choice_terminated = true
    end

    if @did.status == "terminated"
      @choice_free = true
    end

    if @choice_free_dp
      accountant? ? @dialplan_source = Dialplan.where(:user_id => 0) : @dialplan_source = current_user.dialplans

      @qfddps = @dialplan_source.where("dptype = 'quickforwarddids' AND id != 1").order("name ASC")

      unless @qf_rule_collisions
        @ccdps = @dialplan_source.where(:dptype => 'callingcard').order("name ASC")
        @abpdps = @dialplan_source.where(:dptype => 'authbypin').order("name ASC")

        if callback_active?
          @cbdps = @dialplan_source.where(["dptype = 'callback' AND data1 != ?", @did.id]).order("name ASC")
        else
          @cbdps = @dialplan_source.where(["dptype = 'callback' AND data1 != ?", @did.id]).order("name ASC").limit(1)
        end

        @dp_has_dids = (@cbdps.blank? ? 0 : Did.where(dialplan_id: @cbdps.first.id, status: 'active').count)
        @allow_add_cbdid = ((@dp_has_dids.to_i < 1) or callback_active?)

        @pbxfdps = @dialplan_source.where(:dptype => 'pbxfunction').order("name ASC")
        @ivrs = @dialplan_source.where(:dptype => 'ivr').order("name ASC")
        @vm_extension = Confline.get_value("VM_Retrieve_Extension", 0)
        @ringdps = @dialplan_source.where(:dptype => 'ringgroup').order("name ASC")
        @queues = @dialplan_source.where(:dptype => 'queue').order("name ASC")
      end
    end

    @tone_zones = ['at', 'au', 'be', 'br', 'ch', 'cl', 'cn', 'cz', 'de', 'dk', 'ee', 'es', 'fi', 'fr', 'gr', 'hu', 'it', 'lt', 'mx', 'ml', 'no', 'nz', 'pl', 'pt', 'ru', 'se', 'sg', 'uk', 'us', 'us-old', 'tw', 've', 'za', 'il'].sort
    @cc_tariffs = Tariff.where(["purpose != 'provider' and owner_id = ?", correct_owner_id])

  end

  def update
    status = params[:status].to_s.strip
    params[:user_id] = params[:s_user_id] if params[:s_user_id].present?
    params_settings_are_details = params[:BMUpdate_setting].to_s == 'details'
    if params[:id]

      if reseller?
        did = Did.where(["dids.id = ? AND dids.reseller_id = ?", params[:id], current_user.id]).first
      else
        did = Did.where(["dids.id = ?", params[:id]]).first
      end

      unless did
        flash[:notice]=_('DID_was_not_found')
        redirect_to :action => :index and return false
      end
      did_id = did.id

      did.tonezone = params[:did][:tonezone] if params[:did] and params[:did][:tonezone]
      did.sound_file_id = params[:did][:sound_file_id] if params[:did] and params[:did].has_key?(:sound_file_id)
      did.cc_tariff_id = params[:did][:cc_tariff_id] if params[:did] and params[:did][:cc_tariff_id]

      ["t_digit", "t_response", "grace_time"].each do |key|
        did[key] = params[:did][key] if params[:did] and params[:did].has_key?(key)
      end

      update_did(did, status, 1)
      add_action(session[:user_id], 'did_edited', did_id)
    else
      params[:device_id] = params[:s_device] if params[:s_device].present?
      from = params[:from]
      till = params[:till]
      user_id = params[:user_id].to_i

      if params_settings_are_details
        options = {
            from: from,
            till: till,
            active: params[:active]
        }
        @dids = find_dids_on_condition(options)
      else
        find_dids # finds @dids ant sets @opts (additional request params)
      end

      if reseller?
        all_dids = Did.where("did BETWEEN '#{from.to_s}' AND '#{till.to_s}' AND dids.reseller_id = '#{current_user.id}'").count
      else
        all_dids = Did.where("did BETWEEN '#{from.to_s}' AND '#{till.to_s}'").count
      end

      error_did = Did.new

      @dids_size = @dids.size.to_i

      @dids.each do |did|
        update_did(did, status, 0)
        add_action(current_user.id, 'did_edited', did_id)
      end

      dids_size = @dids_size
      difference_dids_all = (all_dids - dids_size).to_s
      if params_settings_are_details
        if (dids_size == all_dids) and (all_dids > 0)
          flash[:status] = _('dids_successfully_updated')
        else
          if (dids_size != 0)
            flash[:status] = _('n_out_of_m_dids_updated', dids_size.to_s, all_dids.to_s)
          end
          message = _('n_dids_were_not_updated', difference_dids_all)
          message += '<br/> * '
          message += _('Only_DIDs_with_owned_Providers_can_be_managed')
          flash[:notice] = message
        end

        if error_did.errors.size > 0
          if dids_size == 0
            flash_errors_for(_('DIDs_were_not_updated', ''), error_did)
          else
            flash_errors_for(_('n_dids_were_not_updated', difference_dids_all), error_did)
          end
          redirect_to({action: 'dids_interval_edit'}.merge(@opts)) and return false
        end
      end

      device_options = @opts[:device]

      if status == 'reserved'
        error_did = Did.new
        user = User.where(id: user_id).first
        did_owner_usertype = user ? user.usertype.to_s : ''
        filtered_user = params[:user].to_i

        if (filtered_user > 0 && filtered_user != user_id)
          flash[:notice] =  _('DIDs_were_not_selected') + '<br/>' + '* ' + _('No_DID_found_Please_check_interval')
          redirect_to({:action => 'dids_interval_edit'}.merge(@opts)) and return false
        end

        if reseller?
          condition = ''
          condition << " AND user_id = #{user.id}" if user
          condition << " AND device_id = #{device_options}" if device_options && params[:management_action] != 'interval_edit'
          total_dids_assigned = Did.where("reseller_id = #{current_user.id.to_i} AND did BETWEEN '#{from.to_s}' AND '#{till.to_s}'" + condition.to_s).count
          total_dids_not_assigned = all_dids - total_dids_assigned
        else
          # Calculate how many DIDs belong to user/reseller after DID update
          total_dids_assigned = Did.where("#{did_owner_usertype == 'reseller' ? 'reseller_id' : 'user_id'} = #{user_id} AND did BETWEEN '#{from}' AND '#{till}'").count
          # Now we can calculate how many were updated
          total_dids_not_assigned = all_dids - total_dids_assigned
        end

        if total_dids_not_assigned > 0
          flash[:notice] = "#{total_dids_not_assigned} #{_('DIDs_were_not_updated')}<br/> * #{_('DID_already_assigned_user_dial')}"
        end

        if total_dids_assigned > 0
          if params[:device_id].to_i > 0
            flash[:status] = "#{total_dids_assigned} #{_('Assigned_did')}"
          else
            flash[:status] = "#{total_dids_assigned} #{_('DIDs_were_updated')}"
          end
        end

        if params_settings_are_details
          flash[:status] = _('n_out_of_m_dids_updated', dids_size, all_dids)
          error_did.errors.add(:dids_assigned_to_prov, _('dids_dont_belong_to_provider'))
          if dids_size == 0
            flash_errors_for(_('DIDs_were_not_updated', ''), error_did)
          else
            flash_errors_for(_('n_dids_were_not_updated', bad_num_string), error_did)
          end
        end
      elsif status == 'free'
        flash[:status] = [dids_size, _('DID_made_available')].join(" ") if dids_size > 0
        params[:user_id] = ""
      end

      @opts[:user] = params[:user_id] if params[:user_id]
    end

    if params[:id]
      redirect_to :action => 'edit', :id => params[:id], s_user_id: params[:s_user_id], s_user: params[:s_user] and return false
    else
      # @opts is beeing set in find_dids method
      if params[:back]
        redirect_to({:action => 'dids_interval_add_to_trunk'}.merge(@opts)) and return false
      else
        redirect_to(:action => 'list') and return false
        #ticket #5946
        #redirect_to({:action => 'dids_interval_edit'}.merge(@opts)) and return false
      end
    end
  end

  def update_did(did, status, comment)
    did_id = did.id
    param_did = params[:did]
    params_device = params[:device_id]
    if status == "provider"
      old_did_number, bad_provider = did.update_provider_did(params, current_user, comment)
      did.skip_conditions_callback = true
      if !bad_provider && did.save
        if param_did[:did] != old_did_number
          add_action_second(session[:user_id], 'did_changed_did_number', did_id, "From: "+old_did_number.to_s)
        end
        Action.add_action_hash(session[:user_id], {:target_type => 'provider', :target_id => param_did[:provider_id], :action => 'did_edit_provider', :data => did_id})
        flash[:status] = _('dids_successfully_updated')
      else
        if @dids_size
          @dids_size -= 1
        else
          flash[:notice] = _("DID_must_be_unique")
        end
      end
    end

    if status == "free"
      if reseller?
        did.make_free_for_reseller
      else
        did.make_free
      end
      add_action(session[:user_id], 'did_made_available', did_id)
      flash[:status] = _('one_DID_made_available')
      #  redirect_to :action => 'edit', :id => did.id and return false
    end

    if status == "active"
      old_dev_id = did.device_id
      if did.assign(params_device) && did.device.user
        access = configure_extensions(did.device_id, {:no_redirect => true, :current_user => current_user})
        return false if !access

        if old_dev_id.to_i > 0
          dev = Device.where({:id => old_dev_id}).first
          if dev && dev.user
            dev.primary_did_id = 0
            access= configure_extensions(old_dev_id, {:no_redirect => true, :current_user => current_user})
            return false if !access
          end
        end
        Action.add_action_hash(current_user.id, {:target_type => 'device', :target_id => old_dev_id, :action => 'did_assigned', :data => did_id})
        flash[:status] = _('DID_assigned')
      else
        flash_errors_for(_("Could_not_assign_did"), did)
      end
    end

    if status == "closed"
      did.close
      access = configure_extensions(did.device_id, {:no_redirect => true, :current_user => current_user})
      return false if !access
      add_action(session[:user_id], 'did_closed', did_id)
      flash[:status] = _('DID_closed')
    end

    if did.dialplan_id > 0 and status != "provider"
      if did.errors.size > 0
        flash_errors_for(_('Did_was_not_updated'), did)
      end
    end

    params_user_id = params[:user_id]
    # Check if not assigned to reseller and user not reseller or user is reseller and did assigned to reseller
    device_integer = params[:s_device].to_i
    # Only free DIDs can be reserved/assigned to user/device
    # Also, if DID belongs to user, then DID can be reassigned to other device (did.user_id == params_user_id)
    if status == "reserved" && (did.status.to_s == 'free' || did.user_id.to_i == params_user_id.to_i) && ((did.reseller_id == 0 && !reseller?) || (reseller? && did.reseller_id != 0))
      if did.reserve(params_user_id)
        if device_integer > 0
          did.unassing
          did.assign(params_device)
          flash[:status] = _('DID_assigned')
        else
          flash[:status] = _('DID_reserved')
        end
        add_action_second(session[:user_id], 'did_reserved', did_id, params_user_id)
      else
        flash_errors_for(_('Did_was_not_updated'), did)
      end
    end

    if status == "terminated"
      if did.device_id != 0
        access = configure_extensions(did.device_id, {:no_redirect => true, :current_user => current_user})
        return false if !access
      end
      did.terminate
      add_action(session[:user_id], 'did_terminated', did_id)
      flash[:status] = _('DID_terminated')
    end
  end

  def assign_to_dp
    if params[:id]
      @page_title = _('Assign_to_dialplan')
      did = Did.where(:id => params[:id]).first
      unless did
        flash[:notice]=_('DID_was_not_found')
        redirect_to :action => :index and return false
      end
      if params[:dp_id].to_i > 0
        dp = Dialplan.where(:id => params[:dp_id]).first
        unless dp
          flash[:notice]=_('Dialplan_was_not_found')
          redirect_to :action => :index and return false
        end
        did.dialplan = dp
      else
        flash[:notice]=_('Dialplan_was_not_found')
        redirect_to :action => :index and return false
      end
      did.status = "active"
      if did.save
        flash[:status] = _('Did_assigned_to_dp') + ": " + dp.name
        add_action_second(session[:user_id], 'did_assigned_to_dp', did.id, dp.id)
      else
        flash_errors_for(_('Did_was_not_updated'), did)
      end
      redirect_to :action => 'edit', :id => did.id
    else
      options = {:from => params[:from],
                 :till => params[:till], :active => params[:active].to_i,
      }
      options[:user] = params[:user].to_i if params[:user]
      options[:device] = params[:device].to_i if params[:device]

      free_dids = find_dids_on_condition(options, 'all', 'dids.status = \'free\'', 'dids.user_id = 0', 'dids.reseller_id = 0')

      did_errors = {
          active: find_dids_on_condition(options, 'count', 'dids.status = \'active\'', 'dids.dialplan_id != 0'),
          reserved: find_dids_on_condition(options, 'count', '((dids.user_id != 0 OR dids.reseller_id !=0) AND dids.dialplan_id = 0)'),
          quickforward: 0
      }

      assigned = 0
      total = find_dids_on_condition(options, 'count')

      did_error_messages = {
          active: 'dids_already_assigned_to_dialplan',
          reserved: 'dids_reserved',
          quickforward: 'dids_collide_with_quickforward_rule'
      }

      if params[:dp_id].to_i > 0
        dp = Dialplan.where(:id => params[:dp_id]).first
        unless dp
          flash[:notice]=_('Dialplan_was_not_found')
          redirect_to({:action => 'dids_interval_assign_dialplan'}.merge(@opts)) and return false
        end
      end
      free_dids.each do |did|
        did.assign_attributes({dialplan: dp,
                               status:'active'})
        if did.save
          add_action_second(session[:user_id], 'did_assigned_to_dp', did.id, dp.id)
          assigned += 1
        else
          did_errors[:quickforward] += 1 if did.errors.keys.include? :qf_rule_collision
        end
      end
      if assigned.eql? total
        flash[:status] = _('Dids_interval_assigned_to_dialplan')
        redirect_to({:action => :list})
      else
        did_errors.reject! {|_, value| value.zero?}
        error_list = String.new
        did_errors.each do |key, value|
          error_list << "* #{_(did_error_messages[key])}</br>"
        end
        if assigned.zero?
          flash[:notice] = _('dids_not_assigned_to_dialplan')
          flash[:notice] << "</br> #{error_list}"
        else
          flash[:status] = _('n_out_of_m_dids_assigned_to_dialplan', assigned.to_s, total.to_s)
          flash[:notice] = _('n_dids_not_updated', (total-assigned).to_s)
          flash[:notice] << "</br> #{error_list}"
        end
        redirect_to({:action => 'dids_interval_assign_dialplan'}.merge(@opts)) and return false
      end
    end
  end

  def assign_dp
    assign_type = params[:assign_type].strip
    @did = Did.where(:id => params[:id]).first
    unless @did
      flash[:notice]=_('DID_was_not_found')
      redirect_to :action => :index and return false
    end
    did_id = @did.id

    if assign_type == "callingcard"

      number_length = params[:number_length].strip
      pin_length = params[:pin_length].strip
      answer = params[:answer].strip

      # assign dp to did
      Did.assign_did_to_calling_card_dp(@did, answer, number_length, pin_length)
      add_action_second(session[:user_id], 'did_assign_did_to_calling_card_dp', did_id)
      flash[:status] = _('Did_assigned_to_dp') + ": " + did_id
    end


    if assign_type == "authbypin"
      assign_did_to_auth_by_pin_dp(@did)
      add_action_second(session[:user_id], 'did_assign_did_to_auth_by_pin_dp', did_id)
      flash[:status] = _('Did_assigned_to_dp') + ": " + did_id
    end


    redirect_to :action => 'list'
  end


  def destroy
    did = Did.where(:id => params[:id]).first
    unless did
      flash[:notice]=_('DID_was_not_found')
      redirect_to :action => :index and return false
    end
    didrates = did.didrates
    id = did.id
    if did.destroy
      didrates.each { |dr| dr.destroy }
      flash[:status] = _('Did_deleted')
      add_action(session[:user_id], 'did_deleted', id)
    else
      flash[:notice] = _('Did_can_not_delete')
    end

    redirect_to :action => 'list'
  end

  def quickforwarddids
    @page_title = _('Quick_Forwards')
    session_quickforwarddids_stats = session[:quickforwarddids_stats]
    unless user?
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    default = {
        :items_per_page => session[:items_per_page].to_i,
        :page => "1",
        :order_by => "did",
        :order_desc => 0,
    }
    @options = ((params[:clear] || !session_quickforwarddids_stats) ? default : session_quickforwarddids_stats)
    default.each { |key, value| @options[key] = params[key] if params[key] }

    @options[:order_by] = 'did' unless %w[did number description].include?(@options[:order_by].to_s.strip)

    @options[:order_by_full] = @options[:order_by] + (@options[:order_desc].to_i == 1 ? " DESC" : " ASC")

    @qfd_dialplan = Dialplan.where("dptype = 'quickforwarddids'").order("name ASC").first

    @dids = Did.get_quickforwarddids(current_user, @options)
  end

  def quickforwarddid_edit
    params_id = params[:id]
    @page_title = _('Quick_Forwards')
    @page_icon = 'edit.png'

    @qfdid = Quickforwarddid.where(did_id: params_id, user_id: current_user.id
    ).first || current_user.quickforwarddids.build(did_id: params_id)

    @did = @qfdid.did
    redirect_to(action: :index) if @did.blank?
  end

  def quickforwarddid_update
    params_id = params[:id]
    if params[:number].length == 0
      flash[:notice] = _('Enter_number')
      redirect_to(action: :quickforwarddid_edit, id: params[:did_id]) && (return false)
    end

    if params_id
      qfdid = Quickforwarddid.where(id: params_id).first
      unless qfdid
        flash[:notice] = _('Quickforwarddid_was_not_found')
        redirect_to(action: :index) && (return false)
      end
    else
      qfdid = Quickforwarddid.new
    end

    Quickforwarddid.quickforwarddid_update(qfdid, params, current_user)

    add_action_second(session[:user_id], 'quickforwarddid_edit', qfdid.did_id, qfdid.id)
    redirect_to action: :quickforwarddids
  end

  def quickforwarddid_destroy
    params_id = params[:id]
    quickforward_did = Quickforwarddid.where(:id => params_id).first
    unless quickforward_did
      flash[:notice]=_('Quickforwarddid_was_not_found')
      redirect_to :action => :index and return false
    end
    quickforward_did.destroy
    add_action(session[:user_id], 'quickforwarddid_deletedt', params_id)
    flash[:status] = _('Number_deleted')
    redirect_to :action => 'quickforwarddids'
  end

  def bulk_management
    @bulk_params = {
      :did_start => '',
      :did_end => '',
      :did_action => 0,
      :did_user => '',
      :did_user_id => -2,
      :did_device => 0
    }

    @page_title = _('Bulk_management')
    @page_icon = "edit.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/DID_Management#DID_bulk_management"

    # @from=params[:from] if params[:from]
    # @till=params[:till] if params[:till]

    unless reseller?
      @providers = Provider.where(['hidden=?', 0]).order("name ASC")
      sql = "SELECT count(devices.id)  FROM devices
              left join users on (devices.user_id = users.id)
              where devices.istrunk = 1 and users.owner_id = '#{accountant? ? 0 : session[:user_id]}'"

      @trunk = Device.count_by_sql(sql)
      @dps_created = (not Dialplan.where("id != 1").order("name ASC").empty?)
    end

    @devices = []

    !params[:did_action].blank? and (1..4).include?(params[:did_action].to_i) ? @did_action = params[:did_action].to_i : @did_action = 1
    @did_action = 1 if @trunk.to_i == 0 and @did_action == 4
  end

  def confirm_did_action
    @bulk_params[:did_start] = params[:did_start] if params[:did_start]
    @bulk_params[:did_end] = params[:did_end] if params[:did_end]
    @bulk_params[:did_action] = params[:did_action].to_i if params[:did_action]
    @bulk_params[:did_user] = params[:s_user]
    @bulk_params[:did_user_id] = params[:s_user_id]
    @bulk_params[:did_device] = params[:device]

    error = false

    params[:did_action] = 0 if reseller? and ![1, 3, 5].include?(params[:did_action].to_i)
    opts = {:from => params[:did_start], :till => params[:did_end]}
    if opts[:from].blank? or opts[:till].blank?
      flash[:notice] = _('DIDs_were_not_selected') + '<br/>' + '* ' + _('Enter_DID_interval')
      render :bulk_management
      error = true
    end

    if opts[:from].to_i > opts[:till].to_i && !error
      flash[:notice] = _('DIDs_were_not_selected') + '<br/>' + '* ' + _('Bad_interval_start_and_end')
      render :bulk_management
      error = true
    end

    opts[:user] = params[:s_user_id].to_i if params[:s_user_id] and !params[:s_user_id].strip.blank?
    opts[:device] = params[:s_device].to_i if params[:s_device] and !params[:s_device].strip.blank?
    opts[:active] = params[:active].to_i
    case params[:did_action].to_i
      when 1 then
        opts[:action] = :dids_interval_edit
      when 2 then
        opts[:action] = :dids_interval_delete
      when 3 then
        opts[:action] = :dids_interval_rates
      when 4 then
        opts[:action] = :dids_interval_trunk
      when 5 then
        opts[:action] = :dids_interval_add_to_user
      when 6 then
        opts[:action] = :dids_interval_assign_dialplan
      else
        flash[:notice] =_('DIDs_were_not_selected') + '<br/>' + '* ' +  _("Action_was_not_correct")
      if !error
        render :bulk_management
        error = true
      end
    end
    if !error
      redirect_to opts
    end
  end

  def dids_interval_add_to_user
    @page_title = _('Dids_interval_add_to_user')
    @page_icon = "edit.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/DID_Management"

    @devices = []
  end

  def add_to_user
    @from = params[:from].to_s
    @till = params[:till].to_s
    @opts = {:from => @from, :till => @till}
    var = [@from, @till]
    cond = ["dids.did BETWEEN ? AND ?"]
    num = 0
    owner_id = current_user.id

    # Accountants should use their owner id
    if accountant?
      owner_id = current_user.owner_id
    end

    if reseller?
      cond << 'reseller_id = ?'
      var << owner_id
    end

    device = params[:device].to_s.strip

    if not (device.blank? or device.downcase == 'all')
      @device = current_user.load_users_devices({first: true, conditions: ["devices.id = #{device}"]})
      if @device
        cond << "dids.device_id = ?"
        var << @device.id
        @opts[:device] = @device.id
      else
        flash[:notice] = _("Device_not_found")
        redirect_to({:action => 'dids_interval_add_to_user'}.merge(@opts)) and return false
      end
    end

    user = params[:user].to_s.strip

    unless user.blank?
      @user = User.where({:id => user.strip}).first
      if @user and @user.owner_id == correct_owner_id
        cond << "dids.user_id = ?"
        var << @user.id
        @opts[:user] = @user.id
      else
        dont_be_so_smart
        (redirect_to :root) && (return false)
      end
    end

    s_user_id = params[:s_user_id]
    @s_user = User.where(["users.id = ?", params[:s_user_id]]).first
    if @s_user
      s_device = params[:s_device].to_s.strip
      if (s_device.present? && s_device.downcase != 'none')
        @s_device = current_user.load_users_devices({first: true, conditions: ["devices.id = #{s_device}"]})
        unless @s_device
          flash[:notice] = _("Device_not_found")
          redirect_to({:action => 'dids_interval_add_to_user'}.merge(@opts)) and return false
        end
      end

      if (user.present? && user != s_user_id)
        flash[:notice] =  _('DIDs_were_not_selected') + '<br/>' + '* ' + _('No_DID_found_Please_check_interval')
        redirect_to({:action => 'dids_interval_add_to_user'}.merge(@opts)) and return false
      elsif (user.blank?)
        all_num = ActiveRecord::Base.connection.select_value("select COUNT(dids.id) from dids left join quickforwards_rules on ( did REGEXP(rule_regexp)) where  quickforwards_rules.id is null AND #{ActiveRecord::Base.send(:sanitize_sql_array,[cond.join(' AND '), *var])} ;")
        cond << "((dids.status = 'free' OR dids.user_id = #{s_user_id.to_i}) AND (dids.reseller_id = #{owner_id.to_i}))"
      end
      num = ActiveRecord::Base.connection.select_value("select COUNT(dids.id) from dids left join quickforwards_rules on ( did REGEXP(rule_regexp)) where  quickforwards_rules.id is null AND #{ActiveRecord::Base.send(:sanitize_sql_array,[cond.join(' AND '), *var])} ;")
      bad_num = ActiveRecord::Base.connection.select_value("select COUNT(dids.id) from dids left join quickforwards_rules on ( did REGEXP(rule_regexp)) where  quickforwards_rules.id is NOT null AND #{ActiveRecord::Base.send(:sanitize_sql_array,[cond.join(' AND '), *var])} ;")
      if @s_device
        ActiveRecord::Base.connection.execute("UPDATE dids, ( select dids.id from dids left join quickforwards_rules on ( did REGEXP(rule_regexp)) where  quickforwards_rules.id is null) as v SET dids.user_id = #{@s_user.id}, device_id = #{@s_device.id}, status = 'active' where dids.id = v.id AND #{ ActiveRecord::Base.send(:sanitize_sql_array,[cond.join(' AND '), *var])} ;")
      else
        if @s_user.usertype == 'reseller'
          ActiveRecord::Base.connection.execute("UPDATE dids, ( select dids.id from dids left join quickforwards_rules on ( did REGEXP(rule_regexp)) where  quickforwards_rules.id is null) as v SET reseller_id = #{@s_user.id}, dids.user_id = 0, device_id = 0, status = 'free' where dids.id = v.id AND #{ ActiveRecord::Base.send(:sanitize_sql_array,[cond.join(' AND '), *var])} ;")
        else
          ActiveRecord::Base.connection.execute("UPDATE dids, ( select dids.id from dids left join quickforwards_rules on ( did REGEXP(rule_regexp)) where  quickforwards_rules.id is null) as v SET dids.user_id = #{@s_user.id}, device_id = 0, status = 'reserved' where dids.id = v.id AND #{ ActiveRecord::Base.send(:sanitize_sql_array,[cond.join(' AND '), *var])} ;")
        end

      end
      flash[:notice] = _('DIDs_were_not_selected') + '<br/>' + '* ' + _('No_DID_found_Please_check_interval') if num.to_i == 0
      flash[:notice] = [bad_num.to_s, _('DIDs_were_not_updated')].join(" ") if bad_num.to_i > 0
      flash[:notice] = [(all_num.to_i - num.to_i).to_s, _('DID_were_not_rezerved')].join(" ") + '<br/>' + '* ' + _('DID_already_assigned_user_dial') if all_num.to_i > num.to_i
      flash[:status] = [num.to_s, _('DIDs_were_updated')].join(" ") if num.to_i > 0
      redirect_to({:action => 'list'}) and return false
    else
      flash[:notice] = _('User_Was_Not_Found')
    end
    redirect_to({:action => 'dids_interval_add_to_user'}.merge(@opts))
  end

  # @dids, @from, @till, (@user, @device) in before filter
  def dids_interval_add_to_trunk
    @page_title = _('Dids_interval_add_to_Trunk')
    @page_icon = "trunk.png"
    sql = "SELECT devices.* FROM devices
              left join users on (devices.user_id = users.id)
              where devices.istrunk = 1 and users.owner_id = '#{accountant? ? 0 : session[:user_id]}'"

    @available_trunks = Device.find_by_sql(sql)
    if  @available_trunks.size.to_i == 0
      flash[:notice] = _('No_available_trunks')
      redirect_to :controller => "dids", :action => "list"
    end
  end

  # @dids, @from, @till, (@user, @device) in before filter
  def dids_interval_trunk
    @page_title = _('Dids_interval_add_to_Trunk')
    @page_icon = "trunk.png"

    sql = "SELECT count(devices.id)  FROM devices
              left join users on (devices.user_id = users.id)
              where devices.istrunk = 1 and users.owner_id = '#{accountant? ? 0 : session[:user_id]}'"

    @available_trunks = Device.count_by_sql(sql)
    if  @available_trunks.to_i == 0
      flash[:notice] = _('No_available_trunks')
      redirect_to :controller => "dids", :action => "list"
    end
    @free_users = User.where("hidden = 0")
  end

  # @dids, @from, @till, (@user, @device) in before filter
  def dids_interval_edit
    @page_title =  _('Dids_interval_update')
    @page_icon = "edit.png"

    @providers = Provider.where("hidden = 0 AND user_id = #{correct_owner_id}").order("name ASC")

    @help_link = "http://wiki.kolmisoft.com/index.php/DID_Management"
  end

  # @dids, @from, @till, (@user, @device) in before filter
  def dids_interval_rates
    @page_title = _('Dids_interval_rates')
    @page_icon = "edit.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/DID_Management"

    @dids.each do |did|
      did.did_prov_rates
      did.did_incoming_rates
      did.did_owner_rates
    end
  end

  def edit_rate
    params_user_id = params[:user].to_i

    if params[:till]

      if params[:user]
        if reseller?
          add_condition = "and user_id = #{params_user_id}"
        else
          add_condition = "and (reseller_id = #{params_user_id} or user_id = #{params_user_id})"
        end
      else
        add_condition = ''
      end

      device_id = params[:device].to_s.strip
      unless device_id.blank?
        add_condition << " AND device_id = #{device_id} "
      end

      if reseller?
        @dids = Did.where(["did >= ? AND did <= ? AND dids.reseller_id = ? #{add_condition}", params[:from], params[:till], current_user.id])
      else
        @dids = Did.where(["did >= ? AND did <= ? #{add_condition}", params[:from], params[:till]])
      end

      @dids.each do |did|
       # Checks if did has his own rates in didrates table, if not he creates them
        did.check_did_rates
        if params[:provider]
          did.did_prov_rates.each do |rate|
            update_rate(rate.id, params[:rate], params[:con_fee], params[:inc], params[:min_time])
          end
        end

        if params[:incoming]
          did.did_incoming_rates.each do |rate|
            update_rate(rate.id, params[:rate], params[:con_fee], params[:inc], params[:min_time])
          end
        end

        if params[:owner]
          did.did_owner_rates.each do |rate|
            update_rate(rate.id, params[:rate], params[:con_fee], params[:inc], params[:min_time])
          end
        end

        if params[:interval]
          if params[:update_incom_rate]
            did.did_incoming_rates.each do |rate|
              update_rate(rate.id, params[:irate], params[:icon_fee], params[:iinc], params[:imin_time])
            end
          end

          if !reseller?
            if params[:update_prov_rate]
              did.did_prov_rates.each do |rate|
                update_rate(rate.id, params[:prate], params[:pcon_fee], params[:pinc], params[:pmin_time])
              end
            end

            if params[:update_ownr_rate]
              did.did_owner_rates.each do |rate|
                update_rate(rate.id, params[:orate], params[:ocon_fee], params[:oinc], params[:omin_time])
              end
            end
          end
        end
        flash[:status] = _('Did_interval_rate_edited')
      end

      redirect_to :action => :list and return false

    else
      update_rate(params[:id], params[:rate], params[:con_fee], params[:inc], params[:min_time])

      redirect_back_or_default("/dids/list")
    end
  end

  def update_rate(id, rate, fee, increments, min_time)
    didrates_conditions = {:readonly => false, :select => "didrates.*"}
    if current_user.usertype == 'reseller'
      didrates_conditions[:conditions] = ["didrates.id = ? AND dids.reseller_id = ?", id, current_user.id]
      didrates_conditions[:joins] = "LEFT JOIN dids ON (didrates.did_id = dids.id)"
    else
      didrates_conditions[:conditions] = ["didrates.id = ?", id]
    end

    dr = Didrate.select(didrates_conditions[:select]).
            joins(didrates_conditions[:joins].to_s).
            where(didrates_conditions[:conditions]).readonly(false).first
    if dr
      dr.update_attributes({rate: rate,
                            connection_fee: fee,
                            increment_s: increments,
                            min_time: min_time})
      add_action_second(session[:user_id], 'did_rate_edited', dr.did_id, dr.id)
      flash[:status] = _('Did_rate_edited')
    else
      flash[:notice] = _('Rate_was_not_found')
    end
  end

  # @dids, @from, @till, (@user, @device) in before filter
  def dids_interval_delete
    @page_title = _('Dids_interval_delete')
    @page_icon = "edit.png"
    @providers = Provider.where(['hidden=?', 0]).order("name ASC")
    @help_link = "http://wiki.kolmisoft.com/index.php/DID_Management"
  end

  # @dids, @from, @till, (@user, @device) in before filter
  def dids_interval_assign_dialplan
    @page_title = _('Dids_interval_assign_to_dialplan')
    @page_icon = "edit.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/DID_Management"

    user_id = accountant? ? 0 : current_user.id
    @ccdps = Dialplan.where(:dptype => 'callingcard', :user_id => user_id).order("name ASC").all
    @abpdps = Dialplan.where(:dptype => 'authbypin', :user_id => user_id).order("name ASC").all
    @cbdps = Dialplan.where("dptype = 'callback' AND data1 NOT IN ('#{@dids.map { |item| item.id }.join("','")}') AND user_id = #{user_id}").order("name ASC").all
    @qfddps = Dialplan.where("id != 1 AND dptype = 'quickforwarddids' AND user_id = #{user_id}").order("name ASC").all
    @pbxfdps = Dialplan.where(:dptype => 'pbxfunction', :user_id => user_id).order("name ASC").all
    @ivrs = Dialplan.where(:dptype => 'ivr', :user_id => user_id).order("name ASC").all
    @queues = Dialplan.where(:dptype => 'queue', :user_id => user_id).order("name ASC").all
    @vm_extension = Confline.get_value("VM_Retrieve_Extension", 0)

  end

  # @dids, @from, @till, (@user, @device) in before filter
  def delete
    options = {
      from: params[:from],
      till: params[:till],
      active: params[:active]
    }
    @dids = find_dids_on_condition(options)

    status = params[:status].to_s.strip
    if status == 'provider'
      params[:did] = nil
      all_dids = find_dids_on_condition(@opts, 'count')

      error_did = Did.new

      @dids.each do |did|
        update_did(did, "free", 0)
        update_did(did, "terminated", 0)
        did.didrates.each { |dr| dr.destroy }
        add_action(session[:user_id], 'did_deleted', did.id)
        did.destroy
      end

      dids_size = @dids.size.to_i

      if (dids_size == all_dids) and (all_dids > 0)
        flash[:status] = _('dids_deleted_successfully')
      else
        if (dids_size != 0)
          flash[:status] = _('n_out_of_m_dids_deleted', dids_size, all_dids)
        end
        error_did.errors.add(:dids_assigned_to_prov, _('dids_dont_belong_to_provider'))
      end

      if error_did.errors.size > 0
        if dids_size == 0
          flash_errors_for(_('n_dids_were_not_deleted', ''), error_did)
          redirect_to({action: 'dids_interval_delete'}.merge(@opts)) and return false
        else
          flash_errors_for(_('n_dids_were_not_deleted', (all_dids - dids_size).to_s), error_did)
        end
      end
    end

    if status != 'provider'
      status = [nil, 'free', 'terminated', nil, 'closed'][params[:dids_action].to_i]
      @dids.each do |did|
        if did.device_id.to_i != 0 and status == 'closed'
          update_did(did, status, 0)
          add_action(session[:user_id], 'did_edited', did.id)
        end
        if status != 'closed'
          update_did(did, status, 0)
          add_action(session[:user_id], 'did_edited', did.id)
        end
      end
    end

    if params[:id]
      redirect_to action: 'edit', id: params[:id]
    else
      dids_interval_delete
      @deleted = true
      render 'dids_interval_delete'
    end
  end

  # FunctionsController.integrity_recheck

  def personal_dids
    @page_title = _('DIDs')
    @page_icon = 'did.png'
    params_page = params[:page]
    session_items_per_page = session[:items_per_page]
    user = User.where(id: session[:user_id].to_i).first

    if !user? || user.blank?
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    user_id = user.id
    params_page ? @page = params_page.to_i : @page = 1
    @total_pages = (Did.where(["user_id = ?", user_id]).size/session_items_per_page.to_d).ceil
    @dids = Did.where(user_id: user_id).offset(session_items_per_page*(@page-1)).limit(session_items_per_page).all
    @allow_user_assign_did_functionality = allow_user_assign_did_functionality
  end

  def did_edit
    @did = Did.includes(:user).where(["dids.id = ? AND dids.user_id = ?", params[:id], current_user.id]).first
    if @did
      if did_is_closed?(@did)
        flash[:notice] =_('DID_cant_be_edited')
        (redirect_to action: 'personal_dids') && (return false)
      else
        @page_title = _('DID_edit') + ': ' + @did.did
        @page_icon = 'edit.png'
        @help_link = 'http://wiki.kolmisoft.com/index.php/DID_Management#Settings'
        @free_devices = @did.user.devices.where(istrunk: 0)
        @did_route_to_server = !@did.external_server.to_s.blank?
      end
    else
      flash[:notice] =_('DID_was_not_found')
      (redirect_to :root) && (return false)
    end
  end

  def did_update
    did = Did.where(["dids.id = ?", params[:id]]).first
    did_id = did.id
    status = params[:status].to_s.strip
    ext_server = params[:external_sip].to_s.strip
    route_type_dev = params[:route_type].to_s.strip == 'dev'
    session[:external_server_must_be_present_err] = ''

    if route_type_dev
      update_did(did, status, 1)
    else
      if ext_server.blank?
        session[:external_server_must_be_present_err] = 1
        did.errors.add(:did, _('external_server_must_be_present'))
        flash_errors_for(_('Did_was_not_updated'), did)
        redirect_to action: 'did_edit', id: did_id and return false
      end

      did.assign_server(params[:external_sip].to_s.strip)
    end

    flash[:status] = _('DID_assigned')
    add_action(session[:user_id], 'did_edited', did_id)
    redirect_to action: 'personal_dids'
  end

  def summary
    @page_title = _('DIDs_report')
    @page_icon = 'did.png'
    @show_currency_selector = 1
    @help_link = 'http://wiki.kolmisoft.com/index.php/DIDs_Report'

    change_date
    did_summary_options

    @data = EsDidsSummary.get_data({
      from: es_limit_search_by_days,
      till: es_session_till,
      options: @options,
      current_user: current_user,
      show_currency: session[:show_currency],
      can_see_finances: can_see_finances?}
   )

  end

  def did_summary_options
    if accountant? && session[:acc_manage_dids_opt_1].to_i == 0
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      (redirect_to :root) && (return false)
    end

    dids_summary_list_options = session[:dids_summary_list_options]
    params_user_id = params[:s_user_id]
    params_device = params[:s_device]
    params_days = params[:s_days]
    params_provider_id = params[:provider_id]
    params_period = params[:period]
    params_dids_grouping = params[:dids_grouping].to_i
    params_did_search_till = params[:did_search_till]
    params_did_search_from = params[:did_search_from]
    params_did_number = params[:did_number]
    params_d_search_to_i = params[:d_search].to_i
    params_clean = params[:clean]
    change_date_to_present if params_clean

    @options = ((params_clean || !dids_summary_list_options) ? {} : dids_summary_list_options)

    @options[:dids_grouping] = params_dids_grouping == 0 ? (@options[:dids_grouping].to_i == 0 ? 1 : @options[:dids_grouping].to_i) :  params_dids_grouping


    @options[:d_search] = params_d_search_to_i == 0 ? (@options[:d_search].to_i == 0 ? 1 : @options[:d_search].to_i) :  params_d_search_to_i
    (params_provider_id && params_provider_id.to_s != '') ? @options[:provider] = params_provider_id : @options[:provider] = 'any'
    (params_did_number && params_did_number.to_s != '') ? @options[:did] = params_did_number : @options[:did] = ''
    @options[:s_user] = params[:s_user] || ''
    @options[:user_id] = (params_user_id && params_user_id.to_s != '') ?  params_user_id.gsub('-2', 'any') : 'any'
    (params_device && params_device.to_s != '') ? @options[:device_id] = params_device : @options[:device_id] = "all"
    (params_days && params_days.to_s != '') ? @options[:sdays] = params_days : @options[:sdays] = 'all'
    (params_period && params_period.to_s != '') ? @options[:period] = params_period : @options[:period] = '-1'
    (params_did_search_from && params_did_search_from.to_s != '') ? @options[:did_search_from] = params_did_search_from : @options[:did_search_from] = ''
    (params_did_search_till && params_did_search_till.to_s != '') ? @options[:did_search_till] = params_did_search_till : @options[:did_search_till] = ''

    @search_user = @options[:s_user]
    @user_id = @options[:user_id]
    @providers = Provider.all.order('name ASC')

    @nice_days =  @options[:sdays].to_s == 'all' ? _('All') :   (@options[:sdays].to_s == 'wd' ?  _('Work_days') :   _('Free_days')    )
    did_rate = Didrate.where({id: @options[:period]}).first
    @nice_period = did_rate.start_time.strftime("%H:%M:%S").to_s + '-' + did_rate.end_time.strftime("%H:%M:%S").to_s if did_rate

    if @options[:user_id] == 'any'
      @devices =   []
    else
      @user = User.find(@options[:user_id])
      if @user && (%w[admin accountant].include?(session[:usertype]) || @user.owner_id = corrected_user_id)
        @devices = @user.devices(:conditions => "device_type != 'FAX'").select('devices.*').joins('JOIN dids ON (dids.device_id = devices.id)').group('devices.id').all
      else
        @devices = []
      end
    end

    @periods = Didrate.find_hours_for_select({day: @options[:sdays], did: @options[:did], d_search: @options[:d_search].to_i == 1 ? 'true' : 'false', did_from: @options[:did_search_from], did_till: @options[:did_search_till]})
    session[:dids_summary_list_options] = @options
  end

  def bad_dids_from_csv
    @page_title = _('Bad_rows_from_CSV_file')
    if ActiveRecord::Base.connection.tables.include?(session[:tname].to_s)
      @rows = ActiveRecord::Base.connection.select_all("SELECT * FROM #{session[:tname].to_s} WHERE f_error > 0")
    end

    render(layout: 'layouts/mor_min')
  end

  def dids_imported
    @page_title = _('DIDs')
    @page_icon = "did.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Data_import#Importing_DIDs"
    sql = "SELECT * FROM #{session[:tname].to_s}"
    @file = ActiveRecord::Base.connection.select_all(sql).each(&:symbolize_keys!)
    @total_dids = @file.size
    @imported_dids = @file.select{|did| did[:f_error] == 0}.size
  end

  def allow_user_assign_did_functionality
    return (
      (Confline.get_value('Allow_User_assign_DID_to_Device', correct_owner_id).to_i == 1)
      )
  end

  private

  def access_denied_user_dids
    access_denied
  end

  def assign_did_to_auth_by_pin_dp(did)
    Dialplan.new_pin_auth_dp
    dp = Dialplan.where(dptype: 'authbypin').first
    dp_ext = 'dp' + dp.id.to_s
    did.dialplan = dp
    did.status = "active"
    did.save
    # Extline.mcreate(Default_Context, 1, "Goto", dp_ext+"|1", did.did, 0)
  end

  def check_user_for_dids
    if current_user.usertype == 'user'
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to controller: 'callc', action: 'login' and return false
    end
  end

  def set_search_param(param)
    session[:did_search_options] ||= {}
    key = param.to_s.gsub(/search/, 's')

    result = if params.has_key?(key)
               params.fetch(key)
             elsif session[:did_search_options].has_key?(key)
               session[:did_search_options].fetch(key)
             else
               ''
             end
    session[:did_search_options][key] = result.to_s
    instance_variable_set "@#{param}", result.to_s
  end

  def check_device_presence
    if params[:status] && params[:status] == 'active' && params[:device_id]
      device = Device.where(id: params[:device_id]).first

      unless device
        flash[:notice] = _('Device_not_found')
        redirect_to action: 'list'
      end
    end
  end

  def find_provider
    @provider = Provider.where(:id => params[:provider]).first
    unless @provider
      flash[:notice] = _('Provider_was_not_found')
      redirect_to action: 'new'
    end
  end

  def find_dids
    @from = params[:from].to_s
    @till = params[:till].to_s
    active = params[:active].to_i

    @opts = {from: @from, till: @till, active: active.to_i}

    var = [@from, @till]
    cond = ["dids.did BETWEEN ? AND ?"]
    unless params[:device].to_s.strip.blank?
      @device = Device.where(id: params[:device].to_s.strip).first
      if @device
        cond << "dids.device_id = ?"
        var  << params[:device].strip
        @opts[:device] = @device.id
      end
    end
    if params[:did] and params[:did][:provider_id] and !params[:did][:provider_id].strip.blank?
      @provider = Provider.where(:id => params[:did][:provider_id]).first
      var << params[:did][:provider_id].to_i
      cond << "dids.provider_id = ?"
    end
    if reseller?
      cond << "dids.reseller_id = ?"
      var << current_user.id
    end
    if params[:user] and !params[:user].strip.blank?
      @user = User.where(:id => params[:user].strip).first
      if @user
        # find dids that assigned to user or reseller
        if @user.usertype == 'reseller'
          cond << "dids.reseller_id = ?"
        else
          cond << "dids.user_id = ?"
        end
        var << params[:user].strip
        @opts[:user] = @user.id
      end
    end
    if active.to_i == 1
      cond << 'dids.status = ?'; var << 'active'
    end

    @dids = Did.where([cond.join(" AND "), *var]).all
    flash[:notice] =  _('DIDs_were_not_selected') + '<br/>' + '* ' + _('No_DID_found_Please_check_interval') if @dids.size == 0
  end

  # More dynamic than the previous method
  def find_dids_on_condition(options, select = 'all', *conditions)
    @opts = options
    @from = @opts[:from].to_s
    @till = @opts[:till].to_s

    cond = ["dids.did BETWEEN '#{@from}' AND '#{@till}'"]
    unless params[:device].to_s.strip.blank?
      cond << "dids.device_id = #{params[:device].to_i}"
    end
    update_action = params[:action] == 'update'
    if !update_action && params[:did] && params[:did][:provider_id] && !params[:did][:provider_id].strip.blank?
      cond << "dids.provider_id = #{params[:did][:provider_id]}"
    end
    if reseller?
      cond << "dids.reseller_id = #{current_user.id}"
    end
    if params[:user] and !params[:user].strip.blank?
      @user = User.where(:id => params[:user].strip).first
      if @user
        # find dids that assigned to user or reseller
        if @user.usertype == 'reseller'
          cond << "dids.reseller_id = #{params[:user].to_i}"
        else
          cond << "dids.user_id = #{params[:user].to_i}"
        end
      end
    end
    cond = "(#{cond.join(' AND ')}) "
    unless conditions.blank?
      cond << "AND #{conditions.join(' AND ')}"
    end

    if select.eql? 'all'
      did_query = Did.where(cond).all
    elsif select.eql? 'count'
      did_query = Did.where(cond).count
    end
    return did_query
  end

  def check_dids_creation
    if !allow_manage_dids? and !['admin', 'accountant'].include?(current_user.usertype)
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    user_is_reseller = current_user.is_reseller?
    own_providers = current_user.own_providers.to_i
    if user_is_reseller && params[:provider] && own_providers == 1 && !current_user.providers.where(["providers.id = ? ", params[:provider]]).first && params[:provider] != Confline.get_value("DID_default_provider_to_resellers").to_i
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    if user_is_reseller && params[:provider] && own_providers == 0 && params[:provider].to_i != Confline.get_value("DID_default_provider_to_resellers").to_i
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

  end

  def check_did_params
    params[:user_id] = params[:s_user_id] if params[:s_user_id].present?

    if !['reserved', "terminated", "free", "closed", "active"].include?(params[:status]) and (!params[:did] or !params[:status])
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
    usertype = current_user.usertype
    own_providers = current_user.own_providers.to_i
    user_id = current_user.id
    if params[:status] == 'reserved'
      user_current = User.where(:id => params[:user_id]).first
      if usertype == 'reseller' && (!params[:user_id] || !user_current || user_current.owner_id != correct_owner_id)
        dont_be_so_smart
        (redirect_to :root) && (return false)
      end
    end
    if params[:status] == "active"
      device = Device.where(:id => params[:device_id]).first
      if usertype == 'reseller' && (!device or !Device.joins("LEFT JOIN users ON (devices.user_id = users.id)").where("devices.id = #{device.id} and (users.owner_id = #{user_id} or users.id = #{user_id})").first)
        dont_be_so_smart
        (redirect_to :root) && (return false)
      end
    end
    if params[:did] && params[:did][:provider_id]
      if usertype == 'reseller' && params[:did][:provider_id] && own_providers == 1 && !current_user.providers.where(["providers.id = ?", params[:did][:provider_id]]).first && params[:did][:provider_id] != Confline.get_value("DID_default_provider_to_resellers").to_i
        dont_be_so_smart
        (redirect_to :root) && (return false)
      end

      if usertype == 'reseller' && params[:did][:provider_id] && own_providers == 0 && params[:did][:provider_id].to_i != Confline.get_value("DID_default_provider_to_resellers").to_i
        dont_be_so_smart
        (redirect_to :root) && (return false)
      end
    end
  end

  # Transaltes order_by param to database fields for summary report.
  def summary_order_by(params, options)
    options_order = options[:order_by]
    order_by = case params[:order_by].to_s
               when 'nice_user' then
                 'nice_user'
               when 'did' then
                 'did'
               when 'provider' then
                 'providers.name'
               when 'comment' then
                 'dids.comment'
               when "calls" then
                 'total_calls'
               when 'billed_duration' then
                 'dids_billsec'
               when 'owner_price' then
                 'own_price'
               when 'provider_price' then
                 'd_prov_price'
               else
                 options_order ? options_order : ''
               end

      without = order_by
      unless order_by.blank?
        order_by += options[:order_desc].to_i == 0 ? ' ASC' : ' DESC'
      end
    return without, order_by
  end

  def default_edit_details
    @details = {}
    @details[:owner_user] = (params[:s_user].present? && params[:s_user]) ||
                            (@did.try(:user).present? && nice_user(@did.try(:user))) || ''
    @details[:owner_user_id] = (params[:s_user_id ].present? && params[:s_user_id]) ||
                               (@did.try(:user).present? && @did.try(:user).try(:id)) || -2
  end

  def private_access_denied
    dont_be_so_smart
    redirect_to(:root) && (return false)
  end

  def did_is_closed?(did)
    did.status == 'closed'
  end
end
