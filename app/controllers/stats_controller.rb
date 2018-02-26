# -*- encoding : utf-8 -*-
# MOR Statistics.
class StatsController < ApplicationController
  include PdfGen
  include SqlExport
  include UniversalHelpers
  require 'uri'
  require 'net/http'
  require 'pdf_gen/prawn'

  layout 'callc'

  before_filter :check_localization
  before_filter :authorize, :except => [:active_calls_longer_error, :active_calls_longer_error_send_email,
                                        :last_calls_stats_totals, :old_calls_stats_totals]
  before_filter :access_denied, only: [
                                        :active_calls_graph, :server_load, :files,
                                        :bulk_management, :bulk_delete, :archived_calls_download,
                                        :archived_calls_delete, :provider_active_calls
                                      ], unless: -> { admin? }
  before_filter :check_if_can_see_finances, :only => [:profit]
  before_filter :check_authentication, :only => [:active_calls, :active_calls_count, :active_calls_show]
  before_filter :load_ok?, :only => [:show_user_stats, :active_calls, :calls_by_scr, :calls_per_day,
    :all_users_detailed, :last_calls_stats, :load_stats, :loss_making_calls, :old_calls_stats, :users_finances, :profit,
    :country_stats, :dids, :dids_usage, :faxes, :first_activity, :hangup_cause_codes_stats, :providers,
    :subscriptions_stats, :system_stats, :action_log, :google_maps]
  before_filter :find_user_from_id_or_session, :only => [:reseller_all_user_stats, :call_list, :index, :user_stats,
    :call_list_to_csv, :call_list_from_link, :new_calls_list, :user_logins, :call_list_to_pdf]
  before_filter :find_provider, :only => [:providers_calls]
  before_filter :check_reseller_in_providers, :only => [:providers, :providers_stats, :country_stats]
  before_filter :check_post_method, only: [:country_stats_download_table_data]
  before_filter :no_cache, :only => [:active_calls]
  before_filter :no_users, :only => [:old_calls_stats]
  before_filter :strip_params, :only => [:last_calls_stats, :old_calls_stats, :active_calls_show,
              :last_calls_stats_totals, :old_calls_stats_totals]
  before_filter :lambda_round_seconds, :only => [:active_calls_graph, :update_active_calls_graph]
  before_filter :check_if_searching, :only => [:last_calls_stats, :old_calls_stats, :user_stats]
  before_filter :number_separator, :only => [:server_load]
  skip_before_filter :redirect_callshop_manager, :only => [:prefix_finder_find, :prefix_finder_find_country, :rate_finder_find]
  before_filter :is_devices_for_scope_present, :only => [:last_calls_stats, :old_calls_stats]
  before_filter :acc_manage_provider, only: [:providers, :providers_stats], if: -> { accountant? }
  before_action :authorize_action_log, only: [:action_log, :action_log_mark_reviewed, :action_processed]

  before_filter { |method|
    method.instance_variable_set :@allow_read, true
    method.instance_variable_set :@allow_edit, true
  }

  before_filter(:only => [:subscriptions_stats]) { |method|
    allow_read, allow_edit = method.check_read_write_permission( [:subscriptions_stats], [], {:role => "accountant", :right => :acc_manage_subscriptions_opt_1})
    method.instance_variable_set :@allow_read, allow_read
    method.instance_variable_set :@allow_edit, allow_edit
    true
  }

  before_filter(only: [:dids, :dids_usage]) { |method|
    allow_read, allow_edit = method.check_read_write_permission([:dids, :dids_usage], [],
      { role: 'accountant', right: :acc_manage_dids_opt_1, ignore: true })
    method.instance_variable_set :@dids_allow_read, allow_read
    method.instance_variable_set :@dids_allow_edit, allow_edit
    true
  }

  def index
    redirect_to :action => :user_stats and return false
  end

  def prepare_data_for_es_user_stats
    options = {}
    assigned_users =
    acc_show_assigned_users = if current_user.show_only_assigned_users == 1
                                  "AND users.responsible_accountant_id = #{current_user_id}"
                                else
                                  ''
                                end
    options[:gte] = es_limit_search_by_days
    options[:lte] = es_session_till
    options[:exrate] = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])

    %w[users partners resellers].each do |usertype|
      options[usertype.to_sym] = "users.hidden = 0 AND users.owner_id = #{corrected_user_id} AND users.id >= 0 AND usertype = '#{usertype.chop!}' #{acc_show_assigned_users}"
    end

    options[:current_user] = @current_user

    options
  end

  def show_user_stats
    @page_title = _('Calls')
    @page_icon = 'call.png'
    @show_currency_selector = 1
    @help_link = 'http://wiki.kolmisoft.com/index.php/Users_Calls'
    change_date
    change_date_to_present if params[:clear]

    @data = EsCallsByUser.get_data(prepare_data_for_es_user_stats)
  end

  def all_users_detailed
    @page_title = _('All_users_detailed')
    @users = User.where("hidden = 0") # , :conditions => "usertype = 'user'") #, :limit => 6)
    @help_link = "http://wiki.kolmisoft.com/index.php/Integrity_Check"
    @searching = params[:search_on].to_i == 1
    change_date

    if @searching
      @call_stats = Call.es_total_calls_by(es_session_from, es_session_till)

      if @call_stats.blank?
        return false
        @searching = 0
      end

      attributes_for_graphs
    end
  end

# In before filter : user (:find_user_from_id_or_session, :authorize_user)
  def reseller_all_user_stats
    unless session[:usertype] == 'reseller'
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    @page_title = _('Detailed_stats_for')+" "+@user.first_name+" "+@user.last_name
    change_date

    users = User.find_all_for_select(corrected_user_id, {:exclude_owner => true})
    users << @user
    user_ids = users.map(&:id)

    @call_stats = Call.es_total_calls_by(es_session_from, es_session_till, user_ids)
    attributes_for_graphs(user_ids)
  end

# In before filter : user (:find_user_from_id_or_session, :authorize_user)
  def user_stats
    change_date

    @page_title = "#{_('Detailed_stats_for')} #{nice_user(@user)}"

    session[:hour_from] = "00"
    session[:minute_from] = "00"
    session[:hour_till] = "23"
    session[:minute_till] = "59"

    if @searching
      @hide_non_answered_calls_for_user = (@user.usertype == 'user' and
                                           @user.hide_non_answered_calls.to_i == 1)
      @todays_normative = @user.normative_perc(Time.now)
      @months_normative = @user.months_normative(Time.now.strftime("%Y-%m"))
      @new_calls_today = @user.new_calls(Time.now.strftime("%Y-%m-%d")).size

      user_perspective = current_user.is_user? && current_user.stats_from_user_perspective == 1
      @call_stats = Call.es_total_calls_by(es_session_from, es_session_till, [@user.id], user_perspective)
      if @call_stats.blank?
        return false
        @searching = 0
      end
      attributes_for_graphs([@user.id])
    end
  end

# In before filter : user (:find_user_from_id_or_session, :authorize_user)
  def user_logins
    change_date
    @Login_graph = []

    @page = 1
    @page = params[:page].to_i if params[:page]
    @page_title = _('Login_stats_for') + nice_user(@user)

    date_start = Time.mktime(session[:year_from], session[:month_from], session[:day_from])
    date_end = Time.mktime(session[:year_till], session[:month_till], session[:day_till])

    @MyDay = Struct.new("MyDay", :date, :login, :logout, :duration)
    @a = [] # day
    @b = [] # login
    @c = [] # logout
    @d = [] # duration

    # making date array
    date_end = Time.now if date_end > Time.now
    if date_start == date_end
      @a << date_start
    else
      date = date_start
      while date < (date_end + 1.day)
        @a << date
        date = date+1.day
      end
    end


    @total_pages = ((@a.size).to_d / 10.to_d).ceil
    @all_date =@a
    @a = []
    iend = ((10 * @page) - 1)
    iend = @all_date.size - 1 if iend > (@all_date.size - 1)
    for i in ((@page - 1) * 10)..iend
      @a << @all_date[i]
    end
    @page_select_header_id = @user.id


    # make state lists for every date
    graph_number = 0

    user_id = @user.id

    @a.each do |date|
      bb = [] # login date
      cc = [] # logout date
      dd = [] # duration

      date_str = date.strftime("%Y-%m-%d")
      # let's find starting action for the day
      start_action = Action.where(["user_id = ? AND SUBSTRING(date,1,10) < ?", user_id, date_str]).order("date DESC").first
      other_actions = Action.where(["user_id = ? AND SUBSTRING(date,1,10) = ?", user_id, date_str]).order("date ASC")

      # form array for actions
      actions = []
      actions << start_action if start_action
      for oa in other_actions
        actions << oa
      end

      # compress array removing spare logins/logouts
      pa = 0 # previous action to compare
      # if actions.size > 0
      for i in 1..actions.size-1
        if actions[i].action == actions[pa].action # and actions[i] != actions.last
          actions[i] = nil
        else
          pa = i
        end
        i+=1
      end
      actions.compact!
      # build array from data
      if actions.size > 0 # fix if we do not have data
        if actions.size == 1
          # all day same state
          date_next_day = date + 1.day

          if actions[0].action == "login"
            bb << date
            cc << date_next_day - 1.second
            dd << date_next_day - date

          end

        else
          # we have some state change during day
          i = 1
          i = 0 if actions[0].action == "login"

          (actions.size/2).times do

            # login
            if actions[i].date.day == date.day
              lin = actions[i].date
            else
              lin = date
            end

            # logout
            if actions[i+1] # we have logout
              lout = actions[i+1].date
            else # no logout, login end - end of day
              lout = date+1.day-1.second
            end

            bb << lin
            cc << lout
            dd << lout - lin

            i+=2
          end
        end

      end

      @b << bb
      @c << cc
      @d << dd

      hours = Hash.new

      i = 0
      12.times do
        hours[(i*8)] = (i*2).to_s
        i+=1
      end

      # hours = {0 => "0", 2=>"2", 4=>"4", 6=>"6", 8=>"8", 10=>"10",12=>"12",  14=>"14", 16=>"16", 18=>"18", 20=>"20", 22=>"22" }

      # format data array
      # for i in 0..95

      array = []
      96.times do
        array << 0
      end


      (0..bb.size - 1).each do |index|
        x_axis = (bb[index].hour * 60 + bb[index].min) / 15
        y_axis = (cc[index].hour * 60 + cc[index].min) / 15
        for iindex in x_axis..y_axis
          array[iindex] = 1
        end
        #        my_debug x_axis
        #        my_debug y_axis
      end

      # formating graph for Log States whit flash
      @Login_graph[graph_number] = ""
      rr = 0
      while rr <= 96
        db= rr % 8
        as= rr/4
        if db ==0
          @Login_graph[graph_number] += as.to_s + ";" + array[rr].to_s + "\\n"
        end
        rr=rr+1
      end

      graph_number += 1
    end

    @days = @MyDay.new(@a, @b, @c, @d)
  end


  def new_calls
    change_date
    @page_title = _('New_calls')
    @page_icon = "call.png"
    @users = User.where("hidden = 0")
  end


# in before filter : user (:find_user_from_id_or_session, :authorize_user)
  def new_calls_list
    @page_title = "#{_('New_calls')}: #{nice_user(@user)} - #{session_from_date}"
    @calls = @user.new_calls(session_from_date)

    @select_date = false
    render :new_call_list
  end

