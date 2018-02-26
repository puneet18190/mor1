# -*- encoding : utf-8 -*-
# Recorded Users' calls, for Monitoring purposes.
class RecordingsController < ApplicationController
  layout 'callc'

  before_filter :check_localization
  before_filter :addon_on?
  before_filter :authorize, if: lambda { !accountant? }
  before_filter :check_post_method, only: [:destroy_recording, :destroy, :update, :list_users_update]
  before_filter :res_authorization, only: [:show]
  before_filter :res_recordings_auth, only: [:recordings, :bulk_management, :bulk_delete, :recordings_checkboxes]
  before_filter :find_user, only: [:recordings]
  before_filter :authorize_rec_list, only: [:list]

  before_filter { |method|
    view = [:list, :play_rec, :play_recording, :show, :get_recording]
    edit = [:edit, :update, :setup, :destroy, :destroy_recording]
    allow_read, allow_edit = method.check_read_write_permission(
        view, edit, { role: 'accountant', right: 'acc_recordings_manage', ignore: true }
    )
    method.instance_variable_set :@allow_read, allow_read
    method.instance_variable_set :@allow_edit, allow_edit
    true
  }

  def get_recording
    rec_id = params[:rec]
    rec = Recording.where(id: rec_id).first
    rec_dst_user_id = rec.dst_user_id
    rec_users = User.where(id: [rec.try(:user_id), rec_dst_user_id]) if rec
    is_authorized = (rec_users.map(&:owner_id) + [rec.user_id, rec_dst_user_id, 0]).include? correct_owner_id if rec
    rec_mp3_file = "/home/mor/public/recordings/#{rec.mp3}"

    if rec_id.blank? || rec_users.blank?
      dont_be_so_smart
      redirect_to(:root) && (return false)
    elsif !is_authorized
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to(:root) && (return false)
    else
      rec_mp3 = File.read(rec_mp3_file) rescue nil
      unless rec && rec_mp3
        flash[:notice] = _('Recording_was_not_found')
        redirect_to(:root) && (return false)
      else
        send_data(File.open(rec_mp3_file).read, filename: rec.datetime.strftime('%F_%T_') + nice_user(rec.user).gsub(' ', '_').to_s + '_[' + rec.uniqueid + '].mp3')
      end
    end
  end

  def show
    unless recordings_addon_active?
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
    @device = Device.where(id: params[:show_rec]).first
    unless @device
      flash[:notice] = _('Device_not_found')
      (redirect_to :root) && (return false)
    end

    @user = @device.user
    device_id = @device.id.to_i

    @page_title = _('Recordings')
    @page_icon = 'music.png'

    change_date

    from_t = session[:current_user_time_from]
    till_t = session[:current_user_time_till]

    @page = (params[:page] || 1).to_i
    @from = ((@page - 1) * session[:items_per_page]).to_i
    @to = (session[:items_per_page]).to_i
    @s_dev = device_id

    sql = "SELECT recordings.*, calls.real_billsec, calls.disposition, calls.dst AS call_dst, calls.id AS real_call_id, calls.src AS call_src,
                  providers.name AS provider_name
           FROM recordings
           LEFT JOIN calls ON (recordings.uniqueid = calls.uniqueid AND calls.calldate = recordings.datetime)
           LEFT JOIN providers ON providers.id = calls.provider_id
           WHERE recordings.datetime BETWEEN '#{from_t}' AND '#{till_t}'
                 AND (recordings.src_device_id = '#{device_id}' OR recordings.dst_device_id = '#{device_id}')
           GROUP BY recordings.id
           ORDER BY recordings.datetime DESC LIMIT #{@from}, #{@to}"

    @recs = Recording.find_by_sql(sql)

    @total_pages = Recording.where("datetime BETWEEN '#{from_t}' AND '#{till_t}' AND (src_device_id = '#{device_id}' OR dst_device_id = '#{device_id}')").size
    (@total_pages % session[:items_per_page] > 0) ? (@rest = 1) : (@rest = 0)
    @total_pages = @total_pages / session[:items_per_page] + @rest
    @page_select_options = {action: 'show', controller: 'recordings', show_rec: @s_dev}
    @show_recordings_with_zero_billsec = (Confline.get_value('Show_recordings_with_zero_billsec').to_i == 1)
  end

  def play_rec
    @page_title = ''
    @rec = Recording.where(id: params[:rec]).first
    unless @rec
      flash[:notice] = _('Recording_was_not_found')
      redirect_to(:root) && (return false)
    end
    @rec_folder = defined?(Recordings_Folder) ? Recordings_Folder : '/var/spool/asterisk/monitor/'
    @title = Confline.get_value('Admin_Browser_Title')
    render(layout: 'play_rec')
  end

  # Plays recording in new popup window.
  def play_recording
    @page_title = ''
    @rec = Recording.where(id: params[:id]).first
    unless @rec
      flash[:notice] = _('Recording_was_not_found')
      (redirect_to :root) && (return false)
    end

    @recording = ''
    if @rec
      server_path = get_server_path(@rec.local)
      user_rec = check_user_for_recording(@rec)
      return false unless user_rec

      @title = Confline.get_value('Admin_Browser_Title')

      @recording = server_path.to_s + @rec.mp3
      @rec.play
    end
    render(layout: 'play_rec')
  end

  # Lists recordings for user.
  def list_recordings
    @page_title = _('Recordings')
    @page_icon = 'music.png'

    unless current_user.recording_enabled.to_i == 1 && show_recordings? && user? && !!session[:simple_user_menu_permissions][:recordings]
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    @user = User.where(id: session[:user_id]).first

    @server_path = get_server_path(1)
    @remote_server_path = get_server_path(0)

    change_date

    default_options = {
      page: 1,
      order_desc: 1,
      order_by: 'datetime',
      s_destination: '',
      s_source: '',
      search_on: 0
    }

    @options = session[:user_recording_options] || {}

    if params[:clear].to_i == 1
      @options = default_options
      @search = 0
      change_date_to_present
    else
      set_options_from_params(@options, params, default_options)
    end

    @search = (params[:search_on] || @options[:search_on]).to_i
    @search_source = (params[:s_source] || @options[:s_source]).to_s
    @search_destination = (params[:s_destination] || @options[:s_destination]).to_s
    @date_from = params[:date_from_link] || limit_search_by_days
    @date_till = params[:date_till_link] || session_till_datetime

    conditions_str = "recordings.datetime BETWEEN #{ActiveRecord::Base::sanitize(@date_from)} AND #{ActiveRecord::Base::sanitize(@date_till)} AND deleted = 0"

    if @search_source.present?
      conditions_str << " AND calls.src LIKE #{ActiveRecord::Base::sanitize(@search_source)}"
    end

    if @search_destination.present?
      conditions_str << " AND calls.dst LIKE #{ActiveRecord::Base::sanitize(@search_destination)}"
    end

    user_id = @user.id
    conditions_str << " AND ((recordings.user_id = #{user_id} AND visible_to_user = 1) OR
                             (recordings.dst_user_id = #{user_id} AND visible_to_dst_user = 1))"

    @size = Recording.select('DISTINCT recordings.id')
                     .joins('LEFT JOIN devices as src ON (src.id = recordings.src_device_id)')
                     .joins('LEFT JOIN devices as dst ON (dst.id = recordings.dst_device_id)')
                     .joins('LEFT JOIN users src_user ON (src_user.id = src.user_id)')
                     .joins('LEFT JOIN users dst_user ON (dst_user.id = dst.user_id)')
                     .joins('LEFT JOIN calls ON (calls.uniqueid = recordings.uniqueid AND calls.calldate = recordings.datetime)')
                     .where(conditions_str).count

    fpage, @total_pages, @options = Application.pages_validator(session, @options, @size)

    sql = "SELECT * FROM (SELECT recordings.*, calls.real_billsec, calls.disposition, calls.dst AS call_dst,
              calls.id AS real_call_id, calls.src AS call_src
           FROM recordings
           LEFT JOIN devices as src ON (src.id = recordings.src_device_id)
           LEFT JOIN devices as dst ON (dst.id = recordings.dst_device_id)
           LEFT JOIN users src_user ON (src_user.id = src.user_id)
           LEFT JOIN users dst_user ON (dst_user.id = dst.user_id)
           LEFT JOIN calls ON (calls.uniqueid = recordings.uniqueid AND calls.calldate = recordings.datetime)
           WHERE #{conditions_str}
           ORDER BY calls.uniqueid, real_call_id DESC) AS A
           GROUP BY A.id
           ORDER BY A.datetime DESC LIMIT #{fpage}, #{session[:items_per_page]}"

    @recordings = Recording.find_by_sql(sql)

    @show_recordings_with_zero_billsec = (Confline.get_value('Show_recordings_with_zero_billsec').to_i == 1)
    session[:user_recording_options] = @options
  end

  # Recording edit action for admin and reseller.
  def edit
    @page_title = _('Edit_Recording')
    @page_icon = 'edit.png'
    @recording = Recording.where(id: params[:id]).first
    unless @recording
      flash[:notice] = _('Recording_was_not_found')
      (redirect_to :root) && (return false)
    end
    access = check_user_for_recording(@recording)
    return false unless access
  end

