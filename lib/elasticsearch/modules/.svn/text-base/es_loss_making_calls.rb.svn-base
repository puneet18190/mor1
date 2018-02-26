#-*- encoding : utf-8 -*-
module EsLossMakingCalls
  extend UniversalHelpers

  def self.get_data(options = {})
    data, es_options = loss_making_calls_variables(options)
    current_user = options[:current_user]

    if options[:reseller_id].to_i < 1 && current_user.usertype == 'accountant' && current_user.show_only_assigned_users.to_i == 1
      es_options[:show_only_assigned_users] = 1
      current_acc_id = current_user.id
      es_options[:user_array] = User.where(usertype: 'user', responsible_accountant_id: current_acc_id).pluck(:id)
      es_options[:reseller_array] = User.where(usertype: 'reseller', responsible_accountant_id: current_acc_id).pluck(:id)
    end

    es_loss_making_calls = Elasticsearch.safe_search_mor_calls(
        ElasticsearchQueries.loss_making_calls(es_options),
        {search_type: false}
    )

    return loss_making_calls_prepare(data, es_loss_making_calls)
  end

  def self.loss_making_calls_variables(options = {})
    data = {table_rows: [], table_totals: {duration: 0, loss: 0}, options: {}}

    es_options = {from: options[:from], till: options[:till]}
    es_options[:reseller_id] = options[:reseller_id].to_i unless [-1, 0].include?(options[:reseller_id].to_i)

    current_user = options[:current_user]
    data[:options][:can_see_finances] = options[:can_see_finances]
    data[:options][:seconds_offset] = (Time.zone.now.utc_offset().second - Time.now.utc_offset().second).to_i
    data[:options].merge!(default_formatting_options(current_user))

    return data, es_options
  end

  def self.loss_making_calls_prepare(data, es_loss_making_calls)
    if es_loss_making_calls.present? && es_loss_making_calls['hits']['hits'].present? && es_loss_making_calls['aggregations'].present?
      data = loss_making_calls_data_count(data, es_loss_making_calls)
    end

    loss_making_calls_totals_format(data)
  end

  def self.loss_making_calls_data_count(data, es_result)
    data_cache = {destination_name: {}, nice_username: {}, devicename: {}}
    es_result['hits']['hits'].each do |hit|
      hit_fields = hit['fields']

      call_id = hit['_id']
      calldate = (Time.parse(hit_fields['calldate'].first) + data[:options][:seconds_offset]).strftime('%Y-%m-%d %H:%M:%S')
      dst = hit_fields['dst'].first
      prefix = hit_fields['prefix'].first
      duration = hit_fields['billsec'].first.to_d

      if data[:options][:can_see_finances]
        user_rate = (hit_fields['user_rate'].first.to_d) * data[:options][:exchange_rate]
        provider_rate = (hit_fields['provider_rate'].first.to_d) * data[:options][:exchange_rate]
        user_price = (hit_fields['user_price'].first.to_d + hit_fields['did_inc_price'].first.to_d) * data[:options][:exchange_rate]
        provider_price = (hit_fields['provider_price'].first.to_d - hit_fields['did_prov_price'].first.to_d) * data[:options][:exchange_rate]
        loss = (hit_fields['provider_price'].first.to_d - hit_fields['did_prov_price'].first.to_d - (hit_fields['user_price'].first.to_d + hit_fields['did_inc_price'].first.to_d)) * data[:options][:exchange_rate]
      else
        user_rate = 0
        provider_rate = 0
        user_price = 0
        provider_price = 0
        loss = 0
      end

      user_id = hit_fields['user_id'].first
      src_device_id = hit_fields['src_device_id'].first

      destination = data_cache[:destination_name][prefix] ||= Destination.select("TRIM(CONCAT(directions.name, ' ', destinations.name)) AS dirdstname").where(prefix: prefix).joins(:direction).first.try(:dirdstname)
      nice_username = data_cache[:nice_username][user_id] ||= User.select("#{SqlExport.nice_user_name_sql}").where(id: user_id).first.try(:nicename)
      devicename = data_cache[:devicename][src_device_id] ||= Device.select("CONCAT(device_type, '/', name) AS devicename").where(id: src_device_id).first.try(:devicename)

      data[:table_rows] << {
          date: calldate,
          called_to: dst,
          destination: destination,
          duration: duration,
          user_rate: user_rate,
          provider_rate: provider_rate,
          difference: provider_rate - user_rate,
          user_price: user_price,
          provider_price: provider_price,
          loss: loss,
          user_device: "#{nice_username} - #{devicename}",
          call_id: call_id
      }
    end

    data[:table_totals][:duration] = es_result['aggregations']['total_billsec']['value'].to_d
    data[:table_totals][:loss] = data[:options][:can_see_finances] ? (es_result['aggregations']['total_provider_price']['value'].to_d - es_result['aggregations']['total_did_prov_price']['value'].to_d - (es_result['aggregations']['total_user_price']['value'].to_d + es_result['aggregations']['total_did_inc_price']['value'].to_d)) * data[:options][:exchange_rate] : 0

    data
  end

  def self.loss_making_calls_totals_format(data)
    data[:table_totals][:duration] = nice_time(data[:table_totals][:duration], true)

    data[:table_totals][:loss] = nice_number_with_separator(
        data[:table_totals][:loss], data[:options][:number_digits], data[:options][:number_decimal]
    )

    data
  end
end
