# -*- encoding : utf-8 -*-
# Tariffs and Rates managing, Rates import.
class TariffsController < ApplicationController

  require 'csv'
  include UniversalHelpers
  layout 'callc'

  before_filter :check_post_method, only: [:destroy, :create, :update, :rate_destroy, :ratedetail_update, :ratedetail_destroy, :ratedetail_create, :artg_destroy, :user_rate_update, :user_rate_delete, :user_rates_update, :user_rate_destroy, :day_destroy, :day_update, :update_tariff_for_users, :delete_all_rates, :update_rates_by_destination_mask]
  before_filter :check_localization
  before_filter :authorize, except: [:destinations_csv]
  before_filter :check_if_can_see_finances, only: [:new, :create, :list, :edit, :update, :destroy, :rates_list, :import_csv, :delete_all_rates, :make_user_tariff, :make_user_tariff_wholesale]
  before_filter :find_user_from_session, only: [:generate_personal_rates_csv, :generate_personal_rates_pdf, :generate_personal_wholesale_rates_csv, :user_rates, :user_rates_detailed, :common_use_prov_rates]
  before_filter :find_user_tariff, only: [:generate_personal_rates_csv, :generate_personal_rates_pdf, :generate_personal_wholesale_rates_csv, :user_rates, :user_rates_detailed]
  before_filter :find_tariff_whith_currency, only: [:generate_providers_rates_csv, :generate_user_rates_pdf, :generate_user_rates_csv]
  before_filter :find_tariff_from_id, only: [:check_tariff_time, :rate_new_by_direction, :edit, :update, :destroy, :tariffs_list, :rates_list, :rate_new_quick, :rate_try_to_add, :rate_new, :rate_new_by_direction_add, :delete_all_rates, :user_rates_list, :user_arates_full, :user_rates_update, :make_user_tariff, :make_user_tariff_wholesale, :make_user_tariff_status, :make_user_tariff_status_wholesale, :ghost_percent_edit, :ghost_percent_update, :import_xls, :import_csv2, :update_rates, :update_rates_by_destination_mask]
  before_filter :find_rate_from_id, only: [:ratedetails_manage, :rate_details, :ard_manage]
  before_filter :find_rate_and_ratedetail_from_id, only: [:ratedetail_edit, :ratedetail_update]
  before_filter :check_user_for_tariff, only: [:edit, :update, :destroy, :tariffs_list, :check_tariff_time, :rate_new,
    :ghost_percent_edit, :ghost_percent_update, :rate_try_to_add, :delete_all_rates, :user_rates_list,
    :user_arates_full, :import_xls, :import_csv2, :rates_list, :generate_user_rates_csv]

  before_filter { |method|
    view = [:index, :list, :rates_list, :user_rates_list, :user_arates_full, :user_arates, :day_setup]
    edit = [:new, :create, :edit, :update, :destroy, :user_rate_update, :user_rates_update, :user_ard_time_edit, :ard_manage, :day_add, :day_edit, :day_update, :ghost_percent_edit, :ghost_percent_update]
    allow_read, allow_edit = method.check_read_write_permission(view, edit, { role: 'accountant', right: :acc_tariff_manage, ignore: true })
    method.instance_variable_set :@allow_read, allow_read
    method.instance_variable_set :@allow_edit, allow_edit
    true
  }

  def index
    redirect_to(action: :list) && (return false)
  end

  def list
    user = User.where(id: correct_owner_id).first
    unless user
      flash[:notice]=_('User_was_not_found')
      redirect_to :root
      return false
    end
    user_id = user.id

    @page_title = _('Tariffs')
    @page_icon = 'view.png'

    @allow_manage, @allow_read = accountant_permissions
    params_s_prefix = params[:s_prefix]
    if params_s_prefix
      @s_prefix = params_s_prefix.present? ? params_s_prefix : '%'
      dest = Destination.where("prefix LIKE ?", @s_prefix.to_s).all
    end
    @des_id = []
    @des_id_d = []
    if dest and dest.size.to_i > 0
      dest.each do |destination|
        next if destination.destinationgroup_id.blank?
        @des_id << destination.id
        @des_id_d << destination.destinationgroup_id
      end

      if @des_id.blank? || @des_id_d.blank?
        con = ''
        cond = ''
        incl = ''
      else
        cond = " AND rates.destination_id IN (#{@des_id.join(',')})"
        con = " AND rates.destinationgroup_id IN (#{@des_id_d.join(',')}) "
        @search = 1
        incl = [:rates]
      end
    else
      con = ''
      cond = ''
      incl = ''
    end

    tariff =  Tariff.includes(incl).references(incl).order('tariffs.name ASC').group('tariffs.id')

    @prov_tariffs = tariff.where("purpose = 'provider' AND owner_id = '#{user_id}' #{cond}").to_a
    @user_tariffs = tariff.where("purpose = 'user' AND owner_id = '#{user_id}' #{con}").to_a
    @user_wholesale_tariffs = tariff.where("purpose = 'user_wholesale' AND owner_id = '#{user_id}' #{cond}").to_a
    @user_by_provider_tariffs = tariff.where("purpose = 'user_by_provider' AND owner_id = '#{user_id}' #{cond}").to_a


    @show_currency_selector =1
    @tr = []
    tariffs_rates = Tariff.select('tariffs.id, COUNT(rates.id) as rsize')
                          .where("(purpose = 'provider' or purpose = 'user_wholesale' ) AND owner_id = '#{user_id}'")
                          .joins('LEFT JOIN rates ON (rates.tariff_id = tariffs.id)')
                          .order('tariffs.name ASC').group('tariffs.id').to_a
    tariffs_rates.each { |tariff| @tr[tariff.id] = tariff.rsize.to_i }

    # deleting not necessary session vars - just in case after crashed csv rate import
    %i{
      file status_array update_rate_array short_prefix_array bad_lines_array
      bad_lines_status_array manual_connection_fee manual_increment manual_min_time
    }.each { |key| session[key] = nil }
  end

  def new
    @page_title = _('Tariff_new')
    @page_icon = 'add.png'
    @tariff = Tariff.new
    @currs = Currency.get_active
  end

  def create
    @page_title = _('Tariff_new')
    @page_icon = 'add.png'

    @currs = Currency.get_active
    validate_delta_params if admin? || accountant?

    user = User.where(id: correct_owner_id).first
    @tariff = user.owned_tariffs.build(params[:tariff])

    if @tariff.save
      flash[:status] = _('Tariff_was_successfully_created')
      redirect_to action: 'list'
    else
      flash_errors_for(_('Tariff_Was_Not_Created'), @tariff)
      render :new
    end
  end

  # before_filter : tariff(find_taririff_from_id)
  def edit
    @page_icon = 'edit.png'
    @page_title = _('Tariff_edit')
    @no_edit_purpose = true
    @currs = Currency.get_active
    @delta_value = @tariff.delta_value
    @delta_percent = @tariff.delta_percent

  end

  # before_filter : tariff(find_taririff_from_id)
  def update
    @page_icon = 'edit.png'
    @currs = Currency.get_active
    validate_delta_params if admin? || accountant?

    if @tariff.update_attributes(params[:tariff])
      flash[:status] = _('Tariff_was_successfully_updated')
      @tariff.updated
      redirect_to action: 'list', id: @tariff
    else
      flash_errors_for(_('Tariff_Was_Not_Updated'), @tariff)
      render :edit
    end
  end

def update_rates
  update_rates_owner = Tariff.where(id: params[:id]).first.owner_id
  no_rates = Rate.where(tariff_id: params[:id]).first
  if (((update_rates_owner != current_user_id) && !accountant?) || (accountant? && update_rates_owner != 0)) || no_rates.blank?
    dont_be_so_smart
    (redirect_to :root) && (return false)
  end

  @page_icon = 'pencil.png'
  @page_title = _('update_rates_by_destination_mask')
  @help_link = 'http://wiki.kolmisoft.com/index.php/Rates_Update'

  @rate_updater = Tariff::RateUpdater.new
  end

  def update_rates_by_destination_mask
    @page_icon = 'pencil.png'
    @page_title = _('update_rates_by_destination_mask')
    @help_link = 'http://wiki.kolmisoft.com/index.php/Rates_Update'

    @rate_updater = Tariff::RateUpdater.new(
      dg_name: params[:dg_name].to_s,
      rate: params[:new_rate].to_s.try(:sub, /[\,\.\;]/, ".").try(:strip),
      tariff: @tariff,
      exchange_rate: 1
    )

    if @rate_updater.update_rates
      @tariff.update_time
      flash[:status] = _('rates_successfully_updated')
      redirect_to action: :rates_list , id: @tariff.id, st: session[:destination_first_letter]
    else
      flash_errors_for(_('rates_were_not_updated'), @rate_updater)
      render 'update_rates'
    end
  end

  # before_filter : tariff(find_taririff_from_id)
  def destroy
    if @tariff.able_to_delete?
      @tariff.delete_all_rates
      @tariff.destroy
      flash[:status] = _('Tariff_deleted')
    else
      flash_errors_for(_('Tariff_not_deleted'), @tariff)
    end
    redirect_to action: 'list'
  end

  # ================== TARIFFS LIST =====================

  # before_filter : tariff(find_taririff_from_id)
  def tariffs_list
    @page_title = _('Tariff_list')
    @page_icon = 'view.png'
    tariff_id = @tariff.id
    @user = User.where(tariff_id: tariff_id).all
    @cardgroup = Cardgroup.where(tariff_id: tariff_id).all
  end


  # =============== RATES FOR PROVIDER ==================

  # before_filter : tariff(find_taririff_from_id)
  def rates_list
    tariff_id = @tariff.id
    current_user_id = current_user.id.to_i
    @allow_manage, @allow_read = accountant_permissions
    @page_title = _('Rates_for_tariff')
    @can_edit = true
    @effective_from_active = ( !user? && ['provider', 'user_wholesale'].include?(@tariff.purpose.to_s))

    @can_edit = false if reseller? && @tariff.owner_id != current_user_id &&
      CommonUseProvider.where(reseller_id: current_user_id, tariff_id: tariff_id).first

    params_s_prefix = params[:s_prefix]

    @letters_to_bold = @tariff.rates.select('UPPER(LEFT(destinations.name, 1)) AS first_letter')
                                .joins('JOIN destinations ON (rates.destination_id = destinations.id)')
                                .joins('JOIN directions ON (destinations.direction_code = directions.code)')
                                .where(@s_prefix.present? ? "destinations.prefix LIKE '#{params_s_prefix.to_s}'" : '')
                                .group('first_letter').collect(&:first_letter)


    @directions_first_letters = Rate.select('destinations.name AS name').
                                     joins('LEFT JOIN destinations on rates.destination_id = destinations.id').
                                     where("rates.tariff_id = #{tariff_id}").
                                     order('destinations.name ASC').group('SUBSTRING(destinations.name,1,1)').to_a

    @directions_first_letters.map! { |rate| rate.name[0..0] if rate.name }
    @st = (params[:st] ? params[:st].upcase : @directions_first_letters[0]).to_s
    @st = 'A' if @st.blank?
    @st = nil if params[:s_prefix].present?

    @directions_name_query = @st.present? ? ['directions.name LIKE ?', @st.to_s + '%'] : ''

    if params_s_prefix
      @s_prefix = params_s_prefix.present? ? params_s_prefix : '%'
    end

    @directions_present = Direction.where(@directions_name_query).all.present?

    @page = params[:page] ? params[:page].to_i : 1
    @page = 1 if @page < 1
    record_offset = (@page - 1) * session[:items_per_page].to_i
    select = "rates.*, destinations.name as destinations_name"
    destinations_join = "LEFT JOIN destinations on rates.destination_id = destinations.id"
    condition = "rates.tariff_id = #{tariff_id} AND "
    condition += params_s_prefix ? "rates.prefix LIKE #{ActiveRecord::Base::sanitize(@s_prefix.to_s)}" : "destinations.name like #{ActiveRecord::Base::sanitize(@st + '%')}"

    destination_name_order = ''
    if params_s_prefix
      @search = 1
      rate_count = Rate.where(condition).count
    else
      destination_name_order = 'destinations.name ASC, '
      rate_count = Rate.joins(destinations_join).where(condition).count
    end

    if @effective_from_active
      select << ", IF(IFNULL(rates.effective_from, 0) = rates2.max_effective_from, 1, 0) AS active"
      join = "LEFT JOIN (
                        SELECT rates.prefix, IFNULL(MAX(effective_from), 0) AS max_effective_from
                        FROM rates
                        INNER JOIN (
                                    SELECT rates.prefix
                                    FROM rates
                                    #{destinations_join}
                                    WHERE #{condition}
                                    ORDER BY #{destination_name_order}rates.prefix ASC
                                    LIMIT #{session[:items_per_page].to_i} OFFSET #{record_offset}
                                   ) rates2 ON rates.prefix = rates2.prefix

                        WHERE (effective_from < now() OR effective_from IS NULL) AND tariff_id = #{tariff_id}
                        GROUP BY prefix
                        ) rates2 ON rates.prefix = rates2.prefix"
      effective_from_order = ", rates.effective_from DESC"
    end

    @rates = Rate.select(select).joins(join)
                                .joins(destinations_join)
                                .where(condition)
                                .group('rates.id')
                                .order("#{destination_name_order}rates.prefix ASC#{effective_from_order}")
                                .offset(record_offset)
                                .limit(session[:items_per_page].to_i).all

    @total_pages = (rate_count.to_f / session[:items_per_page].to_f).ceil
    @letter_select_header_id = tariff_id
    @page_select_header_id = tariff_id
  end

  def directions_list
    return dont_be_so_smart unless request.xhr?
    respond_to do |format|
      format.js
    end
  end
  # Checks if prefix is available and has no set rates.
  # post data - prefix that needs to be checked.
  def check_prefix_availability
    @prefix = (params.keys.select { |parameter| parameter =~ /[0-9]+/ })[0]
    @destination = Destination.joins(:direction).
        select('destinations.*, destinations.name AS destination_name, directions.name AS direction_name').
        where(prefix: @prefix).first
    # unless @destination.present?
    #   @destination = Application.find_closest_destinations(@prefix)
    # end
    @rate = Rate.where(prefix: @prefix, tariff_id: params[:tariff_id]).first
    render layout: false
  end