# in before filter : user (:find_user_from_id_or_session, :authorize_user)
  def call_list_from_link

    @date_from = params[:date_from]
    @date_till = params[:date_till].to_s != 'time_now' ? params[:date_till] : Time.now.strftime("%Y-%m-%d %H:%M:%S")

    @call_type = "all"
    @call_type = params[:call_type] if params[:call_type]

    page_titles = {
      'all' => _('all_calls'),
      'answered' => _('answered_calls'),
      'answered_inc' => _('incoming_calls'),
      'missed' => _('missed_calls')
    }

    @page_title = "#{page_titles[@call_type]}: #{nice_user(@user)}"

    @calls = @user.calls(@call_type, @date_from, @date_till)

    @total_duration = 0
    @total_price = 0
    @total_billsec = 0

    @curr_rate= {}
    @curr_rate2= {}
    exrate = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])

    @calls.each do |call|
      call_id = call.id
      @total_duration += call.duration
      if @direction == "incoming"
        call_did_price = call.did_price
        @rate_cur = Currency.count_exchange_prices({:exrate => exrate, :prices => [call_did_price.to_d]}) if call_did_price
        @total_price += @rate_cur if call_did_price
        @curr_rate2[call_id]=@rate_cur
        @total_billsec += call.did_billsec
      else
        call_user_price = call.user_price
        @rate_cur = Currency.count_exchange_prices({:exrate => exrate, :prices => [call_user_price.to_d]}) if call_user_price
        @total_price += @rate_cur if call_user_price
        @curr_rate[call_id]=@rate_cur
        @total_billsec += call.nice_billsec
      end
   end

    @show_destination = params[:show_dst]
    redirect_to :controller => "stats", :action => "call_list", :id => @user.id, :call_type => @call_type, :date_from_link => @date_from, :date_till_link => @date_till, :direction => "outgoing" #and return false
  end

  # in before filter : user (:find_user_from_id_or_session)
  def last_calls_stats
    @page_title = _('Last_calls')
    @page_icon = 'call.png'
    @show_currency_selector = 1
    @help_link = 'http://wiki.kolmisoft.com/index.php/Last_Calls'
    change_date
    search_from = limit_search_by_days

    if user?
      unless (@user = current_user)
        dont_be_so_smart
        (redirect_to :root) && (return false)
      end

      @hide_non_answered_calls_for_user = (@user.hide_non_answered_calls.to_i == 1)
    end

    @options = last_calls_stats_parse_params(false, @hide_non_answered_calls_for_user ? true : false)

    time = current_user.user_time(Time.now)
    year, month, day = time.year.to_s, time.month.to_s, time.day.to_s
    from = session_from_datetime_array != [year, month, day, "0", "0", "00"]
    till = session_till_datetime_array != [year, month, day, "23", "59", "59"]

    if from or till
      @options[:search_on] = 1
    end

    if user?
      @devices, @device = last_calls_stats_user(@user, @options)
    end

    if reseller?
      @user, @devices, @device, @hgcs, @hgc, @providers, @provider, @did, @did_provider = last_calls_stats_reseller(@options)
    end

    if ["admin", "accountant"].include?(session[:usertype])
      @user, @devices, @device, @hgcs, @hgc, @did, @providers, @provider, @reseller, @resellers, @resellers_with_dids, @did_provider = last_calls_stats_admin(@options)
    end

    if partner?
      @user, @devices, @device, @hgcs, @hgc, @did, @providers, @provider, @reseller, @resellers, @resellers_with_dids, @did_provider = current_user.last_calls_stats_partner(@options)
    end

    session[:last_calls_stats] = @options
    s_card_number = params[:s_card_number].to_s
    s_card_pin = params[:s_card_pin].to_s
    options = last_calls_stats_set_variables(@options, {
      user: @user,
      device: @device,
      hgc: @hgc,
      did: @did,
      current_user: current_user,
      provider: @provider,
      can_see_finances: can_see_finances?,
      reseller: @reseller,
      did_provider: @did_provider,
      s_card_number: !!s_card_number.match(/^[0-9%]+$/) ? s_card_number : '',
      s_card_pin: !!s_card_pin.match(/^[0-9%]+$/) ? s_card_pin : '',
    })
    options[:user_perspective] = @current_user.is_user? && @current_user.stats_from_user_perspective == 1
    type = 'html'
    type = 'csv' if params[:csv].to_i == 1
    type = 'pdf' if params[:pdf].to_i == 1

    case type
      when 'html'
        manage_totals_cache(:last_calls_totals_admin)
        if @searching && @options[:s_user_id].present?
          options[:from] = es_limit_search_by_days
          options[:till] = es_session_till
          options[:usertype] = @current_user.try(:usertype)

          if @total_calls_stats.blank?
            @total_calls_stats = EsLastCallsTotals.get_data(options)
            @total_calls = @total_calls_stats[:total_calls]
          else
            @total_calls = Call.last_calls_total_count(options)
          end

          @calls = Call.last_calls(options)
        else
          @total_calls = 0
          @calls = []
        end
        @total_pages = (@total_calls / session[:items_per_page].to_d).ceil
        options[:page] = @total_pages if options[:page].to_i > @total_pages.to_i
        options[:page] = 1 if options[:page].to_i < 1
        @show_destination = 1
        session[:last_calls_stats] = @options
      # @calls = [@calls[1]]
      when 'pdf'
        options[:column_dem] = '.'
        options[:current_user] = current_user
        options[:from] = es_limit_search_by_days
        options[:till] = es_session_till
        options[:usertype] = @current_user.try(:usertype)
        calls, test_data = Call.last_calls_csv(options.merge({pdf: 1}))
        total_calls = EsLastCallsTotals.get_data(options)
        pdf = PdfGen::Generate.generate_last_calls_pdf(calls, total_calls, current_user,
                                                      { direction: '', date_from: session_from_datetime,
                                                        date_till: session_till_datetime,
                                                        show_currency: session[:show_currency],
                                                        rs_active: reseller_active?,
                                                        can_see_finances: can_see_finances? })
        @show_destination = 1
        session[:last_calls_stats] = @options

        if params[:test].to_i == 1
          render :text => "OK"
        elsif (@user == nil) or (Confline.get_value("Show_Usernames_On_Pdf_Csv_Export_Files_In_Last_Calls").to_i == 0)
          cookies['fileDownload'] = 'true'
          send_data pdf.render, :filename => "Calls_#{session_from_datetime}-#{session_till_datetime}.pdf", :type => "application/pdf"
        else
          cookies['fileDownload'] = 'true'
          send_data pdf.render, :filename => "#{nice_user(@user).gsub(' ', '_')}_Calls_#{session_from_datetime}-#{session_till_datetime}.pdf", :type => "application/pdf"
        end
      when 'csv'
        options[:test] = 1 if params[:test]
        options[:collumn_separator], options[:column_dem] = current_user.csv_params
        options[:current_user] = current_user
        options[:show_full_src] = session[:show_full_src]
        options[:csv] = true
        options[:cdr_template_id] = params[:cdr_template_id] if params[:cdr_template_id].present?

        if options[:cdr_template_id].present?
          partner? ? Call.last_calls_csv_partner(options) : Call.last_calls_csv(options)
          return false
        else
          if partner?
            filename, test_data = Call.last_calls_csv_partner(options)
            filename = load_file_through_database(filename) if Confline.get_value('Load_CSV_From_Remote_Mysql').to_i == 1
          else
            filename, test_data = Call.last_calls_csv(options)
          end
        end

        if filename
          filename = archive_file_if_size(filename, "csv", Confline.get_value("CSV_File_size").to_d)
          if (params[:test].to_i == 1) and (@user != nil) and (Confline.get_value("Show_Usernames_On_Pdf_Csv_Export_Files_In_Last_Calls").to_i != 0)
            render :text => ("#{nice_user(@user).gsub(' ', '_')}_" <<  filename) + test_data.to_s
          elsif params[:test].to_i == 1
            render :text => filename + test_data.to_s
          elsif (@user == nil) or (Confline.get_value("Show_Usernames_On_Pdf_Csv_Export_Files_In_Last_Calls").to_i == 0)
            file = File.open(filename) if File.exist?(filename)
            cookies['fileDownload'] = 'true'
            send_data file.read, :filename => filename if file
          else
            file = File.open(filename)
            cookies['fileDownload'] = 'true'
            send_data file.read, :filename => "#{nice_user(@user).gsub(' ', '_')}_" << filename
          end
        else
          flash[:notice] = _("Cannot_Download_CSV_File_From_DB_Server")
          (redirect_to :root) && (return false)
        end
    end

    if !params[:commit].nil?
      @options[:page] = 1
    end
  end

  def last_calls_stats_totals
    search_from = limit_search_by_days
    @user = current_user

    @hide_non_answered_calls_for_user = (user? && @user.hide_non_answered_calls.to_i == 1 )

    @options = last_calls_stats_parse_params(false, @hide_non_answered_calls_for_user)

    time = current_user.user_time(Time.now)
    year, month, day = time.year.to_s, time.month.to_s, time.day.to_s
    from = session_from_datetime_array != [year, month, day, "0", "0", "00"]
    till = session_till_datetime_array != [year, month, day, "23", "59", "59"]

    if from or till
      @options[:search_on] = 1
    end

    if user?
      @devices, @device = last_calls_stats_user(@user, @options)
    end

    if reseller?
      @user, @devices, @device, @hgcs, @hgc, @providers, @provider, @did, @did_provider = last_calls_stats_reseller(@options)
    end

    if ["admin", "accountant"].include?(session[:usertype])
      @user, @devices, @device, @hgcs, @hgc, @did, @providers, @provider, @reseller, @resellers, @resellers_with_dids, @did_provider = last_calls_stats_admin(@options)
    end

    if partner?
      @user, @devices, @device, @hgcs, @hgc, @did, @providers, @provider, @reseller, @resellers, @resellers_with_dids, @did_provider = current_user.last_calls_stats_partner(@options)
    end

    options = last_calls_stats_set_variables(@options, {
        user: @user,
        device: @device,
        hgc: @hgc,
        did: @did,
        current_user: current_user,
        provider: @provider,
        can_see_finances: can_see_finances?,
        reseller: @reseller,
        did_provider: @did_provider,
        from: es_session_from,
        till: es_session_till,
        usertype: @current_user.try(:usertype)
    })

    if @options[:s_user_id].present?
      @total_calls_stats = EsLastCallsTotals.get_data(options)
    else
      @total_calls_stats = []
    end

    session[:last_calls_totals] = @total_calls_stats

    respond_to do |format|
      format.html {
        render(partial: params[:total_line],
               locals: Hash[self.instance_variables.collect{|var| [var.to_s.sub('@', '').downcase.to_sym, eval(var.to_s)]}],
               layout: false)
      }
    end
  end

  def files
    @page_title = _('Files')
    @page_icon  = 'call.png'
    @help_link  = "http://wiki.kolmisoft.com/index.php/Archived_Calls_in_Files"

    raw_array = get_archived_calls.delete_if { |filename|
      begin
        DateTime.strptime(filename.slice(24..39), '%Y%b%d-%H%M%S')
        false
      rescue
        true
      end
    }
    files_array = raw_array.sort_by { |filename| DateTime.strptime(filename.slice(24..39), '%Y%b%d-%H%M%S') }.reverse
    @options = {order_desc: 1, order_by: "file_name"}
    order_desc = params[:order_desc]
    if order_desc.present? && order_desc.to_i == 0
        files_array.reverse!
        @options[:order_desc] = 0
    end
    @page = params[:page] ? params[:page].to_i : 1
    @total_pages = (files_array.count.to_f / session[:items_per_page].to_f).ceil
    record_offset = (@page - 1) * session[:items_per_page].to_i
    @files = files_array[record_offset.to_i, session[:items_per_page].to_i]
  end

  def bulk_management
    @page_title = _('Bulk_management')
    @page_icon = 'music.png'

    @find_backup_size = -1
    count = 0
    @delete_file = []
    if params[:date_from].present?
      change_date
      @files = get_archived_calls
      date_from_params = (params[:date_from][:year].to_s + '-' + params[:date_from][:month].to_s + '-' + params[:date_from][:day].to_s + ' ' + params[:date_from][:hour].to_s + ':' + params[:date_from][:minute].to_s + ':00').to_datetime
      date_till_params = (params[:date_till][:year].to_s + '-' + params[:date_till][:month].to_s + '-' + params[:date_till][:day].to_s + ' ' + params[:date_till][:hour].to_s + ':' + params[:date_till][:minute].to_s + ':59').to_datetime
      @files.each { |file|

        date_from_index = file.index('from_')
        date_till_index = file.index('to_')
        begin
          date_from = DateTime.strptime(file.slice(date_from_index+5..date_from_index+20), '%Y%b%d-%H%M%S')
          date_till = DateTime.strptime(file.slice(date_till_index+3..date_till_index+18), '%Y%b%d-%H%M%S')
        rescue
          flash[:notice] = _('Archived_calls_files_missing')
          (redirect_to action: :bulk_management) && (return false)
        end
          if (date_from_params <= date_from) && (date_till_params >= date_till)
            count += 1
            @delete_file << file
          end
      }
      if flash[:notice] != _('Date_from_greater_thant_date_till')
        @find_backup_size = count
      else
        (redirect_to action: :bulk_management) && (return false)
        flash[:notice] = nil
      end
    end
  end

  def bulk_delete
    path = backup_path
    params[:array].each { |file|
      if File.exist?("#{path}/#{file}")
        File.delete("#{path}/#{file}")
      else
        flash[:notice] = _('Archived_calls_files_missing')
        (redirect_to action: :files) && (return false)
      end
    }
    flash[:status] = _('Archived_calls_files_deleted')
    redirect_to action: :files
  end

  def archived_calls_download
    path = backup_path
    filename = params[:name]
    full_filename = path + '/' + filename
    begin
      send_file full_filename, filename: filename, x_sendfile: true, stream: true
    rescue
      flash[:notice] = _('Archived_calls_file_missing')
      (redirect_to action: :files) && (return false)
    end
  end

  def archived_calls_delete
    path = backup_path
    full_filename = path + '/' + params[:name]
    if File.exist?(full_filename)
      File.delete(full_filename)
    else
      flash[:notice] = _('Archived_calls_file_missing')
      (redirect_to action: :files) && (return false)
    end
    flash[:status] = _('Archived_calls_file_deleted')
    redirect_to action: :files
  end

  def old_calls_stats
    @page_title = _('Old_Calls')
    @page_icon  = 'call.png'
    @help_link  = "http://wiki.kolmisoft.com/index.php/Old_calls"

    change_date

    @show_currency_selector = 1
    @options = last_calls_stats_parse_params(true)

    time = current_user.user_time(Time.now)
    year_s = time.year.to_s
    month_s = time.month.to_s
    day_s = time.day.to_s
    from = session_from_datetime_array != [year_s, month_s, day_s, '0', '0', '00']
    till = session_till_datetime_array != [year_s, month_s, day_s, '23', '59', '59']

    if from or till
      @options[:search_on] = 1
    end

    if user?
      unless (@user = current_user)
        dont_be_so_smart
        (redirect_to :root) && (return false)
      end
      @devices, @device = last_calls_stats_user(@user, @options)
    end

    if reseller?
      @user, @devices, @device, @hgcs, @hgc, @providers, @provider, @did, @did_provider = last_calls_stats_reseller(@options)
    end

    if ["admin", "accountant"].include?(session[:usertype])
      @user, @devices, @device, @hgcs, @hgc, @did, @providers, @provider, @reseller, @resellers, @resellers_with_dids, @did_provider = last_calls_stats_admin(@options)
    end

    if partner?
      @user, @devices, @device, @hgcs, @hgc, @did, @providers, @provider, @reseller, @resellers, @resellers_with_dids, @did_provider = current_user.last_calls_stats_partner(@options)
    end

    session[:last_calls_stats] = @options
    options = last_calls_stats_set_variables(@options, {
      user: @user,
      device: @device,
      hgc: @hgc,
      did: @did,
      current_user: current_user,
      provider: @provider,
      can_see_finances: can_see_finances?,
      reseller: @reseller,
      did_provider: @did_provider
    })

    type = 'html'
    type = 'csv' if params[:csv].to_i == 1
    # type = 'pdf' if params[:pdf].to_i == 1

    case type
      when 'html'
        manage_totals_cache(:old_calls_totals)
        if @searching && @options[:s_user_id].present?
          @total_calls = OldCall.last_calls_total_count(options)
          if @total_calls_stats.blank?
            @total_calls_stats = OldCall.last_calls_total_stats(options)
          end

          logger.debug " >> Total calls: #{@total_calls}"
          @calls = @total_calls.to_i > 0 ? OldCall.last_calls(options) : []
        else
          @total_calls = 0
          @calls = []
        end
        @total_pages = (@total_calls/ session[:items_per_page].to_d).ceil
        options[:page] = @total_pages if options[:page].to_i > @total_pages.to_i
        options[:page] = 1 if options[:page].to_i < 1
        @show_destination = 1
        session[:last_calls_stats] = @options
      # @calls = [@calls[1]]
      # when 'pdf'
      #   options[:column_dem] = '.'
      #   options[:current_user] = current_user
      #   calls, test_data = OldCall.last_calls_csv(options.merge({:pdf => 1}))
      #   total_calls = OldCall.last_calls_total_stats(options)
      #   pdf = PdfGen::Generate.generate_last_calls_pdf(calls, total_calls, current_user, {:direction => '', :date_from => session_from_datetime, :date_till => session_till_datetime, :show_currency => session[:show_currency], :rs_active => reseller_active?, :can_see_finances => can_see_finances?})
      #   logger.debug("  >> Calls #{calls.size}")
      #   @show_destination = 1
      #   session[:last_calls_stats] = @options
      #   if params[:test].to_i == 1
      #     render :text => "OK"
      #   else
      #     send_data pdf.render, :filename => "Calls_#{session_from_datetime}-#{session_till_datetime}.pdf", :type => "application/pdf"
      #   end
      when 'csv'
        options[:test] = 1 if params[:test]
        options[:collumn_separator], options[:column_dem] = current_user.csv_params
        options[:current_user]  = current_user
        options[:show_full_src] = session[:show_full_src]
        options[:csv] = true
        if partner?
          filename, test_data = OldCall.last_calls_csv_partner(options)
        else
          filename, test_data = OldCall.last_calls_csv(options)
        end
        filename = load_file_through_database(filename) if Confline.get_value("Load_CSV_From_Remote_Mysql").to_i == 1
        if filename
          filename = archive_file_if_size(filename, "csv", Confline.get_value("CSV_File_size").to_d)
          if (params[:test].to_i == 1) and (@user != nil) and (Confline.get_value("Show_Usernames_On_Pdf_Csv_Export_Files_In_Last_Calls").to_i != 0)
            render :text => ("#{nice_user(@user).gsub(' ', '_')}_" <<  filename) + test_data.to_s
          elsif params[:test].to_i == 1
            render :text => filename + test_data.to_s
          elsif (@user == nil) or (Confline.get_value("Show_Usernames_On_Pdf_Csv_Export_Files_In_Last_Calls").to_i == 0)
            file = File.open(filename) if File.exist?(filename)
            send_data file.read, :filename => filename if file
          else
            file = File.open(filename)
            send_data file.read, :filename => "#{nice_user(@user).gsub(' ', '_')}_" << filename
          end
        else
          flash[:notice] = _("Cannot_Download_CSV_File_From_DB_Server")
          (redirect_to :root) && (return false)
        end
    end

    if !params[:commit].nil?
      @options[:page] = 1
    end
  end

  def old_calls_stats_totals
    search_from = limit_search_by_days
    @user = current_user

    @hide_non_answered_calls_for_user = (user? && @user.hide_non_answered_calls.to_i == 1 )

    @options = last_calls_stats_parse_params(true)

    time = current_user.user_time(Time.now)
    year, month, day = time.year.to_s, time.month.to_s, time.day.to_s
    from = session_from_datetime_array != [year, month, day, "0", "0", "00"]
    till = session_till_datetime_array != [year, month, day, "23", "59", "59"]

    if from or till
      @options[:search_on] = 1
    end

    if user?
      @devices, @device = last_calls_stats_user(@user, @options)
    end

    if reseller?
      @user, @devices, @device, @hgcs, @hgc, @providers, @provider, @did, @did_provider = last_calls_stats_reseller(@options)
    end

    if ["admin", "accountant"].include?(session[:usertype])
      @user, @devices, @device, @hgcs, @hgc, @did, @providers, @provider, @reseller, @resellers, @resellers_with_dids, @did_provider = last_calls_stats_admin(@options)
    end

    if partner?
      @user, @devices, @device, @hgcs, @hgc, @did, @providers, @provider, @reseller, @resellers, @resellers_with_dids, @did_provider = current_user.last_calls_stats_partner(@options)
    end

    options = last_calls_stats_set_variables(@options, {
        user: @user,
        device: @device,
        hgc: @hgc,
        did: @did,
        current_user: current_user,
        provider: @provider,
        can_see_finances: can_see_finances?,
        reseller: @reseller,
        did_provider: @did_provider
    })

    if @options[:s_user_id].present?
      @total_calls_stats = OldCall.last_calls_total_stats(options)
    else
      @total_calls_stats = []
    end

    session[:old_calls_totals] = @total_calls_stats

    respond_to do |format|
      format.html {
        render(partial: params[:total_line],
               locals: Hash[self.instance_variables.collect{|var| [var.to_s.sub('@', '').downcase.to_sym, eval(var.to_s)]}],
               layout: false)
      }
    end
  end

  def call_list
    dont_be_so_smart
    (redirect_to :root) && (return false)
  end

  def country_stats
    @page_title = _('Country_Stats')
    @page_icon = 'world.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Country_Stats'

    change_date
    country_stats_parse_params

    @data = EsCountryStats.get_data(
        s_user_id: params[:s_user_id], current_user: current_user,
        from: es_limit_search_by_days, till: es_session_till
    )

    session[:country_stats] = @options
  end

  def country_stats_download_table_data
    filename = Call.country_stats_download_table_csv(params, current_user)
    filename = archive_file_if_size(filename, 'csv', Confline.get_value('CSV_File_size').to_d)

    cookies['fileDownload'] = 'true'
    send_data(File.open(filename).read, filename: filename.sub('/tmp/', ''))
  end

  ############ CSV ###############

  def last_calls_stats_admin
    redirect_to :action => "last_calls_stats"
  end


