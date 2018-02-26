# -*- encoding : utf-8 -*-
# MOR accounting stuff.
class AccountingController < ApplicationController
  layout 'callc'
  require 'csv'
  before_filter :check_post_method, only: [:invoice_recalculate, :update_invoice_details, :invoice_delete, :delete_all]
  before_filter :check_localization
  before_filter :authorize
  before_filter :check_if_can_see_finances, only: [:vouchers, :vouchers_list_to_csv, :voucher_new, :voucher_create,
                                                      :voucher_delete]
  before_filter { |method|
    method.instance_variable_set :@allow_read, true
    method.instance_variable_set :@allow_edit, true
  }

  @@voucher_view = [:vouchers, :vouchers_list_to_csv]
  @@voucher_edit = [:vouchers_new, :vouchers_create, :voucher_delete, :bulk_management]

  before_filter(only: @@voucher_view + @@voucher_edit) { |method|
    allow_read, allow_edit =
        method.
            check_read_write_permission(@@voucher_view,
                                        @@voucher_edit,
                                        {role: 'accountant',
                                         right: :acc_vouchers_manage, ignore: true})
    method.instance_variable_set :@allow_read, allow_read
    method.instance_variable_set :@allow_edit, allow_edit
    true
  }

  @@invoice_view = [:invoices]
  @@invoice_edit = [:generate_invoices]
  before_filter(only: @@invoice_view + @@invoice_edit) { |method|
    allow_read, allow_edit =
        method.
            check_read_write_permission(@@invoice_view,
                                        @@invoice_edit,
                                        {role: 'accountant',
                                         right: :acc_invoices_manage, ignore: true})
    method.instance_variable_set :@allow_read, allow_read
    method.instance_variable_set :@allow_edit, allow_edit
    true
  }

  before_filter :find_invoice, only: [:invoice_recalculate, :export_invoice_to_xlsx]
  before_filter :find_invoice_new, only: [:invoice_details_list, :user_invoice_details, :generate_invoice_by_cid_pdf,
     :generate_invoice_detailed_csv, :generate_invoice_destinations_csv, :generate_invoice_csv, :generate_invoice_pdf]
  before_filter :number_separator

  def index
    redirect_to(action: 'user_invoices')
  end

  def index_main
    dont_be_so_smart
    redirect_to(:root) && (return false)
  end

  def generate_invoices
    @type = 'postpaid'
    @page_title = _('Generate_invoices')
    @page_icon = 'application_go.png'

    @options = {}
    @options[:currencies] = Currency.select(:name).where(active: 1).all.map(&:name)
    @options[:default_currency] = User.current.currency.try(:name)

    @post = 1
    @pre = 0
  end

  def generate_invoices_to_prepaid_users
    @page_title = _('Generate_invoices_to_prepaid_users')
    @page_icon = 'application_go.png'
  end

  # ================== sending invoices =============================
  def send_invoices
    change_date
    @options = session[:invoice_options] || {}

    [
      :s_username, :s_first_name, :s_last_name, :s_number, :s_period_start, :s_period_end,
      :s_issue_date, :s_sent_email, :s_sent_manually, :s_paid, :s_invoice_type
    ].each do |key|
      @options[key] = params[key].try(:to_s).try(:strip) || @options[key].to_s
    end

    @invoices = Invoice.for_send(corrected_user_id, @options)

    MorLog.my_debug("*************Invoice sending, found : #{@invoices.size.to_i}", 1)

    @number = 0
    not_sent = 0

    params[:email_or_not] = 1
    session[:invoice_options] = @options
    email_from = Confline.get_value('Email_from', correct_owner_id)

    if @invoices.size.to_i > 0
      @invoices.each { |invoice|
        user = invoice.user
        attach = []
        params[:id] = invoice.id
        prepaid = invoice.invoice_type.to_s == 'prepaid' ? 'Prepaid_' : ''
        @invoice = user.send_invoice_types.to_i
        if @invoice.to_i != 0
          if (user.email).length > 0
            @invoice -= if @invoice >= 512
                          xlsx = {
                            file: export_invoice_to_xlsx,
                            content_type: 'application/octet-stream',
                            filename: "#{_('invoice_xlsx')}.xlsx"
                          }
                          attach << xlsx
                          512
                        else
                          0
                        end

            if  !(user.postpaid == 0 && invoice.invoicedetails.first.try(:name).to_s == "Manual Payment")
              if (@invoice % 2) == 1
                @invoice = Confline.get_value("#{prepaid}Invoice_default",
                                              correct_owner_id).to_i
              end

              @invoice -= if @invoice >= 256
                            calls_cvs = {}
                            calls_cvs[:file] = get_prepaid_user_calls_csv(user, invoice)
                            calls_cvs[:content_type] = 'text/csv'
                            calls_cvs[:filename] = "#{_('Calls')}.csv"
                            attach << calls_cvs
                            256
                          else
                            0
                          end

              @invoice -= if @invoice >= 128
                            csv = {}
                            csv[:file] = generate_invoice_by_cid_csv
                            csv[:content_type] = 'text/csv'
                            csv[:filename] = "#{_('Invoice_by_CallerID_csv')}.csv"
                            attach << csv
                            128
                          else
                            0
                          end

              @invoice -= if @invoice >= 64
                            csv = {}
                            csv[:file] = generates_invoice_destinations_csv

                            unless csv[:file]
                              redirect_to :root unless performed?
                              return false
                            end

                            csv[:content_type] = 'text/csv'
                            csv[:filename] = "#{_('Invoice_destinations_csv')}.csv"
                            attach << csv
                            64
                          else
                            0
                          end

              @invoice -= if @invoice >= 32
                            pdf = {}
                            pdf[:file] = generate_invoice_by_cid_pdf
                            pdf[:content_type] = 'application/pdf'
                            pdf[:filename] = "#{_('Invoice_by_CallerID_pdf')}.pdf"
                            attach << pdf
                            32
                          else
                            0
                          end

              @invoice -= if @invoice >= 16
                            csv = {
                              file: generate_invoice_detailed_csv,
                              content_type: 'text/csv',
                              filename: "#{_('Invoice_detailed_csv')}.csv"
                            }
                            attach << csv
                            16
                          else
                            0
                          end

              @invoice -= if @invoice >= 8
                            pdf = {
                              file: generate_invoice_detailed_pdf,
                              content_type: 'application/pdf',
                              filename: "#{_('Invoice_detailed_pdf')}.pdf"
                            }
                            attach << pdf
                            8
                          else
                            0
                          end
            end

            @invoice -= if @invoice >= 4
                          csv = {
                            file: generate_invoice_csv,
                            content_type: 'text/csv',
                            filename: "#{_('Invoice_csv')}.csv"
                          }
                          attach << csv
                          4
                        else
                          0
                        end

            if @invoice >= 2
              pdf = {
                file: generate_invoice_pdf,
                content_type: 'application/pdf',
                filename: "#{_('Invoice_pdf')}.pdf"
              }
              attach << pdf
            end

            variables = email_variables(user)
            email= Email.where(["name = 'invoices' AND owner_id = ?", user.owner_id]).first
            MorLog.my_debug("Try send invoice to : #{user.address.email}, Invoice : #{invoice.id}, User : #{user.id}, Email : #{email.id}", 1)
            # @num = EmailsController.send_email_with_attachment(email, email_from,
            #                                                    user, attach, variables)
            variables = Email.email_variables(user)
            email.body = nice_email_sent(email, variables)

            @num = EmailsController.send_invoices(email, user.email.to_s,
                                                  email_from, attach,
                                                  invoice.number.to_s)

            MorLog.my_debug ("Invoice email was send to : #{user.address.email} ? : #{@num}")
            if @num == 'true'
              @number += 1
              invoice.sent_email = 1
              invoice.save
              Action.create_email_sending_action(user, 'email_sent', email)
            else
              not_sent += 1
              Action.create_email_sending_action(user, 'error', email,
                                                 {er_type: 1, err_message: @num})
            end
          else
            not_sent += 1
            email= Email.where(["name = 'invoices' AND owner_id = ?", user.owner_id]).first
            Action.create_email_sending_action(user, 'error', email, {er_type: 1})
          end
        end
      }
    end

    flash[:notice] = _('ERROR') + ': ' + @num[1].to_s if  @num && @num[0] == 0
    if @number.to_i > 0
      flash[:status] = _('Invoices_sent') + ': ' + @number.to_s
    else
      flash[:notice] = _('Invoices_not_sent') + ': ' + not_sent.to_s if  not_sent.to_i > 0
    end
    flash[:notice] = _('No_invoices_found_in_selected_period') if @invoices.size.to_i == 0
    redirect_to(action: :invoices) unless performed?
    return false
  end

  # ================= generate invoices ===============================
  def generate_invoices_status
    MorLog.my_debug " ********* \n for period #{session_from_date} - #{session_till_date}"
    change_date
    MorLog.my_debug "for period #{session_from_date} - #{session_till_date}"

    unless params[:invoice]
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
    owner_id = correct_owner_id
    if params[:date_issue].present?
      issue_date = Time.mktime(params[:date_issue][:year],
                               params[:date_issue][:month],
                               params[:date_issue][:day])
    end

    type = %W[postpaid prepaid user].include?(params[:invoice][:type].downcase)? params[:invoice][:type] : 'postpaid'

    from_time = Time.parse(session_from_datetime_no_timezone)
    till_time = Time.parse(session_till_datetime_no_timezone)

    if type == 'user'
      @user = User.where(['users.id = ?', params[:s_user_id]]).first if params[:s_user_id]
      unless @user
        flash[:notice] = _('User_not_found')
        redirect_to(action: :generate_invoices) && (return false)
      end
      valid_period = validate_period_user(@user, till_time)
    else
      valid_period = validate_period(type, till_time)
    end

    redirect_to(action: :generate_invoices) && (return false) unless valid_period

    if from_time > till_time
      flash[:notice] = _('Date_from_greater_thant_date_till')
      redirect_to(action: :generate_invoices) && (return false)
    end

    invoice_type_confline = (type == 'prepaid' && (admin? || accountant?)) ? 'Prepaid_' : ''
    invoice_number_type = Confline.get_value("#{invoice_type_confline}Invoice_Number_Type", owner_id).to_i

    unless [1, 2].include?(invoice_number_type)
      flash[:notice] = _('Please_set_invoice_params')
      usertype = session[:usertype].to_s
      unless accountant?
        if %w(reseller partner).include?(usertype)
          redirect_to(controller: 'functions', action: "#{usertype}_settings") && (return false)
        else
          redirect_to(controller: 'functions', action: 'settings') && (return false)
        end
      else
        redirect_to(action: 'generate_invoices') && (return false)
      end
    end
    BackgroundTask.create(
      task_id: 5,
      owner_id: owner_id,
      created_at: Time.now,
      status: 'WAITING',
      user_id: params[:s_user_id].present? ? params[:s_user_id].to_i : -2,
      data1: session_from_datetime_no_timezone,
      data2: session_till_datetime_no_timezone,
      data3: type,
      data4: issue_date.to_s,
      data5: params[:currency]
    )
    system("/usr/local/mor/mor_invoices elasticsearch &")
    flash[:status] = _('bg_task_for_generating_invoice_successfully_created')
    if admin?
      redirect_to(controller: 'functions', action: 'background_tasks') && (return false)
    else
      redirect_to(action: 'invoices') && (return false)
    end
  end

  # before_filter
  #   find_invoice
  def invoice_recalculate
    invoice_id = @invoice.id

    if @invoice.paid?
      flash[:notice] = _('Invoice_already_paid')
      redirect_to action: :invoice_details, id: invoice_id
    end
    if @invoice.invoice_was_send?
        flash[:notice] = _('Invoice_already_send')
        redirect_to action: :invoice_details, id: invoice_id
    else
       BackgroundTask.create(
        task_id: 6,
        owner_id: correct_owner_id,
        created_at: Time.zone.now,
        status: 'WAITING',
        user_id: @invoice.user_id,
        data1: @invoice.period_start.to_s + ' 00:00:00',
        data2: @invoice.period_end.to_s + ' 23:59:59' ,
        data3: 'user',
        data6: invoice_id
      )
      system("/usr/local/mor/mor_invoices recalculate elasticsearch &")
      flash[:status] = _('bg_task_for_recalculating_successfully_created')
      if admin?
        redirect_to(controller: 'functions', action: 'background_tasks') && (return false)
      else
        redirect_to(action: 'invoices') && (return false)
      end
    end
  end


  def date_query(date_from, date_till)
    # date query
    if date_from == ''
      date_sql = ''
    else
      date_from_string, date_till_string = [date_from.to_s, date_till.to_s]

      if date_from.length > 11
        date_sql = "AND calldate BETWEEN '#{date_from_string}' AND '#{date_till_string}'"
      else
        date_sql = "AND calldate BETWEEN '" + date_from_string + " 00:00:00' AND '" + date_till_string + " 23:59:59'"
      end
    end

    date_sql
  end

  def invoices
    @page_title = _('Invoices')
    @page_icon = 'view.png'
    @show_currency_selector = 1
    @options = session[:invoice_options] ? session[:invoice_options] : {}

    change_date

    if params[:email].present?
      MorLog.my_debug('*************Invoice sending manually from invoices list')
      send_invoices
      MorLog.my_debug('*************Invoice sending manually from invoices list is over')
    end

    # search params parsing. Assign new params if they were sent, default unset params to '' and leave if param is set but not sent
    if params[:clear].to_s == 'true'
      @options.each { |key, value|
        logger.debug "Need to clear search."
        if key.to_s.scan(/^s_.*/).size > 0
          @options[key] = nil
          logger.debug "     clearing #{key}"
        end
      }
    end
    [:s_username, :s_first_name, :s_last_name, :s_number, :s_period_start, :s_period_end,
     :s_issue_date, :s_sent_email, :s_sent_manually, :s_paid, :s_invoice_type].each { |key|
      @options[key] = (params[key] || @options[key] || '').to_s.strip
    }

    # page number is an exception because it defaults to 1
    if params[:page] && params[:page].to_i > 0
      @options[:page] = params[:page].to_i
    else
      @options[:page] = 1 if !@options[:page] || @options[:page] <= 0
    end

    # same goes for order descending
    params[:order_desc] ?
        @options[:order_desc] = params[:order_desc].to_i :
        (@options[:order_desc] = 0 if !@options[:order_desc])

    cond = []
    cond_param = []

    # params that need to be searched with appended any value via LIKE in users table
    ['username', 'first_name', 'last_name'].each { |col|
      add_contition_and_param(@options["s_#{col}".to_sym],
                              @options["s_#{col}".intern].to_s,
                              "users.#{col} LIKE ?", cond, cond_param)
    }

    # params that need to be searched with appended any value via LIKE in invoices table
    add_contition_and_param(@options[:s_number],
                            @options[:s_number].to_s,
                            "invoices.number LIKE ?", cond, cond_param)

    # params that need to be searched via equality.
    ['period_start', 'period_end', 'issue_date', 'sent_email',
     'sent_manually', 'paid', 'invoice_type'].each { |col|
      add_contition_and_param(@options["s_#{col}".to_sym], @options["s_#{col}".to_sym],
                              "invoices.#{col} = ?", cond, cond_param) }

    owner_id = session[:usertype] == 'accountant' ? 0 : session[:user_id]
    # If accountant must see only assigned users, else ignore and do as before
    acc_show_assigned_users = if current_user.show_only_assigned_users == 1
                                "AND users.responsible_accountant_id = #{current_user_id}"
                              else
                                ''
                              end
    cond << "users.owner_id = ? #{acc_show_assigned_users}"
    cond_param << owner_id

    @options[:order_by], order_by = invoices_order_by(params, @options)

    @total_pages = (Invoice.includes(:user).
        where([cond.join(" AND ")] + cond_param).references(:user).to_a.size.to_d / session[:items_per_page].to_d).ceil

    @options[:page] = @total_pages if @options[:page].to_i > @total_pages and @total_pages > 0

    dc = session[:show_currency]
    @ex = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])

    @conf = Confline.get_value("Invoice_allow_recalculate_after_send").to_i

    join_users_and_taxes = 'INNER JOIN `users` ON `users`.`id` = `invoices`.`user_id` LEFT JOIN `taxes` ON `taxes`.`id` = `invoices`.`tax_id`'


    if params[:to_csv].to_i == 0
      @tot_in_wat = 0


      @invoice_query = Invoice.joins(join_users_and_taxes).
          where([cond.join(' AND ')] + cond_param)
      @invoices = @invoice_query.
          order(order_by).
          limit(session[:items_per_page]).
          offset(session[:items_per_page] * (@options[:page] - 1))

      calculate_invoices_totals

      @search = cond.length > 1 ? 1 : 0
      # cond.length > 1 ? @send_invoices = 1 : @send_invoices = 0
      @send_invoices = 0

      @period_starts = ActiveRecord::Base.connection.select_all("SELECT DISTINCT period_start FROM invoices, users where users.owner_id = #{corrected_user_id} and invoices.user_id = users.id ORDER BY period_start ASC")
      @period_ends = ActiveRecord::Base.connection.select_all("SELECT DISTINCT period_end FROM invoices, users where users.owner_id = #{corrected_user_id} and invoices.user_id = users.id ORDER BY period_end ASC")
      @issue_dates = ActiveRecord::Base.connection.select_all("SELECT DISTINCT issue_date FROM invoices, users where users.owner_id = #{corrected_user_id} and invoices.user_id = users.id ORDER BY issue_date ASC")

      session[:invoice_options] = @options
    else
      nice_number_hash = {change_decimal: session[:change_decimal],
                          global_decimal: session[:global_decimal]}

      invoices = Invoice.joins(join_users_and_taxes).
          where([cond.join(' AND ')] + cond_param).references([:user, :tax]).order(order_by)

      sep, dec = current_user.csv_params
      csv_line = "'#{_('ID')}'#{sep}'#{_('User')}'#{sep}'#{_('Amount')} (#{dc})'#{sep}'#{_('Tax')}'#{sep}'#{_('Amount_with_tax')} (#{dc})'#{sep}'#{(_('Invoice_number'))}'#{sep}'#{(_('VAT_Reg_number'))}'\n"
      csv_line += invoices.map { |result| "#{result.id}#{sep}" +
          "#{nice_user(result.user).delete(sep)}#{sep}" +
          "#{result.nice_invoice_number(result.converted_price(result.invoice_currency.to_s == dc ? result.invoice_exchange_rate : @ex), nice_number_hash).to_s.gsub(".", dec).to_s}#{sep}" +
          "#{result.nice_invoice_number((result.converted_price_with_vat(result.invoice_currency.to_s == dc ? result.invoice_exchange_rate : @ex) - result.converted_price(result.invoice_currency.to_s == dc ? result.invoice_exchange_rate : @ex)), nice_number_hash).to_s.gsub(".", dec).to_s}#{sep}" +
          "#{result.nice_invoice_number((result.converted_price_with_vat(result.invoice_currency.to_s == dc ? result.invoice_exchange_rate : @ex)), nice_number_hash).to_s.gsub(".", dec).to_s}#{sep}" +
          "#{result.number}#{sep}#{result.client_details7}"
      }.join("\n")
      if params[:test].to_i == 1
        render text: "Invoices-#{session[:show_currency]}.csv" + csv_line.to_s
      else
        send_data(csv_line,
                  type: 'text/csv; charset=utf-8; header=present',
                  filename: "Invoices-#{session[:show_currency]}.csv")
      end
    end
  end

  def user_invoices
    @ex = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])
    @page_title = _('Invoices')
    @page_icon = 'view.png'

    if admin? or accountant?
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    @invoices = Invoice.includes([:tax]).where(["invoices.user_id = ?", session[:user_id]])
  end

  def bulk_unpaid_invoices
    @page_title = _('Pay_unpaid_Invoices')
    @page_icon = 'view.png'

    @invoices = Invoice.where("invoices.paid = 0 AND users.owner_id = #{corrected_user_id}").joins(:user).to_a
  end

  def bulk_pay_unpaid_invoices
    invoices = Invoice.where("invoices.paid = 0 AND users.owner_id = #{corrected_user_id}").joins(:user)
    paid = 0

    invoices.each do |invoice|
      paid += invoice.pay({create_payment: 1, date: {day: Time.now.day}}, correct_owner_id) ? 1 : 0
    end

    flash[:status] = "#{_('Invoices_paid')}: #{paid} #{_('out_of')} #{invoices.to_a.size}"
    redirect_to(action: :invoices)
  end

  def pay_invoice
    invoice = Invoice.includes([:tax]).where(id: params[:id]).first

    if (invoice && (invoice.user.owner_id != correct_owner_id)) || request.get?
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end

    unless invoice
      flash[:notice] = _('Invoice_not_found')
      redirect_to(:root) && (return false)
    end

    invoice.pay(params, correct_owner_id)

    redirect_to(action: 'invoices')
  end

  def sent_invoice
    invoice = Invoice.where(id: params[:id]).first
    unless invoice
      flash[:notice] = _('Invoice_not_found')
      (redirect_to :root) && (return false)
    end

    invoice.toggle_status(params[:status])

    redirect_to action: :invoice_details, id: invoice.id
  end

  def invoice_details
    unless can_see_finances?
      flash[:notice] = _('You_have_no_view_permission')
      (redirect_to :root) && (return false)
    end

    flash[:notice] = _('Invoice_not_found') and redirect_to action: 'invoices' and return false unless params[:id]
    @invoice = Invoice.includes([:user]).where(id: params[:id]).first
    @user = @invoice.user if @invoice

    unless (@invoice && [@user.id.to_s, @user.owner_id.to_s].include?(corrected_user_id.to_s))
      flash[:notice] = _('Invoice_not_found')
      redirect_to(:root) && (return false)
    end

    @invoice_invoicedetails = @invoice.invoicedetails
    @ex = @invoice.invoice_exchange_rate
    @day_selection = @invoice.paid_date || Time.now
    @page_title = _('Invoice') + ': ' + @invoice.number
    @page_icon = 'view.png'
    @countries = Direction.all
  end

  def update_invoice_details
    invoice = Invoice.includes([:user]).where(["invoices.id = ?", params[:id]]).first

    unless invoice ||
        (['admin', 'accountant'].include?(session[:usertype])) ||
        (session[:user_id] == @invoice.user.owner_id)

      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    invoice.update_attributes(params[:invoice])
    flash[:status] = _('Invoice_updated')

    redirect_to action: :invoice_details, id: invoice.id
  end

  def invoice_details_list
    @page_title, @page_icon = [_('Invoice_details'), 'view.png']
    @options = initialize_options
    @invoice_currency = @invoice.invoice_currency.to_s.upcase
    @invoice_lines_all, @invoice_lines_in_page_count, @invoice_lines_in_page, @total_pages, @options, @clear_search = nice_invoice_details_list(@options, session[:items_per_page].to_i, @invoice.id)
    @invoice_precision = Invoice.where(id: params[:id]).first.invoice_precision.to_i
    total_inv_line_amount(@invoice_lines_all)
    session[:invoice_lines_options] = @options
    Application.change_separators(@options, @nbsp)
  end

  def user_invoice_details
   @ex = (@invoice.invoice_currency.present? ?
        @invoice.invoice_exchange_rate :
        Currency.count_exchange_rate(session[:default_currency], session[:show_currency]))

    @invoice_invoicedetails = @invoice.
        invoicedetails.select("name,  price * #{@ex} AS price, quantity, invdet_type").to_a

    if @invoice.user_id != current_user_id
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    @user = @invoice.user
    @invoices_status = @user.get_invoices_status
    @page_title = _('Invoice') + ': ' + @invoice.number
    @page_icon = 'view.png'
  end

  def invoice_delete
    inv = Invoice.includes([:user, :tax]).where(id: params[:id]).first
    if !inv
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
    inv_num = inv.number

    if inv.destroy
      flash[:status] = _('Invoice_deleted') + ': ' + inv_num
    else
      flash_errors_for(_('Invoice_not_deleted'), inv_num)
    end
    redirect_to(action: :invoices) && (return false)
  end

  def delete_all
    @options = session[:invoice_options] ? session[:invoice_options] : {}

    [:s_username, :s_first_name, :s_last_name, :s_number, :s_period_start, :s_period_end,
     :s_issue_date, :s_sent_email, :s_sent_manually, :s_paid, :s_invoice_type].each { |key|
      @options[key] = (params[key] || @options[key] || '').to_s.strip
    }

    cond = []
    cond_param = []

    # Params that need to be searched with appended any value via LIKE in users table
    %w[username first_name last_name].each do |col|
      add_contition_and_param(
          @options["s_#{col}".to_sym],
          @options["s_#{col}".intern].to_s,
          "users.#{col} LIKE ?", cond, cond_param
      )
    end

    # Params that need to be searched with appended any value via LIKE in invoices table
    add_contition_and_param(@options[:s_number], @options[:s_number].to_s, 'invoices.number LIKE ?', cond, cond_param)

    # Params that need to be searched via equality.
    %w[period_start period_end issue_date sent_email sent_manually paid invoice_type].each do |col|
      add_contition_and_param(
          @options["s_#{col}".to_sym],
          @options["s_#{col}".to_sym],
          "invoices.#{col} = ?", cond, cond_param
      )
    end

    owner_id = accountant? ? 0 : @current_user.id

    # If accountant must see only assigned users, else ignore and do as before
    acc_show_assigned_users = if current_user.show_only_assigned_users == 1
                                "AND users.responsible_accountant_id = #{current_user_id}"
                              else
                                ''
                              end

    cond << "users.owner_id = ? #{acc_show_assigned_users}"
    cond_param << owner_id
    join_users_and_taxes = 'INNER JOIN `users` ON `users`.`id` = `invoices`.`user_id` LEFT JOIN `taxes` ON `taxes`.`id` = `invoices`.`tax_id`'
    invoices = Invoice.joins(join_users_and_taxes).where([cond.join(' AND ')] + cond_param).references([:user, :tax])

    destroyed = 0
    invoices.try(:each) { |inv| destroyed += 1 if inv.destroy }

    if destroyed == invoices.size
      flash[:status] = _('Invoices_deleted')
    else
      flash[:notice] = _('Sent_Invoices_were_not_deleted')
    end

    redirect_to(action: :invoices) && (return false)
  end

  # ==========PDF==========
  def generate_invoice_pdf
    if @invoice.is_a?(Fixnum)
      invoice = Invoice.includes([:tax, :user]).where(id: params[:id]).first
    else
      invoice = @invoice
    end
    idetails = invoice.try(:invoicedetails)
    user = invoice.user
    @invoices_status = user.get_invoices_status
    status = (@invoices_status[0] == 2)

    if not_authorized_generate_pdf_or_csv(user, status) == 1
      redirect_to :root unless performed?
      return false
    end

    type = (user.postpaid.to_i == 1 or invoice.user.owner_id != 0) ? 'postpaid' : 'prepaid'

    dc , ex = manage_exchange_rates(invoice)
    show_avg_rate = 1

    pdf, arr_t = invoice.
        generate_simple_pdf(current_user, dc, nice_invoice_number_digits(type), session[:change_decimal],
          session[:global_decimal], show_avg_rate, params[:test].to_i == 1)

    filename = invoice.filename(type, 'pdf')

    if params[:email_or_not]
      return pdf.render
    else
      if params[:test].to_i == 1
        pdf.render
        # Changing Date format To default Format specified in settings
        # This causes Date .to_s to format date as default date specified

        default_format = Date::DATE_FORMATS[:default]
        Date::DATE_FORMATS[:default] = session[:date_format]

        text = 'Ok'
        text += "\n" + invoice.to_yaml if invoice
        text += "\n" + idetails.to_yaml if idetails
        text += "\n" + type
        text += "\n" + filename
        text += "\n" + arr_t.to_yaml if arr_t

        # Should not affect globaly
        Date::DATE_FORMATS[:default] = default_format

        render text: text
      else
        send_data pdf.render, filename: filename, type: 'application/pdf'
      end
    end
  end

  def generate_invoice_detailed_pdf
    invoice = Invoice.where(id: params[:id]).includes([:tax, :user]).first

    unless invoice
      if params[:action] == 'generate_invoice_detailed_pdf'
        flash[:notice] = _('Invoice_not_found')
        redirect_to :root unless performed?
        return false
      else
        raise 'Invoice_not_found'
      end
    end

    user = invoice.user
    @invoices_status = user.get_invoices_status
    status = (@invoices_status[2] == 8)

    if not_authorized_generate_pdf_or_csv(user, status)
      (redirect_to :root) && (return false)
    end

    type = ((user.postpaid.to_i == 1) || (user.owner_id != 0)) ? 'postpaid' : 'prepaid'

    # Hide from prepaid manual payments
    if (type == 'prepaid') &&
        (invoice.invoicedetails.first.try(:name).to_s == 'Manual Payment')

      flash[:notice] = _('Dont_be_so_smart')
      redirect_to :root unless performed?
      return false
    end

    dc, ex = manage_exchange_rates(invoice)
    show_avg_rate = 1

    pdf, arr_t = invoice.generate_invoice_detailed_pdf(current_user, dc, nice_invoice_number_digits(type), session[:change_decimal], session[:global_decimal], show_avg_rate, params[:test].to_i == 1)

    if params[:email_or_not]
      return pdf.render
    else
      filename = invoice.filename(type, 'pdf','Invoice_detailed')
      if params[:test].to_i == 1
        pdf.render
        text = 'Ok'
        text += "\n" + type
        text += "\n" + filename
        text += "\n" + "currency #{dc}"
        text += "\n" + "avg_rate => #{arr_t.to_yaml}" if arr_t
        render :text => text
      else
        send_data pdf.render, filename: filename, type: 'application/pdf'
      end
    end
  end

  def add_space (space)
    space = space.to_i
    sp = ''
    space.times do
      sp += ' '
    end
    sp
  end

  def generate_invoice_by_cid_pdf
    find_invoice_new
    return false unless @invoice

    invoice = @invoice
    user = invoice.user
    @invoices_status = user.get_invoices_status
    status = (@invoices_status[4] == 32)

    if not_authorized_generate_pdf_or_csv(user, status)
      redirect_to :root unless performed?
      return false
    end

    type = (user.postpaid.to_i == 1 || user.owner_id != 0) ? 'postpaid' : 'prepaid'

    # Hide from prepaid manual payments
    if type == 'prepaid' && invoice.invoicedetails.first.try(:name).to_s == 'Manual Payment'
      flash[:notice] = _('Dont_be_so_smart')
      redirect_to :root unless performed?
      return false
    end

    dc, ex = manage_exchange_rates(invoice)
    params_test_eq_one = (params[:test].to_i == 1)

    pdf, arr_t = invoice.generate_invoice_by_cid_pdf(current_user, dc, ex, nice_invoice_number_digits(type), session[:change_decimal], session[:global_decimal], params_test_eq_one)

    if params[:email_or_not]
      return pdf.render
    else
      filename = invoice.filename(type, 'pdf','Invoice_by_cid')
      if params_test_eq_one
        pdf.render
        text = 'Ok'
        text += "\n" + "#{arr_t.inspect}" if arr_t
        text += "\n" + type
        text += "\n" + filename
        render :text => text
      else
        send_data pdf.render, filename: filename, type: 'application/pdf'
      end
    end

  end

  def generate_test_pdf
    pdf = Prawn::Document.new(size: 'A4', layout: :portrait)
    pdf.font("#{Prawn::BASEDIR}/data/fonts/DejaVuSans.ttf")

    # ---------- Company details ----------

    pdf.text(session[:company], {left: 40, size: 23})
    pdf.text(Confline.get_value("Invoice_Address1"), {left: 40, size: 12})
    pdf.text(Confline.get_value("Invoice_Address2"), {left: 40, size: 12})
    pdf.text(Confline.get_value("Invoice_Address3"), {left: 40, size: 12})
    pdf.text(Confline.get_value("Invoice_Address4"), {left: 40, size: 12})

    # ----------- Invoice details ----------

    pdf.fill_color('DCDCDC')
    pdf.draw_text(_('INVOICE'), {at: [330, 700], size: 26})
    pdf.fill_color('000000')
    pdf.draw_text(_('Date') + ': ' + 'invoice.issue_date.to_s', {at: [330, 685], size: 12})
    pdf.draw_text(_('Invoice_number') + ': ' + 'invoice.number.to_s', {at: [330, 675], size: 12})

    pdf.image(Actual_Dir+"/public/images/rails.png")
    pdf.text("Test Text : ąčęėįšųūž_йцукенгшщз")
    send_data pdf.render, filename: "test.pdf", type: 'application/pdf'
  end


  #================================ end of PDF ========================================================================
  def generate_invoice_csv
    if @invoice.is_a?(Fixnum)
      invoice = Invoice.includes([:tax, :user]).where(id: params[:id]).first
    else
      invoice = @invoice
    end

    user = invoice.user
    @invoices_status = user.get_invoices_status
    status = (@invoices_status[1] == 4)

    if not_authorized_generate_pdf_or_csv(user, status) == 1
      redirect_to :root unless performed?
      return false
    end

    sep, dec = user.csv_params
    nice_number_hash  = {:change_decimal => session[:change_decimal], :global_decimal => session[:global_decimal]}

    dc, ex = manage_exchange_rates(invoice)

    csv_string = ["number#{sep}user_id#{sep}period_start#{sep}period_end#{sep}issue_date#{sep}price (#{dc})#{sep}price_with_tax (#{dc})#{sep}accounting_number"]
    csv_string << "#{invoice.number.to_s}#{sep}" +
        "#{nice_user(user)}#{sep}" +
        "#{nice_date(invoice.period_start, 0)}#{sep}" +
        "#{nice_date(invoice.period_end, 0)}#{sep}" +
        "#{nice_date(invoice.issue_date)}#{sep}" +
        "#{invoice.nice_invoice_number(invoice.converted_price(ex), nice_number_hash).to_s.gsub(".", dec).to_s}#{sep}" +
        "#{invoice.nice_invoice_number(invoice.converted_price_with_vat(ex), nice_number_hash).to_s.gsub(".", dec).to_s}#{sep}" +
        "#{user.accounting_number}"

    #  my_debug csv_string
    prepaid, prep = invoice_type(invoice, user)

    filename = invoice.filename(prep, 'csv', nil, dc)

    if params[:email_or_not]
      return csv_string.join("\n")
    else
      if params[:test].to_i == 1
        render :text => (["Filename: #{filename}"] + csv_string).join("\n")
      else
        send_data(csv_string.join("\n"), :type => 'text/csv; charset=utf-8; header=present', :filename => filename)
      end
    end
  end

  def generate_invoice_detailed_csv
    find_invoice_new
    return false unless @invoice

    invoice = @invoice
    idetails = invoice.invoicedetails.order(:name)
    first_idetail = idetails.first
    user = invoice.user
    @invoices_status = user.get_invoices_status
    status = (@invoices_status[3] == 16)

    if not_authorized_generate_pdf_or_csv(user, status)
      redirect_to :root unless performed?
      return false
    end

    # Hide from prepaid manual payments
    invoice_type_is_prepaid = (invoice.invoice_type.to_s.downcase == 'prepaid')

    if invoice_type_is_prepaid && first_idetail && first_idetail.name == 'Manual Payment'
      flash[:notice] = _('Dont_be_so_smart')
      redirect_to :root unless performed?
      return false
    end

    dc, ex = manage_exchange_rates(invoice)

    sep, dec = user.csv_params

    owner = user.owner_id
    prepaid = (invoice_type_is_prepaid && owner == 0) ? 'Prepaid_' : ''

    up, rp, pp = user.get_price_calculation_sqls
    billsec_cond = Confline.get_value("Invoice_user_billsec_show", owner).to_i == 1 ? 'user_billsec' : 'billsec'
    user_price = SqlExport.replace_price(up, {ex: ex})
    reseller_price = SqlExport.replace_price(rp, {ex: ex})
    partner_price = SqlExport.replace_price('calls.partner_price', {ex: ex})
    did_sql_price = SqlExport.replace_price('calls.did_price', {ex: ex, reference: 'did_price'})
    did_inc_sql_price = SqlExport.replace_price('calls.did_inc_price', {ex: ex, reference: 'did_inc_price'})
    #did_sql_price = SqlExport.replace_price('calls.did_price', 'did_price')
    selfcost = SqlExport.replace_price(pp, {ex: ex, reference: 'selfcost'})
    user_rate = SqlExport.replace_price('calls.user_rate', {ex: ex, reference: 'user_rate'})
    min_type = (Confline.get_value("#{prepaid}Invoice_Show_Time_in_Minutes", owner).to_i == 1) ? 1 : 0
    csv_string = []

    sub = 0
    idetails.each { |id|
      if id.invdet_type > 0 || id.name == _('Did_owner_cost') || id.name == _('SMS')
        sub = 1
      end
    }

    if idetails
      if sub.to_i == 1
        csv_string << "services#{sep}price"
      end

      idetails.each { |id|
        #MorLog.my_debug(id.to_yaml)
        @iprice = id.price if id.price
        if id.invdet_type > 0
          if id.quantity
            qt = id.quantity
            tp = qt * id.converted_price(ex) if id.price
          else
            qt = ''
            tp = id.converted_price(ex)
          end
          csv_string << "#{nice_inv_name(id.name)}#{sep}#{nice_number(tp).to_s.gsub(".", dec).to_s}"
        elsif id.name == _('Did_owner_cost') or id.name == _('SMS')
          qt = id.quantity
          tp = id.converted_price(ex) if id.price
          csv_string << "#{nice_inv_name(id.name)}#{sep}#{nice_number(tp).to_s.gsub(".", dec).to_s}"
        end
      }
    end

    csv_string << _('Minimal_Charge_for_Calls') + " (#{dc})" + sep + nice_number(user.converted_minimal_charge(ex).to_d) if user.minimal_charge_enabled?
    show_zero_calls = user.invoice_zero_calls.to_i
    zero_calls_sql = (show_zero_calls == 0) ? " AND #{up} > 0 " : ''
    invoice_period_start, invoice_period_end = [invoice.period_start, invoice.period_end]

    user_timezone = user.time_zone
    calls_calldate_from = (Time.parse("#{invoice_period_start} 00:00:00") - Time.parse("#{invoice_period_start} 00:00:00").in_time_zone(user_timezone).utc_offset().second + Time.parse("#{invoice_period_start} 00:00:00").utc_offset().second)
    calls_calldate_till = (Time.parse("#{invoice_period_end} 23:59:59") - Time.parse("#{invoice_period_end} 23:59:59").in_time_zone(user_timezone).utc_offset().second + Time.parse("#{invoice_period_end} 23:59:59").utc_offset().second)
    calls_calldate_from = "#{calls_calldate_from.strftime('%Y-%m-%d %H:%M:%S')}"
    calls_calldate_till = "#{calls_calldate_till.strftime('%Y-%m-%d %H:%M:%S')}"
    sql = "SELECT #{user_rate}, destinationgroups.id, destinationgroups.flag as 'dg_flag', destinationgroups.name as 'dg_name', COUNT(*) as 'calls', SUM(#{billsec_cond}) as 'billsec', #{selfcost}, SUM(#{user_price}) as 'price', dids.did as 'to_did' " +
        "FROM calls "+
        "LEFT JOIN dids on calls.did_id = dids.id AND dids.did = calls.dst "+
        "LEFT JOIN devices ON (calls.src_device_id = devices.id)
        LEFT JOIN destinations ON (destinations.prefix = calls.prefix)  "+
        "LEFT JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) #{SqlExport.left_join_reseler_providers_to_calls_sql}"+
        "WHERE calls.calldate BETWEEN '#{calls_calldate_from}' AND '#{calls_calldate_till}' AND calls.disposition = 'ANSWERED' " +
        " AND devices.user_id = '#{user.id}' AND calls.card_id = 0  #{zero_calls_sql}" +
        "GROUP BY destinationgroups.id, to_did, calls.user_rate "+
        "ORDER BY destinationgroups.name ASC"

     user_is_reseller = user.is_reseller?

    if user_is_reseller || user.is_partner?
      price, owner_id_sql = user_is_reseller ? [reseller_price, 'calls.reseller_id'] : [partner_price, 'calls.partner_id']

      reseller_select = "SELECT calls.dst,  COUNT(*) as 'count_calls', SUM(#{billsec_cond}) as 'sum_billsec', #{selfcost}, SUM(#{price}) as 'price', #{user_rate}  " +
          "FROM calls "+
          "#{SqlExport.left_join_reseler_providers_to_calls_sql} LEFT JOIN destinations ON (destinations.prefix = calls.prefix) LEFT JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) "+
          "WHERE calls.calldate BETWEEN '#{calls_calldate_from}' AND '#{calls_calldate_till}' AND calls.disposition = 'ANSWERED' " +
          " AND (#{owner_id_sql} = '#{user.id}' ) #{zero_calls_sql}" +
          "GROUP BY destinationgroups.id, calls.user_rate "+
          "ORDER BY destinationgroups.name ASC"
      result_on_reseller_select = ActiveRecord::Base.connection.select_all(reseller_select)
    end

    res = ActiveRecord::Base.connection.select_all(sql)

    if res != []
      csv_string << "number#{sep}accounting_number#{sep}country#{sep}type#{sep}rate#{sep}calls#{sep}billsec#{sep}price (#{dc})"
    end

    res && res.each { |result|
      country = (not result['to_did'].to_s.blank?) ? _('Calls_To_Dids') : result['dg_name']
      calls = result['calls']
      billsec = result['billsec']
      rate = result['user_rate']
      price = result['price']
      csv_string << "#{invoice.number.to_s}#{sep}#{user.accounting_number.to_s.blank? ? ' ' : user.accounting_number.to_s}#{sep}#{country}#{sep}#{rate}#{sep}#{calls}#{sep}#{billsec}#{sep}#{nice_number(price).to_s.gsub(".", dec).to_s}"
    }

    params[:email_or_not] ? req_user = user : req_user = current_user

    if user_is_reseller || user.is_partner? and result_on_reseller_select
      csv_string << "\n" + _('Calls_from_users') + ":"
      csv_string << "#{_('DID')}#{sep}#{_('Calls')}#{sep}#{_('Total_time')}#{sep}#{_('Price')}(#{dc})"
      result_on_reseller_select.each { |result|
        csv_string << "#{hide_dst_for_user(req_user, "csv", result["dst"].to_s)}#{sep}#{result["count_calls"].to_s}#{sep}#{invoice_nice_time(result["sum_billsec"], min_type)}#{sep}#{nice_number(result['price']).to_s.gsub(".", dec).to_s}"
      }
    end

    prepaid, prep = invoice.new_invoice_type(user)

    filename = invoice.filename(prep, 'csv', nil, dc)
    if params[:email_or_not]
      return csv_string.join("\n")
    else
      if params[:test].to_i == 1
        render :text => (["Filename: #{filename}"] + csv_string).join("\n")
      else
        send_data(csv_string.join("\n"), type: 'text/csv; charset=utf-8; header=present', filename: filename)
      end
    end
  end

  def generate_invoice_destinations_csv
    unless generates_invoice_destinations_csv
      (redirect_to :root) && (return false)
    end
  end

  def generates_invoice_destinations_csv
    find_invoice_new
    return false unless @invoice

    invoice = @invoice
    idetails = invoice.invoicedetails_ordered
    first_idetail = idetails.first
    user = invoice.user
    @invoices_status = user.get_invoices_status
    status = (@invoices_status[5] == 64)

    return false if not_authorized_generate_pdf_or_csv(user, status)

    # Hide from prepaid manual payments
    if invoice.invoice_type.downcase == 'prepaid' && first_idetail && first_idetail.name == 'Manual Payment'
      flash[:notice] = _('Dont_be_so_smart')
      return false
    end

    dc, ex = manage_exchange_rates(invoice)
    sep, dec = user.csv_params
    owner = invoice.user.owner_id
    prepaid = (invoice.invoice_type.to_s == 'prepaid' && owner == 0) ? 'Prepaid_' : ''
    billsec_cond = Confline.get_value("Invoice_user_billsec_show", owner).to_i == 1 ? 'user_billsec' : 'billsec'

    csv_string = ["Invoice NO.:#{sep} #{invoice.number.to_s}"]
    csv_string << ''
    csv_string << "Invoice Date:#{sep} #{nice_date(invoice.period_start, 0)} - #{nice_date(invoice.period_end, 0)}"
    csv_string << ''
    csv_string << "Due Date:#{sep} #{nice_date(invoice.issue_date, 0)}"
    csv_string << ''
    csv_string << ''

    sub = 0
    calls_to_dids_translation = _('Calls_To_Dids')
    idetails.each do |id|
      id_name = id.name
      (sub = 1) && break if id_name != 'Calls' && id_name != calls_to_dids_translation
    end

    if idetails
      csv_string << "services#{sep}price\n" if sub == 1

      idetails.each do |id|
        id_name = id.name

        if id_name != 'Calls'
          @iprice = id.price

          if id.invdet_type > 0
            if id.quantity
              qt = id.quantity
              tp = qt * id.converted_price(ex) if id.converted_price(ex)
            else
              qt = ''
              tp = id.converted_price(ex)
            end
            csv_string << "#{nice_inv_name(id_name)}#{sep}#{nice_number(tp).to_s.gsub(".", dec).to_s}"
          elsif id_name == _('Did_owner_cost')
            qt = id.quantity
            tp = id.converted_price(ex) if id.converted_price(ex)
            csv_string << "#{nice_inv_name(id_name)}#{sep}#{nice_number(tp).to_s.gsub(".", dec).to_s}"
          elsif id_name == calls_to_dids_translation
            qt = id.quantity
            tp = id.converted_price(ex)
            csv_string << "#{nice_inv_name(id_name)}#{sep}#{nice_number(tp).to_s.gsub(".", dec).to_s}"
          elsif id_name == _('SMS')
            qt = id.quantity
            tp = id.converted_price(ex)
            csv_string << "#{nice_inv_name(id_name)}#{sep}#{nice_number(tp).to_s.gsub(".", dec).to_s}"
          end
        end
      end
    end

    csv_string << ''
    csv_string << _('Minimal_Charge_for_Calls') + " (#{dc})" + sep + nice_number(user.converted_minimal_charge(ex).to_d) if user.minimal_charge_enabled?
    csv_string << ''

    es_options = {
      from: "#{invoice.period_start} 00:00:00",
      till: "#{invoice.period_end} 23:59:59",
      user: user,
      csv_sep: sep,
      dec_sep: dec,
      dec_digits: Confline.get_value('Nice_Number_Digits').to_i,
      exrate: ex,
      billsec_field: billsec_cond,
    }

    csv_string << "Country#{sep}Rate#{sep}ASR %#{sep}Calls#{sep}ACD#{sep}Billsec#{sep}Price"
    csv_string += EsInvoiceDestinations::csv(es_options)

    prepaid, prep = invoice.new_invoice_type(user)
    filename = invoice.filename(prep, 'csv', nil, dc)

    if  params[:email_or_not]
      return csv_string.join("\n")
    else
      if params[:test].to_i == 1
        render text: (["Filename: #{filename}"] + csv_string).join("\n")
      else
        send_data(csv_string.join("\n"), type: 'text/csv; charset=utf-8; header=present', filename: filename)
      end
    end
  end

  def generate_invoice_by_cid_csv
    invoice = Invoice.where(id: params[:id]).includes([:tax, :user]).first

    unless invoice
      flash[:notice] = _('Invoice_not_found')
      redirect_to :root unless performed?
      return false
    end

    # Hide from prepaid manual payments
    if invoice.invoice_type.downcase == 'prepaid' && invoice.invoicedetails.first.try(:name).to_s == 'Manual Payment'
      flash[:notice] = _('Dont_be_so_smart')
      redirect_to :root unless performed?
      return false
    end

    dc = current_user.currency.name
    user = invoice.user
    @invoices_status = user.get_invoices_status
    status = (@invoices_status[6] == 128)

    if not_authorized_generate_pdf_or_csv(user, status)
      redirect_to :root unless performed?
      return false
    end

    unless cid_csv_elastic_not_working(user)
      return false
    end

    dc, ex = manage_exchange_rates(invoice)

    sep, dec = user.csv_params

    up, rp, pp = user.get_price_calculation_sqls
    zero_calls_sql = user.invoice_zero_calls_sql
    user_price = SqlExport.replace_price(up, {ex: ex})
    csv_s = []

    # remove cards conditions, calls.did_inc_price conditions
    # sql = "SELECT calls.src, SUM(#{user_price}) as 'price', COUNT(calls.id) AS calls_size FROM calls JOIN devices ON (calls.src_device_id = devices.id OR calls.dst_device_id = devices.id) #{SqlExport.left_join_reseler_providers_to_calls_sql} WHERE devices.user_id = #{user.id} AND calls.card_id = 0 AND calls.did_inc_price > 0 AND calls.calldate BETWEEN '#{invoice.period_start} 00:00:00' AND '#{invoice.period_end} 23:59:59' AND calls.disposition = 'ANSWERED' AND billsec > 0 #{zero_calls_sql} GROUP BY calls.src;"
    user_timezone = user.time_zone
    calls_calldate_from = (Time.parse("#{invoice.period_start} 00:00:00") - Time.parse("#{invoice.period_start} 00:00:00").in_time_zone(user_timezone).utc_offset().second + Time.parse("#{invoice.period_start} 00:00:00").utc_offset().second)
    calls_calldate_till = (Time.parse("#{invoice.period_end} 23:59:59") - Time.parse("#{invoice.period_end} 23:59:59").in_time_zone(user_timezone).utc_offset().second + Time.parse("#{invoice.period_end} 23:59:59").utc_offset().second)
    calls_calldate_from = "#{calls_calldate_from.strftime('%Y-%m-%d %H:%M:%S')}"
    calls_calldate_till = "#{calls_calldate_till.strftime('%Y-%m-%d %H:%M:%S')}"

    inv_start = Time.parse(calls_calldate_from).strftime('%Y-%m-%dT%H:%M:%S')
    inv_end = Time.parse(calls_calldate_till).strftime('%Y-%m-%dT%H:%M:%S')

    devices = Device.where(user_id: user.id).pluck(:id)
    admin_providers = Provider.where(user_id: 0).pluck(:id)

    cids = EsInvoiceByCidCsv.get_data(
    {
      from: inv_start, till: inv_end, device_id: devices, admin_providers: admin_providers, user: user
    })

    if cids.present?
      csv_s << "\"CallerID\"#{sep}price(#{dc})#{sep}calls#{sep}"

      cids.each { |cid|
        csv_s << "\"#{cid[:src]}\"" + sep.to_s + cid[:total].to_d.to_s.gsub(".", dec).to_s + sep + cid[:calls].to_i.to_s }
    end

    csv_string = csv_s.join("\n")
    prepaid, prep = invoice.new_invoice_type(user)

    filename = invoice.filename(prep , 'csv', nil, dc)
    if  params[:email_or_not]
      return csv_string
    else
      if params[:test].to_i == 1
        render :text => "Filename: #{filename}" + csv_string
      else
        send_data(csv_string, type: 'text/csv; charset=utf-8; header=present', filename: filename)
      end
    end
  end

  def change_session_flag
    session[:invoices_is_generating] = 0
    redirect_to :root
  end

  def invoices_recalculation
    @username = params[:s_user] || ''
    @user_id = params[:s_user_id] || -2
    @page_title = _('Recalculate_invoices')
    @page_icon = 'application_go.png'
    @type = params[:type] || 'postpaid'
    @post = 1
    @pre = 0
  end

  def invoices_recalculation_status
    @page_title = _('Recalculate_invoices_status')
    @page_icon = 'application_go.png'

    change_date

    unless params[:invoice]
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
    type = params[:invoice][:type]
    type = 'postpaid' if !(['postpaid', 'prepaid', 'user'].include?(type))

    cond = Confline.get_value("Invoice_allow_recalculate_after_send").to_i == 1 ? '' : ' AND sent_manually = 0 AND sent_email = 0 '

    if type == 'user'
      @invoices_count = Invoice.includes([:user]).where(["paid = 0 #{cond} AND user_id = ? AND period_start >= ? AND period_end <= ? AND users.owner_id = ?", params[:s_user_id], session_from_date, session_till_date, correct_owner_id]).references([:user]).count
    else
      @invoices_count = Invoice.includes([:user]).where(["paid = 0 #{cond} AND invoice_type = ? AND period_start >= ? AND period_end <= ? AND users.owner_id = ?", type, session_from_date, session_till_date, correct_owner_id]).references([:user]).count
    end

    @period_start = session_from_date
    @period_end = session_till_date

    if @invoices_count > 0
      BackgroundTask.create(
        task_id: 6,
        owner_id: correct_owner_id,
        created_at: Time.zone.now,
        status: 'WAITING',
        user_id: params[:s_user_id].present? ? params[:s_user_id] : -2,
        data1: session_from_datetime_no_timezone,
        data2: session_till_datetime_no_timezone,
        data3: type
      )
      system("/usr/local/mor/mor_invoices recalculate elasticsearch &")
      flash[:status] = _('bg_task_for_recalculating_successfully_created')
      if admin?
        redirect_to(controller: 'functions', action: 'background_tasks') && (return false)
      else
        redirect_to(action: 'invoices') && (return false)
      end
    else
      flash[:notice] = _('No_invoice_found_to_recalculate')
      redirect_to action: :invoices_recalculation, s_user: params[:s_user], s_user_id: params[:s_user_id], type: type and return false
    end
  end

  def financial_statements
    @page_title = _('Financial_statements')
    @page_icon = 'view.png'
    @show_currency_selector = 1
    @currency = session[:show_currency]

    params[:clear] ? change_date_to_present : change_date
    @issue_from_date = Date.parse(session_from_date)
    @issue_till_date = Date.parse(session_till_date)

    session_options = session[:accounting_statement_options]
    @valid_status_values = ['paid', 'unpaid', 'all']
    @user_id = financial_statements_user_id(session_options)
    @status = financial_statements_status(session_options)
    @options = {s_user_id: @user_id, s_user: params[:s_user], status: @status}


    @show_search = true

    if admin? or accountant?
      owner_id = 0
    else
      owner_id = current_user_id
    end
    ordinary_user = (current_user.usertype == 'user')
    credit_notes = convert_to_user_currency(CreditNote.financial_statements(owner_id, @user_id, @status, @issue_from_date, @issue_till_date, ordinary_user))
    if @status != 'unpaid'
      @paid_credit_note = get_financial_statement(credit_notes, 'paid')
    end
    if @status != 'paid'
      @unpaid_credit_note = get_financial_statement(credit_notes, 'unpaid')
    end

    # invoces do not have price with vat calculated so this method returns information
    # abount paid and unpaid invoices, we just have to convert currency FROM USER
    # CURRENCY TO USER'S SELECTED CURRENCY
    currency_name = current_user.currency.name
    @paid_invoice, @unpaid_invoice = Invoice.financial_statements(owner_id, @user_id, @status, @issue_from_date, @issue_till_date, ordinary_user)
    @paid_invoice.price = @paid_invoice.price.to_d * count_exchange_rate(currency_name, session[:show_currency])
    @paid_invoice.price_with_vat = @paid_invoice.price_with_vat.to_d * count_exchange_rate(currency_name, session[:show_currency])
    @unpaid_invoice.price = @unpaid_invoice.price.to_d * count_exchange_rate(currency_name, session[:show_currency])
    @unpaid_invoice.price_with_vat = @unpaid_invoice.price_with_vat.to_d * count_exchange_rate(currency_name, session[:show_currency])

    # there is no need to convert to user currency because method does it by itself
    @paid_payment, @unpaid_payment = Payment.financial_statements(owner_id, @user_id, @status, @issue_from_date, @issue_till_date, ordinary_user, session[:show_currency])

    # TODO rename to session options
    session[:accounting_statement_options] = @options
  end

  def not_authorized_generate_pdf_or_csv(user, status)
    err = 1
      # its user and he has permission to generate this pdf/csv
    if !(((user.id == session[:user_id]) && status) ||
      # its users owner
      (user.owner_id == session[:user_id]) ||
      # its accountant and pdf/csv belongs to admins user
      (accountant? && (user.owner_id == 0)))
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')

      if user.id != session[:user_id]
        flash[:notice] = _('Invoice_not_found')
      end
    else
      err = 0
    end

    (err == 1)
  end

  def export_invoice_to_xlsx
    if params[:id].present?
      @invoice = Invoice.where(id: params[:id]).first
    else
      @invoice = Invoice.where(id: @invoice).first if @invoice.is_a? Numeric
    end

    unless @invoice
      flash[:notice] = _('Invoice_was_not_found')
      redirect_to action: :invoices unless performed?
      return false
    end

    if user? && (@invoice.user_id != current_user_id)
      flash[:notice] = _('invoice_not_found')
      redirect_to action: :invoices unless performed?
      return false
    end

    user = @invoice.user
    @invoices_status = user.get_invoices_status
    status = (@invoices_status[8] == 512)

    if not_authorized_generate_pdf_or_csv(user, status)
      redirect_to :root unless performed?
      return false
    end

    require 'templateXL/x6_invoice_template'

    invoice_number = @invoice.number

    inv_user_owner = user.owner
    inv_user_owner.create_xlsx_conflines_if_not_exists
    inv_user_owner_id = inv_user_owner.id
    templates_name_ending = (admin? || inv_user_owner.is_admin?) ? '' : '_' + inv_user_owner_id.to_s
    template_path = "#{Actual_Dir}/public/invoice_templates/default#{templates_name_ending}.xlsx"
    file_path, file_name = ["/tmp/mor/invoices/#{invoice_number}.xlsx", "#{invoice_number}.xlsx"]

    test = params[:test].to_i == 1

    if File.exists?(file_path) && !test
      data = File.open(file_path).try(:read)
      if params[:email_or_not]
        data
      else
        send_data(data, filename: file_name, type: 'application/octet-stream')
      end
    else
      round_2_dec = Confline.get_value("Round_finals_to_2_decimals").to_i

      if round_2_dec != 1
        precision = @invoice.invoice_precision.presence || session[:nice_number_digits]
      else
        precision = 2
      end
      invoice_template = TemplateXL::X6InvoiceTemplate.new(template_path, file_path, inv_user_owner_id, precision)
      invoice_template.invoice, invoice_template.invoicedetails = @invoice.copy_for_xslx
      invoice_template.generate

      if test
        test_data = invoice_template.test
        render text: test_data.to_s
      else
        begin
          invoice_template.save
        rescue => err
          MorLog.my_debug("#{err.message}")
          flash[:notice] = _('File_does_not_exist_in_a_file_system')
          redirect_to action: :invoices unless performed?
          return false
        end
        if params[:email_or_not]
          invoice_template.content
        else
          send_data(invoice_template.content, filename: file_name, type: 'application/octet-stream')
        end
      end
    end
  end

  def cid_csv_elastic_not_working(user)
    unless elasticsearch_status_check
      if params[:email_or_not]
        user_owner_id = user.owner.is_partner? ? 0 : user.owner_id.to_i
        smtp_server = Confline.get_value('Email_Smtp_Server', user_owner_id).to_s.strip
        smtp_user = Confline.get_value('Email_Login', user_owner_id).to_s.strip
        smtp_pass = Confline.get_value('Email_Password', user_owner_id).to_s.strip
        smtp_port = Confline.get_value('Email_Port', user_owner_id).to_s.strip
        from = Confline.get_value('Email_from', user_owner_id)

        smtp_connection =  "'#{smtp_server}:#{smtp_port}'"
        smtp_connection << " -xu '#{smtp_user}' -xp '#{smtp_pass}'" if smtp_user.present?

        admin = User.find(0)
        admin_email = admin.email
        email_body = 'Invoice By CallerID was not sent, because server cannot connect to Elasticsearch'
        mail_subject = 'Invoice By CallerID error'

				system_call = ApplicationController::send_email_dry(from, admin_email, email_body + ' ', mail_subject, '', smtp_connection)
        system(system_call)

        return false
      else
        flash[:notice] = _('Cannot_connect_to_Elasticsearch') unless flash[:notice].present?
        redirect_to action: :invoice_details, id: params[:id]
        return false
      end
    end
    return true
  end

  def get_prepaid_user_calls_csv(user, invoice)
    # CSV and decimal separators
    sep, dec = user.csv_params

    # Spare the function calls and get the visuals only once
    time_format = Confline.get_value('time_format', user.owner.id) || Confline.get_value('time_format', 0)
    hide_dst_end = user.hide_destination_end

    # Export Call data on file (spare RAM)
    filename = invoice.generate_prepaid_csv

    # CSV header
    csv = "#{_('Date')}#{sep}#{_('Called_from')}#{sep}#{_('Called_to')}#{sep}#{_('Destination')}"\
      "#{sep}#{_('Duration')}#{sep}#{_('Price')} (#{_(session[:default_currency].to_s)})\n"

    # Date: 0, Source: 1, Destination: 2, Duration: 3, User price: 4, Destination name: 5
    CSV.foreach(filename) do |row|
      csv << "#{nice_date_time(row[0])}#{sep}#{row[1]}#{sep}"\
        "#{hide_dst_for_user(user, 'csv', row[2], hide_dst_end)}#{sep}"\
        "#{row[5]}#{sep}#{nice_time(row[3], false, time_format)}#{sep}"\
        "#{nice_number(row[4]).to_s.sub('.', dec)}\n"
    end

    csv

  rescue Errno::ENOENT
    MorLog.my_debug("ERROR: Prepaid Invoice File was not found!")
    return nil
  rescue Errno::EACCES
    MorLog.my_debug("ERROR: Prepaid Invoice File cannot be accessed!")
    return nil
  ensure
    # Remove the temporal file
    system "rm -rf #{filename}"
  end

  private

  # Based on what params user selected or if they were not passed based on params saved in session
  # return user_id, that should be filtered for financial statements. if user passed clear as param
  # return nil

  # *Params*
  # +session_options+ hash including :user_id, might be nil

  # *Return*
  # +user_id+ integer or nil
  def financial_statements_user_id(session_options)
    not_params_clear = !params[:clear]
    params_user_id, session_user_id = [params[:s_user_id], session_options.try(:[], :s_user_id)]

    if current_user.usertype == 'user'
      user_id = current_user_id
    elsif params_user_id && not_params_clear
      user_id = params_user_id || 'all'
      user_id = -1 if params[:s_user].present? && params_user_id.to_i == -2
    elsif session_options && session_user_id && not_params_clear
      user_id = session_user_id
    else
      user_id = nil
    end

    user_id
  end

