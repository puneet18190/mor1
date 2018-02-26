# -*- encoding : utf-8 -*-
# Cron Actions.
class CronActionsController < ApplicationController
  layout 'callc'

  before_filter :check_post_method, only: [:destroy, :create, :update]
  before_filter :check_localization
  before_filter :authorize, if: -> { !(admin? || reseller?) }
  before_filter :find_setting, only: [:edit, :update, :destroy]

  def index
    @page_title, @page_icon, @help_link =
        _('Cron_settings'), 'clock.png', 'http://wiki.kolmisoft.com/index.php/Cron_actions'

    @cron_settings = current_user.cron_settings.all
  end

  def new
    @page_title, @page_icon, @help_link =
        _('New_Cron_setting'), 'clock.png', 'http://wiki.kolmisoft.com/index.php/Cron_actions'

    time_now = Time.now
    @cron_setting = CronSetting.new({user_id: current_user_id, valid_from: time_now, valid_till: time_now})
    find_data_for_cron
  end

  def create
    cron_params = params[:cron_setting]
    params[:cron_setting][:repeat_forever] = '0' if cron_params[:periodic_type] == '0'
    @cron_setting, lcr = cron_setting_lcr(params, :create)
    if cron_params[:action] == 'change_LCR' && lcr.blank?
      flash_errors_for(_('Lcr_was_not_found'), @cron_setting)
      find_data_for_cron
      render(:new) && (return false)
    end

    if @cron_setting.save
      flash[:status] = _('Setting_saved')
      redirect_to(action: :index)
    else
      flash_errors_for(_('Setting_not_created'), @cron_setting)
      find_data_for_cron
      render(:new)
    end
  end

  def edit
    @page_title, @page_icon, @help_link =
        _('Edit_Cron_Setting'), 'clock.png', 'http://wiki.kolmisoft.com/index.php/Cron_actions'

    find_data_for_cron
  end

  def update
    @cron_setting, lcr = cron_setting_lcr(params, :update)

    if params[:cron_setting][:action] == 'change_LCR' && lcr.blank?
      flash_errors_for(_('Lcr_was_not_found'), @cron_setting)
      find_data_for_cron
      render(:edit) && (return false)
    end

    if @cron_setting.save
      flash[:status] = _('Setting_updated')
      redirect_to(action: :index)
    else
      flash_errors_for(_('Setting_not_updated'), @cron_setting)
      find_data_for_cron
      render(:edit)
    end
  end

  def destroy
    @cron_setting.destroy
    flash[:status] = _('Setting_deleted')
    redirect_to(action: :index)
  end

  private

  def find_setting
    @cron_setting = current_user.cron_settings.where(id: params[:id]).first
    unless @cron_setting
      flash[:notice] =_('Setting_not_found')
      redirect_to(action: :index)
    end
  end

  def find_data_for_cron
    @options = {}
    @data = {
        tariffs: current_user.load_tariffs,
        users: User.find_all_for_select(current_user_id),
        providers: Provider.where(user_id: current_user_id).order('name ASC').all,
        provider_tariffs: Tariff.where(purpose: 'provider', owner_id: current_user_id).order('name ASC').all,
        lcrs: Lcr.where(user_id: current_user_id).order('name ASC').all,
        email_sending_disabled: Confline.get_value('Email_Sending_Enabled').to_i.zero?
    }
    @options[:currencies] = Currency.get_active.map(&:name)
    @options[:default_currency] = User.current.currency.try(:name)
  end

  def cron_setting_lcr(params, action)
    params_cron_setting, activation_start, activation_end =
        params[:cron_setting], params[:activation_start], params[:activation_end]

    case action
      when :create
        @cron_setting = CronSetting.new(params_cron_setting.merge!({user_id: current_user_id}))
      when :update
        @cron_setting.update_attributes(params_cron_setting)
      else
        redirect_to(action: :index) && (return false)
    end

    @cron_setting.valid_from, @cron_setting.valid_till, lcr =
            current_user.system_time(Time.mktime(activation_start[:year],
                                                 activation_start[:month],
                                                 activation_start[:day],
                                                 activation_start[:hour],
                                                 '0', '0')
            ),
            current_user.system_time(Time.mktime(activation_end[:year],
                                                 activation_end[:month],
                                                 activation_end[:day],
                                                 activation_end[:hour],
                                                 '59', '59')
            ),
            Lcr.where("id = #{params_cron_setting[:lcr_id].to_i} and user_id = #{current_user_id}").first

    return @cron_setting, lcr
  end
end