=begin rdoc
 Quickly adds new rate of desired price for tariff.

 *Params*:

 +id+ - Tariff id.
 +prefix+ - String with prefix
 +price+ - String with rate price
 +st+ - Direction's first letter for correct pagination
 +page+ - number of the page user should be returned to

 *Flash*:

 +Rate_already_set+ - if rate is already set
 +Prefix_was_not_found+ - desired rate was not found so it cannot be set
 +Rate_was_added+ - if rate was created successfully
 +Rate_was_not_added+ - if rate was not created successfully

 *Redirect*

 +rates_list+
=end

  # before_filter : tariff(find_taririff_from_id)
  def rate_new_quick
    @page = params[:page].to_i > 0 ?  params[:page].to_i : 1
    params[:price] = -1 if params[:price].to_s.downcase == 'blocked'
    @prefix, @price, destination_id = params[:prefix], params[:price], params[:destination]
    params_effective_date = params[:effective_date]
    @effective_from = params_effective_date.present? ? current_user.system_time(params_effective_date[:year] + '-' + params_effective_date[:month] + '-' +
                                                                    params_effective_date[:day] + ' ' + params_effective_date[:hour] +
                                                                    ':' + params_effective_date[:minute]) : DateTime.now

    unless Destination.where(prefix: @prefix).first
      flash[:notice] = _('Destination_not_found')
      redirect_to(action: :rates_list, id: @tariff.id, st: params[:st], page: @page)
      return false
    end
    if Rate.where('rates.tariff_id = ? AND rates.prefix = ? AND rates.effective_from = ?', @tariff.id, @prefix, @effective_from).first
      flash[:notice] = _('Rate_already_set')
      redirect_to(action: :rates_list, id: @tariff.id, st: params[:st], page: @page)
      return false
    end
    @destination = Destination.find_with_direction(Application.shorter_longest_prefix_string(@prefix)).
      try(:where, "destinations.id = ?", destination_id.to_i).try(:first)
    if @destination
      if @tariff.add_new_rate(@destination, @price, params[:increment_s], params[:min_time], params[:connection_fee], params[:ghost_percent], @prefix, @effective_from)
        flash[:status] = _('Rate_was_added')
      else
        flash[:notice] = _('Rate_was_not_added')
      end
    else
      flash[:notice] = _('Prefix_was_not_found')
    end
    redirect_to(action: :rates_list, id: @tariff.id, st: params[:st], page: @page)
    return false
  end

=begin rdoc
 Shows list of free destinations for 1 direction. User can set rates for destinations.

 *Params*:

 +id+ - Tariff id
 +dir_id+ Direction id
 +st+ - Direction's first letter for correct pagination
 +page+ - list page number