=begin
  Based on what params user selected or if they were not passed based params saved in session
  return status, that should be filtered for financial statements.

  *Params*
  +session_options+ hash including :status, might be nil

  *Returns*
  +status+ - string, one of valid_status_values, by default 'all'
=end
  def financial_statements_status(session_options)
    not_params_clear = !params[:clear]
    params_status, session_options_status = [params[:status], session_options.try(:[], [:status])]

    if (@valid_status_values.include? params_status) && not_params_clear
      params_status
    elsif session_options && (@valid_status_values.include? session_options_status) && not_params_clear
      session_options_status
    else
      'all'
    end
  end

=begin
  convert prices in statements from default system currency to
  currency that is set in session

  *Params*
  +statement+ iterable of financial stement data(they rices should be in system currency)

  *Returns*
  +statement+ same object that was passed only it's prices recalculated in user selected currency
=end
  def convert_to_user_currency(statements)
    exchange_rate = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])

    statements.each { |statement|
      statement.price = statement.price.to_d * exchange_rate
      statement.price_with_vat = statement.price_with_vat.to_d * exchange_rate
    }

    statements
  end

=begin
  financial data returned by invoice, credit notes or payments may lack some information,
  this method's purpose is to retrieve information from part of financial statement(let's
  say financial stetement is devided in three parts: credit note, invoice and payments) about
  paid/unpaid financial data. if there is no such data return default, default meaning that
  there is no paid/unpaid part, so it's count and price is 0.
  TODO should rename valiable names, cause they dont make much sense. maybe event method name
  should be renamed
  Note that price and price including taxes will be converted from default system currency to
  user selected

  *Params*
  +statement+ - part of financial statement
  +status+ - whatever valid status might have the statement

  *Returns*
  +paid/unpaid_statement+ if there is such statement that satisfies condition(status) returns it,
   else returns default statement.
