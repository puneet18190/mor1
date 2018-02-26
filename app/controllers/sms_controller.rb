# -*- encoding : utf-8 -*-
# SMS Addon.
class SmsController < ApplicationController
  include UniversalHelpers
  layout :mobile_standard

  before_filter :authorize_for_sms_actions
  before_filter :check_post_method, only: [:destroy, :create, :update, :lcr_destroy, :lcr_create, :lcr_update,
    :provider_update, :provider_create, :provider_destroy, :rates_update, :rate_destroy]
  before_filter :check_localization, except: [:sms_result]
  before_filter :authorize
  before_filter :check_sms_addon, except: [:sms_result]
  before_filter :find_session_user, only: [:send_sms, :user_rates, :sms]
  before_filter :find_user, only: [:edit_user, :lcr_update_user]
  before_filter :find_lcr, only: [:send_sms, :sms]
  before_filter :find_provider, only: [:send_sms, :sms]
  before_filter :find_user_tariff, only: [:send_sms, :sms, :user_rates]
  before_filter :find_number, only: [:send_sms]
  before_filter :find_lcr_from_id, only: [:lcr_providers, :try_to_add_provider, :lcr_edit, :lcr_update, :lcr_destroy,
    :lcr_details, :remove_lcr_provider, :lcr_provider_change_status, :lcr_providers_sort, :providers_sort_save]
  before_filter :find_provider_from_id, only: [:provider_edit, :provider_update, :provider_destroy]

  def index
    redirect_to(action: :sms_list) && (return false)
  end

  def users
    @page_title = _('Users_subscribed_to_sms')
    @page_icon = 'user.png'
    session_user_id = session[:user_id]

    users = User.select(all_with_nice_user)
    @active_users = users.where(sms_service_active: 1, owner_id: session_user_id, hidden: 0).order('nice_user ASC')
    users = users. where(sms_service_active: 0, owner_id: session_user_id, hidden: 0).order('nice_user ASC')
    @not_active_users = users.reject { |user| user.is_reseller? && !user.has_reseller_sms_permission? || user.is_admin? }
  end

  def user_subscribe_to_sms
    @user = User.find(params[:user_id])
    @lcr = SmsLcr.first

    unless @lcr
      flash[:notice] = reseller? ? _('No_available_SMS_LCR_reseller') : _('No_available_SMS_LCR')
      redirect_to(action: :users) && (return false)
    end

    @tariff = Tariff.where(purpose: 'user_wholesale', owner_id: current_user.id).first

    unless @tariff
      flash[:notice] = _('No_available_SMS_Tariff')
      redirect_to(action: :users) && (return false)
    end

    action_hash, status = @user.sms_subscription(@tariff.id, @lcr.id)
    flash[:status] = status
    Action.add_action_hash(User.current, action_hash)

    redirect_to(action: :users) && (return false)
  end

  def lcrs
    @page_title = _('Sms_lcrs')
    @lcrs = SmsLcr.order(:name)
  end

  def lcr_new
    @page_title = _('LCR_new')
    @page_icon =  'add.png'
    @lcr = SmsLcr.new
  end

  def lcr_create
    @page_title = _('LCR_new')
    @page_icon = 'add.png'
    @lcr = SmsLcr.new(params[:lcr].each_value(&:strip!))

    if @lcr.save
      flash[:status] = _('Lcr_was_successfully_created')
      redirect_to(action: :lcrs) && (return false)
    else
      render(:lcr_new) && (return false)
    end
  end

  def lcr_providers
    @page_title  = _('Providers_for_LCR')
    @page_icon = 'provider.png'
    @providers = @lcr.sms_providers('asc')
    @all_providers = SmsProvider.all
    @other_providers = []

    @all_providers.each { |provider| @other_providers << provider if !@providers.include?(provider) }
    flash[:notice] = _('No_providers_available') if @all_providers.empty?
  end

  def try_to_add_provider
    prov_id = params[:select_prov]

    if prov_id != '0'
      @prov = SmsProvider.find_by(id: prov_id)
      @lcr.add_sms_provider(@prov)
      flash[:status] = _('Provider_added')
    else
      flash[:notice] = _('Please_select_provider_from_the_list')
    end

    redirect_to(action: :lcr_providers, id: @lcr) && (return false)
  end

  def lcr_edit
    @page_title = _('LCR_edit')
    @page_icon = 'edit.png'
  end

  def lcr_update
    @page_title = _('LCR_edit')
    @page_icon = 'edit.png'

    if @lcr.update_attributes(params[:lcr].each_value(&:strip!))
      flash[:status] = _('Lcr_was_successfully_updated')
      redirect_to(action: :lcrs, id: @lcr) && (return false)
    else
      render(:lcr_edit) && (return false)
    end
  end

  def lcr_destroy
    # Check if no users uses this lcr
    if User.where(sms_lcr_id: @lcr).to_a.size > 0
      flash[:notice] = _('Lcr_not_deleted')
    else
      flash[:status] = _('Lcr_deleted')
      @lcr.destroy
    end

    redirect_to(action: :lcrs) && (return false)
  end

  def lcr_details
    @page_title = _('LCR_Details')
    @page_icon = 'view.png'
    @user = User.select(all_with_nice_user).where(sms_lcr_id: @lcr).order('nice_user ASC')
  end

  def remove_lcr_provider
    @lcr.remove_sms_provider(params[:prov])
    flash[:status] = _('Provider_removed')
    redirect_to(action: :lcr_providers, id: @lcr) && (return false)
  end

  def lcr_provider_change_status
    prov_id = params[:prov]

    if @lcr.sms_provider_active(prov_id)
      value = 0
      flash[:status] = _('Provider_disabled')
    else
      value = 1
      flash[:status] = _('Provider_enabled')
    end
    lcr_id = @lcr.id
    sql = "UPDATE sms_lcrproviders SET active = #{value} WHERE sms_lcr_id = #{lcr_id} AND sms_provider_id = #{prov_id}"
    ActiveRecord::Base.connection.update(sql)

    redirect_to(action: :lcr_providers, id: lcr_id) && (return false)
  end

  def lcr_providers_sort
    if (@lcr.order.to_s != 'priority')
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end

    @page_title = "#{_('Change_Order')}: #{@lcr.name}"
    @page_icon = 'arrow_switch.png'
    @items = @lcr.sms_providers('asc')
  end

  def providers_sort_save
    params_sortable_list = params[:sortable_list]
    params_sortable_list.each_index do |index|
      item = SmsLcrprovider.where(sms_provider_id: params_sortable_list[index], sms_lcr_id: params[:id]).first
      item.priority = index
      item.save
    end
    @page_title = "#{_('Change_Order')}: #{@lcr.name}"
    @items = @lcr.sms_providers('asc')
    render(layout: false, action: :providers_sort) && (return false)
  end

  def edit_user
    @page_title = _('Sms_user')
    @page_icon = 'edit.png'
    @sms_lcrs = SmsLcr.order(:name)
    @tariffs = current_user.sms_tariffs
  end

  def lcr_update_user
    flash[:status] = @user.lcr_update(params, session[:usertype]) ? _('User_updated') : _('User_not_updated')
    redirect_to(action: :edit_user, id: @user.id) && (return false)
  end

  def providers
    @page_title = _('Sms_providers')
    @page_icon = 'provider.png'
    @providers = SmsProvider.all
  end

  def provider_new
    @page_title = _('New_provider')
    @page_icon = 'add.png'
    @provider = SmsProvider.new
    @action = :new
    @tariffs = current_user.sms_provider_tariffs
    unless @tariffs.present?
      flash[:notice] = _('No_SMS_tariffs_available')
      redirect_to(action: :providers) && (return false)
    end
    @new_provider = true
  end

  def provider_create
    sms_prov = SmsProvider.create_by_params(params)
    if sms_prov.save
      flash[:status] = _('Sms_provider_created')
      redirect_to(action: :providers) && (return false)
    else
      flash_errors_for(_('Sms_provider_not_created'), sms_prov)
      @api_string, @api_keywords, @provider = sms_prov.login, sms_prov.email_good_keywords, sms_prov
      @tariffs = current_user.sms_provider_tariffs
      render(:provider_new) && (return false)
    end
  end

  def provider_edit
    # Only admin may edit sms providers. Checking for direct-link attempts
    unless admin?
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
    @page_title = _('Sms_providers_edit')
    @page_icon = 'edit.png'

    @tariffs = current_user.sms_provider_tariffs
    @api_string = @provider.login
    @api_keywords = @provider.email_good_keywords
  end

  def provider_update
    @provider.set_wait_for_email(params)
    if @provider.save
      flash[:status] = _('Sms_provider_updated')
      redirect_to(action: :providers) && (return false)
    else
      flash_errors_for(_('Sms_provider_not_updated'), @provider)
      @api_string, @api_keywords, @tariffs = @provider.login, @provider.email_good_keywords,
          current_user.sms_provider_tariffs
      render(:provider_edit) && (return false)
    end
  end

  def provider_destroy
    unless @provider
      flash[:notice] = _('Sms_provider_not_found')
      redirect_to(action: :providers) && (return false)
    end
    @provider.destroy
    flash[:status] = _('Sms_provider_deleted')
    redirect_to(action: :providers) && (return false)
  end

  #------------------ SMS sending -----------------------------
  def sms
    @page_title = _('Send_sms')

    if @user.sms_service_active == 0
      flash[:notice] = session[:usertype] == 'admin' ? _('User_not_subscribed_to_SMS') : dont_be_so_smart
      redirect_to(action: :sms_list) && (return false)
    end

    @addresses = Phonebook.where(user_id: session[:user_id])

    if request.env['HTTP_X_MOBILE_GATEWAY']
      respond_to { |format| format.wml { render 'sms.wml.builder' } }
    end
  end

  def send_sms
    sms_numbers = params[:sms_counter].to_d
    message = params[:body]

    for number in @all_numbers
      if number.class.to_s == 'Phonebook'
        number = number.number
      end

      sms_providers = SmsProvider.find_providers_by_lcr(@lcr.id, number, @user)

      # if there is no provider rate found with particular number,
      # SmsMessage will still be created with required status code
      time_now, user_id, user_owner_id = Time.now, @user.id, @user.owner_id
      if sms_providers.present?
        # for iteration here is required so that sms variable would be accessable from outside too
        for provider in sms_providers do
          sms = SmsMessage.new(sending_date: time_now, user_id: user_id, reseller_id: user_owner_id, number: number)
          sms.save
          sms.sms_send(@user, @user_tariff, number, @lcr, sms_numbers, message, params.merge({sms_unicode: 0, smsprovider: provider}))
          break if sms.status_code == 0
        end
      else
        sms = SmsMessage.create(sending_date: time_now, user_id: user_id, reseller_id: user_owner_id, number: number)
        sms.sms_send(@user, @user_tariff, number, @lcr, sms_numbers, message, params.merge({sms_unicode: 0}))
      end
    end

    status, type = sms.sms_status
    flash[type] = status

    if request.env['HTTP_X_MOBILE_GATEWAY']
      redirect_to(:root, sms_notice: status_code_tip.to_s) && (return false)
    else
      redirect_to(action: :sms_list) && (return false)
    end
  end

  def sms_result
    sms_result_params
    action_log_data4 = params.inspect.to_s[0..255]
    charge_value = @charge.to_d
    @sms = SmsMessage.find_by(clickatell_message_id: @apiMsgId)
    if @sms
      sms_callback_action = Action.where(target_id: @sms, target_type: 'SMS', action: 'SMS_callback').
          where.not(data3: 0).first.blank?
      @user, charge = @sms.user, false

      if charge_value > 0 && sms_callback_action
        @sms.charge_user
        charge = true
      elsif charge_value <= 0 && sms_callback_action
        @sms.return_sms_price_to_user
        charge = true
      end
      @sms.status_code = @status.to_s
      @sms.save

      Action.add_action_hash(@user,
                             {action: 'SMS_callback', data: @status, data4: action_log_data4, data2: charge_value,
                              target_id: @sms.id, target_type: 'SMS', data3: charge})
    else
      Action.add_error(0, 'SMS_callback', {data4: action_log_data4, target_type: 'SMS', data2: 'SMS_not_found'})
    end

    render(nothing: true) && (return false)
  end

  def sms_list
    @page_title = _('Sms_list')
    session_items_per_page = session[:items_per_page]
    @page = (params[:page] || 1).to_i
    @all_sms = SmsMessage.where(user_id: session[:user_id]).order(sending_date: :desc)
    all_sms_size = @all_sms.size
    @total_pages = (all_sms_size.to_d / session_items_per_page.to_d).ceil

    @sms, @a_number = [], []
    sms_size_decreased = all_sms_size - 1
    iend = ((session_items_per_page * @page) - 1)
    iend = sms_size_decreased if iend > sms_size_decreased
    (((@page - 1) * session_items_per_page)..iend).each { |index| @sms << @all_sms[index] }

    @t_sms, @t_sms_price = 0, 0
    @sms.each do |sms|
      sms_user_rate = sms.user_rate
      sms_user_price = sms.user_price
      if [0, 4].include?(sms.status_code.to_i) && (sms_user_rate.to_d != 0.0)
        @t_sms += sms_user_price / sms_user_rate
        @t_sms_price += sms_user_price
      else
        @t_sms += 0
        @t_sms_price += 0
      end
    end
  end

  def user_rates
    @page_title = _('Sms_rates')
    session_items_per_page = session[:items_per_page]
    @st = params[:st].try(:upcase) || 'A'
    @page = (params[:page] || 1).to_i
    ex = Currency.count_exchange_rate(@user_tariff.currency, current_user.currency.name)
    @all_rates = @user_tariff.sms_rates_by_st(@st, 0, 10000, {exchange_rate: ex, user: @user})
    all_rates_size = @all_rates.size
    @total_pages = (all_rates_size.to_d / session_items_per_page.to_d).ceil
    @rates = []

    all_rates_size_decreased = all_rates_size - 1
    iend = ((session_items_per_page * @page) - 1)
    iend = all_rates_size_decreased if iend > all_rates_size_decreased
    (((@page - 1) * session_items_per_page)..iend).each { |index| @rates << @all_rates[index] }
  end

  def prefix_finder_find
    @phrase = params[:prefix].to_s
    sql = "
      SELECT
        destinations.*,
        directions.name AS dirname
      FROM destinations
      JOIN rates ON (rates.prefix = destinations.prefix)
      LEFT JOIN directions ON (directions.code = destinations.direction_code)
      WHERE destinations.prefix = SUBSTRING(#{ActiveRecord::Base::sanitize(@phrase)}, 1, LENGTH(destinations.prefix))
      ORDER BY LENGTH(destinations.prefix) DESC
      LIMIT 1
    "
    @dest = Destination.find_by_sql(sql) if @phrase != ''
    user_currency_name = current_user.currency.name
    if !@dest || @dest.blank? || @phrase.blank?
      @results = _('Cant_send_SMS_no_rate_for_this_destination')
    else
      sms_tarif_id = current_user.sms_tariff_id
      @tariff, @results = Tariff.find_by(id: sms_tarif_id), ''
      if @tariff
        ex = Currency.count_exchange_rate(@tariff.currency, user_currency_name)
        @rate = SmsMessage.sms_rate(current_user, @phrase)
        @dest.each { |dest| @results = "#{dest.dirname} #{dest.name}" }
        @price = ''
        if @rate
          @price = @rate.price * ex
          @results += ' / 1 SMS: ' + nice_number(@price) + ' ' + user_currency_name.to_s
        else
          @results += " - #{_('Cant_send_SMS_no_rate_for_this_destination')}"
        end
      end
    end
    render(layout: false)
  end

  private

  def get_users_numbers(number)
    return number.to_s == 'All' ? Phonebook.where(user_id: session[:user_id]) : [number]
  end

  def all_with_nice_user
    "*, #{SqlExport.nice_user_sql}"
  end

  def format_number(number)
    pre_formatted = number.gsub('-', '').strip
    pre_formatted_length = pre_formatted.length
    formatted = (pre_formatted_length == 11 && pre_formatted[0, 1] == '1') ?
        pre_formatted[1..pre_formatted_length] : pre_formatted
    is_valid?(formatted) ? formatted : (raise Exception.new("Phone number (#{number}) is not formatted correctly"))
  end

  def is_valid?(number)
    (number.length >= 5 && number[/^.\d+$/]) ? true : false
  end

  def check_sms_addon
    owner = User.find_by(id: current_user.owner_id)

    unless sms_active? && ((session[:usertype] == 'admin') || ((((reseller? || owner.is_reseller?) && current_user.has_reseller_sms_permission?) || (!owner.is_reseller? && !reseller?)) && session[:sms_service_active].to_i == 1))
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
  end

  def find_session_user
    @user = User.find_by(id: session[:user_id])
    unless @user
      flash[:notice] = _('User_was_not_found')
      redirect_to(:root) && (return false)
    end
  end

  def find_user
    @user = User.find_by(id: params[:id])
    if !@user || (@user.owner_id != session[:user_id])
      flash[:notice] = _('User_was_not_found')
      redirect_to(:root) && (return false)
    end
  end

  def find_lcr
    @lcr = @user.sms_lcr
    unless @lcr
      flash[:notice] = _('No_available_SMS_LCR')
      redirect_to(:root) && (return false)
    end
  end

  def find_lcr_from_id
    @lcr = SmsLcr.find_by(id: params[:id])
    unless @lcr
      flash[:notice] = _('No_available_SMS_LCR')
      redirect_to(:root) && (return false)
    end
  end

  def find_provider
    @providers = @lcr.sms_providers
    if !@providers || @providers.size.to_i < 1
      flash[:notice] = _('No_available_SMS_Provider')
      redirect_to(:root) && (return false)
    end
  end

  def find_provider_from_id
    @provider = SmsProvider.find_by(id: params[:id])
    unless @provider
      flash[:notice] = _('No_available_SMS_Provider')
      redirect_to(:root) && (return false)
    end
  end

  def find_user_tariff
    @user_tariff = Tariff.find_by(id: @user.sms_tariff_id)
    unless @user_tariff
      action = Action.new(user_id: session[:user_id], date: Time.now,
                          action: 'error', data: _('No_sms_tariff'), data2: request.url)
      action.save
      flash[:notice] = _('No_SMS_tariffs_available')
      redirect_to(:root) && (return false)
    end
  end

  def find_tariff_from_id
    @tariff = Tariff.find_by(id: params[:id])
    if !@tariff || (@tariff.owner_id != session[:user_id])
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
  end

  def find_number
    if request.env['HTTP_X_MOBILE_GATEWAY']
      params_number_second = params[:number2]
      params[:number] = params_number_second.to_i != 0 ? params_number_second : params[:number1]
    end

    @all_numbers = get_users_numbers(params[:number])
    if params[:number].to_s.length == 0 || @all_numbers.size == 0
      flash[:notice] = _('Please_enter_number')
      redirect_to(action: :sms) && (return false)
    end
  end

  def authorize_for_sms_actions
    authorize_accountant if accountant?
    authorize_reseller if reseller?
    authorize_user if user?
    authorize_admin if admin?
  end

  def authorize_admin
    pages_for_admin = [:sms, :send_sms]
    pages_for_admin_is_current_action = pages_for_admin.include?(params[:action].to_sym)

    if pages_for_admin_is_current_action
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
  end

  def authorize_accountant
    pages_for_acc = [:prefix_finder_find]
    pages_for_acc_is_current_action = pages_for_acc.include?(params[:action].to_sym)

    unless pages_for_acc_is_current_action
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
  end

  def authorize_reseller
    pages_for_reseller = [:user_subscribe_to_sms, :prefix_finder_find, :tariffs, :tariff_new, :tariff_create,
      :tariff_edit, :tariff_update, :tariff_destroy, :users, :rates, :rate_new, :rate_try_to_add, :rates_update,
      :rate_destroy, :delete_all_rates, :edit_user, :lcr_update_user]
    pages_for_reseller_is_current_action = pages_for_reseller.include?(params[:action].to_sym)

    if pages_for_reseller_is_current_action && (current_user.reseller_right('sms_addon').to_i != 2)
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to(:root) && (return false)
    elsif !pages_for_reseller_is_current_action
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
  end

  def authorize_user
    pages_for_user = [:sms_list, :sms, :send_sms, :user_rates, :prefix_finder_find]
    pages_for_user_is_current_action = pages_for_user.include?(params[:action].to_sym)

    unless pages_for_user_is_current_action
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
  end

  def sms_result_params
    @api_id = params[:api_id].to_s
    @from = params[:from].to_s
    @to = params[:to].to_s
    @text = params[:text].to_s
    @dated = params[:timestamp].to_s
    @apiMsgId = params[:apiMsgId].to_s
    @status = params[:status].to_s
    @charge = params[:charge].to_s
  end
end
