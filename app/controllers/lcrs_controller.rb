# -*- encoding : utf-8 -*-
# Least Cost Routing - set of Providers that should be used to send a call.
class LcrsController < ApplicationController

  layout 'callc'

  before_filter :check_post_method, :only => [:remove_provider, :destroy, :create, :update, :lcrpartial_destroy, :update_lcrpartial]


  before_filter :check_localization
  before_filter :authorize
  before_filter :acc_manage_lcr_restrict, only: [:lcr_clone], if: -> { accountant? }
  before_filter :acc_manage_lcr_no_permissions, only: [:make_tariff], if: -> { accountant? }
  before_filter :acc_manage_lcr_read_permission, only: [:new, :providers_percent, :providers_sort], if: -> { accountant? }

  @@acc_lcr_view = [
      :index, :list, :prefix_finder_find_country, :edit, :details_by_destinations, :lcrpartial_edit,
      :lcrpartial_destinations, :providers_list, :tariffs_list, :providers_percent, :find_lcr_from_id,
      :find_lcr_partial_from_id, :providers_sort, :new
  ]
  @@acc_lcr_edit = [
      :create, :destroy, :update, :create_prefix_lcr_partials, :create_destinationgroup_lcr_partials,
      :create_destination_lcr_partials, :lcrpartial_destroy, :update_lcrpartial, :provider_change_status,
      :remove_provider, :try_to_add_provider, :providers_sort_save
  ]

  before_filter(only: @@acc_lcr_view + @@acc_lcr_edit) { |method|
    allow_read, allow_edit = method.check_read_write_permission(@@acc_lcr_view, @@acc_lcr_edit, {role: 'accountant', right: :acc_manage_lcr})
    method.instance_variable_set :@allow_read, allow_read
    method.instance_variable_set :@allow_edit, allow_edit
    true
  }

  before_filter :providers_enabled_for_reseller?, unless: -> { accountant? }
  before_filter :find_lcr_from_id, :only => [:lcr_clone, :make_tariff, :details, :provider_change_status, :remove_provider, :try_to_add_provider, :providers_sort_save, :providers_sort, :providers_percent, :provider_change_status, :edit, :update, :destroy, :details_by_destinations, :providers_list, :try_to_add_failover_provider, :change_position]
  before_filter :find_lcr_partial_from_id, :only => [:lcrpartial_destroy, :lcrpartial_edit, :update_lcrpartial]
  before_filter :check_owner, :only => [:make_tariff, :details, :provider_change_status, :remove_provider, :try_to_add_provider, :providers_sort_save, :providers_sort, :providers_percent, :provider_change_status, :edit, :update, :destroy, :details_by_destinations, :providers_list, :try_to_add_failover_provider]
  before_filter :lcr_uses_failover_as_provider?, only: [:try_to_add_failover_provider]

  def list
    @page_title = _('LCR')
    @page_icon = "arrow_switch.png"
    @help_link = 'http://wiki.kolmisoft.com/index.php/LCR'

    @show_currency_selector=1

    session[:lcrs_list_options] ? @options = session[:lcrs_list_options] : @options = {}

    # search
    params[:page] ? @options[:page] = params[:page].to_i : (@options[:page] = 1 if !@options[:page])
    params[:s_name] ? @options[:s_name] = params[:s_name].strip.to_s : (params[:clean]) ? @options[:s_name] = "" : (@options[:s_name]) ? @options[:s_name] = session[:lcrs_list_options][:s_name] : @options[:s_name] = ""

    # order
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 0 if !@options[:order_desc])
    params[:order_by] ? @options[:order_by] = params[:order_by].to_s : @options[:order_by] == "acc"

    order_by = corrected_current_user.lcrs.lcrs_order_by(params, @options)

    cond =[]; var =[]
    if !@options[:s_name].blank?
      cond << 'lcrs.name LIKE ?'; var << ["%" +@options[:s_name] + "%"]
    end
    arr = {}
    arr[:conditions] =[cond.join(' AND ')] + var if cond.size.to_i > 0

    # page params
    @lcrs_size = corrected_current_user.load_lcrs(arr).size.to_i
    @fpage, @total_pages, @options = Application.pages_validator(session, @options, @lcrs_size)

    @search = @options[:s_name].blank? ? 0 : 1

    arr[:order] = order_by
    arr[:limit] = "#{@fpage}, #{session[:items_per_page].to_i}"
    @lcrs = corrected_current_user.load_lcrs(arr)

    session[:lcrs_list_options] = @options
  end

  def new
    @page_title = _('LCR_new')
    @page_icon = "add.png"
    @lcr = Lcr.new
    @help_link = 'http://wiki.kolmisoft.com/index.php/LCR'
  end

  def create
    @page_title = _('LCR_new')
    @page_icon = "add.png"
    @help_link = 'http://wiki.kolmisoft.com/index.php/LCR'

    param_lcr = params[:lcr]
    @lcr = Lcr.new(param_lcr.merge!({:user_id => corrected_current_user.id}))
    @lcr.name = param_lcr[:name] || ''

    if !@lcr.name.blank?
      if @lcr.save
        flash[:status] = _('Lcr_was_successfully_created')
        redirect_to :action => 'list'
      else
        flash_errors_for(_('Lcr_not_created'), @lcr)
        render :new
      end
    else
      flash_errors_for(_('Lcr_not_created'), @lcr)
      render :new
    end
  end

  #in before filter : @lcr
  def edit
    @page_title = _('LCR_edit')
    @page_icon = "edit.png"
    @help_link = 'http://wiki.kolmisoft.com/index.php/LCR'

    @options = session[:lcr_edit_options] || Hash.new

    @lcr.create_timeperiods if @lcr.lcr_timeperiods.size < 5

    @months_for_select	 = [["",""]]+(Date::MONTHNAMES.compact).zip((1..12).to_a)
    @weekdays_for_select = [["",""]]+(Date::DAYNAMES.compact).zip((1..7).to_a)
    @lcrs_for_select	 = @lcr.user.lcrs.order(:name).reject { |lcr| lcr.id == @lcr.id }
  end

  #in before filter : @lcr
  def update
    @page_title = _('LCR_edit')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/LCR'

    @old_lcr = @lcr.dup
    @lcr.no_failover = params[:lcr][:no_failover].to_i

    minimal_rate_numeric = is_numeric?(params[:lcr][:minimal_rate_margin_percent]) ? '' : 'minimal_rate_margin_percent'
    if @lcr.update_attributes(params[:lcr].reject { |key, value| key == 'user_id' || key == minimal_rate_numeric })
      if @old_lcr.order != @lcr.order && @lcr.order == 'priority'
        Lcrprovider.select('lcrproviders.*')
        .joins('RIGHT JOIN providers ON (providers.id = lcrproviders.provider_id)')
        .where(lcr_id: @lcr.id)
        .each_with_index { |provider, index|
          provider.priority = index
          provider.save
        }
      end

      # A: LcrTimeperiods forma
      errors = []
      unless params['periods'].blank?
        @lcr.lcr_timeperiods.each do |period|
          options = params['periods']["#{period.id}"]
          period.active = options[:active]
          options.each do |key, value|
            period[key.to_sym] = value.to_s.strip
          end

          unless period.save
            errors += period.errors.messages.values.flatten
          end
        end
      end

      unless is_numeric?(params[:lcr][:minimal_rate_margin_percent])
        errors << _('Minimal_margin_percent_must_be_decimal_number')
      end

      if errors.blank?
        flash[:status] = _('Lcr_was_successfully_updated')
        redirect_to action: :list, id: @lcr
      else
        flash[:notice] = _('Lcr_not_updated')
        errors.uniq.each do |error|
          flash[:notice] += "<br /> * #{error}"
        end
        session[:lcr_edit_options] = params
        redirect_to action: :edit, id: @lcr
      end
    else
      flash_errors_for(_('Lcr_not_updated'), @lcr)
      render :edit
    end
  end

  #in before filter : @lcr
  def destroy
    @lcr.validate_before_destroy
    if @lcr.respond_to?(:errors) and @lcr.errors.size == 0
      @lcr.destroy_all
      @lcr.destroy
      LcrPartial.where(:main_lcr_id => @lcr.id).destroy_all
      flash[:status] = _('Lcr_deleted')
    else
      flash_errors_for(_('Lcr_not_deleted'), @lcr)
    end
    redirect_to :action => 'list'
  end

  def details
    @page_title = _('LCR_Details')
    @page_icon = "view.png"
    @lcrs = @lcr
    owner_id = correct_owner_id
    if ['reseller', 'accountant', 'admin'].include?(corrected_current_user.usertype) and (@lcr.user_id != corrected_current_user.id and @lcr.id != corrected_current_user.lcr_id)
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
    lcr_id = @lcrs.id
    @user = User.where(['lcr_id = ? AND owner_id = ?', lcr_id, owner_id])
    @cardgroup = Cardgroup.where(['lcr_id = ? AND owner_id = ?', lcr_id, owner_id])
  end

  #in before filter : @lcr
  def details_by_destinations
    @page_title = _('Routing_by_destinations')
    @page_icon = 'view.png'

    session[:details_by_destinations_options] ? @options = session[:details_by_destinations_options] : @options = {}
    @options = clear_options(@options) if params[:clear].to_i == 1

    [:s_destination, :s_prefix, :s_country].each { |key|
      params[key] ? @options[key] = (params[key].to_s) : (@options[key] = '' if !@options[key])
    }

    if params[:page] and params[:page].to_i > 0
      @options[:page] = params[:page].to_i
    else
      @options[:page] = 1 if !@options[:page] or @options[:page] <= 0
    end

    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 0 if !@options[:order_desc])
    params[:order_by] ? @options[:order_by] = params[:order_by].to_s : @options[:order_by] == 'name'

    @lcr_partials = @lcr.lcr_partials_destinations(@options)

    fpage, @total_pages, @options = Application.pages_validator(session, @options, @lcr_partials.try(:size))

    @lcr_partials = @lcr_partials[fpage...(session[:items_per_page].to_i + fpage)].to_a

    @dest_new = 0
    @lcrs = corrected_current_user.load_lcrs({order: 'name ASC'})
    @countrys = Direction.order(:name)
    @destination_groups = Destinationgroup.order(:name)
    @phrase = request.raw_post || request.query_string
    @phrase = @phrase.gsub('=', '')
    if (@phrase.to_s != 'no_directiontrue') && (@phrase != nil)
      @direction = Direction.where(code: params[:dir]).first
    else
      @direction = Direction.first
    end

    @search = @options.any? { |opt| [:s_destination, :s_prefix, :s_country].include?(opt[0]) if opt[1].present? } ? 1 : 0

    session[:details_by_destinations_options] = @options
  end

  def create_prefix_lcr_partials
    main_lcr_id = params[:id]
    prefix = params[:search].to_s

    if prefix.present?
      if Destination.where('prefix = ?', prefix).first
        lp = LcrPartial.new(
          prefix: prefix,
          main_lcr_id: main_lcr_id,
          lcr_id: params[:lcr],
          user_id: corrected_current_user.id
        )

        # Search for same prefix in lcr_partials
        if lp.duplicate_partials == 0
          lp.save
          flash[:status] = _('Saved')
        else
          flash[:notice] = _('Such_prefix_already_exists_in_this_LCR')
        end
      else
        flash[:notice] = _('Prefix_not_found')
      end
    else
      flash[:notice] = _('Prefix_error')
    end

    redirect_to(action: :details_by_destinations, id: main_lcr_id)
  end

  def create_destinationgroup_lcr_partials
    main_lcr_id = params[:id]
    destinationgroup_id = params[:destinationgroup_id].to_i

    if destinationgroup_id > 0
      if Destinationgroup.where('id = ?', destinationgroup_id).first
        dg_lp = LcrPartial.new(
          destinationgroup_id: destinationgroup_id,
          main_lcr_id: main_lcr_id,
          lcr_id: params[:lcr],
          user_id: corrected_current_user.id
        )

        # Search for same destination group in lcr_partials
        if dg_lp.duplicate_partials == 0
          dg_lp.save
          flash[:status] = _('Saved')
        else
          flash[:notice] = _('Such_destination_group_already_exists_in_this_LCR')
        end
      else
        flash[:notice] = _('Destination_group_was_not_found')
      end
    else
      flash[:notice] = _('Destination_group_error')
    end

    redirect_to(action: :details_by_destinations, id: main_lcr_id)
  end

  def create_destination_lcr_partials
    main_lcr_id = params[:id]
    destination_name = params[:destination_name].to_s

    if destination_name.present?
      dst_lp = LcrPartial.new(
        destination_name: destination_name,
        main_lcr_id: main_lcr_id,
        lcr_id: params[:lcr],
        user_id: corrected_current_user.id
      )

      # Check if there are destinations by given name
      # Also check for duplicate records
      if Destination.where('name LIKE ?',  destination_name).count == 0
        flash[:notice] = _('Destinations_were_not_found')
      elsif dst_lp.duplicate_partials == 0
        dst_lp.save
        flash[:status] = _('Saved')
      else
        flash[:notice] = _('Such_destination_name_already_exists_in_this_LCR')
      end
    else
      flash[:notice] = _('Destination_name_is_empty')
    end

    redirect_to(action: :details_by_destinations, id: main_lcr_id)
  end

  def prefix_finder_find
    @phrase = params[:prefix]
    @dest = Destination.where(["prefix = SUBSTRING(? , 1, LENGTH(destinations.prefix))", @phrase]).
                        order("LENGTH(destinations.prefix) DESC").first if @phrase != ''
    @results = ""
    @direction = nil
    @direction = @dest.direction if @dest
    if @dest and @direction
      @results = @direction.name.to_s + ' ' + @dest.name.to_s
    end
    render(:layout => false)
  end

  def complete_prefix_finder
    return redirect_to :root unless request.xhr?

    @dst = Destination.find_by(prefix: params[:prefix])
    @dir = @dst.try(:direction)
    render layout: false
  end

  def prefix_finder_find_country
    @phrase = params[:prefix]
    @direction = Direction.where(["code= ?", @phrase]).first
    render(:layout => false)
  end

  def lcrpartial_destinations
    lcrp = LcrPartial.where('id = ? AND user_id = ?', params[:lcrp].to_i, corrected_current_user.id).first
    @direction = Direction.where(['id = ?', params[:id].to_i]).first

    if lcrp && @direction
      # Collect lower partials
      lp_str = ''
      lcrp.lower_partials.each do |lp|
        lp_str << " AND prefix NOT LIKE '#{lp.prefix}%'"
      end

      @prefix = params[:prefix].to_s
      @res = Destination.where("prefix LIKE ? #{lp_str}", "#{@prefix}%")
      render(layout: 'layouts/mor_min') && (return true)
    end

    flash[:notice] = @direction ? _('LcrPartial_was_not_found') : _('Direction_was_not_found')
    redirect_to action: :list
  end

  def lcrpartial_destinations_by_name
    destination_name = params[:dest_name].to_s
    @table_title = destination_name
    @res = Destination.where('name LIKE ?', destination_name).order(:prefix).limit(1000)
    render 'lcrpartial_destinations', layout: 'layouts/mor_min'
  end

  def lcrpartial_destinations_by_group
    @table_title = params[:dg_name]
    @direction = Direction.where('code = ?', params[:direction_code].to_s).first
    @res = Destination.where(destinationgroup_id: params[:dg_id]).order(:prefix).limit(1000)
    render 'lcrpartial_destinations', layout: 'layouts/mor_min'
  end

  #in before filter : @lp
  def lcrpartial_edit
    @page_title = _('Edit_lcrpartial')
    @page_icon = 'edit.png'
    @lcrs = corrected_current_user.lcrs.order('name ASC')
    @destinationgroups = Destinationgroup.all.order('name ASC')
    flash[:notice] = flash[:notice] if flash[:notice]
  end

  #in before filter : @lp
  def update_lcrpartial
    prefix = params[:prefix]
    destination_name = params[:destination_name]
    destination_group_id = params[:destination_group_id]
    lp_id = @lp.id

    if prefix && !Destination.where('prefix = ?', prefix.to_s).first
      return redirect_to_lcrpartial_edit(_('Prefix_not_found'), lp_id)
    elsif destination_name && !destination_name.present?
      return redirect_to_lcrpartial_edit(_('Destination_name_is_empty'), lp_id)
    elsif destination_group_id && destinationgroup_id.to_i < 1
      return redirect_to_lcrpartial_edit(_('Destination_group_was_not_found'), lp_id)
    end

    @lp.update_attributes(
      prefix: prefix,
      destination_name: destination_name,
      destination_group_id: destination_group_id,
      main_lcr_id: params[:main_lcr_id],
      lcr_id: params[:lcr_id]
    )

    if @lp.save
      flash[:status] = _('Lcrpartial_saved')
    else
      flash[:notice] = _('Lcrpartial_not_saved')
    end
    redirect_to(action: :lcrpartial_edit, id: lp_id)
  end

  #in before filter : @lp
  def lcrpartial_destroy
    lcr_id = @lp.main_lcr_id
    @lp.destroy
    flash[:status] = _('Destination_deleted')
    redirect_to :action => 'details_by_destinations', :id => lcr_id
  end

  #in before filter : @lcr
  def providers_list
    @page_title = _('Providers_for_LCR') # + ": " + @lcr.name
    @page_icon = "provider.png"

    @providers = @lcr.providers("asc")

    @all_providers = corrected_current_user.providers.includes([:device, :tariff]).order('name ASC')
    if corrected_current_user.usertype == 'reseller'
      @provs = Provider.where("common_use = 1 AND id IN (SELECT provider_id FROM common_use_providers WHERE reseller_id = #{corrected_current_user.id})").order("name ASC")
      if @all_providers
        #ticket 3906
        #@all_providers += Provider.find(:all, :conditions => "common_use = 1", :order => "name ASC")
        @all_providers += @provs
      else
        # @all_providers = Provider.find(:all, :conditions => "common_use = 1", :order => "name ASC")
        @all_providers = @provs
      end
    end
    @other_providers = []
    for prov in @all_providers
      @other_providers << prov if (!@providers.include?(prov) && prov.hidden == 0) || prov == @lcr.failover_provider
    end
    flash[:notice] = _('No_providers_available') if @all_providers.empty?
  end

  #in before filter : @lcr
  def providers_percent
    @page_title = _('Providers_for_LCR') # + ": " + @lcr.name
    @page_icon = "provider.png"

    lcr_id = @lcr.id
    @providers = @lcr.providers('asc')
    sum = 0.to_d
    if params[:pr].to_i == 2
      params.each { |key, value| sum += value.to_d.abs if key.match("prov_") }
      if sum.to_i == 100.to_i
        params.each { |key, value|
          if key.match("prov_")
            @lcrpr = Lcrprovider.where(["provider_id = ? AND lcr_id= ?", key.to_s.strip.delete("prov_").to_i, lcr_id]).first
            if @lcrpr
              @lcrpr.percent = value.to_d.abs * 100
              @lcrpr.save
            end
          end
        }
        flash[:status] = _('Percent_changed')
        redirect_to :action => 'providers_list', :id => lcr_id
      else
        flash[:notice] = _('Is_not_100%')
      end

    end
  end

  # in before filter : @lcr
  def providers_sort
    @page_title = _('Change_Order') + ": " + @lcr.name
    @page_icon = "arrow_switch.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Change_Provider_order_by_Drag%26Drop_video"

    if (@lcr.order.to_s != 'priority')
      dont_be_so_smart
      redirect_to :root
    end

    @items = @lcr.providers("asc")
  end

  #in before filter : @lcr
  def providers_sort_save
    params[:sortable_list].each_index do |i|
      item = Lcrprovider.where(["provider_id = ? AND lcr_id = ?", params[:sortable_list][i], @lcr.id]).first
      unless item
        flash[:notice] = _('Lcrprovider_was_not_found')
        redirect_to :action => :list and return false
      end
      item.priority = i
      item.save
    end
    @page_title = _('Change_Order') + ": " + @lcr.name
    @items = @lcr.providers("asc")
    #    @translations = Translation.find(:all, :order => 'position ASC')
    render :layout => false, :action => :providers_sort
  end

  #in before filter : @lcr
  def try_to_add_provider
    prov_id = params[:select_prov]

    @lcr.no_failover = params[:no_failover].to_i
    if prov_id != '0' && @lcr.no_failover.to_i == 0
      @prov = Provider.where(['id = ? AND (user_id = ? OR common_use = 1)', prov_id, corrected_current_user.id]).first
      unless @prov
        flash[:notice] = _('Provider_was_not_found')
        redirect_to(action: :list) && (return false)
      end
      # @lcr.add_provider(@prov)
      if @lcr.add_provider(@prov)
        @lcr.save
        flash[:status] = _('Provider_added')
      else
        flash_errors_for(_('Provider_was_not_added'), @lcr)
      end
    else
      flash[:notice] = _('Please_select_provider_from_the_list')
    end

    redirect_to(action: :providers_list, id: @lcr)
  end

  def try_to_add_failover_provider
    prov_id = params[:select_prov]
    @prov = Provider.where(['id = ? AND (user_id = ? OR common_use = 1)', prov_id, corrected_current_user.id]).first

    @lcr.no_failover = params[:no_failover].to_i
    if prov_id != "0" and @lcr.no_failover.to_i == 0 and prov_id.to_i != @lcr.failover_provider.try(:id).to_i
      unless @prov
        flash[:notice] = _('Provider_was_not_found')
        redirect_to :action => :list and return false
      end
      flash[:status] = _('Failover_provider_added')
    else
      if @prov.try(:id) != @lcr.failover_provider.try(:id)
        flash[:status] = _('Failover_provider_unassigned')
      else
        flash[:status] = _('Settings_saved')
      end
      @prov = nil if @lcr.no_failover.to_i == 1
    end
    @lcr.failover_provider = @prov
    @lcr.save

    redirect_to :action => 'providers_list', :id => @lcr
  end

  #in before filter : @lcr
  def remove_provider
    prov_id = params[:prov]
    @lcr.remove_provider(prov_id)
    flash[:status] = _('Provider_removed')
    redirect_to :action => 'providers_list', :id => @lcr
  end

  #in before filter : @lcr
  def provider_change_status
    prov_id = params[:prov]
    flash[:status] = @lcr.provider_change_status(prov_id).to_i == 0 ? _('Provider_disabled') : _('Provider_enabled')
    redirect_to :action => 'providers_list', :id => @lcr.id
  end

  def make_tariff

    if !@lcr.providers and @lcr.providers.size.to_i < 1
      flash[:notice] = _('Providers_not_found')
      (redirect_to :root) && (return false)
    end

    options={}
    options[:test] = 1 if params[:test]
    options[:collumn_separator], options[:column_dem] = corrected_current_user.csv_params
    options[:current_user] = corrected_current_user
    options[:curr] = session[:show_currency]
    options[:rand] = random_password(10).to_s
    if options[:test].to_i == 1
      filename, data = @lcr.make_tariff(options)
    else
      filename = @lcr.make_tariff(options)
    end
    filename = load_file_through_database(filename) if Confline.get_value("Load_CSV_From_Remote_Mysql").to_i == 1

    if filename
      filename = archive_file_if_size(filename, "csv", Confline.get_value("CSV_File_size").to_d)
      if params[:test].to_i != 1
        send_data File.open(filename).read, :filename => filename
      else
        render :text => filename.to_s + data
      end
    else
      flash[:notice] = _("Cannot_Download_CSV_File_From_DB_Server")
      (redirect_to :root) && (return false)
    end

  end

  def clone_lcrs
    reseller_a_id = params[:resellerA].to_i
    reseller_b_id = params[:resellerB].to_i
    param_lcr = params[:lcr]
    if admin?
      if reseller_a_id > 0 and reseller_b_id > 0 and param_lcr and param_lcr.size > 0
        resellerA = User.where(["id = ? AND usertype = 'reseller'", reseller_a_id])
        resellerB = User.where(["id = ? AND usertype = 'reseller'", reseller_b_id])
        if not resellerA or not resellerB
          flash[:notice] = _('Specify_both_resellers')
          redirect_to :controller => "lcrs", :action => "clone_options" and return false
        end
        selected_lcrs = param_lcr.map { |key, value| key.to_i }
        selected_lcrs.reject! { |lcr_id| lcr_id == 0 }
        if selected_lcrs.size > 0
          if Lcr.clone_lcrs(resellerA[0], resellerB[0], selected_lcrs)
            flash[:status] = _('Selecte_LCRs_cloned')
          else
            flash[:notice] = _("Failed_to_clone_LCR's")
          end
          redirect_to :controller => "lcrs", :action => "clone_options" and return false

        else
          flash[:notice] = _('Specify_at_least_one_LCR')
          redirect_to :controller => "lcrs", :action => "clone_options" and return false
        end
      else
        flash[:notice] = _('Specify_both_resellers_and_at_least_one_LCR')
        redirect_to :controller => "lcrs", :action => "clone_options" and return false
      end
    else
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
  end

  def clone_options
    @page_title = _('Copy_LCRs')
    @page_icon = 'arrow_switch.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/LCR#Copying_LCRs_between_resellers'

    if admin?
      @resellers = User.where(:usertype => 'reseller', :hidden => 0).all
   else
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
  end

  def clone_resellers_lcrs
    if admin?
      @resellers = User.where(:usertype => 'reseller', :hidden => 0).all
    else
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
  end

  def resellers_lcrs
    if admin?
      reseller_id = params[:id].to_i
      @lcrs = Lcr.where(:user_id => reseller_id).all
      render :layout => false
    else
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
  end

  def resellers_with_common_providers
    if admin?
      reseller_id = params[:id]
      resellerA = User.where(["id = #{reseller_id}"])[0]
      @resellers = resellerA.resellers_with_common_providers
      render layout: false
    else
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
  end

  def lcr_clone
    ln = @lcr.dup
    ln.name = 'Clone: ' + ln.name + ' ' + Time.now.to_s(:db)
    if ln.save
      for provider in @lcr.lcrproviders
        pn = provider.dup
        pn.lcr = ln
        pn.save
      end
      @lpp = LcrPartial.where(['main_lcr_id=?', @lcr.id]).all
      for lcr_partial in @lpp
        lp = lcr_partial.dup
        lp.lcr = lcr_partial.lcr
        lp.main_lcr= ln
        lp.save
      end
      flash[:status] = _('Lcr_copied')
    else
      flash_errors_for(_('Lcr_not_copied'), ln)
    end
    redirect_to :action => 'list' and return false
  end

  def change_position
    @lcr_prov = Lcrprovider.where(id: params[:item_id]).first
    @lcr_prov.move_lcr_prov(params[:direction]) if @lcr_prov
    @items = @lcr.providers('asc')
    render layout: false
  end

  private

  def redirect_to_lcrpartial_edit(notice, lp_id)
    flash[:notice] = notice
    redirect_to(action: :lcrpartial_edit, id: lp_id)
  end

  def check_owner
    if ['reseller', 'admin', 'accountant'].include?(corrected_current_user.usertype) and @lcr.user_id != correct_owner_id
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
  end

  def find_lcr_from_id
    @lcr =Lcr.where(['id=?', params[:id]]).first
    unless @lcr
      flash[:notice] = _('Lcr_was_not_found')
      redirect_to :action => :list and return false
    end
  end

  def find_lcr_partial_from_id
    @lp = LcrPartial.where(['id=? AND user_id =?', params[:id], corrected_current_user.id]).first
    unless @lp
      flash[:notice] = _('LcrPartial_was_not_found')
      redirect_to :action => :list and return false
    end
  end

  def lcr_uses_failover_as_provider?
    lcr_ids = @lcr.providers.map{ |prov| prov.id }.flatten
    if lcr_ids.include?(params[:select_prov].to_i)
      flash[:notice] = _('Failover_Provider_belongs_to_LCR')
      redirect_to :action => :providers_list, :id => @lcr.id and return false
    end
  end

  def acc_manage_lcr_no_permissions
    if session[:acc_manage_lcr].to_i == 0
      flash[:notice] = _('You_have_no_view_permission')
      redirect_to(:root) && (return false)
    end
  end

  def acc_manage_lcr_restrict
    dont_be_so_smart
    (redirect_to :root) && (return false)
  end

  def acc_manage_lcr_read_permission
    if (accountant? && session[:acc_manage_lcr].to_i == 1)
      flash[:notice] = _('You_have_no_view_permission')
      redirect_to(:root) && (return false)
    end
  end
end
