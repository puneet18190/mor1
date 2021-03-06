# -*- encoding : utf-8 -*-
# Aggregates, Call Summary and Call info.
class CallsController < ApplicationController
  include SqlExport
  include CsvImportDb
  include UniversalHelpers

  layout 'callc'
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_call,
                only: [
                    :call_info, :download_pcap, :pcap_image, :retrieve_call_details_pcap_text, :retrieve_call_log_text,
                    :retrieve_pcap_file, :retrieve_log_file, :wait_for_call_log
                ]
  before_filter :acc_permissions_tracing,
                only: [
                  :download_pcap, :pcap_image, :retrieve_call_details_pcap_text,
                  :retrieve_call_log_text, :retrieve_pcap_file, :retrieve_log_file,
                  :wait_for_call_log
                ]

  def aggregate
    unless reseller_pro?
      flash[:notice] = _('You_have_no_view_permission')
      (redirect_to :root) && (return false)
    end

    @page_title = _('Aggregate')
    @help_link = 'http://wiki.kolmisoft.com/index.php/Last_Calls#Call_information_representation'
    change_date
    @searching = params[:search_on].to_i == 1

    # If we have some options preset in session we can retreave them if not new options hash is created.
    @options = session[:aggregate_list_options] ? session[:aggregate_list_options] : {}

    params[:page] ? @options[:page] = params[:page].to_i : (@options[:page] = 1 if !@options[:page])
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 1 if !@options[:order_desc])
    params[:destination_grouping] ? @options[:destination_grouping] = params[:destination_grouping].to_i : (@options[:destination_grouping] = 1 if !@options[:destination_grouping])
    @options[:use_real_billsec] = params[:use_real_billsec]
    params[:from_user_perspective] ? @options[:from_user_perspective] = params[:from_user_perspective].to_i : (@options[:from_user_perspective] = 0 if !@options[:from_user_perspective])

    # default values for first collumn (selects and fields)
    if !session[:aggregate_list_options] or params[:search].to_i == 1
      (params[:originator] and params[:originator].to_s != "") ? @options[:originator] = params[:originator] : @options[:originator] = "any"
      (params[:terminator] and params[:terminator].to_s != "") ? @options[:terminator] = params[:terminator] : @options[:terminator] = "any"
      (params[:prefix] and params[:prefix].to_s != "") ? @options[:prefix] = params[:prefix] : @options[:prefix] = ""

      #default values for show/do not show checkboxes and collumns
      (params[:unique_id_show] and params[:unique_id_show].to_s != "") ? @options[:unique_id_show] = params[:unique_id_show].to_i : @options[:unique_id_show] = 1
      (params[:destination_show] and params[:destination_show].to_s != "") ? @options[:destination_show] = params[:destination_show].to_i : @options[:destination_show] = 1
      (params[:customer_orig_show] and params[:customer_orig_show].to_s != "") ? @options[:customer_orig_show] = params[:customer_orig_show].to_i : @options[:customer_orig_show] = 1
      (params[:customer_term_show] and params[:customer_term_show].to_s != "") ? @options[:customer_term_show] = params[:customer_term_show].to_i : @options[:customer_term_show] = 1
      (params[:ip_address_orig_show] and params[:ip_address_orig_show].to_s != "") ? @options[:ip_address_orig_show] = params[:ip_address_orig_show].to_i : @options[:ip_address_orig_show] = 1
      (params[:ip_address_term_show] and params[:ip_address_term_show].to_s != "") ? @options[:ip_address_term_show] = params[:ip_address_term_show].to_i : @options[:ip_address_term_show] = 1
      if can_see_finances?
        (params[:price_orig_show] and params[:price_orig_show].to_s != "") ? @options[:price_orig_show] = params[:price_orig_show].to_i : @options[:price_orig_show] = 1
        (params[:price_term_show] and params[:price_term_show].to_s != "") ? @options[:price_term_show] = params[:price_term_show].to_i : @options[:price_term_show] = 1
      end
      (params[:billed_time_orig_show] and params[:billed_time_orig_show].to_s != "") ? @options[:billed_time_orig_show] = params[:billed_time_orig_show].to_i : @options[:billed_time_orig_show] = 1
      (params[:billed_time_term_show] and params[:billed_time_term_show].to_s != "") ? @options[:billed_time_term_show] = params[:billed_time_term_show].to_i : @options[:billed_time_term_show] = 1
    end

    @options[:order_by], order_by = agregate_order_by(params, @options)
    if (@options[:destination_grouping].to_i == 1 and @options[:order_by] == "directions.name") or (@options[:destination_grouping].to_i == 2 and @options[:order_by] == "destinations.name")
      order_by = ''
      @options[:order_by] = ''
    end

    terminator_cond = @options[:terminator] != 'any' ? @options[:terminator] : ''

    # groups by those params that are not in search conditions
    group_by = []
    @options[:destination_grouping].to_i == 1 ? group_by << "ds.direction_code, ds.prefix" : group_by << "ds.direction_code"
    cond = []

    if @options[:customer_orig_show].to_i == 1 or @options[:customer_term_show].to_i == 1
      group_by << "dv.user_id" if @options[:originator] == "any"
      group_by << "p.terminator_id" if @options[:terminator] == "any"
    end

    # form condition array for sql
    cond2 = ["calldate BETWEEN '" + limit_search_by_days + "' AND '" + session_till_datetime + "'"]
    cond << "u.owner_id = #{current_user_id}" if reseller?

    cond << "(u.id = #{q(@options[:originator].to_i)} OR u.owner_id = #{q(@options[:originator].to_i)})" if @options[:originator] != "any"
    cond2 << "c.prefix LIKE '#{@options[:prefix]}'" if  @options[:prefix].to_s != ""
    if terminator_cond.to_s != ''
      cond << "p.terminator_id = #{terminator_cond.to_s}"
    else
      cond << "p.terminator_id > 0"
    end

    #limit terminators to allowed ones.
    term_ids = current_user.load_terminators_ids
    if term_ids.size == 0
      cond << "p.terminator_id = 0"
    else
      cond << "p.terminator_id IN (#{term_ids.join(", ")})"
    end

    # terminator requires other conditions

    if reseller?
      originating_billed = SqlExport.replace_price("SUM(IF(c.disposition = 'ANSWERED', if(c.user_price is NULL, 0, #{SqlExport.user_price_sql.gsub("calls.", "c.")}), 0))", {:reference => 'originating_billed'})
      originating_billsec = "SUM(IF(c.disposition = 'ANSWERED', IF(c.user_billsec IS NULL, 0, c.user_billsec), 0)) AS 'originating_billsec'"

      terminator_billed = SqlExport.replace_price("SUM(IF(c.disposition = 'ANSWERED', #{SqlExport.reseller_provider_price_sql.gsub("calls.", "c.").gsub("providers.", "p.")}, 0))", {:reference => 'terminating_billed'})
      terminator_billsec = "SUM(IF(c.disposition = 'ANSWERED', c.reseller_billsec, 0)) AS 'terminating_billsec'"
    else
      # Check if call belongs to resellers user if yes then admins income is reseller perice
      originating_billed = SqlExport.replace_price("SUM(IF(u.owner_id = 0 AND c.disposition = 'ANSWERED', if(c.user_price is NULL, 0, #{SqlExport.user_price_sql.gsub("calls.", "c.")}), IF(c.reseller_price IS NULL, 0, (c.reseller_price + c.did_inc_price))))", {:reference => 'originating_billed'})
      originating_billsec = "SUM(IF(u.owner_id = 0 AND c.disposition = 'ANSWERED', IF(c.user_billsec IS NULL, 0, c.user_billsec), IF(c.reseller_billsec IS NULL, 0, c.reseller_billsec))) AS 'originating_billsec'"

      terminator_billed = SqlExport.replace_price("(SUM(IF(c.disposition = 'ANSWERED', #{SqlExport.admin_provider_price_sql.gsub("calls.", "c.").gsub("providers.", "p.")}, 0)) - c.did_prov_price)", {:reference => 'terminating_billed'})
      terminator_billsec = "SUM(IF(c.disposition = 'ANSWERED', c.provider_billsec, 0)) AS 'terminating_billsec'"
    end

    billsec_option = "billsec"
    billsec_option = "real_" + billsec_option if @options[:use_real_billsec]

    if @options[:from_user_perspective].zero?
        table = "SELECT c.* FROM calls c WHERE " + cond2.join(" AND ")
    else
      table = "SELECT * FROM (SELECT c.* FROM calls c WHERE " + cond2.join(" AND ") + " ORDER BY id DESC) AS p GROUP BY uniqueid "
    end

    sql = "
    SELECT
    #{SqlExport.nice_user_sql("u")},
    c.prefix,
    ds.direction_code AS 'code',
    ds.name AS 'dest_name',
    u.username AS 'username',
    u.first_name AS 'first_name',
    u.last_name AS 'last_name',
    p.terminator_id AS 'terminator_id',

    #{[originating_billed, terminator_billed, originating_billsec, terminator_billsec].join(",\n")},

    SUM(IF(c.disposition = 'ANSWERED', c.#{billsec_option}, 0)) AS 'duration',
    COUNT(*) AS 'total_calls',
    SUM(IF(c.disposition = 'ANSWERED', 1,0)) AS 'answered_calls',
    SUM(IF(c.disposition = 'ANSWERED', 1,0))/COUNT(*)*100 AS 'asr',
    SUM(IF(c.disposition = 'ANSWERED', c.#{billsec_option}, 0))/SUM(IF(c.disposition = 'ANSWERED', 1,0)) AS 'acd'

    FROM (
      #{table}
    ) c

    JOIN providers p ON p.id = c.provider_id
    LEFT JOIN devices dv ON c.src_device_id = dv.id
    LEFT JOIN users u ON u.id = dv.user_id
    LEFT JOIN destinations ds ON ds.prefix = c.prefix
    #{"LEFT JOIN terminators t ON t.id = p.terminator_id" if @options[:order_by] == "terminators.name"}

    WHERE (" + cond.join(" AND ")+ ")
    #{group_by.size > 0 ? 'GROUP BY ' +group_by.join(", ") : ''}
    #{order_by.size > 0 ? 'ORDER BY ' +order_by : ''}"

    @result_full = @searching ? Call.find_by_sql(sql) : []
    @result = []
    @total_calls = @result_full.size if @result_full
    # calculate total values of dataset.
    @total = { billed_orig: 0, billed_term: 0, billsec_orig: 0, billsec_term: 0, duration: 0, total_calls: 0, asr: 0, acd: 0, answered_calls: 0 }
    @result_full.each { |row|
      @total[:billed_orig] += row.originating_billed.to_d
      @total[:billed_term] += row.terminating_billed.to_d
      @total[:billsec_orig] +=row.originating_billsec.to_d
      @total[:billsec_term] += row.terminating_billsec.to_d
      @total[:duration] += row.duration.to_d
      @total[:total_calls] += row.total_calls.to_i
      @total[:answered_calls] += row.answered_calls.to_i
    }
    @total[:total_calls] == 0 ? @total[:asr] = 0 : @total[:asr] = @total[:answered_calls].to_d/@total[:total_calls].to_d*100
    @total[:answered_calls] == 0 ? @total[:acd] = 0 : @total[:acd] = @total[:duration].to_d / @total[:answered_calls].to_d

    # fetch required number of items.
    @result = []
    start, @total_pages, @options = Application.pages_validator(session, @options, @total_calls)
    (start..(start+session[:items_per_page])-1).each { |i|
      @result << @result_full[i] if @result_full[i]
    }

    session[:aggregate_list_options] = { page: @options[:page], order_desc: @options[:order_desc],
                                        destination_grouping: @options[:destination_grouping],
                                        originator: @options[:originator], terminator: @options[:terminator],
                                        prefix: @options[:prefix], unique_id_show: @options[:unique_id_show],
                                        destination_show: @options[:destination_show], customer_orig_show: @options[:customer_orig_show],
                                        customer_term_show: @options[:customer_term_show], ip_address_orig_show: @options[:ip_address_orig_show],
                                        ip_address_term_show: @options[:ip_address_term_show], price_orig_show: @options[:price_orig_show],
                                        price_term_show: @options[:price_term_show], billed_time_orig_show: @options[:billed_time_orig_show],
                                        billed_time_term_show: @options[:billed_time_term_show], order_by: @options[:order_by],
                                        use_real_billsec: @options[:use_real_billsec] }

    #session[:aggregate_list_options] = @options
    # no need to store these 2 in session as they are not options but values from database.
    @options = load_parties(@options)

    if @options[:terminator] == "any"
      @terminator_providers_count = any_terminator_providers_count(@options[:terminators])
    else
      @terminator_providers_count = terminator_providers_count(@options[:terminators], @options[:terminator])
    end

    file = "/tmp/aggregate_csv_" + current_user_id.to_s + ".csv"
    dir_cache = {}
    term_cache = {}
    File.open( file, 'w' ) do |writer|
      @result_full.each do |row|
        line = []
        direction = dir_cache["d#{row.code}".to_sym] ||= Direction.where(["directions.code = ?", row.code]).first
        terminator = term_cache["t#{row.terminator_id}".to_sym] ||= Terminator.where(["terminators.id = ?", row.terminator_id]).first
        if @options[:destination_show].to_i == 1
          if @options[:destination_grouping].to_i == 1
            line << (direction ? direction.name.to_s.html_safe : "") + " " + " " + row.dest_name.to_s.html_safe + " ("+row.prefix.to_s + ")"
          else
            line << (direction ? direction.name.to_s.html_safe : "") + " " + " ("+row.prefix.to_s + ")"
          end
        end
        if @options[:customer_orig_show].to_i == 1
          line << nice_user_from_data(row.username, row.first_name, row.last_name).to_s.html_safe
        end
        if @options[:customer_term_show].to_i == 1
          line << (terminator ? terminator.name.to_s.html_safe : "")
        end
        if can_see_finances?
          if @options[:price_orig_show].to_i == 1
            line << nice_number(row.originating_billed) + " " + current_user.currency.name
          end
          if @options[:price_term_show].to_i == 1
            line << nice_number(row.terminating_billed) + " " + current_user.currency.name
          end
        end
        if @options[:billed_time_orig_show].to_i == 1
          line << nice_time(row.originating_billsec)
        end
        if @options[:billed_time_term_show].to_i == 1
          line << nice_time(row.terminating_billsec)
        end
        line << nice_time(row.duration)
        line << row.answered_calls.to_i
        line << row.total_calls
        line << nice_number(row.asr)
        line << nice_time(row.acd)
        writer << line.join(";")
        writer << "\n"
      end
    end
  end

    # Call summary.
  def summary
    unless reseller_pro?
      flash[:notice] = _('You_have_no_view_permission')
      (redirect_to :root) && (return false)
    end

    @page_title = _('Summary')
    change_date
    @searching = params[:search_on].to_i == 1
    search_from = limit_search_by_days

    session[:summary_list_options] ? @options = session[:summary_list_options] : @options = {}

    params[:page] ? @options[:page] = params[:page].to_i : (@options[:page] = 1 if !@options[:page])

    params[:term_order_desc] ? @options[:term_order_desc] = params[:term_order_desc].to_i : (@options[:term_order_desc] = 1 if !@options[:order_desc])
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : (@options[:order_desc] = 1 if !@options[:order_desc])
    params[:order_by] ? @options[:order_by_name] = params[:order_by].to_s : (@options[:order_by_name] = "" if !@options[:order_by_name])

    if !session[:summary_list_options] or params[:search].to_i == 1
      (params[:originator] and params[:originator].to_s != "") ? @options[:originator] = params[:originator] : @options[:originator] = "any"
      (params[:terminator] and params[:terminator].to_s != "") ? @options[:terminator] = params[:terminator] : @options[:terminator] = "any"
      (params[:prefix] and params[:prefix].to_s != "") ? @options[:prefix] = params[:prefix].gsub(/[^0-9]/, "") : @options[:prefix] = ""
    end

    @options[:terminator] != "any" ? terminator_cond = @options[:terminator] : terminator_cond = ""

    cond = ["calldate BETWEEN '" + search_from + "' AND '" + session_till_datetime + "'"]
    # cond << "calls.user_id != -1"
    cond << "calls.user_id IN (SELECT id FROM users WHERE id = #{@options[:originator].to_i} OR users.owner_id = #{@options[:originator].to_i})" if @options[:originator] != "any"
    cond << "calls.prefix LIKE '#{@options[:prefix].gsub(/[^0-9]/, "")}%'" if  @options[:prefix].to_s != ""

    @options[:order_by], order_by = summary_order_by(params, @options)

    (@options[:order_by_name].to_s.scan(/term_/).size > 0) ? order_by_desc = order_by : order_by_desc = ""

    @terminator_lines = @searching ? Call.summary_by_terminator(cond, terminator_cond, order_by_desc, current_user) : []

    @total_items_term = @terminator_lines.size

    @total = { term_calls: 0, term_min: 0, term_exact_min: 0, term_amount: 0,
              orig_calls: 0, orig_min: 0, orig_exact_min: 0, orig_amount: 0, orig_amount_with_vat: 0 }
    @terminator_lines.each { |row|
      @total[:term_calls] += row.total_calls.to_i
      @total[:term_exact_min] += row.exact_billsec.to_d
      @total[:term_min] += row.provider_billsec.to_d
      @total[:term_amount] += row.provider_price.to_d
    }

    (@options[:order_by_name].to_s.scan(/orig_/).size > 0) ? order_by_orig = order_by : order_by_orig = ""
    @originator_lines_full = @searching ? Call.summary_by_originator(cond, terminator_cond, order_by_orig, current_user) : []
    @originator_lines_full.each { |row|
      @total[:orig_calls] += row.total_calls.to_i
      @total[:orig_exact_min] += row.exact_billsec.to_d
      @total[:orig_min] += row.originator_billsec.to_d
      @total[:orig_amount] += row.originator_price.to_d
      @total[:orig_amount_with_vat] += row.originator_price_with_vat.to_d
    }

    start, @total_pages, @options = Application.pages_validator(session, @options, @originator_lines_full.size)

    @originator_lines = []
    start = session[:items_per_page]*(@options[:page]-1)
    (start..(start+session[:items_per_page]-1)).each { |item|
      @originator_lines << @originator_lines_full[item] if @originator_lines_full[item]
    }

    # session[:summary_list_options] = @options <Ã¢ÂÂÃ¢ÂÂ never do this. fills session with objects and overloads

    session[:summary_list_options] = { page: @options[:page], term_order_desc: @options[:term_order_desc], order_desc: @options[:order_desc], order_by_name: @options[:order_by_name], order_by: @options[:order_by], originator: @options[:originator], terminator: @options[:terminator], prefix: @options[:prefix] }

    @options = load_parties(@options)

    if @options[:terminator] == "any"
      @terminator_providers_count = any_terminator_providers_count(@options[:terminators])
    else
      @terminator_providers_count = terminator_providers_count(@options[:terminators], @options[:terminator])
    end
  end

  def active_call_soft_hangup
    uniqueid, server_id, channel = params[:uniqueid], params[:server_id].to_i, params[:channel].to_s

    %x`fs_cli -x 'uuid_kill #{uniqueid}'`

    if server_id > 0 && channel.length > 0
      server = Server.where(id: server_id, server_type: :asterisk).first
      server.ami_cmd("channel request hangup #{channel}") if server
    end

    MorLog.my_debug "Hangup channel: #{channel} on server: #{server_id}"
    render(layout: 'layouts/mor_min')
  end

  def call_info
    @page_title = _('Call_info')
    @page_icon = 'information.png'
    @help_link = 'http://wiki.kolmisoft.com/index.php/Call_Info'

    @did = nil
    @did = Did.where(["id = ?", @call.did_id.to_i]).first if @call.did_id.to_i > 0

    @user = nil
    @user = User.where(["id = ?", @call.user_id.to_i]).first if @call.user_id.to_i >= 0

    @src_device = nil
    @src_device = Device.where(["id = ?", @call.src_device_id.to_i]).first if @call.src_device_id.to_i >= 0

    @reseller = nil
    @reseller = User.where(["id = ?", @call.reseller_id.to_i]).first if @call.reseller_id.to_i > 0

    @provider = nil
    @provider = Provider.where(["providers.id = ?", @call.provider_id.to_i]).includes(:user).first if @call.provider_id.to_i > 0

    @card = nil
    @card = Card.where(["id = ?", @call.card_id.to_i]).first if @call.card_id.to_i > 0

    @call_log = @call.call_log

    @call_details = CallDetail.where(call_id: @call.id).first
  end

  def download_pcap
    if pcap = CallDetail.where(call_id: @call.id).first.try(:pcap)
      send_data(hex_to_bytes(pcap), filename: "call_#{@call.id}.pcap", type: 'application/octet-stream')
    end
  end

  def pcap_image
    if pcap_graph = CallDetail.where(call_id: @call.id).first.try(:pcap_graph)
      send_data(hex_to_bytes(pcap_graph), type: 'image/png', disposition: 'inline')
    end
  end

  def retrieve_call_details_pcap_text
    call_detail = CallDetail.where(call_id: @call.id).first
    render(json: call_detail.try(:nice_pcap_text) || [])
  end

  def retrieve_pcap_file
    server = Server.where(id: @call.server_id).first
    unless server
      flash[:notice] = "#{_('Server_Not_Found')}"
      (redirect_to :root) && (return false)
    end
    # Perform the retrieval procedure locally/remotely
    request = @call.pcap_file_request
    if server.local?
      system(request)
    else
      begin
        Net::SSH.start(
          server[:server_ip].to_s, server[:ssh_username].to_s,
          port: server[:ssh_port].to_i, timeout: 10,
          keys: %w(/var/www/.ssh/id_rsa), auth_methods: %w(publickey)
        ) { |ssh| ssh.exec! request }
      rescue Net::SSH::Exception, SystemExit, ScriptError, StandardError => error
        MorLog.my_debug "Retrieve PCAP error: #{error.message}"
        flash[:notice] = _('Cannot_connect_to_core_server')
      end
    end
    # Script takes a few seconds to complete
    sleep(6)
    # Script could not generate a PCAP file
    unless CallDetail.where(call_id: @call.id).first.try(:pcap)
      flash[:notice] = _('PCAP_file_does_not_exist')
    end
    (redirect_to(action: :call_info, id: params[:id])) && (return true)
  end

  def retrieve_log_file
    # Create new empty call_logs record and set uniqueid
    # Due to technical reasons, executed script cannot create call_logs records therefore we create this record here
    # Executed script can only update this record
    call_uniqueid = @call.uniqueid
    CallLog.create(uniqueid: call_uniqueid) unless CallLog.where(uniqueid: call_uniqueid).first
    # Set request (path to mor_call_log script with arguments)
    request = @call.call_log_request
    # Send request to specific asterisk server via SSH unless server is local
    server = Server.where(id: @call.server_id).first

    if server.local?
      # Execute request locally
      system(request)
    else
      begin
        # Execute request via SSH
        Net::SSH.start(
          server[:server_ip].to_s, server[:ssh_username].to_s,
          port: server[:ssh_port].to_i, timeout: 10,
          keys: %w(/var/www/.ssh/id_rsa), auth_methods: %w(publickey)
        ) { |ssh| ssh.exec! request }
      rescue Net::SSH::Exception, SystemExit, ScriptError, StandardError => error
        MorLog.my_debug "Retrieve Call Log error: #{error.message}"
        flash[:notice] = _('Cannot_connect_to_core_server')
      end
    end

    (redirect_to(action: :call_info, id: params[:id])) && (return true)
  end

  def retrieve_call_log_text
    call_log = CallLog.where(uniqueid: @call.uniqueid).first
    render(json: call_log.try(:nice_log_text) || [])
  end

  def try_aggregate_to_csv
    @filename = '/tmp/aggregate_csv_' + current_user_id.to_s + '.csv'

    if File.exist?(@filename)
      aggregate_to_csv
    else
      aggregate
      aggregate_to_csv
    end
  end

  # to download created csv of aggregate current search
  def aggregate_to_csv
    @filename = '/tmp/aggregate_csv_' + current_user_id.to_s + '.csv'

    if params[:test].to_i == 0
      File.open(@filename, 'r') do |file|
        send_data file.read, type: 'text/csv', filename: 'Aggregate.csv'
      end
    else
      File.open(@filename, 'r') do |file|
        render text: file.read
      end
    end
  end

  private

  def terminator_providers_count(terminators, terminator_id)
    count = 0
    terminators.each do |terminator|
      count = terminator.providers_size.to_i if terminator.id.to_s == terminator_id
    end
    return count
  end

  def any_terminator_providers_count(terminators)
    count = 0
    terminators.each { |terminator| count += terminator.providers_size.to_i }
    return count
  end

  def load_parties(options)
    options[:originators] = current_user.load_users
    options[:terminators] = current_user.load_terminators
    options
  end

  def agregate_order_by(params, options)
    case params[:order_by].to_s
      when "direction" then
        order_by = "destinations.direction_code"
      when "destination" then
        order_by = "destinations.name"
      when "customer_orig" then
        order_by = "nice_user"
      when "customer_term" then
        order_by = "terminators.name"
      when "billed_orig" then
        order_by = "originating_billed"
      when "billed_term" then
        order_by = "terminating_billed"
      when "billsec_orig" then
        order_by = "originating_billsec"
      when "billsec_term" then
        order_by = "terminating_billsec"
      when "duration" then
        order_by = "duration"
      when "answered_calls" then
        order_by = "answered_calls"
      when "total_calls" then
        order_by = "total_calls"
      when "asr" then
        order_by = "asr"
      when "acd" then
        order_by = "acd"
      else
        options[:order_by] ? order_by = options[:order_by] : order_by = ''
    end

    without = order_by
    order_by = "users.first_name " + (options[:order_desc] == 1 ? "DESC" : "ASC") + ", users.last_name" if order_by.to_s == "users.first_name"
    order_by = "ds.direction_code " + (options[:order_desc] == 1 ? "DESC" : "ASC") + ", ds.name" if order_by.to_s == "destinations.name"
    order_by = "ds.direction_code " + (options[:order_desc] == 1 ? "DESC" : "ASC") if order_by.to_s == "destinations.name"
    order_by = "t.name" if order_by.to_s == "terminators.name"

    order_by += " ASC" if options[:order_desc] == 0 && order_by != ''
    order_by += " DESC" if options[:order_desc] == 1 && order_by != ''
    return without, order_by
  end

 # Transaltes order_by param to database fields for summary report.
  def summary_order_by(params, options)
    case params[:order_by].to_s
      when "orig_name" then
        order_by = "u.first_name"
      when "orig_calls" then
        order_by = "total_calls"
      when "orig_exec_billsec" then
        order_by = "exact_billsec"
      when "orig_billsec" then
        order_by = "originator_billsec"
      when "orig_price" then
        order_by = "originator_price"
      when "orig_price_with_vat" then
        order_by = "originator_price_with_vat"

      when "term_name" then
        order_by = "provider_name"
      when "term_calls" then
        order_by = "total_calls"
      when "term_exec_billsec" then
        order_by = "exact_billsec"
      when "term_billsec" then
        order_by = "provider_billsec"
      when "term_price" then
        order_by = "provider_price"
      else
        options[:order_by] ? order_by = options[:order_by] : order_by = ""
    end
    without = order_by

    order_by = "users.first_name " + (options[:order_desc] == 1 ? "DESC" : "ASC") + ", users.last_name" if order_by.to_s == "users.first_name"

    order_by += " ASC" if options[:order_desc] == 0 && order_by != ''
    order_by += " DESC" if options[:order_desc] == 1 && order_by != ''
    return without, order_by
  end

  def find_call
    unless @call = Call.where(id: params[:id]).first
      flash[:notice] = _('Call_not_found')
      redirect_to(:root) && (return false)
    end

    # Only admin and accountant can view call info
    if current_user && !admin? && !accountant?
      flash[:notice] = _('You_have_no_view_permission')
      redirect_to(:root) && (return false)
    end
  end

  def acc_permissions_tracing
    if !admin? && !(accountant? && session[:acc_call_tracing_usage].to_i == 1)
      flash[:notice] = _('You_have_no_view_permission')
      redirect_to(:root) && (return false)
    end
  end
end
