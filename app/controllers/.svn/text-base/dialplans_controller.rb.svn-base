# -*- encoding : utf-8 -*-
# Dial Plans managing.
class DialplansController < ApplicationController
  layout 'callc'
  before_filter :check_post_method, :only => [:destroy, :create, :update, :did_assign_to_dp]
  before_filter :access_denied, only: [:dialplans, :edit, :update, :new, :create, :destroy], if: -> { !current_user.try(:load_dids).present? && User.current.try(:owner).try(:is_partner?) }
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_dialplan, :only => [:list_extlines, :edit, :update, :destroy, :did_assign_to_dp, :regenerate_dialplan]
  before_filter :find_default_create_values, only: [:new]
  before_filter :check_reseller_pbx_addon_permissions, only: [:list_extlines, :edit, :create, :update, :destroy]
  before_filter :find_did, only: [:did_assign_to_dp]

  @@CC_End_ivr = ['End IVR #1', 'End IVR #2', 'End IVR #3', 'End IVR #4', 'End IVR #5', 'End IVR #6', 'End IVR #7', 'End IVR #8', 'End IVR #9', 'End IVR #10']
  @@ANI_End_ivr = ['End IVR #1', 'End IVR #2', 'End IVR #3']

  def dialplans
    @page_title = _('Dial_Plans')

    @ccdps = []
    @ccdps = current_user.dialplans.select('dialplans.*, ivrs.name AS balance_ivr').joins('LEFT JOIN ivrs ON dialplans.data12 = ivrs.id').where("dptype = 'callingcard'").order('name ASC')

    @abpdps = Dialplan.where(["dptype = 'authbypin' AND user_id = ?", current_user_id]).order("name ASC") #  find(:all, :conditions => "dptype = 'authbypin'", :order => "name ASC")

    if callback_active?
      @cbdps = Dialplan.where(["dptype = 'callback' AND user_id = ?", current_user_id]).order("name ASC") #find(:all, :conditions => "dptype = 'callback'", :order => "name ASC") if callback_active?
    else
      @cbdps = Dialplan.where(["dptype = 'callback' AND user_id = ?", current_user_id]).order("name ASC").limit(1)
    end

    @ivr_dialplans = Dialplan.where(["dptype = 'ivr' AND user_id = ?", current_user_id]).order("name ASC") # find(:all, :conditions => "dptype = 'ivr'", :order => "name ASC")
    @cc_end_ivr = @@CC_End_ivr
    @ani_end_ivr = @@ANI_End_ivr

    @quickforward_dialplans = current_user.dialplans.select("dialplans.*, users.username AS user_name, devices.username AS device_name, devices.device_type").joins("LEFT JOIN devices ON dialplans.data3 = devices.id LEFT JOIN users ON users.id = devices.user_id").where("dptype = 'quickforwarddids' and dialplans.id != 1").order("dialplans.name ASC")
  end

  def list_extlines
    @page_title = _('Extlines')
    @page_icon = "asterisk.png"

    @extlines = Extline.where("exten = 'dialplan#{@dp.id}'").order("exten ASC, priority ASC")

    @ivr1, @ivr2, @ivr3, @ivr4 = @dp.list_extlines_ivrs

    @ivr1_blocks = @ivr1.ivr_blocks if @ivr1
    @ivr2_blocks = @ivr2.ivr_blocks if @ivr2
    @ivr3_blocks = @ivr3.ivr_blocks if @ivr3
    @ivr4_blocks = @ivr4.ivr_blocks if @ivr4
  end

  def edit
    @page_title = _('Dial_Plan_edit')
    @page_icon = "edit.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Calling_Card_Dial_Plan"

    check_pbx_addon(@dp.dptype)