=end
  # before_filter : tariff(find_taririff_from_id)
  def rate_new_by_direction
    @page = params[:page].to_i > 0 ? params[:page].to_i : 1
    @st = params[:st]
    @direction = Direction.where('id = ?', params[:dir_id]).first
    flash_tariff_not_found = flash[:notice] = _('Tariff_Was_Not_Found')
    unless @direction
      flash[:notice]=_('Direction_was_not_found')
      redirect_to(action: :list) && (return false)
    end
    if current_user.usertype == 'accountant'
      allow_manage, allow_read = accountant_permissions
      if allow_manage || current_user.accountant_allow_read('see_financial_data')
        if @tariff.owner_id != 0
          flash_tariff_not_found
          redirect_to(action: :list) && (return false)
        end
      else
        flash[:notice] = _('You_are_not_authorized_to_view_this_page')
        redirect_to(:root) && (return false)
      end
    elsif @tariff.owner_id != current_user_id
      flash_tariff_not_found
      redirect_to(action: :list) && (return false)
    end
    @destinations = @tariff.free_destinations_by_direction(@direction)
    @total_items = @destinations.size
    session_items_per_page = session[:items_per_page]
    @total_pages = (@total_items.to_d / session_items_per_page.to_d).ceil
    istart = (@page - 1) * session_items_per_page
    iend = @page * session_items_per_page - 1
    @destinations = @destinations[istart..iend]
    @page_select_options = { id: @tariff.id, dir_id: @direction.id, st: @st }
    @page_title = _('Rates_for_tariff') + ' ' + _('Direction')+ ': ' + @direction.name
    @page_icon = 'money.png'
  end

  # before_filter : tariff(find_taririff_from_id)
  def rate_new_by_direction_add
    @st = params[:st]
    @direction = Direction.where('id = ?', params[:dir_id]).first
    unless @direction
      flash[:notice] = _('Direction_was_not_found')
      redirect_to action: :list
      return false
    end
    convert_blocked_params(params)
    @destinations = @tariff.free_destinations_by_direction(@direction)
    @destinations.each { |dest|
      destination_id = dest.id
      if params["dest_#{destination_id}"] and params["dest_#{destination_id}"].to_s.length > 0
        @tariff.add_new_rate(dest, params["dest_#{destination_id}"], 1, 0,0, params[('gh_' + destination_id.to_s).intern])
      end
    }
    flash[:status] = _('Rates_updated')
    redirect_to action: 'rate_new_by_direction', id: params[:id], st: params[:st], dir_id: @direction.id
  end

  # Before_filter : tariff(find_tariff_from_id)
  def rate_new
    tariff_id = @tariff.id

    if @tariff.purpose == 'user'
      flash[:notice] = _('Tariff_type_error')
      redirect_to action: :list
      return false
    end
    @page_title = _('Add_new_rate_to_tariff')
    @page_icon = 'add.png'

    # st - from which letter starts rate's direction (usualy country)
    @st = 'A'
    @st = params[:st].upcase if params[:st]
    @page = (params[:page] || 1).to_i
    session_items_per_page = session[:items_per_page]
    offset = (@page - 1) * session_items_per_page.to_i

    @dests, total_records = @tariff.free_destinations_by_st(@st, session_items_per_page, offset)
    @total_pages = (total_records.to_f / session_items_per_page.to_f).ceil

    @letter_select_header_id, @page_select_header_id = tariff_id, tariff_id
  end

  # Before_filter : tariff(find_tariff_from_id)
  def ghost_percent_edit
    @page_title = _('Ghost_percent')
    @rate = Rate.where(id: params[:rate_id]).first
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to action: :list
      return false
    end

    @destination = @rate.destination
    unless @destination.direction
      flash[:notice]=_('Direction_was_not_found')
      redirect_to action: :list
      return false
    end
  end

  # Before_filter : tariff(find_tariff_from_id)
  def ghost_percent_update
    @rate = Rate.where(id: params[:rate_id]).first
    if @rate
      @rate.update_ghost_percent(params[:rate][:ghost_min_perc])
    end
    flash[:status] = _('Rate_updated')

    @rate.action_on_change(@current_user)
    @rate.tariff_updated

    redirect_to action: :ghost_percent_edit, id: @tariff.id, rate_id: params[:rate_id]
  end

  # Before_filter : tariff(find_tariff_from_id)
  def rate_try_to_add
    if @tariff.purpose == 'user'
      flash[:notice] = _('Tariff_type_error')
      redirect_to controller: :tariffs, action: :list
      return false
    end
    convert_blocked_params(params)

    # st - from which letter starts rate's direction (usualy country)
    st = params[:st].try(:upcase) || 'A'

    @tariff.free_destinations_by_st(st).each do |dest|
      # Add only rates which are entered
      destination_id = dest.id.to_s
      destination = params[(destination_id).intern]
      if destination.to_s.length > 0
        @tariff.add_new_rate(dest, destination, 1, 0,0, params[('gh_' + destination_id).intern])
      end
    end

    flash[:status] = _('Rates_updated')
    redirect_to action: 'rates_list', id: params[:id], st: st
  end

  def rate_destroy
    rate = Rate.where(["id = ?", params[:id]]).first
    unless rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end
    if rate
      return false unless check_user_for_tariff(rate.tariff_id)

      st = (rate.destination.direction.try(:name) || rate.destination.name).first
      rate.destroy_everything
    end

    flash[:status] = _('Rate_deleted')
    redirect_to :action => 'rates_list', :id => params[:tariff], :st => st
  end

  # =============== RATE DETAILS ==============

  def rate_details
    rated = Ratedetail.where(:rate_id => params[:id]).first

    if !rated
      rd = Ratedetail.new(
        start_time: '00:00:00',
        end_time: '23:59:59',
        rate: 0,
        connection_fee: 0,
        rate_id: params[:id].to_i,
        increment_s: 0,
        min_time: 0,
        daytype: 'WD'
      )
      rd.save
    end

    check_user_for_tariff(@rate.tariff_id)
    @allow_manage, @allow_read = accountant_permissions
    @page_title = _('Rate_details')
    @rate_details = @rate.ratedetails
    firs_ratedetail = @rate_details.first

    if firs_ratedetail && firs_ratedetail.daytype == ''
      @wdfd = true
    else
      @wdfd = false
      @WDrdetails = @rate_details.where(daytype: 'WD').to_a
      @FDrdetails = @rate_details.where(daytype: 'FD').to_a
    end

    @tariff = @rate.tariff
    @destination = @rate.destination
    # Every rate should have destination assigned, but since it is common to have
    # Broken relational itegrity, we should check whether destination is not nil
    unless @destination
      flash[:notice] = _('Rate_does_not_have_destination_assigned')
      redirect_to :root
    end
    @can_edit = true

    current_user_id = current_user.id.to_i
    if current_user.usertype == 'reseller' and @tariff.owner_id != current_user_id and CommonUseProvider.where(["reseller_id = ? AND tariff_id = ?", current_user_id, @tariff.id]).first
      @can_edit = false
    end
  end

  def ratedetails_manage
    return false unless check_user_for_tariff(@rate.tariff_id)

    rdetails = @rate.ratedetails
    rdaction = params[:rdaction]

    case rdaction
    when 'COMB_WD'
      rdetails.each { |rate_detail| rate_detail.combine_work_days }
      status = _('Rate_details_combined')
    when 'COMB_FD'
      rdetails.each { |rate_detail| rate_detail.combine_free_days }
      status = _('Rate_details_combined')
    when 'SPLIT'
      rdetails.each { |rate_detail| rate_detail.split }
      status = _('Rate_details_split')
    end

    if status.present?
      flash[:status] = status
      @rate.tariff_updated
    end

    redirect_to action: 'rate_details', id: @rate.id
  end

  def ratedetail_edit
    @page_title = _('Rate_details_edit')
    @page_icon = "edit.png"


    check_user_for_tariff(@rate.tariff_id)

    rdetails = @rate.ratedetails_by_daytype(@ratedetail.daytype)

    @tariff = @rate.tariff
    @destination = @rate.destination
    @etedit = (rdetails[(rdetails.size - 1)] == @ratedetail)

  end

  def ratedetail_update
    rd = @ratedetail

    return false unless check_user_for_tariff(@rate.tariff_id)

    rdetails = @rate.ratedetails_by_daytype(@ratedetail.daytype)

    if (params[:ratedetail] and params[:ratedetail][:end_time]) and ((nice_time2(rd.start_time) > params[:ratedetail][:end_time]) or (params[:ratedetail][:end_time] > "23:59:59"))
      flash[:notice] = _('Bad_time')
      redirect_to :action => 'rate_details', :id => @ratedetail.rate_id and return false
    end

    params[:ratedetail][:rate] = -1 if params[:ratedetail][:rate].downcase == 'blocked'

    if @ratedetail.update_attributes(params[:ratedetail])

      # we need to create new rd to cover all day
      if (nice_time2(@ratedetail.end_time) != '23:59:59') and ((rdetails[(rdetails.size - 1)] == @ratedetail))
        st = @ratedetail.end_time.blank? ? '00:00:00' : @ratedetail.end_time + 1.second

        attributes = rd.attributes.merge(start_time: st.to_s, end_time: '23:59:59')
        nrd = Ratedetail.new(attributes)
        nrd.save
      end

      @ratedetail.action_on_change(@current_user)
      @rate.tariff_updated

      flash[:status] = _('Rate_details_was_successfully_updated')
      redirect_to action: 'rate_details', id: @ratedetail.rate_id
    else
      render :ratedetail_edit
    end
  end

  def ratedetail_new
    @rate = Rate.where(:id => params[:id]).first
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :action => :list and return false
    end
    @page_title = _('Ratedetail_new')
    @page_icon = 'add.png'
    @ratedetail = Ratedetail.new(
      start_time: '00:00:00',
      end_time: '23:59:59'
    )
  end

  def ratedetail_create
    @rate = Rate.where(id: params[:id]).first
    unless @rate
      flash[:notice] = _('Rate_was_not_found')
      redirect_to action: :list
      return false
    end
    @ratedetail = Ratedetail.new(params[:ratedetail])
    @ratedetail.rate = @rate
    if @ratedetail.save
      flash[:status] = _('Rate_detail_was_successfully_created')
      redirect_to action: 'rate_details', id: @ratedetail.rate_id
    else
      render :ratedetail_new
    end
  end

  def ratedetail_destroy
    @rate = Rate.where(id: params[:rate]).first
    unless @rate
      flash[:notice] = _('Rate_was_not_found')
      redirect_to action: :list
      return false
    end

    return false unless check_user_for_tariff(@rate.tariff_id)

    rd = Ratedetail.where(id: params[:id]).first
    unless rd
      flash[:notice]=_('Ratedetail_was_not_found')
      redirect_to action: :list
      return false
    end
    rdetails = @rate.ratedetails_by_daytype(rd.daytype)


    if rdetails.size > 1

      #update previous rd
      et = nice_time2(rd.start_time - 1.second)
      daytype = rd.daytype
      prd = Ratedetail.where(["rate_id = ? AND end_time = ? AND daytype = ?", @rate.id, et, daytype]).first
      if prd
        prd.end_time = "23:59:59"
        prd.save
      end
      rd.destroy
      flash[:status] = _('Rate_detail_was_successfully_deleted')
    else
      flash[:notice] = _('Cant_delete_last_rate_detail')
    end

    redirect_to action: 'rate_details', id: params[:rate]
  end


  # ======== XLS IMPORT =================
  def import_xls
    @step = params[:step].try(:to_i) || 1
    set_page_title_and_name(@step)

    if @step == 2
      if params[:file] || session[:file]
        if params[:file]
          @file = params[:file]
          session[:file] = params[:file].read if @file.size > 0
        else
          @file = session[:file]
        end
        session[:file_size] = @file.size
        if session[:file_size].to_i == 0
          flash[:notice] = _('Please_select_file')
          redirect_to action: 'import_xls', id: @tariff.id, step: '1'
          return false
        end

        file_name = '/tmp/temp_excel.xls'
        files = File.open(file_name, 'wb')
        files.write(session[:file])
        files.close
        workbook = Excel.new(file_name)
        session[:pagecount] = 0
        last_sheet, count = count_data_sheets(workbook)

        flash[:status] = _('File_uploaded')
      end
    end
  end

  def find_prefix_column(workbook, sheet)
    workbook.default_sheet = sheet
    size = workbook.last_row
    midle = size / 2
    midle.upto(size) do |index|
      workbook.row(index)
    end
  end

  def count_data_sheets(workbook)
    count = 0
    for sheet in workbook.sheets do
      workbook.default_sheet = sheet
      if workbook.last_row.to_i > 0 and workbook.last_column.to_i > 1
        count += 1
        last = sheet
      end
    end
    return sheet, count
  end

  # ======== CSV IMPORT =================
  def import_csv
    redirect_to action: :import_csv2, id: params[:id]
    return false
  end

  def import_csv2
    if %w[user].include?(@tariff.purpose.to_s)
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    @sep, @dec = Application.nice_action_session_csv(params, session, correct_owner_id)
    store_location

    @step = params[:step].try(:to_i) || 0
    @step = 0 unless (0..9).include?(@step)

    @step_name = find_step_name(@step)

    space = "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;"
    @page_title = (_('Import_CSV') + space + _('Step') + ': ' + @step.to_s + space + @step_name).html_safe
    @page_icon = 'excel.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Rate_import_from_CSV'

    tariff_id = @tariff.id

    @effective_from_active = ((admin? || reseller? || accountant? || partner?) && ['provider', 'user_wholesale'].include?(@tariff.purpose.to_s))

    catch(:done) do
      step = @step
      import_csv2_step_0 if step == 0
      import_csv2_step_1 if step == 1
      import_csv2_step_2 if step == 2
      if step > 2
        check_if_file_in_db
        check_if_filename_in_session
        import_csv2_step_3 if step == 3
        if step > 3
          check_existence_of_calldate_and_billsec
          import_csv2_step_4 if step == 4
          import_csv2_step_5 if step == 5
          import_csv2_step_6 if step == 6
          import_csv2_step_7 if step == 7
          import_csv2_step_8 if step == 8

          @tariff.update_time if step > 4
        end
      end
    end
  end

  def bad_rows_from_csv
    @page_title = _('Bad_rows_from_CSV_file')
    @csv2= params[:csv2].to_i
    session_csv_params_tariff_id = session["tariff_name_csv_#{params[:tariff_id].to_i}".to_sym]
    if @csv2.to_i == 0
      @rows = session[:bad_lines_array]
      @status = session[:bad_lines_status_array]
    else
      if ActiveRecord::Base.connection.tables.include?(session_csv_params_tariff_id)
        @rows = ActiveRecord::Base.connection.select_all("SELECT * FROM #{session_csv_params_tariff_id} WHERE f_error = 1")
      end
    end
    render(:layout => "layouts/mor_min")
  end

  def zero_rates_from_csv
    @page_title = _('Zero_rates_csv')
    @csv2= params[:csv2].to_i
    params_tariff_id = params[:tariff_id].to_i
    session_csv_params_tariff_id = session["tariff_name_csv_#{params_tariff_id}".to_sym]
    if @csv2.to_i == 0
      @rows = []
    else
      if ActiveRecord::Base.connection.tables.include?(session_csv_params_tariff_id)
        @rows = ActiveRecord::Base.connection.
            select_all("SELECT *
                        FROM #{session_csv_params_tariff_id}
                        WHERE col_#{session["tariff_import_csv2_#{params_tariff_id}".to_sym][:imp_rate]} #{SqlExport.is_zero_condition}")
      else
        @rows = []
      end
    end
    render(template: 'cdr/bad_rows_from_csv', :layout => "layouts/mor_min", locals: {rows: @rows})
  end

  def dst_to_create_from_csv
    @page_title = _('Dst_to_create_from_csv')
    @file = session[:file]
    @status = session[:status_array]
    @csv2=0
    flash_zero_file = flash[:notice] = _('Zero_file_size')
    tariff_name_csv_params = "tariff_name_csv_#{params[:tariff_id].to_i}".to_sym
    if !@file.blank?
      if params[:csv2].to_i == 0
        flash_zero_file
        redirect_to :controller => "tariffs", :action => "list"
      else
        @csv2=1
        if ActiveRecord::Base.connection.tables.include?(session[tariff_name_csv_params])
          @csv_file = ActiveRecord::Base.connection.select_all("SELECT * FROM #{session[tariff_name_csv_params]} WHERE not_found_in_db = 1 AND f_error = 0")
        end
        render(:layout => "layouts/mor_min")
      end
    else
      flash_zero_file
      redirect_to :controller => "tariffs", :action => "list"
    end
  end

  def dst_to_update_from_csv
    @page_title = _('Dst_to_update_from_csv')
    @file = session[:file]
    @status = session[:status_array]
    @csv2= params[:csv2].to_i
    if @csv2.to_i == 0
      @dst = session[:dst_to_update_hash]
    else
      @tariff_id = params[:tariff_id].to_i
      if ActiveRecord::Base.connection.tables.include?(session["tariff_name_csv_#{params[:tariff_id].to_i}".to_sym])
        @dst = ActiveRecord::Base.connection.select_all("SELECT destinations.prefix, col_#{session["tariff_import_csv2_#{@tariff_id}".to_sym][:imp_dst]} as new_name, IFNULL(original_destination_name,destinations.name) as dest_name FROM destinations JOIN #{session["tariff_name_csv_#{params[:tariff_id].to_i}".to_sym]} ON (replace(col_#{session["tariff_import_csv2_#{@tariff_id}".to_sym][:imp_prefix]}, '\\r', '') = prefix) WHERE ned_update IN (1, 3, 5, 7) AND (BINARY replace(replace(TRIM(col_2), '\r', ''), '  ', ' ') != IFNULL(original_destination_name,destinations.name) OR destinations.name IS NULL)")
      end
    end
    render(:layout => "layouts/mor_min")
  end

  def dir_to_update_from_csv
    @page_title = _('Direction_to_update_from_csv')
    @file = session[:file]
    @status = session[:status_array]
    @csv2= params[:csv2].to_i
    if @csv2.to_i == 0
      @dst = session[:dst_to_update_hash]
    else
      @tariff_id = params[:tariff_id].to_i
      tariff_name_csv_params = "tariff_name_csv_#{params[:tariff_id].to_i}".to_sym
      if ActiveRecord::Base.connection.tables.include?(session[tariff_name_csv_params])
        imp_cc = session["tariff_import_csv2_#{@tariff_id}".to_sym][:imp_cc]
        table_name = session[tariff_name_csv_params]
        imp_prefix = session["tariff_import_csv2_#{@tariff_id}".to_sym][:imp_prefix]
        @directions = ActiveRecord::Base.connection.select_all("SELECT prefix, destinations.direction_code old_direction_code, replace(col_#{imp_cc}, '\\r', '') new_direction_code from #{table_name} join directions on (replace(col_#{imp_cc}, '\\r', '') = directions.code) join destinations on (replace(col_#{imp_prefix}, '\\r', '') = destinations.prefix) WHERE destinations.direction_code != directions.code;")
      end
    end
    render(:layout => "layouts/mor_min")
  end

  def rate_import_status
    #render(:layout => false)
  end

  def rate_import_status_view
    render(:layout => false)
  end

  # before_filter : tariff(find_taririff_from_id)
  def delete_all_rates
    @tariff.delete_all_rates
    @tariff.updated
    flash[:status] = _('All_rates_deleted')
    redirect_to :action => 'list'
  end

=begin
  returns first letter of destination group name if it has any rates set, if nothing is set return 'A'
=end
  def tariff_dstgroups_with_rates(tariff_id)
    res = Destinationgroup.select(:name).joins(:rates).where("rates.tariff_id = #{tariff_id}").group("destinationgroups.id").order("destinationgroups.name ASC").to_a
    res.map! { |rate| rate['name'][0..0] }
    res.uniq
  end

  def dstgroup_name_first_letters
    res = Destination.select("destinationgroups.name").joins(:destinationgroup).group(:destinationgroup_id).order("destinationgroups.name ASC").to_a
    res.map! {|dstgroup| dstgroup['name'][0..0].upcase}
    res.uniq
  end

  # =============== RATES FOR USER ==================
  # before_filter : tariff(find_taririff_from_id)
  def user_rates_list
    tariff_id = @tariff.id

    if flash[:notice].blank? and @tariff.purpose != 'user'
      flash[:notice] = _('Tariff_type_error')
      redirect_to :controller => :tariffs, :action => :list and return false
    end

    @page_title = _('Rates_for_tariff')
    @page_icon = 'coins.png'
    @res =[]
    session[:tariff_user_rates_list] ? @options = session[:tariff_user_rates_list] : @options = {:page => 1}
    @options[:page] = params[:page].to_i if !params[:page].blank?
    @items_per_page = Confline.get_value("Items_Per_Page").to_i
    @letter_select_header_id = tariff_id

    # dst groups are rendered in 'pages' according to they name's first letter
    # if no letter is specified in params, by default we show page full of
    # dst groups
    @directions_first_letters = tariff_dstgroups_with_rates(tariff_id)
    @st = (params[:st] ? params[:st].upcase : (@directions_first_letters[0] || 'A'))

    # needed to know whether to make link to sertain letter or not
    # when rendering letter_select_header
    @directions_defined = dstgroup_name_first_letters()

    @page = 1
    @page = params[:page].to_i if params[:page]
    @page = 1 if @page < 1

    params_s_prefix = params[:s_prefix]
    if params_s_prefix and !params_s_prefix.blank?
      @s_prefix = params_s_prefix.present? ? params_s_prefix : '%'
      cond = "destinations.prefix LIKE '#{@s_prefix.to_s}'"
      @search = 1
    else
      cond = "destinationgroups.name LIKE '#{@st}%'"
    end

    # Cia refactorintas , veikia x7 greiciau...
    sql = "SELECT * FROM (
                          SELECT destinationgroups.flag, destinationgroups.name, destinationgroup_id AS dg_id, COUNT(DISTINCT destinations.id) AS destinations  FROM destinations
                                JOIN destinationgroups ON (destinationgroups.id = destinations.destinationgroup_id)
                                WHERE #{cond}
                                GROUP BY destinations.destinationgroup_id
                                ORDER BY destinationgroups.name ASC
                         ) AS dest
              LEFT JOIN (SELECT rates.ghost_min_perc, rates.destinationgroup_id AS dg_id2, rates.id AS rate_id, COUNT(DISTINCT aratedetails.id) AS arates_size,  IF(art2.id IS NULL, aratedetails.price, NULL) AS price, IF(art2.id IS NULL, aratedetails.round, NULL) AS round, IF(art2.id IS NOT NULL,  NULL, 'minute') as artype FROM destinations
                                JOIN destinationgroups ON (destinationgroups.id = destinations.destinationgroup_id)
                                LEFT JOIN rates ON (rates.destinationgroup_id = destinationgroups.id )
                                LEFT JOIN aratedetails ON (aratedetails.rate_id = rates.id)
                                LEFT JOIN aratedetails AS art2 ON (art2.rate_id = rates.id and art2.artype != 'minute')
                                WHERE #{cond}  AND rates.tariff_id = #{tariff_id}
                                GROUP BY rates.destinationgroup_id
                        ) AS rat ON (dest.dg_id = rat.dg_id2)"

    @res = ActiveRecord::Base.connection.select_all(sql)
    @options[:total_pages] = (@res.size.to_d / @items_per_page.to_d).ceil
    @options[:page] = 1 if @options[:page] > @options[:total_pages]
    istart = (@options[:page]-1)*@items_per_page
    iend = (@options[:page])*@items_per_page-1
    @res = @res[istart..iend]
    session[:tariff_user_rates_list] = @options

    rids= []
    @res.each { |res| rids << res['rate_id'].to_i if !res['rate_id'].blank? }
    @rates_list = Rate.where("rates.id IN (#{rids.join(',')})").includes([:aratedetails, :tariff, :destinationgroup]).all if rids.size.to_i > 0

    current_user_id = current_user.id.to_i
    @can_edit = true
    if current_user.usertype == 'reseller' and @tariff.owner_id != current_user_id and CommonUseProvider.where(["reseller_id = ? AND tariff_id = ?", current_user_id, tariff_id]).first
      @can_edit = false
    end

  end

  def user_arates
    @rate = Rate.where(["id = ?", params[:id]]).first
    if !@rate
      Action.add_action(session[:user_id], "error", "Rate: #{params[:id].to_s} was not found") if session[:user_id].to_i != 0
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
    @tariff = @rate.tariff
    @page_title = _('Rates_for_tariff') + ': ' + @tariff.name
    @dgroup = @rate.destinationgroup

    @st = params[:st]
    @dt = params[:dt]
    @dt = '' if not params[:dt]

    @ards = Aratedetail.where(["rate_id = ? AND start_time = ? AND daytype = ?", @rate.id, @st, @dt]).order("aratedetails.from ASC, artype ASC")

    @ards and @ards.size > 0 ? @et = nice_time2(@ards[0].end_time) : @et = "23:59:59"

    @can_add = false
    #last ard
    lard = @ards.last
    if lard
      lard_duration = lard.duration
      lard_artype = lard.artype
      lard_from = lard.from
      lard_artype_min = lard_artype == 'minute'
      lard_artype_event = lard_artype == 'event'

      if (lard_duration != -1 and lard_artype_min) or (lard_artype_event)
        @can_add = true
        @from = (lard_from && lard_duration) ? lard_from + lard_duration : 1
        @from = lard_from if lard_artype_event
      end
    end

    current_user_id = current_user.id.to_i
    @can_edit = true
    if current_user.usertype == 'reseller' and @tariff.owner_id != current_user_id and CommonUseProvider.where(["reseller_id = ? AND tariff_id = ?", current_user_id, @tariff.id]).first
      @can_edit = false
    end

  end

  # before_filter : tariff(find_taririff_from_id)
  def user_arates_full
    @page_title = _('Rates_for_tariff') + ': ' + @tariff.name
    @dgroup = Destinationgroup.where(:id => params[:dg]).first

    unless @dgroup
      flash[:notice]=_('Destinationgroup_was_not_found')
      redirect_to action: :list and return false
    end

    @rate = @dgroup.rate(@tariff.id)

    if not @rate
      rate = Rate.new(tariff: @tariff, destinationgroup: @dgroup)
      rate.save

      ard = Aratedetail.new(
          from: 1,
          duration: -1,
          artype: 'minute',
          round: 1,
          price: 0,
          rate: rate,
      )
      ard.save

      @rate = rate
      #my_debug "creating rate and ard"
    end

    @ards = @rate.aratedetails

    if @ards.first.blank?

      ard = Aratedetail.new(
          from: 1,
          duration: -1,
          artype: 'minute',
          round: 1,
          price: 0,
          rate: @rate
      )
      ard.save

      @ards = @rate.aratedetails
    end


    if @ards.first.daytype.to_s == ''
      @wdfd = true

      sql = "SELECT TIME(start_time) start_time, TIME(end_time) end_time FROM aratedetails WHERE daytype = '' AND rate_id = #{@rate.id}  GROUP BY start_time ORDER BY start_time ASC"
      res = ActiveRecord::Base.connection.select_all(sql)
      @st_arr = []
      @et_arr = []
      for record in res
        @st_arr << record["start_time"].strftime("%H:%M:%S")
        @et_arr << record["end_time"].strftime("%H:%M:%S")
      end

    else
      @wdfd = false

      sql = "SELECT TIME(start_time) start_time, TIME(end_time) end_time FROM aratedetails WHERE daytype = 'WD' AND rate_id = #{@rate.id}  GROUP BY start_time ORDER BY start_time ASC"
      res = ActiveRecord::Base.connection.select_all(sql)
      @wst_arr = []
      @wet_arr = []
      for record in res
        @wst_arr << record["start_time"].strftime("%H:%M:%S")
        @wet_arr << record["end_time"].strftime("%H:%M:%S")
      end

      sql = "SELECT TIME(start_time) start_time, TIME(end_time) end_time FROM aratedetails WHERE daytype = 'FD' AND rate_id = #{@rate.id} GROUP BY start_time ORDER BY start_time ASC"
      res = ActiveRecord::Base.connection.select_all(sql)
      @fst_arr = []
      @fet_arr = []
      for record in res
        @fst_arr << record["start_time"].strftime("%H:%M:%S")
        @fet_arr << record["end_time"].strftime("%H:%M:%S")
      end

    end

    current_user_id = current_user.id.to_i
    @can_edit = true

    if current_user.usertype == 'reseller' and @tariff.owner_id != current_user_id and
      CommonUseProvider.where(["reseller_id = ? AND tariff_id = ?", current_user_id, @tariff.id]).first
      @can_edit = false
    end
  end

  def user_ard_time_edit
    @rate = Rate.where(id: params[:id]).first

    unless @rate
      flash[:notice] = _('Rate_was_not_found')
      redirect_to action: :list and return false
    end

    checking_for_tariff = check_user_for_tariff(@rate.tariff_id)
    return false if !checking_for_tariff

    dt = params[:daytype]

    et = params[:date][:hour] + ':' + params[:date][:minute] + ':' + params[:date][:second]
    st = params[:st]

    if Time.parse(st) > Time.parse(et)
      flash[:notice] = _('Bad_time')
      redirect_to action: 'user_arates_full', id: @rate.tariff_id, dg: @rate.destinationgroup_id and return false
    end

    rdetails = @rate.aratedetails_by_daytype(params[:daytype])

    ard = Aratedetail.where("rate_id = #{@rate.id} AND start_time = '#{st}'  AND daytype = '#{dt}'").first

    #my_debug ard.start_time
    #my_debug rdetails[(rdetails.size - 1)].start_time

    # we need to create new rd to cover all day
    if (et != "23:59:59") and ((rdetails[(rdetails.size - 1)].start_time == ard.start_time))
      nst = Time.mktime('2000', '01', '01', params[:date][:hour], params[:date][:minute], params[:date][:second]) + 1.second
      #my_debug nst
      ards = Aratedetail.where("rate_id = #{@rate.id} AND start_time = '#{st}'   AND daytype = '#{dt}'")

      ards.each do |arate_detail|
        attributes = arate_detail.attributes.merge(start_time: nst.to_s, end_time: '23:59:59')

        new_arate_detail = Aratedetail.new(attributes)
        new_arate_detail.save

        arate_detail.end_time = et
        arate_detail.save
        arate_detail.action_on_change(@current_user)
      end

    end

    @rate.tariff_updated
    flash[:status] = _('Rate_details_updated')
    redirect_to action: 'user_arates_full', id: @rate.tariff_id, dg: @rate.destinationgroup_id
  end


  def artg_destroy
    @rate = Rate.where(:id => params[:id]).first
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to action: :list and return false
    end
    dt = params[:dt]
    dt = '' if not params[:dt]
    st = params[:st]

    ards = Aratedetail.where("rate_id = #{@rate.id} AND start_time = '#{st}'   AND daytype = '#{dt}'")
    #my_debug ards.size
    pet = nice_time2(ards[0].start_time - 1.second)

    for item in ards
      item.destroy
    end

    pards = Aratedetail.where("rate_id = #{@rate.id} AND end_time = '#{pet}'   AND daytype = '#{dt}'")
    for pa in pards
      pa.end_time = "23:59:59"
      pa.save
    end


    flash[:status] = _('Rate_details_updated')
    redirect_to action: 'user_arates_full', id: @rate.tariff_id, dg: @rate.destinationgroup_id

  end


  def ard_manage
    return false unless check_user_for_tariff(@rate.tariff_id)

    rdetails = @rate.aratedetails
    rdaction = params[:rdaction]


    case rdaction
    when 'COMB_WD'
      rdetails.where('daytype != ?', 'WD').destroy_all
      rdetails.where('daytype = ?', 'WD').update_all(daytype: '')
      rate_details_updated('Rate_details_combined')
    when 'COMB_FD'
      rdetails.where('daytype != ?', 'FD').destroy_all
      rdetails.where('daytype = ?', 'FD').update_all(daytype: '')
      rate_details_updated('Rate_details_combined')
    when 'SPLIT'
      rdetails.update_all(daytype: 'WD')
      rdetails.each do |rate_detail|
        attributes = rate_detail.attributes.merge(daytype: 'FD')
        Aratedetail.create(attributes)
      end
      rate_details_updated('Rate_details_split')
    end

    redirect_to action: 'user_arates_full', id: @rate.tariff_id, dg: @rate.destinationgroup_id
  end

  #update one rate
  def user_rate_update
    @ard = Aratedetail.where(:id => params[:id]).first
    unless @ard
      flash[:notice] = _('Aratedetail_was_not_found')
      redirect_to action: :list and return false
    end

    user_tariff_found = check_user_for_tariff(@ard.rate.tariff_id)
    return false if !user_tariff_found
    if params[:infinity] == '1'
      p_duration = -1
    else
      p_duration = params[:duration].to_i
    end
    from_duration = params[:from].to_i + p_duration
    from_duration_db = @ard.from.to_i + @ard.duration.to_i
    rate_id = @ard.rate_id
    st = nice_time2 @ard.start_time
    dt = @ard.daytype
    rate_is_zero = params[:rate].to_i == 0

    if (p_duration != -1 and from_duration < params[:round].to_i and rate_is_zero) or (params[:rate].to_i == 1 and @ard.duration.to_i != -1 and from_duration_db < params["round_#{@ard.id}".to_sym].to_i)
      flash[:notice] = _('Round_by_is_too_big')
    else
      if rate_is_zero
        artype = params[:artype]

        duration = params[:duration].to_i
        infinity = params[:infinity]
        duration = -1 if infinity == '1' and artype == 'minute'
        duration = 0 if artype == 'event'

        round = params[:round].to_i
        price = params[:price].to_d
        round = 1 if round < 1

        @ard.assign_attributes(
          from: params[:from],
          artype: artype,
          duration: duration,
          round: round,
          price: price
        )
      else
        @ard.assign_attributes(
          price: params["price_#{@ard.id}".to_sym].to_d,
          round: params["round_#{@ard.id}".to_sym].to_i
        )
      end
      @ard.save
      @ard.action_on_change(@current_user)
      flash[:status] = _('Rate_updated')
    end
    redirect_to action: 'user_arates', id: rate_id, st: st, dt: dt
  end


  def user_rate_add
    @rate = Rate.where(:id => params[:id]).first
    unless @rate
      flash[:notice] = _('Rate_was_not_found')
      redirect_to action: :list and return false
    end
    @ard = Aratedetail.new

    user_tariff_found = check_user_for_tariff(@rate.tariff_id)
    return false if !user_tariff_found
    from_duration = params[:from].to_i + params[:duration].to_i
    artype = params[:artype]

    duration = params[:duration].to_i
    infinity = params[:infinity]
    duration = -1 if infinity == '1' and artype == 'minute'
    duration = 0 if artype == "event"

    round = params[:round].to_i
    price = params[:price].to_d
    round = 1 if round < 1

    rate_id = @rate.id
    st = params[:st]
    et = params[:et]
    dt = params[:dt]
    dt = "" if not params[:dt]
    if params[:duration].to_i!= -1 and from_duration < params[:round].to_i
      flash[:notice] = _('Round_by_is_too_big')
    else
      attributes = {
          from: params[:from],
          artype: artype,
          duration: duration,
          round: round,
          price: price,
          rate: @rate,
          daytype: dt,
          start_time: st,
          end_time: et
      }
      @ard.update_attributes(attributes)
      flash[:status] = _('Rate_updated')
    end
    redirect_to action: 'user_arates', id: rate_id, st: st, dt: dt

  end

  def user_rate_delete
    @ard = Aratedetail.where(:id => params[:id]).first
    unless @ard
      flash[:notice] = _('Aratedetail_was_not_found')
      redirect_to action: :list and return false
    end

    check_user_tariff_rate = check_user_for_tariff(@ard.rate.tariff)
    return false if !check_user_tariff_rate

    rate_id = @ard.rate_id
    st = nice_time2 @ard.start_time
    dt = @ard.daytype

    @ard.destroy

    flash[:status] = _('Rate_deleted')
    redirect_to action: 'user_arates', id: rate_id, st: st, dt: dt

  end

  #update all rates at once
  # before_filter : tariff(find_taririff_from_id)
  def user_rates_update
    user_tariff_found = check_user_for_tariff(@tariff.id)
    return false if !user_tariff_found
    @dgroups = Destinationgroup.where("destinationgroups.name LIKE '#{params[:st]}%'").order("name ASC").all

    for dg in @dgroups

      price = ''
      price = params[('rate' + dg.id.to_s).intern] if params[('rate' + dg.id.to_s).intern]
      round = params[('round' + dg.id.to_s).intern].to_i
      round = 1 if round < 0
      #      if price.to_d != 0 or round != 1
      # Rate.where("tariff_id = #{tariff_id} AND destinationgroup_id = #{self.id}").first
      rrate = dg.rates.where(tariff_id: @tariff.id).first
      unless price.blank?
        #let's create ard
        unless rrate
          rate = Rate.new(
              tariff: @tariff,
              destinationgroup: dg,
              ghost_min_perc: params["gch#{dg.id}".intern].to_d
          )
          rate.tariff_updated
          rate.save


          ard = Aratedetail.new(
              from: 1,
              duration: -1,
              artype: 'minute',
              round: round,
              price: price.to_d,
              rate: rate
          )
          ard.save

          # my_debug "create rate"

        else
          # update existing ard
          aratedetails = rrate.aratedetails
          # my_debug aratedetails.size
          if aratedetails.size == 1
            ard = aratedetails[0]
            # my_debug price
            # my_debug "--"
            if price == ''
              rrate.destroy_everything
              # ard.destroy
            else
              from_duration_db = ard.from.to_i + ard.duration.to_i
              rrate.ghost_min_perc = params[('gch' + dg.id.to_s).intern].to_d
              rrate.tariff_updated
              rrate.save
              rrate.action_on_change(@current_user)
              if ard.duration.to_i != -1 and from_duration_db < round.to_i
                flash[:notice] = _('Rate_not_updated_round_by_is_too_big') + ': '+ "#{dg.name}"
                redirect_to action: 'user_rates_list', id: @tariff.id, page: params[:page], st: params[:st], s_prefix: params[:s_prefix] and return false
              else
                ard.price = price.to_d
                ard.round = round
                ard.save
                ard.action_on_change(@current_user)
              end
            end
          end

        end
      else
        if rrate
          rrate.ghost_min_perc = params[('gch' + dg.id.to_s).intern].to_d
          rrate.save
          rrate.action_on_change(@current_user)
        end
      end
    end

    flash[:status] = _('Rates_updated')
    redirect_to(action: 'user_rates_list', id: @tariff.id, page: params[:page], st: params[:st], s_prefix: params[:s_prefix]) && (return false)
  end


  def user_rate_destroy
    rate = Rate.where(:id => params[:id]).first
    unless rate
      flash[:notice] = _('Rate_was_not_found')
      redirect_to action: :list and return false
    end
    tariff_id = rate.tariff_id

    user_tariff_found = check_user_for_tariff(tariff_id)
    return false if !user_tariff_found

    rate.destroy_everything

    flash[:status] = _('Rate_deleted')
    redirect_to(action: 'user_rates_list', id: tariff_id, page: params[:page], st: params[:st], s_prefix: params[:s_prefix])

  end

  # for final user
  # before_filter : user; tariff
  def user_rates
    @page_title, @page_icon = [_('Personal_rates'), 'coins.png']

    if !(user? || reseller? || partner?) || (session[:show_rates_for_users].to_i != 1) || Tariff.where(id: current_user.tariff_id).first.purpose == 'user_by_provider'
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    @show_currency_selector = true
    show_currency = session[:show_currency].gsub(/[^A-Za-z]/, '')
    items_per_page = session[:items_per_page].abs

    params_s_prefix = params[:s_prefix]
    session[:user_rates_prefix] = params_s_prefix if params_s_prefix
    @s_prefix = session[:user_rates_prefix] ||= ''
    prefix_cond = @s_prefix.present? ? ['destinations.prefix LIKE ?', @s_prefix.to_s] : ''
    @page = params[:page] ? params[:page].to_i : 1
    @page = 1 if @page < 1
    tariff_purpose_user = @tariff.purpose == 'user'

    if tariff_purpose_user
      @letters_to_bold = Destinationgroup.select('LEFT(destinationgroups.name, 1) AS first_letter')
                                         .joins('JOIN destinations ON (destinations.destinationgroup_id = destinationgroups.id)')
                                         .where(prefix_cond)
                                         .group('first_letter').collect(&:first_letter)
    else
      @letters_to_bold = @tariff.rates.select('LEFT(directions.name, 1) AS first_letter')
                                .joins('JOIN destinations ON (rates.destination_id = destinations.id)')
                                .joins('JOIN directions ON (destinations.direction_code = directions.code)')
                                .where(prefix_cond)
                                .group('first_letter').collect(&:first_letter)
    end

    @st = (params[:st] ? params[:st].upcase : (@letters_to_bold[0] || 'A'))

    @dgroupse = Destinationgroup.joins('JOIN destinations ON (destinations.destinationgroup_id = destinationgroups.id)')
                                .where(['destinationgroups.name like ?', "#{@st}%"])
                                .where(prefix_cond)
                                .group('destinationgroups.id')
                                .order('destinationgroups.name ASC')

    @dgroups = []
    ibeginn, iend = generate_page_details(@dgroupse.length)

    @show_rates_without_tax = Confline.get_value('Show_Rates_Without_Tax', @user.owner_id)

    for item in ibeginn..iend
      @dgroups << @dgroupse[item]
    end

    if tariff_purpose_user
      @total_pages = (@dgroupse.length.to_d / items_per_page).ceil
    else
      @rates = @tariff.rates_by_st(@st, 10000, prefix_cond)
      @total_pages = (@rates.length.to_d / items_per_page).ceil

      @record_offset = (@page - 1) * items_per_page.to_i

      tax = @show_rates_without_tax ? 1 : current_user.get_tax_value

      exrate = Currency.count_exchange_rate(@tariff.currency, show_currency)
      @ratesd = Ratedetail.find_active_rates({s_prefix: @s_prefix, st: @st, items_per_page: items_per_page, offset: @record_offset, exrate: exrate, destinations: true, directions: true, tax: tax, tariff_id: @tariff.id})
    end

    tariff_id = @tariff.id
    @letter_select_header_id = tariff_id
    @page_select_header_id = tariff_id

    @exchange_rate = count_exchange_rate(@tariff.currency, show_currency)
    @cust_exchange_rate = count_exchange_rate(session[:default_currency], show_currency)
  end

  # for final user
  # before_filter : user; tariff
  def common_use_prov_rates
    common_use_provider_tariff(params[:id])

    if @common_use_provider.blank?
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
    @page_title = @tariff.name
    @page_icon = 'coins.png'

    @show_currency_selector = true
    show_currency = session[:show_currency].gsub(/[^A-Za-z]/, '')
    items_per_page =  session[:items_per_page]

    @page = (params[:page].present?) ? params[:page].to_i : 1
    params_st = params[:st]
    @st = (params_st && ('A'..'Z').include?(params_st.upcase)) ?  params_st.upcase  : 'A'
    @dgroupse = Destinationgroup.where(['name like ?', "#{@st}%"]).order('name ASC')

    @dgroups = []
    dgroupse_size = @dgroupse.size
    ibeginn, iend = generate_page_details(dgroupse_size)
    for item in ibeginn..iend
      @dgroups << @dgroupse[item]
    end

    if @tariff.purpose == 'user'
      @total_pages = (dgroupse_size.to_d / items_per_page).ceil
    else
      @rates = @tariff.rates_by_st(@st, 10000, '')
      @total_pages = (@rates.length.to_d / items_per_page).ceil

      @all_rates = @rates
      @rates = []
      ibeginn, iend = generate_page_details(@all_rates.size)
      for item in ibeginn..iend
        @rates << @all_rates[item]
      end

      exrate = Currency.count_exchange_rate(@tariff.currency, show_currency)
      @ratesd = Ratedetail.find_all_from_id_with_exrate({rates: @rates, exrate: exrate, destinations: true, directions: true})
    end

    @letter_select_header_id = @common_use_provider
    @page_select_header_id = @common_use_provider

    @exchange_rate = count_exchange_rate(@tariff.currency, show_currency)
    @cust_exchange_rate = count_exchange_rate(session[:default_currency], show_currency)
    @show_rates_without_tax = Confline.get_value('Show_Rates_Without_Tax', @user.owner_id)
    render 'user_rates'
  end

  # before_filter : user; tariff
  def user_rates_detailed
    @page_title = _('Personal_rates')
    @page_icon = 'view.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Advanced_Rates'

    if (Confline.get_value("Show_Advanced_Rates_For_Users", current_user.owner_id).to_i != 1 || session[:show_rates_for_users].to_i != 1) && @common_use_provider.blank?
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    @page_title = _("Detailed_rates")
    @dgroup = Destinationgroup.where(:id => params[:id]).first

    unless @dgroup
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    @rate = @dgroup.rate(@tariff.id)
    @custom_rate = Customrate.where(["user_id = ? AND destinationgroup_id = ?", session[:user_id], @dgroup.id]).first

    if !@rate and !@custom_rate
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    if @custom_rate
      @ards = @custom_rate.acustratedetails
      r_details = 'acustratedetails'
      r_ident	= 'customrate_id'
      r_id	= @custom_rate.id or 0
    else
      @ards = @rate.aratedetails
      r_details = 'aratedetails'
      r_ident	= 'rate_id'
      r_id	= @rate.id or 0
    end

    if @ards.first.daytype.to_s == ''
      @wdfd = true

      sql = "SELECT * FROM #{r_details} WHERE daytype = '' AND #{r_ident} = '#{r_id}' GROUP BY start_time ORDER BY start_time ASC"
      @day_arr = ActiveRecord::Base.connection.select_all(sql)
    else
      @wdfd = false

      sql = "SELECT * FROM #{r_details} WHERE daytype = 'WD' AND #{r_ident} = '#{r_id}' GROUP BY start_time ORDER BY start_time ASC"
      @wd_arr = ActiveRecord::Base.connection.select_all(sql)

      sql = "SELECT * FROM #{r_details} WHERE daytype = 'FD' AND #{r_ident} = '#{r_id}' GROUP BY start_time ORDER BY start_time ASC"
      @fd_arr = ActiveRecord::Base.connection.select_all(sql)
    end

    @exchange_rate = count_exchange_rate(@tariff.currency, session[:show_currency])
    @show_rates_without_tax = Confline.get_value("Show_Rates_Without_Tax", @user.owner_id)
  end

  def user_advrates
    @page_title = _('Rates_details')
    @page_icon = 'coins.png'

    @dgroup = Destinationgroup.where(:id => params[:id]).first
    unless @dgroup
      flash[:notice]=_('Destinationgroup_was_not_found')
      redirect_to action: :list and return false
    end
    @rate = @dgroup.rate(session[:tariff_id])
    dgrate_id = @rate.id
    @custrate = @dgroup.custom_rate(session[:user_id])
    dgcustrate_id = @custrate.id

    @cards = Acustratedetail.where("customrate_id = #{dgcustrate_id}").order("daytype DESC, start_time ASC, acustratedetails.from ASC, artype ASC") if @custrate
    @ards = Aratedetail.where("rate_id = #{dgrate_id}").order("daytype DESC, start_time ASC, aratedetails.from ASC, artype ASC")

    if @cards and @cards.size > 0
      table = 'acustratedetails'
      trate_id = 'customrate_id'
      rate_id = dgcustrate_id
    else
      table = 'aratedetails'
      trate_id = 'rate_id'
      rate_id = dgrate_id
    end

    if @ards[0].daytype == ''
      @wdfd = true


      sql = "SELECT start_time, end_time FROM #{table} WHERE daytype = '' AND #{trate_id} = #{rate_id}  GROUP BY start_time ORDER BY start_time ASC"
      res = ActiveRecord::Base.connection.select_all(sql)
      @st_arr = []
      @et_arr = []
      for daytype in res
        @st_arr << daytype["start_time"]
        @et_arr << daytype["end_time"]
      end

    else
      @wdfd = false

      sql = "SELECT start_time, end_time FROM #{table} WHERE daytype = 'WD' AND #{trate_id} = #{rate_id}  GROUP BY start_time ORDER BY start_time ASC"
      res = ActiveRecord::Base.connection.select_all(sql)
      @wst_arr = []
      @wet_arr = []
      for daytype in res
        @wst_arr << daytype["start_time"]
        @wet_arr << daytype["end_time"]
      end

      sql = "SELECT start_time, end_time FROM #{table} WHERE daytype = 'FD' AND #{trate_id} = #{rate_id}  GROUP BY start_time ORDER BY start_time ASC"
      res = ActiveRecord::Base.connection.select_all(sql)
      @fst_arr = []
      @fet_arr = []
      for daytype in res
        @fst_arr << daytype["start_time"]
        @fet_arr << daytype["end_time"]
      end

    end

    @tax = session[:tax]
  end

  #======= Day setup ==========

  def day_setup
    @page_title = _('Day_setup')
    @page_icon = 'date.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Day_setup'
    @days = Day.order("date ASC")
  end

  def day_add
    date = params[:date][:year] + '-' + good_date(params[:date][:month]) + '-' + good_date(params[:date][:day])
    # my_debug  date

    # real_date = Time.mktime(params[:date][:year], good_date(params[:date][:month]), good_date(params[:date][:day]))

    if Application.validate_date(params[:date][:year], good_date(params[:date][:month]), good_date(params[:date][:day])) == 0
      flash[:notice] = _('Bad_date')
      redirect_to action: 'day_setup' and return false
    end

    # my_debug "---"

    if Day.where(["date = ? ", date]).first
      flash[:notice] = _('Duplicate_date')
      redirect_to action: 'day_setup' and return false
    end

    attributes = params.slice(:daytype, :description).merge date: date
    day = Day.new(attributes)
    day.save

    flash[:status] = _('Day_added') + ': ' + date
    redirect_to action: 'day_setup'
  end

  def day_destroy

    day = Day.where(:id => params[:id]).first
    unless day
      flash[:notice] = _('Day_was_not_found')
      redirect_to action: :list and return false
    end
    flash[:status] = _('Day_deleted') + ': ' + day.date.to_s
    day.destroy
    redirect_to action: 'day_setup'
  end


  def day_edit
    @page_title = _('Day_edit')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Day_setup'

    @day = Day.where(id: params[:id]).first
    unless @day
      flash[:notice] = _('Day_was_not_found')
      redirect_to action: :list and return false
    end
  end

  def day_update
    day = Day.where(id: params[:id]).first
    unless day
      flash[:notice] = _('Day_was_not_found')
      redirect_to action: :list and return false
    end

    params_date = params[:date]
    date = params_date[:year] + '-' + good_date(params_date[:month]) + '-' + good_date(params_date[:day])

    if Day.where(["date = ? and id != ?", date, day.id]).first
      flash[:notice] = _('Duplicate_date')
      redirect_to action: 'day_setup' and return false
    end

    attributes = params.slice(:daytype, :description).merge date: date
    day.assign_attributes(attributes)
    day.save

    flash[:status] = _('Day_updated') + ': ' + date
    redirect_to action: 'day_setup'
  end

  # ======== Make user tariff out of provider tariff ==========
  # before_filter : tariff(find_taririff_from_id)
  def make_user_tariff
    @tariff.purpose == 'user_wholesale' ? @tariff_purpose = _('Wholesale_tariff') : @tariff_purpose = _('Provider_tariff')
    @page_title = _('Make_User_Tariff')
    @page_icon = 'application_add.png'
    @ptariff = @tariff
    @total_rates = Rate.where("tariff_id = '#{@ptariff.id}' AND destination_id != 0").count
    check_user_for_tariff(@ptariff.id)
    @rates_number = Rate.where("tariff_id = '#{@ptariff.id}' AND destination_id != 0").count
  end

  # before_filter : tariff(find_taririff_from_id)
  def make_user_tariff_wholesale
    @tariff.purpose == 'user_wholesale' ? @tariff_purpose = _('Wholesale_tariff') : @tariff_purpose = _('Provider_tariff')
    @page_title = _('Make_user_tariff')
    @page_icon = 'application_add.png'
    @ptariff = @tariff
    @tariff_rates = @ptariff.rates.size
    check_user_for_tariff(@ptariff.id)
    @rates_number = Rate.where("tariff_id = '#{@ptariff.id}' AND destination_id != 0").count
  end

  # before_filter : tariff(find_taririff_from_id)
  def make_user_tariff_status
    @tariff.purpose == 'user_wholesale' ? @tariff_purpose = _('Wholesale_tariff') : @tariff_purpose = _('Provider_tariff')
    @page_title = _('Make_user_tariff')
    @page_icon = 'application_add.png'
    @ptariff = @tariff
    user_tariff_found = check_user_for_tariff(@ptariff.id)
    return false if !user_tariff_found

    @add_amount = 0
    @add_percent = 0
    @add_confee_percent = 0
    @add_confee_amount = 0
    if (params[:add_amount].to_s.length + params[:add_percent].to_s.length + params[:add_confee_amount].to_s.length + params[:add_confee_percent].to_s.length) == 0
      flash[:notice] = _('Please_enter_amount_or_percent')
      redirect_to action: 'make_user_tariff', id: @ptariff.id and return false
    end

    unless params[:round_by][/^[1-9]+\d*$|^$/]
      flash[:notice] = _('Round_by_must_be_positive')
      redirect_to action: 'make_user_tariff', id: @ptariff.id and return false
    end

    @add_amount = params[:add_amount] if params[:add_amount].length > 0
    @add_percent = params[:add_percent] if params[:add_percent].length > 0
    @add_confee_amount = params[:add_confee_amount] if params[:add_confee_amount].length > 0
    @add_confee_percent = params[:add_confee_percent] if params[:add_confee_percent].length > 0
    @round_by = params[:round_by]
    if @ptariff.make_retail_tariff(@add_amount, @add_percent, @add_confee_amount, @add_confee_percent, correct_owner_id, @round_by)
      flash[:status] = _('Tariff_created')
    else
      flash[:notice] = _('Tariff_not_created')
    end

  end

  #
  # Makes new tariff and adds fixed percentage and/or amount to prices
  # Most of the work is done inside model.

  # before_filter : tariff(find_taririff_from_id)
  def make_user_tariff_status_wholesale
    @tariff.purpose == 'user_wholesale' ? @tariff_purpose = _('Wholesale_tariff') : @tariff_purpose = _('Provider_tariff')
    @page_title = _('Make_wholesale_tariff')
    @page_icon = 'application_add.png'
    @ptariff = @tariff
    user_tariff_found = check_user_for_tariff(@ptariff)
    return false if !user_tariff_found
    if (params[:add_amount].to_s.length + params[:add_percent].to_s.length + params[:add_confee_amount].to_s.length + params[:add_confee_percent].to_s.length) == 0
      flash[:notice] = _('Please_enter_amount_or_percent')
      redirect_to action: 'make_user_tariff_wholesale', id: @ptariff.id and return false
    end
    @rates_number = Rate.where("tariff_id = '#{@ptariff.id}' AND destination_id != 0").count
    @add_amount = params[:add_amount].to_d
    @add_percent = params[:add_percent].to_d
    @add_confee_amount = params[:add_confee_amount].to_d
    @add_confee_percent = params[:add_confee_percent].to_d
    if admin? || accountant?
      @t_type = params[:t_type] if params[:t_type].to_s.length > 0
    end

    if reseller? || partner?
      @t_type = 'user_wholesale'
    end

    unless @t_type
      flash[:notice] = _('Please_set_tariff_type')
      redirect_to action: 'make_user_tariff_wholesale', id: @ptariff.id and return false
    end

    if @ptariff.make_wholesale_tariff(@add_amount, @add_percent, @add_confee_amount, @add_confee_percent, @t_type)
      flash[:status] = _('Tariff_created')
    else
      flash[:notice] = _('Such_Tariff_Already_Exists')
      redirect_to action: 'make_user_tariff_wholesale', id: @ptariff.id and return false
    end
  end

  def change_tariff_for_users
    @page_title = _('Change_tariff_for_users')
    @page_icon = 'application_add.png'
    user_id = correct_owner_id
    @tariffs = Tariff.where("owner_id = #{user_id}")
  end

  def update_tariff_for_users
    if params[:tariff_from] and params[:tariff_to]
      @tariff_from = Tariff.where(id: params[:tariff_from]).first
      unless @tariff_from
        flash[:notice] = _('Tariff_was_not_found')
        redirect_to action: :list and return false
      end
      @tariff_to = Tariff.where(id: params[:tariff_to]).first
      unless @tariff_to
        flash[:notice] = _('Tariff_was_not_found')
        redirect_to action: :list and return false
      end
      @tariff_from.users.each do |user|
        user.tariff = @tariff_to
        user.save
      end
      flash[:status] = _('Updated_tariff_for_users')
    else
      flash[:notice] = _('Tariff_not_found')
    end
    redirect_to action: 'list'
  end

  # ----------------- PDF/CSV export

  # before_filter : tariff(find_tariff_whith_currency)
  def generate_providers_rates_csv
    check_tariff = check_user_for_tariff(@tariff)
    return false if !check_tariff

    filename = "#{@tariff.name.gsub(' ', '_').upcase}-#{@tariff.currency.to_s.upcase}.csv"
    file = @tariff.generate_providers_rates_csv(session, current_user)
    testable_file_send(file, filename, 'text/csv; charset=utf-8; header=present')
  end

  # before_filter : user; tariff
  def generate_personal_wholesale_rates_csv
    filename = "Rates-#{(@tariff.currency.to_s.upcase).to_s}.csv"
    file = @tariff.generate_providers_rates_csv(session, current_user)
    testable_file_send(file, filename, 'text/csv; charset=utf-8; header=present')
  end
  # before_filter : tariff(find_tariff_whith_currency)
  def generate_user_rates_pdf
    rates = Rate.joins('LEFT JOIN destinationgroups on (destinationgroups.id = rates.destinationgroup_id)').where(['rates.tariff_id = ?', @tariff.id]).order('destinationgroups.name ASC').all
    options = {
        name: @tariff.name,
        pdf_name: _('Users_rates'),
        currency: @tariff.currency.to_s.upcase
    }
    pdf = PdfGen::Generate.generate_rates_header(options)
    pdf = PdfGen::Generate.generate_user_rates_pdf(pdf, rates, @tariff, options)
    file = pdf.render
    filename = "Rates-#{session[:show_currency]}.pdf"
    testable_file_send(file, filename, 'application/pdf')
  end

  # before_filter : tariff(find_tariff_whith_currency)
  def generate_user_rates_csv
    filename = "#{@tariff.name.gsub(' ', '_').upcase}-#{@tariff.currency.to_s.upcase}.csv"
    file = @tariff.generate_user_rates_csv(session)
    testable_file_send(file, filename, 'text/csv; charset=utf-8; header=present')
  end

  def get_personal_rate_details(tariff, dg, exrate)
    rate = dg.rate(tariff.id)

    @arates = []
    @arates = Aratedetail.where("rate_id = #{rate.id} AND artype = 'minute'").order("price DESC") if rate

    # check for custom rates
    @crates = []
    crate = Customrate.where("user_id = '#{session[:user_id]}' AND destinationgroup_id = '#{dg.id}'").first
    if crate && crate[0]
      @crates = Acustratedetail.where("customrate_id = '#{crate[0].id}'").order("price DESC")
      @arates = @crates if @crates[0]
    end
    if @arates[0]
      @arate_cur = Currency.count_exchange_prices({ exrate: exrate, prices: [@arates[0].price.to_d] }) if @arates[0]
    end
  end

  # before_filter : user; tariff
  def generate_personal_rates_pdf
    tariff_currency = @tariff.currency.to_s.upcase
    @s_prefix = session[:user_rates_prefix] ||= ''
    prefix_cond = @s_prefix.present? ? "prefix LIKE #{ActiveRecord::Base::sanitize(@s_prefix.to_s)}" : ''
    dgroups = Destinationgroup.joins('JOIN destinations ON destinations.destinationgroup_id = destinationgroups.id')
                              .where(prefix_cond).order('name ASC').all
    dgroups.uniq!
    tax = session[:tax]
    options = {
        name: @tariff.name,
        pdf_name: _('Personal_rates'),
        currency: tariff_currency
    }
    pdf = PdfGen::Generate.generate_rates_header(options)
    pdf = PdfGen::Generate.generate_personal_rates(pdf, dgroups, @tariff, tax, @user, options)

    filename = "Rates-Personal-#{@user.username}-#{tariff_currency}.pdf"
    file = pdf.render
    testable_file_send(file, filename, 'application/pdf')
  end

  # before_filter : user; tariff
  def generate_personal_rates_csv
    @s_prefix = session[:user_rates_prefix] ||= ''
    prefix_cond = @s_prefix.present? ? "prefix LIKE #{ActiveRecord::Base::sanitize(@s_prefix.to_s)}" : ''
    dgroups = Destinationgroup.joins('JOIN destinations ON destinations.destinationgroup_id = destinationgroups.id')
                              .where(prefix_cond).order('name ASC').all
    dgroups.uniq!
    tax = session[:tax]

    sep = Confline.get_value('CSV_Separator').to_s
    dec = Confline.get_value('CSV_Decimal').to_s

    # csv_string = "Name,Rate,Rate_with_VAT(#{vat}%)\n"
    csv_string = _('Name') + sep + _('Rate') + sep + _('Rate_with_VAT') + "\n"

    for dg in dgroups
      get_personal_rate_details(@tariff, dg, 1)

      if @arates.size > 0
        csv_string += "#{dg.name.to_s.gsub(sep, ' ')}#{sep}"
        csv_string += @arate_cur ? "#{nice_number(@arate_cur).to_s.gsub('.', dec)}#{sep}#{nice_number(tax.count_tax_amount(@arate_cur) + @arate_cur).to_s.gsub('.', dec)}\n" : "0#{sep}0\n"
      end
    end

    filename = "Rates-Personal-#{@user.username}-#{@tariff.currency.to_s.upcase}.csv"
    testable_file_send(csv_string, filename, 'text/csv; charset=utf-8; header=present')
  end

  def analysis
    @page_title = _('Tariff_analysis')
    @page_icon = 'table_gear.png'

    @prov_tariffs = Tariff.where("purpose = 'provider'").order('name ASC')
    @user_wholesale_tariffs = Tariff.where("purpose = 'user_wholesale'").order('name ASC')
    @currs = Currency.get_active
  end

  def analysis2
    @page_title = _('Tariff_analysis')
    @page_icon = 'table_gear.png'

    @prov_tariffs_temp = Tariff.where("purpose = 'provider'").order('name ASC').all
    # @user_tariffs_temp = Tariff.find(:all, :conditions => "purpose = 'user'", :order => "name ASC")
    @user_wholesale_tariffs_temp = Tariff.where("purpose = 'user_wholesale'").order('name ASC').all

    @prov_tariffs = []
    # @user_tariffs = []
    @user_wholesale_tariffs = []
    @all_tariffs = []

    @prov_tariffs_temp.each do |provider_tariff|
      tariff_id = provider_tariff.id
      params_tariff_id_one = params["t#{tariff_id}".intern] == '1'
      @prov_tariffs << provider_tariff if params_tariff_id_one
      @all_tariffs << tariff_id if params_tariff_id_one
    end

    # for t in @user_tariffs_temp
    #  @user_tariffs << t if params[("t" + t.id.to_s).intern] == "1"
    #  @all_tariffs << t.id if params[("t" + t.id.to_s).intern] == "1"
    # end

    @user_wholesale_tariffs_temp.each do |wholesale_tariff|
      tariff_id = wholesale_tariff.id
      params_tariff_id_one = params["t#{tariff_id}".intern] == '1'
      @user_wholesale_tariffs << wholesale_tariff if params_tariff_id_one
      @all_tariffs << tariff_id if params_tariff_id_one
    end

    @curr = params[:currency]

    @tariff_line = ''
    @all_tariffs.each do |tariff|
      @tariff_line << "#{tariff}|"
    end
  end

  def generate_analysis_csv

    cs = confline('CSV_Separator')
    dec = confline('CSV_Decimal')

    curr = params[:curr]
    all_tariffs = params[:tariffs].split('|')

    # my_debug "t----"
    # my_debug params[:tariffs]

    exch_rates = []
    tariff_names = []
    tariff_rates = []

    # header

    csv_string = _('Currency') + ": #{curr}#{cs}#{cs}#{cs}#{cs}".gsub(cs, ' ')

    for tarif in all_tariffs
      tariff = Tariff.find(tarif)
      tariff_names << tariff.name
      er = count_exchange_rate(curr, tariff.currency)
      exch_rates << er.to_d
      if tariff.rates
        tariff_rates << tariff.rates.size
      else
        tariff_rates << 0
      end
      csv_string += "(#{curr}/#{tariff.currency}): ".gsub(cs, ' ')
      csv_string += er.to_s.gsub('.', dec) if er
      csv_string += cs
    end
    csv_string += "\n"

    # my_debug tariff_names

    # csv_string += "direction#{cs}destinations#{cs}subcode#{cs}prefix#{cs}"
    csv_string += _('Direction') + cs + _('Destinations') + cs + _('Prefix')

    for tarif in all_tariffs
      csv_string += Tariff.find(tarif).name.gsub(cs, ' ')
      csv_string += (" (" + tarif.to_s.gsub('.', dec) + ")#{cs}")
    end

    csv_string += cs
    # csv_string += "Min#{cs}Min Provider#{cs}Max#{cs}Max Provider"
    csv_string += _('Min') + cs + _('Min_provider') + cs + _('Max') + cs + _('Max_provider')
    csv_string += "\n"

    # data

    res = []
    prefixes = []
    directions = []
    destinations = []

    min_rates = []
    max_rates = []

    i = 0
    for one_tariff in all_tariffs

      min_rates[i] = 0
      max_rates[i] = 0

      res[i] = []
      tariff = Tariff.find(one_tariff)

      sql = "SELECT directions.name, destinations.name as 'dname', destinations.prefix, ratedetails.rate FROM destinations JOIN directions ON (directions.code = destinations.direction_code) LEFT JOIN  rates ON (destinations.id = rates.destination_id AND rates.tariff_id = '#{tariff.id}')  	LEFT JOIN ratedetails ON (ratedetails.rate_id = rates.id) ORDER BY directions.name ASC, destinations.prefix ASC;"
      sqlres = ActiveRecord::Base.connection.select_all(sql)

      j = 0
      for sr in sqlres
        res[i][j] = sr['rate']
        prefixes[j] = sr['prefix']
        directions[j] = sr['name']
        destinations[j] = sr['dname']

        j += 1
      end

      i += 1
    end


    i = 0
    for rr in 0..res[0].size - 1

      min = nil
      minp = nil
      max = nil
      maxp = nil

      csv_string += directions[i].to_s.gsub(cs, ' ') if directions[i]
      csv_string += cs

      csv_string += destinations[i].to_s.gsub(cs, ' ') if destinations[i]
      csv_string += cs

      csv_string += prefixes[i] if prefixes[i]
      csv_string += cs

      j = 0
      for item in res

        rate = nil
        rate = item[i].to_d / exch_rates[j] if item[i] && exch_rates[j]


        if rate && ((min == nil) || (min.to_d > rate.to_d))
          min = rate
          minp = j
        end

        if rate && ((max == nil) || (max.to_d < rate.to_d))
          max = rate
          maxp = j
        end

        #          my_debug "j: #{j}, maxp: #{maxp}"

        csv_string += nice_number(rate).to_s.gsub('.', dec)
        csv_string += cs
        j += 1
      end


      csv_string += cs
      if !min
        min = ''
        minpt = ''
      else
        if minp
          minpt = tariff_names[minp]
          min_rates[minp] += 1
        end
      end

      if !max
        max = ''
        maxpt = ''
      else
        if maxp
          maxpt = tariff_names[maxp]
          max_rates[maxp] += 1
        end
      end

      csv_string += "#{cs}#{min.to_s.gsub('.', dec)}#{cs}#{minpt.to_s.gsub(cs, ' ')}#{cs}#{max.to_s.gsub('.', dec)}#{cs}#{maxpt.to_s.gsub(cs, ' ')}"

      csv_string += "\n"
      i += 1
    end

    csv_string += "\n"
    csv_string += "#{cs}#{cs}#{cs}#{cs}"

    all_tariffs.each do |tariff|
      csv_string += Tariff.find(tariff).name
      csv_string += (" (" + tariff.to_s + ")#{cs}")
    end

    csv_string += "\n"
    csv_string += "#{cs}#{cs}#{cs}Total rates: #{cs}"

    all_tariffs.each_with_index do |tariff, index|
      csv_string += ("#{tariff_rates[index]}#{cs}")
    end

    csv_string += "\n"
    csv_string += "#{cs}#{cs}#{cs}Min rates: #{cs}"

    all_tariffs.each_with_index do |tariff, index|
      csv_string += ("#{min_rates[index]}#{cs}")
    end

    csv_string += "\n"
    csv_string += "#{cs}#{cs}#{cs}Max rates: #{cs}"

    all_tariffs.each_with_index do |tariff, index|
      csv_string += ("#{max_rates[index]}#{cs}")
    end

    filename = 'Tariff_analysis.csv'
    testable_file_send(csv_string, filename, 'text/csv; charset=utf-8; header=present')
  end

  def destinations_csv
    sql = "SELECT prefix, directions.name AS 'dir_name', destinations.name AS 'dest_name'  FROM destinations JOIN directions ON (destinations.direction_code = directions.code) ORDER BY directions.name, prefix ASC;"
    res = ActiveRecord::Base.connection.select_all(sql)
    cs = confline('CSV_Separator', correct_owner_id)
    cs = ',' if cs.blank?
    csv_line = res.map { |item| "#{item["prefix"]}#{cs}#{item['dir_name'].to_s.gsub(cs, ' ')}#{cs}#{item['dest_name'].to_s.gsub(cs, ' ')}" }.join("\n")
    if params[:test].to_i == 1
      render text: csv_line
    else
      send_data(csv_line, type: 'text/csv; charset=utf-8; header=present', filename: 'Destinations.csv')
    end
  end

  def check_tariff_time
    user_tariff_found = check_user_for_tariff(@tariff.id)
    return false if !user_tariff_found
    session[:imp_date_day_type] = params[:rate_day_type].to_s

    @f_h, @f_m, @f_s, @t_h, @t_m, @t_s = params[:time_from_hour].to_s, params[:time_from_minute].to_s, params[:time_from_second].to_s, params[:time_till_hour].to_s, params[:time_till_minute].to_s, params[:time_till_second].to_s
    @rate_type, flash[:notice_2] = @tariff.check_types_periods(params)

    # logger.info @f_h

    render(layout: false)
  end

  private

  def validate_delta_params
    params_tariff_delta_value = params[:tariff][:delta_value]
    params_tariff_delta_percent = params[:tariff][:delta_percent]

    if params[:delta] == 'delta_value'
      params_tariff_delta_percent = nil
    else
      params_tariff_delta_value = nil
    end
    %w[, ;].each do |symbol|
      params_tariff_delta_percent.to_s.gsub!(symbol, '.')
      params_tariff_delta_value.to_s.gsub!(symbol, '.')
    end
    params[:tariff][:delta_value] = params_tariff_delta_value
    params[:tariff][:delta_percent] = params_tariff_delta_percent
  end

  def check_user_for_tariff(tariff = nil)
    tariff ||= @tariff.id
    if tariff.class.to_s != 'Tariff'
      tariff = Tariff.where('id = ? ', tariff).first
    end

    owner_id = tariff.owner_id
    session_usertype = session[:usertype].to_s

    if session_usertype == 'accountant'
      if owner_id != 0 || session[:acc_tariff_manage].to_i == 0
        dont_be_so_smart
        redirect_to action: :list and return false
      end
    elsif session_usertype == 'reseller' && owner_id != session[:user_id] && (params[:action] == 'rate_details' || params[:action] == 'rates_list' || params[:action] == 'user_rates_list' || params[:action] == 'user_arates_full')
      if !CommonUseProvider.where('reseller_id = ? AND tariff_id = ?', current_user.id, tariff.id).first
        flash[:notice] = _('You_have_no_view_permission')
        redirect_to :root
        return false
      end
    else
      if owner_id != session[:user_id]
        dont_be_so_smart
        redirect_to action: :list and return false
      end
    end
    return true
  end

  def find_tariff_whith_currency
    @tariff = Tariff.where(['id=?', params[:id]]).first
    unless @tariff
      flash[:notice] = _('Tariff_was_not_found')
      redirect_to action: :list and return false
    end

    unless @tariff.real_currency
      flash[:notice] = _('Tariff_currency_not_found')
      redirect_to action: :list and return false
    end
  end

  def find_tariff_from_id
    @tariff = Tariff.where('id = ?', params[:id]).first
    unless @tariff
      flash[:notice] = _('Tariff_was_not_found')
      redirect_to action: :list
      return false
    end
  end

  def find_user_from_session
    @user = User.includes(:tariff).where(['users.id = ?', session[:user_id]]).first
    unless @user
      flash[:notice] = _('User_was_not_found')
      redirect_to action: :list and return false
    end
  end

  def find_user_tariff
    common_use_provider_tariff
    @tariff = @user.tariff if @tariff.blank?
    unless @tariff
      flash[:notice] = _('Tariff_was_not_found')
      redirect_to action: :list and return false
    end

    unless @tariff.real_currency
      flash[:notice] = _('Tariff_currency_not_found')
      redirect_to action: :list and return false
    end
  end

  def get_provider_rate_details(rate, exrate)
    @rate_details = Ratedetail.where(['rate_id = ?', rate.id]).order('rate DESC')
    if @rate_details.size > 0
      @rate_increment_s = @rate_details[0]['increment_s']
      @rate_cur, @rate_free = Currency.count_exchange_prices({exrate: exrate, prices: [@rate_details[0]['rate'].to_d, @rate_details[0]['connection_fee'].to_d]})
    end
    @rate_details
  end

  def accountant_permissions
    session_acc_tariff_manage = session[:acc_tariff_manage].to_i
    session_acc_tariff = session_acc_tariff_manage == 0
    session_usertype_accountant = session[:usertype] == 'accountant'
    allow_manage = !(session_usertype_accountant && (session_acc_tariff || session_acc_tariff_manage == 1))
    allow_read = !(session_usertype_accountant && (session_acc_tariff))
    return allow_manage, allow_read
  end

  def common_use_provider_tariff(id = nil)
    @common_use_provider = nil
    provider_id = id || params[:common_use_provider]
    if provider_id.present? && reseller?
      provider = Application.common_use_provider(provider_id)
      if provider.present?
        @tariff = Tariff.where(id: provider.tariff_id).first
        @common_use_provider = provider_id
      end
    end
  end

  def generate_page_details(collection_size)
    items_per_page = session[:items_per_page]
    page_number = @page

    iend = ((items_per_page * page_number) - 1)
    iend = collection_size - 1 if iend > collection_size - 1
    items_beginning = ((page_number - 1) * items_per_page)

    return items_beginning, iend
  end

  def find_step_name(step)
    case step
    when 2 then _('Column_assignment')
    when 3 then _('Column_confirmation')
    when 4 then _('Analysis')
    when 5 then _('Creating_destinations')
    when 6 then _('deleting_rates')
    when 7 then _('Updating_rates')
    when 8 then _('Creating_new_rates')
    else _('File_upload')
    end
  end

  def import_csv2_step_0
    tariff_id = @tariff.id
    options_to_session_delete(session)
    my_debug_time '**********import_csv2************************'
    my_debug_time 'step 0'
    session["tariff_name_csv_#{tariff_id}".to_sym] = nil
    session["temp_tariff_name_csv_#{tariff_id}".to_sym] = nil
    session[:import_csv_tariffs_import_csv_options] = nil
  end

  def import_csv2_step_1
    tariff_id = @tariff.id
    my_debug_time 'step 1'
    session["temp_tariff_name_csv_#{tariff_id}".to_sym] = nil
    session["tariff_name_csv_#{tariff_id}".to_sym] = nil
    if params[:file]
      @file = params[:file]
      file_size = @file.size
      if  file_size > 0
        if !@file.respond_to?(:original_filename) || !@file.respond_to?(:read) || !@file.respond_to?(:rewind)
          flash[:notice] = _('Please_select_file')
          redirect_to action: "import_csv2", id: tariff_id, step: '0' and throw :done
        end
        if get_file_ext(@file.original_filename, "csv") == false
          @file.original_filename
          flash[:notice] = _('Please_select_CSV_file')
          redirect_to action: "import_csv2", id: tariff_id, step: '0' and throw :done
        end
        @file.rewind
        file = @file.read.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace, replace: '?').gsub("\r\n", "\n")
        session[:file_size] = file.size
        session["temp_tariff_name_csv_#{tariff_id}".to_sym] = @tariff.save_file(file)
        flash[:status] = _('File_downloaded')
        redirect_to action: "import_csv2", id: tariff_id, step: '2' and throw :done
      else
        session["temp_tariff_name_csv_#{tariff_id}".to_sym] = nil
        flash[:notice] = _('Please_select_file')
        redirect_to action: "import_csv2", id: tariff_id, step: '0' and throw :done
      end
    else
      session["temp_tariff_name_csv_#{tariff_id}".to_sym] = nil
      flash[:notice] = _('Please_upload_file')
      redirect_to action: "import_csv2", id: tariff_id, step: '0' and throw :done
    end
  end

  def import_csv2_step_2
    tariff_id = @tariff.id
    if session[:import_date_from].present?
      %i[ year month day hour minute].each do |key|
        params[:date_from] ||= {}
        params[:date_from][key] = session[:import_date_from][key] if params[:date_from][key].blank?
      end
    end
    my_debug_time 'step 2'
    my_debug_time "use : #{session["temp_tariff_name_csv_#{tariff_id}".to_sym]}"
    if session["temp_tariff_name_csv_#{tariff_id}".to_sym]
      file = @tariff.head_of_file("/tmp/#{session["temp_tariff_name_csv_#{tariff_id}".to_sym]}.csv", 20).join
      session[:file] = file
      if params[:dont_check_seperator] || check_csv_file_seperators(file, 2, 2)
        @fl = @tariff.head_of_file("/tmp/#{session["temp_tariff_name_csv_#{tariff_id}".to_sym]}.csv", 1).join.split(@sep)
        begin
          session["tariff_name_csv_#{tariff_id}".to_sym] = @tariff.load_csv_into_db(session["temp_tariff_name_csv_#{tariff_id}".to_sym], @sep, @dec, @fl)

          # drop columns from temp table that are not allowed to be imported
          ['Class'].each do |column_to_drop|
            unless @fl.index("#{column_to_drop}").nil?
              ActiveRecord::Base.connection.execute("ALTER TABLE #{session["tariff_name_csv_#{tariff_id}".to_sym]} " +
                                                    "DROP col_#{@fl.index("#{column_to_drop}")};")
            end
          end

          session[:file_lines] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{session["tariff_name_csv_#{tariff_id}".to_sym]}")
          session[:first_effective_from_value] =
                if @effective_from_active
                  effective_from_col = @fl.index { |column_header| Regexp.union(/\Aeffective from\z/).match(column_header.to_s.strip.downcase) }
                  if effective_from_col.blank?
                    ''
                  else
                    ActiveRecord::Base.connection.select_value("SELECT col_#{effective_from_col} FROM #{session["tariff_name_csv_#{tariff_id}".to_sym]} WHERE id = 2")
                  end
                else
                  ''
                end
        rescue => e
          MorLog.log_exception(e, Time.now.to_i, params[:controller], params[:action])
          session[:import_csv_tariffs_import_csv_options] = { sep: @sep, dec: @dec }
          begin
            session[:file] = File.open("/tmp/#{session["temp_tariff_name_csv_#{tariff_id}".to_sym]}.csv", 'rb').read
          rescue => e
            MorLog.log_exception(e, Time.now.to_i, params[:controller], params[:action])
            flash[:notice] = _('Please_upload_file')
            redirect_to action: 'import_csv2', id: tariff_id, step: '1'
            throw :done
          end
          Tariff.clean_after_import(session["temp_tariff_name_csv_#{tariff_id}".to_sym])
          session["temp_tariff_name_csv_#{tariff_id}".to_sym] = nil
          flash[:notice] = _('MySQL_permission_problem_contact_Kolmisoft_to_solve_it')
          redirect_to action: 'import_csv2', id: tariff_id, step: '2'
          throw :done
        end
        session[:default_effective_from] = Time.now
        flash[:status] = _('File_uploaded') if !flash[:notice]
      end
    else
      session["tariff_name_csv_#{tariff_id}".to_sym] = nil
      flash[:notice] = _('Please_upload_file')
      redirect_to action: 'import_csv2', id: tariff_id, step: '1'
      throw :done
    end
    @rate_type, flash[:notice_2] = @tariff.check_types_periods(params)
  end

  def check_if_file_in_db
    tariff_id = @tariff.id
    key = "temp_tariff_name_csv_#{tariff_id}".to_sym
    file_is_in_db = ActiveRecord::Base.connection.tables.include?(session[key])
    if !file_is_in_db || !session[:file]
      flash[:notice] = _('Please_upload_file')
      redirect_to action: 'import_csv2', id: tariff_id, step: '0'
      throw :done
    end
  end

  def check_if_filename_in_session
    if !session["tariff_name_csv_#{@tariff.id}".to_sym] || !session[:file]
      flash[:notice] = _('Zero_file')
      redirect_to controller: 'tariffs', action: 'list'
      throw :done
    end
  end

  def import_csv2_step_3
    tariff_id = @tariff.id
    options_to_session(params)
    my_debug_time 'step 3'
    params_prefix_id = params[:prefix_id]
    params_rate_id = params[:rate_id]
    params_effective_from = params[:effective_from].to_i

    if params_prefix_id && params_rate_id && params_prefix_id.to_i >= 0 && params_rate_id.to_i >= 0
      @options = {
        imp_prefix: params_prefix_id.to_i,
        imp_rate: params_rate_id.to_i
      }

      if @effective_from_active
        if params_effective_from >= 0
        @options.merge!({
          imp_effective_from: params_effective_from,
          current_user_tz: Time.zone.now.formatted_offset,
          date_format: (params[:effective_from_date_format] + ' %H:%i:%s')
        })
        elsif params_effective_from <= 0
          change_date_from
          params_date = params[:date_from]
          blank_params = params_date.try(:any?) { |_param, value| value.blank? }
          chosen_time = session_from_datetime
          date_from_second = params[:date_from][:second]
          # Effective From not selected manually, default value will be used
          if blank_params || params_date.try(:size) != 6 || chosen_time.blank? || date_from_second.blank?
            @options[:manual_effective_from] = session[:default_effective_from]
          else # Effective from selected manually
            @options[:manual_effective_from] = chosen_time[0, chosen_time.rindex(':') + 1] + date_from_second
          end
        end
      end

      @options.merge!({
        imp_increment_s: params[:increment_id].to_i,
        imp_min_time: params[:min_time_id].to_i,
        imp_ghost_percent: params[:ghost_percent_id].to_i,
        imp_cc: -1,
        imp_city: -1,
        imp_country: -1,
        imp_connection_fee: (params[:connection_fee_id].try(:to_i) || -1),
        imp_date_day_type: params[:rate_day_type].to_s,
        imp_dst: (params[:destination_id].try(:to_i) || -1)
      })

      @rate_type, flash[:notice_2] = @tariff.check_types_periods(params)
      @options[:imp_time_from_type] = params[:time_from][:hour].to_s + ':' + params[:time_from][:minute].to_s + ':' + params[:time_from][:second].to_s if params[:time_from]
      @options[:imp_time_till_type] = params[:time_till][:hour].to_s + ':' + params[:time_till][:minute].to_s + ':' + params[:time_till][:second].to_s if params[:time_till]

      @options[:imp_update_dest_names] = params[:update_dest_names].to_i if admin? || accountant?
      @options[:imp_delete_unimported_prefix_rates] = params[:delete_unimported_prefix_rates].to_i

      if (admin? || accountant?) && params[:update_dest_names].to_i == 1

        if !params[:destination_id] || params[:destination_id].to_i < 0
          flash[:notice] = _('Please_Select_Columns_destination')
          redirect_to action: 'import_csv2', id: tariff_id, step: '2'
          throw :done
        else
          check_destination_names = "select count(*) as notnull from " + session["tariff_name_csv_#{@tariff.id}".to_sym].to_s + " where original_destination_name is NOT NULL"
          not_blank_values = ActiveRecord::Base.connection.select(check_destination_names).first["notnull"].to_i

          if not_blank_values == 0
            sql = "UPDATE " + session["tariff_name_csv_#{@tariff.id}".to_sym].to_s + " JOIN destinations ON (replace(col_1, '\\r', '') = destinations.prefix) SET original_destination_name = destinations.name"
            ActiveRecord::Base.connection.execute(sql)
          end
        end
      end
      # priority over csv

      sql = "SELECT COUNT(*) FROM #{session["tariff_name_csv_#{tariff_id}".to_sym]}"
      file_lines = ActiveRecord::Base.connection.select_value(sql)

      @options.merge!({
        manual_connection_fee: (params[:manual_connection_fee] || ''),
        manual_increment: (params[:manual_increment]),
        manual_min_time: (params[:manual_min_time] || ''),
        sep: @sep,
        dec: @dec,
        file: session[:file],
        file_size: session[:file_size],
        file_lines: file_lines,
        manual_ghost_percent: params[:manual_ghost_percent]
      }.reject { |_, value| value.nil? })

      session["tariff_import_csv2_#{tariff_id}".to_sym] = @options
      flash[:status] = _('Columns_assigned')
    else
      flash[:notice] = _('Please_Select_Columns')
      redirect_to action: 'import_csv2', id: tariff_id, step: '2'
      throw :done
    end
  end

  def check_existence_of_calldate_and_billsec
    tariff_id = @tariff.id
    session_tariff_import_csv2 = session["tariff_import_csv2_#{tariff_id}".to_sym]
    if session_tariff_import_csv2 && session_tariff_import_csv2[:imp_prefix] && session_tariff_import_csv2[:imp_rate]
    else
      flash[:notice] = _('Please_Select_Columns')
      redirect_to action: 'import_csv2', id: tariff_id, step: '2'
      throw :done
    end
  end

  # Analyze imported rates. Plan to Update/Create Destinations, Update/Create Rates/Ratedetails
  def import_csv2_step_4
    my_debug_time('step 4')
    options_to_session_delete(session)
    tariff_id = @tariff.id

    @tariff_analize = @tariff.analyze_file(session["tariff_name_csv_#{tariff_id}".to_sym],
                                           session["tariff_import_csv2_#{tariff_id}".to_sym]
    )

    session[:bad_destinations] = @tariff_analize[:bad_prefixes]
    session[:bad_lines_array] = @tariff_analize[:bad_prefixes]
    session[:bad_lines_status_array] = @tariff_analize[:bad_prefixes_status]


    flash[:status] = _('Analysis_completed')
    session["tariff_analize_csv2_#{tariff_id}".to_sym] = @tariff_analize

    begin
      if reseller? || partner?
        @tariff.create_deatinations(session["tariff_name_csv_#{tariff_id}".to_sym],
                                    session["tariff_import_csv2_#{tariff_id}".to_sym],
                                    session["tariff_analize_csv2_#{tariff_id}".to_sym]
        )
      end
    rescue => err
      my_debug_time(err.to_yaml)
      flash[:notice] = _('collision_Please_start_over')

      my_debug_time('clean start')
      Tariff.clean_after_import(session["tariff_name_csv_#{@tariff.id}".to_sym])
      session["temp_tariff_name_csv_#{@tariff.id}".to_sym] = nil
      my_debug_time('clean done')

      redirect_to(action: :import_csv2, id: @tariff.id, step: '0') && (return false)
    end
  end

  # Update/Create Destinations
  def import_csv2_step_5
    my_debug_time('step 5')
    tariff_id = @tariff.id
    @tariff_analize = session["tariff_analize_csv2_#{tariff_id}".to_sym]

    begin
      status = ''
      session["tariff_analize_csv2_#{tariff_id}".to_sym][:created_destination_from_file] = @tariff.create_deatinations(session["tariff_name_csv_#{tariff_id}".to_sym], session["tariff_import_csv2_#{tariff_id}".to_sym], session["tariff_analize_csv2_#{tariff_id}".to_sym])
      status += _('Created_destinations') + ": #{session["tariff_analize_csv2_#{tariff_id}".to_sym][:created_destination_from_file]}" if session["tariff_analize_csv2_#{tariff_id}".to_sym][:created_destination_from_file].to_i > 0
      if session["tariff_import_csv2_#{tariff_id}".to_sym][:imp_update_dest_names].to_i == 1 && ['admin', 'accountant'].include?(session[:usertype])
        session["tariff_analize_csv2_#{tariff_id}".to_sym][:updated_destination_from_file] = @tariff.update_destinations(session["tariff_name_csv_#{tariff_id}".to_sym], session["tariff_import_csv2_#{tariff_id}".to_sym], session["tariff_analize_csv2_#{tariff_id}".to_sym])
        status += '<br />' if status.present?
        status += _('Destination_names_updated') + ": #{session["tariff_analize_csv2_#{tariff_id}".to_sym][:updated_destination_from_file]}" if session["tariff_analize_csv2_#{tariff_id}".to_sym][:updated_destination_from_file].to_i > 0
      end
      session["tariff_analize_csv2_#{tariff_id}".to_sym][:nil_destinations_in_db] = Destination.count_without_group
      flash[:status] = status if status.present?
    rescue => err
      my_debug_time(err.to_yaml)
      flash[:notice] = _('collision_Please_start_over')

      my_debug_time('clean start')
      Tariff.clean_after_import(session["tariff_name_csv_#{@tariff.id}".to_sym])
      session["temp_tariff_name_csv_#{@tariff.id}".to_sym] = nil
      my_debug_time('clean done')

      redirect_to(action: :import_csv2, id: @tariff.id, step: '0') && (return false)
    end
  end

  # delete rates not present in imported file
  def import_csv2_step_6
    my_debug_time('step 6')
    tariff_id = @tariff.id

    @tariff_analize = session["tariff_analize_csv2_#{tariff_id}".to_sym]

    if @tariff_analize[:rates_to_delete].to_i > 0
      @tariff_analize[:deleted_rates] = @tariff.delete_unimported_rates(session["tariff_name_csv_#{tariff_id}".to_sym],
                                                                        session["tariff_import_csv2_#{tariff_id}".to_sym]
      )
    end

    flash[:status] = "#{_('deleted_rates')}: #{@tariff_analize[:deleted_rates]}"

    Action.add_action(session[:user_id], 'tariff_import_2', _('Tariff_was_imported_from_CSV'))
  end

  # Update Rates' Creating/Updating Ratedetails
  # 'Update' (Create) Rates with different Effective From (marking it as Rate update)
  def import_csv2_step_7
    my_debug_time('step 7')
    tariff_id = @tariff.id
    tariff_analysis = "tariff_analize_csv2_#{tariff_id}".to_sym

    @tariff_analize = session[tariff_analysis]

    # Update Rates/Ratedetails with identical Effective From
    # 'Update' (create) Rates with different Effective From
    if session[tariff_analysis].present?
      # Nasty workaround, requires to fix, this is because its not quite working well with effective from and ratedetails (day types)
      session[tariff_analysis][:updated_rates_from_file] = @tariff_analize[:rates_to_update]
      @tariff.update_rates_from_csv(session["tariff_name_csv_#{tariff_id}".to_sym],
                                    session["tariff_import_csv2_#{tariff_id}".to_sym],
                                    session[tariff_analysis]
      )
    end

    # Update Rates creating new Ratedetails
    #   updates existing Rates, if there are new Rates to create, postpone for when they are created.
    if @tariff_analize[:new_rates_to_create].to_i.zero?
      @tariff.insert_ratedetails(session["tariff_name_csv_#{tariff_id}".to_sym],
                                 session["tariff_import_csv2_#{tariff_id}".to_sym],
                                 session[tariff_analysis]
      )
    end

    if @tariff_analize[:rates_to_update].to_i > 0
      flash[:status] = "#{_('Rates_updated')}: #{@tariff_analize[:rates_to_update]}"
    else
      flash[:status] = nil
    end
  end

  # Create new Rates/Ratedetails if Rate (by prefix) not found
  def import_csv2_step_8
    my_debug_time('step 8')
    tariff_id = @tariff.id
    tariff_analysis = "tariff_analize_csv2_#{tariff_id}".to_sym

    @tariff_analize = session[tariff_analysis]

    session[tariff_analysis][:created_rates_from_file] =
        @tariff.create_rates_from_csv(session["tariff_name_csv_#{tariff_id}".to_sym],
                                      session["tariff_import_csv2_#{tariff_id}".to_sym],
                                      session[tariff_analysis]
        )

    # Update Rates creating new Ratedetails
    # For newly created Rates
    tariff_analize_rates_create = @tariff_analize[:new_rates_to_create].to_i > 0
    if tariff_analize_rates_create
      @tariff.insert_ratedetails(session["tariff_name_csv_#{tariff_id}".to_sym],
                                 session["tariff_import_csv2_#{tariff_id}".to_sym],
                                 session[tariff_analysis]
      )
    end

    if tariff_analize_rates_create
      flash[:status] = "#{_('New_rates_created')}: #{@tariff_analize[:new_rates_to_create]}"
    else
      flash[:status] = nil
    end
  end

  def find_rate_from_id
    @rate = Rate.where(id: params[:id]).first
    unless @rate
      flash[:notice] = _('Rate_was_not_found')
      redirect_to action: :list
      return false
    end
  end

  def find_rate_and_ratedetail_from_id
    @ratedetail = Ratedetail.where(id: params[:id]).first
    unless @ratedetail
      flash[:notice] = _('Ratedetail_was_not_found')
      redirect_to action: :list
      return false
    end

    @rate = Rate.where(id: @ratedetail.rate_id).first
    unless @rate
      flash[:notice] = _('Rate_was_not_found')
      redirect_to action: :list
      return false
    end
  end

  def set_page_title_and_name(step)
    step_names = [_('File_upload'),
                  _('Column_assignment'),
                  _('Column_confirmation'),
                  _('Analysis'),
                  _('Creating_destinations'),
                  _('Updating_rates'),
                  _('Creating_new_rates')]
    @step_name = step_names[step - 1]

    space =  "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;"
    @page_title = (_('Import_XLS') + space + _('Step') + ': ' + step.to_s + space + @step_name).html_safe
    @page_icon = 'excel.png'
  end

  def rate_details_updated(message)
    flash[:status] = _(message)
    @rate.tariff_updated
  end

  def convert_blocked_params(params)
    params.each { |key, value| params[key] = -1 if params[key].to_s.downcase == 'blocked' }
  end

  def options_to_session(params)
    %i[ prefix_id rate_id effective_from connection_fee_id increment_id min_time_id ghost_percent_id destination_id manual_connection_fee manual_increment manual_min_time manual_ghost_percent ].each do |key|
      session[key] = params[key]
    end
    params_date = params[:date_from]
    if params_date[:year].present? && params_date[:month].present? && params_date[:day].present? && params_date[:hour].present? && params_date[:minute].present? && params_date[:second].present?
      session[:import_manual_eff] = params_date[:year].to_s + '-' + params_date[:month].to_s + '-' + params_date[:day].to_s + ' ' + params_date[:hour].to_s + ':' + params_date[:minute].to_s + ':' + params_date[:second].to_s
    end

    if params[:time_from].present?
      session[:time_from_hour] = params[:time_from][:hour].to_s
      session[:time_from_minute] = params[:time_from][:minute].to_s
      session[:time_from_second] = params[:time_from][:second].to_s
    end
    if params[:time_till].present?
      session[:time_till_hour] = params[:time_till][:hour].to_s
      session[:time_till_minute] = params[:time_till][:minute].to_s
      session[:time_till_second] = params[:time_till][:second].to_s
    end
    session[:update_dest_names] = params[:update_dest_names]
    session[:delete_unimported_prefix_rates] = params[:delete_unimported_prefix_rates].to_i
    session[:effective_from_date_format] = params[:effective_from_date_format]
    session[:rate_day_type] = params[:rate_day_type]
  end

  def options_to_session_delete(session)
    session.delete(:time_from_hour)
    session.delete(:time_from_minute)
    session.delete(:time_from_second)
    session.delete(:time_till_hour)
    session.delete(:time_till_minute)
    session.delete(:time_till_second)
    session.delete(:import_manual_eff)
    %i[ prefix_id rate_id effective_from connection_fee_id increment_id min_time_id ghost_percent_id destination_id manual_connection_fee manual_increment manual_min_time manual_ghost_percent ].each do |key|
      session.delete(key)
    end
    session.delete(:rate_day_type)
    session.delete(:update_dest_names)
    session.delete(:delete_unimported_prefix_rates)
    session.delete(:effective_from_date_format)
  end
end
