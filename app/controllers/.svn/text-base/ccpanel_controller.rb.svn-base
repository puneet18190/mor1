# -*- encoding : utf-8 -*-
# Calling Card Panel.
class CcpanelController < ApplicationController

  before_filter :check_localization
  before_filter :check_callingcards_enabled
  before_filter :check_authentication, only: [
      :card_details, :call_list, :rates, :speeddials, :speeddial_add_new, :speeddial_edit, :speeddial_update,
      :speeddial_destroy
  ]
  before_filter :find_card, only: [:card_details, :rates]
  before_filter :find_tariff, only: [
      :generate_personal_rates_csv, :generate_personal_rates_pdf, :generate_personal_wholesale_rates_csv,
      :generate_personal_wholesale_rates_pdf
  ]
  before_filter :find_phonebook, only: [:speeddial_edit, :speeddial_update, :speeddial_destroy]

  def index
    redirect_to action: :list
  end

  def list
    @page_title = _('Calling_Card_Panel')
  end

  def try_to_login
    redirect_to(action: :index) && (return false) if session[:cclogin]

    card = if cc_single_login_active?
             Card.where('CONCAT(cards.number, cards.pin) = ?', params['login']).first
           else
             Card.where(number: params['login_num'], pin: params['login_pin']).first
           end

    if card
      session.update(
          card_id: card.id, card_number: card.number,
          nice_number_digits: Confline.get_value('Nice_Number_Digits', 0).to_i, cclogin: true,
          items_per_page: Confline.get_value('Items_Per_Page', 0).to_i,
          default_currency: Currency.where(id: 1).first.try(:name)
      )
      session[:show_currency] = session[:default_currency]

      flash[:status] = _('login_successfully')
      redirect_to(controller: :ccpanel, action: :card_details) && (return false)
    else
      flash[:notice] = _('bad_cc_login')
      redirect_to(controller: :ccpanel, action: :index) && (return false)
    end
  end

  def logout
    session[:cclogin] = false
    session[:card_id] = nil
    session[:card_number] = nil

    flash[:status] = _('logged_off')
    redirect_to(controller: :ccpanel, action: :index) && (return false)
  end

  def card_details
    @page_title = _('Card')
    @cg = @card.cardgroup
  end

  def call_list
    @page_title = _('Calls')
    card = Card.includes(:cardgroup, :calls).where(id: session[:card_id]).first
    @calls = card.calls
    @cg = card.cardgroup

    @totals = {billsec: 0, price: 0}
    @calls.each do |call|
      @totals[:billsec] += call.billsec.to_i
      @totals[:price] += call.user_price.to_d
    end
    @totals[:price_with_vat] = @totals[:price] + @cg.get_tax.count_tax_amount(@totals[:price])
  end

  def rates
    @page_title = _('Rates')
    @page_icon = 'coins.png'

    @cardgroup = @card.cardgroup
    @tariff = @cardgroup.tariff
    tariff_id = @tariff.id
    tariff_currency = @tariff.currency
    items_per_page = session[:items_per_page]
    show_currency = session[:show_currency]

    @page = params[:page] ? params[:page].to_i : 1
    @st = params[:st] ? params[:st].upcase : 'A'

    @show_currency_selector = true
    @dgroups = (@dgroups ||= Destinationgroup.where('name LIKE ?', "#{@st}%").order('name ASC').all)

    @rates = @tariff.rates_by_st(@st, 10000, '')
    @total_pages = (@rates.length.to_f / items_per_page.to_f).ceil
    @all_rates = @rates
    all_rates_size = @all_rates.size - 1
    @rates = []
    @rates_current = []
    @rates_free2 = []
    @rates_d = []
    iend = ((items_per_page * @page) - 1)
    iend = all_rates_size if iend > all_rates_size
    for index in ((@page - 1) * items_per_page)..iend
      @rates << @all_rates[index]
    end

    rates = Rate.find_by_sql("
      SELECT rates.*
      FROM rates, destinations, directions
      WHERE rates.tariff_id = #{tariff_id}
            AND rates.destination_id = destinations.id
            AND destinations.direction_code = directions.code
            AND directions.name LIKE #{ActiveRecord::Base::sanitize(@st + '%')}
      ORDER by directions.name ASC;
    ")

    exrate = Currency.count_exchange_rate(tariff_currency, show_currency)
    ratedetails = Ratedetail.where("rate_id IN (
                                                SELECT rates.id
                                                FROM rates, destinations, directions
                                                WHERE rates.tariff_id = #{tariff_id}
                                                AND rates.destination_id = destinations.id
                                                AND destinations.direction_code = directions.code
                                                AND directions.name LIKE #{ActiveRecord::Base::sanitize(@st + '%')}
                                               )").order('rate DESC').all

    for rate in rates
      rate_d = ratedetails.select { |ratedetail| ratedetail.rate_id.to_i == rate.id.to_i }
      get_provider_rate_details(rate_d, exrate)
      @rates_current[rate.id] = @rate_cur
      @rates_free2[rate.id] = @rate_free
      @rates_d[rate.id] = @rate_increment_s
    end

    @letter_select_header_id = tariff_id
    @page_select_header_id = tariff_id

    @show_values_without_vat = confline('CCShop_show_values_without_VAT_for_user').to_i
    @exchange_rate = count_exchange_rate(tariff_currency, show_currency)
    @cust_exchange_rate = count_exchange_rate(session[:default_currency], show_currency)
  end

  def generate_personal_rates_pdf
    tariff_currency = @tariff.currency.to_s.upcase
    rates = Rate.joins('LEFT JOIN destinationgroups on (destinationgroups.id = rates.destinationgroup_id)').
        where('rates.tariff_id = ?', @tariff.id).order('destinationgroups.name').all
    options = {
        name: @tariff.name,
        pdf_name: _('Users_rates'),
        currency: tariff_currency
    }
    pdf = PdfGen::Generate.generate_rates_header(options)
    pdf = PdfGen::Generate.generate_user_rates_pdf(pdf, rates, @tariff, options)
    testable_file_send(pdf.render, "Rates-#{tariff_currency}.pdf", 'application/pdf')
  end

  def generate_personal_rates_csv
    if testing?
      render text: @tariff.generate_user_rates_csv(session)
    else
      send_data(
          @tariff.generate_user_rates_csv(session), type: 'text/csv; charset=utf-8; header=present',
          filename: "Rates-#{@tariff.currency.to_s.upcase}.csv"
      )
    end
  end

  def generate_personal_wholesale_rates_csv
    if testing?
      render text: @tariff.generate_personal_wholesale_rates_csv(session)
    else
      send_data(
          @tariff.generate_personal_wholesale_rates_csv(session), type: 'text/csv; charset=utf-8; header=present',
          filename: "Rates-#{(@tariff.currency.to_s.upcase).to_s}.csv"
      )
    end
  end

  def generate_personal_wholesale_rates_pdf
    tariff_currency = @tariff.currency.to_s.upcase
    rates = Rate.find_by_sql("
      SELECT rates.*
      FROM rates, destinations, directions
      WHERE rates.tariff_id = #{@tariff.id}
            AND rates.destination_id = destinations.id
            AND destinations.direction_code = directions.code
      ORDER by directions.name ASC;
    ")
    options = {
        # Font size
        fontsize: 6,
        title_fontsize1: 16,
        title_fontsize2: 10,
        header_size_add: 1,
        page_number_size: 8,
        # Positions
        first_page_pos: 150,
        second_page_pos: 70,
        page_num_pos: 780,
        header_eleveation: 20,
        step_size: 15,
        title_pos1: 50,
        title_pos2: 70,

        first_page_items: 40,
        second_page_items: 45,

        # Column positions
        col1_x: 30,
        col2_x: 205,
        col3_x: 250,
        col4_x: 310,
        col5_x: 350,
        col6_x: 420,
        col7_x: 470,

        currency: tariff_currency
    }
    pdf = PdfGen::Generate.generate_personal_wholesale_rates_pdf(rates, @tariff, nil, options)
    send_data pdf.render, filename: "Rates-#{(tariff_currency).to_s}.pdf", type: 'application/pdf'
  end

  def speeddials
    @page_title = _('Speed_Dials')
    @page_icon = 'book.png'

    @sp = Phonebook.where(card_id: session[:card_id]).all
  end

  def speeddial_add_new
    ph = Phonebook.new(
        name: params[:name].presence, number: params[:number].presence, speeddial: params[:speeddial].presence,
        added: Time.now, user_id: 0, card_id: session[:card_id]
    )
    ph.save ? flash[:status] = _('speeddial_successfully_created') : flash_errors_for(_('Speeddial_not_created'), ph)

    redirect_to action: :speeddials
  end

  def speeddial_edit
    @page_title = _('Edit_Speed_Dial')
    @page_icon = 'edit.png'
  end

  def speeddial_update
    if @phonebook.update(params[:phonebook])
      flash[:status] = _('Speed_Dial_successfully_updated')
      redirect_to action: :speeddials
    else
      flash_errors_for(_('Speed_Dial_was_not_updated'), @phonebook)
      redirect_to action: :speeddial_edit, id: @phonebook
    end
  end

  def speeddial_destroy
    @phonebook.destroy
    flash[:status] = _('Speed_Dial_successfully_deleted')
    redirect_to action: :speeddials
  end

  private

  def find_card
    @card = Card.includes(:cardgroup).where(id: session[:card_id]).first

    if @card.blank? || @card.cardgroup.blank?
      flash[:notice] = _('Cardgroup_was_not_found')
      redirect_to(controller: :ccpanel, action: :index) && (return false)
    end
  end

  def check_authentication
    if session[:card_id].blank?
      flash[:notice] = _('Must_login_first')
      redirect_to(action: :list) && (return false)
    end
  end

  def find_tariff
    @tariff = Tariff.where(id: params[:id]).first

    unless @tariff
      flash[:notice] = _('Tariff_was_not_found')
      redirect_to(action: :index) && (return false)
    end

    unless @tariff.real_currency
      flash[:notice] =_('Tariff_currency_not_found')
      redirect_to(action: :index) && (return false)
    end
  end

  def testing?
    params[:test]
  end

  def check_callingcards_enabled
    unless cc_active?
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to(controller: :callc, action: :login) && (return false)
    end
  end

  def find_phonebook
    @phonebook = Phonebook.where(id: params[:id], card_id: session[:card_id]).first
    unless @phonebook
      dont_be_so_smart
      redirect_to(action: :speeddials) && (return false)
    end
  end

  def get_provider_rate_details(rate_d, exrate)
    @rate_details = rate_d
    if @rate_details.present?
      @rate_increment_s = @rate_details[0]['increment_s']
      @rate_cur, @rate_free = Currency.count_exchange_prices(
          exrate: exrate, prices: [@rate_details[0]['rate'].to_d, @rate_details[0]['connection_fee'].to_d]
      )
    end
    @rate_details
  end
end
