# -*- encoding : utf-8 -*-
# Mass SMS Addon.
class SmsautodialerController < ApplicationController

  layout 'callc'
  before_filter :check_post_method, only: [:redial_all_failed_calls, :campaign_update, :campaign_create,
    :campaign_destroy, :action_destroy, :action_add, :action_update, :number_destroy]
  before_filter :check_localization
  before_filter :authorize
  before_filter :check_user_type, only: [:export_call_data_to_csv, :campaign_new, :campaign_destroy, :campaign_update,
    :redial_all_failed_calls, :action_add, :campaign_actions, :import_numbers_from_file, :campaign_edit,
    :campaign_change_status, :campaign_numbers, :delete_all_numbers]
  before_filter :find_campaign, only: [:export_call_data_to_csv, :campaign_destroy, :view_campaign_actions,
    :campaign_update, :redial_all_failed_calls, :action_add, :campaign_actions, :import_numbers_from_file,
    :campaign_edit, :campaign_change_status, :campaign_numbers, :delete_all_numbers]
  before_filter :find_campaign_action, only: [:play_rec, :action_update, :action_edit, :action_destroy]
  before_filter :find_adnumber, only: [:reactivate_number, :number_destroy]
  before_filter :check_params_campaign, only: [:campaign_create, :campaign_update]
  before_filter :check_sms_addon

  def index
    user_campaigns
    redirect_to :action => :user_campaigns and return false
  end

  # --------- Admin campaigns -------------

  def campaigns
    (dont_be_so_smart and redirect_to :root) if (reseller? and current_user.reseller_right('sms_addon').to_i != 2)
    @page_title = _('SMS_Campaigns')
    @page_icon = 'phone.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/SMS_Addon_Mass_SMS'

    current_user_id = current_user.id
    session_campaigns_order = session[:campaigns_order]
    @campaigns = []

    @options = session_campaigns_order ? session_campaigns_order : {:order_by => 'username', :order_desc => 0, :page => 1}

    params[:order_by] ? @options[:order_by] = params[:order_by].to_s : (@options[:order_by] = "name" if !@options[:order_by])
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 0 if !@options[:order_desc])
    @options[:page] = params[:page].to_i if params[:page]

    session[:campaigns_order] = @options

    order_by = campaigns_order_by(@options)

    session_items_per_page = session[:items_per_page]
    @page = @options[:page].to_i
    total_campaigns = SmsCampaign.where(:owner_id => current_user_id).size
    @total_pages = (total_campaigns / session_items_per_page.to_d).ceil

    @page = @total_pages if @page > @total_pages
    @page = 1 if @page < 1
    offset = session_items_per_page * (@page-1)

    @options[:page] = @page

    @campaigns = SmsCampaign.select("sms_campaigns.*").
                                    joins('INNER JOIN users ON (users.id = sms_campaigns.user_id)').
                                    where(:owner_id => current_user_id).
                                    limit(@page * session_items_per_page).
                                    offset(offset).
                                    order(order_by)

  end


  def view_campaign_actions
    @page_title = _('Actions_for_campaign') + ": " + @campaign.name
    @page_icon = "actions.png"
    @actions = @campaign.sms_adactions
  end

  def campaigns_order_by(options)
    order_by_str = ''

    case options[:order_desc]
      when 0
        order_by_desc = ' ASC'
      when 1
        order_by_desc = ' DESC'
    end

    case options[:order_by]
      when 'username'
        order_by_str << 'username'
      when 'name'
        order_by_str << 'sms_campaigns.name'
      when 'type'
        order_by_str << 'sms_campaigns.campaign_type'
      when 'status'
        order_by_str << 'sms_campaigns.status'
      when 'start_time'
        order_by_str << 'sms_campaigns.start_time'
      when 'stop_time'
        order_by_str << 'sms_campaigns.stop_time'
    end

    order_by_str << order_by_desc if !order_by_str.blank?

    return order_by_str
  end

  # ------------ User campaigns -------------

  def user_campaigns
    if admin? or reseller?
      redirect_to :action => :campaigns and return false
    end

    @page_title = _('SMS_Campaigns')
    @page_icon = 'phone.png'

    params_page = params[:page]
    params_order_desc = params[:order_desc]
    params_order_by = params[:order_by]
    session_user_campaigns_order = session[:user_campaigns_order]
    items_per_page =  session[:items_per_page]
    current_user_id = current_user.id

    @options = session_user_campaigns_order ? session_user_campaigns_order : {:order_by => 'name', :order_desc => 0, :page => 1}

    @options[:order_by] = params_order_by.to_s if params_order_by
    @options[:order_desc] = params_order_desc.to_i if params_order_desc
    @options[:page] = params_page.to_i if params_page

    session[:user_campaigns_order] = @options

    order_by = campaigns_order_by(@options)

    @page = @options[:page].to_i
    total_campaigns = SmsCampaign.where(:user_id => current_user_id).size
    @total_pages = (total_campaigns / items_per_page.to_d).ceil

    @page = @total_pages if @page > @total_pages
    @page = 1 if @page < 1
    offset = items_per_page * (@page-1)

    @options[:page] = @page

    @campaigns = SmsCampaign.where(:user_id => current_user_id).limit(@page * items_per_page).offset(offset).order(order_by)
  end

  def campaign_new
    if admin? or reseller?
      redirect_to :action => :campaigns
    end

    @user = current_user
    current_user_type = current_user.usertype
    if current_user_type == 'user' or current_user_type == 'accountant'
      @devices = current_user.devices.where("device_type != 'FAX'")
    else
      @devices = Device.select("devices.id, devices.description, devices.extension, devices.device_type, devices.istrunk, devices.name, devices.ani, devices.username").joins("LEFT JOIN users ON (users.id = devices.user_id)").where(["device_type != 'FAX' AND owner_id = ? AND name NOT LIKE 'mor_server_%'", corrected_user_id]).order("extension")
    end

    if @devices.size == 0
      flash[:notice] = _('Please_create_device_for_sms_campaign')
      redirect_to :action => 'user_campaigns' and return false
    end

    @page_title = _('New_campaign')
    @page_icon = "add.png"

    @campaign = SmsCampaign.new

    @ctypes = ["simple"]

  end

  def campaign_create
    @campaign = SmsCampaign.create_by_user(current_user, params)
    if @campaign.save
      flash[:status] = _('Campaign_was_successfully_created')
      redirect_to :action => 'user_campaigns'
    else
      flash_errors_for(_('Campaign_was_not_created'), @campaign)
      redirect_to :action => 'campaign_new'
    end
  end


  def campaign_destroy
    @campaign.destroy
    flash[:status] = _('Campaign_deleted')
    redirect_to :action => 'user_campaigns'
  end


  def campaign_edit
    @page_title = _('Edit_campaign')
    @page_icon = "edit.png"
    @ctypes = ["simple"]

    @user = current_user
    current_user_type = current_user.usertype
    if current_user_type == 'user' or current_user_type == 'accountant'
      @devices = current_user.devices.where("device_type != 'FAX'")
    else
      @devices = Device.select("devices.id, devices.description, devices.extension, devices.device_type, devices.istrunk, devices.name, devices.ani, devices.username").joins("LEFT JOIN users ON (users.id = devices.user_id)").where(["device_type != 'FAX' AND owner_id = ? AND name NOT LIKE 'mor_server_%'", corrected_user_id]).order("extension")
    end
  end


  def campaign_update
    @campaign.update_by(params)
    if @campaign.save
      flash[:status] = _('Campaigns_details_was_successfully_changed')
      redirect_to :action => 'user_campaigns'
    else
      flash_errors_for(_('Campaigns_details_not_changed'), @campaign)
      redirect_to :action => 'campaign_edit', :id => @campaign.id
    end
  end

  def campaign_change_status
    notice, status_changed = @campaign.change_status
    if @campaign.save and status_changed
      flash[:status] = notice
    else
      flash_errors_for(_('Campaigns_details_not_changed'), @campaign)
      flash[:notice] =notice
      Action.add_action_hash(current_user, :target_type => 'campaign', :action => "failed_ad_campaign_activation", :target_id => @campaign.id, :data2 => notice)
    end
    redirect_to :action => 'user_campaigns'
  end

  # --------- Numbers ---------

  def campaign_numbers
    @page_title = _('Numbers_for_campaign') + ": " + @campaign.name
    @page_icon = "details.png"

    campaign_sms_adnumbers = @campaign.sms_adnumbers
    fpage, @total_pages, options = Application.pages_validator(session, params, campaign_sms_adnumbers.size.to_d)
    @page = options[:page]
    @numbers = campaign_sms_adnumbers.limit(session[:items_per_page]).offset(fpage)
  end

  def number_destroy
    sms_campaign_id = @number.sms_campaign_id
    @number.destroy
    flash[:status] = _('number_successfully_deleted')
    redirect_to :controller => :smsautodialer, :action => :campaign_numbers, :id => sms_campaign_id
  end


  def delete_all_numbers
    for num in @campaign.sms_adnumbers
      num.destroy
    end

    flash[:status] = _('All_numbers_deleted')
    redirect_to :action => 'campaign_numbers', :id => params[:id]
  end


  def import_numbers_from_file

    @page_title = _('Number_import_from_file')
    @page_icon = "excel.png"

    params_step = params[:step]
    params_file = params[:file]
    @step = 1
    @step = params_step.to_i if params_step

    campaign_id = @campaign.id
    if @step == 2
      if params_file
        @file = params_file
        if  @file.size > 0
          if !@file.respond_to?(:original_filename) or !@file.respond_to?(:read) or !@file.respond_to?(:rewind)
            flash[:notice] = _('Please_select_file')
            redirect_to :action => "import_numbers_from_file", :id => campaign_id, :step => "0" and return false
          end
          if get_file_ext(@file.original_filename, "csv") == false
            @file.original_filename
            flash[:notice] = _('Please_select_CSV_file')
            redirect_to :action => "import_numbers_from_file", :id => campaign_id, :step => "0" and return false
          end
          @file.rewind
          file = @file.read
          session[:file_size] = file.size

          tname = CsvImportDb.save_file(campaign_id, file, "/tmp/")
          session["atodialer_number_import_#{campaign_id}".to_sym] = tname
          colums ={}
          colums[:colums] = [{:name=>"f_number", :type=>"VARCHAR(50)", :default=>''},
                             {:name=>"f_error", :type=>"INT(4)", :default=>0},
                             {:name=>"nice_error", :type=>"INT(4)", :default=>0},
                             {:name=>"not_found_in_db", :type=>"INT(4)", :default=>0},
                             {:name=>"id", :type=>'INT(11)', :inscrement=>' NOT NULL auto_increment '}]
          begin
            CsvImportDb.load_csv_into_db(tname, ',', '.', '', "/tmp/", colums, false)

            @total_numbers, @imported_numbers = @campaign.insert_numbers_from_csv_file(tname)


            if @total_numbers.to_i == @imported_numbers.to_i
              flash[:status] = _('Numbers_imported')
            else
              flash[:status] = _('M_out_of_n_numbers_imported', @imported_numbers, @total_numbers)
            end

          rescue => exception
            MorLog.log_exception(exception, Time.now.to_i, params[:controller], params[:action])
            CsvImportDb.clean_after_import(tname, "/tmp/")
            flash[:notice] = _('MySQL_permission_problem_contact_Kolmisoft_to_solve_it')
            redirect_to :action => "import_numbers_from_file", :id => campaign_id, :step => "0" and return false
          end
        else
          flash[:notice] = _('Please_select_file')
          redirect_to :action => "import_numbers_from_file", :id => campaign_id, :step => "0" and return false
        end
      else
        flash[:notice] = _('Please_upload_file')
        redirect_to :action => "import_numbers_from_file", :id => campaign_id, :step => "0" and return false
      end
    end

  end

  def bad_numbers_from_csv
    @page_title = _('Bad_rows_from_CSV_file')
    params_id = params[:id].to_i
    if ActiveRecord::Base.connection.tables.include?(session["atodialer_number_import_#{params_id}".to_sym])
      @rows = ActiveRecord::Base.connection.select_all("SELECT * FROM #{session["atodialer_number_import_#{params_id}".to_sym]} WHERE f_error = 1")
    end

    render(:layout => "layouts/mor_min")
  end


  def reactivate_number
    @number.status = "new"
    @number.save
    flash[:status] = _('Number_reactivated') + ": " + @number.number
    redirect_to :action => 'campaign_numbers', :id => @number.sms_campaign_id

  end

  #-------------- Actions --------------

  def campaign_actions
    @page_title = _('Actions_for_campaign') + ": " + @campaign.name
    @page_icon = "actions.png"
    @actions = @campaign.sms_adactions
  end


  def action_add
    action_type = params[:action_type]
    campaign_id = @campaign.id
    action = SmsAdaction.new({:priority => @campaign.sms_adactions.size + 1, :sms_campaign_id => campaign_id, :action => action_type})
    if action.save
      flash[:status] = _('Action_added')
      redirect_to :action => 'campaign_actions', :id => campaign_id
    else
      flash[:notice] = _('Action_was_not_correct')
      redirect_to :action => 'campaign_actions', :id => campaign_id
    end

  end


  def action_destroy
    campaign_id = @action.sms_campaign_id
    @action.destroy_action
    flash[:status] = _('Action_deleted')
    redirect_to :action => 'campaign_actions', :id => campaign_id
  end


  def action_edit
    @page_title = _('Edit_action')
    @page_icon = "edit.png"
    @campaign = @action.sms_campaign
    @ivrs = current_user.ivrs if allow_manage_providers?
  end

  def action_update
    @action.update_action(params)
    @action.save
    redirect_to :action => 'campaign_actions', :id => @action.sms_campaign_id
  end


  def play_rec
    @filename2 = @action.file_name
    @page_title = ""
    @Adaction_Folder = Web_Dir + "/ad_sounds/"
    @title = confline("Admin_Browser_Title")
    render(:layout => "play_rec")
  end


  def redial_all_failed_calls
    if SmsAdnumber.where(status: 'executed', sms_campaign_id: @campaign.id).update_all(status: 'new', executed_time: nil)
      flash[:status] = _('All_calls_failed_redial_was_successful')
    else
      flash[:notice] = _('All_calls_failed_redial_was_not_successful')
    end
    if session[:usertype] == 'admin'
      redirect_to :action => :campaigns and return false
    else
      user_campaigns
      redirect_to :action => :user_campaigns and return false
    end
  end

  def campaign_statistics
    @page_title = _('Campaign_Stats')
    sms_campaign_params
    change_date
    @campaign_id =  @options[:campaign_id].to_i

    campaign_owner_id = ((@current_user.is_admin? || @current_user.is_accountant?) ? 0 : @current_user.id)
    @all_campaigns = SmsCampaign.where(user_id: campaign_owner_id)

    if @campaign_id != -1
      @campaing_stat = SmsCampaign.where(id: @campaign_id).first
      if @campaing_stat.present?
        @campaing_stat_name = @campaing_stat.name
        user_id = @campaing_stat.user_id

        @numbers = SmsAdnumber.where(sms_campaign_id: @campaign_id).count.to_i
        if @numbers > 0
          if Time.parse(session_from_datetime) > Time.parse(session_till_datetime)
            flash[:notice] = _('Date_from_greater_thant_date_till')
          else
            @dialed = @campaing_stat.executed_numbers_count.to_s
            @complete = @campaing_stat.completed_numbers_count

            user_timezone_offset = "(SELECT TIME_TO_SEC(TIMEDIFF('#{date_str_from_hash(@options[:date_from])}', "\
            "'#{session_from_datetime}'))/3600)"

            sql = "SELECT COUNT(sms_adnumbers.id) AS 'sms_messages', DATE_FORMAT(DATE_ADD(executed_time, "\
            "INTERVAL #{user_timezone_offset} HOUR), '%Y-%m-%d') AS 'day' FROM sms_adnumbers "\
            "WHERE status = 'completed' AND sms_campaign_id = "\
            "#{@campaign_id} AND executed_time BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}'"\
            " GROUP BY day"
            @res = ActiveRecord::Base.connection.select_all(sql)
            if @res.count > 0
              @calls_graph = ''
              @res.try(:each) { |day| @calls_graph << "#{day['day']};#{day['sms_messages']}\\n" }
              @calls_graph << '\\n'
            else
              flash[:notice] = _('No_SMS_in_selected_time_period_for_campaign') + @campaing_stat_name
            end
          end
        else
          flash[:notice] = _('No_numbers_in_campaign') + @campaing_stat_name
        end
      else
        flash[:notice] = _('Campaign_was_not_found')
        if admin? || reseller?
          redirect_to(action: :campaigns) && (return false)
        else
          redirect_to(action: :user_campaigns) && (return false)
        end
      end
    end
    session[:campaign_stats] = @options
  end



  def   export_call_data_to_csv

    @numbers = @campaign.sms_adnumbers

    sep, dec = current_user.csv_params

    csv_string = []

    for number in @numbers
      str = []
      executed_time = number.executed_time
      completed_time = number.completed_time
      str << number.number
      str << executed_time.to_s if !executed_time.blank?
      str << completed_time.to_s if !completed_time.blank?

      csv_string << str.join(sep) if str and str.size.to_i > 0
    end

    string = csv_string.join("\n")
    if params[:test].to_i == 1
      render :text => string
    else
      send_data(string, :type => 'text/csv; charset=utf-8; header=present', :filename => 'Campaign_call_data.csv')
    end

  end

  private

  def date_str_from_hash(hash)
    "#{hash[:year]}-#{hash[:month]}-#{hash[:day]} #{hash[:hour]}:#{hash[:minute]}:00"
  end

  def sms_campaign_params
    clear = params[:clear].to_i == 1
    campaign_id = params[:campaign_id] || -1
    campaign_id_present = campaign_id.to_i != -1
    dates_present = [:date_from, :date_till].any? { |key| params.key? key }
    search = dates_present || campaign_id_present
    @options = search ? params : session[:campaign_stats]
    @options[:campaign_id] = campaign_id if campaign_id_present

    # session[:date_from] = params[:date_from]
    # @options[:date_from] = session[:date_from] if !dates_present

    @options[:date_from] = session[:campaign_stats][:date_from] if !dates_present
    clear_smsautodialer_search if clear

    options_tmp = @options
    time_not_current = [[:date_from, '00:00'], [:date_till, '23:59']].any? do |key, hour|
      Time.parse(date_str_from_hash(options_tmp[key])).strftime('%Y-%m-%d %H:%M') != Time.current.strftime("%Y-%m-%d #{hour}")
    end if [:date_from, :date_till].all? { |key| options_tmp.try(:key?, key) }
    @options[:show_clear] = (time_not_current || campaign_id_present) && !clear
  end

  def clear_smsautodialer_search
    change_date_to_present
    @options[:campaign_id] = -1
    @options[:show_clear] = false
  end

  def check_user_type
    if admin? or reseller?
      dont_be_so_smart
      redirect_to :action => :campaigns
    end
  end

  def find_campaign
    params_id = params[:id]
    if admin? or reseller?
      @campaign = SmsCampaign.where(:id => params_id).first
    else
      @campaign = current_user.sms_campaigns.where(:id => params_id).first
    end

    unless @campaign
      flash[:notice] = _('Campaign_was_not_found')
      if admin? or reseller?
        redirect_to :action => :campaigns and return false
      else
        redirect_to :action => :user_campaigns and return false
      end
    end
  end

  def find_campaign_action
    @action = SmsAdaction.where(:id => params[:id]).includes(:sms_campaign).first
    unless @action
      flash[:notice] = _('Action_was_not_found')
      if admin?
        redirect_to :action => :campaigns and return false
      else
        redirect_to :action => :user_campaigns and return false
      end
    end

    access = check_user_id_with_session(@action.sms_campaign.user_id)
    return false if !access
  end

  def find_adnumber
    @number = SmsAdnumber.where(:id => params[:id]).includes(:sms_campaign).first
    unless @number
      flash[:notice] = _('Number_was_not_found')
      if admin?
        redirect_to :action => :campaigns and return false
      else
        user_campaigns
        redirect_to :action => :user_campaigns and return false
      end
    end
    access = check_user_id_with_session(@number.sms_campaign.user_id)
    return false if !access
  end

  def check_params_campaign
    if !params[:campaign]
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
  end

  def check_sms_addon
    authorization_fault = _('You_are_not_authorized_to_view_this_page')
    if !sms_active?
      flash[:notice] = authorization_fault
      (redirect_to :root) && (return false)
    end
    if reseller? and current_user.reseller_right('sms_addon').to_i != 2
      flash[:notice] = authorization_fault
      (redirect_to :root) && (return false)
    end
    current_user_owner = current_user.owner
    if current_user_owner.is_reseller? and current_user_owner.reseller_right('sms_addon').to_i != 2
      flash[:notice] = authorization_fault
      (redirect_to :root) && (return false)
    end
  end
end
