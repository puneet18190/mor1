# -*- encoding : utf-8 -*-
# Ast Queues controller.
class AstQueuesController < ApplicationController
  layout 'callc'

  before_filter :check_post_method, only: [:create, :update, :destroy]
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_queue, only: [:edit, :update, :destroy]
  before_filter :check_pbx_addon, only: [:edit, :list, :new]

  before_filter do |method|
    view = [:index, :list]
    edit = [:create, :destroy, :update, :edit, :new]
    allow_read, allow_edit = method.check_read_write_permission(
        view, edit, {role: 'accountant', right: :acc_manage_queues, ignore: true}
    )
    method.instance_variable_set :@allow_read, allow_read
    method.instance_variable_set :@allow_edit, allow_edit
    true
  end

  before_filter :check_reseller
  before_filter :check_pbx_addon

  # Shows the list of queues. Accountant requires "Manage Queues" permissions
  def list
    @page_title = _('Queues')

    @options = session[:queues_list_options] || {}

    # Search
    @options[:page] = params[:page].to_i if params[:page].present?

    # Order
    @options[:order_desc] = if params[:order_desc]
                              params[:order_desc].to_i
                            elsif !@options[:order_desc]
                              0
                            else
                              @options[:order_desc]
                            end

    @options[:order_by] = if params[:order_by]
                            params[:order_by].to_s
                          elsif !@options[:order_by]
                            'name'
                          else
                            @options[:order_by]
                          end

    order_by = queues_order_by(@options)

    fpage, @total_pages, @options = Application.pages_validator(session, @options, AstQueue.where(owner_id: corrected_user_id).count)

    @queues = AstQueue.select('queues.*, pbx_pools.name AS pbx_name').
        joins('LEFT JOIN pbx_pools ON queues.pbx_pool_id = pbx_pools.id').
        where(owner_id: corrected_user_id).
        order(order_by).limit("#{fpage}, #{session[:items_per_page].to_i}").all

    session[:queues_list_options] = @options
  end

  def new
    @page_title = _('New_queue')
    @pbx_pool_dropdown = PbxPool.where(owner_id: corrected_user_id).order(:name).all
    @queue_params = params[:queue]
  end

  # Creating queue, after_create - create
  def create
    params[:queue][:name].to_s.strip!
    params[:queue][:extension].to_s.strip!
    params[:queue][:owner_id] = corrected_user_id
    @queue = AstQueue.new(params[:queue])

    # Checking for extension validation
    if extension_pbx_pool_exists?(params[:queue])
      @queue.errors.add(:extension_error, _('Extension_and_PBX_Pool_is_used'))
    end

    if !@queue.errors.any? && @queue.save
      reload_servers(get_servers_for_reload(ccl_active?, @queue.server_id))

      flash[:status] = _('Queue_created')
      redirect_to action: :edit, id: @queue.id
    else
      flash_errors_for(_('Queue_was_not_created'), @queue)
      redirect_to(action: :new, queue: params[:queue])
    end
  end

  def edit
    @page_title = _('Queue_edit')
    @page_icon = 'group.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Call_Queues'

    @dialplan = Dialplan.where(data1: @queue.id, dptype: 'queue').first
    @assigned_dids = Did.where(dialplan_id: @dialplan.id)
    @pbx_pool_dropdown = PbxPool.where(owner_id: corrected_user_id).order(:name).all

    show_servers_if_ccl_not_active(ccl_active?)

    @queue_strategies = %w[ringall roundrobin leastrecent fewestcalls random rrmemory wrandom linear rrordered]

    if @queue.failover_action.to_s == 'device'
      @device = Device.where(id: @queue.failover_data.to_i).first
      @user = @device.user
      @devices = Device.where(user_id: @user.id).all
    else
      @user, @devices, @device = [nil, [], nil]
    end

    if @queue.failover_action.to_s == 'did'
      @did = Did.where(id: @queue.failover_data).first
    end

    @announcements = IvrSoundFile.select('id, path').all
    @static_agents = QueueAgent.where(queue_id: @queue.id).order(:priority).all
    @mohs = Moh.all
    @ivrs = Ivr.where(user_id: corrected_user_id).all
    @join_leave_empty = %w[paused penalty inuse ringing unavailable invalid unknown wrapup]
    @periodic_announcements = QueuePeriodicAnnouncement.
        select('queue_periodic_announcements.id AS id,ivr_sound_files.path AS path').
        joins('LEFT JOIN ivr_sound_files ON (ivr_sound_files.id = queue_periodic_announcements.ivr_sound_files_id)').
        where(queue_id: @queue.id).order('priority').all

    # ===== Visualization =====
    @vis_join_ann = if @queue.join_announcement.to_i == 0
                      'none'
                    else
                      IvrSoundFile.where(id: @queue.join_announcement.to_i).first.try(:path).to_s
                    end
    a = Moh.select('ivr_sound_files.path AS path').joins('LEFT JOIN ivr_sound_files ON (ivr_sound_files.ivr_voice_id = mohs.ivr_voice_id)').where(id: @queue.moh_id).first
    group_name = Moh.select('mohs.moh_name AS name').joins('LEFT JOIN ivr_sound_files ON (ivr_sound_files.ivr_voice_id = mohs.ivr_voice_id)').where(id: @queue.moh_id).first
    @vis_moh = group_name.blank? ? 'default' : group_name.name.to_s
    fail_over_action = @queue.failover_action.to_s

    if fail_over_action == 'hangup'
      @vis_fail_over = _('Hangup')
    elsif fail_over_action == 'extension'
      @vis_fail_over = _('Transfer_to_extension') + ': ' + @queue.failover_data.to_s
    elsif fail_over_action == 'did'
      @vis_fail_over = _('Transfer_to_DID') + ': ' + Did.where(id: @queue.failover_data.to_i).first.did
    elsif fail_over_action == 'device'
      dev = Device.where(id: @queue.failover_data.to_i).first
      device_name = dev.name
      device_type = dev.device_type
      d = device_type + '/'
      d += device_name if device_type != 'FAX'
      d += dev.extension if (device_type == 'FAX') || (device_name.length == 0)
      @vis_fail_over = _('Transfer_to_device') + ': ' + d
    end

    a = Ivr.where(id: @queue.context.to_i).first
    @vis_ivr = a.blank? ? 'none' : a.name.to_s
  end

  # Updating queue, and dialplan of that queue
  def update
    @page_title = _('Queue_edit')
    @page_icon = 'group.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Call_Queues'

    if params[:queue].blank?
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    @pbx_pool_dropdown = PbxPool.where(owner_id: corrected_user_id).order(:name).all
    params[:queue][:name].to_s.strip!
    params[:queue][:extension].to_s.strip!

    errors = 0
    params[:queue][:join_announcement] = 0 if params[:queue][:join_announcement].to_i == -1
    params[:queue][:moh_id] = 0 if params[:queue][:moh_id].to_i == -1
    params[:queue][:context] = 0 if params[:queue][:context].to_i == -1
    params[:queue][:maxlen] = 0 if params[:queue][:maxlen].to_i == 0
    params[:queue][:failover_data] = params[:s_device].to_i if params[:queue][:failover_action].to_s == 'device'
    params[:queue][:server_id] = Confline.get_value('Resellers_server_id') if reseller?
    did = Did.get_dids(current_user).where(did: params[:s_did_pattern].to_i).first

    if params[:queue][:failover_action].to_s == 'did'
      if did
        params[:queue][:failover_data] = did.id
      else
        params[:queue][:failover_data] = params[:s_did_pattern]
        errors += 1
      end
    end

    params[:queue][:joinempty] = params[:join_empty] ? params[:join_empty].join(',') : ''
    params[:queue][:leavewhenempty] = params[:leave_empty] ? params[:leave_empty].join(',') : ''

    @queue_old = @queue.dup
    @queue.attributes = params[:queue]
    @queue.valid?

    #checking for extension validation
    if extension_pbx_pool_exists?(params[:queue], @queue_old)
      @queue.errors.add(:extension_error, _('Extension_and_PBX_Pool_is_used'))
    end

    if !@queue.errors.any? and errors == 0 and @queue.update_attributes(params[:queue])
      dial_plan = Dialplan.where(name: @queue_old.name, dptype: 'queue', data1: @queue.id, data2: @queue_old.extension).first
      recreate_extlines(dial_plan.id, @queue, @queue_old)
      dial_plan.data2 = params[:queue][:extension].to_s if params[:queue][:extension]
      dial_plan.data6 = @queue.try(:pbx_pool_id).to_i
      dial_plan.name = params[:queue][:name].to_s if params[:queue][:name]
      dial_plan.save

      reload_servers(get_servers_for_reload(ccl_active?, @queue.server_id))

      flash[:status] = _('Queue_Updated')
      redirect_to(action: :list) && (return false)
    else
      if params[:queue][:failover_action].to_s == 'did'
        if did.blank?
          @queue.errors.add(:did, _('Fail_Over_did_not_found'))
        end
      end

      @queue.attributes = params[:queue]
      @dialplan = Dialplan.where(data1: @queue.id).first
      @assigned_dids = Did.where(dialplan_id: @dialplan.id)

      show_servers_if_ccl_not_active(ccl_active?)

      @queue_strategies = %w[ringall roundrobin leastrecent fewestcalls random rrmemory wrandom linear rrordered]
      @users = User.select("id, username, first_name, last_name, usertype, #{SqlExport.nice_user_sql}").where("users.usertype = 'user' AND users.owner_id = #{corrected_user_id}").order('nice_user')

      if @queue.failover_action.to_s == "device"
        @device = Device.where(id: @queue.failover_data.to_i).first
        @user = @device.user
        @devices = Device.where(user_id: @user.id).all
      else
        @user = @users.first
        @devices = @user.devices
      end
      if @queue.failover_action.to_s == 'did'
        @did = Did.where(id: @queue.failover_data).first
      end
      @announcements = IvrSoundFile.select('id, path').all
      @static_agents = QueueAgent.where(queue_id: @queue.id).order('priority').all
      static_agents_exists = @static_agents.blank?

      agent_devices = static_agents_exists ? [] : Device.where("id in (#{@static_agents.map(&:device_id).join(',')})")
      @static_agent_users = @users.reject {|user| ((user.devices.blank? ? [] : user.devices.map(&:id)) - agent_devices.map(&:id)).blank?}
      @static_agent_user_devices = @static_agent_users.first ? @static_agent_users.first.devices : []
      @static_agent_devices = static_agents_exists ? (@static_agent_user_devices ? @static_agent_user_devices : []) : (@static_agent_user_devices.reject { |device| @static_agents.map(&:device_id).member?(device.id) })
      @mohs = Moh.all
      @ivrs = Ivr.all
      @join_leave_empty = ['paused','penalty','inuse','ringing','unavailable','invalid','unknown','wrapup']
      @periodic_announcements = QueuePeriodicAnnouncement.select("queue_periodic_announcements.id AS id,ivr_sound_files.path AS path").joins("LEFT JOIN ivr_sound_files ON (ivr_sound_files.id = queue_periodic_announcements.ivr_sound_files_id)").where(queue_id: @queue.id).order("priority").all

      # ===== Visualization =====

      if @queue.join_announcement.to_i == 0
        @vis_join_ann = 'none'
      else
        @vis_join_ann = IvrSoundFile.where(id: @queue.join_announcement.to_i).first.try(:path) || ""
      end
      moh = Moh.select("ivr_sound_files.path AS path").joins("LEFT JOIN ivr_sound_files ON (ivr_sound_files.ivr_voice_id = mohs.ivr_voice_id)").where(id: @queue.moh_id).first
      group_name = Moh.select('mohs.moh_name AS name').joins("LEFT JOIN ivr_sound_files ON (ivr_sound_files.ivr_voice_id = mohs.ivr_voice_id)").where(id: @queue.moh_id).first
      @vis_moh = group_name.blank? ? 'default' : group_name.name.to_s
      fail_over_action = @queue.failover_action.to_s

      if fail_over_action == 'hangup'
        @vis_fail_over = _('Hangup')
      elsif fail_over_action == 'extension'
        @vis_fail_over = _('Transfer_to_extension') + ": " + @queue.failover_data.to_s
      elsif fail_over_action == 'did'
        d = Did.where(id: @queue.failover_data.to_i).first
        @vis_fail_over = _('Transfer_to_DID') + ": " + (d ? d.did : "")
      elsif fail_over_action == 'device'
        dev = Device.where(id: @queue.failover_data.to_i).first
        device_name = dev.name
        device_type = dev.device_type
        d = device_type + '/'
        d += device_name if device_type != 'FAX'
        d += dev.extension if device_type == 'FAX' || device_name.length == 0
        @vis_fail_over = _('Transfer_to_device') + ': ' + d
      end

      ivr = Ivr.where(id: @queue.context.to_i).first
      @vis_ivr = ivr.blank? ? 'none' : ivr.name.to_s
      flash_errors_for(_('Queue_was_not_updated'), @queue)
      render action: 'edit', id: @queue.id
    end
  end

  def destroy
    if @queue.destroy_all
      flash[:status] = _('Queue_deleted')
    else
      flash_errors_for(_('Queue_was_not_deleted'), @queue)
    end
    redirect_to action: :list
  end

  def get_user_devices
    @devices = Device.where(user_id: params[:user_id]).all
    render layout: false
  end

  def agent_get_user_devices
    @agents = QueueAgent.where(queue_id: params[:queue_id])
    @static_agent_user_devices = Device.where(user_id: params[:user_id])
    @static_agent_devices = @agents.blank? ? (@static_agent_user_devices ? @static_agent_user_devices : []) : (@static_agent_user_devices.reject { |dev| @agents.map(&:device_id).member?(dev.id) })
    render layout: false
  end

  def agent_get_users
    @users = User.select("id, username, first_name, last_name, usertype, #{SqlExport.nice_user_sql}").where("users.usertype = 'user' AND users.owner_id = #{corrected_user_id}").order("nice_user")
    @agents = QueueAgent.where(queue_id: params[:queue_id])
    agent_devices = @agents.blank? ? [] : Device.where("id in (#{@agents.map(&:device_id).join(',')})")
    @static_agent_users = @users.reject {|user| ((user.devices.blank? ? [] : user.devices.map(&:id)) - agent_devices.map(&:id)).blank?}
    render layout: false
  end

  def create_queue_agent

    last_agent = QueueAgent.where(queue_id: params[:queue_id].to_i).order('priority DESC').first

    @agent = QueueAgent.new({
        agent_name: params[:agent_name].to_s,
        queue_id: params[:queue_id].to_i,
        device_id: params[:device_id].to_i,
        penalty: params[:penalty].to_i,
        priority: (last_agent.present? ? last_agent.priority.to_i + 1 : 1) ,
        paused: 0
    })
    if @agent.save
      @queue = AstQueue.where(id: params[:queue_id]).first
      @static_agents = QueueAgent.where(queue_id: @queue.id).order('priority').all
    end

    render partial: 'queue_agents', locals: {static_agents: @static_agents, queue: @queue}, layout: false and return false
  end

  def change_position
    @queue_agent = QueueAgent.where(id: params[:agent_id]).first
    @queue_agent.move_queue_agent(params[:direction])
    @queue = AstQueue.where(id: params[:queue_id]).first
    @static_agents = QueueAgent.where(queue_id: @queue_agent.queue_id).order('priority').all
    render partial: 'queue_agents', locals: {static_agents: @static_agents, queue: @queue}, layout: false
  end

  def edit_queue_agent
    sql = "UPDATE queue_agents SET penalty = #{params[:penalty].to_i} WHERE id = #{params[:agent_id]};"
    ActiveRecord::Base.connection.update(sql)
    render text: ''
  end

  def delete_queue_agent
    @queue_agent = QueueAgent.where(id: params[:agent_id]).first
    QueueAgent.destroy(params[:agent_id].to_i)
    @queue = AstQueue.where(id: params[:queue_id]).first
    @static_agents = QueueAgent.where(queue_id: @queue_agent.queue_id).order('priority').all
    render partial: 'queue_agents', locals: {static_agents: @static_agents, queue: @queue}, layout: false
  end

  def change_announcement_position
    @queue_announcement = QueuePeriodicAnnouncement.where(id: params[:id]).first
    @queue_announcement.move_announcement(params[:direction])
    @queue = AstQueue.where(id: params[:queue_id]).first
    @periodic_announcements = QueuePeriodicAnnouncement.select('queue_periodic_announcements.id AS id,ivr_sound_files.path AS path').joins('LEFT JOIN ivr_sound_files ON (ivr_sound_files.id = queue_periodic_announcements.ivr_sound_files_id)').where(queue_id: @queue.id).order('priority').all
    render partial: 'queue_announcements', locals: { queue: @queue, periodic_announcements: @periodic_announcements }, layout: false
  end

  def create_new_announcement
    last_announcement = QueuePeriodicAnnouncement.where(queue_id: params[:queue_id].to_i).order('priority DESC').first

    @announcement = QueuePeriodicAnnouncement.new({
        queue_id: params[:queue_id].to_i,
        ivr_sound_files_id: params[:ivr_sound_file_id].to_i,
        priority: (last_announcement.present? ? last_announcement.priority.to_i + 1 : 1)
    })
    if @announcement.save
      @queue = AstQueue.where(id: params[:queue_id]).first
      @periodic_announcements = QueuePeriodicAnnouncement.select("queue_periodic_announcements.id AS id,ivr_sound_files.path AS path").joins("LEFT JOIN ivr_sound_files ON (ivr_sound_files.id = queue_periodic_announcements.ivr_sound_files_id)").where(queue_id: @queue.id).order("priority").all
    end
    render partial: "queue_announcements", locals: { queue: @queue, periodic_announcements: @periodic_announcements }, layout: false
  end

  def delete_queue_announcement
    @queue_announcement = QueuePeriodicAnnouncement.where(id: params[:id].to_i).first
    QueuePeriodicAnnouncement.delete(params[:id].to_i)
    @queue = AstQueue.where(id: params[:queue_id]).first
    @periodic_announcements = QueuePeriodicAnnouncement.select("queue_periodic_announcements.id AS id,ivr_sound_files.path AS path").joins("LEFT JOIN ivr_sound_files ON (ivr_sound_files.id = queue_periodic_announcements.ivr_sound_files_id)").where(queue_id: @queue.id).order("priority").all
    render partial: 'queue_announcements', locals: { queue: @queue, periodic_announcements: @periodic_announcements }, layout: false
  end

  def get_static_agents_map

    user_str = params[:livesearch].to_s

    static_agent_users = User.select("users.id, users.username, users.first_name, users.last_name, users.usertype, #{SqlExport.nice_user_sql}").
                              joins("INNER JOIN devices ON devices.user_id = users.id LEFT JOIN queue_agents ON queue_agents.device_id = devices.id AND queue_id = #{params[:options][:queue_id].to_i}").
                              where("queue_agents.device_id IS NULL AND users.usertype = 'user' AND users.owner_id = #{corrected_user_id} #{Application.find_like_user_sql(user_str)} ")

    static_agent_count = static_agent_users.count('DISTINCT users.id')

    static_agent_users = static_agent_users.order('nice_user').group('users.id')

    output = Application.seek_by_filter_sql(static_agent_users, static_agent_count, params[:empty_click].to_s, user_str)

    render(text: output)
  end

  private

  def queues_order_by(options)
    order_by =  case options[:order_by].to_s.strip
                when 'name'
                  'queues.name'
                when 'extension'
                  'queues.extension'
                when 'pbx_name'
                  'pbx_name'
                when 'strategy'
                  'queues.strategy'
                else
                  options[:order_by]
                end

    if order_by.present?
      order_by << (options[:order_desc].to_i == 0 ? ' ASC' : ' DESC')
    end

    order_by
  end

  def find_queue
    @queue = AstQueue.where(id: params[:id].to_i).first

    if @queue.blank?
      flash[:notice]=_('Queue_was_not_found')
      (redirect_to :root) && (return false)
    elsif @queue.owner_id != corrected_user_id
      dont_be_so_smart
      redirect_to action: :list
      return false
    end
  end
  def check_pbx_addon
    if !pbx_active?
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      (redirect_to :root) && (return false)
    end
  end

  def show_servers_if_ccl_not_active(ccl_active)
    @ccl_active = ccl_active

    unless ccl_active
      @servers = Server.where(server_type: 'asterisk').order('id ASC').all
    end
  end

  def recreate_extlines(dialplan_id, queue, queue_old)
    ast_queue_id = queue.id
    extension = queue.extension
    old_extension = queue_old.extension
    Extline.delete_all(exten: old_extension, appdata: "MOR_DP_ID=#{dialplan_id}")
    Extline.delete_all(exten: old_extension, appdata: "mor_queues,queue#{ast_queue_id}, 1")

    context = queue.pbx_pool_id == 1 ? 'mor_local' : "pool_#{queue.pbx_pool_id}_mor_local"
    app = 'Set'
    appdata = "MOR_DP_ID=#{dialplan_id}"
    Extline.mcreate(context, "1", app, appdata, extension, '0')

    app = 'Goto'
    appdata = "mor_queues,queue#{ast_queue_id}, 1"
    Extline.mcreate(context, '2', app, appdata, extension, '0')
  end

  def extension_pbx_pool_exists?(queue, queue_old = nil)
    extension, pbx_pool_id = queue[:extension].to_s, queue[:pbx_pool_id].to_i
    old_extension, old_pbx_pool_id = [queue_old.extension, queue_old.pbx_pool_id] if queue_old

    # Extension and PBX Pool have not changed in update, all good
    return false if queue_old && extension == old_extension && pbx_pool_id == old_pbx_pool_id

    # If new Extension and PBX Pool are not unique, not good
    context = pbx_pool_id == 1 ? 'mor_local' : "pool_#{pbx_pool_id}_mor_local"
    return true if Extline.where(context: context, exten: extension).first

    return false
  end

  def check_reseller
    dont_be_so_smart && (redirect_to :root) if reseller_not_pro?
  end

  def check_pbx_addon
    unless pbx_active?
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      (redirect_to :root) && (return false)
    end
  end
end