# in before filter : user (:find_user_from_id_or_session, :authorize_user)
  def call_list_to_csv
    @direction = "outgoing"
    @direction = params[:direction] if params[:direction]

    @sel_device_id = 0
    @sel_device_id = params[:device].to_i if params[:device]

    @device = Device.where(["id = ?", @sel_device_id]).first if @sel_device_id > 0

    @hgcs = Hangupcausecode.all
    @sel_hgc_id = 0
    @sel_hgc_id = params[:hgc].to_i if params[:hgc]

    @hgc = Hangupcausecode.where(:id => @sel_hgc_id).first if @sel_hgc_id > 0

    if session[:usertype].to_s != 'admin' and params[:reseller]
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
    res = session[:usertype] == 'admin' ? params[:reseller].to_i : 0

    date_from = params[:date_from] ? params[:date_from] : session_from_datetime
    date_till = params[:date_till] ? params[:date_till] : session_till_datetime
    call_type = params[:call_type] ? params[:call_type].to_s : 'answered'

    session[:usertype] == "accountant" ? user_type = "admin" : user_type = session[:usertype]
    filename, test_data = @user.user_calls_to_csv({:tz => current_user.time_offset, :device => @device, :direction => @direction, :call_type => call_type, :date_from => date_from, :date_till => date_till, :default_currency => session[:default_currency], :show_currency => session[:show_currency], :show_full_src => session[:show_full_src], :hgc => @hgc, :usertype => user_type, :nice_number_digits => session[:nice_number_digits], :test => params[:test].to_i, :reseller => res.to_i, :hide_finances => !can_see_finances?})
    filename = load_file_through_database(filename) if Confline.get_value("Load_CSV_From_Remote_Mysql").to_i == 1
    if filename
      filename = archive_file_if_size(filename, "csv", Confline.get_value("CSV_File_size").to_d)
      if params[:test].to_i != 1
        send_data(File.open(filename).read, :filename => filename)
      else
        render :text => filename + test_data.to_s
      end
    else
      flash[:notice] = _("Cannot_Download_CSV_File_From_DB_Server")
      (redirect_to :root) && (return false)
    end
  end

  ############ PDF ###############

