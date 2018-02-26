# -*- encoding : utf-8 -*-
# Call Shop Addon.
class CallshopController < ApplicationController

  layout "callshop", except: [:new, :free_booth, :topup_booth, :invoice_print, :invoice_edit, :comment_update, :number_digits]

  before_filter :check_localization
  before_filter :use_default_callshop, only: [:reset_booth]
  skip_before_filter :redirect_callshop_manager, :number_digits
  skip_before_filter :check_session, only: [:show]
  before_filter :set_content_type

  @@invoice_searchable_cols = ["created_at", "balance", "state", "comment", "invoice_type"]
  @@invoice_default_search = { order_by: "created_at", order_dir: "DESC", page: 1 }

  @@callshop_view = []
  @@callshop_edit = [:show, :show_json, :new, :reserve_booth, :update, :free_booth, :release_booth, :comment_update,
    :topup_booth, :topup_update, :invoices, :invoice_print, :invoice_edit, :get_number_data]
  before_filter(only: @@callshop_view + @@callshop_edit) { |method|
    allow_read, allow_edit = method.check_read_write_permission(@@callshop_view, @@callshop_edit,
      { role: "reseller", right: :res_call_shop, ignore: true })
    method.instance_variable_set :@callshop, allow_read
    method.instance_variable_set :@callshop, allow_edit
    true
  }

  before_filter :find_shop_and_authorize, except: [:show_json, :get_number_data, :number_digits]
  # manager view
  def show
    @users = @cshop.users
    unless @users
      flash[:notice] = _('Usesr_Were_Not_Found')
      (redirect_to :root) && (return false)
    end
    session[:callshop] = {}
    session[:callshop][:booths] ||= @users.collect { |user| user.id }
    @users.each { |user| store_invoice_in_session(user, user.cs_invoices.first) }
  end

  # load JSON using data about users from variable that is set in show_v2
  def show_json
    if session[:callshop] and session[:callshop][:booths] and session[:callshop][:booths].size > 0
      booths = status_for_ajax(session[:callshop][:booths])
      json_hash = {
          #        free_booths: booths.collect{|b| b[:state] if b[:state] == "free"}.compact.size,
          #        active_calls: booths.collect{|b| b[:state] if b[:state] == "occupied"}.compact.size,
          booths: booths}
      render json: json_hash.to_json
    else
      render text: "{}"
    end
  end

  # reservation form (mean to be used by xhr)
  # in case we cant find current user redirect to login page
  def new
    @invoice = CsInvoice.new(user_id: params[:user_id])
    if current_user
      @currency = current_user.currency.name #Currency.get_default.name
      render layout: false
    else
      redirect_to controller: 'callc', action: 'logout' and return false
    end
  end

  # reservation action (xhr)
  def reserve_booth
    @invoice = CsInvoice.new(params[:invoice].try(:merge!,{callshop_id: params[:id]}))

    @user, @old_invoice, @invoice = Callshop.reserve_booth(@invoice, params)

    store_invoice_in_session(@user, @invoice)

    respond_to do |format|
      format.json {
        render json: @invoice.attributes.merge(created_at: nice_date_time(@invoice.created_at)).to_json
      }
    end
  end

  def reset_booth
    @booth = User.where(id: params[:user_id]).first
    @user = User.where(id: params[:user_id]).first
    @invoice = @booth.cs_invoices.first

    terminate_calls

    with_invoice = params[:with_invoice].to_i == 1
    manage_invoice(with_invoice)

    reserve_booth
  end

  # balance update topup action (xhr)
  def update
    @invoice = CsInvoice.where(id: params[:invoice_id]).first

    @user, @invoice = Callshop.update(@invoice, params)

    store_invoice_in_session(@user, @invoice)

    respond_to do |format|
      format.json { render json: 'OK'.to_json }
    end
  end

  # booth summary form (xhr)
  def free_booth
    @booth = User.where(id: params[:user_id]).first
    @invoice = @booth.cs_invoices.first

    terminate_calls

    render layout: false
  end

  # booth release action (xhr)
  def release_booth
    @user = User.where(id: params[:user_id]).first
    @invoice = @user.cs_invoices.first

    render text: _('Invoice_not_found') unless @invoice

    manage_invoice
  end

  # comment update form (xhr)
  def comment_update
    @invoice = User.where(id: params[:user_id]).first.cs_invoices.first
    render layout: false
  end

  # booth topup form (xhr)
  def topup_booth
    @invoice = CsInvoice.where(["cs_invoices.user_id = ? AND state = 'unpaid'", params[:user_id]]).first
    render layout: false
  end

  def topup_update
    logger.debug " >> Finding targets"
    @invoice = CsInvoice.includes(:user, :tax).where(["cs_invoices.id = ?", params[:invoice_id]]).first

    params[:invoice][:balance_with_tax] = params[:invoice][:balance].to_d
    if params[:increase] and params[:invoice] and !params[:invoice][:balance].to_d.zero?
      @user, @invoice = Callshop.topup_update(@invoice, params)

      store_invoice_in_session(@user, @invoice)
    else
      logger.debug " >> Not enough params"
      logger.debug "   >> Increase? #{params[:increase]}"
      logger.debug "   >> Adjustment: #{params[:invoice][:balance]}" if params[:invoice] and params[:invoice][:balance]
    end
    render text: "OK"
  end

  # invoices view
  def invoices
    @search_params = session[:callshop_invoices_order] ||= @@invoice_default_search
    @currency = current_user.currency.name #Currency.get_default.name
    @search_params = invoices_parse_params(params, @search_params)
    @total_invoices = @cshop.invoices.where("paid_at IS NOT NULL").size
    @total_pages = (@total_invoices.to_d / session[:items_per_page].to_d).ceil
    @search_params[:page] = correct_page_number(@search_params[:page], @total_pages)
    @invoices = @cshop.invoices.where(["paid_at IS NOT NULL"]).
                                order(invoices_order(@search_params)).
                                offset((@search_params[:page].to_i - 1) * session[:items_per_page]).
                                limit(session[:items_per_page]).all

    @invoices = @cshop.invoices.where(["paid_at IS NOT NULL"]).
                                order(invoices_order(@search_params)).
                                offset((@search_params[:page].to_i - 1) * session[:items_per_page]).
                                limit(session[:items_per_page]).all
    respond_to do |format|
      format.html {}
      format.json {
        invoices = @invoices.map { |invoice|
          {id: invoice.id,
           issue_date: invoice.created_at.strftime("%Y-%m-%d %H:%M:%S"),
           amount: format_money(invoice.balance, @currency, session[:nice_number_digits]),
           status: invoice_state(invoice),
           comment: invoice.comment,
           user_type: invoice.invoice_type}
        }
        render text: {invoices: invoices, pages: page_select_header(@search_params[:page].to_i, @total_pages, {}, {}, "array")}.to_json
      }
    end
    session[:callshop_invoices_order] = @search_params
  end

  def rate_search
  end

  # invoice print
  def invoice_print
    @invoice = CsInvoice.where(id: params[:invoice_id]).first
    render layout: false
  end

  def invoice_edit
    @invoice = CsInvoice.where(id: params[:invoice_id]).first
    @invoice_calls = @invoice.calls((@invoice.paid_at || @invoice.updated_at).strftime("%Y-%m-%d %H:%M:%S"))
    render layout: false
  end

  def get_number_data
    number = params[:number]
    arguments = {
        "directions.name" => "direction_name",
        "directions.code" => "code",
        "destinations.prefix" => "prefix",
        "destinations.name" => "dest_name",
        "rates.id" => "rate_id"
    }
    joins = [
        "LEFT JOIN directions on (destinations.direction_code = directions.code)",
        "LEFT JOIN rates ON (rates.destination_id = directions.id)",
    ]
    sql = "SELECT #{arguments.map { |key, value| "#{key} AS #{value}" }.join(", ")} FROM destinations " +
      "#{joins.join("\n")} WHERE prefix = SUBSTRING('#{number}', 1, LENGTH(destinations.prefix)) " +
      "ORDER BY LENGTH(destinations.prefix) DESC LIMIT 1"
    rez = ActiveRecord::Base.connection.select_all(sql)
    result = []
    if rez and rez[0]
      rez = rez[0]
      MorLog.my_debug("..........................")
      MorLog.my_debug(sql)

      destination = [rez["direction_name"], rez["dest_name"]].compact

      result = [{type: "with_flag", flag: rez["code"].downcase, name: _("Destination"), value: destination.join(" ")}, {name: "SOMENAME", value: "somevalue"}]
    end
    render json: result.to_json
  end

  # action for balance updating from .js
  def number_digits
    render text: (!session or !session[:nice_number_digits]) ? Confline.get_value("Nice_Number_Digits") : session[:nice_number_digits]
  end

  private

  def find_shop_and_authorize
    @cshop = Callshop.includes(users: [:cs_invoices]).where("groups.id = ? AND usergroups.gusertype = 'user'", params[:id]).includes(users: [:cs_invoices]).order("usergroups.position asc").first
    unless @cshop
      reset_session
      flash[:notice] = _('Callshop_was_not_found_or_is_empty')
      if session[:user_id] != nil
        (redirect_to :root) && (return false)
      else
        redirect_to controller: "callc", action: "login" and return false
      end
    end

    unless session[:cs_group] && @cshop.id == session[:cs_group].group_id
      reset_session
      flash[:notice] = _('You_are_not_authorized_to_manage_callshop')
      if session[:user_id] != nil
        (redirect_to :root) && (return false)
      else
        redirect_to controller: "callc", action: "login" and return false
      end
    end

    @currency = current_user.currency.name #@cshop.manager_user.currency.name #Currency.get_default.name
  end

  def invoices_parse_params(params, search_params)
    search_params[:page] = params[:page] if params[:page] and params[:page].to_i > 0
    search_params[:order_by] = params[:order_by].to_s if params[:order_by] and @@invoice_searchable_cols.include?(params[:order_by].to_s)
    search_params[:order_dir] = params[:order_dir].upcase if params[:order_dir] and ["ASC", "DESC"].include?(params[:order_dir].upcase)
    search_params
  end


  def invoices_order(search_params)
    col = @@invoice_searchable_cols.include?(search_params[:order_by]) ? search_params[:order_by] : @@invoice_default_search[:order_by]
    dir = ["ASC", "DESC"].include?(search_params[:order_dir].upcase) ? search_params[:order_dir].upcase : @@invoice_default_search[:order_dir]
    "#{col} #{dir}"
  end

  def status_for_ajax(users)

    session[:callshop] ||= {}
    #MorLog.my_debug( session[:callshop].inspect)
    session[:callshop][:cs_invoices] ||= {}

    old_countries = session[:callshop][:countries] ||= {}
    countries = {}
    columns = {
        id: 'users.id',
        number: 'activecalls.dst',
        prefix: 'activecalls.prefix',
        #here getting only answer time
        duration: 'activecalls.answer_time',
        user_rate: 'activecalls.user_rate',
        user_type: 'users.postpaid',
        timestamp: 'activecalls.start_time',
        balance: 'ABS(users.balance)',
        server: 'activecalls.server_id',
        channel: 'activecalls.channel',
    }

    sql = "SELECT #{columns.map { |key, value| "#{value} AS #{key.to_s}" }.join(", ")} FROM users
  LEFT JOIN activecalls ON (users.id = activecalls.user_id)
  WHERE users.id IN (#{users.join(", ")});"
    #MorLog.my_debug("-----------------------------------------------\n"  + sql.to_s)
    rez = ActiveRecord::Base.connection.select_all(sql)
    all_booths = rez.inject([]) { |booths, row|
      booth = {id: nil, created_at: nil, number: nil, duration: nil, user_rate: nil, country: nil, user_type: nil, timestamp: nil, balance: nil, state: nil, server: nil, channel: nil}
      row.each { |key, value| booth[key.to_sym] = value if booth.has_key?(key.to_sym) } # parse values from SQL

      #replaced duration counting from sql NOW() to Time.now.getlocal()
      #booth[:duration] = nice_time(booth[:duration])
      if !booth[:duration].to_s.blank?
        booth[:duration] = nice_time(Time.now.getlocal()- Time.parse(booth[:duration].to_s))
      else
        booth[:duration] = "-"
      end

      booth[:balance] = nice_number(booth[:balance])
      booth[:user_type] = (booth[:user_type].to_i == 1 ? "postpaid" : "prepaid")

      if booth[:number]
        if countries[booth[:number]].blank?
          countries[booth[:number]] ||= old_countries[booth[:number]] ||= Direction.name_by_prefix(row["prefix"])
        end
        booth[:country] = countries[booth[:number]]
      end

      # Add invoice data
      if invoice = session[:callshop][:cs_invoices][booth[:id].to_s]
        booth[:comment] = invoice[:comment]
        booth[:created_at] = invoice[:created_at]
        updated = invoice[:updated_at]
        if updated
          booth[:timestamp] = booth[:timestamp] ? booth[:timestamp] : updated
        else
          booth[:timestamp] = nil
        end
      else
        booth[:number] = booth[:comment] = booth[:user_rate] = booth[:timestamp] = booth[:duration] = booth[:balance] = nil
      end
      booth[:state] = booth_state(booth)
      booths.push(booth)
    }
    session[:callshop][:countries] = countries
    all_booths
  end

  def booth_state(booth)
    if !booth[:created_at].blank? and !booth[:duration].blank?
      "occupied"
    else
      booth[:created_at] ? "reserved" : "free"
    end
  end

  def store_invoice_in_session(user, invoice)
    invoice = {comment: invoice.comment, created_at: nice_date_time(invoice.created_at), updated_at: invoice.updated_at.to_i} if invoice
    user = user.id if user.class == User
    session[:callshop] ||= {}
    session[:callshop][:cs_invoices] ||= {}
    session[:callshop][:cs_invoices][user.to_s] = invoice
  end

  def correct_page_number(page, total_pages, min_pages = 1)
    page = total_pages.to_i if page.to_i > total_pages.to_i
    page = min_pages.to_i if page.to_i < min_pages.to_i

    return page
  end

  def use_default_callshop
    default_callshop = Callshop.where(id: params[:id].to_i).first
    if default_callshop.simple_session?
      params[:invoice] = {}
      params[:invoice][:invoice_type] = default_callshop.nice_type
      params[:invoice][:balance] = default_callshop.balance.to_d
      params[:invoice][:comment] = ''
      params[:invoice][:user_id] = params[:user_id].to_s
    end
  end

  def terminate_calls
    if @invoice
      begin
        # terminated calls if any
        server_id, channel = params.values_at(:server, :channel)

        unless server_id.blank? or channel.blank?
          server = Server.where(id: server_id.to_i, server_type: 'asterisk').first

          if server
            server.ami_cmd("soft hangup #{channel}")
          end

          MorLog.my_debug "Hangup channel: #{channel} on server: #{server_id}"
        end
     rescue => e
        @status = _('Unable_to_terminate_calls_check_connectivity')
      end
    end
  end

  def manage_invoice(store_invoice = true)
    if store_invoice
      if @invoice
        @user.update_attributes(balance: 0, blocked: 1)
        opts = {
            state: (params[:full_payment].eql?('true')) ? 'full' : 'partial'
        }
        calls = @invoice.calls
        if calls && calls.size > 0
          @invoice.update_attributes({comment: params[:comment], balance: params[:balance], paid_at: Time.now}.merge(opts))
        else
          @invoice.destroy
        end
        @user.cs_invoices.where(state: 'unpaid').all.each(&:destroy)
        store_invoice_in_session(@user, nil)
        #render text: 'OK'
      else
        #render text: _('Invoice_not_found')
      end
    else
      @invoice.try(:destroy)
    end
  end

end