=begin rdoc
  Recording edit action for user.
=end

  def edit_recording
    @page_title = _('Edit_Recording')
    @page_icon = 'edit.png'
    @recording = Recording.where(id: params[:id]).first
    unless @recording
      flash[:notice] = _('Recording_was_not_found')
      (redirect_to :root) && (return false)
    end
    user_rec = check_user_for_recording(@recording)
    return false unless user_rec
  end

=begin rdoc
 Recording update action for admin and reseller.
=end

  def update
    @recording = Recording.where(id: params[:id]).first
    unless @recording
      flash[:notice] = _('Recording_was_not_found')
      (redirect_to :root) && (return false)
    end
    a = check_user_for_recording(@recording)
    return false unless a

    @recording.comment = params[:recording][:comment].to_s
    if @recording.save
      flash[:notice] = _('Recording_was_updated')
    else
      flash[:notice] = _('Recording_was_not_updated')
    end
    redirect_to(action: 'list_recordings') and return false
  end

=begin rdoc
 Recording update action for user
=end

  def update_recording
    @recording = Recording.where(id: params[:id]).first
    unless @recording
      flash[:notice] = _('Recording_was_not_found')
      (redirect_to :root) && (return false)
    end
    access = check_user_for_recording(@recording)
    return false unless access

    param_recordings = params[:recording]

    if session[:usertype] == 'user'
      @recording.user_comment = param_recordings[:user_comment].to_s
      action = 'list_recordings'
    else
      @recording.comment = param_recordings[:comment].to_s
      action = 'recordings'
    end

    if @recording.save
      flash[:status] = _('Recording_was_updated')
    else
      flash[:notice] = _('Recording_was_not_updated')
    end
    redirect_to(action: action) and return false
  end