=begin
in before filter : user (:find_user_from_id_or_session, :authorize_user)
=end
  def call_list_to_pdf
    @direction = "outgoing"
    @direction = params[:direction] if params[:direction]

    @sel_device_id = 0
    @sel_device_id = params[:device].to_i if params[:device]

    @device = Device.find(@sel_device_id) if @sel_device_id > 0


    @hgcs = Hangupcausecode.all
    @sel_hgc_id = 0
    @sel_hgc_id = params[:hgc].to_i if params[:hgc]

    @hgc = Hangupcausecode.where(:id => @sel_hgc_id).first if @sel_hgc_id > 0

    date_from = params[:date_from]
    date_till = params[:date_till]
    call_type = params[:call_type]
    user = @user

    calls = user.calls(call_type, date_from, date_till, @direction, "calldate", "DESC", @device, {:hgc => @hgc})


    ###### Generate PDF ########
    pdf = Prawn::Document.new(:size => 'A4', :layout => :portrait)
    pdf.font("#{Prawn::BASEDIR}/data/fonts/DejaVuSans.ttf")

    pdf.text("#{_('CDR_Records')}: #{user.first_name} #{user.last_name}", {:left => 40, :size => 16})
    pdf.text(_('Period') + ": " + date_from + "  -  " + date_till, {:left => 40, :size => 10})
    pdf.text(_('Currency') + ": #{session[:show_currency]}", {:left => 40, :size => 8})
    pdf.text(_('Total_calls') + ": #{calls.size}", {:left => 40, :size => 8})

    total_price = 0
    total_billsec = 0
    total_prov_price = 0
    total_prfit = 0
    total_did_provider = 0
    total_did_inc = 0
    total_did_own = 0
    total_did_prof = 0


    exrate = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])

    items = []
    calls.each do |call|
      item = []
      @rate_cur3 = Currency.count_exchange_prices({:exrate => exrate, :prices => [call.user_price.to_d]})
      @rate_prov = Currency.count_exchange_prices({:exrate => exrate, :prices => [call.provider_price.to_d]}) if session[:usertype] == "admin"
      if session[:usertype] == "reseller"
        if call.reseller_id == 0
          # selfcost for reseller himself is user price, so profit always = 0 for his own calls
          @rate_prov = Currency.count_exchange_prices({:exrate => exrate, :prices => [call.user_price.to_d]})
        else
          @rate_prov = Currency.count_exchange_prices({:exrate => exrate, :prices => [call.reseller_price.to_d]})
        end
      end

      @rate_did_pr = Currency.count_exchange_prices({:exrate => exrate, :prices => [call.did_prov_price.to_d]})
      @rate_did_ic = Currency.count_exchange_prices({:exrate => exrate, :prices => [call.did_inc_price.to_d]})
      @rate_did_ow = Currency.count_exchange_prices({:exrate => exrate, :prices => [call.did_price.to_d]})

      item << call.calldate.strftime("%Y-%m-%d %H:%M:%S")
      item << call.src
      item << hide_dst_for_user(current_user, "pdf", call.dst.to_s)

      if @direction == "incoming"
        billsec = call.did_billsec
      else
        billsec = call.nice_user_billsec
      end

      item << nice_time(billsec)
      item << call.disposition

      if session[:usertype] == "admin"
        if @direction == "incoming"
          item << nice_number(@rate_did_pr)
          item << nice_number(@rate_did_ic)
          item << nice_number(@rate_did_ow)
          item << nice_number(@rate_did_pr + @rate_did_ic + @rate_did_ow)
          item << nice_number(@rate_did_pr + @rate_did_ow)
        else
          item << nice_number(@rate_cur3)
          item << nice_number(@rate_prov)
          item << nice_number(@rate_cur3.to_d - @rate_prov.to_d)
          item << nice_number(@rate_cur3.to_d != 0.to_d ? ((@rate_cur3.to_d - @rate_prov.to_d)/ @rate_cur3.to_d) *100 : 0) + " %"
          item << nice_number(@rate_prov.to_d != 0.to_d ? ((@rate_cur3.to_d / @rate_prov.to_d) *100)-100 : 0) + " %"
        end
      end

      if session[:usertype] == "reseller"
        if @direction == "incoming"
          item << nice_number(@rate_did_ow)
        else
          item << nice_number(@rate_cur3)
          item << nice_number(@rate_prov)
          item << nice_number(@rate_cur3.to_d - @rate_prov.to_d)
          item << nice_number(@rate_cur3.to_d != 0.to_d ? ((@rate_cur3.to_d - @rate_prov.to_d)/ @rate_cur3.to_d) *100 : 0) + " %"
          item << nice_number(@rate_prov.to_d != 0.to_d ? ((@rate_cur3.to_d / @rate_prov.to_d) *100)-100 : 0) + " %"
        end
      end

      if session[:usertype] == "user" or session[:usertype] == "accountant"
        if @direction != "incoming"
          item << nice_number(@rate_cur3)
        else
          item << nice_number(@rate_did_ow)
        end
      end

      price_element = 0
      if @direction == "incoming"
        price_element = @rate_did_ow
      else
        price_element = @rate_cur3 if call.user_price
      end
      total_price += price_element
      #total_price += @rate_cur3 if call.user_price
      total_prov_price += @rate_prov.to_d
      total_prfit += @rate_cur3.to_d - @rate_prov.to_d
      total_billsec += call.nice_user_billsec
      total_did_provider += @rate_did_pr
      total_did_inc += @rate_did_ic
      total_did_own += @rate_did_ow
      total_did_prof += @rate_did_pr.to_d + @rate_did_ic.to_d + @rate_did_ow.to_d

      items << item
    end
    item = []
    #Totals
    item << {:text => _('Total'), :colspan => 3}
    item << nice_time(total_billsec)
    item << ' '
    if session[:usertype] == "admin" or session[:usertype] == "reseller"
      if @direction == "incoming"
        item << nice_number(total_did_provider)
        item << nice_number(total_did_inc)
        item << nice_number(total_did_own)
        item << nice_number(total_did_prof)
      else
        item << nice_number(total_price)
        item << nice_number(total_prov_price)
        item << nice_number(total_prfit)
        total_price_dec = total_price.to_d
        if total_price_dec != 0
          item << nice_number(total_price_dec != 0.to_d ? (total_prfit / total_price_dec) * 100 : 0) + " %"
        else
          item << nice_number(0) + " %"
        end
        if total_prov_price.to_d != 0
          item << nice_number(total_prov_price.to_d != 0 ? ((total_price_dec / total_prov_price.to_d) *100)-100 : 0) + " %"
        else
          item << nice_number(0) + " %"
        end
      end
    else
      if @direction != "incoming"
        item << nice_number(total_price)
      end
    end

    items << item

    headers, _h = PdfGen::Generate.call_list_to_pdf_header(pdf, @direction, session[:usertype], 0, {})

    pdf.table(items,
              :width => 550, :border_width => 0,
              :font_size => 7,
              :headers => headers) do
    end

    string = "<page>/<total>"
    opt = {:at => [500, 0], :size => 9, :align => :right, :start_count_at => 1}
    pdf.number_pages string, opt

    send_data pdf.render, :filename => "Calls_#{user.first_name}_#{user.last_name}_#{date_from}-#{date_till}.pdf", :type => "application/pdf"
  end

  def users_finances
    default = {:page => "1", :s_completed => '', :s_username => "", :s_fname => "", :s_lname => "", :s_balance_min => "", :s_balance_max => "", :s_type => ""}
    @page_title = _('Users_finances')
    @page_icon = "money.png"
    @searching = params[:search_on].to_i == 1

    @options = !session[:users_finances_options] ? default : session[:users_finances_options]
    default.each { |key, value| @options[key] = params[key] if params[key] }

    if @searching
      owner_id = (session[:usertype] == "accountant" ? 0 : session[:user_id])
      cond = ['users.hidden = ?', 'users.owner_id = ?']
      var = [0, owner_id]

      if ['postpaid', 'prepaid'].include?(@options[:s_type])
        cond << 'users.postpaid = ?'
        var << (@options[:s_type] == "postpaid" ? 1 : 0)
      end

      add_contition_and_param(@options[:s_username], @options[:s_username] + '%', "users.username LIKE ?", cond, var)
      add_contition_and_param(@options[:s_fname], @options[:s_fname] + '%', "users.first_name LIKE  ?", cond, var)
      add_contition_and_param(@options[:s_lname], @options[:s_lname] + '%', "users.last_name LIKE ?", cond, var)
      add_contition_and_param(@options[:s_balance_min], @options[:s_balance_min].to_d, "users.balance >= ?", cond, var)
      add_contition_and_param(@options[:s_balance_max], @options[:s_balance_max].to_d, "users.balance <= ?", cond, var)
      @total_users = User.where([cond.join(' AND ').to_s] + var).size.to_i

      items_per_page, total_pages = item_pages(@total_users)
      page_no = Application.valid_page_number(@options[:page], total_pages)
      offset, limit = Application.query_limit(total_pages, items_per_page, page_no)

      @total_pages = total_pages
      @options[:page] = page_no

      @users = User.includes(payments: {user: :tax}).
                    where([cond.join(' AND ').to_s] + var).
                    limit(limit).
                    offset(offset).all

      cond.size.to_i > 2 ? @search = 1 : @search = 0
      @total_balance = @total_credit = @total_payments = @total_amount =0
      @amounts = {}
      @payment_size = {}
      hide_uncompleted_payment = Confline.get_value("Hide_non_completed_payments_for_user", current_user.id).to_i

      @users.each_with_index do |user, _i|

        payments = user.payments
        amount = 0
        pz = 0
        payments.each do |payment|
          if hide_uncompleted_payment == 0 or (hide_uncompleted_payment == 1 and (payment.pending_reason != 'Unnotified payment' or payment.pending_reason.blank?))
            if payment.completed.to_i == @options[:s_completed].to_i or @options[:s_completed].blank?
              pz += 1
              pa = payment.payment_amount
              amount += get_price_exchange(pa, payment.currency)
            end
          end
        end
        user_id = user.id
        @amounts[user_id] = amount
        @payment_size[user_id] = pz
        @total_balance += user.balance
        @total_credit += user.credit if user.credit != (-1) and user.postpaid.to_i != 0
        @total_payments += pz
        @total_amount += amount
      end
    end
    session[:users_finances_options] = @options
  end

  def providers
    @page_title = _('Providers_stats')
    @page_icon = 'chart_bar.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Providers_Statistics'
    @show_currency_selector = 1

    providers_options

    @data = EsProvidersStats.es_providers(
        {
            from: es_limit_search_by_days, till: es_session_till, current_user: corrected_current_user,
            can_see_finances: can_see_finances?, show_currency: session[:show_currency]
        }.merge(@options[:search])
    )

    destination_flag_name
  end

  def providers_options
    change_date
    default_search = {show_hidden_providers: 0, hide_providers_without_calls: 0, prefix: ''}
    @options = {search: (session[:stats_providers_options][:search] || default_search)}

    if params[:clear].to_i == 1
      change_date_to_present
      @options[:search] = default_search
    else
      [:show_hidden_providers, :hide_providers_without_calls].each do |key|
        @options[:search][key] = params[key].to_i if params[key]
      end
      @options[:search][:prefix] = params[:prefix].to_s.strip if params[:prefix]
    end

    @options[:search][:active] = true if @options[:search] != default_search || search_not_for_today

    session[:stats_providers_options] = {search: @options[:search]}
  end

  def providers_stats
    @page_title = _('Providers_stats')
    @page_icon = 'chart_pie.png'

    # Clearing search values
    if params[:clear]
      change_date_to_present
      @s_prefix = ''
    end

    provider_id = params[:id].to_i
    @first_provider = Provider.where(id: provider_id).first

    if @first_provider.blank?
      flash[:notice] = _('Provider_not_found')
      (redirect_to :root) && (return false)
    end

    change_date

    @s_prefix = ''

    if params[:search]
      @s_prefix = params[:search].to_s
    elsif session[:stats_providers_options][:search][:prefix]
      @s_prefix = session[:stats_providers_options][:search][:prefix].to_s
    end

    if @s_prefix.present?
      @dest = Destination.where("prefix = SUBSTRING(#{ActiveRecord::Base::sanitize(@s_prefix.to_s)}, 1, LENGTH(destinations.prefix))").order('LENGTH(destinations.prefix) DESC').first
      @flag = nil

      if @dest == nil
        @results = ''
      else
        @flag = @dest.direction_code
        direction = @dest.direction
        @results = direction ? ("#{direction.name} #{@results}") : @dest.name.to_s
      end
    end

    user = User.where(id: corrected_user_id).first
    @data = EsProvidersStats.es_provider_stats(
        {
            from: es_limit_search_by_days, till: es_session_till, current_user: corrected_current_user,
            provider_id: provider_id, prefix: @s_prefix
        }
    )

    answered_calls = Call.calls_for_providers_stats(
        {
            user_id: user.id, prov_id: provider_id, reseller?: reseller?, admin?: admin?,
            date_from: session_from_datetime, date_till: session_till_datetime,
            s_prefix: @s_prefix
        }
    )

    all_dates = {}
    (session_from_datetime.to_datetime..session_till_datetime.to_datetime).each do |d|
      all_dates.update(
          {
              d.strftime('%Y-%m-%d') => {
                  'billsec' => 0,
                  'asr_pr' => 0,
                  'sel_price' => 0,
                  'selfcost_price' => 0
              }
          }
      )
    end

    date_with_data = {}
    if answered_calls.present?
      answered_calls.each do |result|
        billsec = (result['calls_count'] > 0) ? result['billsec'] / result['calls_count'] : 0
        asr_pr = (result['calls_count'].to_f > 0) ? (result['calls_count'].to_f / result['all_calls_count'].to_f) * 100 : 0
        date_with_data.update(
            {
                result['date'] => {
                    'billsec' => billsec.round.to_s,
                    'asr_pr' => asr_pr.round(2).to_s,
                    'sel_price' => result['sel_price'].round(2).to_s,
                    'selfcost_price' => result['selfcost_price'].round(2).to_s
                }
            }
        )
      end
    end

    aggregated_data = all_dates.merge(date_with_data) { |key, old, new| old = new if new != 0  }

    @calls_graph = ''
    @avg_calltime_graph = ''
    @asr_graph = ''
    @profit_graph = ''

    aggregated_data.each do |key, value|
      @avg_calltime_graph << "#{key};#{value['billsec'].to_s if value['billsec'].to_f != 0}\\n"
      @asr_graph << "#{key};#{value['asr_pr'].to_s if value['asr_pr'].to_f != 0}\\n"
      @profit_graph << "#{key};#{value['sel_price'].to_s if value['sel_price'].to_f != 0};#{value['selfcost_price'].to_s if value['selfcost_price'].to_f != 0}\\n"
    end

    @calls_graph = _('ANSWERED') + ';' + @data[:table_totals][:answered].to_s + ';' + 'false' + '\\n' +
        _('NO_ANSWER') + ';' + @data[:table_totals][:no_answer].to_s + ';' + 'false' + '\\n' +
        _('BUSY') + ';' + @data[:table_totals][:busy].to_s + ';' + 'false' + '\\n' +
        _('FAILED') + ';' + @data[:table_totals][:failed].to_s + ';' + 'false' + '\\n'

    if aggregated_data.blank?
       @calls_graph = 'No result;0;false\\n'
       @avg_calltime_graph = 'No result;0\\n'
       @asr_graph = 'No result;0\\n'
       @profit_graph = 'No result;0;0\\n'
    end
  end

  def loss_making_calls
    @page_title = _('Loss_making_calls')
    @page_icon = 'money_delete.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Loss_Making_Calls'

    select_hash = {usertype: :reseller}
    if current_user.usertype == 'accountant' && current_user.show_only_assigned_users.to_i == 1
      select_hash = {usertype: :reseller, responsible_accountant_id: current_user.id}
    end

    @options = {
        select: {
            resellers: User.select("id, #{SqlExport.nice_user_name_sql}").where(select_hash).order('nicename')
        },
        search: {
            reseller_id: params[:reseller_id]
        }
    }

    change_date
    session[:hour_from], session[:minute_from], session[:hour_till], session[:minute_till] = %w[00 00 23 59]
    @data = EsLossMakingCalls.get_data(
        {
            from: es_limit_search_by_days, till: es_session_till,
            can_see_finances: can_see_finances?,
            current_user: current_user, reseller_id: params[:reseller_id]
        }
    )

    if @data[:table_rows].size >= 10000
      flash.now[:notice] = _('Only_first_10000_most_recent_loss_making_Calls_are_shown_Totals_are_not_affected')
    end
  end

  def retrieve_call_debug_info
    if admin?
      call = Call.where(id: params[:id]).first
      render json: call.try(:getDebugInfo)
    else
      render json: {}
    end
  end

  def get_rs_user_map
    @responsible_accountant_id = params[:responsible_accountant_id] ? params[:responsible_accountant_id].to_i : -1
    @responsible_accountant_id.to_s != '-1' ? cond = ['responsible_accountant_id = ?', @responsible_accountant_id] : ''
    output = []
    output << "<option value='-1'>All</option>"
    output << User.where(cond).map { |user| ["<option value='"+user.id.to_s+"'>"+nice_user(user)+"</option>"] }
    render :text => output.join
  end

  def profit
    @page_title = _('Profit')
    @page_icon = 'money.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Profit_Stats'
    @show_currency_selector = 1

    profit_options

    @data = EsProfit.get_data(
        {
            from: es_limit_search_by_days, till: es_session_till,
            current_user: corrected_current_user, show_currency: session[:show_currency]
        }.merge(@options[:search])
    )

    @search_user = params[:s_user]
    @search = params[:search_on].to_i == 1 || search_not_for_today ? 1 : 0

    if admin?
      @responsible_accountants = User.responsible_acc_for_list
    end
  end

  def profit_options
    change_date
    if params[:clear].to_s == 'true'
      change_date_to_present
    end

    @user_id = params[:s_user_id] if params[:s_user_id] != ''

    if params[:s_user].blank? || %w[-2 -1].include?(params[:s_user_id].to_s)
      @user_id = -1
    end

    @options = {search: {}}
    responsible_accountant_id = params[:responsible_accountant_id] || (current_user.show_only_assigned_users.to_i == 1 ? current_user_id : nil)
    @options[:search][:responsible_accountant_id] = responsible_accountant_id ? responsible_accountant_id.to_i : -1
    @options[:search][:s_user_id] = @user_id
    @options[:search][:session_from] = session_from_datetime
    @options[:search][:session_till] = session_till_date
    @options[:search][:session_till_for_subsc] = session_till_datetime
  end

 # Generates profit report in PDF
  def generate_profit_pdf
    @user_id = -1
    user_name = ''
    if params[:user_id]
      if params[:user_id] != '-1'
        @user_id = params[:user_id]
        user = User.find_by_sql("SELECT * FROM users WHERE users.id = '#{@user_id}'")
        if user[0].present?
          user_name = user[0]['username'] + ' - ' + user[0]['first_name'] + ' ' + user[0]['last_name']
        else
          user_name = params[:username].to_s
        end
      else
        user_name = 'All users'
      end
    end

    pdf = Prawn::Document.new(:size => 'A4', :layout => :portrait)
    pdf.font_families.update('arial' => {
        :bold => "#{Prawn::BASEDIR}/data/fonts/Arialb.ttf",
        :italic => "#{Prawn::BASEDIR}/data/fonts/Ariali.ttf",
        :bold_italic => "#{Prawn::BASEDIR}/data/fonts/Arialbi.ttf",
        :normal => "#{Prawn::BASEDIR}/data/fonts/Arial.ttf"})

    pdf.text(_('PROFIT_REPORT'), {:left => 40, :size => 14, :style => :bold})
    pdf.text(_('Time_period') + ': ' + session_from_date.to_s + ' - ' + session_till_date.to_s, {:left => 40, :size => 10, :style => :bold})
    pdf.text(_('Counting') + ': ' + user_name.to_s, {:left => 40, :size => 10, :style => :bold})

    pdf.move_down 60
    pdf.stroke do
      pdf.horizontal_line 0, 550, :fill_color => '000000'
    end
    pdf.move_down 20

    items = []

    item = [_('Total_calls'), {:text => params[:total_calls].to_s, :align => :left}, {:text => ' ', :colspan => 3}]
    items << item

    item = [_('Answered_calls'), {:text => params[:total_answered_calls].to_s, :align => :left}, {:text => nice_number(params[:total_answer_percent].to_s) + ' %', :align => :left}, _('Duration') + ': ' + nice_time(params[:total_duration]), _('Average_call_duration') + ': ' + nice_time(params[:average_call_duration])]
    items << item

    item = [_('No_Answer'), {:text => params[:total_not_ans_calls].to_s, :align => :left}, {:text => nice_number(params[:total_not_ans_percent].to_s) + ' %', :align => :left}, {:text => ' ', :colspan => 2}]
    items << item

    item = [_('Busy_calls'), {:text => params[:total_busy_calls].to_s, :align => :left}, {:text => nice_number(params[:total_busy_percent].to_s) + ' %', :align => :left}, {:text => ' ', :colspan => 2}]
    items << item

    item = [_('Error_calls'), {:text => params[:total_error_calls].to_s, :align => :left}, {:text => nice_number(params[:total_error_percent].to_s) + ' %', :align => :left}, {:text => ' ', :colspan => 2}]
    items << item

    # bold
    item = [' ', {:text => _('Price'), :align => :left, :style => :bold}, {:text => _('Percent'), :align => :left, :style => :bold}, {:text => _('Call_time'), :align => :left, :style => :bold}, {:text => _('Active_users'), :align => :left, :style => :bold}]
    items << item

    item = [_('Total_call_price'), {:text => nice_number(params[:total_call_price].to_s), :align => :left}, {:text => nice_number(params[:total_percents].to_s), :align => :left}, {:text => nice_time(params[:total_duration].to_s), :align => :left}, {:text => params[:active_users].to_i.to_s, :align => :left}]
    items << item

    item = [_('Total_call_self_price'), {:text => nice_number(params[:total_call_selfprice].to_s), :align => :left}, {:text => nice_number(params[:total_selfcost_percents].to_s), :align => :left}, {:text => ' ', :colspan => 2}]
    items << item

    item = [_('Calls_profit'), {:text => nice_number(params[:total_profit].to_s), :align => :left}, {:text => nice_number(params[:total_profit_percent].to_s), :align => :left}, {:text => ' ', :colspan => 2}]
    items << item

    item = [_('Average_profit_per_call_min'), {:text => nice_number(params[:avg_profit_call_min].to_s), :align => :left}, {:text => ' ', :colspan => 3}]
    items << item

    item = [_('Average_profit_per_call'), {:text => nice_number(params[:avg_profit_call].to_s), :align => :left}, {:text => ' ', :colspan => 3}]
    items << item

    item = [_('Average_profit_per_day'), {:text => nice_number(params[:avg_profit_day].to_s), :align => :left}, {:text => ' ', :colspan => 3}]
    items << item

    item = [_('Average_profit_per_active_user'), {:text => nice_number(params[:avg_profit_user].to_s), :align => :left}, {:text => ' ', :colspan => 3}]
    items << item

    unless reseller?
      # bold
      item = [' ', {:text => _('Price'), :align => :left, :style => :bold}, {:text => ' ', :colspan => 3}]
      items << item

      unless partner?
        # bold  1 collumn
        item = [{:text => _('Subscriptions_profit'), :align => :left, :style => :bold}, {:text => nice_number(params[:sub_price].to_s), :align => :left}, {:text => ' ', :colspan => 3}]
        items << item
      end

      # bold  1 collumn
      item = [{:text => _('Total_profit'), :align => :left, :style => :bold}, {:text => nice_number(params[:s_total].to_s), :align => :left}, {:text => ' ', :colspan => 3}]
      items << item
    end

    pdf.table(items,
              :width => 550, :border_width => 0,
              :font_size => 9) do
      column(0).style(:align => :left)
      column(1).style(:align => :left)
      column(2).style(:align => :left)
      column(3).style(:align => :left)
      column(4).style(:align => :left)
    end

    pdf.move_down 20
    pdf.stroke do
      pdf.horizontal_line 0, 550, :fill_color => '000000'
    end

    send_data pdf.render, :filename => "Profit-#{user_name}-#{session_from_date.to_s}_#{session_till_date.to_s}.pdf", :type => 'application/pdf'
  end

  def providers_calls
    dont_be_so_smart
    (redirect_to :root) && (return false)
  end

  ############ PDF ###############

  def providers_calls_to_pdf
    # require "pdf/wrapper"
    id = params[:id]
    if id
      provider = Provider.find(id)
    end

    id = id.to_i

    date_from = params[:date_from]
    date_till = params[:date_till]
    call_type = params[:call_type]
    params[:direction] ? @direction = params[:direction] : @direction = "outgoing"
    params[:call_type] ? @call_type = params[:call_type] : @call_type = "all"
    @orig_call_type = @call_type
    if @direction == "incoming"
      disposition = " (calls.did_provider_id = '#{id}' OR calls.src_device_id = '#{provider.device_id}' )"
    else
      disposition = " calls.provider_id = '#{id}' "
    end
    disposition += " AND disposition = '#{@call_type}' " if @call_type != "all"
    disposition += " AND calldate BETWEEN '#{date_from}' AND '#{date_till}'"
    calls = Call.where("#{disposition}").order("calldate DESC")
    options = {
        :date_from => date_from,
        :date_till => date_till,
        :call_type => call_type,
        :nice_number_digits => session[:nice_number_digits],
        :currency => session[:show_currency],
        :default_currency => session[:default_currency],
        :direction => @direction
    }

    morlog_start = MorLog.my_debug("Genetare_start", true)
    pdf = PdfGen::Generate.providers_calls_to_pdf(provider, calls, options)
    morlog_end = MorLog.my_debug("Genetare_end", true)
    MorLog.my_debug("Generate_time : #{morlog_end - morlog_start}")
    send_data pdf.render, :filename => "CDR-#{provider.name}-#{date_from}_#{date_till}.pdf", :type => "application/pdf"
  end

  ############ CSV ###############

  def faxes
    @page_title = _('Faxes')
    @page_icon = 'printer.png'
    @options = session[:faxes] || {}

    change_date
    search_params(params)
    user_id = params[:s_user_id] || @options[:search][:s_user_id]

    conditions = faxes_conditions(user_id)

    if current_user.is_admin?
      @users = User.where(hidden: 0, usertype: 'user').where(conditions)
    else
      @users = User.where(hidden: 0, usertype: 'user', owner_id: correct_owner_id).where(conditions)
    end

    @options[:session_from_datetime] = session_from_datetime
    @options[:session_till_datetime] = session_till_datetime

    totals = Pdffax.total_faxes(@options, conditions)
    @t_size_on_hdd = totals.total_size.to_d / (1024 * 1024)
    @t_received = totals.good.to_i
    @t_corrupted = totals.pdf_size.to_i
    @t_mistaken = totals.no_tif.to_i
    @t_total = @t_received + @t_corrupted + @t_mistaken

    page_params(@users)
    order_by = users_order_by(@options)
    @options[:fpage] = @fpage

    @search_user = User.where(id: @options[:search][:s_user_id]).first unless
      %w(-2 -1).include?(user_id.to_s)
    @users = User.find_users_for_faxes(@options,
                                           session[:items_per_page], order_by, conditions).load
    session[:faxes] = @options
  end

  def faxes_conditions(user_id)
    var = []
    cond = []
    if user_id.present? && !%w(-2 -1).include?(user_id.to_s)
      cond << 'users.id = ?'
      var << [user_id]
    end
    [cond.join(' AND ')] + var if cond.size.to_i > 0
  end

  def search_params(params)
    @options[:search] ||= {}
    %i(s_user_id s_user).each do |key|
      param_key = params[key]
      if param_key
        @options[:show_clear] = true
        @options[:search][key] = param_key
      end
    end
    clear_search if params[:clear].to_i == 1
  end

  def clear_search
    change_date_to_present
    @options[:show_clear] = false
    @options[:search] = {}
  end

  def page_params(users)
    page_number_params
    order_params
    order_by_params
    # page params
    @total_users_size = users.size
    session_items_per_page = session[:items_per_page]
    @total_pages = (@total_users_size.to_d / session_items_per_page.to_d).ceil
    total_pages_number = @total_pages.to_i
    @options[:page] = @total_pages if
    @options[:page].to_i > total_pages_number && total_pages_number > 0
    @page = @options[:page]
    @fpage = ((@options[:page] - 1) * session_items_per_page).to_i
  end

  def users_order_by(options)
    order_by_option = options[:order_by].to_s.strip
    order_by = if order_by_option == 'name'
                 'nice_user'
               elsif order_by_option == 'received'
                 'good'
               elsif order_by_option == 'corrupted'
                 'pdf_size'
               elsif order_by_option == 'mistaken'
                 'no_tif'
               elsif order_by_option == 'total'
                 'totals'
               elsif order_by_option == 'size'
                 'total_size'
               else
                 order_by_option
               end

    if order_by != ''
      order_by << (options[:order_desc].to_i == 0 ? ' ASC' : ' DESC')
    end

    order_by
  end

  def page_number_params
    params_page = params[:page]
    params_page ? @options[:page] =
    params_page.to_i : (@options[:page] = 1 unless @options[:page])
  end

  def order_params
    order_desc = params[:order_desc]
    order_desc ? @options[:order_desc] =
    order_desc.to_i :
    (@options[:order_desc] = 0 unless @options[:order_desc])
  end

  def order_by_params
    order_by = params[:order_by]
    order_by ? @options[:order_by] =
    order_by.to_s :
    (@options[:order_by] = 'users.username' unless @options[:order_by])
  end

  def faxes_list
    @page_title = _('Faxes')
    @page_icon = 'printer.png'

    selected_user = User.where(id: params[:id]).first
    if !selected_user.try(:is_user?) || !session[:fax_device_enabled]
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    change_date

    if admin? or accountant?
      @user = User.where(["id = ?", params[:id].to_i]).first
      if params[:id].to_i >= 0 and @user == nil
        flash[:notice] = _('User_not_found')
        (redirect_to :root) && (return false)
      end
    else
      @user = User.find(session[:user_id])
    end

    @devices = @user.fax_devices

    @Fax2Email_Folder = Confline.get_value('Fax2Email_Folder', 0)
    if @Fax2Email_Folder.to_s == ''
      @Fax2Email_Folder = Web_URL + Web_Dir + '/fax2email/'
    end

    @sel_device = 'all'
    @sel_device = params[:device_id] if params[:device_id]
    device_sql = ''
    device_sql = " AND device_id = #{ActiveRecord::Base::sanitize(@sel_device.to_i)} " if @sel_device != 'all'

    @fstatus = 'all'
    @fstatus = params[:fstatus] if params[:fstatus]
    status_sql = ''
    status_sql = " AND status = #{ActiveRecord::Base::sanitize(@fstatus)} " if @fstatus != 'all' && %w[good pdf_size_0 no_tif].include?(@fstatus.to_s.strip)

    @search = 0
    @search = 1 if params[:search_on]

    sql = "SELECT pdffaxes.* FROM pdffaxes, devices WHERE pdffaxes.device_id = devices.id AND devices.user_id = #{@user.id} AND receive_time BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}' #{status_sql} #{device_sql}"
    @faxes = Pdffax.find_by_sql(sql)


  end

  #================= ACTIVE CALLS ====================

  def active_calls_count
    user = User.new(:usertype => session[:usertype])
    user.id = session[:usertype] == 'accountant' ? 0 : session[:user_id]
    @acc = Activecall.count_for_user(user).to_s + ' / ' + Activecall.count_for_user(user, true).to_s
    render(:layout => false)
  end

  def active_calls
    unless ["admin", "accountant"].include?(session[:usertype]) or session[:show_active_calls_for_users].to_i == 1 or (current_user and current_user.reseller_allow_providers_tariff?)
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      (redirect_to :root) && (return false)
    end
    user = User.new(:usertype => session[:usertype])
    user.id = session[:usertype] == 'accountant' ? 0 : session[:user_id]
    @page_title = _('Active_Calls')
    @page_icon = 'call.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Active_Calls'
    active_calls_show

    # search
    @countries = Direction.select('name')
    @providers = accountant? ?  Provider.all : current_user.load_providers
  end

  def active_calls_show
    @options = session[:active_calls_options] || {}
    @refresh_period = session[:active_calls_refresh_interval].to_i

    # This code selects correct calls for admin/reseller/user
    hide_active_calls_longer_than = Confline.get_value('Hide_active_calls_longer_than', 0).to_i
    hide_active_calls_longer_than = 24 if hide_active_calls_longer_than == 0
    user_sql = " (DATE_ADD(activecalls.start_time, INTERVAL #{hide_active_calls_longer_than} HOUR) > NOW()) "
    user_id = session[:user_id]
    @user_id = accountant? ? 0 : user_id
    # Reseller or user
    if reseller?
      # Reseller
      user_sql << " AND (activecalls.user_id = #{user_id} OR dst_usr.id = #{user_id} OR  activecalls.owner_id = #{user_id} OR dst_usr.owner_id = #{user_id})"
    elsif accountant? && current_user.show_only_assigned_users == 1
      # Accountant
      user_sql << " AND (users.responsible_accountant_id = #{user_id} OR dst_usr.responsible_accountant_id = #{user_id} OR call_users.responsible_accountant_id = #{user_id})"
    elsif user_id != 0 && !accountant?
      # User
      user_sql << " AND (activecalls.user_id = #{user_id} OR dst_usr.id = #{user_id}) "
    end

    @show_did = current_user.active_calls_show_did?
    @ma_active = monitorings_addon_active?
    @chanspy_disabled = Confline.chanspy_disabled?
    @spy_device = Device.where("id = #{current_user.spy_device_id.to_i}").first

    if user_id.to_s.blank?
      # Faking empty object
      @active_calls = Activecall.where( id: nil )
    else
      @active_calls = Activecall
          .select(
              "activecalls.id as ac_id, activecalls.channel as channel, activecalls.prefix, activecalls.server_id as server_id,
          activecalls.answer_time as answer_time, activecalls.src as src, activecalls.src_device_id as src_device_id, activecalls.localized_dst as localized_dst, activecalls.uniqueid as uniqueid,
          activecalls.lega_codec as lega_codec,activecalls.legb_codec as legb_codec,activecalls.pdd as pdd,
          #{SqlExport.replace_price('activecalls.user_rate', {:reference => 'user_rate'})}, tariffs.currency as rate_currency,
          users.id as user_id, users.first_name as user_first_name, users.last_name as user_last_name, users.username as user_username, users.owner_id as user_owner_id,
          devices.id as 'device_id',devices.device_type as device_type, devices.name as device_name, devices.username as device_username, devices.extension as device_extension, devices.istrunk as device_istrunk, devices.ani as device_ani, devices.user_id as device_user_id,
          dst.id as dst_device_id,  dst.device_type as dst_device_type, dst.name as dst_device_name, dst.username as dst_device_username, dst.extension as dst_device_extension, dst.istrunk as dst_device_istrunk, dst.ani as dst_device_ani, dst.user_id as dst_device_user_id,
          dst_usr.id as dst_user_id, dst_usr.first_name as dst_user_first_name, dst_usr.last_name as dst_user_last_name, dst_usr.username as dst_user_username, dst_usr.owner_id as dst_user_owner_id, dst_usr.responsible_accountant_id as dst_resp_acc,
          destinations.direction_code as direction_code, directions.name as direction_name, destinations.name as destination_name,
          providers.id as provider_id, providers.name as provider_name, providers.common_use, providers.user_id as 'providers_owner_id', activecalls.did_id as did_id, dids.did as did_num, NULL as did_direction_code,
          NOW() - activecalls.answer_time AS 'duration', users.responsible_accountant_id as src_resp_acc,
          IF(activecalls.answer_time IS NULL, 0, 1 ) as 'status',
          activecalls.card_id as cc_id, cards.number as cc_number, cards.owner_id as cc_owner_id
          #{', common_use_providers.provider_name as common_use_provider_name' if reseller?}"
          ).joins(
          "LEFT JOIN providers ON (providers.id =activecalls.provider_id)
          #{"LEFT JOIN common_use_providers ON (common_use_providers.provider_id = providers.id AND common_use_providers.reseller_id = #{current_user_id})" if reseller?}
          LEFT JOIN devices ON (devices.id = activecalls.src_device_id)
          LEFT JOIN devices AS dst ON (dst.id = activecalls.dst_device_id)
          LEFT JOIN users ON (users.id = devices.user_id)
          LEFT JOIN cards ON (cards.id = activecalls.card_id)
          LEFT JOIN users AS dst_usr ON (dst_usr.id = dst.user_id)
          LEFT JOIN users AS call_users ON (call_users.id = activecalls.user_id)
          LEFT JOIN tariffs ON (tariffs.id = users.tariff_id)
          LEFT JOIN destinations ON (destinations.prefix = activecalls.prefix)
          LEFT JOIN directions ON (directions.code = destinations.direction_code)
          LEFT JOIN dids ON (activecalls.did_id = dids.id)"
      ).where(user_sql)

      elements = [:s_user, :s_user_id, :s_status, :s_country, :s_provider, :s_source, :s_destination, :search_on]
      count = 0
      elements.each { |key| count += 1 if params[key].present? }
      search =  count > 0 ? params : @options

      if search[:s_user].present? && search[:s_user_id].present? && search[:s_user_id].to_i >= 0
        @active_calls = @active_calls.where(user_id: search[:s_user_id])
      end

      if search[:s_country].present?
        direction =  Direction.where(name: search[:s_country]).first.code
        @active_calls = @active_calls.where('destinations.direction_code = ?', direction)
      end

      if search[:s_status].present?
        status = 'NOT' unless search[:s_status].to_i == 0
        @active_calls = @active_calls.where("answer_time IS #{status} NULL")
      end

      if search[:s_provider].present?
        @active_calls = @active_calls.where('providers.id = ?', search[:s_provider])
      end

      if search[:s_source].present?
        @active_calls = @active_calls.where('activecalls.src LIKE ?', search[:s_source])
      end

      if search[:s_destination].present?
        @active_calls = @active_calls.where('activecalls.localized_dst LIKE ?', search[:s_destination])
      end
    end
    # Active Calls Destination names by best matching prefix
    Activecall.update_calls_by_destinations(@active_calls)

    session[:active_calls_options] = search

    json_except = admin? || accountant? ? [:did] : [:did, :uniqueid]
    json_except += [:provider_id, :provider_name, :common_use,
                    :providers_owner_id] if user? || (reseller? && current_user.own_providers.to_i == 0)
    @active_calls_json = @active_calls.to_json(except: json_except)

    if request.xhr?
      render json: @active_calls_json
    end
  end

