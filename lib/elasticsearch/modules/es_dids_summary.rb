#-*- encoding : utf-8 -*-
module EsDidsSummary
  extend UniversalHelpers
  # Performs ES query, returns formatted result
  # Params:
  #   +options+:: query options
  # Returns:
  #   ready-to-view response data
  def self.get_data(options = {})
    # Prepare options for the query
    data, es_options = es_dids_summary_variables(options)
    # Perform the query
    es_dids_summary = Elasticsearch.safe_search_mor_calls(ElasticsearchQueries.dids_summary(es_options))
    # Get the final result
    es_dids_summary_prepare(data, es_dids_summary)
  end

  def self.es_dids_summary_variables(options = {})
    # # Result hash structure:

    data = { table_rows: [], table_totals: {
      total_calls: 0, total_billsec: 0, incoming_price: 0, owner_price: 0,
      provider_price: 0}, options: {}
    }

    params = options[:options]

    # Prepare conditionals
    current_user = options[:current_user]
    seconds_offset = (Time.zone.now.utc_offset().second - Time.now.utc_offset().second).to_i
    utc_offset = ActiveSupport::TimeZone.seconds_to_utc_offset(seconds_offset)

    es_options = { from: options[:from], till: options[:till], dids_grouping: params[:dids_grouping], utc_offset: utc_offset}
    es_options[:providers_id] = Provider.all.pluck(:id)
    es_options[:dids_id] = Did.all.pluck(:id) if params[:dids_grouping] == 2
    es_options[:did_id_params] = Did.where("did LIKE '#{params[:did].to_i}%'").pluck(:id) if params[:did] != '' && params[:d_search].to_i == 1
    if params[:did_search_from] != '' && params[:did_search_till] != '' && params[:d_search].to_i == 2
      es_options[:did_id_range] = Did.where('did Between ? AND ? ', params[:did_search_from].to_i, params[:did_search_till].to_i).pluck(:id)
    end
    es_options[:did_provider_id] = params[:provider] if params[:provider] != 'any'
    es_options[:s_by_user_id] = Did.where("user_id = '#{params[:user_id].to_i}'").pluck(:id)  if params[:user_id] != 'any'
    es_options[:s_by_device_id] = Did.where("device_id = '#{params[:device_id].to_i}'").pluck(:id)  if params[:device_id] != 'all'
    # Days
    es_options[:s_days] = params[:sdays] if params[:sdays] != 'all'

    # Period
    if (params[:period] != 'all' && params[:period].to_i != -1) && params[:period].present?
      did_rate = Didrate.where({id: params[:period]}).first
      nice_period_start = did_rate.start_time.strftime("%H:%M:%S").to_s
      nice_period_end = did_rate.end_time.strftime("%H:%M:%S").to_s
      start_time = Time.parse(nice_period_start).to_i
      end_time = Time.parse(nice_period_end).to_i
      midnight = Time.parse('00:00').to_i
      total_seconds_start = start_time - midnight
      total_seconds_end = end_time - midnight
      es_options[:rate_start] = total_seconds_start
      es_options[:rate_end] = total_seconds_end
   end

    data[:options][:can_see_finances] = options[:can_see_finances]
    data[:options][:seconds_offset] = Time.parse(options[:from]).in_time_zone(current_user.time_zone).utc_offset.seconds - Time.parse(options[:from]).utc_offset.seconds
    data[:options].merge!(default_formatting_options(current_user, { show_currency: options[:show_currency] }))
    data[:options][:dids_grouping] = params[:dids_grouping]

    return data, es_options
  end

  def self.es_dids_summary_prepare(data, es_dids_summary_response)
    # Take the grouped ES buckets (by did_id)
    did_id_buckets = es_dids_summary_response['aggregations']['group_by_provider_id']['buckets'] if es_dids_summary_response.present?
    # Aggregate, fill with relational data and format the fields
    data = es_dids_summary_data_count(data, did_id_buckets) if did_id_buckets.present?
    es_dids_summary_totals_format(data)
  end

  def self.es_dids_summary_data_count(data, did_id_buckets)
    exchange_rate = data[:options][:exchange_rate]
    did_grouping_by_user = data[:options][:dids_grouping].to_i == 2

    did_id_buckets.each do |bucket|
      did_id = bucket['key'].to_i
      calls = bucket['doc_count'].to_i
      billsec = bucket['total_did_billsec']['value'].to_i
      incoming_price = bucket['total_did_inc_price']['value'].to_d * exchange_rate
      provider_price = bucket['total_did_prov_price']['value'].to_d * exchange_rate
      owner_price = bucket['total_did_price']['value'].to_d * exchange_rate

      if did_grouping_by_user
        did_info = Did.select(:user_id, :device_id).where(id: did_id).pluck(:user_id, :device_id).first
        device_id = did_info[1]
        user_id = did_info[0]
       else
         provider = { id: did_id,  name: Provider.where(id: did_id).pluck(:name).to_sentence }
      end

       data[:table_rows] << {
        name: did_id.to_i,
        provider: provider,
        user_id: user_id,
        device_id: device_id,
        calls: calls,
        billsec: billsec.to_i,
        incoming_price: incoming_price.to_f,
        owner_price: owner_price.to_f,
        provider_price: provider_price.to_f
      }

      data[:table_totals][:total_calls] += calls
      data[:table_totals][:total_billsec] += billsec
      data[:table_totals][:incoming_price] += incoming_price.to_f
      data[:table_totals][:owner_price] += owner_price.to_f
      data[:table_totals][:provider_price] += provider_price.to_f
    end


    # This only if grouping is By User/Device
    if did_grouping_by_user
      group = []
      data[:table_rows].group_by { |x| [x[:user_id], x[:device_id]]}.map {|key, hashes|
        result = hashes[0]
        [:calls, :billsec].each { |key|
          result[key] = hashes.inject(0) { |s, x| s + x[key].to_f }
        }
        group << result
      }

      data[:table_rows] = []
      data[:table_rows] = group

      data[:table_rows].each do |row|
        nice_username = User.select("#{SqlExport.nice_user_name_sql}").where(id: row[:user_id]).first.try(:nicename)
        device = Device.select("CONCAT(device_type, '/', IF(username = '', extension, name)) AS devicename, device_type, istrunk, ani").where(id: row[:device_id]).first
        if device.present?
	        device_name = device.devicename
          device_pic = get_device_pic(device.device_type, device.istrunk, device.ani)
    	end

        row[:user_name] = nice_username
        row[:user_id] = row[:user_id]
        row[:device] = { device_name: device_name, device_id: row[:device_id], device_pic_name: device_pic}
      end

    end

    data
  end

  def self.es_dids_summary_totals_format(data)
    options = data[:options]
    # Make data and time in settings format
    data[:table_totals][:total_billsec] = nice_time(data[:table_totals][:total_billsec], true)

    [:incoming_price, :owner_price, :provider_price].each do |key|
      data[:table_totals][key] = nice_number_with_separator(
          data[:table_totals][key], data[:options][:number_digits], data[:options][:number_decimal])
    end
    data
  end

  def self.get_device_pic(device_type, istrunk, ani)
    name = ''
    name = 'device' if device_type == "SIP" || device_type == "IAX2" || device_type == "H323" || device_type == "dahdi"
    name = 'trunk' if istrunk == 1 && ani && ani == 0
    name = 'trunk_ani' if istrunk == 1 && ani && ani == 1
    name = 'printer' if device_type == "FAX"
    name = 'virtual_device' if device_type == "Virtual"
    return name
  end


end