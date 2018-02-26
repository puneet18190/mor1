# -*- encoding : utf-8 -*-
# Currencies managing.
class CurrenciesController < ApplicationController

  layout 'callc'
  before_filter :allow_to_use, except: [:calculate, :calculate_min_max_notice]
  before_filter :check_post_method, :only => [:destroy, :create, :update]
  before_filter :check_localization, :except => [:calculate, :calculate_min_max_notice]
  before_filter :authorize, :except => [:calculate, :calculate_min_max_notice]
  before_filter :find_currecy, :only => [:currencies_change_update_status, :currencies_change_status, :currencies_change_default, :edit, :update, :destroy]

  def calculate
    amount = params[:amount]
    first_currency = params[:curr1].to_s
    second_currency = params[:curr2].to_s

    min_amount = params[:min_amount].try(:to_d)
    max_amount = params[:max_amount].try(:to_d)

    user_id = params[:user].to_i

    amount_without_tax = (first_currency == second_currency) ? round_to_cents(amount).to_d : exchange(amount, first_currency, second_currency).to_d
    @without_tax = if min_amount.present? && amount_without_tax < min_amount
                     min_amount
                   elsif max_amount.present? && !max_amount.zero? && amount_without_tax > max_amount
                     max_amount
                   else
                     amount_without_tax
                   end
    @tax_in_amount = params[:tax_in_amount].to_s
    if @tax_in_amount == 'excluded'
      @with_tax = ActiveProcessor.configuration.substract_tax.call(user_id, @without_tax).to_d
      @with_tax, @without_tax = @without_tax, @with_tax
    else
      @with_tax = ActiveProcessor.configuration.calculate_tax.call(user_id, @without_tax)
    end

    result = {
        :without_tax => round_to_cents(@without_tax),
        :with_tax => round_to_cents(@with_tax)
    }

    respond_to do |format|
      format.json {
        render :json => result.to_json
      }
    end
  end

  def calculate_min_max_notice
    @gateway = GatewayEngine.find(:first, {:engine => params[:engine], :gateway => params[:gateway], :for_user => current_user.try(:id)}).enabled_by(current_user.try(:owner).try(:id)).query

    default_currency = @gateway.settings['default_currency']
    selected_currency = params[:currency]
    exchange_rate = Currency.count_exchange_rate(default_currency, selected_currency).to_f

    @min_max_notice_data = {}

    @min_max_notice_data[:min_amount] = @gateway.get(:config, 'min_amount').to_f * exchange_rate
    @min_max_notice_data[:max_amount] = @gateway.get(:config, 'max_amount').to_f * exchange_rate
    @min_max_notice_data[:current_currency] = selected_currency

    respond_to do |format|
      format.html { render(partial: '/active_processor/gateways/min_max_notice', locals:{min_max_notice_data: @min_max_notice_data}, layout: false) }
    end
  end

  def currencies
    @page_title = _('Currencies')
    @page_icon = "money_dollar.png"
    @currs = Currency.order("name ASC")
  end


  def currencies_change_update_status
    @currency.curr_update = @currency.curr_update == 1 ? 0 : 1
    if @currency.save
      flash[:status] = @currency.curr_update == 1 ? _('Currency_update_enabled') : _('Currency_update_disabled')
    else
      flash_errors_for(_('Currency_not_updated'), @currency)
    end
    redirect_to :action => 'currencies'
  end

  def currencies_change_status
    @currency.active = @currency.active == 1 ? 0 : 1

    if @currency.save
      flash[:status] = @currency.active == 1 ? _('Currency_enabled') : _('Currency_disabled')
    else
      flash_errors_for(_('Currency_not_updated'), @currency)
    end
    redirect_to :action => 'currencies'
  end

  def change_default
    @page_title = _('Default_currency')
    @page_icon = 'money_dollar.png'
    @currs = Currency.all
  end

  def currencies_change_default
    curr = @currency.set_default_currency
    if curr
      session[:default_currency] = curr
      flash[:status] = _('Currencies_rates_updated')
    else
      flash[:notice] = _('Error_Please_Try_Again_Later')
    end
    redirect_to :action => :change_default
  end

  def update_currencies_rates
    updated = true
    if params[:all].to_i == 1
      begin
        Currency.transaction do
          updated = Currency.update_currency_rates
        end
      rescue
        updated = false
      end
    else
      currency = Currency.where(id: params[:id]).first
      unless currency
        flash[:notice] = _('Currency_was_not_found')
        redirect_back_or_default('/currencies/currencies')
      end

      # here we get if currency's currency was successfully updated, but it won't update currency itself
      updated = currency.update_rate
      # for this reason, we will have to query @currency once again, to make sure, its exchange rate is right
      @currency = Currency.where(id: params[:id]).first

      # check if currency exchange rate was not set to 1 (no found rate), its not default (because then it would be 1)
      # and currencies was updated, as it would make no sense then to check exchange rate
      if (@currency.exchange_rate == 1 && (@currency.name.to_s != session[:default_currency].to_s)) && updated
        flash[:notice] = _('Yahoo_could_not_find_currency')
        redirect_to(action: :currencies) && (return false)
      end
    end
    if updated
      # Update/Create daily currencies
      daily_currencies = DailyCurrency.where(added: Time.now.strftime('%F')).first || DailyCurrency.new
      daily_currencies.currencies_update
      daily_currencies.save
      flash[:status] = params[:all].to_i == 1 ? _('Currencies_rates_updated') :
          _('Currency_exchange_rate_successfully_updated')
    else
      flash[:notice] = _('Error_Please_Try_Again_Later')
    end
    redirect_to(action: :currencies)
  end

  def edit
    @page_title = _('Currency_edit')
    @page_icon = 'edit.png'
  end

  def update
    exchange_rate = params[:exchange_rate].try(:to_d)
    if exchange_rate > 0.to_d
      @currency.exchange_rate = (@currency.id == 1) ? 1 : exchange_rate
    else
      @currency.active = 0
    end
    @currency.assign_attributes(full_name: params[:full_name], last_update: Time.now)
    if @currency.save
      # Update/Create daily currencies
      daily_currencies = DailyCurrency.where(added: Time.now.strftime('%F')).first || DailyCurrency.new
      daily_currencies.currencies_update
      daily_currencies.save
      flash[:status] = _('Currency_details_updated')
    else
      flash_errors_for(_('Currency_details_not_updated'), @currency)
    end
    redirect_to :action => 'currencies'
  end

  def destroy
    local_currency = @currency
    total_tariffs = @currency.tariffs.size

    if (local_currency.id != 1) and (total_tariffs == 0) and (local_currency.curr_edit != 1) # AND check if some tariff etc uses this currency
      session[:show_currency] = session[:default_currency] if session[:show_currency] == local_currency.name
      @currency.destroy
      flash[:status] = _('Currency_deleted')
    else
      flash[:notice] = _('Cant_delete_this_currency_some_tariffs_are_using_it') if total_tariffs != 0
    end
    redirect_to :action => 'currencies'
  end

  private

  def exchange(amount, curr_from, curr_to)
    amount = amount.to_d * ActiveProcessor.configuration.currency_exchange.call(curr_from, curr_to) if defined? ActiveProcessor.configuration.currency_exchange
    return round_to_cents(amount)
  end

  def round_to_cents(amount)
    sprintf("%.2f", amount.to_f)
  end

  def find_currecy
    @currency = Currency.where(['id=?', params[:id]]).first
    unless @currency
      flash[:notice] = _('Currency_was_not_found')
      redirect_back_or_default("/currencies/currencies") and return false
    end
  end

  def allow_to_use
    if current_user.blank? || !admin?
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
  end
end
