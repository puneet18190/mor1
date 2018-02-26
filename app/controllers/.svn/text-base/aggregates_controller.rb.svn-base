# -*- encoding : utf-8 -*-
# Aggregated Calls' statistics.
class AggregatesController < ApplicationController

  layout 'callc'

  include UniversalHelpers
  before_filter :check_localization
  before_filter :check_post_method, only: [:aggregates_download_table_data]
  before_filter :access_denied, except: [:calls_per_hour], if: -> { !current_user.present? || user? }
  before_filter :calls_per_hour_access_denied, only: [:calls_per_hour],
                if: -> { !current_user.present? || user? || reseller? }
  before_filter :reset_min_sec, only: [:list]

  def list
    @page_title = _('calls_aggregate')
    @help_link = 'http://wiki.kolmisoft.com/index.php/Last_Calls#Call_information_representation'
    @searching = params[:search_on].to_i == 1
    clean = params[:clean].to_i == 1
    search_pressed = params[:search_pressed]

    change_date
    reset_min_sec

    if @searching && Time.parse(session_from_datetime) > Time.parse(session_till_datetime)
      redirect_to(action: :list) && (return false)
    end

    @options = session[:aggregate_options] ||= {}

    if @options.blank? || search_pressed || clean
      @default = !@searching
      set_checkboxes
      # unless search_pressed
      if !search_pressed
        @options[:originator] = ''
        @options[:originator_id] = 'any'
        @options[:terminator] = '0'
        @options[:destination_group] = '0'
        @options[:prefix] = ''
        @options[:use_real_billsec] = 0
        @options[:from_user_perspective] = 0
        @options[:answered_calls] = 1
        change_date_to_present
      end
    end

    time = current_user.user_time(Time.now)
    year = time.year
    month = time.month
    day = time.day
    @from = (session_from_datetime_array.map(&:to_i) != [year, month, day, 0, 0, 0])
    @till = (session_till_datetime_array.map(&:to_i) != [year, month, day, 23, 59, 59])

    @terminators = current_user.load_terminators
    @destination_groups = Destinationgroup.order(:name).all

    if search_pressed
      @search_values = params.select { |key, _|
        ['terminator', 'prefix', 'destination_group', 'use_real_billsec', 'from_user_perspective', 'answered_calls'].member?(key)
      }.symbolize_keys
      @search_values[:answered_calls] = '1' if @search_values[:answered_calls] == ''

      params_originator, params_originator_id = [params[:s_originator], params[:s_originator_id]]

      case params_originator.downcase
        when 'any'
          params_originator_id = 'any'
        when 'none'
          params_originator_id = 'none'
      end

      @search_values[:originator], @search_values[:originator_id] = [params_originator, params_originator_id]
      return false if params_originator.present? && (params_originator_id == '-2')

      @options.merge!(@search_values) if @search_values.present?
    end

    if @searching
      @data = EsAggregates.get_data(
          aggregates_data_search_variables.merge(current_user: current_user)
      )
    end
    session[:aggregate_options] = @options
  end

  def aggregates_download_table_data
    filename = aggregates_download_table_csv(params, current_user)
    filename = archive_file_if_size(filename, 'csv', Confline.get_value('CSV_File_size').to_d)

    cookies['fileDownload'] = 'true'
    send_data(File.open(filename).read, filename: filename.sub('/tmp/', ''))
  end

  def calls_per_hour
    @page_title, @page_icon = _('Calls_per_Hour'), 'chart_bar.png'
    calls_per_hour_search_options

    if @options[:searching]
      @es_calls_per_hour = EsCallsPerHour.get_data(
          calls_per_hour_data_search_variables.merge(current_user: current_user)
      )
    end
  end

  def calls_per_hour_data_expand
    data = EsCallsPerHour.get_data(calls_per_hour_data_expand_params.merge(current_user: current_user))
    output = calls_per_hour_data_expand_rows(data, params)
    render(text: output)
  end

  private

  def aggregates_download_table_csv(params, user)
    require 'csv'

    filename = 'Aggregates'
    sep, dec = user.csv_params

    table_data = JSON.parse(params[:table_content])
    table_data_keys = table_data.present? ? table_data[0].keys : []

    CSV.open('/tmp/' + filename + '.csv', 'w', {col_sep: sep, quote_char: "\""}) do |csv|
      headers = []
      table_data_keys.each do |header|
        headers << case header
                     when _('Originator')
                       "#{_('Customer')} #{_('Originator')}"
                     when _('Terminator')
                       "#{_('Customer')} #{_('Terminator')}"
                     when "#{_('Originator')} (#{user.currency.name})"
                       "#{_('Billed')} #{_('Originator')}"
                     when "#{_('Originator_Price_with_Vat')} (#{user.currency.name})"
                       "#{_('Billed')} #{_('Originator_Price_with_Vat')}"
                     when "#{_('Terminator')} (#{user.currency.name})"
                       "#{_('Billed')} #{_('Terminator')}"
                     when " #{_('Originator')} "
                       "#{_('Billed_Duration')} #{_('Originator')}"
                     when " #{_('Terminator')} "
                       "#{_('Billed_Duration')} #{_('Terminator')}"
                     else
                       header
                   end
      end

      csv << headers

      table_data.each_with_index do |line|
        data_line = []

        data_line << line[_('Destination_Group')] if table_data_keys.include?(_('Destination_Group'))
        data_line << line[_('Prefix')] if table_data_keys.include?(_('Prefix'))
        data_line << line[_('Originator')] if table_data_keys.include?(_('Originator'))
        data_line << line[_('Terminator')] if table_data_keys.include?(_('Terminator'))

        data_line << line["#{_('Originator')} (#{user.currency.name})"].gsub(/(,|;)/, '.').to_f.to_s.gsub('.', dec) if table_data_keys.include?("#{_('Originator')} (#{user.currency.name})")
        data_line << line["#{_('Originator_Price_with_Vat')} (#{user.currency.name})"].gsub(/(,|;)/, '.').to_f.to_s.gsub('.', dec) if table_data_keys.include?("#{_('Originator_Price_with_Vat')} (#{user.currency.name})")
        data_line << line["#{_('Terminator')} (#{user.currency.name})"].gsub(/(,|;)/, '.').to_f.to_s.gsub('.', dec) if table_data_keys.include?("#{_('Terminator')} (#{user.currency.name})")

        data_line << nice_time(line[" #{_('Originator')} "].to_i) if table_data_keys.include?(" #{_('Originator')} ")
        data_line << nice_time(line[" #{_('Terminator')} "].to_i) if table_data_keys.include?(" #{_('Terminator')} ")
        data_line << nice_time(line[_('Duration')].to_i) if table_data_keys.include?(_('Duration'))

        data_line << line[_('Answered_calls')].to_i if table_data_keys.include?(_('Answered_calls'))
        data_line << line[_('Total_calls')].to_i if table_data_keys.include?(_('Total_calls'))

        data_line << line["#{_('ASR')} %"].gsub(/(,|;)/, '.').to_f.to_s.gsub('.', dec) if table_data_keys.include?("#{_('ASR')} %")
        data_line << nice_time(line[_('ACD')].to_i) if table_data_keys.include?(_('ACD'))

        csv << data_line
      end
    end

    return filename
  end

  def set_checkboxes
    checkboxes = ['price_orig_show',
                  'price_term_show',
                  'billed_time_orig_show',
                  'billed_time_term_show',
                  'duration_show',
                  'acd_show',
                  'calls_answered_show',
                  'asr_show',
                  'calls_total_show']

    checkboxes.each do |check|
      check = check.to_sym
      @options[check] = if @default
                          1
                        else
                          if params[:search_pressed].present? && params[:date_from].blank?
                            @options[check]
                          else
                            params[check].to_i
                          end
                        end
    end

    # if accountant dont have permission to see financial data, information about prices must be hidden
    @options[:price_orig_show], @options[:price_orig_show] = [0, 0] unless can_see_finances?
  end

  def reset_min_sec
    session[:minute_from], session[:minute_till] = '00', '59'
  end

  def aggregates_data_search_variables
    search_values = params.select { |key, _|
      %w[terminator prefix destination_group use_real_billsec from_user_perspective answered_calls].member?(key)
    }.symbolize_keys

    search_values[:answered_calls] = '1' if search_values[:answered_calls] == ''

    params_originator, params_originator_id = [params[:s_originator], params[:s_originator_id]]
    case params_originator.to_s.downcase
      when 'any'
        params_originator_id = -2
      when 'none'
        params_originator_id = -1
    end

    case params_originator_id.to_s.downcase
      when 'any'
        params_originator_id = -2
      when 'none'
        params_originator_id = -1
    end

    search_values[:originator], search_values[:originator_id] = [params_originator, params_originator_id]

    search_values[:from] = es_session_from
    search_values[:till] = es_session_till

    search_values
  end

  def calls_per_hour_search_options
    change_date
    @options = params
    @options[:terminators] = current_user.load_terminators

    if @options.try(:[], [:searching]) && Time.parse("#{session_from_date} 00:00:00") > Time.parse("#{session_till_date} 23:59:59")
      redirect_to(action: :calls_per_hour) && (return false)
    end

    if params[:search_pressed]
      @options[:searching] = true
    elsif params[:clear]
      @options[:searching] = false
      change_date_to_present
    end
  end

  def calls_per_hour_data_search_variables
    {
        from: es_session_from, till: es_session_till,
        prefix: @options[:prefix].to_s.strip,
        terminator: @options[:terminator].to_i,
        user: @options[:s_user].blank? ? 0 : @options[:s_user_id].to_i
    }
  end

  def calls_per_hour_data_expand_params
    query_date = DateTime.strptime(params[:day], session[:date_format].to_s).strftime('%Y-%m-%d')
    query_time = params[:time].to_s.split(' ').last
    array_of_hours = []
    query_time.present? ? 2.times { |time| array_of_hours << query_time.to_i } : array_of_hours = [00, 23]
    time_from, time_till = ["#{query_date} #{array_of_hours[0]}:00:00", "#{query_date} #{array_of_hours[1]}:59:59"]

    level = params[:row_id].to_s.count('.').to_i
    search_user = params[:search_user]
    search_terminator = params[:search_terminator]
    search_prefix = params[:search_prefix]
    originator_id = search_user.to_i > 0 ? search_user : params[:originator]
    terminator_id = search_terminator if search_terminator.to_i > 0
    query_destination = search_prefix.present? ? search_prefix : params[:destination].to_s.split('(').last.try(:chop)
    query_date_time_from, query_date_time_till = Time.parse(current_user.system_time(time_from)).to_s[0, 19].sub(' ', 'T'), Time.parse(current_user.system_time(time_till)).to_s[0, 19].sub(' ', 'T')

    {
        from: query_date_time_from, till: query_date_time_till,
        prefix: query_destination,
        terminator: terminator_id.to_i,
        user: originator_id.to_i,
        level: level.to_i
    }
  end

  def calls_per_hour_data_expand_rows(data_calls, query)
    row_id = query[:row_id].to_s
    level = row_id.count('.').to_i
    rows = []
    case level
      when 0
        data_calls[:table_rows].each_with_index do |call, index|
          row_index = "#{row_id}.#{index}"
          rows << "
            <tr data-tt-id='#{row_index}' data-tt-parent-id='#{row_id}' data-tt-branch='true' style='height: 21px;' data-tt-user_id='#{call[:secret_user_id]}'>
                <td id='cph_day_map_#{row_index}' align='left'>#{call[:branch]}</td>
                <td id='cph_day_user_call_attempts_#{row_index}' align='right'>#{call[:user_call_attempts]}</td>
                <td id='cph_day_user_answered_calls_#{row_index}' align='right'>#{call[:answered_calls]}</td>
                <td id='cph_day_user_acd_#{row_index}' align='center'>#{nice_time(call[:user_acd], true)}</td>
                <td id='cph_day_user_asr_#{row_index}' align='right'>#{nice_number_with_separator(call[:user_asr], 2, data_calls[:options][:number_decimal])}</td>
                <td id='cph_day_admin_call_attempts_#{row_index}' align='right'>#{call[:admin_call_attempts]}</td>
                <td id='cph_day_admin_answered_calls_#{row_index}' align='right'>#{call[:answered_calls]}</td>
                <td id='cph_day_admin_acd_#{row_index}' align='center'>#{nice_time(call[:admin_acd], true)}</td>
                <td id='cph_day_admin_asr_#{row_index}' align='right'>#{nice_number_with_separator(call[:admin_asr], 2, data_calls[:options][:number_decimal])}</td>
                <td id='cph_day_duration_#{row_index}' align='center'>#{nice_time(call[:duration], true)}</td>
                <td id='cph_day_call_list_link_#{row_index}' align='center'>
                  <a href='#{Web_Dir}/stats/last_calls?day_from=#{call[:day].to_s[8..9]}&day_till=#{call[:day].to_s[8..9]}&hour_from=0&hour_till=23&minute_from=0&minute_till=59&month_from=#{call[:day].to_s[5..6]}&month_till=#{call[:day].to_s[5..6]}&year_from=#{call[:day].to_s[0..3]}&year_till=#{call[:day].to_s[0..3]}&s_user=#{call[:branch]}&s_user_id=#{call[:secret_user_id]}&s_destination=' id='call_list_link_#{row_index}'><img alt='Call' src='#{Web_Dir}/images/icons/call.png' title=''> </a>
                </td>
            </tr>
          "
        end
      when 1
        index = -1
        23.downto(0) do |hour|
          index += 1
          row_index = "#{row_id}.#{index}"
          if data_calls[:table_rows].any? { |call| call[:hour].to_i == hour }
            call = data_calls[:table_rows].select { |call| call[:hour].to_i == hour }.first
            call_hour = call[:hour].to_i
            rows << "
            <tr data-tt-id='#{row_index}' data-tt-parent-id='#{row_id}' data-tt-branch='true' style='height: 21px;'>
                <td id='cph_day_map_#{row_index}' align='left'>Hour #{call_hour}</td>
                <td id='cph_day_user_call_attempts_#{row_index}' align='right'>#{call[:user_call_attempts]}</td>
                <td id='cph_day_user_answered_calls_#{row_index}' align='right'>#{call[:answered_calls]}</td>
                <td id='cph_day_user_acd_#{row_index}' align='center'>#{nice_time(call[:user_acd], true)}</td>
                <td id='cph_day_user_asr_#{row_index}' align='right'>#{nice_number_with_separator(call[:user_asr], 2, data_calls[:options][:number_decimal])}</td>
                <td id='cph_day_admin_call_attempts_#{row_index}' align='right'>#{call[:admin_call_attempts]}</td>
                <td id='cph_day_admin_answered_calls_#{row_index}' align='right'>#{call[:answered_calls]}</td>
                <td id='cph_day_admin_acd_#{row_index}' align='center'>#{nice_time(call[:admin_acd], true)}</td>
                <td id='cph_day_admin_asr_#{row_index}' align='right'>#{nice_number_with_separator(call[:admin_asr], 2, data_calls[:options][:number_decimal])}</td>
                <td id='cph_day_duration_#{row_index}' align='center'>#{nice_time(call[:duration], true)}</td>
                <td id='cph_day_call_list_link_#{row_index}' align='center'>
                  <a href='#{Web_Dir}/stats/last_calls?day_from=#{call[:day].to_s[8..9]}&day_till=#{call[:day].to_s[8..9]}&hour_from=#{call_hour}&hour_till=#{call_hour}&minute_from=0&minute_till=59&month_from=#{call[:day].to_s[5..6]}&month_till=#{call[:day].to_s[5..6]}&year_from=#{call[:day].to_s[0..3]}&year_till=#{call[:day].to_s[0..3]}&s_user=#{call[:nice_username]}&s_user_id=#{call[:secret_user_id]}&s_destination=' id='call_list_link_#{row_index}'><img alt='Call' src='#{Web_Dir}/images/icons/call.png' title=''> </a>
                </td>
            </tr>
          "
          else
            rows << "
            <tr data-tt-id='#{row_index}' data-tt-parent-id='#{row_id}' data-tt-branch='false' style='height: 21px;'>
                <td id='cph_day_map_#{row_index}' align='left'>Hour #{hour}</td>
                <td id='cph_day_user_call_attempts_#{row_index}' align='right'>0</td>
                <td id='cph_day_user_answered_calls_#{row_index}' align='right'0</td>
                <td id='cph_day_user_acd_#{row_index}' align='center'></td>
                <td id='cph_day_user_asr_#{row_index}' align='right'></td>
                <td id='cph_day_admin_call_attempts_#{row_index}' align='right'>0</td>
                <td id='cph_day_admin_answered_calls_#{row_index}' align='right'>0</td>
                <td id='cph_day_admin_acd_#{row_index}' align='center'></td>
                <td id='cph_day_admin_asr_#{row_index}' align='right'></td>
                <td id='cph_day_duration_#{row_index}' align='center'></td>
                <td id='cph_day_call_list_link_#{row_index}' align='center'></td>
            </tr>
          "
          end
        end
      when 2
        data_calls[:table_rows].each_with_index do |call, index|
          call_hour = call[:hour].to_i
          row_index = "#{row_id}.#{index}"
          rows << "
            <tr data-tt-id='#{row_index}' data-tt-parent-id='#{row_id}' data-tt-branch='true' style='height: 21px;'>
                <td id='cph_day_map_#{row_index}' align='left'>#{call[:dest_prefix]}</td>
                <td id='cph_day_user_call_attempts_#{row_index}' align='right'>#{call[:user_call_attempts]}</td>
                <td id='cph_day_user_answered_calls_#{row_index}' align='right'>#{call[:answered_calls]}</td>
                <td id='cph_day_user_acd_#{row_index}' align='center'>#{nice_time(call[:user_acd], true)}</td>
                <td id='cph_day_user_asr_#{row_index}' align='right'>#{nice_number_with_separator(call[:user_asr], 2, data_calls[:options][:number_decimal])}</td>
                <td id='cph_day_admin_call_attempts_#{row_index}' align='right'>#{call[:admin_call_attempts]}</td>
                <td id='cph_day_admin_answered_calls_#{row_index}' align='right'>#{call[:answered_calls]}</td>
                <td id='cph_day_admin_acd_#{row_index}' align='center'>#{nice_time(call[:admin_acd], true)}</td>
                <td id='cph_day_admin_asr_#{row_index}' align='right'>#{nice_number_with_separator(call[:admin_asr], 2, data_calls[:options][:number_decimal])}</td>
                <td id='cph_day_duration_#{row_index}' align='center'>#{nice_time(call[:duration], true)}</td>
                <td id='cph_day_call_list_link_#{row_index}' align='center'>
                  <a href='#{Web_Dir}/stats/last_calls?day_from=#{call[:day].to_s[8..9]}&day_till=#{call[:day].to_s[8..9]}&hour_from=#{call_hour}&hour_till=#{call_hour}&minute_from=0&minute_till=59&month_from=#{call[:day].to_s[5..6]}&month_till=#{call[:day].to_s[5..6]}&year_from=#{call[:day].to_s[0..3]}&year_till=#{call[:day].to_s[0..3]}&s_user=#{call[:nice_user]}&s_destination=#{call[:prefix]}%25&s_user_id=#{call[:secret_user_id]}' id='call_list_link_#{row_index}'><img alt='Call' src='#{Web_Dir}/images/icons/call.png' title=''> </a>
                </td>
            </tr>
          "
        end
      when 3
        data_calls[:table_rows].each_with_index do |call, index|
          row_index = "#{row_id}.#{index}"
          rows << "
            <tr data-tt-id='#{row_index}' data-tt-parent-id='#{row_id}' data-tt-branch='false' style='height: 21px;'>
                <td id='cph_day_map_#{row_index}' align='left'>#{call[:terminator_name]}</td>
                <td id='cph_day_user_call_attempts_#{row_index}' align='right'>#{call[:user_call_attempts]}</td>
                <td id='cph_day_user_answered_calls_#{row_index}' align='right'>#{call[:answered_calls]}</td>
                <td id='cph_day_user_acd_#{row_index}' align='center'>#{nice_time(call[:user_acd], true)}</td>
                <td id='cph_day_user_asr_#{row_index}' align='right'>#{nice_number_with_separator(call[:user_asr], 2, data_calls[:options][:number_decimal])}</td>
                <td id='cph_day_admin_call_attempts_#{row_index}' align='right'>#{call[:admin_call_attempts]}</td>
                <td id='cph_day_admin_answered_calls_#{row_index}' align='right'>#{call[:answered_calls]}</td>
                <td id='cph_day_admin_acd_#{row_index}' align='center'>#{nice_time(call[:admin_acd], true)}</td>
                <td id='cph_day_admin_asr_#{row_index}' align='right'>#{nice_number_with_separator(call[:admin_asr], 2, data_calls[:options][:number_decimal])}</td>
                <td id='cph_day_duration_#{row_index}' align='center'>#{nice_time(call[:duration], true)}</td>
                <td id='cph_day_call_list_link_#{row_index}' align='center'>
                </td>
            </tr>
          "
        end
    end
    rows.join
  end

  def calls_per_hour_access_denied
    dont_be_so_smart
    redirect_to(:root) && (return false)
  end
end
