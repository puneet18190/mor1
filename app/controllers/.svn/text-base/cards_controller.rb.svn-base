# -*- encoding : utf-8 -*-
# A telephone card, calling card or phone card for short, is a small card,
#   usually resembling a credit card, used to pay for telephone services.
class CardsController < ApplicationController
  layout 'callc'

  before_filter :check_post_method, only: [:destroy, :create, :update]
  before_filter :check_localization
  before_filter :authorize
  before_filter :check_distrobutor, only: [:create, :update]
  before_filter :check_distrobutor_cards, only: [
      :user_list, :card_active, :bullk_for_activate, :bulk_confirm, :card_active_bulk
  ]
  before_filter :find_cardgruop, only: [
      :card_buy_finish, :card_buy, :import_csv, :create, :create_bulk, :new, :card_payment_finish, :list, :act,
      :act_confirm, :act2, :card_pay, :card_payment_status, :user_list
  ]
  before_filter :find_card, only: [
      :card_active, :card_buy_finish, :card_buy, :payments, :destroy, :update, :edit, :card_pay, :card_payment_status,
      :card_payment_finish, :show
  ]
  before_filter :allow_add_cards?, only: [:new, :create, :import_csv]

  @@card_view = [:index, :list]
  @@card_edit = [:new, :import_csv, :act, :edit, :destroy]
  before_filter(only: @@card_view + @@card_edit) do |method|
    allow_read, allow_edit = method.check_read_write_permission(
        @@card_view, @@card_edit, {role: 'accountant', right: :acc_callingcard_manage, ignore: true}
    )
    method.instance_variable_set :@allow_read, allow_read
    method.instance_variable_set :@allow_edit, allow_edit
    true
  end

  @@card_view_res = []
  @@card_edit_res = [:new, :import_csv, :act, :index, :list]
  before_filter(only: @@card_view_res + @@card_edit_res) do |method|
    allow_read, allow_edit = method.check_read_write_permission(
        @@card_view_res, @@card_edit_res, {role: 'reseller', right: :res_calling_cards, ignore: true}
    )
    method.instance_variable_set :@allow_read_res, allow_read
    method.instance_variable_set :@allow_edit_res, allow_edit
    true
  end

  def list
    @page_title = _('Cards')

    accountant_cc_manage = session[:acc_callingcard_manage].to_i

    @show_pin = !(accountant? && session[:acc_callingcard_pin].to_i == 0)
    @allow_manage = !(accountant? && ([0, 1].include?(accountant_cc_manage)))
    @allow_read = !(accountant? && (accountant_cc_manage == 0))
    @options = session[:cards_list_options] || {}

    [:s_number, :s_name, :s_pin, :s_batch_number, :s_balance_min, :s_balance_max, :s_callerid].each do |key|
      update_option(key, '')
    end
    [:s_language, :s_sold].each { |key| update_option(key, _('All')) }
    update_option(:s_user, '')
    update_option(:s_user_id, -1)
    bad_page = (!@options[:page] || params[:page].to_i <= 0)
    update_option(:page, 1, bad_page)

    @cards, @cards_all, @search, @cards_first_used = Card.find_calling_cards_for_list(@options, @cg, cc_active?)

    @fpage, @total_pages, @options = Application.pages_validator(session, @options, @cards_all)

    @cards = @cards.offset(@fpage).limit(session[:items_per_page].to_i)

    session[:cards_list_options] = @options
  end

  def user_list
    @page_title = _('Cards')
    @options = session[:cards_user_list_options] || {}

    bad_page = (!@options[:page] || (params[:page].to_i <= 0))
    update_option(:page, 1, bad_page)

    [:s_number, :s_name, :s_pin, :s_batch_number, :s_balance_min, :s_balance_max].each { |key| update_option(key, '') }
    [:s_language, :s_active].each { |key| update_option(key, _('All')) }

    @options[:order_by] = if params[:order_by]
                            case params[:order_by].to_s
                              when 'card_number'
                                'card_number'
                              when 'card_name'
                                'card_name'
                              when 'card_pin'
                                'card_pin'
                              when 'card_batch_number'
                                'card_batch_number'
                              when 'card_balance'
                                'card_balance'
                              when 'card_first_use'
                                'card_first_use'
                              when 'card_active'
                                'card_active'
                              when 'card_language'
                                'card_language'
                              else
                                'card_number'
                            end
                          elsif params[:clean] || !session[:cards_user_list_options]
                            'number'
                          else
                            session[:cards_user_list_options][:order_by]
                          end

    update_option(:order_desc, params[:order_desc].to_i, !@options[:order_desc])

    @options[:cg] = @cg.id
    @page = @options[:page]

    order_by = generate_order_string('card_', @options)
    @cards, @cards_all, @search, @cards_first_used = Card.find_calling_cards_for_user_list(@options, @cg, cc_active?, current_user)
    @fpage, @total_pages, @options = Application.pages_validator(session, @options, @cards_all)
    @cards = @cards.offset(@fpage).limit(session[:items_per_page].to_i).order(order_by)
    session[:cards_user_list_options] = @options
    @show_pins = Confline.get_value('CCShop_hide_pins_for_distributors', correct_owner_id).to_i.zero?
  end

  # ================ Bulk management  ===============

  def act
    @page_title = _('Bulk_management')
    @page_icon = 'groups.png'
  end

  def act_confirm
    @page_title = _('Bulk_management')
    @page_icon = 'groups.png'

    @activate = params[:activate].to_i
    if @activate.to_i == 6 && params[:card] && (params[:card][:min_balance] !~ /^[-+]?[0-9]*\.?[0-9]+$/)
      flash[:notice] = _('Bad_minimal_balance')
      redirect_to(action: :act, cg: @cg) && (return false)
    end

    find_start_and_end_numbers

    @u_id = params[:s_user_id].to_i
    @min_balance = params[:card] ? params[:card][:min_balance].to_d : 0.0
    @card_language = params[:card] ? params[:card][:language].to_s : ''

    card_group_number_length = @cg.number_length
    if [@start_num.to_i, @end_num.to_i].include?(0) || (@start_num.length != card_group_number_length) || (@end_num.length != card_group_number_length)
      flash[:notice] = _('Bad_number_length_should_be') + ': ' + card_group_number_length.to_s
      redirect_to(action: :act, cg: @cg) && (return false)
    end

    user_id = corrected_user_id
    card_group_id = @cg.id
    @list_second = Card.where(
        'hidden = 0 AND number >= ? AND number <= ? AND sold = 1 AND owner_id = ? AND cardgroup_id = ? ',
        @start_num, @end_num, user_id, card_group_id
    ).size
    @list = Card.where(
        'hidden = 0 AND number >= ? AND number <= ? AND sold = 0 AND owner_id = ? AND cardgroup_id = ? ',
        @start_num, @end_num, user_id, card_group_id
    ).size

    @a_name = case @activate
              when 0
                _('Disable')
              when 1
                _('Activate')
              when 2
                _('Delete')
              when 4
                _('Change_distributor')
              when 5
                _('Delete_and_hide')
              when 6
                _('Minimal_balance')
              when 7
                _('Language')
              end

    if @activate.to_i == 3
      @a_name = _('Buy')
      @user = User.includes(:address).where(id: user_id).first
      real_price = Card.select('SUM(balance) AS balance_sum').
          where("hidden = 0 AND number >= #{@start_num} and number <= #{@end_num} AND sold = 0 AND owner_id = #{session[:user_id]} AND cardgroup_id = '#{@cg.id}'").first.try(:balance_sum).to_d
      @real_price = real_price.to_d * current_user.currency.exchange_rate.to_d
      @tax = @cg.get_tax
      @taxes = @tax.applied_tax_list(@real_price)
      @total_tax_name = @tax.total_tax_name
    end
  end

  def act2
    start_num = params[:start].to_i <= params[:end].to_i ? params[:start] : params[:end]
    end_num = params[:end].to_i >= params[:start].to_i ? params[:end] : params[:start]
    action = params[:activate_i].to_i
    user_id = corrected_user_id
    card_group_id = @cg.id

    case action
    when 0
      cards = Card.where(
          'hidden = 0 AND number >= ? AND number <= ? AND sold = 1 AND owner_id = ? AND cardgroup_id = ?',
          start_num, end_num, user_id, card_group_id
      ).all
      cards.each { |card| card.update_attributes(sold: 0) }
    when 2
      cards_deleted, cards_not_deleted =
          Card.delete_from_sql({cardgroup_id: @cg.id, start_num: start_num, end_num: end_num})
    when 3
      list = Card.where(
          'hidden = 0 AND number >= ? AND number <= ? AND sold = 0 AND owner_id = ? AND cardgroup_id = ?',
          start_num, end_num, user_id, card_group_id
      ).all
      @email = params[:email].to_s
      list.each { |card| card.sell_from_bach(@email, session[:default_currency], current_user_id) }
    when 4
      cards = Card.where(
          'hidden = 0 AND number >= ? AND number <= ? AND owner_id = ? AND cardgroup_id = ?',
          start_num, end_num, user_id, card_group_id
      ).all
      cards.each { |card| card.update_attributes(user_id: params[:user].to_i) }
    when 5
      cards_deleted, cards_hidden =
          Card.delete_and_hide_from_sql({cardgroup_id: card_group_id, start_num: start_num, end_num: end_num})
    when 6
      cards = Card.where(
          'hidden = 0 AND number >= ? AND number <= ? AND owner_id = ? AND cardgroup_id = ?',
          start_num, end_num, user_id, card_group_id
      ).all
      cards.each { |card| card.update_attributes(min_balance: params[:min_balance].to_d) }
    when 7
      cards = Card.where(
          'hidden = 0 AND number >= ? AND number <= ? AND owner_id = ? AND cardgroup_id = ?',
          start_num, end_num, user_id, card_group_id
      ).all
      cards.each { |card| card.update_attributes(language: params[:language].to_s) }
    end

    case action
    when 0
      flash[:status] = _('Cards_were_successfully_disabled')
    when 1
      flash[:status] = _('Cards_were_successfully_activated')
    when 2
      not_deleted_number = cards_not_deleted == 0
      if cards_deleted == 0
        if not_deleted_number
          flash[:notice] = _('Cards_not_deleted') + '<br> * ' + _('Cards_were_not_found')
        else
          flash[:notice] = _('Cards_not_deleted') + '<br> * ' + _('Cards_have_calls')
        end
      else
        if not_deleted_number
          flash[:status] = _('Cards_successfully_deleted')
        else
          total = cards_deleted.to_i + cards_not_deleted.to_i
          flash[:status] = "#{cards_deleted.to_s} #{_('out_of')} #{total.to_s} #{_('Cards_successfully_deleted')}"
          flash[:notice] = "#{cards_not_deleted.to_s} #{_('out_of')} #{total.to_s} #{_('Cards_not_deleted')} <br> * #{_('Cards_have_calls')}"
        end
      end
    when 3
      flash[:status] = _('Cards_were_successfully_bought')
    when 4
      flash[:status] = _('Distributor_changed')
    when 5
      no_hidden_cards = cards_hidden.to_i == 0
      if cards_deleted == 0
        if no_hidden_cards
          flash[:notice] = _('Cards_not_deleted_or_hidden') + '<br> * ' + _('Cards_were_not_found')
        else
          flash[:status] = _('Cards_were_successfully_hidden')
        end
      else
        if no_hidden_cards
          flash[:status] = _('Cards_successfully_deleted')
        else
          total = cards_deleted.to_i + cards_hidden.to_i
          flash[:status] = "#{cards_deleted.to_s} #{_('out_of')} #{total.to_s} #{_('Cards_successfully_deleted')}"
          flash[:status] += "<br> #{cards_hidden.to_s} #{_('out_of')} #{total.to_s} #{_('Cards_were_successfully_hidden')}"
        end
      end
    when 6
      flash[:status] = _('Minimal_balance_changed')
    when 7
      flash[:status] = _('Language_changed')
    end

    redirect_to(action: :list, cg: @cg) && (return false)
  end

  # ============= Card_pay ============================

  def card_pay
    @page_title = _('Add_card_payment')
    @page_icon = 'money.png'

    @currs = Currency.get_active
    @user = User.where(id: session[:user_id]).includes(:address).first
  end

  def card_payment_status
    @page_title = _('Add_card_payment')
    @page_icon = 'money.png'

    @amount = params[:amount].to_d
    @curr = params[:currency]
    @description = params[:description].to_s
    @exchange_rate = count_exchange_rate(current_user.currency.name, @curr)

    if @exchange_rate == 0
      flash[:notice] = _('Currency_not_found')
      redirect_to(action: :card_pay, id: params[:id], cg: params[:cg]) && (return false)
    end

    @converted_amount = @amount / @exchange_rate
    @real_amount = @cg.get_tax.count_amount_without_tax(@converted_amount)

    if @card.sold == 0
      flash[:notice] = _('Cannot_fill_unsold_Card')
      redirect_to(action: :card_pay, id: params[:id], cg: params[:cg]) && (return false)
    end
  end

  def card_payment_finish
    amount = params[:amount].to_d
    currency = params[:currency]

    if @card.add_real_amount(params[:real_amount].to_d)
      Payment.add_for_card(@card, amount, currency, current_user.get_corrected_owner_id, params[:description])
      flash[:status] = _('Payment_added')
    else
      flash_errors_for(_('Payment_was_not_added'), @card)
    end

    redirect_to(action: :list, cg: @cg) && (return false)
  end

  def show
    @show_pin = !(accountant? && (session[:acc_callingcard_pin].to_i == 0))

    @page_title = _('Card_details')
    @cg = @card.cardgroup(include: [:tax])

    check_user_for_cardgroup(@cg)
  end

  def new
    @page_title = "#{_('add_cards_to')} #{@cg.name}"
    @page_icon = 'add.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Calling_Card_management#Card_Creation'

    @single_card = session[:single_card]
    @bulk_form = session[:bulk_form] || Forms::CallingCards::BulkForm.new
    session.try(:delete, :single_card)
    session.try(:delete, :bulk_form)

    # CSV Import, reset settings/etc
    session[:card_import_csv] = nil
    session[:temp_card_import_csv] = nil
    session[:import_csv_card_import_csv_options] = nil
    session[:card_import_csv2] = nil
  end

  def create
    # Initialize shared variables
    owner_id = current_user_id
    params[:single_card][:user_id] = (params[:s_user_id].to_i > 0 && params[:s_user_id]) || -1
    cg = @cg
    cg_id, cg_price = [cg.id, cg.price]
    pins = all_pins(cg, 1)
    redirect_to(action: :new, cg: cg) && (return false) unless pins

    params[:single_card][:pin] = pins.first

    default_card = {
      number: '',
      pin: '',
      active: 0,
      user_id: 0,
      balance: cg_price,
      cardgroup_id: cg_id,
      sold: false,
      owner_id: owner_id,
      language: 'en',
      batch_number: '',
      min_balance: 0.0
    }
    card = Card.new(default_card)

    if card.create_card(params[:single_card])
      flash[:status] = _('card_successfully_created')
      redirect_to action: :list, cg: cg_id
    else
      flash_errors_for(_('card_was_not_created'), card)
      session[:single_card] = card
      redirect_to action: :new, cg: cg_id
    end
  end

  def create_bulk
    params[:distributor_id] = (params[:s_bulk_user_id].to_i > 0 && params[:s_bulk_user_id]) || -1
    bulk_form = Forms::CallingCards::BulkForm.new(
        params[:bulk_form].merge(card_group: @cg).update(distributor_id: params[:distributor_id])
    )

    unless bulk_form.valid?
      flash_errors_for(_('card_was_not_created'), bulk_form)
      session[:bulk_form] = bulk_form
      redirect_to(action: :new, cg: @cg) && (return false)
    end

    unless @cg.pins_available?(bulk_form.total)
      flash[:notice] = "#{_('Bad_number_interval_max') } : #{@cg.total_pins_available} cards"
      redirect_to(action: :new, cg: @cg) && (return false)
    end

    factory = CallingCard::BulkFactory.new(bulk_form.attributes)
    factory.trial = !cc_active?
    factory.fabricate!

    flash[:status] = "#{_('Cards_created') }: #{factory.cards_created}"
    cards_with_errors = factory.invalid_cards

    if cards_with_errors.present?
      render('_new_cards', locals: {cards: cards_with_errors, cg: @cg}, layout: true) && (return false)
    else
      redirect_to(action: :list, cg: @cg) && (return false)
    end

    redirect_to action: :new, cg: @cg
  end

  # Create array of available pins
  def all_pins(cg, user_wants)
    length, max = [cg.pin_length, cg.total_pins_available]
    # Get pins from db
    pins_in_db = Card.select('pin').where("LENGTH(pin) = #{length}").map(&:pin)
    # Count available pins
    available_pin_number = max - pins_in_db.size
    if available_pin_number < user_wants
      # If user wants more - message about available amount
      flash[:notice] = _('Bad_number_interval_no_pin_left') + ': ' + available_pin_number.to_s + ' ' + _('cards')
      return false
    else
      # Generate pin list, no match
      pins = []
      random_num = (max/0.2).to_i
      until pins.size == user_wants
        begin
          pin = sprintf("%0#{length}d", rand(random_num))
        end while pins_in_db.include?(pin) || pins.include?(pin)
        pins << pin
      end
      pins
    end
  end

  def edit
    @page_title = _('Edit_card')
    @page_icon = 'edit.png'
    @return_controller = params[:return_to_controller].presence
    @return_action = params[:return_to_action].presence

    @daily_charge_paid_till_time =
        if @card.daily_charge_paid_till
          @card.daily_charge_paid_till += Time.zone.now.utc_offset.second - Time.now.utc_offset.second
          # Taking time from daily_charge_paid_till to pass it to update action
          @card.daily_charge_paid_till.strftime('%H:%M:%S')
        else
          '00:00:00'
        end

    @cg = @card.cardgroup
    check_user_for_cardgroup(@cg)
  end

  def update
    params[:card][:user_id] = params[:s_user_id].to_i == -2 ? -1 : params[:s_user_id]
    return_controller = params[:return_to_controller].presence
    return_action = params[:return_to_action].presence
    @card_old = @card.dup
    @cg = @card.cardgroup

    return false if check_user_for_cardgroup(@cg) == false

    # Safety hack
    if params[:card]
      params[:card] = params[:card].except('sold', 'balance', :sold, :balance)
      params[:card][:active] = (params[:card][:user_id].to_i > 0 ? 1 : 0) if Confline.get_value('Charge_Distributor_on_first_use').to_i == 1
    end

    if @card.update_daily_charge_paid_till(params, current_user)
      if @card.pin != @card_old.pin
        Action.add_action_hash(
            session[:user_id],
            {
                target_id: @card.id, target_type: 'card', action: 'card_pin_changed',
                data: @card_old.pin, data2: @card.pin
            }
        )
      end

      flash[:status] = _('Card_was_successfully_updated')

      if return_controller && return_action
        redirect_to controller: return_controller, action: return_action
      else
        redirect_to action: :show, id: @card.id
      end
    else
      flash_errors_for(_('Card_was_not_updated'), @card)
      @users = User.find_all_for_select(current_user_id)
      render :edit
    end
  end

  def destroy
    cg = @card.cardgroup
    return false unless check_user_for_cardgroup(cg)

    @card.destroy ? flash[:status] =_('Card_successfuly_deleted') : flash[:notice] = _('Card_was_not_deleted') + '<br> * ' + _('Card_has_calls')
    redirect_to(action: :list, cg: cg) && (return false)
  end

  def payments
    @page_title = _('Card_payments')
    @page_icon = 'details.png'
    @return_controller = params[:return_to_controller].presence
    @return_action = params[:return_to_action].presence

    @cg = @card.cardgroup
    @payments = Payment.where(user_id: @card.id, paymenttype: 'Card')

    if check_user_for_cardgroup(@cg)
      if !admin? && @card.is_not_owned_by?(current_user)
        flash[:notice] = _('You_are_not_authorized_to_view_this_page')
        redirect_to(:root) && (return false)
      end
    end
  end

  # ======== CSV IMPORT =================

  def import_csv
    step_names = [
        _('Import_cards'), _('File_upload'), _('Column_assignment'), _('Column_confirmation'), _('Analysis'),
        _('Create_cards')
    ]
    @step = params[:step] ? params[:step].to_i : 0

    if @step <= 0 || @step > step_names.size
      flash[:notice] = _('Please_upload_file')
      redirect_to action: :new, cg: @cg.id
    end

    @step_name = step_names[@step]
    @page_title = _('Import_CSV') + '&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;' + _('Step') + ': ' + @step.to_s +
      '&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;' + @step_name.to_s
    @page_icon = 'excel.png'

    @sep, @dec = Application.nice_action_session_csv(params, session, correct_owner_id)

    if @step == 1
      my_debug_time 'step 1'
      session[:temp_card_import_csv] = nil
      session[:card_import_csv] = nil

      if params[:file]
        @file = params[:file]

        if @file.present?
          if !@file.respond_to?(:original_filename) || !@file.respond_to?(:read) || !@file.respond_to?(:rewind)
            flash[:notice] = _('Please_select_file')
            redirect_to(action: :new, cg: @cg.id) && (return false)
          end

          unless get_file_ext(@file.original_filename, 'csv')
            @file.original_filename
            flash[:notice] = _('Please_select_CSV_file')
            redirect_to(action: :new, cg: @cg.id) && (return false)
          end

          @file.rewind
          file = @file.read
          session[:card_file_size] = file.size
          session[:temp_card_import_csv] = CsvImportDb.save_file('_crd_', file)
          flash[:status] = _('File_downloaded')
          redirect_to(action: :import_csv, step: 2, cg: @cg.id) && (return false)
        else
          session[:temp_card_import_csv] = nil
          flash[:notice] = _('Please_select_file')
          redirect_to(action: :new, cg: @cg.id) && (return false)
        end
      else
        session[:temp_card_import_csv] = nil
        flash[:notice] = _('Please_upload_file')
        redirect_to(action: :new, cg: @cg.id) && (return false)
      end
    end

    if @step == 2
      my_debug_time "step 2\nuse : #{session[:temp_card_import_csv]}"

      if session[:temp_card_import_csv]
        file = CsvImportDb.head_of_file("/tmp/#{session[:temp_card_import_csv]}.csv", 20).join('')
        session[:file] = file

        if check_csv_file_seperators(file, 2, 2, {cg: @cg, line: 0})
          @fl = CsvImportDb.head_of_file("/tmp/#{session[:temp_card_import_csv]}.csv", 1).join('').split(@sep)
          begin
            colums = {
                colums: [
                    {name: 'f_error', type: 'INT(4)', default: 0},
                    {name: 'nice_error', type: 'INT(4)', default: 0},
                    {name: 'do_not_import', type: 'INT(4)', default: 0},
                    {name: 'changed', type: 'INT(4)', default: 0},
                    {name: 'not_found_in_db', type: 'INT(4)', default: 0},
                    {name: 'id', type: 'INT(11)', inscrement: ' NOT NULL auto_increment '}
                ]
            }
            session[:card_import_csv] =
                CsvImportDb.load_csv_into_db(session[:temp_card_import_csv], @sep, @dec, @fl, nil, colums, false)
            @lines_number =
                ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{session[:card_import_csv]}")
          rescue => e
            MorLog.log_exception(e, Time.now.to_i, params[:controller], params[:action])
            session[:import_csv_card_import_csv_options] = {
                sep: @sep,
                dec: @dec
            }
            session[:file] = File.open("/tmp/#{session[:temp_card_import_csv]}.csv", 'rb').read
            CsvImportDb.clean_after_import(session[:temp_card_import_csv])
            session[:temp_card_import_csv] = nil
            redirect_to(action: :import_csv, step: 2, cg: @cg.id) && (return false)
          end

          flash[:status] = _('File_uploaded') unless flash[:notice]
        end
      else
        session[:card_import_csv] = nil
        flash[:notice] = _('Please_upload_file')
        redirect_to(action: :import_csv, step: 1, cg: @cg.id) && (return false)
      end
    end

    if @step > 2
      unless ActiveRecord::Base.connection.tables.include?(session[:temp_card_import_csv])
        flash[:notice] = _('Please_upload_file')
        redirect_to(action: :new, cg: @cg.id) && (return false)
      end

      if session[:card_import_csv]
        if @step == 3
          my_debug_time 'step 3'

          if params[:number_id] && params[:pin_id] && params[:number_id].to_i >= 0 && params[:pin_id].to_i >= 0
            @options = {
                imp_number: params[:number_id].to_i,
                imp_pin: params[:pin_id].to_i,
                imp_balance: params[:balance_id].to_i,
                imp_language: params[:language_id].to_i,
                sep: @sep, dec: @dec,
                file: session[:file],
                file_lines: ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{session[:card_import_csv]}")
            }

            @lines_number = @options[:file_lines]

            session[:card_import_csv2] = @options
            flash[:status] = _('Columns_assigned')
          else
            flash[:notice] = _('Please_Select_Columns')
            redirect_to(action: :import_csv, step: 2, cg: @cg.id) && (return false)
          end
        end

        if session[:card_import_csv2] && session[:card_import_csv2][:imp_pin] && session[:card_import_csv2][:imp_number]
          if @step == 4
            my_debug_time 'step 4'
            @card_analize = @cg.analize_card_import(session[:temp_card_import_csv], session[:card_import_csv2])
            session[:card_analize] = @card_analize

            # If calling card addon is not active than there is a limmit of 10 cards.
            unless cc_active?
              cards_to_import = 10 - Card.where(cardgroup_id: @cg.id).size
              session[:card_import_csv2][:limit] = (cards_to_import < 0) ? 0 : cards_to_import
              session[:card_analize][:cards_number] = cards_to_import
            end
          end

          if @step == 5
            my_debug_time 'step 5'
            start_time = Time.now
            @card_analize = session[:card_analize]
            @run_time = 0

            begin
              @total_cards, @errors =
                  @cg.create_from_csv(current_user, session[:temp_card_import_csv], session[:card_import_csv2])
              flash[:status] = _('Import_completed')
              session[:temp_card_import_csv] = nil
              @run_time = Time.now - start_time
            rescue => e
              flash[:notice] = _('Error')
              MorLog.log_exception(e, Time.now, 'Cards', 'csv_import')
            end
          end
        else
          flash[:notice] = _('Please_Select_Columns')
          redirect_to(action: :import_csv, step: 2, cg: @cg.id) && (return false)
        end
      else
        flash[:notice] = _('Zero_file')
        redirect_to(controller: :cards, action: :list, cg: @cg.id) && (return false)
      end
    end
  end

  def bad_cards
    @page_title = _('bad_cards')
    if ActiveRecord::Base.connection.tables.include?(session[:temp_card_import_csv])
      @rows =
          ActiveRecord::Base.connection.select_all("SELECT * FROM #{session[:temp_card_import_csv]} WHERE f_error = 1")
    end
  end

  # Allows admin to buy calling cards.
  def card_buy
    @page_title = _('Buy_Card')
    @page_icon = 'money.png'

    @email = params[:email]
    @real_price = @card.balance + @cg.get_tax.count_tax_amount(@card.balance)
    @send_invoice = params[:send_invoice]
    @total_tax_name = Confline.get_value('Total_tax_name')
    @description = params[:description].to_s
  end

  def card_buy_finish
    if @card.sold.to_i == 1
      flash[:notice] = _('Card_is_already_sold')
      redirect_to(action: :card_pay, id: @card.id, cg: @cg.id) && (return false)
    end

    unless @card.sell(session[:show_currency], correct_owner_id, params[:description])
      flash_errors_for(_('Can_not_sell_invalid_card'), @card)
      redirect_to(action: :list, cg: @cg) && (return false)
    end

    finalize_purchase

    flash[:status] = _('Card_is_sold')
    redirect_to(action: :list, id: @card.id, cg: @cg.id) && (return false)
  end

  def card_active
    if @card.user_id != current_user_id
      dont_be_so_smart
      redirect_to(:root) && (return false)
    else
      card_activation(@card)

      Action.add_action_hash(
          current_user, {action: 'Card activation', data: @card.active.to_i, target_id: @card.id, target_type: 'Card'}
      )
      flash[:status] = @card.active == 1 ? _('Cards_are_activated') : _('Cards_are_deactivated')
      link_to = {action: :user_list, controller: :cards}
      link_to.merge!(params[:back_to].to_hash) unless params[:back_to].blank?
      redirect_to(controller: link_to[:controller], action: link_to[:action], cg: params[:cg]) && (return false)
    end
  end

  def bullk_for_activate
    if user?
      cg = Cardgroup.where(id: params[:cg].to_i).first

      unless cg
        flash[:notice] = _('Cardgroup_was_not_found')
        redirect_to(:root) && (return false)
      end
    end
  end

  def bulk_confirm
    find_start_and_end_numbers

    @activate = params[:activate].to_i

    if @start_num.to_i == 0 || @end_num.to_i == 0
      flash[:notice] = _('Bad_number_length_should_be')
      redirect_to(action: :bullk_for_activate, cg: params[:cg].to_i) && (return false)
    end

    @list_second = Card.where(
        'number >= ? AND number <= ? AND active = 1 AND user_id = ?',
        @start_num, @end_num, current_user_id
    ).size

    @list = Card.where(
        'number >= ? AND number <= ? AND active = 0 AND user_id = ?',
        @start_num, @end_num, current_user_id
    ).size

    @a_name = @activate.to_i == 1 ? _('Activate') : _('Disable')
  end

  def card_active_bulk
    start_num = params[:start].to_i <= params[:end].to_i ? params[:start] : params[:end]
    end_num = params[:end].to_i >= params[:start].to_i ? params[:end] : params[:start]
    action = params[:activate_i].to_i
    search_action = action.zero? ? 1 : 0

    cards = Card.where(
        'number >= ? AND number <= ? AND active = ? AND user_id = ?',
        start_num, end_num, search_action, current_user_id
    ).all

    cards.each { |card| card_activation(card) }

    flash[:status] = action.to_i == 1 ? _('Card_is_activated') : _('Card_is_deactivated')
    redirect_to(action: :user_list, cg: params[:cg].to_i) && (return false)
  end

  private

  def generate_order_string(prefix = '', options)
    order_string = ''

    if options[:order_desc].present? && options[:order_by].present?
      order_string << "#{options[:order_by].gsub(prefix, '')} #{options[:order_desc].to_i.zero? ? 'ASC' : 'DESC'}"
    end
  end

  # Checks if reseller or accounant is allowed to edit cardgroups.
  def check_user_for_cardgroup(cardgroup)
    cardgroup_owner_id = cardgroup.owner_id
    current_user_not_cardgroup_owner = (cardgroup_owner_id != session[:user_id])

    if (accountant? && ((cardgroup_owner_id != 0) || (session[:acc_callingcard_manage].to_i == 0))) ||
      (reseller? && (current_user_not_cardgroup_owner || (session[:res_calling_cards].to_i != 2))) ||
      (admin? && current_user_not_cardgroup_owner)
        dont_be_so_smart
        redirect_to(:root) && (return false)
    end

    true
  end

  def find_cardgruop
    @cg = Cardgroup.includes(:tax).where(id: params[:cg]).first

    if !@cg || (user? && !Card.where(user_id: session[:user_id], cardgroup_id: params[:cg].to_i).first.present?)
      flash[:notice] = _('Cardgroup_was_not_found')
      redirect_to(:root) && (return false)
    end

     check_user_for_cardgroup(@cg)
  end

  def find_card
    query_conditions = {id: params[:id], hidden: 0}
    query_conditions[:cardgroup_id] = params[:cg] if params[:cg]
    @card = Card.where(query_conditions).includes(:cardgroup, :user).first

    unless @card
      flash[:notice] = _('Card_was_not_found')
      redirect_to(controller: :cardgroups, action: :list) && (return false)
    end
  end

  def check_distrobutor
    if params[:card] && params[:card][:user_id]
      dis = User.where(id: params[:card][:user_id]).first

      if reseller?
        if dis.try(:id) != current_user_id && dis.try(:owner_id) != correct_owner_id
          dont_be_so_smart
          redirect_to(:root) && (return false)
        end
      else
        if dis.try(:owner_id) != correct_owner_id
          dont_be_so_smart
          redirect_to(:root) && (return false)
        end
      end
    end
  end

  def check_distrobutor_cards
    if current_user.try(:cards).blank?
      flash[:notice] = _('You_have_no_view_permission')
      redirect_to(:root) && (return false)
    end
  end

  def allow_add_cards?
    if !calling_cards_active? && Card.where(cardgroup_id: @cg.id).size >= 10
      flash[:notice] = _('You_have_no_view_permission')
      redirect_to(:root) && (return false)
    end
  end

  def card_activation(card)
    status = card.active.to_i.zero? ? 1 : 0
    [:active, :sold].each { |attribute| card[attribute] = status }
    card.save
  end

  def finalize_purchase
    creation_time = Time.now
    @email = params[:email].to_s

    invoice = CcInvoice.new(
        owner_id: session[:user_id],
        number: CcInvoice.get_next_number(session[:user_id]),
        sent_email: 0,
        sent_manually: 0,
        paid: 1,
        created_at: creation_time,
        paid_date: creation_time,
        email: @email
    )
    card_balance = @card.balance
    amount = card_balance + @cg.get_tax.count_tax_amount(card_balance)

    ccorder = Ccorder.create(
        ordertype: 'manual',
        email: @email,
        currency: session[:show_currency],
        amount: amount,
        payer_email: @email,
        date_added: creation_time,
        shipped_at: creation_time,
        completed: 1,
        tax: @cg.get_tax.count_tax_amount(@card.balance),
        gross: card_balance
    )

    Cclineitem.create(
        cardgroup_id: @cg.id, quantity: '1', ccorder_id: ccorder.id, card_id: @card.id, price: card_balance
    )

    invoice.ccorder = ccorder
    invoice.save

    if params[:send_invoice].to_i == 1
      options = {
          title_fontsize: 13,
          title_fontsize1: 16,
          title_fontsize2: 9,
          address_fontsize: 8,
          fontsize: 7,
          tax_fontsize: 7,
          # Header/address text
          address_pos1: 40, title_pos0: 43,
          address_pos2: 70, title_pos1: 75,
          address_pos3: 85, title_pos2: 90,
          address_pos4: 100,
          address_pos5: 115,

          left: 40,
          title_left2: 330,
          item_line_height: 20,
          item_line_add_y: 3,
          item_line_add_x: 6,
          line_y: 140,
          length: 520,
          item_line_start: 220,
          lines: 20,
          col1_x: 320,
          col2_x: 390,
          col3_x: 470,
          tax_box_h: 11,
          tax_box_text_add_y: 1,
          tax_box_text_x: 360,
          bank_details_step: 15
      }
      PdfGen::Generate.generate_cc_invoice(invoice, options)
      invoice.save
    end
  end

  def update_option(key, value, condition = (params[:clean] || !session[:cards_list_options]))
    if params[key]
      @options[key] = value.is_a?(Integer) ? params[key].to_i : params[key].to_s.strip
    else
      @options[key] = value if condition
    end
  end

  def find_start_and_end_numbers
    params_start_number, params_end_number = [params[:start_number], params[:end_number]]
    params_start_number_int, params_end_number_int = [params_start_number.to_i, params_end_number.to_i]

    @start_num = (params_start_number_int <= params_end_number_int) ? params_start_number : params_end_number
    @end_num = (params_end_number_int >= params_start_number_int) ? params_end_number : params_start_number
  end
end
