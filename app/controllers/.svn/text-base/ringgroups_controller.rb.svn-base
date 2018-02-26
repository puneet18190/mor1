# -*- encoding : utf-8 -*-
# Ringgroup - Collection of Asterisk extensions.
class RinggroupsController < ApplicationController
  layout 'callc'

  before_filter :check_post_method, only:  [:destroy, :create, :update]

  before_filter :check_localization
  before_filter :authorize
  before_filter :find_ringgroup, only: [
      :edit, :destroy, :assign_device, :show_dids, :show_devices, :show_extlines, :device_sort, :update,
      :free_user_devices, :delete_device
  ]
  before_filter :check_pbx_addon, only: [:index, :new, :edit]

  def index
    @page_title = _('Ring_groups')
    @options = session[:ringgroups_list_options] || {}

    # Search
    @options[:page] = if params[:page]
                        params[:page].to_i
                      elsif !@options[:page]
                        1
                      else
                        @options[:page]
                      end

    # Order
    @options[:order_by] = if params[:order_by]
                              params[:order_by].to_s
                            elsif !@options[:order_by]
                              'acc'
                            else
                              @options[:order_by]
                            end

    @options[:order_desc] = if params[:order_desc]
                              params[:order_desc].to_i
                            elsif !@options[:order_desc]
                              0
                            else
                              @options[:order_desc]
                            end

    order_by = current_user.ringgroups.ringgroups_order_by(@options)

    fpage, @total_pages, @options = Application.pages_validator(session, @options, current_user.ringgroups.all.size.to_i)

    @ringgroups = current_user.ringgroups.joins('LEFT JOIN dialplans ON dialplans.data1 = ringgroups.id').
        where("dialplans.dptype = 'ringgroup'").order(order_by).limit("#{fpage}, #{session[:items_per_page].to_i}").all

    session[:ringgroups_list_options] = @options
  end

  def new
    @page_title = _('Ring_group_new')
    @page_icon = 'add.png'
    @ringgroup = Ringgroup.new
    @ringgroup[:timeout] = 60
    @dialplan = Dialplan.new
    @pbx_pool_dropdown = PbxPool.where(owner_id: corrected_user_id).order(:name).all
    @dids = current_user.dids_for_select('assigned')
  end

  def create
    # check if extension entered
    ext = params[:dialplan][:data2]
    params[:ringgroup_temp_did] = params[:ringgroup][:did_id]
    params[:ringgroup][:did_id] = Did.where(['did = ?', params[:ringgroup][:did_id]]).first.id rescue 0
    @ringgroup = Ringgroup.new(params[:ringgroup].merge({ :name => params[:dialplan][:name] }))

    @dialplan = Dialplan.new(params[:dialplan].merge({ :dptype => "ringgroup", data6: params[:ringgroup][:pbx_pools_id] }))
    @pbx_pool_dropdown = PbxPool.where(owner_id: corrected_user_id).order(:name).all

    if !ext || ext.length == 0
      @ringgroup.errors.add(:extension, _('Enter_extension'))
    end

    # check if such extension exist
    if params[:dialplan][:data2] && !Ringgroup.is_extension_valid?(params[:ringgroup][:pbx_pools_id], ext)
      @ringgroup.errors.add(:extension, _('Extension_and_PBX_Pool_is_used'))
    end

    if !params[:dialplan] || params[:dialplan][:name].blank?
      @ringgroup.errors.add(:extension, _('Name_cannot_be_blank'))
    end

    if @ringgroup.errors.empty? && @ringgroup.save
      @dialplan.data1 = @ringgroup.id
      @dialplan.save
      @ringgroup.update_exline(ext)
      flash[:status] = _('Ring_Group_was_successfully_created')
      redirect_to :action => :edit, :id => @ringgroup.id
    else
      @page_title = _('Ring_group_new')
      @page_icon = "add.png"
      @dids = current_user.dids_for_select('assigned')
      flash_errors_for(_('Ring_Group_not_created'), @ringgroup)
      (render :new) && (return false)
    end
  end

  def edit
    @page_title = _('Ring_group_edit')
    @page_icon = "edit.png"

    @dids = current_user.dids_for_select('assigned')
    @free_dids = Did.free_dids_for_select(@ringgroup.did_id)
    @devices = @ringgroup.devices
    @dialplan = @ringgroup.dialplan
    @pbx_pool_dropdown = PbxPool.where(owner_id: corrected_user_id).order(:name).all
    @extlines = Extline.where(['exten = ? AND app IN ("Set", "Dial", "Goto")', @dialplan.data2]).order("priority ASC")
  end

  def update
    params[:ringgroup][:did_id] = Did.where(['did = ?', params[:ringgroup][:did_id]]).first.id rescue 0

    if !params[:dialplan] or params[:dialplan][:name].blank?
      @ringgroup.errors.add(:name, _('Name_cannot_be_blank'))
      @ringgroup.attributes = params[:ringgroup].reject{|key,value| key == 'user_id'}
    end

    @dialplan = @ringgroup.dialplan

    ext = params[:dialplan][:data2]

    if !ext || ext.to_s.strip.length == 0
      @ringgroup.errors.add(:extension, _('Enter_extension'))
    elsif ext && !Ringgroup.is_extension_valid?(params[:ringgroup][:pbx_pools_id], ext, @dialplan.try(:data2), @ringgroup.try(:pbx_pools_id))
      @ringgroup.errors.add(:extension_error, _('Extension_and_PBX_Pool_is_used'))
    end

    old_ext = @dialplan.try(:data2)
    old_id = @ringgroup.try(:pbx_pools_id)

    if @ringgroup.errors.empty? && @ringgroup.update_attributes(params[:ringgroup].reject{|key,value| key == 'user_id'})
      ext = @dialplan.data2.to_s
      @dialplan.update_attributes(params[:dialplan].merge({data6: params[:ringgroup][:pbx_pools_id]}))
      @ringgroup.update_exline(ext, old_ext, old_id)
      flash[:status] = _('Ring_Group_was_successfully_updated')
      redirect_to :action=>:index
    else
      @page_title = _('Ring_group_edit')
      @page_icon = "edit.png"

      @dids = current_user.dids_for_select('assigned')
      @free_dids = Did.free_dids_for_select(@ringgroup.did_id)
      @devices = @ringgroup.devices
      @dialplan = @ringgroup.dialplan
      @extlines = Extline.where(['exten = ? AND app IN ("Set", "Dial", "Goto")', @dialplan.data2]).order("priority ASC")
      @pbx_pool_dropdown = PbxPool.where(owner_id: corrected_user_id).order(:name).all
      flash_errors_for(_('Ring_Group_not_updated'), @ringgroup)
      (render :edit) && (return false)
    end
  end

  def destroy
    if @ringgroup.destroy
      flash[:status] = _('Ring_Group_was_successfully_deleted')
    else
      flash_errors_for(_('Ring_Group_not_deleted'), @ringgroup)
    end

    redirect_to(action: :index)
  end

  def assign_device
    params_device_id = params[:device_id].to_i
    ringgroup_id = @ringgroup.id
    if RinggroupsDevice.where(device_id: params_device_id, ringgroup_id: ringgroup_id).first.blank?
      if Callflow.where(device_id: params_device_id, cf_type: 'before_call', action: 'fax_detect').first.blank?
        r = RinggroupsDevice.new(device_id: params_device_id, ringgroup_id: ringgroup_id)
        r_old = RinggroupsDevice.where(ringgroup_id: ringgroup_id).order('priority DESC').first
        r.priority = r_old ? r_old.priority.to_i + 1 : 0
        r.save
      else
        flash[:notice] = _('Fax_Detect_Device_cannot_be_use_in_Ring_Group')
      end
      @ringgroup.update_exline
    end
    @devices = @ringgroup.devices
    @users = User.all
    render layout: false
  end

  def delete_device
    r = RinggroupsDevice.where({ :device_id => params[:device_id].to_i, :ringgroup_id => @ringgroup.id }).first
    r.destroy if r
    @ringgroup.update_exline
    @devices = @ringgroup.devices
    @users = User.all
    render :layout => false
  end

  def device_sort
    ringgroup_id = @ringgroup.id
    params[:sortable_list].each_index do |index|
      item = RinggroupsDevice.where(device_id: params[:sortable_list][index], ringgroup_id: ringgroup_id).first
      item.update_attributes(priority: index)
    end
    @devices, @users, @dids, @free_dids, @dialplan, @extlines = @ringgroup.device_sort_variables(current_user)
    @pbx_pool_dropdown = PbxPool.where(owner_id: corrected_user_id).order(:name).all
    render layout: false, action: :edit, id: ringgroup_id
  end

  def free_user_devices
    @free_devices = @ringgroup.free_devices(params[:user_id].to_i)
    render :layout => false
  end

  def show_dids
    @dialplan = @ringgroup.dialplan
    render :layout => false
  end

  def show_devices
    @devices = @ringgroup.devices
    render :layout => false
  end

  def show_extlines
    devices = @ringgroup.devices
    appdata = ''
    if devices
      devices.each_with_index do |device, index|
        device_name, device_type = device.name, device.device_type.to_s
        index_more_than_zero = index > 0
        if device_type == 'Virtual'
          if index_more_than_zero
            appdata += "&Local/#{device_name}@mor_local"
          else
            appdata += "Local/#{device_name}@mor_local"
          end
        else
          if index_more_than_zero
            appdata += "&#{device_type}/#{device_name}"
          else
            appdata += "#{device_type}/#{device_name}"
          end
        end
      end
    end

    appdata += "|#{params[:timeout]}|#{params[:options]}"
    @set, @dial, @goto = ''
    @set = "exten => #{params[:exten]},1,Set(CALLERID(NAME) = \"#{params[:prefix]}\"+${CALLERID(NAME)})" if !params[:prefix].blank?
    @dial = "exten => #{params[:exten]},2,Dial(#{appdata})"
    @goto = "exten => #{params[:exten]},3,Goto(mor|#{params[:did]}|1)" if params[:did].to_i > 0
    render :layout => false
  end

  private

  def find_ringgroup
    @ringgroup = current_user.ringgroups.where({ :id => params[:id] }).includes([:dialplan]).first
    unless @ringgroup
      flash[:notice] = _('Ringgroup_was_not_found')
      (redirect_to :controller => "ringgroups") && (return false)
    end
  end

  def check_pbx_addon
    unless pbx_active?
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      (redirect_to :root) && (return false)
    end
  end
end
