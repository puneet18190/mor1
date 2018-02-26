# -*- encoding : utf-8 -*-
# Vouchers are used to fill the balance of a user.
class VouchersController < ApplicationController
  layout 'callc'

  before_filter :check_localization
  before_filter :authorize
  before_filter :check_if_can_see_finances, only: [:vouchers, :voucher_new, :voucher_delete]
  before_filter :find_voucher, only: [:voucher_pay]
  before_filter { |method|
    method.instance_variable_set :@allow_read, true
    method.instance_variable_set :@allow_edit, true
  }

  @@voucher_view = [:vouchers]
  @@voucher_edit = [:vouchers_new, :vouchers_create, :voucher_delete, :bulk_management]
  before_filter(only: @@voucher_view + @@voucher_edit) { |method|
    allow_read, allow_edit = method.check_read_write_permission(@@voucher_view, @@voucher_edit,
      { role: 'accountant', right: :acc_vouchers_manage, ignore: true }
    )
    method.instance_variable_set :@allow_read, allow_read
    method.instance_variable_set :@allow_edit, allow_edit
    true
  }
  before_filter :find_vouchers, only: [:voucher_delete, :voucher_active]

  def vouchers
    @page_title = _('Vouchers')
    @default = {
        page: 1, s_usable: 'all', s_active: 'all', s_number: '', s_tag: '', s_credit_min: '', s_credit_max: '',
        s_curr: '', s_use_date: '', s_active_till: ''
    }

    @options = session[:vouchers_vouchers_options] || @default
    session_items_per_page = session[:items_per_page]
    # search

    params_page = params[:page]
    params_s_usable = params[:s_usable]
    params_s_active = params[:s_active]
    params_s_number = params[:s_number]
    params_s_tag = params[:s_tag]
    params_s_credit_min = params[:s_credit_min]
    params_s_credit_max = params[:s_credit_max]
    params_s_curr = params[:s_curr]
    params_s_use_date = params[:s_use_date]
    params_s_active_till = params[:s_active_till]
    if params[:clean]
      @options = @default
    else
      @options[:page] = params_page.to_i if params_page
      @options[:s_usable] = params_s_usable.to_s if params_s_usable
      @options[:s_active] = params_s_active.to_s if params_s_active
      @options[:s_number] = params_s_number.to_s if params_s_number
      @options[:s_tag] = params_s_tag.to_s if params_s_tag
      @options[:s_credit_min] = params_s_credit_min.to_s if params_s_credit_min
      @options[:s_credit_max] = params_s_credit_max.to_s if params_s_credit_max
      @options[:s_curr] = params_s_curr.to_s if params_s_curr
      @options[:s_use_date] = params_s_use_date.to_s if params_s_use_date
      @options[:s_active_till] = params_s_active_till.to_s if params_s_active_till
    end

    options_s_usable = @options[:s_usable].to_s
    options_s_active = @options[:s_active].to_s
    options_s_credit_min = @options[:s_credit_min]
    options_s_credit_max = @options[:s_credit_max]
    options_s_curr = @options[:s_curr]

    cond = ['vouchers.id > 0']
    var = []

    if options_s_active.downcase != 'all'
      cond << (options_s_active == 'yes' ? 'vouchers.active = 1' : 'vouchers.active = 0')
    end

    time_now = Time.now
    if options_s_usable.downcase != 'all'
      is_active = '(NOT ISNULL(use_date) OR active_till < ?)'

      if options_s_usable == 'yes'
        cond << "(NOT (#{is_active}) AND active = 1)"
      else
        cond << "NOT (NOT (#{is_active}) AND active = 1)"
      end
      var << current_user.user_time(time_now)
    end

    %w[number tag].each do |col|
      add_contition_and_param(@options["s_#{col}".to_sym],
                              '%' + @options["s_#{col}".intern].to_s + '%', "vouchers.#{col} LIKE ?", cond, var
      )
    end

    %w[use_date active_till].each do |col|
      add_contition_and_param(@options["s_#{col}".to_sym],
                              @options["s_#{col}".intern].to_s + '%', "vouchers.#{col} LIKE ?", cond, var
      )
    end

    if options_s_credit_min.present?
      cond << 'credit_with_vat >= ?'; var << options_s_credit_min
    end

    if options_s_credit_max.present?
      cond << 'credit_with_vat <= ?'; var << options_s_credit_max
    end

    if options_s_curr.present?
      cond << 'currency = ?'; var << options_s_curr
    end

    @total_vouchers = Voucher.where([cond.join(' AND ')]+var).order('use_date DESC, active_till ASC').size
    MorLog.my_debug("TW: #{@total_vouchers}")
    @fpage, @total_pages, @options = Application.pages_validator(session, @options, @total_vouchers)

    @vouchers = Voucher.includes([:tax, :user]).where([cond.join(' AND ')] + var).
        order('use_date DESC, active_till ASC').limit("#{@fpage}, #{session_items_per_page.to_i}").all

    @search = 0
    @search = 1 if cond.length > 0

    @use_dates = Voucher.get_use_dates
    @active_tills = Voucher.get_active_tills
    @currencies = Voucher.get_currencies

    session[:vouchers_vouchers_options] = @options

    if params[:csv] and params[:csv].to_i > 0
      sep = Confline.get_value('CSV_Separator', 0).to_s
      dec = Confline.get_value('CSV_Decimal', 0).to_s
      @vouchers = Voucher.includes([:tax, :user]).where([cond.join(' AND ')] + var).order('use_date DESC, active_till ASC').all
      csv_string = _('Active') + sep + _('Number') + sep + _('Tag') + sep + _('Credit') + sep + _('Credit_with_VAT') +
        sep + _('Currency') + sep + _('Use_date') + sep + _('Active_till') + sep + _('User')
      csv_string += "\n"
      @vouchers.each do |voucher|
        user = voucher.user
        active_till = voucher.active_till
        use_date = voucher.use_date
        active = 1
        active = 0 if use_date
        active = 0 if active_till.to_s < time_now.to_s
        user ? nuser = nice_user(user) : nuser = ""
        csv_string += "#{active.to_s}#{sep}#{voucher.number.to_s}#{sep}#{voucher.tag.to_s}#{sep}"
        if can_see_finances?
          csv_string += "#{nice_number(voucher.count_credit_with_vat).to_s.gsub('.', dec).to_s}#{sep}#{nice_number(voucher.credit_with_vat).to_s.gsub(".", dec).to_s}#{sep}#{voucher.currency}#{sep}"
        end
        csv_string += "#{nice_date_time use_date}#{sep}#{nice_date(active_till).to_s}#{sep}#{nuser}"
        csv_string +="\n"
      end

      filename = 'Vouchers.csv'
      if params[:test].to_i == 1
        render(text: csv_string)
      else
        send_data(csv_string, type: 'text/csv; charset=utf-8; header=present', filename: filename)
      end
    end
  end

  def voucher_new
    @page_title, @page_icon = _('Add_vouchers'), 'add.png'
    @currencies, @tax = Currency.get_active, Confline.get_default_tax(session[:user_id])
    @amaunt, @credit, @tag, @curr = '', '', '', ''
  end

  def vouchers_create
    @page_title, @page_icon = _('New_vouchers'), 'add.png'
    tax = tax_from_params
    change_date_from

    params_credit = params[:credit]
    params_tag = params[:tag]
    params_currency = params[:currency]
    params_amount_total = params[:amount_total]

    @vouchers = []

    credit_not_positive = (params_credit.to_d <= 0)
    active_currency = Currency.get_active

    time_now = Time.now
    time_formated = time_now.strftime('%Y%m%d%H%M%S')
    time_date = time_now.to_date
    time_date_comparison = session_from_date.to_date <= time_date

    voucher_number_length = confline('Voucher_Number_Length').to_i
    voucher_number_generated = voucher_number(voucher_number_length)

    if credit_not_positive || time_date_comparison
      @amaunt = params_amount_total
      @credit = params_credit
      @tag = params_tag
      @curr = params_currency
      @currencies = active_currency
      @tax = Tax.new(tax)
      if credit_not_positive
        flash[:notice] = _('Please_enter_credit')
        render(:voucher_new) && (return false)
      end
      if time_date_comparison
        flash[:notice] = _('Time_should_be_in_future')
        render(:voucher_new) && (return false)
      end
    end

    amount = params[:amount]

    params_tag_lenght_positive = (params_tag.length > 0)

    if amount == 'one'
      # One voucher
      voucher = Voucher.new(
        number: voucher_number(voucher_number_length),
        tag: params_tag_lenght_positive ? params_tag : time_formated,
        credit_with_vat: params_credit.to_d,
        currency: params_currency,
        active_till: session_from_date,
        user_id: -1
      )
      voucher.save
      voucher.tax = Tax.new(tax)
      voucher.tax.save
      if voucher.save
        flash[:status] = _('Voucher_was_created')
      end
      @vouchers << voucher
    else
      # Many vouchers
      total = params_amount_total.to_i

      if total <= 0
        @amaunt = params_amount_total
        @credit = params_credit
        @tag = params_tag
        @curr = params_currency
        @currencies = active_currency
        @tax = Tax.new(tax)
        flash[:notice] = _('Please_enter_amount')
        render(:voucher_new) && (return false)
      end

      (1..total).each do
        voucher = Voucher.new(
          number: voucher_number(voucher_number_length),
          tag: params_tag_lenght_positive ? params_tag : time_formated,
          credit_with_vat: params_credit.to_d,
          currency: params_currency,
          active_till: session_from_date,
          user_id: -1
        )
        voucher.tax = Tax.new(tax)
        voucher.tax.save
        voucher.save
        @vouchers << voucher
      end
      flash[:status] = _('Vouchers_was_created')
    end
  end

  def voucher_use
    @page_title = _('Voucher')

    @user = current_user
    user_vouchers_disabled_till = current_user.vouchers_disabled_till
    time_now = Time.now

    if user_vouchers_disabled_till > time_now
      flash[:notice] = _('Vouchers_disabled_till') + ': ' + nice_date_time(user_vouchers_disabled_till)
      redirect_to :root
    end

    if Confline.get_value('Vouchers_Enabled').to_i == 0
      flash[:notice] = _('Vouchers_disabled')
      redirect_to :root
    end

    if session[:voucher_attempt] >= Confline.get_value('Voucher_Attempts_to_Enter').to_i &&
        user_vouchers_disabled_till < time_now + confline('Voucher_Disable_Time').to_i.minutes
      session[:voucher_attempt] = 0
    end
  end

  def voucher_status
    @page_title = _('Voucher')

    not_found_notice = _('Voucher_not_found')
    @number = params[:number]
    @voucher = Voucher.where(number: @number).first
    unless @voucher
      flash[:notice] = not_found_notice
      redirect_to(:root) && (return false)
    end
    unless @voucher.active.to_i == 1
      flash[:notice] = _('Voucher_is_inactive_please_contact_system_Administrator')
      redirect_to(:root) && (return false)
    end
    if Confline.get_value('Vouchers_Enabled').to_i == 0
      flash[:notice] = _('Vouchers_disabled')
      redirect_to :root
    end
    @user = User.where(id: session[:user_id]).first

    user_vouchers_disabled_till = @user.vouchers_disabled_till
    time_now = Time.now

    if user_vouchers_disabled_till > time_now
      flash[:notice] = _('Vouchers_disabled_till') + ': ' + nice_date_time(user_vouchers_disabled_till)
      redirect_to :root
    end

    if @voucher.present?
      @credit_without_vat = @voucher.get_tax.count_amount_without_tax(@voucher.credit_with_vat)
      @credit_in_default_currency = @credit_without_vat * count_exchange_rate(@voucher.currency, session[:default_currency])
      @balance_after_use = (@user.raw_balance + @credit_in_default_currency) * count_exchange_rate(session[:default_currency], @user.currency)
    else
      session[:voucher_attempt] += 1
    end

    if session[:voucher_attempt] >= Confline.get_value('Voucher_Attempts_to_Enter').to_i &&
                                                                          user_vouchers_disabled_till< time_now

      @user.vouchers_disabled_till = time_now + Confline.get_value('Voucher_Disable_Time').to_i.minutes
      @user.save
      flash[:notice] = _('Too_many_wrong_attempts_Vouchers_disabled_till') + ': ' + nice_date_time(@user.vouchers_disabled_till)
      redirect_to(:root) && (return false)
    end

    @active = 0

    if @voucher.present?
      voucher = @voucher
      @active = 1
      @active = 0 if voucher.use_date
      @active = 0 if voucher.active_till < time_now
    end

    flash[:notice] = not_found_notice if @active == 0
  end

  def voucher_pay
    @user = current_user

    user_vouchers_disabled_till = @user.vouchers_disabled_till
    time_now = Time.now

    if user_vouchers_disabled_till > time_now
      flash[:notice] = _('Vouchers_disabled_till') + ': ' + nice_date_time(user_vouchers_disabled_till)
      redirect_to(:root) && (return false)
    end

    if @voucher.try(:is_active).to_i == 0
      flash[:notice] = _('Voucher_not_found')
      (redirect_to :root) && (return false)
    end

    @voucher.make_voucher_payment(@user)

    flash[:status] = _('Voucher_used_to_update_balance_thank_you')
    redirect_to :root
  end

  def bulk_management
    params_v_active = params[:v_active]
    params_v_credit_min = params[:v_credit_min]
    params_v_credit_max = params[:v_credit_max]
    params_v_atill = params[:v_atill]
    params_vaction = params[:vaction]
    params_v_tag = params[:v_tag]

    @page_title = _('Bulk_management')
    @page_icon = 'edit.png'
    @tag = params_v_tag if params_v_tag
    @active = params_v_active if params_v_active
    @credit_min = params_v_credit_min.to_i if params_v_credit_min
    @credit_max = params_v_credit_max.to_i if params_v_credit_max
    @atill = params_v_atill if params_v_atill
    @action = params_vaction if params_vaction
    @tags = Voucher.get_tags
    @active_tills = Voucher.get_active_tills
  end

  def vouchers_interval
    params_v_active = params[:v_active]
    params_v_credit_min =  params[:v_credit_min]
    params_v_credit_max = params[:v_credit_max]
    params_v_atill = params[:v_atill]
    params_vaction = params[:vaction]
    params_v_tag = params[:v_tag]

    @page_title = _('Delete_Vouchers_interval')
    @page_icon = 'edit.png'

    @tag = params_v_tag.to_s if params_v_tag
    @active = params_v_active if params_v_active
    @credit_min = params_v_credit_min.to_i if params_v_credit_min.present?
    @credit_max = params_v_credit_max.to_i if params_v_credit_max.present?
    if params_v_atill
      @atill = params_v_atill.to_s
      atill_string_length = @atill.length > 0
    end
    @action = params_vaction if params_vaction

    today = nice_date_time(Time.now)

    cond = ''
    cond << " ISNULL(use_date) AND active_till >= '#{today}' " if @active == 'yes'
    cond << " NOT (ISNULL(use_date) AND active_till >= '#{today}') " if @active == 'no'

    tag_length = @tag.length > 0
    cond << ' AND ' if cond.length > 0 && tag_length
    cond << " tag = '#{@tag}' " if tag_length

    # Credit
    credit_min_local = @credit_min.to_i
    credit_max_local = @credit_max.to_i
    credit_min_length = @credit_min.to_s.length
    credit_min_length_positive = (credit_min_length > 0)
    credit_max_length = @credit_max.to_s.length
    credit_max_length_positive = (credit_max_length > 0)
    credit_min_max_local = credit_min_local <= credit_max_local

    cond << ' AND ' if cond.length > 0 && credit_min_length_positive
    cond << " credit_with_vat #{credit_min_max_local ? '>=' : '<=' } #{credit_min_local} " if credit_min_length_positive

    cond << ' AND ' if cond.length > 0 && credit_max_length_positive
    cond << " credit_with_vat #{credit_min_max_local ? '<=' : '>=' } #{credit_max_local} " if credit_max_length_positive

    cond << ' AND ' if cond.length > 0 && atill_string_length
    cond << " active_till LIKE '#{@atill}%' " if atill_string_length

    @vouchers = Voucher.where(cond).to_a if cond.present?

    session[:vouchers_bulk] = @vouchers
  end

  def voucher_delete
    # @vouchers set in before_filter
    vouchers_deleted = 0
    @vouchers.each { |voucher| vouchers_deleted += 1 if voucher.destroy }
    vouchers_deleted_zero = (vouchers_deleted == 0)

    if params[:interval].to_i == 1
      if vouchers_deleted_zero
        flash[:notice] = _('Vouchers_interval_was_not_deleted')
      else
        flash[:status] = _('Vouchers_interval_deleted')
      end
    else
      if vouchers_deleted_zero
        flash_errors_for(_('Voucher_was_not_deleted'), @vouchers[0])
      else
        flash[:status] = _('Voucher_deleted')
      end
    end

    redirect_to(action: :vouchers)
  end

  def voucher_active
    # @vouchers set in before_filter
    params_page = params[:page]

    vouchers_bulk_not_blank = session[:vouchers_bulk].present?
    id_positive = (params[:id].to_i > 0)

    @page = params_page if params_page
    @active =
        if params[:interval].to_i == 1
          params[:vaction].to_s == 'active' ? 1 : 0
        else
          @vouchers[0].active.to_i == 1 ? 0 : 1
        end

    sql = "UPDATE vouchers SET active = #{@active} WHERE id IN (#{@vouchers.map { |voucher| [voucher.id] }.join(',')})"
    ActiveRecord::Base.connection.update(sql)

    flash[:status] =
        if @active == 1
          if vouchers_bulk_not_blank || id_positive
            _('Vouchers_interval_activated')
          else
            _('No_Vouchers_found_to_activate')
          end
        else
          if vouchers_bulk_not_blank || id_positive
            _('Vouchers_interval_deactivated')
          else
            _('No_Vouchers_found_to_deactivate')
          end
        end
    redirect_to(action: :vouchers, page: @page)
  end

  private

  def find_vouchers
    params_action = params[:action].to_s
    params_vaction = params[:vaction].to_s
    params_interval = params[:interval].to_i == 1

    session_vouchers_bulk = session[:vouchers_bulk]

    action_voucher_active = (params_action == 'voucher_active')
    action_voucher_delete = (params_action == 'voucher_delete')
    vaction_active = (params_vaction == 'active')

    @vouchers = []
    if params_interval
      if session_vouchers_bulk != nil
        @vouchers = Voucher.where('id IN (?)', session_vouchers_bulk).to_a
      end
    else
      @vouchers << Voucher.where(id: params[:id].to_i).first
    end
    @vouchers.compact!

    if @vouchers.blank?
      if params_interval
        flash[:notice] = _('No_Vouchers_found_to_delete') if action_voucher_delete
        flash[:notice] = _('No_Vouchers_found_to_activate') if action_voucher_active && vaction_active
        flash[:notice] = _('No_Vouchers_found_to_deactivate') if action_voucher_active && !vaction_active
      else
        flash[:notice] = _('Voucher_not_found')
      end
      redirect_to(action: :vouchers)
    end
  end

  def find_voucher
    @voucher = Voucher.where(id: params[:id].to_i).first

    unless @voucher
      flash[:notice] = _('Voucher_not_found')
      redirect_to(:root) && (return false)
    end
  end
end
