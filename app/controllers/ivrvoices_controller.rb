# -*- encoding : utf-8 -*-
# MOR Interactive Voice Response voices managing.
class IvrvoicesController < ApplicationController

  layout 'callc'
  before_filter :check_post_method, :only => [:destroy, :create, :update]
  before_filter :check_localization
  before_filter :authorize

  before_filter :find_ivr_voice, :only => [:update, :edit, :destroy]
  before_filter :check_reseller
  before_filter :check_sound_direction


  def index
    @page_title = _('IVR_Voices')
    @page_icon = "play.png"
    @voices = current_user.ivr_voices
  end

  def sound_files
    @page_title = _('IVR_sound_files')
    @page_icon = "play.png"
    @voices = current_user.ivr_voices
    @sounds = current_user.find_sound_files_for_ivrs
  end

  def new
    @page_title = _('New_IVR_Voice')
    @page_icon = "add.png"
  end

  def create
    ivr_voice = IvrVoice.new(params[:ivr])

    if ivr_voice.save
      flash[:status] = _('IVR_Voice_Created')
    else
      flash_errors_for(_('IVR_Voice_Not_Created'), ivr_voice)
    end
    redirect_to :action => :index and return false
  end

  def destroy

    if @voice.readonly.to_i == 1
      flash[:notice] = _('Dont_be_so_smart')
      redirect_to :action => :index and return false
    end
    voice = @voice.voice
    if !IvrAction.where("name = 'Change Voice' and data1 = '#{voice}'").first and !IvrAction.where("name = 'Playback' and data1 = '#{voice}'").first
      sounds = @voice.ivr_sound_files
      flag = true
      q = 0
      qa = 0
      for sound in sounds do
        queue = AstQueue.where("announce = #{sound.id} OR join_announcement = #{sound.id}").first
        queue_announcements = QueuePeriodicAnnouncement.where(:ivr_sound_files_id => sound.id).first
        if IvrAction.where("name = 'Playback' and data2 = '#{sound.path}'").first or !queue.blank? or !queue_announcements.blank?
          if !queue.blank?
            q += 1
          elsif !queue_announcements.blank?
            qa += 1
          end
          flag = false
        end
      end
      if flag
        @voice.destroy_with_file
        flash[:status] = _("IVR_Voice_Deleted")
      elsif q != 0
        notice = _("Can_Not_Delete_Some_Sound_File_Are_assigned_to_queues")
      elsif qa != 0
        notice = _("Can_Not_Delete_Some_Sound_File_Are_assigned_to_queues_announcement")
      else
        notice = _("Can_Not_Delete_Some_Sound_File_Are_In_Use")
      end
      unless notice.blank?
        flash[:notice] = notice
      end
    else
      flash[:notice] = _("Can_Not_Delete_Voice_Is_In_Use")
    end
    redirect_to :action => :index
  end

=begin
  Before filter variables: @voice
=end

  def edit
    @page_title = _('Edit_IVR_Voice')
    @page_icon = 'edit.png'
    @files = @voice.ivr_sound_files
  end

=begin
  Before filter variables: @voice
=end

  def update
    @voice.description = params[:voice][:description] if params[:voice]
    if @voice.save
      flash[:status] = _('IVR_Voice_Updated')
    else
      flash_errors_for(_('IVR_Voice_Not_Updated'), @voice)
    end
    redirect_to :action => :index
  end

  private

  def find_ivr_voice
    @voice = current_user.ivr_voices.where(["id = ?", params[:id]]).first if current_user
    unless @voice
      flash[:notice] = _("Ivr_Voice_Was_Not_Found")
      (redirect_to :root) && (return false)
    end
  end

  def check_reseller
    if reseller? && current_user && current_user.own_providers.to_i == 0
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
  end

  def check_sound_direction
    dir = Confline.get_value("IVR_Voice_Dir")
    if !File.directory?(dir)
      flash[:notice] = _("Cannot_access") + ": #{dir}"
      redirect_to :root
    end
  end

end
