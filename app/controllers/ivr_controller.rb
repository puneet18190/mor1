# -*- encoding : utf-8 -*-
# MOR Interactive Voice Response.
class IvrController < ApplicationController
  layout 'callc'
  before_filter :check_post_method, only: [:destroy, :create, :update]
  before_filter :check_localization
  before_filter :authorize

  before_filter :find_ivr_action_silent, only: [:update_data1, :update_data2, :update_data3, :action_params]
  before_filter :find_ivr_block_silent, only: [:update_block_timeout_digits, :update_block_timeout_response, :update_block_name]
  before_filter :find_ivr, only: [:edit, :update_ivr_name, :destroy, :update_ivr_all_users_can_use]
  before_filter :find_ivr_block, only: [:add_ivr_extension, :ivr_extlines, :change_block, :add_block]
  before_filter :check_reseller
  before_filter :check_pbx_addon

  # Global variables. Defines possible choices for extensions and actions
  $pos_actions = [
      'Playback', 'Change Voice','Delay', 'Hangup', 'Transfer To', 'Debug', 'Set Accountcode',
      'Change CallerID (Number)', 'Action log', 'Random Play'
  ]
  $pos_extensions = %w(0 1 2 3 4 5 6 7 8 9 # * i t)
  $pos_variables = ['MOR_ASK_DST_TIMES']

  def settings
    @page_title = _('IVR_Settings')
    @page_icon = 'play.png'
  end

  def settings_change
    Confline.set_value('IVR_Voice_Dir', params[:voice_dir])
    redirect_to action: :settings
  end

  def index
    @page_title = _('IVRs')
    @page_icon = 'play.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/IVR_system'

    @total_ivrs = current_user.ivrs.size

    @options = {}

    @options[:page] = params[:page].to_i if params[:page].present?
    fpage, @total_pages, @options = Application.pages_validator(session, @options, @total_ivrs)

    session[:ivr_index] = @options[:page]

    @ivrs = current_user.ivrs.order('name ASC').offset(fpage).limit(session[:items_per_page].to_i).all
  end

  def new
    @page_title = _('New_IVR')
    @page_icon = 'add.png'
  end

  def create
    params_block_name = params[:block_name].to_s
    params_ivr_name = params[:ivr_name].to_s

    block_name = params_block_name.blank? ? 'New_Block' : params[:block_name]
    @block = IvrBlock.create(name: block_name)

    @ivr = Ivr.new
    @ivr.start_block = @block
    @ivr.name = params_ivr_name.blank? ? 'New_Ivr' : params[:ivr_name]

    if @ivr.save
      @block.update_by(@ivr)
      @block.save
      flash[:status] = _('IVR_Was_Created')
    else
      @block.destroy
      flash[:notice] = _('IVR_Was_Not_Created')
    end

    redirect_to action: :index
  end

  def edit
    @page_title = _('Edit_IVR')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/IVR_system'

    @ivr_voices = current_user.ivr_voices.first
    @ivr_sound_files = current_user.ivr_sound_files.first

    @block = @ivr.start_block
    @blocks = IvrBlock.includes([:ivr_extensions, :ivr_actions]).where(ivr_id: @ivr.id).all
    @extensions = @block.ivr_extensions
    @actions = @block.ivr_actions
  end

  # Sets default values for added and changed actions.
  #
  # Actions : <tt>['Playback', 'Delay', 'Change Voice', 'Hangup', 'Transfer To', 'Debug', 'Set Accountcode', 'Mor']</tt>
  # Variables: <tt>['MOR_DESTINATION']</tt>
  # <tt>params[:id]</tt> must be set to ID of an coresponding action.
  #
  # * *Playback*
  # Answer is performed before this action
  #
  # * *Delay*
  # * *Change* *Voice*
  # * *Hangup*
  # * *Transfer* *To*
  # * *Debug*
  # * *Set* *Accountcode*
  # <tt>data1</tt> - device name.
  #
  # * *Mor* - Sends user to MOR internal engine
  # Takes no params.
  #
  # * *Set* *Variable* - allows user to set some Asteris internal variable.
  # <tt>data1</tt> - variable name.
  # <tt>data2</tt> - variable value.

  def action_params
    @num = params[:action_name]
    @action.name = @num.to_s
    @action.clear_data_fields
    @action.update_action_data(current_user, $pos_variables[0])
    @action.save
    critical_update(@action)

    render(layout: false)
  end

  def update_block_name
    @name = params[:data].to_s

    if @name.present?
      @block.name = @name
      @block.save
    end

    render(nothing: true)
  end

  def update_ivr_name
    @name = params[:data].to_s

    if @ivr
      @ivr.name = @name if @name.present?
      @ivr.save
    end

    render(nothing: true) && (return false)
  end

  def update_ivr_all_users_can_use
    @all_users_can_use = params[:data] == 'null' ? 0 : 1

    if @ivr
      @ivr.all_users_can_use = @all_users_can_use.to_i if @ivr.all_users_can_use.to_i != @all_users_can_use.to_i
      @ivr.save
    end

    render(nothing: true) && (return false)
  end

  def update_block_timeout_digits
    @data = params[:data].to_i

    if @data >= 5
      @block.timeout_digits = @data
      @block.save
      critical_update(@block)
    end
  end

  def update_block_timeout_response
    @data = params[:data].to_i

    if @data >= 10
      @block.timeout_response = @data
      @block.save
      critical_update(@block)
    end
  end

  def update_data1
    @data = params[:data]
    @action.update_data_1(current_user, params)

    @action.save
    critical_update(@action)

    if @action.name == 'Transfer To' || @action.name == 'Playback'
      render(layout: false)
    else
      render(nothing: true) && (return false)
    end
  end

  def update_data2
    data = params[:data].to_s

    if @action && data.present?
      if @action.data1 == 'DID'
        d = Did.where(did: data).first
        @action.data2 = d.blank? ? '0' : data
      else
        @action.data2 = data
      end
      @action.save
      critical_update(@action)
    end

    render(nothing: true) && (return false)
  end

  def update_data3
    if @action && params[:data]
      @action.data3 = params[:data]
      @action.save
      critical_update(@action)
    end

    render(nothing: true) && (return false)
  end

  def extension_block
    @data, @ext, critical_update = Ivr.extension_block(params)
    critical_update(@ext) if critical_update == 1

    render(nothing: true) && (return false)
  end

  def add_ivr_action
    @ivr_voices = current_user.ivr_voices.first
    @ivr_sound_files = current_user.ivr_sound_files.first

    if params[:rm].to_s == 'true'
      @action = IvrAction.includes(:ivr_block).where("ivr_actions.id = #{params[:id]}").first
      @action.destroy if @action
    else
      @action = IvrAction.create(ivr_block_id: params[:block_id], name: 'Delay', data1: '0')
    end

    @actions = IvrAction.where(ivr_block_id: params[:block_id])

    if @action
      @block = @action.ivr_block
      critical_update(@block)
    end

    render(layout: false)
  end

  def add_ivr_extension
    @ivr = @block.ivr

    if params[:rm].to_s == 'true'
      ext = IvrExtension.where(id: params[:id]).first
      ext.destroy
    else
      ext = IvrExtension.new({ivr_block: @block, goto_ivr_block_id: @block.id, exten: $pos_extensions[0]})
      ext.save
    end

    @ivr_voices = current_user.ivr_voices.first
    @ivr_sound_files = current_user.ivr_sound_files.first

    @blocks = @ivr.ivr_blocks
    @extensions = @block.ivr_extensions
    critical_update(@block)

    render(layout: false)
  end

  def add_block
    if @block.blank?
      flash[:notice] = _('Block_Not_Found')
      render(partial: :redirect_home) && (return false)
    else
      @ivr = @block.ivr

      if params[:rm].to_s == 'true'
        block_id = @block.id
        if block_id != @ivr.start_block.id && IvrExtension.where(goto_ivr_block_id: block_id).where.not(ivr_block_id: block_id).blank?
          @block.destroy
          @block = @ivr.start_block
        end
      else
        new_block = IvrBlock.new(name: _('New_Block'), timeout_digits: 3, timeout_response: 10)
        new_block.ivr = @ivr
        new_block.save
        @block = new_block
      end

      @ivr_voices = current_user.ivr_voices.first
      @ivr_sound_files = current_user.ivr_sound_files.first
      @blocks = @ivr.ivr_blocks
      @extensions = @block.ivr_extensions
      @actions = @block.ivr_actions
      critical_update(@block)

      render(layout: false) && (return false)
    end
  end

  def refresh_edit_window
    # Reload servers to activate ivr changes - tmp workaround to activate ivr changes
    Server.where(server_type: 'asterisk').each { |server| server.ami_cmd('extensions reload') if server.active == 1 }

    unless (@block = IvrBlock.includes(:ivr).where(["ivr_blocks.id = ?", params[:block_id].gsub('=', '')]).first)
      flash[:notice] = _('Block_Not_Found')
      (redirect_to :root) && (return false)
    end

    @ivr_voices = current_user.ivr_voices.first
    @ivr_sound_files = current_user.ivr_sound_files.first

    @ivr = @block.ivr
    @blocks = @ivr.ivr_blocks
    @extensions = @block.ivr_extensions
    @actions = @block.ivr_actions

    render(layout: false, action: :add_block)
  end

  def change_block
    @ivr = @block.ivr
    @blocks = @ivr.ivr_blocks
    @extensions = @block.ivr_extensions
    @actions = @block.ivr_actions

    render(action: :add_block, layout: false)
  end

  def ivr_extlines
    @page_title = _('IVR_Extlines')
    @page_icon = 'asterisk.png'

    @extlines = Extline.where(context: "ivr_block#{params[:block_id]}")
  end

  def destroy
    notice = @ivr.validate_before_destroy
    ivr_id = @ivr.id

    if !@ivr.errors.blank?
      flash_errors_for(_('IVR_Was_Not_Deleted'), @ivr)
    elsif notice.blank? and !current_user.dialplans.where(["dptype = 'ivr' and (data2 = ? or data4 = ? or data6 = ? or data7 = ? )", ivr_id, ivr_id, ivr_id, ivr_id]).first and Adaction.where("data = ?", ivr_id).first.blank?
      @ivr.destroy
      flash[:status] = _('IVR_Deleted')
    else
      if notice.blank?
        flash[:notice] = _('IVR_Is_In_Use')
      else
        flash[:notice] = notice
      end
    end

    redirect_to(controller: :ivr, action: :index)
  end

  private

  # Is called when some value is changed and there is need to regenerate coresponding extlines.
  # object - IvrAction, IvrBlock, IvrExtension, IvrTimeperiod and of those objects are accepted as params.
  # Finds IvrBlock and regenerates Extlines for this block.

  def critical_update(object)
    object_id = object.id
    block = case object.class.to_s
            when 'IvrAction'
              object.ivr_block
            when 'IvrBlock'
              object
            when 'IvrExtension'
              object.ivr_block
            when 'IvrTimeperiod'
              plans = current_user.dialplans.where(["dptype = 'ivr' and (data1 = ? or data3 = ? or data5 = ?)", object_id, object_id, object_id])
              for plan in plans do
                plan.regenerate_ivr_dialplan
              end
              nil
            else
              nil
            end

    block.regenerate_extlines if block
  end

  def find_ivr_action_silent
    @action = IvrAction.where(id: params[:id]).first

    unless @action
      render(nothing: true) && (return false)
    end
  end

  def find_ivr_block_silent
    @block = IvrBlock.where(id: params[:id]).first

    unless @block
      render(nothing: true) && (return false)
    end
  end

  def find_ivr
    @ivr = current_user.ivrs.where(id: params[:id]).first

    unless @ivr
      flash[:notice] = _('IVR_Was_Not_Found')
      redirect_to(action: :index) && (return false)
    end
  end

  def find_ivr_block
    current_user_id = current_user.id.to_i
    @block = IvrBlock.where(id: params[:block_id]).first

    unless @block
      flash[:notice] = _('IVR_Block_Was_Not_Found')
      redirect_to(action: :index) && (return false)
    end

    if !@block.ivr || @block.ivr.user_id != current_user_id
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
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