=begin rdoc

=end

  def list_users
    @page_title = _('Users')
    @page_icon = 'vcard.png'
    @roles = Role.where("name !='guest'").all
    @items_per_page = Confline.get_value('Items_Per_Page').to_i

    @search = params[:search_on].try(:to_i) || 0
    @page = params[:page].try(:to_i) || 1
    @search_username = params[:s_username] || ''
    @search_fname = params[:s_first_name] || ''
    @search_lname = params[:s_last_name] || ''
    @search_agrnumber = params[:s_agr_number] || ''
    @search_sub = params[:sub_s].try(:to_i) || -1
    @search_type = params[:user_type] || -1
    @search_account_number = params[:s_acc_number] || ''
    @search_clientid = params[:s_clientid] || ''

    @users, @size = User.list_for_recordings(params, session)

    @total_pages = (@size / @items_per_page.to_d).ceil
    @page_select_params = {
        s_username: @search_username,
        s_first_name: @search_fname,
        s_last_name: @search_lname,
        s_agr_number: @search_agrnumber,
        sub_s: @search_sub,
        user_type: @search_type,
        s_acc_number: @search_account_number,
        s_clientid: @search_clientid
    }
  end

  def list
    @page_title = _('Recordings')
    @page_icon = 'music.png'

    unless recordings_addon_active?
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    param_id = params[:id]

    if param_id.to_i == 0
      redirect_to action: 'recordings' and return false
    end

    @server_path = get_server_path(1)
    @remote_server_path = get_server_path(0)

    if %w(admin reseller accountant).include?(session[:usertype])
      id = param_id
    else
      id = session[:user_id]
    end
    @user = User.where(id: id, owner_id: 0, usertype: 'user').first

    if @user.blank?
      flash[:notice] = _('Recordings_were_not_found')
      (redirect_to :root) && (return false)
    end

    change_date
    set_variables_by_params

    conditions_str = "recordings.datetime BETWEEN #{ActiveRecord::Base::sanitize(@date_from)} AND #{ActiveRecord::Base::sanitize(@date_till)}"

    if @search_source.present?
      conditions_str << " AND calls.src LIKE '#{@search_source}'"
      @search = 1
    end

    if @search_destination.present?
      conditions_str << " AND calls.dst LIKE '#{@search_destination}'"
      @search = 1
    end

    if @user
      user_id = @user.id.to_i
      conditions_str << " AND (recordings.user_id = #{user_id} OR recordings.dst_user_id = #{user_id})"
      @search = 1
    end

    @search = 0 if params[:clear].to_i == 1
    @items_per_page = Confline.get_value('Items_Per_Page').to_i

    sql = "SELECT * FROM (SELECT recordings.*, calls.real_billsec, calls.disposition, calls.dst AS call_dst,
              calls.id AS real_call_id, calls.src AS call_src
           FROM recordings
           LEFT JOIN devices as src ON (src.id = recordings.src_device_id)
           LEFT JOIN devices as dst ON (dst.id = recordings.dst_device_id)
           LEFT JOIN users src_user ON (src_user.id = src.user_id)
           LEFT JOIN users dst_user ON (dst_user.id = dst.user_id)
           LEFT JOIN calls ON (calls.uniqueid = recordings.uniqueid AND calls.calldate = recordings.datetime)
           WHERE #{conditions_str}
           ORDER BY calls.uniqueid, real_call_id DESC) AS A
           GROUP BY A.id
           ORDER BY datetime DESC LIMIT #{(@page - 1) * @items_per_page}, #{@items_per_page}"

    @recordings = Recording.find_by_sql(sql)

    @size = Recording.select('DISTINCT recordings.id')
                     .joins('LEFT JOIN devices as src ON (src.id = recordings.src_device_id)')
                     .joins('LEFT JOIN devices as dst ON (dst.id = recordings.dst_device_id)')
                     .joins('LEFT JOIN users src_user ON (src_user.id = src.user_id)')
                     .joins('LEFT JOIN users dst_user ON (dst_user.id = dst.user_id)')
                     .joins('LEFT JOIN calls ON (calls.uniqueid = recordings.uniqueid AND calls.calldate = recordings.datetime)')
                     .where(conditions_str).count

    @total_pages = (@size.to_d / @items_per_page.to_d).ceil
    @page_select_params = {
        s_source: @search_source,
        s_destination: @search_destination
    }
    @show_recordings_with_zero_billsec = (Confline.get_value('Show_recordings_with_zero_billsec').to_i == 1)
  end

  def recordings
    @page_title = _('Recordings')
    @page_icon = 'music.png'
    change_date
    owner_id = correct_owner_id

    unless show_rec?
      flash[:notice] = partner? ? _('Dont_be_so_smart') : _('You_are_not_authorized_to_view_this_page')
      (redirect_to :root) && (return false)
    end

    unless recordings_addon_active?
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    default_options = {
      page: 1,
      order_desc: 1,
      order_by: 'datetime',
      s_destination: '',
      s_source: '',
      s_user: '',
      s_user_id: -2,
      s_device: 'all'
    }

    @options = session[:recording_options] || {}

    if params[:clear].to_i == 1
      @options = default_options
      @search = 0
      change_date_to_present
    else
      set_options_from_params(@options, params, default_options)
    end

    if params[:search_on]
      @search = 1
    end

    @devices = []
    param_s_user_id = params[:s_user_id]
    @user = (param_s_user_id || @options[:s_user_id]).to_i
    @device = (params[:s_device] || @options[:s_device]).to_i
    @search_source = (params[:s_source] || @options[:s_source]).to_s
    @search_destination = (params[:s_destination] || @options[:s_destination]).to_s
    @date_from = params[:date_from_link] || limit_search_by_days
    @date_till = params[:date_till_link] || session_till_datetime

    if @user_passed.present? && param_s_user_id.blank?
      @user = @user_passed.try(:id).to_i
      @options[:s_user] = nice_user(@user_passed)
    end

    @options[:s_user_id] = @user
    @options[:s_device] = @device
    @options[:s_source] = @search_source
    @options[:s_destination] = @search_destination

    # Check if user belongs to owner
    if @user > 0
      user = User.where(id: @user).first
      if user.try(:owner_id) != owner_id
        dont_be_so_smart
        redirect_to :root
        return false
      end
    else
      @options[:s_user] = ''
      @options[:s_user_id] = '-2'
    end

    conditions_str = "(src_user.owner_id = #{owner_id} OR dst_user.owner_id = #{owner_id}) AND
                      (recordings.datetime BETWEEN '#{@date_from}' AND '#{@date_till}')"

    if @user > 0
      conditions_str << " AND (recordings.user_id = #{@user} OR recordings.dst_user_id = #{@user})"
      @devices = Device.select('devices.*')
                       .joins('LEFT JOIN users ON (users.id = devices.user_id)')
                       .where(["users.owner_id = ? AND device_type != 'FAX' AND user_id = ? AND name NOT LIKE 'mor_server_%'", owner_id, @user])
    end

    if @device > 0
      conditions_str << " AND (recordings.src_device_id = #{@device} OR recordings.dst_device_id = #{@device})"
    end

    if @search_source.present?
      conditions_str << " AND calls.src LIKE '#{@search_source}'"
    end

    if @search_destination.present?
      conditions_str << " AND calls.dst LIKE '#{@search_destination}'"
    end

    @size = Recording.select('DISTINCT recordings.id')
                     .joins('LEFT JOIN devices as src ON (src.id = recordings.src_device_id)')
                     .joins('LEFT JOIN devices as dst ON (dst.id = recordings.dst_device_id)')
                     .joins('LEFT JOIN users src_user ON (src_user.id = src.user_id)')
                     .joins('LEFT JOIN users dst_user ON (dst_user.id = dst.user_id)')
                     .joins('LEFT JOIN calls ON (calls.uniqueid = recordings.uniqueid AND calls.calldate = recordings.datetime)')
                     .where(conditions_str).count

    fpage, @total_pages, @options = Application.pages_validator(session, @options, @size)
    order_asc = @options[:order_desc].to_i == 0 ? 'ASC' : 'DESC'
    options_order_by = @options[:order_by]
    order_by = ['src', 'dst'].include?(options_order_by.to_s) ? "call_#{options_order_by}" : options_order_by

    sql = "SELECT * FROM (SELECT recordings.*, calls.real_billsec, calls.disposition, calls.dst AS call_dst,
              calls.id AS real_call_id, calls.src AS call_src
           FROM recordings
           LEFT JOIN devices as src ON (src.id = recordings.src_device_id)
           LEFT JOIN devices as dst ON (dst.id = recordings.dst_device_id)
           LEFT JOIN users src_user ON (src_user.id = src.user_id)
           LEFT JOIN users dst_user ON (dst_user.id = dst.user_id)
           LEFT JOIN calls ON (calls.uniqueid = recordings.uniqueid AND calls.calldate = recordings.datetime)
           WHERE #{conditions_str}
           ORDER BY calls.uniqueid, real_call_id DESC) AS A
           GROUP BY A.id
           ORDER BY #{order_by} #{order_asc} LIMIT #{fpage}, #{session[:items_per_page]}"

    @recordings = Recording.find_by_sql(sql)
    @server_path = get_server_path(1)
    @remote_server_path = get_server_path(0)
    @show_recordings_with_zero_billsec = (Confline.get_value('Show_recordings_with_zero_billsec').to_i == 1)
    session[:recording_options] = @options
  end

  def list_users_update
    @search = (params[:search_on] || 0).to_i
    @page = (params[:fs_page] || 1).to_i
    @search_username = params[:fs_username] || ''
    @search_fname = params[:fs_first_name] || ''
    @search_lname = params[:fs_last_name] || ''
    @search_agrnumber = params[:fs_agr_number] || ''
    @search_sub = params[:fsub_s] || -1
    @search_type = params[:fuser_type] || -1
    @search_account_number = params[:fs_acc_number] || ''
    @search_clientid = params[:fs_clientid] || ''
    users = {}
    params.each do |key, value|
      if key.scan(/recording_enabled_|recording_forced_enabled_|recording_hdd_quota_|recordings_email_/).size > 0
        num = key.gsub(/recording_enabled_|recording_forced_enabled_|recording_hdd_quota_|recordings_email_/, '')
        unless users[num]
          users[num] = User.where(id: num).first
        end
      end
    end
    users.each do |num, user|
      recording_before = "#{user.recording_enabled}#{user.recording_forced_enabled}"
      user.update_recordings_permissions(params, num)
      recording_after = "#{user.recording_enabled}#{user.recording_forced_enabled}"
      if recording_before != recording_after
        user.devices.where(device_type: %w[sip iax2 h323 dahdi virtual]).each { |device| configure_extensions(device.id, { api: 1 }) }
      end
    end
    flash[:status] = _('Users_have_been_updated')
    redirect_to action: 'list_users', page: @page, s_username: @search_username, s_first_name: @search_fname, s_last_name: @search_lname, s_agr_number: @search_agrnumber, sub_s: @search_sub, user_type: @search_type, s_acc_number: @search_account_number, s_clientid: @search_clientid and return false
  end

  def destroy_recording
    @recording = Recording.where(id: params[:id]).first

    unless @recording
      flash[:notice] = _('Recording_was_not_found')
      (redirect_to :root) && (return false)
    end

    user_rec = check_user_for_recording(@recording)
    return false unless user_rec

    if @recording.destroy_all_data
      flash[:status] = _('Recording_was_destroyed')
    else
      flash[:notice] = _('Recording_was_not_destroyed')
    end
    redirect_to(:back) && (return false)
  end

  def destroy
    rec = Recording.where(id: params[:id]).first

    unless rec
      flash[:notice] = _('Recording_was_not_found')
      (redirect_to :root) && (return false)
    end

    user_rec = check_user_for_recording(rec)
    return false unless user_rec

    notice = rec.destroy_rec(session)
    if !notice
      (redirect_to :root) && (return false)
    else
      flash[:status] = notice
    end

    redirect_to action: :list_recordings
  end

  def bulk_management
    @page_title = _('Bulk_management')
    @page_icon = 'music.png'
    @find_rec_size = -1

    unless show_rec?
      flash[:notice] = partner? ? _('Dont_be_so_smart') : _('You_are_not_authorized_to_view_this_page')
      (redirect_to :root) && (return false)
    end

    session[:recordings_delete_cond] = nil
    param_rec_action = params[:rec_action].to_i

    if params[:recordings_action].to_i != 0
      @devices = Device.where("user_id = #{params[:s_user_id]} AND device_type != 'FAX'")
    else
      @devices = []
    end

    if param_rec_action != 0
      cond = 'id = -1'
      @type = param_rec_action
      current_user_id = current_user.id
      if param_rec_action == 1
        @device = Device.where(id: params[:s_device]).first
        if @device
          if @device.user.owner_id == current_user_id
            cond = "recordings.src_device_id = #{q(@device.id)}"
            @find_rec_size = Recording.where(cond).size
          else
            dont_be_so_smart
            redirect_to(:root) && (return false)
          end
        else
          flash[:notice] = _('Device_was_not_found')
          redirect_back_or_default('/callc/main')
        end
      end
      if param_rec_action == 2
        change_date
        cond = "datetime BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}' and (src_user.owner_id = #{current_user_id} OR dst_user.owner_id = #{current_user_id})"
        @find_rec_size = Recording.joins('LEFT JOIN devices as src ON (src.id = recordings.src_device_id)')
                            .joins('LEFT JOIN devices as dst ON (dst.id = recordings.dst_device_id)')
                            .joins('LEFT JOIN users src_user ON (src_user.id = src.user_id)')
                            .joins('LEFT JOIN users dst_user ON (dst_user.id = dst.user_id)')
                            .where(cond).count

        session[:delete_by_date] = true
      end
      session[:recordings_delete_cond] = cond
    end
  end

  def bulk_delete
    recordings_delete_cond = session[:recordings_delete_cond]
    if session[:delete_by_date]
      recordings = Recording.joins('LEFT JOIN devices as src ON (src.id = recordings.src_device_id)')
                            .joins('LEFT JOIN devices as dst ON (dst.id = recordings.dst_device_id)')
                            .joins('LEFT JOIN users src_user ON (src_user.id = src.user_id)')
                            .joins('LEFT JOIN users dst_user ON (dst_user.id = dst.user_id)')
                            .where(recordings_delete_cond).readonly(false).all
    else
      recordings = Recording.joins('JOIN users ON users.id = recordings.user_id').where(recordings_delete_cond).readonly(false).all
    end
    for rec in recordings
      unless rec
        flash[:notice] = _('Recording_was_not_found')
        (redirect_to :root) && (return false)
      end
      user_rec = check_user_for_recording(rec)
      return false unless user_rec
      if rec.destroy_all_data
        flash[:notice] = _('Recordings_was_destroyed')
      else
        flash[:notice] = _('Recordings_was_not_destroyed')
        redirect_to(action: 'recordings') and return false
      end
    end
    redirect_to(action: 'recordings') and return false
  end

  def recordings_checkboxes
    param_recording_ids = params[:recording_ids]
    if param_recording_ids.present?
      recordings = recordings_correct_owner(param_recording_ids)

      case params[:commit].to_s
        when _('Delete_Selected')
          delete_selected_recordings(recordings)
          flash_status = _('Selected_Recordings_were_deleted')
        when _('Download_Selected')
          download_selected_recordings(recordings) && (return false)
      end

      flash[:status] = flash_status if flash_status
    else
      flash[:notice] = _('No_Recordings_were_selected')
    end

    redirect_to(action: :recordings) && (return false)
  end

  private

  def recordings_correct_owner(recording_ids = [])
    recording_ids.map! { |id| Recording.where(id: id).first }.delete_if { |rec| !check_user_for_recording(rec, false) }
  end

  def delete_selected_recordings(recordings = [])
    recordings.each { |recording| recording.destroy_all_data }
  end

  def download_selected_recordings(recordings = [])
    recordings.delete_if { |rec| !rec.check_if_file_exist }
    rec_size = recordings.size

    if rec_size == 1
      recording = recordings.first

      send_data(
          File.open("/home/mor/public/recordings/#{recording.mp3}").read,
          filename: recording_download_filename(recording)
      ) rescue nil
    elsif rec_size > 1
      tar_foldername = "recordings_#{Time.now.to_i}"
      tar_filepath = "/tmp/mor/recordings/#{tar_foldername}"
      `mkdir -p #{tar_filepath}`

      # Rename Recordings and temporary store them into /tmp/mor/recordings/
      recordings.each do |recording|
        `cp /home/mor/public/recordings/#{recording.uniqueid}.mp3 #{tar_filepath}/#{recording_download_filename(recording)}`
      end

      # Create tar.gz and send it
      `tar -czf #{tar_filepath}.tar.gz --directory=/tmp/mor/recordings/ #{tar_foldername}`
      send_data(File.open("#{tar_filepath}.tar.gz").read, filename: "#{tar_foldername}.tar.gz") rescue nil

      # Cleanup
      `rm -rf #{tar_filepath}/`
      `rm -rf #{tar_filepath}.tar.gz`
    end
  end

  def recording_download_filename(recording)
    "#{recording.datetime.strftime('%F_%T_')}#{nice_user(recording.user).gsub(' ', '_')}_[#{recording.uniqueid}].mp3"
  end

  def check_user_for_recording(recording, redirect = true)
    if recording.blank?
      if redirect
        dont_be_so_smart
        redirect_to :root
      end
      return false
    end

    session_user_id = session[:user_id]
    rec_user_id = recording.user_id
    user_id = rec_user_id if rec_user_id.present?
    rec_user_not_equal = user_id != session_user_id
    if ((rec_user_not_equal && recording.dst_user_id != session_user_id)) && user?
      if redirect
        dont_be_so_smart
        redirect_to :root
      end
      return false
    end
    if session[:usertype] == 'reseller' && ((recording.user.try(:owner_id) != session_user_id) &&
                                              (recording.dst_user.try(:owner_id) != session_user_id))
      if rec_user_not_equal && (user_id != -1)
        if redirect
          dont_be_so_smart
          redirect_to :root
        end
        return false
      end
    end
    true
  end

  def addon_on?
    unless rec_active?
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
  end

  def res_authorization
    if reseller?
      device = Device.where(id: params[:show_rec]).first
      user = device.user if device
      if user && (user.owner_id != current_user.id)
        flash[:notice] = _('You_have_no_view_permission')
        (redirect_to :root) && (return false)
      end
    end
  end

  def res_recordings_auth
    if reseller? && User.current.recording_enabled.to_i != 1
      flash[:notice] = _('You_have_no_view_permission')
      (redirect_to :root) && (return false)
    end
  end

  def set_order_by
    param_order_by = params[:order_by]
    param_order_desc = params[:order_desc]
    @options = session[:recordings_ordering] || { order_by: 'datetime', order_desc: 1 }
    @options[:order_by] = param_order_by if param_order_by.present?
    @options[:order_desc] = param_order_desc if param_order_desc.present?
    session[:recordings_ordering] = @options
    @options[:order_by] = 'recordings.datetime' unless Recording.new.respond_to?(@options[:order_by]) ||
                                                                             Call.new.respond_to?(@options[:order_by])
    order_by_calls = ['src', 'dst'].include?(@options[:order_by].to_s) ? 'call_' : ''
    @options[:order_full] = "#{order_by_calls}#{@options[:order_by]} #{@options[:order_desc].to_i == 1 ? ' DESC' : ' ASC'}"
  end

  def set_variables_by_params
    @page = (params[:page] || 1).to_i
    @search = (params[:search_on] || 0).to_i
    @search_source = params[:s_source] || ''
    @search_destination = params[:s_destination] || ''
    @date_from = params[:date_from_link] || limit_search_by_days
    @date_till = params[:date_till_link] || session_till_datetime
  end

  def authorize_rec_list
    unless accountant?
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
  end

  def find_user
    search_id = params[:id]
    if search_id.present?
      unless @user_passed = User.where(id: search_id.to_i, owner_id: current_user.get_corrected_owner_id).first
        flash[:notice] = _('User_was_not_found')
        redirect_to(:root) && (return false)
      end
    end
  end
end
