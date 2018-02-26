# -*- encoding : utf-8 -*-
# Auto Dialer Campaigns.
class AutodialerController < ApplicationController
  layout 'callc'

  before_filter :access_denied, only: [:campaign_new, :user_campaigns, :import_numbers_from_file, :campaign_actions,
                                       :campaign_change_status, :campaign_edit, :campaign_numbers, :number_destroy,
                                       :delete_all_numbers],
                if: lambda { !user? }
  before_filter :not_authorized, unless: lambda { ad_active? }
  before_filter :check_post_method, only: [:redial_all_failed_calls, :campaign_update, :campaign_create,
                                           :campaign_destroy, :action_destroy, :action_add, :action_update,
                                           :number_destroy]

  before_filter :check_localization
  before_filter :authorize
  before_filter :find_campaign, only: [:export_call_data_to_csv, :campaign_destroy, :view_campaign_actions,
                                       :campaign_update, :redial_all_failed_calls, :action_add, :campaign_actions,
                                       :import_numbers_from_file, :campaign_edit, :campaign_change_status,
                                       :campaign_numbers, :delete_all_numbers]

  before_filter :find_campaign_action, only: [:play_rec, :action_update, :action_edit, :action_destroy]
  before_filter :find_adnumber, only: [:reactivate_number, :number_destroy]
  before_filter :check_params_campaign, only: [:campaign_create, :campaign_update]

  before_filter :deprecated_functionality, only: [:campaign_new, :user_campaigns, :campaign_change_status,
                                                  :redial_all_failed_calls, :campaign_destroy, :campaign_numbers,
                                                  :campaign_update, :campaign_actions, :campaign_edit, :campaign_update,
                                                  :import_numbers_from_file]

  # --------- Admin campaigns -------------
  def campaigns
    (dont_be_so_smart && (redirect_to :root)) if (current_user.usertype == 'reseller' && current_user.reseller_right('autodialer').to_i != 2)
    @page_title = _('Campaigns')
    @campaigns = Campaign.select("campaigns.*, #{SqlExport.nice_user_sql}")
                         .joins('JOIN users ON campaigns.user_id = users.id')
                         .where(['users.hidden = 0 AND users.owner_id = ?', current_user.id])
                         .order('campaigns.user_id, campaigns.name').all
    @total_numbers, @total_dialed, @total_completed, @total_profit = [0, 0, 0, 0]
  end

  def view_campaign_actions
    @page_title, @page_icon = "#{_('Actions_for_campaign')}: #{@campaign.name}", 'actions.png'
    @actions = @campaign.adactions
  end

  # ------------ User campaigns -------------
  def user_campaigns
    @page_title = _('Campaigns')
    @user = current_user
    @campaigns = @user.campaigns
  end

  def campaign_new
    @user = current_user

    if user? || accountant?
      @devices = current_user.devices.where.not(device_type: 'FAX').all
    else
      @devices = Device.select('devices.id, devices.description, devices.extension, devices.device_type, devices.istrunk, devices.name, devices.ani, devices.username').
                        joins('LEFT JOIN users ON (users.id = devices.user_id)').
                        where(["device_type != 'FAX' AND owner_id = ? AND name not like 'mor_server_%'", corrected_user_id]).
                        order('extension').all
    end

    if @devices.blank?
      flash[:notice] = _('Please_create_device_for_campaign')
      redirect_to(action: :user_campaigns) && (return false)
    end

    @page_title, @page_icon = _('New_campaign'), 'add.png'

    @campaign = Campaign.new

    @ctypes = ['simple']
    time_now = Time.now
    time_now_year = time_now.year
    time_now_month = time_now.month
    time_now_day = time_now.day
    time_from = Time.mktime(time_now_year, time_now_month, time_now_day, '00', '00')
    time_till = Time.mktime(time_now_year, time_now_month, time_now_day, '23', '59')

    @from_hour = time_from.hour
    @from_min = time_from.min
    @till_hour = time_till.hour
    @till_min = time_till.min
  end

  def campaign_create
    params_time_from = params[:time_from]
    params_time_till = params[:time_till]
    time_from = time_in_local_tz(params_time_from[:hour], params_time_from[:minute], '00')
    time_till = time_in_local_tz(params_time_till[:hour], params_time_till[:minute], '59')

    @campaign = Campaign.create_by_user(current_user, params, time_from, time_till)
    if @campaign.errors.blank? && @campaign.save
      flash[:status] = _('Campaign_was_successfully_created')
      redirect_to(action: :user_campaigns)
    else
      flash_errors_for(_('Campaign_was_not_created'), @campaign)
      redirect_to(action: :campaign_new)
    end
  end

  def campaign_destroy
    Adnumber.where(campaign_id: @campaign.id).delete_all
    @campaign.destroy
    flash[:status] = _('Campaign_deleted')
    redirect_to(action: :user_campaigns)
  end

  def campaign_edit
    @page_title, @page_icon = _('Edit_campaign'), 'edit.png'
    @ctypes = ['simple']

    start_time, stop_time = [@campaign.start_time, @campaign.stop_time]

    from = time_in_user_tz(start_time.hour, start_time.min, '00')
    till = time_in_user_tz(stop_time.hour, stop_time.min, '59')

    @from_hour, @from_min = [from.hour, from.min]
    @till_hour, @till_min = [till.hour, till.min]

    @user = current_user

    if user? || accountant?
      @devices = current_user.devices.where.not(device_type: 'FAX')
    else
      @devices = Device.select('devices.id, devices.description, devices.extension, devices.device_type, devices.istrunk, devices.name, devices.ani, devices.username').
                        joins('LEFT JOIN users ON (users.id = devices.user_id)').
                        where(["device_type != 'FAX' AND owner_id = ? AND name not like 'mor_server_%'", corrected_user_id]).
                        order('extension')
    end
  end

  def campaign_update
    params_campaign = params[:campaign]
    params_time_from = params[:time_from]
    params_time_till = params[:time_till]

    time_from = time_in_local_tz(params_time_from[:hour], params_time_from[:minute], '00')
    time_till = time_in_local_tz(params_time_till[:hour], params_time_till[:minute], '59')
    @campaign.update_by(params_campaign, time_from, time_till)

    if @campaign.errors.blank? && @campaign.save
      flash[:status] = _('Campaigns_details_was_successfully_changed')
      redirect_to(action: :user_campaigns)
    else
      flash_errors_for(_('Campaigns_details_not_changed'), @campaign)
      redirect_to(action: :campaign_edit, id: @campaign.id)
    end
  end

  def campaign_change_status
    notice, status_changed = @campaign.change_status
    if @campaign.save && status_changed
      flash[:status] = notice
    else
      flash_errors_for(_('Campaigns_details_not_changed'), @campaign)
      flash[:notice] = notice
      Action.add_action_hash(current_user, target_type: 'campaign', action: 'failed_ad_campaign_activation',
                             target_id: @campaign.id, data2: notice)
    end
    redirect_to(action: :user_campaigns)
  end

  # --------- Numbers ---------
  def campaign_numbers
    @page_title, @page_icon = "#{_('Numbers_for_campaign')}: #{@campaign.name}", 'details.png'
    campaign_adnumbers = @campaign.adnumbers
    campaign_adnumbers_size_decimal, session_items_per_page = campaign_adnumbers.size.to_d, session[:items_per_page]
    @adnumbers_number = campaign_adnumbers_size_decimal
    fpage, @total_pages, options = Application.pages_validator(session, params, @adnumbers_number)
    @page, @numbers = options[:page], campaign_adnumbers.offset(fpage).limit(session_items_per_page)
  end

  def number_destroy
    campaign_id = @number.campaign_id
    @number.destroy
    flash[:status] = _('number_successfully_deleted')
    redirect_to(controller: :autodialer, action: :campaign_numbers, id: campaign_id)
  end

  def delete_all_numbers
    @campaign.adnumbers.each { |number| number.destroy}
    flash[:status] = _('All_numbers_deleted')
    redirect_to(action: :campaign_numbers, id: params[:id])
  end

  def import_numbers_from_file
    campaign_id = @campaign.id
    adnumber_count_campaign_id = Adnumber.where(campaign_id: campaign_id).size
    @page_title = _('Number_import_from_file')
    @page_icon = 'excel.png'

    @step = 1
    params_step = params[:step]
    params_file = params[:file]
    @step = params_step.to_i if params_step

    if @step == 2
      if params_file
        @file = params_file
        if @file.size > 0
          if (!@file.respond_to?(:original_filename)) || (!@file.respond_to?(:read)) || (!@file.respond_to?(:rewind))
            flash[:notice] = _('Please_select_file')
            redirect_to(action: :import_numbers_from_file, id: campaign_id, step: 0) && (return false)
          end

          file_original_filename = @file.original_filename
          if get_file_ext(file_original_filename, 'csv') == false
            file_original_filename
            flash[:notice] = _('Please_select_CSV_file')
            redirect_to(action: :import_numbers_from_file, id: campaign_id, step: 0) && (return false)
          end

          @file.rewind
          file = @file.read
          session[:file_size] = file.size

          tname = CsvImportDb.save_file(campaign_id, file, '/tmp/')
          session["atodialer_number_import_#{campaign_id}".to_sym] = tname

          colums = {
              colums: [
                  {name: 'f_number', type: 'VARCHAR(50)', default: ''},
                  {name: 'f_error', type: 'INT(4)', default: 0},
                  {name: 'nice_error', type: 'INT(4)', default: 0},
                  {name: 'not_found_in_db', type: 'INT(4)', default: 0},
                  {name: 'id', type: 'INT(11)', inscrement: ' NOT NULL auto_increment '}
              ]
          }

          begin
            CsvImportDb.load_csv_into_db(tname, ',', '.', '', '/tmp/', colums, false)
            trial = {}
            @total_numbers, @imported_numbers, @bad_numbers_quantity = @campaign.insert_numbers_from_csv_file(tname, trial)
            flash[:status] = (@total_numbers.to_i == @imported_numbers.to_i) ? _('Numbers_imported') :
              _('M_out_of_n_numbers_imported', @imported_numbers, @total_numbers)
          rescue => crash
            MorLog.log_exception(crash, Time.now.to_i, params[:controller], params[:action])
            CsvImportDb.clean_after_import(tname, '/tmp/')
            flash[:notice] = _('MySQL_permission_problem_contact_Kolmisoft_to_solve_it')
            redirect_to(action: :import_numbers_from_file, id: campaign_id, step: 0) && (return false)
          end
        else
          flash[:notice] = _('Please_select_file')
          redirect_to(action: :import_numbers_from_file, id: campaign_id, step: 0) && (return false)
        end
      else
        flash[:notice] = _('Please_upload_file')
        redirect_to(action: :import_numbers_from_file, id: campaign_id, step: 0) && (return false)
      end
    end
  end

  def bad_numbers_from_csv
    params_id = params[:id].to_i
    session_autodial_number_import = session["atodialer_number_import_#{params_id}".to_sym]
    @page_title = _('Bad_rows_from_CSV_file')
    if ActiveRecord::Base.connection.tables.include?(session_autodial_number_import)
      @rows = ActiveRecord::Base.connection.select_all("SELECT * FROM #{session_autodial_number_import} WHERE f_error = 1")
    end

    render(layout: 'layouts/mor_min')
  end

  def reactivate_number
    @number.update_attributes(status: 'new', executed_time: '', completed_time: '')
    flash[:status] = "#{_('Number_reactivated')}: #{@number.number}"
    redirect_to(action: :campaign_numbers, id: @number.campaign_id)
  end

  #-------------- Actions --------------
  def campaign_actions
    @page_title, @page_icon = "#{_('Actions_for_campaign')}: #{@campaign.name}", 'actions.png'
    @actions = @campaign.adactions
    @ivrs = Ivr.where(user_id: current_user.owner_id).size
  end

  def action_add
    action_type = params[:action_type]
    campaign_id = @campaign.id
    action = Adaction.new({priority: @campaign.adactions.size + 1, campaign_id: campaign_id, action: action_type})
    action.data = 'silence1' if action_type == 'PLAY'
    action.data = '1' if action_type == 'WAIT'
    action.save
    flash[:status] = _('Action_added')
    redirect_to(action: :campaign_actions, id: campaign_id)
  end

  def action_destroy
    campaign_id = @action.campaign_id
    @action.destroy_action
    flash[:notice] = _('Action_deleted')
    redirect_to(action: :campaign_actions, id: campaign_id)
  end

  def action_edit
    @page_title = _('Edit_action')
    @page_icon = 'edit.png'
    @campaign = @action.campaign
    @ivrs = Ivr.where(all_users_can_use: 1, user_id: current_user.owner_id)
  end

  def action_update
    path, final_path = @action.campaign.final_path

    notice = @action.update_action(params, current_user)
    @action.save
    if notice == 'dont_be_so_smart'
      dont_be_so_smart
    elsif !notice.blank?
      flash[:notice] = notice
    end

    redirect_to(action: :campaign_actions, id: @action.campaign_id)
  end

  def play_rec
    @filename2 = @action.file_name
    @page_title = ''
    @Adaction_Folder = Web_Dir + '/ad_sounds/'
    @title = confline('Admin_Browser_Title')
    render(layout: 'play_rec')
  end

  def redial_all_failed_calls
    if Adnumber.where("status = 'executed' and campaign_id = #{@campaign.id}").update_all(status: 'new', executed_time: nil)
      flash[:status] = _('All_calls_failed_redial_was_successful')
    else
      flash[:notice] = _('All_calls_failed_redial_was_not_successful')
    end
    if session[:usertype] == 'admin'
      (redirect_to action: :campaigns) && (return false)
    else
      user_campaigns
      (redirect_to action: :user_campaigns) && (return false)
    end
  end

  def campaign_statistics
    @page_title = _('Campaign_Stats')
    autodialer_parse_params
    change_date
    @campaign_id =  @options[:campaign_id].to_i

    campaign_owner_id = admin? || accountant? ? 0 : @current_user.id
    @all_campaigns = Campaign.where("owner_id = #{campaign_owner_id} OR user_id = #{campaign_owner_id}")
    selected_campaign = Campaign.where(id: @campaign_id).first

    # Set default values
    @answered_percent = @no_answer_percent = @failed_percent = @busy_percent = 0
    @calls_busy = @calls_failed = @calls_no_answer = @calls_answered = 0

    if @campaign_id > 0 && selected_campaign.present?
      @campaing_stat_name = selected_campaign.name
      @numbers = Adnumber.where(campaign_id: @campaign_id).count.to_i

      if @numbers > 0

        if Time.parse(session_from_datetime) > Time.parse(session_till_datetime)
          flash[:notice] = _('Date_from_greater_thant_date_till')
        else
          device_id = selected_campaign.device_id
          @dialed = selected_campaign.executed_numbers_count.to_i
          @complete = selected_campaign.completed_numbers_count.to_i
          @total_billsec = selected_campaign.count_completed_user_billsec(session_from_datetime, session_till_datetime)
          @total_billsec_longer_than_10 = selected_campaign.count_completed_user_billsec_longer_than_ten(session_from_datetime, session_till_datetime)

          calls_by_disposition = Call.find_by_sql("SELECT COUNT(*) AS counted_calls, disposition FROM calls JOIN "\
            "adnumbers ON (adnumbers.number = calls.dst AND adnumbers.campaign_id = #{@campaign_id}) WHERE src_device_id"\
            "= #{device_id} AND disposition IN ('ANSWERED','NO ANSWER','FAILED','BUSY') AND calldate BETWEEN "\
            "'#{session_from_datetime}' AND '#{session_till_datetime}' GROUP BY disposition")

          calls_by_disposition.each do |row|
            call_counted_calls = row.counted_calls.to_i
            case row.disposition
            when 'ANSWERED'
              @calls_answered = call_counted_calls
            when 'NO ANSWER'
              @calls_no_answer = call_counted_calls
            when 'FAILED'
              @calls_failed = call_counted_calls
            when 'BUSY'
              @calls_busy = call_counted_calls
            end
          end

          @calls_all = @calls_answered + @calls_no_answer + @calls_failed + @calls_busy

          if @calls_all > 0
            @answered_percent = @calls_answered * 100 / @calls_all
            @no_answer_percent = @calls_no_answer * 100 / @calls_all
            @failed_percent = @calls_failed * 100 / @calls_all
            @busy_percent = @calls_busy * 100 / @calls_all

            # Create string for the pie chart
            @pie_chart = "ANSWERED;#{@calls_answered};true\\n"\
              "NO ANSWER;#{@calls_no_answer};false\\n"\
              "BUSY;#{@calls_busy};false\\n"\
              "FAILED;#{@calls_failed};false\\n"

            # Calculate calls per day graph
            user_timezone_offset = "(SELECT TIME_TO_SEC(TIMEDIFF('#{date_str_from_hash(@options[:date_from])}', "\
              "'#{session_from_datetime}'))/3600)"
            sql = "SELECT COUNT(calls.id) AS 'calls', SUM(calls.billsec) AS 'billsec', DATE_FORMAT(DATE_ADD(calldate, "\
              "INTERVAL #{user_timezone_offset} HOUR), '%Y-%m-%d') AS 'day' FROM calls JOIN adnumbers ON "\
              "(adnumbers.number = calls.dst AND adnumbers.status = 'completed' AND adnumbers.campaign_id = "\
              "#{@campaign_id}) WHERE (calls.calldate BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}'"\
              " AND src_device_id = #{device_id}) GROUP BY day"
            res = ActiveRecord::Base.connection.select_all(sql)

            @calls_graph = ''
            res.try(:each) { |day| @calls_graph << "#{day['day']};#{day['calls']}\\n" }
            @calls_graph << '\\n'
          else
            flash[:notice] = _('No_Calls_in_selected_time_period_for_campaign') + @campaing_stat_name
          end
        end
      else
        flash[:notice] = _('No_numbers_in_campaign') + @campaing_stat_name
      end
    end
    session[:campaign_stats] = @options
  end

  def export_call_data_to_csv
    IvrActionLog.link_logs_with_numbers

    @numbers = @campaign.adnumbers.includes([:ivr_action_logs]).all

    sep, _dec = current_user.csv_params

    csv_string = []

    @numbers.each do |number|
      data = []
      number_completed_time = number.completed_time
      number_executed_time = number.executed_time
      number_ivr_action_logs = number.ivr_action_logs

      data << number.number
      data << nice_date_time(number_executed_time).to_s unless number_executed_time.blank?
      data << nice_date_time(number_completed_time).to_s unless number_completed_time.blank?

      if number_ivr_action_logs.size.to_i > 0
        number_ivr_action_logs.each do |action|
          data << nice_date_time(action.created_at).to_s
          data << action.action_text.to_s.gsub(sep, '')
        end
      end

      csv_string << data.join(sep) if data && (data.size.to_i > 0)
    end

    csv_string_with_br = csv_string.join("\n")
    if params[:test].to_i == 1
      render text: csv_string_with_br
    else
      send_data(csv_string_with_br, type: 'text/csv; charset=utf-8; header=present', filename: 'Campaign_call_data.csv')
    end
  end

  private

  def clear_autodialer_search
    change_date_to_present
    @options[:campaign_id] = -1
    @options[:show_clear] = false
  end

  def date_str_from_hash(hash)
    "#{hash[:year]}-#{hash[:month]}-#{hash[:day]} #{hash[:hour]}:#{hash[:minute]}:00"
  end

  def autodialer_parse_params
    clear = params[:clear].to_i == 1
    campaign_id = params[:campaign_id] || -1
    campaign_id_present = campaign_id.to_i != -1
    dates_present = [:date_from, :date_till].any? { |key| params.key? key }
    search = dates_present || campaign_id_present
    @options = search ? params : session[:campaign_stats]
    @options[:campaign_id] = campaign_id if campaign_id_present

    clear_autodialer_search if clear

    options_tmp = @options
    time_not_current = [[:date_from, '00:00'], [:date_till, '23:59']].any? do |key, hour|
      Time.parse(date_str_from_hash(options_tmp[key])).strftime('%Y-%m-%d %H:%M') != Time.current.strftime("%Y-%m-%d #{hour}")
    end if [:date_from, :date_till].all? { |key| options_tmp.try(:key?, key) }
    @options[:show_clear] = (time_not_current || campaign_id_present) && !clear
  end

  def find_campaign
    current_user_type = current_user.try(:usertype)

    @campaign = Campaign.where('id = ? AND (user_id = ? OR owner_id = ?)', params[:id], current_user_id, current_user_id).first

    return @campaign if @campaign
    flash[:notice] = _('Campaign_was_not_found')
    if current_user_type.to_s == 'reseller' && current_user.reseller_right('autodialer').to_i != 2
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      (redirect_to :root) && (return false)
    elsif ['admin', 'accountant', 'reseller'].include?(current_user_type)
      dont_be_so_smart
      (redirect_to :root) && (return false)
    else
      (redirect_to action: user_campaigns) && (return false)
    end
  end

  def find_campaign_action
    @action = Adaction.where(id: params[:id]).includes([:campaign]).first
    unless @action
      flash[:notice] = _('Action_was_not_found')
      if current_user.is_admin?
        (redirect_to action: :campaigns) && (return false)
      else
        (redirect_to action: :user_campaigns) && (return false)
      end
    end

    camp, params_ivr = @action.campaign, params[:ivr]
    ivr = Ivr.where(id: params_ivr.to_i, all_users_can_use: 1).first if params_ivr

    if camp.blank? || (params_ivr && ivr.blank?)
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    user_session = check_user_id_with_session(camp.user_id)
    return false unless user_session
  end

  def find_adnumber
    @number = Adnumber.where(id: params[:id]).includes([:campaign]).first
    unless @number
      flash[:notice] = _('Number_was_not_found')
      if session[:usertype] == 'admin'
        (redirect_to action: :campaigns) && (return false)
      else
        user_campaigns
        (redirect_to action: :user_campaigns) && (return false)
      end
    end
    user_session = check_user_id_with_session(@number.campaign.user_id)
    return false unless user_session
  end

  def check_params_campaign
    if (!params[:campaign]) || (!params[:time_from]) || (!params[:time_till])
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
  end

  def deprecated_functionality
    current_user_type = current_user.try(:usertype)
    if ['admin', 'accountant', 'reseller'].include?(current_user_type)
      if current_user_type.to_s == 'reseller' && current_user.reseller_right('autodialer').to_i != 2
        flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      else
        flash[:notice] = _('Deprecated_functionality') +
        " <a href='http://wiki.kolmisoft.com/index.php/Deprecated_functionality' target='_blank'><img alt='Help' src='#{Web_Dir}/images/icons/help.png'/></a>".html_safe
      end
      (redirect_to :root) && (return false)
    end
  end

  def time_in_local_tz(hours, minutes, seconds = '00')
    Time.zone.parse([hours, minutes, seconds].join(':')).localtime
  end

  def not_authorized
    flash[:notice] = _('You_are_not_authorized_to_view_this_page')
    (redirect_to :root) && (return false)
  end
end