=end
  def get_financial_statement(statements, status)
    statements.each { |statement|
      if statement.status == status
        return statement
      end
    }
    #Return default financial data if required stetement was not found
    Struct.new('We', :count, :price, :price_with_vat, :status)
    return Struct::We.new(0, 0, 0, status)
  end

=begin
  Only one who may not have permissions to view financial statements
  is accountant. If he does not have 'can see finances', 'invoices manage'
  and 'manage payments' permissions to read he cannot view financial statements.
  In any other case everyone can view treyr user's invoices, credit notes and payments.
=end
  def can_view_financial_statements?
    if accountant? and (not current_user.accountant_allow_read('can_see_finances') or not current_user.accountant_allow_read('payments_manage') or not current_user.acoutnant_alllow_read('invoices_manage'))
      return false
    else
      return true
    end
  end

  def financial_statements_filter
    if not can_view_financial_statement?
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
  end

  def call_details_for_user(user, period_start_with_time, period_end_with_time, use_index = 0)
    MorLog.my_debug("\nChecking user with id: #{user.id}, name: #{nice_user(user)}, type: #{user.usertype}", 1)

    use_index = 0
    MorLog.my_debug("Search with index ? : #{use_index}", 1)
    # --- Outgoing calls ---

    # find users outgoing (made by this resellers users) calls stats (count and sum price)
    if user.is_reseller? || user.is_partner?
      outgoing_calls_by_users,
      outgoing_calls_by_users_price,
      incoming_calls_by_users,
      incoming_calls_by_users_price = user.users_outgoing_calls_stats_in_period(period_start_with_time,
                                                                                period_end_with_time,
                                                                                use_index)
      MorLog.my_debug("  Outgoing calls by users: #{outgoing_calls_by_users}, for price: #{outgoing_calls_by_users_price}", 1)
      MorLog.my_debug("  Incoming calls by users: #{outgoing_calls_by_users}, for price: #{outgoing_calls_by_users_price}", 1)
    else
      outgoing_calls_by_users = 0
      outgoing_calls_by_users_price = 0
      incoming_calls_by_users = 0
      incoming_calls_by_users_price = 0
    end


    unless user.is_partner?
      # find own outgoing (made by this user) calls stats (count and sum price)
      outgoing_calls,
      outgoing_calls_price = user.own_outgoing_calls_stats_in_period(period_start_with_time,
                                                                     period_end_with_time,
                                                                     use_index)
      MorLog.my_debug("  Outgoing calls: #{outgoing_calls}, for price: #{outgoing_calls_price}", 1)

      # find own outgoing (made by this user) calls stats (count and sum price) of calls to dids
      outgoing_calls_to_dids,
      outgoing_calls_price_to_dids = user.own_outgoing_calls_stats_to_dids_in_period(period_start_with_time,
                                                                                     period_end_with_time,
                                                                                     use_index)
      MorLog.my_debug("  Outgoing calls to dids: #{outgoing_calls_to_dids}, for price: #{outgoing_calls_price_to_dids}", 1)


    # --- Incoming calls ---

      incoming_received_calls,
      incoming_received_calls_price = user.incoming_received_calls_stats_in_period(period_start_with_time,
                                                                                   period_end_with_time,
                                                                                   use_index)
      MorLog.my_debug("  Incoming RECEIVED calls: #{incoming_received_calls}, for price: #{incoming_received_calls_price}", 1)

      incoming_made_calls,
      incoming_made_calls_price = user.incoming_made_calls_stats_in_period(period_start_with_time,
                                                                           period_end_with_time,
                                                                         use_index)
    else
      # Partner Should not Be able to make/raceive calls There is no Need To Strain SQL
      incoming_received_calls = 0
      incoming_received_calls_price = 0
      incoming_made_calls = 0
      incoming_made_calls_price = 0

      incoming_calls_by_users = 0
      incoming_calls_by_users_price = 0

      outgoing_calls = 0
      outgoing_calls_price = 0
      outgoing_calls_to_dids = 0
      outgoing_calls_price_to_dids = 0
    end

    MorLog.my_debug("  Incoming MADE calls: #{incoming_made_calls}, for price: #{incoming_made_calls_price}", 1)

    return incoming_received_calls, incoming_received_calls_price, incoming_made_calls, incoming_made_calls_price, outgoing_calls_price, outgoing_calls_by_users_price, outgoing_calls, outgoing_calls_price, outgoing_calls_by_users, incoming_calls_by_users, incoming_calls_by_users_price, outgoing_calls_to_dids, outgoing_calls_price_to_dids
  end

  def find_invoice
    @invoice = Invoice.where(id: params[:id]).includes([:tax, :user]).first

    unless @invoice
      flash[:notice] = _('Invoice_was_not_found')
      redirect_to action: :invoices
    end
  end

  def find_invoice_new
    @invoice = Invoice.includes([:tax, :user]).where(id: params[:id]).first
    invoice_user = @invoice.user if @invoice

    unless (@invoice && [invoice_user.id.to_s, invoice_user.owner_id.to_s].include?(corrected_user_id.to_s))
      flash[:notice] = _('Invoice_was_not_found')
      redirect_to(:root) && (return false)
    end
  end

  def invoices_order_by(params, options)
    order_by_param_options = nil
    order_by = case params[:order_by].to_s
      when 'user'
        "users.first_name"
      when "number"
        order_by_param_options =  ", number"
        "LENGTH(invoices.number)"
      when "LENGTH(invoices.number)"
        order_by_param_options =  ", number"
        "LENGTH(invoices.number)"
      when 'invoice_type'
        "invoices.invoice_type"
      when 'period_start'
        "invoices.period_start"
      when 'period_end'
        "invoices.period_end"
      when 'issue_date'
        "invoices.issue_date"
      when 'sent_email'
        "invoices.sent_email"
      when 'sent_manually'
        "invoices.sent_manually"
      when 'paid'
        "invoices.paid"
      when "paid_date"
        "invoices.paid_date"
      when 'price'
        "invoices.price"
      when 'timezone'
        'invoices.timezone'
      when 'invoice_currency'
        'invoices.invoice_currency'
      else
        options[:order_by] ? options[:order_by] : "users.first_name"
    end

    without = order_by
    order_by = "users.first_name " + (options[:order_desc] == 1 ? 'DESC' : "ASC") + ", users.last_name" if order_by.to_s == "users.first_name"
    order_by += options[:order_desc].to_i == 1 ? ' DESC' : ' ASC'
    if !order_by_param_options.blank?
      order_by += order_by_param_options
      order_by += options[:order_desc].to_i == 1 ? ' DESC' : ' ASC'
    end
    return without, order_by
  end

  def manage_exchange_rates(invoice)
    invoice_currency = invoice.invoice_currency
    dc = params[:email_or_not] ? invoice.user.currency.name : session[:show_currency]
    dc = invoice_currency if invoice_currency.present?
    [dc, invoice.invoice_exchange_rate]
  end

  def to_old_yaml(object)
    object.to_json.gsub(',"', ' ').gsub('"', '').gsub(':', ': ')
  end

  def add_subscriptions_to_invoice(subscriptions, period_start, period_end, invoice, price, nc)
    subscriptions.each { |sub|
      service = sub.service
      service_price = service.read_attribute(:price)
      count_subscription = 0

      case service.servicetype
      when 'one_time_fee'
        # one-time-fee subscription only counts once for full price
        if (sub.activation_start >= period_start and sub.activation_start <= period_end)
          invd_price = service_price
          count_subscription = 1
        end
      when 'flat_rate'
        if sub.no_expire == 1
          if ((period_start.localtime.to_date)..(period_end.localtime.to_date)) === sub.activation_start.to_date
            invd_price = service_price
            count_subscription = 1
          end
        else
          start_date, end_date = subscription_period(sub, period_start, period_end)
          invd_price = service_price * (months_between(start_date.to_date, end_date.to_date)+1)
          count_subscription = 1
        end
      when 'periodic_fee'
        count_subscription = 1
        #from which day used?
        use_start = (sub.activation_start < period_start) ? period_start : sub.activation_start
        sub_activation_end = sub.activation_end
        #till which day used?
        use_end = (sub_activation_end.blank? or (sub_activation_end > period_end)) ? period_end : sub_activation_end
        start_date = use_start.to_date
        end_date = use_end.to_date
        days_used = end_date - start_date
        days_used_plus_one = (days_used.to_i + 1)
        service_periodtype = service.periodtype

        case service_periodtype
        when 'day'
          invd_price = service_price * days_used_plus_one
        when 'month'
          start_date_end_of_month = start_date.to_time.end_of_month

          if start_date.month == end_date.month and start_date.year == end_date.year
            total_days = start_date_end_of_month.day.to_i
            invd_price = service_price / total_days * days_used_plus_one
          else
            invd_price = 0
            months_between_start_and_end = months_between(start_date, end_date)

            if months_between_start_and_end > 1
              # jei daugiau nei 1 menuo. Tarpe yra sveiku menesiu kuriem nereikia papildomai skaiciuoti intervalu
              invd_price += (months_between_start_and_end - 1) * service_price
            end
            # suskaiciuojam pirmo menesio pabaigos ir antro menesio pradzios datas
            last_day_of_month = start_date_end_of_month.to_date
            last_day_of_month_date = end_date.to_time.end_of_month.to_date
            end_date_day = end_date.day

            if (start_date.day - end_date_day) == 1
              invd_price += service_price
            else
              invd_price += service_price/last_day_of_month.day * (last_day_of_month - start_date + 1).to_i
              invd_price += service_price/last_day_of_month_date.day * (end_date_day)
            end
          end
        end
      end

      if count_subscription == 1
        invd_price_dec = invd_price.to_d
        sub_memo = sub.memo
        memo = sub_memo ? ' - ' + sub_memo.to_s : ''
        nice_invoice_price = invoice.nice_invoice_number(invd_price_dec, { nc: nc, apply_rounding: true })
        invoice.invoicedetails.create( name: service.name.to_s + memo, price: nice_invoice_price, quantity: '1')
        price += nice_invoice_price.to_d
      end
    }

    [invoice, price]
  end

  def calculate_invoices_totals
    @total_price, @total_price_with_vat = [0, 0]

    currencies = {
      show_currency: session[:show_currency].to_s.upcase,
      default_currency: session[:default_currency].to_s.upcase
    }

    @invoice_query.each do |invoice|
      amounts = {
        price: invoice.raw_price, price_with_vat: invoice.raw_price_with_vat,
        currency: invoice.invoice_currency.to_s.upcase, exchange_rate: invoice.invoice_exchange_rate.to_f
      }

      if currencies[:show_currency] == amounts[:currency]
        amounts[:price] *= amounts[:exchange_rate]
        amounts[:price_with_vat] *= amounts[:exchange_rate]
      elsif currencies[:show_currency] != currencies[:default_currency]
        show_exchange_rate = Currency.where(name: currencies[:show_currency]).first.exchange_rate.to_f
        amounts[:price] *= show_exchange_rate
        amounts[:price_with_vat] *= show_exchange_rate
      end

      @total_price += amounts[:price]
      @total_price_with_vat += amounts[:price_with_vat]
    end
  end

  def invoice_attributes
    params[:invoice].merge({ issue_date: params[:issue_date_system_tz], due_date: params[:due_date_system_tz],
                               status_changed: params[:status_changed_system_tz]})
  end

  def initialize_options
    options = session[:invoice_lines_options] || {}
    param_keys = ['order_by', 'order_desc', 'search_on', 'page', 's_prefix']

    params.select{ |key, _| param_keys.member?(key) }.each do |key, value|
      options[key.to_sym] = value.to_s
    end

    Application.change_separators(options, '.')
    options[:csv] = params[:csv].to_i

    options = clear_options(options) if params[:clear]
    options[:clear] = ([:s_nice_user, :s_number, :s_period_start, :s_period_end, :s_issue_date, :s_status,
      :s_min_amount, :s_max_amount, :s_currency].any? { |key| options[key].present? })
    options[:exchange_rate] = change_exchange_rate

    options
  end

  def nice_invoice_details_list(options, items_per_page, invoice_id)
    selection_all, clear_search = Invoicedetail.invoice_details_filter(options, invoice_id)
    fpage, total_pages, options = Application.pages_validator(session, options, selection_all.count)
    selection_in_page_count, selection_in_page = selection_all.invoice_details_order_by(options, fpage, items_per_page)
    [selection_all, selection_in_page_count, selection_in_page, total_pages, options, clear_search]
  end

  def total_inv_line_amount(invoice_lines)
    @total_amount, @total_time = [0, 0]
    invoice_exchange_rate = @invoice.invoice_exchange_rate.to_f

    invoice_lines.each do |invoice_line|
      @total_amount += invoice_line.read_attribute(:price).to_f * invoice_exchange_rate
      @total_time += invoice_line.total_time.to_i
    end
  end

  def invoice_type(invoice, user)
    if invoice.invoice_type.to_s == 'prepaid' and user.owner_id == 0
      ['Prepaid_', 'prepaid']
    else
      ['', 'postpaid']
    end
  end

  def validate_period(type, till_time)
    users = User.where("postpaid = ? AND owner_id = ? AND usertype NOT IN('admin', 'accountant')",
      type == 'postpaid' ? 1 : 0, current_user.id)
    users.try(:each) do |user|
      next if usertime_over?(user, till_time)
      flash[:notice] = _('Period_not_over_for_some_users')
      return false
    end
    true
  end

  def validate_period_user(user, till_time)
    return true if usertime_over?(user, till_time)
    flash[:notice] = _('Period_not_over_for_this_user')
    false
  end
end