=begin

SELECT activecalls.start_time as start_time, activecalls.src as src, activecalls.dst as dst, users.id as user_id, users.first_name as user_first_name, users.last_name as user_last_name, devices.device_type as device_type, devices.name as device_name, devices.extension as device_extension, devices.istrunk as device_istrunk, devices.ani as device_ani, dst.id as dst_id, dst.device_type as dst_device_type, dst.name as dst_device_name, dst.extension as dst_device_extension, dst.istrunk as dst_device_istrunk, dst.ani as dst_device_ani, dst_usr.id as dst_user_id, dst_usr.first_name as dst_user_first_name, dst_usr.last_name as dst_user_last_name
FROM activecalls
LEFT JOIN providers ON (providers.id =activecalls.provider_id)
LEFT JOIN devices ON (devices.id = activecalls.src_device_id)
LEFT JOIN devices AS dst ON (dst.id = activecalls.dst_device_id)
LEFT JOIN users ON (users.id = devices.user_id)
LEFT JOIN users AS dst_usr ON (dst_usr.id = dst.user_id)
LEFT JOIN destinations ON (destinations.prefix = activecalls.prefix)
LEFT JOIN directions ON (directions.code = destinations.direction_code)

=end

  def active_calls_graph
    @page_title = _('active_calls_graph')
    @page_icon = 'call.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Active%20Calls%20Graph'
    @graph = {refresh_period: session[:active_calls_refresh_interval].to_i}

    create_graph_data_file
  end

  def update_active_calls_graph
    create_graph_data_file unless session[:active_calls_graph].present? && session[:active_calls_graph][:last_count].present?

    last_count = session[:active_calls_graph][:last_count].in_time_zone(user_tz)
    new_data = ActiveCallsData.find_from_timestamp(last_count)

    begin
      file = File.open("/home/mor/public/tmp/active_calls.csv", 'r')
    rescue
      create_graph_data_file
      file = File.open("#{Actual_Dir}/public/tmp/active_calls.csv", 'r')
    end

    if !new_data.blank? and ((Time.now - file.atime) >= session[:active_calls_refresh_interval].to_i.seconds - 1.second)
      new_last_count = new_data.last.time.in_time_zone(user_tz)

      csv_lines = file.read.split("\n")
      file.close

      # Replace yesterday's data wtih today's data if a day has passed
      if new_last_count.day != last_count.day
        # In case of long refresh rate finish filling today's data
        end_of_day = last_count.end_of_day
        yesterday_data = new_data.select {|data| data.time.in_time_zone(user_tz) < end_of_day}
        new_data -= yesterday_data
        unless yesterday_data.blank?
          yesterday_data.collect! {|data| [data.time.in_time_zone(user_tz).strftime('%H:%M:%S'), data.count]}
          yesterday_data.each do |data|
            hour, minute, second = data[0].try(:split, ';')
            second = @round_seconds.call(second.to_i)
            index = (hour.to_i * 3600 + minute.to_i * 60 + second.to_i)/15
            new_line = csv_lines[index].try(:split, ';')
            new_line[1] = data[1]
            csv_lines[index] = new_line.try(:join, ';')
          end
        end

        # Switch yesterday's data with today's data
        csv_lines.map! do |line|
          element = line.try(:split, ';')
          element[2] = element[1].to_s
          element[1] = ''
          element.try(:join, ';')
        end
      end

      new_data.collect! {|data| [data.time.in_time_zone(user_tz).strftime('%H:%M:%S'), data.count]}

      new_data.each do |data|
        hour, minute, second = data[0].try(:split, ':')
        second = @round_seconds.call(second.to_i)
        index = (hour.to_i * 3600 + minute.to_i * 60 + second.to_i)/15
        new_line = csv_lines[index].try(:split, ';')
        new_line[1] = data[1]
        new_line[2] = new_line[2].to_s
        csv_lines[index] = new_line.try(:join, ';')
      end

      session[:active_calls_graph][:last_count] = new_last_count

      file = File.open("/home/mor/public/tmp/active_calls.csv", 'w')
      file.write(csv_lines.join("\n"))
      file.close
    end
    render nothing: true
  end

  # Statistics > Various > DIDs
  def dids
    @page_title = _('DIDs')
    @page_icon = 'did.png'
    @show_currency_selector = 1
    @help_link = 'http://wiki.kolmisoft.com/index.php/STATISTICS_-_Various_-_DIDs'
    # Data for dropdowns
    @users = User.find_all_for_select(corrected_user_id)
    @providers = Provider.where(hidden: 0).order('name ASC')

    change_date
    session[:hour_from], session[:minute_from], session[:hour_till], session[:minute_till] = %w[00 00 23 59]
    session[:stats_dids_search] ||= {}

    if params[:clear]
      # Clearing search values
      change_date_to_present
      user_id = provider_id = -1
    else
      # Saving search values
      user_id = params[:s_user_id] || session[:stats_dids_search][:user_id] || -1
      provider_id = params[:provider_id] || session[:stats_dids_search][:provider_id] || -1
    end

    session[:stats_dids_search][:user_id] = user_id
    session[:stats_dids_search][:provider_id] = provider_id

    @search_user = User.where(id: user_id).first
    @provider_id = provider_id

    # Perform ES query
    @data = EsDidsStats.get_data({
      from: es_limit_search_by_days,
      till: es_session_till,
      can_see_finances: can_see_finances?,
      current_user: current_user,
      user_id: user_id.to_s,
      show_currency: session[:show_currency],
      provider_id: @provider_id.to_s})
  end

  def system_stats
    @page_title = _('System_stats')
    @page_icon = 'chart_pie.png'

    show_assign_users = current_user.is_accountant? && current_user.show_only_assigned_users.to_i == 1
    @data = {
        users: User.system_stats(current_user),
        devices: show_assign_users ? Device.system_stats_for_acc(current_user) : Device.system_stats,
        providers: Provider.system_stats,
        tariffs: Tariff.system_stats,
        dids: Did.system_stats,
        calls: Call.es_system_stats(show_assign_users, current_user),
        cards: {
            total: Card.count,
            card_groups: Cardgroup.count,
        },
        other: {
            directions: Direction.count,
            destinations: Destination.count,
            destination_groups: Destinationgroup.count,
            lcrs: Lcr.count
        }
    }
  end

  def dids_usage

    @page_title = _('DIDs_usage')
    @page_icon = "did.png"
    change_date
    @searching = params[:search_on].to_i == 1

    if @searching
      sql_did_closed = "SELECT COUNT(DISTINCT actions.id) as \'actions\' FROM actions WHERE actions.date BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' AND actions.action = 'did_closed'"
      res = ActiveRecord::Base.connection.select_all(sql_did_closed)
      @did_closed = res[0]["actions"].to_i

      sql_did_made_available = "SELECT COUNT(DISTINCT actions.id) as \'actions\' FROM actions WHERE actions.date BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' AND actions.action = 'did_made_available'"
      res = ActiveRecord::Base.connection.select_all(sql_did_made_available)
      @did_made_available = res[0]["actions"].to_i

      sql_did_reserved = "SELECT COUNT(DISTINCT actions.id) as \'actions\' FROM actions WHERE actions.date BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' AND actions.action = 'did_reserved' AND actions.data2 = '0'"
      res = ActiveRecord::Base.connection.select_all(sql_did_reserved)
      @did_reserved = res[0]["actions"].to_i

      sql_did_created = "SELECT COUNT(DISTINCT actions.id) as \'actions\' FROM actions WHERE actions.date BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' AND actions.action = 'did_created'"
      res = ActiveRecord::Base.connection.select_all(sql_did_created)
      @did_created = res[0]["actions"].to_i

      sql_did_assigned1 = "SELECT COUNT(DISTINCT actions.data) as \'actions\' FROM actions WHERE actions.date BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' AND actions.action ='did_assigned_to_dp'"
      res = ActiveRecord::Base.connection.select_all(sql_did_assigned1)
      @did_assigned1 = res[0]["actions"].to_i

      sql_did_assigned2 = "SELECT COUNT(DISTINCT actions.data) as \'actions\' FROM actions WHERE actions.date BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' AND actions.action ='did_assigned'"
      res = ActiveRecord::Base.connection.select_all(sql_did_assigned2)
      @did_assigned2 = res[0]["actions"].to_i

      @did_assigned= @did_assigned1 + @did_assigned2

      sql_did_deleted = "SELECT COUNT(DISTINCT actions.data) as \'actions\' FROM actions WHERE actions.date BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' AND actions.action ='did_deleted'"
      res = ActiveRecord::Base.connection.select_all(sql_did_deleted)
      @did_deleted = res[0]["actions"].to_i

      sql_did_terminated = "SELECT COUNT(DISTINCT actions.data) as \'actions\' FROM actions WHERE actions.date BETWEEN '#{session_from_date} 00:00:00' AND '#{session_till_date} 23:59:59' AND actions.action ='did_terminated'"
      res = ActiveRecord::Base.connection.select_all(sql_did_terminated)
      @did_terminated = res[0]["actions"].to_i
    end

    @free = Did.free.size
    @reserved = Did.reserved.size
    @active = Did.active.size
    @closed = Did.closed.size
    @terminated = Did.terminated.size
  end

  # Prefix Finder ################################################################
  def prefix_finder
    redirect_to :action => 'search' and return false
  end

  def search
    @page_title, @page_icon = _('Dynamic_Search'), 'magnifier.png'
  end

  def prefix_finder_find
    @phrase = params[:prefix].gsub(/[^\d]/, '') if params[:prefix]
    @dest = Destination.where(prefix: @phrase).order('LENGTH(destinations.prefix) DESC').first if @phrase.present?
    @flag = nil

    if @dest == nil
      @results = ''
    else
      @flag = @dest.direction_code
      direction = @dest.direction
      @dg = @dest.destinationgroup
      @results = @dest.name.to_s
      @results = "#{direction.name.to_s} #{@results}" if direction
      @flag2 = @dg.flag if @dg
      @results2 = "#{_('Destination_group')} : #{@dg.name}" if @dg
    end

    render(layout: false)
  end

  def prefix_finder_find_country
    @phrase = params[:prefix].gsub(/['"]/, '') if params[:prefix]
    @dirs = Direction.where(["SUBSTRING(name, 1, LENGTH(?)) = ?", @phrase, @phrase]) if @phrase and @phrase.length > 1
    render(:layout => false)
  end

  def rate_finder_find
    # '123' => ['1', '12', '123']
    collided_prefix = collide_prefix(params[:prefix])
    @callshop = params[:callshop].to_i

    if Destination.where(prefix: collided_prefix).order(prefix: :desc).pluck(:id).present?

      if @callshop.to_i > 0
        sql = "SELECT position, user_id , users.tariff_id, gusertype from usergroups
               left join users on users.id = usergroups.user_id
                left join tariffs on tariffs.id = users.tariff_id where group_id = #{@callshop.to_i}"
        @booths = Usergroup.find_by_sql(sql).sort_by{|usergroup| usergroup.position }
        tariff_list = User.includes(:usergroups).references(:usergroups).
                           where(['usergroups.group_id = ? AND usergroups.gusertype != "manager"', @callshop]).
                           all.map(&:tariff_id).join(', ')
      else
        tariff_list = session[:tariff_id].to_i if user?
      end

      @rates = Stat.find_rates_and_tariffs_by_number(correct_owner_id, collided_prefix, tariff_list)
    end

    render(layout: false)
  end

  def ip_finder_find
    if params[:ip]
      ip = params[:ip].to_s.strip

      if ip.present?
      valid_ip_format = ip.match(/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\..+$/) ? true : false

        if valid_ip_format
          select_clause = 'SELECT id FROM users ' +
            "WHERE (owner_id = #{current_user.id} AND usertype != 'reseller') OR id = #{current_user.id}"
          @users_scope = ActiveRecord::Base.connection.select_values(select_clause)
          users_scope = @users_scope.collect(&:to_i).to_s.gsub("[", "(").gsub("]", ")")

          # searching devices
          ipaddr_clause = make_clause_by_ip_format('ipaddr', ip)
          conditions = "user_id != -1 AND " + ipaddr_clause
          conditions += " AND user_id IN #{users_scope}" if reseller?
          @devices = Device.where(conditions).order('device_type, name').all

          # searching providers
          conditions = make_clause_by_ip_format('server_ip', ip)
          conditions += " AND user_id = #{current_user.id}" if reseller?
          @providers = Provider.where(conditions).order('name, device_id').all
        end
      end
    end

    render(:layout => false)
  end

  # GOOGLE MAPS ##################################################################
  def google_maps
    @page_title = _('Google_Maps')
    @page_icon = 'world.png'
    @key = Confline.get_value('Google_Key')

    @devices = Device.joins(:user).where("users.owner_id = #{current_user.id} AND name NOT LIKE 'mor_server%' AND ipaddr > 0 AND ipaddr != '' AND user_id > -1
    AND '192.168.' != SUBSTRING(ipaddr, 1, LENGTH('192.168.'))
    AND '10.' != SUBSTRING(ipaddr, 1, LENGTH('10.'))
    AND ((CAST(SUBSTRING(ipaddr, 1,6) AS DECIMAL(6,3)) > 172.31)
    or (CAST(SUBSTRING(ipaddr, 1,6) AS DECIMAL(6,3)) < 172.16))").all
    @providers = Provider.where("user_id = #{current_user.id} AND server_ip > 0 AND server_ip != '' AND hidden = 0").all
    @servers = Server.where("server_ip > 0 AND server_ip != '0.0.0.0'").all
    session[:google_active] = 0
  end

  def google_active
    if session[:usertype] == "admin"
      @calls = Activecall.includes(:provider).all
    else
      @calls = Activecall.includes(:provider).where("owner_id = #{current_user.id}").all
    end
  end

  def hangup_cause_codes_stats
    # Ticket 5672 only if reseller pro addon is active, reseller that has own providers can access
    if reseller? && !current_user.reseller_allowed_to_view_hgc_stats?
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    @page_title, @page_icon = _('Hangup_cause_codes_stats'), 'chart_pie.png'

    change_date
    @searching = params[:search_on].to_i == 1

    session[:hour_from] = '00'
    session[:minute_from] = '00'
    session[:hour_till] = '23'
    session[:minute_till] = '59'

    if params[:back]
      @back = params[:back]
      if params[:back].to_i == 2
        @direction = Direction.where(code: params[:country_code]).first
        @country_id = @direction.id
      end
    end

    if params[:s_user].blank?
      params[:s_user_id] = -1
    elsif %w[-2 -1].include?(params[:s_user_id].to_s)
      params[:s_user_id] = -2
    end

    params[:s_device] = -1 if params[:s_device].to_s == 'all'
    @user_id = params[:s_user_id] ? params[:s_user_id].to_i : -1
    @device_id = params[:s_device] ? params[:s_device].to_i : -1
    @provider_id = params[:provider_id] ? params[:provider_id].to_i : -1
    @country_id = params[:country_id] ? params[:country_id].to_i : -1

    user = User.where(id: corrected_user_id).first
    if params[:provider_id] and params[:provider_id].to_i != -1
      @provider = user.providers.where({:id => params[:provider_id]}).first
      unless @provider
        dont_be_so_smart
        (redirect_to :root) && (return false)
      end
    end

    if params[:s_user_id] && ![-2, -1].include?(params[:s_user_id].to_i)
      @user = User.where(id: params[:s_user_id]).first
      unless @user
        dont_be_so_smart
        (redirect_to :root) && (return false)
      end
    end

    @country = Direction.where(id: @country_id).first if @country_id.to_i > -1
    if params[:direction_code]
      @country = Direction.where(code: params[:direction_code].strip).first
    end

    @code = @country.code if @country
    @providers = user.load_providers({conditions: 'hidden = 0', order: 'name ASC'})
    @countries = Direction.order(:name)

    search_from, search_till = [es_limit_search_by_days, es_session_till]

    options = {country_code: @code, provider_id: @provider_id,
               user_id: @user_id, device_id: @device_id,
               a1: search_from, a2: search_till, current_user: current_user
    }

    @calls, @calls_graph, @hangupcusecode_graph, @calls_size =
        if @searching
          EsHgcStats.get_data(options)
        else
          {}
        end
  end

  def calls_by_scr
    @page_title = _('Calls_by_src')
    @page_icon = 'chart_pie.png'
    @searching = params[:search_on].to_i == 1

    cond = ''
    des = ''
    descond = ''
    dest_dir_code = ''
    @prov = -1
    @coun = -1

    @country_id = params[:country_id] if params[:country_id]
    params_provider_id = params[:provider_id]
    if params_provider_id
      if params_provider_id.to_i != -1
        @provider = Provider.find(params_provider_id)
        cond += " ((hcalls.provider_id = #{q params_provider_id} and hcalls.callertype = 'Local') OR " +
          "(hcalls.did_provider_id = #{q params_provider_id} and hcalls.callertype = 'Outside')) AND "
        @prov = @provider.id
      end
    end

    @providers = Provider.where(['hidden=?', 0]).order('name ASC')

    if @country_id
      if @country_id.to_i != -1
        @country = Direction.find(@country_id)
        @coun = @country.id
        des+= 'destinations, '
        descond +=" AND directions.code ='#{@country.code}' "
        dest_dir_code +=" AND destinations.direction_code ='#{@country.code}' "
      end
    end

    @countries = Direction.order('name ASC')

    change_date

    session[:hour_from], session[:minute_from], session[:hour_till], session[:minute_till] = ['00', '00', '23', '59']

    if @searching
      join_calls_and_dest = 'JOIN destinations AS des ON (des.direction_code = directions.code) ' +
        'JOIN calls AS hcalls ON (hcalls.prefix = des.prefix)'
      where = "WHERE #{cond} hcalls.calldate BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}'"
      where_src = "#{descond} AND LENGTH(src) >= 10"

      sql = "SELECT directions.name, des.direction_code, des.name as 'des_name', des.prefix, " +
      "count(hcalls.id) as 'calls' FROM directions #{join_calls_and_dest} #{where} #{where_src} GROUP BY des.id"
      @res = ActiveRecord::Base.connection.select_all(sql)

      sql = "SELECT directions.name, directions.code, count(hcalls.id) as 'calls' FROM directions " +
        "#{join_calls_and_dest} #{where_src} GROUP BY directions.id"
      @res3 = ActiveRecord::Base.connection.select_all(sql)

      sql = "SELECT count(hcalls.id) as 'calls' FROM destinations " +
      "JOIN calls as hcalls on (hcalls.prefix = destinations.prefix) #{where} #{dest_dir_code} AND LENGTH(src) < 10 "
      @res2 = ActiveRecord::Base.connection.select_all(sql)
    end
  end

  def resellers
    @page_title, @page_icon = [_('Resellers'), 'user_gray.png']

    # The following if statement is required for rs, rs_pro addons limitation. #8466
    order = 'ORDER BY nice_user ASC'

    if reseller_pro_active?
      conditions = order
    elsif not reseller_active?
      first_reseller = User.where(own_providers: 0, usertype: 'reseller').first
      first_reseller_pro = User.where(own_providers: 1).first

      conditions = []
      conditions << "users.id = #{first_reseller.id}" if first_reseller
      conditions << "users.id = #{first_reseller_pro.id}" if first_reseller_pro
      conditions = 'AND (' + conditions.join(' OR ') + ')' + order
      conditions = ' LIMIT 0 ' if not first_reseller and not first_reseller_pro
    else
      first_reseller_pro = User.where(own_providers: 1).first
      conditions = ['own_providers = 0']
      conditions << "users.id = #{first_reseller_pro.id}" if first_reseller_pro
      conditions = 'AND (' + conditions.compact.join(' or ') + ')' + order
    end

    sql = "select users.id, users.username, users.first_name, users.last_name, s_calls.calls as 'f_calls',
      s_tariffs.tariffs as 'f_tariffs', s_cardgroups.cardgroups as 'f_cardgroups', s_cards.cards as 'f_cards',
      s_users.users as 'f_users', s_devices.devices as 'f_devices', acc_groups.name as 'group_name',
      acc_groups.id as 'group_id', s_dids.dids as f_dids, #{SqlExport.nice_user_sql}, own_providers
      from users
      LEFT JOIN acc_groups ON (users.acc_group_id = acc_groups.id)
      left join (SELECT COUNT(calls.id) as 'calls', reseller_id FROM calls group by calls.reseller_id) as s_calls on(s_calls.reseller_id = users.id)
      left join (SELECT COUNT(tariffs.id) as 'tariffs', owner_id FROM tariffs group by tariffs.owner_id) as s_tariffs on(s_tariffs.owner_id = users.id)
      left join (SELECT COUNT(cardgroups.id) as 'cardgroups', owner_id FROM cardgroups group by cardgroups.owner_id) as s_cardgroups on(s_cardgroups.owner_id = users.id)
      left join (SELECT COUNT(cards.id) as 'cards', owner_id FROM cards group by cards.owner_id) as s_cards on(s_cards.owner_id = users.id)
      left join (SELECT COUNT(users.id) as 'users', owner_id FROM users group by users.owner_id) as s_users on(s_users.owner_id = users.id)
      left join (SELECT COUNT(devices.id) as 'devices', users.owner_id FROM devices
                        left join users on (devices.user_id = users.id)
                        where users.owner_id > 0 group by users.owner_id) as s_devices on(s_devices.owner_id = users.id)
      left join (SELECT COUNT(dids.id) AS 'dids', reseller_id FROM dids GROUP BY dids.reseller_id) AS s_dids ON(s_dids.reseller_id = users.id)
      where (users.usertype = 'reseller' OR users.usertype = 'partner') and users.hidden = 0 AND users.owner_id = #{correct_owner_id}
      #{conditions}"
    @resellers = User.find_by_sql(sql)
  end

  def calls_per_day
    @page_title = _('Calls_per_day')
    @page_icon = 'chart_bar.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Calls_per_Day'

    change_date
    session[:hour_from], session[:minute_from], session[:hour_till], session[:minute_till] = ['00', '00', '23', '59']
    calls_per_day_options

    @data = EsCallsPerDay.get_data(
        {
            from: es_limit_search_by_days, till: es_session_till, can_see_finances: can_see_finances?, current_user: current_user
        }.merge(@options[:search])
    )
  end

  def calls_per_day_options
    @options = {select: {}, search: {}}
    @options[:select][:destination_groups] = Destinationgroup.select(:id, :name).order(:name)
    @options[:select][:providers] = Provider.select(:id, :name).where(hidden: 0).order(:name) if admin? || accountant?
    select_hash = {usertype: :reseller}
    select_hash[:responsible_accountant_id] = current_user.id if current_user.usertype == 'accountant' && current_user.show_only_assigned_users.to_i == 1
    @options[:select][:resellers] = User.select("id, #{SqlExport.nice_user_name_sql}").
        where((select_hash).merge(partner? ? {owner_id: current_user_id} : {})).order('nicename')

    if params[:s_user].blank?
      params[:s_user_id] = -1
    elsif %w[-2 -1 0].include?(params[:s_user_id].to_s)
      params[:s_user_id] = -2
    end

    @options[:search][:destination_group_id] = params[:destination_group_id]
    @options[:search][:provider_id] = params[:provider_id]
    @options[:search][:reseller_id] = params[:reseller_id]
    @options[:search][:s_user_id] = params[:s_user_id]
  end

  def first_activity
    @page_title = _('First_activity')
    @page_icon = "chart_bar.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/First_Activity"

    change_date

    @size = Action.set_first_call_for_user(session_from_date, session_till_date)

    @total_pages = (@size.to_d / session[:items_per_page].to_d).ceil

    @page = 1
    @page = params[:page].to_i if params[:page]
    @page = @total_pages.to_i if params[:page].to_i > @total_pages && @total_pages.to_i > 0
    @page = 1 if params[:page].to_i < 1

    @fpage = ((@page -1) * session[:items_per_page]).to_i


=begin
    sql = "SELECT calldate, user_id, card_id, c.sb, users.first_name, users.last_name, users.username
           FROM calls
              LEFT JOIN
                (SELECT COUNT(subscriptions.id) AS sb, subscriptions.user_id AS su_id
                  FROM subscriptions WHERE ((activation_start < '#{a1}' AND activation_end BETWEEN '#{a1}' AND '#{a2}') OR (activation_start BETWEEN '#{a1}' AND '#{a2}' AND activation_end < '#{a2}') OR (activation_start > '#{a1}' AND activation_end < '#{a2}') OR (activation_start < '#{a1}' AND activation_end > '#{a2}')) GROUP BY subscriptions.user_id) AS c on (c.su_id = calls.user_id )
              LEFT JOIN users on (users.id = calls.user_id)
           WHERE calldate < '#{session_till_datetime}' AND calls.user_id != -1
           GROUP BY user_id
           ORDER BY calldate ASC
           LIMIT #{@fpage}, #{@tpage}"
=end
    #my_debug sql

    #    sql3 = "SELECT actions.date as 'calldate', actions.data2 as 'card_id', c.sb, users.first_name, users.last_name, users.username, users.id, actions.user_id FROM users
    #              JOIN actions ON  (actions.user_id = users.id)
    #              LEFT JOIN
    #                (SELECT COUNT(subscriptions.id) AS sb, subscriptions.user_id AS su_id
    #                  FROM subscriptions WHERE ((activation_start < '#{a1}' AND activation_end BETWEEN '#{a1}' AND '#{a2}') OR (activation_start BETWEEN '#{a1}' AND '#{a2}' AND activation_end < '#{a2}') OR (activation_start > '#{a1}' AND activation_end < '#{a2}') OR (activation_start < '#{a1}' AND activation_end > '#{a2}')) GROUP BY subscriptions.user_id) AS c on (c.su_id = users.id )
    #              WHERE actions.action = 'first_call' and actions.date BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}'
    #              GROUP BY user_id
    #           ORDER BY date ASC
    #           LIMIT #{@fpage}, #{session[:items_per_page].to_i}"

    sql_query= "SELECT actions.date as 'calldate', actions.data2 as 'card_id', users.first_name, users.last_name, users.username, users.id, actions.user_id FROM users
                  JOIN actions ON  (actions.user_id = users.id)
           WHERE actions.action = 'first_call' and actions.date BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}'
           GROUP BY user_id
           ORDER BY date ASC
           LIMIT #{@fpage}, #{session[:items_per_page].to_i}"
    @res = ActiveRecord::Base.connection.select_all(sql_query)


    #    @all_res = @res
    #    @res = []
    #
    #    iend = ((session[:items_per_page] * @page) - 1)
    #    iend = @all_res.size - 1 if iend > (@all_res.size - 1)
    #    for i in ((@page - 1) * session[:items_per_page])..iend
    #      @res << @all_res[i]
    #    end
    #
    #
    #    @subscriptions = 0
    #    @user = []
    #    for r in @res
    #      @subscriptions+= r['sb'].to_i
    #      if (r['user_id'].to_i != -1) and (r['user_id'].to_s != "") and (r['card_id'].to_i == 0 )
    #        user = User.find(:first, :conditions => "id = #{r['user_id']}") if r['user_id'].to_s.length >= 0
    #        @user[r['user_id'].to_i] = user if r['user_id'].to_i >= 0
    #      end
    #    end
  end


  def subscriptions_stats
    @page_title = _('Subscriptions')
    @page_icon = "chart_bar.png"

    session[:subscriptions_stats_options] ? @options = session[:subscriptions_stats_options] : @options = {}
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 0 if !@options[:order_desc])
    params[:order_by] ? @options[:order_by] = params[:order_by].to_s : (@options[:order_by] = 'user' if !@options[:order_by])
    @options[:order] = Subscription.subscriptions_stats_order_by(@options)

    change_date
    datetime_from = session_from_date
    datetime_till = session_till_date
    @date_from = session_from_date
    sql = "SELECT COUNT(subscriptions.id) AS sub_size  FROM subscriptions
    WHERE ((activation_start < '#{datetime_from}' AND activation_end BETWEEN '#{datetime_from}' AND '#{datetime_till}') OR (activation_start BETWEEN '#{datetime_from}' AND '#{datetime_till}' AND activation_end < 'datetime_till') OR (activation_start > '#{datetime_from}' AND activation_end < '#{datetime_till}') OR (activation_start < '#{datetime_from}' AND activation_end > '#{datetime_till}'))"
    @res = ActiveRecord::Base.connection.select_all(sql)
    sql = "SELECT COUNT(subscriptions.id) AS sub_size  FROM subscriptions
    WHERE activation_start = '#{datetime_from}'"
    @res2 = ActiveRecord::Base.connection.select_all(sql)
    @res3 = Subscription.select("users.id, users.username, users.first_name, users.last_name, CONCAT(users.first_name, ' ', users.last_name) AS nice_user, activation_start, activation_end, added, subscriptions.id AS subscription_id, memo, services.name, services.name AS service_name, services.price AS service_price, services.servicetype AS servicetype, services.quantity, subscriptions.no_expire AS no_expire,  #{SqlExport.nice_user_sql}").where("((activation_start < '#{datetime_from}' AND activation_end BETWEEN '#{datetime_from}' AND '#{datetime_till}') OR (activation_start BETWEEN '#{datetime_from}' AND '#{datetime_till}' AND activation_end < 'datetime_till') OR (activation_start > '#{datetime_from}' AND activation_end < '#{datetime_till}') OR (activation_start < '#{datetime_from}' AND activation_end > '#{datetime_till}'))").joins("JOIN users on (subscriptions.user_id = users.id) JOIN services on (services.id = subscriptions.service_id)").order(@options[:order])

    params[:page] ? @page = params[:page].to_i : (@options[:page] ? @page = @options[:page] : @page = 1)
    @total_pages = (@res3.size.to_d / session[:items_per_page].to_d).ceil

    @all_res = @res3
    @res3 = []

    iend = ((session[:items_per_page] * @page) - 1)
    iend = @all_res.size - 1 if iend > (@all_res.size - 1)
    for item in ((@page - 1) * session[:items_per_page])..iend
      @res3 << @all_res[item]
    end
    @options[:page] = @page
    session[:subscriptions_stats_options] = @options
  end

  def subscriptions_first_day
    @page_title = _('First_day_subscriptions')
    @page_icon = "chart_bar.png"

    @date = session_from_date
    sql = "SELECT users.id, users.username, users.first_name, users.last_name FROM users
    JOIN (SELECT users.id AS suser_id, subscriptions.id as sub_id FROM users
    JOIN subscriptions ON (subscriptions.user_id = users.id AND subscriptions.activation_start BETWEEN '#{@date} 01:01:01' AND '#{@date} 23:59:59')
    GROUP BY users.id) as a on (users.id != a.suser_id )
    where users.owner_id='#{session[:user_id]}' and users.hidden = 0"
    result = ActiveRecord::Base.connection.select_all(sql)
    if result.size.to_i == 0
      sql = "SELECT users.id, users.username, users.first_name, users.last_name FROM users
      where users.owner_id='#{session[:user_id]}' and users.hidden = 0"
      result = ActiveRecord::Base.connection.select_all(sql)
    end
    @page = 1
    @page = params[:page].to_i if params[:page]

    @total_pages = (result.size.to_d / session[:items_per_page].to_d).ceil

    @all_res = result
    @res = []

    iend = ((session[:items_per_page] * @page) - 1)
    iend = @all_res.size - 1 if iend > (@all_res.size - 1)
    for index in ((@page - 1) * session[:items_per_page])..iend
      @res << @all_res[index]
    end

  end

  def action_log
    @page_title = _('Action_log')
    @page_icon = "chart_bar.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/Action_log"
    @searching = params[:search_on].to_i == 1
    @reviewed_labels = [[_('All'), -1], [_('Reviewed').downcase, 1], [_('Not_reviewed').downcase, 0]]

    change_date

    datetime_from = session_from_datetime
    datetime_till = session_till_datetime

    session[:action_log_stats_options] ? @options = session[:action_log_stats_options] : @options = {:order_by => "action", :order_desc => 0, :page => 1}

    # search paramaters
    params[:page] ? @options[:page] = params[:page].to_i : (params[:clean]) ? @options[:page] = 1 : (@options[:page] = 1 if !@options[:page])
    params[:action_type] ? @options[:s_type] = params[:action_type].to_s : (params[:clean]) ? @options[:s_type] = "all" : (@options[:s_type]) ? @options[:s_type] = session[:action_log_stats_options][:s_type] : @options[:s_type] = "all"

    # -1 find all users; -2 find nothing
    if params[:s_user].to_s == '' && @searching
      params[:s_user_id] = -1
    elsif %w[-2 -1].include?(params[:s_user_id].to_s)
      params[:s_user_id] = -2
    end
    (params[:s_user_id] && !params[:s_user_id].blank?) ? @options[:s_user] = params[:s_user_id].to_s : (params[:clean]) ? @options[:s_user] = -1 : params[:user_id] ? @options[:s_user] = params[:user_id] : (@options[:s_user]) ? @options[:s_user] = session[:action_log_stats_options][:s_user] : @options[:s_user] = -1
    params[:processed] ? @options[:s_processed] = params[:processed].to_s : (params[:clean]) ? @options[:s_processed] = -1 : (@options[:s_processed]) ? @options[:s_processed] = session[:action_log_stats_options][:s_processed] : @options[:s_processed] = -1
    # params[:s_int_ch]   ? @options[:s_int_ch] = params[:s_int_ch].to_i     : (params[:clean]) ? @options[:s_int_ch] = 0   : (@options[:s_int_ch])? @options[:s_int_ch] = session[:action_log_stats_options][:s_int_ch] : @options[:s_int_ch] = 0
    params[:target_type] ? @options[:s_target_type] = params[:target_type].to_s : (params[:clean]) ? @options[:s_target_type] = '' : (@options[:s_target_type]) ? @options[:s_target_type] = session[:action_log_stats_options][:s_target_type] : @options[:s_target_type] = ''
    params[:target_id] ? @options[:s_target_id] = params[:target_id].to_s : (params[:clean]) ? @options[:s_target_id] = '' : (@options[:s_target_id]) ? @options[:s_target_id] = session[:action_log_stats_options][:s_target_id] : @options[:s_target_id] = ''
    params[:did] ? @options[:s_did] = params[:did].to_s : (params[:clean]) ? @options[:s_did] = '' : (@options[:s_did]) ? @options[:s_did] = session[:action_log_stats_options][:s_did] : @options[:s_did] = ''

    change_date_to_present if params[:clean]

    time_now = current_user.user_time(Time.now)
    year, month, day = time_now.year.to_s, time_now.month.to_s, time_now.day.to_s
    from = session_from_datetime_array != [year, month, day, "0", "0", "00"]
    till = session_till_datetime_array != [year, month, day, "23", "59", "59"]

    @options[:search_on] = (from or till) ? 1 : 0

    # order
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 1 if !@options[:order_desc])
    params[:order_by] ? @options[:order_by] = params[:order_by].to_s : @options[:order_by] == "acc"
    order_by = Action.actions_order_by(@options)

    @res = Action.select("DISTINCT(actions.action)").order("actions.action").all
    @did = Did.where("did = '#{@options[:s_did]}'").first if !@options[:s_did].blank?
    @options[:s_did] = @did.id  if !@did.blank?

    if @searching
      cond, cond_arr, join = Action.condition_for_action_log_list(current_user, datetime_from, datetime_till, params[:s_int_ch], @options)

      if accountant? && @current_user.show_only_assigned_users == 1
        cond << "users.responsible_accountant_id = #{current_user.id}"
      end

      # page params
      @ac_size = Action.select("actions.id").where([cond.join(" AND ")] + cond_arr).joins(join).size
      @not_reviewed_actions = Action.where([(['processed = 0'] + cond).join(" AND ")] + cond_arr).joins(join).limit(1).size.to_i == 1
      @options[:page] = @options[:page].to_i < 1 ? 1 : @options[:page].to_i
      @total_pages = (@ac_size.to_d / session[:items_per_page].to_d).ceil
      @options[:page] = @total_pages if @options[:page].to_i > @total_pages.to_i and @total_pages.to_i > 0
      fpage = ((@options[:page] -1) * session[:items_per_page]).to_i
      @search = 1
      # search
      @actions = Action.select(" actions.*, #{SqlExport.nice_user_sql}, users.owner_id").
                        where([cond.join(" AND ")] + cond_arr).
                        joins(join).
                        order(order_by).
                        limit("#{fpage}, #{session[:items_per_page].to_i}")
    end
    @options[:s_did] = @did.did  if !@did.blank?
    session[:action_log_stats_options] = @options
  end

  def action_log_mark_reviewed
    datetime_from = session_from_datetime
    datetime_till = session_till_datetime
    session[:action_log_stats_options] ? @options = session[:action_log_stats_options] : @options = {:order_by => "action", :order_desc => 0, :page => 1}
    cond, cond_arr, join = Action.condition_for_action_log_list(current_user, datetime_from, datetime_till, 0, @options)
    @actions = Action.select(" actions.*").
                      where([cond.join(" AND ")] + cond_arr).
                      joins(join)

    if @actions
      @actions.each { |action|
        if action.processed == 0
          action.processed = 1
          action.save
        end
      }
    end
    flash[:status] = _('Actions_marked_as_reviewed')
    redirect_to :action => :action_log, :search_on => 1
  end

  def action_processed
    action = Action.find(params[:id])
    action.toggle_processed
    @user = params[:user].to_s
    @action = params[:s_action]
    @processed = params[:procc]
    flash[:status] = _('Action_marked_as_reviewed')
    redirect_to :action => "action_log", :user_id => @user, :processed => @processed, :action_type => @action, :search_on => 1
  end

  def load_stats
    @page_title, @page_icon, @searching = _('Load_stats'), 'chart_bar.png', params[:search_on].to_i == 1
    @help_link = 'http://wiki.kolmisoft.com/index.php/Simultaneous_Calls_stats'

    if %w[accountant admin].include?(session[:usertype])
      @providers = Provider.where(hidden: 0).order(:name).all
    else
      @providers = current_user.load_providers
    end

    @dids, @servers = Did.all, Server.where(server_type: 'asterisk') unless reseller?

    @default = {s_user: -1, s_provider: -1, s_device: -1, s_direction: -1, s_server: -1}
    @options = (session[:stats_load_stats_options] || @default)

    # -1 find all users, -2 find nothing
    if params[:s_user].to_s == ''
      params[:s_user_id] = -1
    elsif %w[-2 -1].include?(params[:s_user_id].to_s)
      params[:s_user_id] = -2
    end

    @options[:s_user] = params[:s_user_id] if params[:s_user_id]
    @options[:s_device] = params[:device_id] if params[:device_id]
    @devices = Device.where(user_id: params[:s_user_id]).all if params[:s_user_id].to_i >= 0

    [:s_provider, :s_direction].each { |key| @options[key] = params[key] if params[key] }
    [:s_did, :s_server].each { |key| @options[key] = params[key] if params[key] } unless reseller?

    if @searching
      change_date_from

      session[:year_till], session[:month_till], session[:day_till] =
          session[:year_from], session[:month_from], session[:day_from]
      session[:hour_from], session[:minute_from], session[:hour_till], session[:minute_till] = '00', '00', '23', '59'

      @options[:a1], @options[:a2], @options[:current_user] = limit_search_by_days, session_till_datetime, current_user

      @all_calls, answered_calls, highest_duration = Call.calls_for_load_stats(@options)

      all_calls_grouped, answered_calls_grouped, @calls_graph = {},  Array.new(1440, 0), ''

      @all_calls.each { |time_interval| all_calls_grouped[time_interval['call_minute']] = time_interval['calls'] }

      answered_calls.each do |call|
        (call['time_index_from']..(call['time_index_from'] + call['minute_duration'])).each do |time_interval|
          break if time_interval >= 1440
          answered_calls_grouped[time_interval] += call['calls_count']
        end
      end

      (0..23).each do |hour|
        (0..59).each do |minute|
          time_interval = "#{sprintf('%02d', hour)}:#{sprintf('%02d', minute)}"
          @calls_graph << "#{time_interval};#{answered_calls_grouped[hour * 60 + minute]};#{all_calls_grouped[time_interval] || 0}\\n"
        end
      end

      @calls_graph << "00:00;0;0\\n"
      flash[:notice] = _('db_error_broken_call_duration') if highest_duration.to_i > 36000
    end
  end

  def truncate_active_calls
    if admin?
      Activecall.delete_all
      redirect_to :controller => "stats", :action => "active_calls" and return false
    else
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
  end

  def server_load

    @page_title = _('server_load_stats')
    @page_icon  = 'chart_bar.png'
    @help_link  = 'http://wiki.kolmisoft.com/index.php/Server_load_stats'

    @cache = Proc.new do |param|
      if params[:date].blank?
        Time.now.send(param).to_i
      else
        params[:date].try(:[], param).to_i
      end
    end

    @common_stats = ['hdd_util','cpu_general_load','cpu_loadstats1']

    params[:id] = params[:server] if params[:server]
    @server     = params[:id].blank? ? Server.first : Server.where(id: params[:id]).first

    redirection_notice = ''

    unless @server
      redirection_notice = _('Server_not_found')
    end

    if @server.try(:server_type).to_s == 'sip_proxy'
      redirection_notice = _('Dont_be_so_smart')
    end

    if redirection_notice != ''
      flash[:notice] = redirection_notice
      (redirect_to :root) && (return false)
    end

    time = Time.mktime(@cache[:year],@cache[:month],@cache[:day]).strftime('%F')
    group_rule = 'year(datetime), month(datetime), day(datetime), hour(datetime), minute(datetime)'

    raw_data  = @server.server_loadstats.where("datetime like '#{time}%'").group(group_rule)
    @data     = Hash.new(('00:00'..'23:59').to_a.join("\\n"))

    @common_stats.each do |stat_name|
      results = raw_data.collect { |stat| stat.csv_line(stat_name) }.join("\\n")
      @data[stat_name.intern] = results unless results.blank?
    end

    varied_result = raw_data.collect { |stat| stat.csv_line(*@server.which_loadstats?) }.join("\\n")
    @data[:db_gui_core] = varied_result unless varied_result.blank?
  end

  def set_minutes_from_calldate(call_calldate)
    calldate = current_user.user_time(call_calldate).to_time
    (calldate.strftime('%H').to_i * 60) + calldate.strftime('%M').to_i
  end

  def provider_active_calls
    @page_title = _('Provider_Active_Calls')
    @page_icon  = 'chart_bar.png'
    @help_link  = 'http://wiki.kolmisoft.com/index.php/Provider_Active_Calls'
    @refresh_period = session[:active_calls_refresh_interval].to_i

    @data = Provider.active_calls_distribution.to_json except: [:id]

    respond_to do |format|
      format.html
      format.json { render json: @data }
    end
  end

  private

  def authorize_action_log
    if user? || (accountant? && session[:acc_action_log].to_i == 0)
      flash[:notice] = _('You_have_no_view_permission')
      (redirect_to :root) && (return false)
    end
  end

  def backup_path
    path = Confline.get_value('Backup_Folder')
  end

  def get_archived_calls
    files = `ls -t -1 #{backup_path} | grep -P "mor_archived_calls_from_\\d{4}\\w{3}\\d{2}-\\d{6}_to_\\d{4}\\w{3}\\d{2}-\\d{6}.tgz"`.split("\n")
  end

  def no_cache
    response.headers["Last-Modified"] = Time.now.httpdate
    response.headers["Expires"] = '0'
    # HTTP 1.0
    response.headers["Pragma"] = "no-cache"
    # HTTP 1.1 'pre-check=0, post-check=0' (IE specific)
    response.headers["Cache-Control"] = 'no-store, no-cache, must-revalidate, max-age=0, pre-check=0, post-check=0'
  end

  def active_calls_longer_error(calls)
    for call in calls
      ba = Thread.new { active_calls_longer_error_send_email(call['user_id'].to_s, call['provider_id'].to_s, call['server_id'].to_s); ActiveRecord::Base.connection.close }
      # ba.join #kam ji cia joininti?
      MorLog.my_debug 'active_calls_longer_error'
    end
  end

  def active_calls_longer_error_send_email(user, provider, server)
    address = Confline.get_value("Exception_Support_Email").to_s
    subject = "Active calls longer error on : #{Confline.get_value("Company")}"
    message = "URL:            #{Web_URL}\n"
    message += "User ID:        #{user.to_s}\n"
    message += "Provider ID:    #{provider.to_s}\n"
    message += "Server ID:      #{server.to_s}\n"
    message += "----------------------------------------\n"

    # disabling for now
    #`/usr/local/mor/sendEmail -f 'support@kolmisoft.com' -t '#{address}' -u '#{subject}' -s 'smtp.gmail.com' -xu 'crashemail1' -xp 'crashemail199' -m '#{message}' -o tls='auto'`
    MorLog.my_debug('Crash email sent')
  end

  def check_authentication
    redirect_to :root if current_user.nil?
  end

  def check_reseller_in_providers
    if reseller? and (current_user.own_providers.to_i == 0 or !reseller_pro_active?)
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
  end

  def find_user_from_id_or_session
    params[:id] ? user_id = params[:id] : user_id = session[:user_id]
    @user=User.where(["id = ?", user_id]).first

    unless @user
      flash[:notice] = _('User_was_not_found')
      (redirect_to :root) && (return false)
    end

    if session[:usertype] == 'reseller'
      if @user.id != session[:user_id] and @user.owner_id != session[:user_id]
        dont_be_so_smart
        (redirect_to :root) && (return false)
      end
    end

    if session[:usertype] == 'user' and @user.id != session[:user_id]
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
  end

  def last_calls_stats_parse_params(old = false, hide_non_answered_calls_for_user = false)
    default = {
        :items_per_page => session[:items_per_page].to_i,
        :page => "1",
        :s_direction => "outgoing",
        :s_call_type => "all",
        :s_device => "all",
        :s_provider => "all",
        :s_did_provider => "all",
        :s_hgc => 0,
        :search_on => 0,
        :s_user => '',
        :s_user_id => '-2',
        :user => nil,
        :s_did => "all",
        :s_did_pattern => "",
        :s_destination => "",
        :order_by => "time",
        :order_desc => 1,
        :s_country => '',
        :s_reseller => "all",
        :s_source => nil,
        :s_reseller_did => nil,
        :s_card_number => nil,
        :s_card_pin => nil,
        :s_card_id => nil,
        :show_device_and_cid => 0
    }

    options = ((params[:clear] || !session[:last_calls_stats]) ? default : session[:last_calls_stats])
    options[:items_per_page] = session[:items_per_page] if session[:items_per_page].to_i > 0
    default.each { |key, value| options[key] = params[key] if params[key] }

    change_date_to_present if params[:clear]

    if params[:s_user_id]
      options[:s_user_id] = ((params[:s_user_id] == '-2') && params[:s_user].present?) ? '' : params[:s_user_id]
    end

    options[:from] = old ? session_from_datetime : limit_search_by_days
    options[:till] = session_till_datetime
    options[:order_by_full] = options[:order_by] + (options[:order_desc] == 1 ? " DESC" : " ASC")
    options[:order] = old ? OldCall.calls_order_by(params, options) : Call.calls_order_by(params, options)
    options[:direction] = options[:s_direction]
    options[:call_type] = hide_non_answered_calls_for_user ? "answered" : options[:s_call_type]
    options[:destination] = options[:s_destination].to_s
    options[:source] = options[:s_source] if  options[:s_source]

    exchange_rate = Currency.count_exchange_rate(session[:default_currency], session[:show_currency]).to_d
    options[:exchange_rate] = exchange_rate
    options[:show_device_and_cid] = (params[:action].to_s == 'last_calls_stats' ||
                                     params[:action].to_s == 'last_calls_stats_totals') ?
                                      Confline.get_value('Show_device_and_cid_in_last_calls', correct_owner_id) : 0

    options
  end

  def last_calls_stats_user(user, options)
    devices = user.devices(:conditions => "device_type != 'FAX'")
    device = Device.where(:id => options[:s_device]).first if options[:s_device] != "all" and !options[:s_device].blank?
    return devices, device
  end

  def last_calls_stats_reseller(options)
    user = User.where(id: options[:s_user_id]).first if options[:s_user_id].present? && (options[:s_user_id] != '-2')

    if user
      device = Device.where(:id => options[:s_device]).first if options[:s_device] != "all" and !options[:s_device].blank?
      devices = user.devices(:conditions => "device_type != 'FAX'")
    else
      device, devices = [[], []]
    end

    if Confline.get_value('Show_HGC_for_Resellers').to_i == 1
      hgcs = Hangupcausecode.find_all_for_select
      hgc = Hangupcausecode.where(id: options[:s_hgc]).first if options[:s_hgc].to_i > 0
    end

    if current_user.reseller_allow_providers_tariff?
      providers = current_user.load_providers({select: "id, name", order: 'providers.name ASC'})

      if options[:s_provider].to_i > 0
        # provider = Provider.find(:first, :conditions => ["providers.id = ? OR common_use = 1", options[:s_provider]])
        provider = Provider.where(["providers.id = ?", options[:s_provider]]).first
        unless provider
          dont_be_so_smart
          (redirect_to :root) && (return false)
        end
      end
      if options[:s_did_provider].to_i > 0
        did_provider = Provider.where(["providers.id = ?", options[:s_did_provider]]).first
        unless did_provider
          dont_be_so_smart
          (redirect_to :root) && (return false)
        end
      end
    else
      providers = nil; provider = nil; did_provider = nil
    end
    did = Did.where(:id => options[:s_did]).first if options[:s_did] != "all" and !options[:s_did].blank?

    return user, devices, device, hgcs, hgc, providers, provider, did, did_provider
  end

  def last_calls_stats_admin(options)
    user = User.where(id: options[:s_user_id]).first if options[:s_user_id].present? && (options[:s_user_id] != '-2')

    if user
      device = Device.where(:id => options[:s_device]).first if options[:s_device] != "all" and !options[:s_device].blank?
      devices = user.devices(:conditions => "device_type != 'FAX'")
    else
      device, devices = [[], []]
    end

    did = Did.where(:id => options[:s_did]).first if options[:s_did] != "all" and !options[:s_did].blank?
    hgc = Hangupcausecode.where(:id => options[:s_hgc]).first if options[:s_hgc].to_i > 0
    hgcs = Hangupcausecode.find_all_for_select
    providers = Provider.find_all_for_select
    provider = Provider.where(:id => options[:s_provider]).first if options[:s_provider].to_i > 0
    did_provider = Provider.where(:id => options[:s_did_provider]).first if options[:s_did_provider].to_i > 0
    resellers_sql = "SELECT #{SqlExport.nice_user_sql}, id FROM users WHERE usertype = 'reseller' ORDER BY nice_user"
    resellers = ActiveRecord::Base.connection.select(resellers_sql)
    resellers_with_dids = User.joins('JOIN dids ON (users.id = dids.reseller_id)').where('usertype = "reseller"').group('users.id')
    resellers = [] if !resellers
    reseller = User.where(:id => options[:s_reseller]).first if options[:s_reseller] != "all" and !options[:s_reseller].blank?
    return user, devices, device, hgcs, hgc, did, providers, provider, reseller, resellers, resellers_with_dids, did_provider
  end

  def last_calls_stats_set_variables(options, values)
    options.merge(values.reject { |key, value| value.nil? })
  end

  def get_price_exchange(price, cur)
    exrate = Currency.count_exchange_rate(cur, current_user.currency.name)
    rate_cur = Currency.count_exchange_prices({:exrate => exrate, :prices => [price.to_d]})
    return rate_cur.to_d
  end

  def no_users
    if user?
      dont_be_so_smart and redirect_to :root
    end
  end

  def lambda_round_seconds
    @round_seconds = lambda do |seconds|
      mod = seconds % 15
      if mod.zero?
        seconds
      else
        seconds - mod
      end
    end
  end

  def create_graph_data_file
    # Find the data for the current and the previous day
    data_today = ActiveCallsData.find_by_day(Time.zone.now)
    data_yesterday = ActiveCallsData.find_by_day(Time.zone.now - 1.day)

    session[:active_calls_graph] = {
      last_count: data_today.blank? ? Time.zone.now.midnight : data_today.last.time
    }

    time = Time.now.midnight

    # Prepare array for graph data, interval - 60 seconds
    graph_array = []
    ((24*3600)/60).times do
     graph_array.push [time.strftime('%H:%M'), '0', '0']
     time += 60.seconds
    end

    data_yesterday.collect! {|data| [data.time.in_time_zone(user_tz).strftime('%H:%M'), data.count]}
    data_today.collect! {|data| [data.time.in_time_zone(user_tz).strftime('%H:%M'), data.count]}

    data_yesterday.each do |data|
      hour, minute, second = data[0].try(:split, ':')
      second = @round_seconds.call(second.to_i)
      graph_array[(hour.to_i * 3600 + minute.to_i * 60 + second)/60][2] = data[1]
    end

    data_today.each do |data|
      hour, minute, second = data[0].try(:split, ':')
      second = @round_seconds.call(second.to_i)
      graph_array[(hour.to_i * 3600 + minute.to_i * 60 + second)/60][1] = data[1]
    end

    # Generate the CSV data for the Graph to read
    csv = ''
    graph_array.each do |element|
      csv << element.try(:join, ';')
      csv << "\n"
    end

    # The graph reads its data from this file
    file = File.new("#{Actual_Dir}/public/tmp/active_calls.csv", 'w')
    file.write(csv)
    file.close
  end

  def clear_country_stats_search
    @options[:user_id] = -1
    change_date_to_present
  end

  def country_stats_parse_params
    @options = session[:country_stats] || {}

    if params[:s_user].to_s == ''
      params[:s_user_id] = -1
    elsif %w[-2 -1 0].include?(params[:s_user_id].to_s)
      params[:s_user_id] = -2
    end

    clear, user_id, params_user_id = params[:clear], @options[:user_id], params[:s_user_id]

    clear_country_stats_search if clear
    if params[:search_pressed] || @options[:start].blank? || clear
      @options[:start] = Time.parse(session_from_datetime)
      @options[:end] = Time.parse(session_till_datetime)
      @options[:user_id] = params_user_id.to_i if params_user_id
    end

    time_not_current = [[:start, '00'], [:end, '23']].any? do |key, hour|
      @options[key].strftime('%Y-%m-%d %H') != Time.current.strftime("%Y-%m-%d #{hour}")
    end

    @options[:show_clear] = time_not_current || (user_id && user_id != -1)
  end

  def check_if_searching
    @searching = params[:search_on].to_i == 1
  end

  def is_devices_for_scope_present
    devices_for_scope = Device.find_all_for_select(corrected_user_id, {count: true})
    @devices_for_scope_present = devices_for_scope[0].count_all.to_i > 0
  end

  def make_clause_by_ip_format(field, ip)
    ip_address_format = Device.define_ip_address_format(ip)
    ipaddr_clause = "(#{field} LIKE '#{ip}%' OR substring_index('#{ip}','.',3) = substring_index(#{field},'.',3) "

    case ip_address_format.to_s
    when '1'
      ipaddr_clause += "AND ((substring_index('#{ip}','.',-1) >= " +
        "substring_index(substring_index(#{field},'.',-1),'/',1) " +
      "AND substring_index('#{ip}','.',-1) <= CAST(substring_index(#{field},'/',-1) AS SIGNED) " +
      "AND #{field} LIKE '%/%') " +
      "OR (substring_index('#{ip}','.',-1) >= substring_index(substring_index(#{field},'.',-1),'-',1) " +
      "AND substring_index('#{ip}','.',-1) <= CAST(substring_index(#{field},'-',-1) AS SIGNED) " +
      "AND #{field} LIKE '%-%'))) "
    when '2'
      ipaddr_clause += "AND substring_index(substring_index('#{ip}','.',-1),'/',1) >= " +
      "substring_index(substring_index(#{field},'.',-1),'/',1) " +
      "AND substring_index('#{ip}','/',-1) <= CAST(substring_index(#{field},'/',-1) AS SIGNED) " +
      "AND #{field} LIKE '%/%') "
    when '3'
      ipaddr_clause += "AND substring_index(substring_index('#{ip}','.',-1),'-',1) >= " +
      "substring_index(substring_index(#{field},'.',-1),'-',1) " +
      "AND substring_index('#{ip}','-',-1) <= CAST(substring_index(#{field},'-',-1) AS SIGNED) " +
      "AND #{field} LIKE '%-%') "
    end
  end

  def providers_order_options
    options = session[:providers_order_options] || {}
    default = {
        order_by: 'name',
        order_desc: 0
    }

    default.each { |key, value| options[key] =  params[key] if params[key].present? }
    default.each { |key, value| options[key] =  value if options[key].blank? }

    unless ['name', 'tech', 'pcalls', 'billsec', 'answered', 'no_answer', 'busy', 'failed', 'failed_locally', 'ASR', 'ACD',
            'selfcost_price', 'sel_price', 'profit'].include?(options[:order_by])
      options[:order_by] = 'name'
    end
    options[:order_by_full] = options[:order_by] + (options[:order_desc].to_i == 1 ? " DESC" : " ASC")

    session[:providers_order_options] = options
  end

  def acc_manage_provider
    if !(accountant_can_read?('manage_provider') || accountant_can_write?('manage_provider'))
      flash[:notice] = _('You_have_no_view_permission')
      redirect_to(:root) && (return false)
    end
  end

  def manage_totals_cache(page_totals)
    @total_calls_stats = nil

    if params[:date_from].present? || !@searching || params[:currency].present?
      session[page_totals] = nil
    else
      @total_calls_stats = session[page_totals]
    end
  end

  def attributes_for_graphs(users = [])
    search_from = limit_search_by_days
    session[:hour_from] = "00"
    session[:minute_from] = "00"
    session[:hour_till] = "23"
    session[:minute_till] = "59"

    if @call_stats.blank?
      return false
      @searching = 0
    end

    @o_answered_calls = 0
    @o_no_answer_calls = 0
    @o_busy_calls = 0
    @o_failed_calls = 0
    @i_answered_calls = 0
    @i_no_answer_calls = 0
    @i_busy_calls = 0
    @i_failed_calls = 0
    @call_stats.each do |stats|
      direction = stats['direction'].to_s
      disposition = stats['disposition'].to_s.upcase
      total_calls = stats['total_calls'].to_i
      if  direction == 'outgoing'
        if disposition == 'ANSWERED'
          @o_answered_calls = total_calls
        elsif disposition == 'NO ANSWER'
          @o_no_answer_calls = total_calls
        elsif disposition == 'BUSY'
          @o_busy_calls = total_calls
        elsif disposition == 'FAILED'
          @o_failed_calls = total_calls
        end
      elsif direction == 'incoming'
        if disposition == 'ANSWERED'
          @i_answered_calls = total_calls
        elsif disposition == 'NO ANSWER'
          @i_no_answer_calls = total_calls
        elsif disposition == 'BUSY'
          @i_busy_calls = total_calls
        elsif disposition == 'FAILED'
          @i_failed_calls = total_calls
        end
      end
    end
    @outgoing_calls = @o_answered_calls + @o_no_answer_calls + @o_busy_calls + @o_failed_calls
    @incoming_calls = @i_answered_calls + @i_no_answer_calls + @i_busy_calls + @i_failed_calls
    @total_calls = @incoming_calls + @outgoing_calls

    sfd = session_time_from_db
    std = session_time_till_db

    @outgoing_perc = 0
    @outgoing_perc = @outgoing_calls.to_d / @total_calls * 100 if @total_calls > 0
    @incoming_perc = 0
    @incoming_perc = @incoming_calls.to_d / @total_calls * 100 if @total_calls > 0

    @o_answered_perc = 0
    @o_answered_perc = @o_answered_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0
    @o_no_answer_perc = 0
    @o_no_answer_perc = @o_no_answer_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0
    @o_busy_perc = 0
    @o_busy_perc = @o_busy_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0
    @o_failed_perc = 0
    @o_failed_perc = @o_failed_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0

    @i_answered_perc = 0
    @i_answered_perc = @i_answered_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0
    @i_no_answer_perc = 0
    @i_no_answer_perc = @i_no_answer_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0
    @i_busy_perc = 0
    @i_busy_perc = @i_busy_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0
    @i_failed_perc = 0
    @i_failed_perc = @i_failed_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0

    @t_answered_calls = @o_answered_calls + @i_answered_calls
    @t_no_answer_calls = @o_no_answer_calls + @i_no_answer_calls
    @t_busy_calls = @o_busy_calls + @i_busy_calls
    @t_failed_calls = @o_failed_calls + @i_failed_calls

    @t_answered_perc = 0
    @t_answered_perc = @t_answered_calls.to_d / @total_calls * 100 if @total_calls > 0
    @t_no_answer_perc = 0
    @t_no_answer_perc = @t_no_answer_calls.to_d / @total_calls * 100 if @total_calls > 0
    @t_busy_perc = 0
    @t_busy_perc = @t_busy_calls.to_d / @total_calls * 100 if @total_calls > 0
    @t_failed_perc = 0
    @t_failed_perc = @t_failed_calls.to_d / @total_calls * 100 if @total_calls > 0

    @a_date, @a_calls, @a_billsec, @a_avg_billsec, @total_sums = Call.answered_calls_day_by_day(limit_search_by_days, session_till_datetime, users, {es_enabled: true, es_session_from: es_session_from, es_session_till: es_session_till})

    @t_calls = @total_sums['total_calls'].to_i
    @t_billsec = @total_sums['total_billsec'].to_i
    @t_avg_billsec = @total_sums['average_billsec'].to_i

    index = @a_date.length

    # @t_avg_billsec =  @t_billsec / @t_calls if @t_calls > 0

    # formating graph for INCOMING/OUTGOING calls
    t_calls = @t_calls > 0
    if t_calls
      @Out_in_calls_graph = "['#{_('Outgoing')}', #{@outgoing_calls}], ['#{_('Incoming')}', #{@incoming_calls}]"
    else
      @Out_in_calls_graph = "['No result', 1]"
    end

    # formating graph for Call-type calls
    if t_calls
      @Out_in_calls_graph2 = ''
      @Out_in_calls_graph2 += "['#{_('ANSWERED')}', #{@t_answered_calls}],"
      @Out_in_calls_graph2 += "['#{_('NO_ANSWER')}', #{@t_no_answer_calls}],"
      @Out_in_calls_graph2 += "['#{_('BUSY')}', #{@t_busy_calls}],"
      @Out_in_calls_graph2 += "['#{_('FAILED')}', #{@t_failed_calls}]"
    else
      @Out_in_calls_graph2 = "['No result', 1]"
    end

    # formating graph for Calls
    @calls_graph = ''
    (0..@a_calls.size-1).each do |index|
      @calls_graph += "[new Date('#{@a_date[index]}'), #{@a_calls[index]}, '#{nice_date(@a_date[index])}; #{@a_calls[index]}'],"
    end

    # formating graph for Calltime

    @Calltime_graph = ''
    (0..@a_billsec.size-1).each do |index|
      @Calltime_graph += "[new Date('#{@a_date[index]}'), #{(@a_billsec[index].to_i / 60)}, '#{nice_date(@a_date[index])}; #{(@a_billsec[index].to_i / 60).round}'],"
    end

    # formating graph for Avg.Calltime
    @Avg_Calltime_graph = ''
    (0..@a_avg_billsec.size-1).each do |index|
      @Avg_Calltime_graph += "[new Date('#{@a_date[index]}'), #{(@a_avg_billsec[index])}, '#{nice_date(@a_date[index])}; #{(@a_avg_billsec[index]).round(2)}'],"
    end
  end

  def destination_flag_name
    if @options[:search][:prefix]
      destination = Destination.where('prefix LIKE ?', @options[:search][:prefix]).
          order('LENGTH(destinations.prefix) DESC').first

      if destination
        @options[:other] = {
            destination_flag: destination.direction_code,
            destination: "#{destination.direction.try(:name)} #{destination.name}".strip
        }
      end
    end
  end
end