#    @cbdids = Did.find_by_sql("SELECT dids.* FROM dids JOIN dialplans ON (dids.dialplan_id = dialplans.id) WHERE dialplans.dptype != 'callback' AND reseller_id = #{current_user.id}")
    @cbdids = Did.where(["dialplans.dptype != 'callback' AND reseller_id = ?", current_user.id]).joins("INNER JOIN dialplans ON (dids.dialplan_id = dialplans.id)")
    @allow_add_cbdid = ((@dp.dids.size < 1) or callback_active?)
    @cardgroups = Cardgroup.find_by_sql("SELECT cardgroups.id, cardgroups.number_length, cardgroups.pin_length FROM cardgroups WHERE owner_id = #{current_user.id} AND hidden = 0 group by number_length , pin_length ")
    if @dp.dptype == "ivr"
      @dialplan = @dp
      @ivrs = Ivr.where('user_id = ? OR all_users_can_use = 1', current_user.id).order('name ASC')
      @timeperiods = current_user.ivr_timeperiods.order('name ASC').all
      @help_link = "http://wiki.kolmisoft.com/index.php/IVR_system"
    end

    if @dp.dptype == 'callback'
      @free_dids = Did.where(['status = "free" AND reseller_id = ?', current_user.id]).order('did ASC')
      @help_link = "http://wiki.kolmisoft.com/index.php/Callback"
      @initial_device = Device.where(id: @dp.data3.to_i).first
      @initial_device_user = User.where(id: @initial_device.try(:user_id)).first
    end
    if @dp.dptype == 'authbypin'

      if params[:users_device].present?
        @selected_device = Device.where(:id => params[:users_device].to_i).first
        @devices = Device.where(:user_id => @selected_device.user_id).all
        device_used = Device.where(:id => @dp.data5.to_i).first
        @user_id = device_used.user_id
      elsif @dp.data5.blank?
        @user_id = ""
        @devices = []
      else
        @selected_device = Device.where(:id => @dp.data5.to_i).first
        @devices = Device.where(:user_id => @selected_device.user_id).all
        @user_id = @selected_device.user_id
      end
      @selected_device_id = @selected_device.try(:id)
      if @user_id.present?
        @s_user = User.select("#{SqlExport.nice_user_sql}").where(id: @user_id).first[:nice_user]
        @s_user_id = @selected_user_id
      else
        @s_user = params[:s_plan_user] || ''
        @s_user_id = params[:s_plan_user_id] || -2
      end

      @cc_dialplans = Dialplan.where({:dptype => 'callingcard', :user_id => current_user.get_corrected_owner_id})
    end
    if @dp.dptype == 'callingcard'
      @balance_ivrs = Ivr.where('user_id = ? OR all_users_can_use = 1', current_user.id).order('name ASC')
    end

    if @dp.dptype == 'quickforwarddids'
      if params[:quickforwards_device].present?
        @selected_device = Device.select('users.id user_id, devices.id device_id').joins("JOIN users ON users.id = devices.user_id").where("users.owner_id = #{current_user.id} AND devices.id = #{params[:quickforwards_device].to_i}").first
        @devices = Device.where(:user_id => @selected_device.user_id).all
        @selected_user_id = @selected_device.user_id
        @selected_device_id = params[:quickforwards_device].to_i
      elsif @dp.data3.to_s.length > 0 and @selected_device = Device.select('users.id user_id, devices.id device_id').joins("JOIN users ON users.id = devices.user_id").where("users.owner_id = #{current_user.id} AND devices.id = #{@dp.data3.to_i}").first
        @devices = Device.where(:user_id => @selected_device.user_id).all
        @selected_user_id = @selected_device.user_id
        @selected_device_id = @selected_device.device_id
      else
        @devices = []
        @selected_user_id = ''
      end
      if @selected_user_id.present?
        @s_user = User.select("#{SqlExport.nice_user_sql}").where(id: @selected_user_id).first[:nice_user]
        @s_user_id = @selected_user_id
      else
        @s_user = (params[:s_quickforwards_user].present? && params[:s_quickforwards_user]) || ''
        @s_user_id = params[:s_quickforwards_user_id] || -2
      end

    end
    @cc_end_ivr = @@CC_End_ivr
    @ani_end_ivr = @@ANI_End_ivr
  end

  def dialplans_device_ajax
    @device_selected = params[:device_id].to_i
    @device = []
    if params[:id]
      @device = Device.where("user_id = '#{params[:id].to_s}' AND name NOT LIKE 'mor_server_%'").all
    end
    render :layout => false
  end

  def did_assign_to_dp
    add_action_second(User.current.id, 'did_assigned_to_dp', @did.id, @dp.id) if @did.assign_to_dp(@dp)
    @free_dids = Did.free_dids_for_select
    @ringgroup = params[:ringgroup].to_i
    render :layout => false
  end

  def update
    check_pbx_addon(@dp.dptype)
    unless params[:dialplan]
      flash[:notice] = _('Dont_Be_So_Smart')
      redirect_to :action => 'dialplans' and return false
    end

    if params[:dialplan][:name].length == 0
      flash[:notice] = _('Please_enter_name')
      redirect_to :action => 'edit', :id => @dp.id, params: params and return false
    end

    params[:s_user_id] ||= params[:s_plan_user_id] || params[:s_quickforwards_user_id] || ''

    # checking if selected user belongs to current user.
    if !params[:s_user_id].blank? and User.where(['id =  ? AND owner_id != ? AND ? != 0 ', params[:s_user_id], current_user.id, current_user.id]).first and !admin?
      flash[:notice] = _('Dont_be_so_smart')
      (redirect_to :root) && (return false)
    end

    # checking if selected device belongs to selected user.
    if params[:users_device].present? && (params[:s_user_id].blank? || (params[:s_user_id].present? && Device.where(['user_id = ? AND id = ?', params[:s_user_id].to_s, params[:users_device].to_s]).first.blank?))
      flash[:notice] = _('Dont_be_so_smart')
      (redirect_to :root) && (return false)
    end

    @dp.name = params[:dialplan][:name].to_s.strip
    @dp.fabricate(params)
    @dp.data3 = params[:s_device] if @dp.dptype == 'callback'

    if update_error = @dp.errors.get(:update)
      flash[:notice] = update_error.first
      redirect_to :action => 'dialplans', :id => @dp.id and return false
    end

    if @dp.save
      add_action(session[:user_id], 'dp_edited', @dp.id)

      if @dp.dptype == "ivr"
        @dp.regenerate_ivr_dialplan
      end

      flash[:status] = _('Dialplan_was_successfully_updated')
    else
      flash[:notice] = _('Dialplan_was_not_updated')
    end

    redirect_to :action => 'dialplans' and return false
  end

  def new
    @page_title = _('Dial_Plan_new')
    @page_icon = "add.png"
    @dp = Dialplan.new(:data2 => 5)

    # @cbdids = Did.find_by_sql("SELECT dids.* FROM dids JOIN dialplans ON (dids.dialplan_id = dialplans.id) WHERE dialplans.dptype != 'callback' AND dids.reseller_id = #{current_user.id}")
    @cbdids = Did.where(["dialplans.dptype != 'callback' AND reseller_id = ?", current_user_id]).joins("INNER JOIN dialplans ON (dids.dialplan_id = dialplans.id)")
    # Gathers unique CC number_length/pin_length combinations from active cardgroups, the DP is applied to all CC Groups with that combination.
    @cardgroups = Cardgroup.select('id, number_length, pin_length').where("owner_id = #{current_user.id} AND hidden = 0").group('number_length, pin_length').all

    @cc_dialplans = Dialplan.where(:dptype => 'callingcard', :user_id => current_user.get_corrected_owner_id)

    @cb_devices = Device.where(user_id: params[:s_user_id]) if params[:s_user_id]

    @allow_add_cbdp = ((Dialplan.where(dptype: 'callback', user_id: 'current_user.id').count < 1) or callback_active?)

    @balance_ivrs = @ivrs = Ivr.where('user_id = ? OR all_users_can_use = 1', current_user.id).order('name ASC')
    @timeperiods = current_user.ivr_timeperiods.order('name ASC').all

    @dp_data5 = 3
    @dp_data6 = 3
    @dp_data1 = 3
    @dp_data2 = 3
    @dp_data7 = false
    @cc_end_ivr = @@CC_End_ivr
    @ani_end_ivr = @@ANI_End_ivr
    @users_used = ""
  end

  def create
    allow_access = check_pbx_addon(params[:dialplan][:dptype])
    return false unless allow_access

    if !params[:dialplan] or params[:dialplan][:name].blank?
      flash[:notice] = _('Please_enter_name')
      redirect_to action: 'new', params: params and return false
    end
    params[:dialplan][:name]=params[:dialplan][:name].to_s.strip

    params[:dialplan][:data3] = params[:s_device] if params[:dialplan][:dptype] == 'callback'
    dp = Dialplan.new(params[:dialplan])

    params[:s_user_id] ||= params[:s_plan_user_id] || params[:s_quickforwards_user_id] || ''

    # checking if selected user belongs to current user.
    if !params[:s_user_id].blank? and User.where(['id =  ? AND owner_id != ? AND ? != 0 ', params[:s_user_id], current_user.id, current_user.id]).first and !admin?
      flash[:notice] = _('Dont_be_so_smart')
      (redirect_to :root) && (return false)
    end

    # checking if selected device belongs to selected user, or device selected without user.
    if params[:users_device].present? && (params[:s_user_id].blank? || (params[:s_user_id].present? && Device.where(['user_id = ? AND id = ?', params[:s_user_id].to_s, params[:users_device].to_s]).first.blank?))
      flash[:notice] = _('Dont_be_so_smart')
      (redirect_to :root) && (return false)
    end

    dp.fabricate(params)

    if update_error = dp.errors.get(:update)
      flash[:notice] = update_error.first
      redirect_to :action => 'dialplans' and return false
    end

    if dp.save
      if dp.dptype == "ivr"
        dp.regenerate_ivr_dialplan
      end
      add_action(session[:user_id], 'dp_created', dp.id)
      flash[:status] = _('Dialplan_was_successfully_created')
    else
      flash[:notice] = _('Dialplan_was_not_created')
    end

    redirect_to :action => 'dialplans' and return false
  end


  def destroy
    if @dp.destroy_all
      flash[:status] = _('Dialplan_deleted') + ": " + @dp.name
      add_action(session[:user_id], 'dp_deleted', @dp.id)
    else
      flash_errors_for('', @dp)
    end
    redirect_to :action => 'dialplans' and return false
  end

  def regenerate_dialplan
    @dp.regenerate_ivr_dialplan
    @dp.data8 = 0
    @dp.save
    redirect_to :action => "dialplans"
  end

  private

  def find_dialplan
    @dp = Dialplan.where({:id => params[:id]}).first
    unless @dp
      flash[:notice]=_('Dialplan_was_not_found')
      (redirect_to :root) && (return false)
    end

    unless @dp.user_id.to_i == current_user.id.to_i
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
  end

  def check_pbx_addon(dptype)
    if (dptype == 'ivr') && !pbx_active?
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
    return true
  end

  def find_default_create_values
    @s_user_id = params[:s_plan_user_id] || -2
    @s_user = params[:s_plan_user] || ''
    @s_quickforwards_user_id = params[:s_quickforwards_user_id] || -2
    @s_quickforwards_user = params[:s_quickforwards_user] || ''
    @selected_device_id = params[:users_device] || nil

    @devices = Device.where(user_id: @s_user_id) if @s_user_id.present?
    @quickforwards_devices = Device.where(user_id: @s_quickforwards_user_id) if @s_quickforwards_user_id.present?
  end

  def check_reseller_pbx_addon_permissions
    if @dp && (@dp.dptype == 'ivr') && reseller? && !current_user.reseller_allow_edit('pbx_functions')
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
    return true
  end

  def find_did
    @did = Did.where(:id => params[:did_id]).first
    unless @did
      flash[:notice]=_('Did_was_not_found')
      redirect_to :action => :dialplans and return false
    end
  end
end
