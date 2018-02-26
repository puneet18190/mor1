#-*- encoding : utf-8 -*-
module EsCallsPerDay
  extend UniversalHelpers

  def self.get_data(options = {})
    data, es_options = calls_per_day_variables(options)
    data[:options][:can_see_finances] = options[:can_see_finances]

    es_calls_per_day = Elasticsearch.safe_search_mor_calls(ElasticsearchQueries.calls_per_day(es_options))

    calls_per_day_data_prepare(data, es_calls_per_day)
  end

  def self.calls_per_day_variables(options = {})
    data = {
        table_rows: [],
        table_totals: {
            calls: 0, duration: 0, acd: 0, asr: 0, fail: 0, fail_percent: 0,
            price: 0, provider_price: 0, profit: 0, reseller_price: 0, partner_price: 0, partner_profit: 0,
            margin: 0, markup: 0
        },
        options: {}
    }

    current_user = options[:current_user]
    seconds_offset = (Time.zone.now.utc_offset().second - Time.now.utc_offset().second).to_i
    utc_offset = ActiveSupport::TimeZone.seconds_to_utc_offset(seconds_offset)
    admin_providers = Provider.where(user_id: 0).pluck(:id)

    es_options = {
        from: options[:from], till: options[:till],
        utc_offset: utc_offset,
        admin_providers: admin_providers
    }

    es_options[:partner_id] = current_user.id if current_user.usertype == 'partner'
    es_options[:user_id] = options[:s_user_id].to_i if options[:s_user_id].to_i != -1
    es_options[:reseller_id] = options[:reseller_id].to_i if options[:reseller_id].present?
    es_options[:provider_id] = options[:provider_id].to_i if options[:provider_id].present?
    es_options[:destination_group_id] = options[:destination_group_id].to_i if options[:destination_group_id].present?

    if options[:s_user_id].to_i < 0 && current_user.usertype == 'accountant' && current_user.show_only_assigned_users.to_i == 1
      es_options[:show_only_assigned_users] = 1
      current_acc_id = current_user.id
      es_options[:user_array] = User.where(usertype: 'user', responsible_accountant_id: current_acc_id).pluck(:id)
      es_options[:reseller_array] = User.where(usertype: 'reseller', responsible_accountant_id: current_acc_id).pluck(:id)
    end

    data[:options].merge!(default_formatting_options(current_user))

    return data, es_options
  end

  def self.calls_per_day_data_prepare(data, es_calls_per_day)
    if es_calls_per_day.present? && es_calls_per_day['aggregations']['dates']['buckets'].present?
      data = calls_per_day_data_count(
          data,
          es_calls_per_day['aggregations']['dates']['buckets']
      )
    end

    calls_per_day_totals_format(data)
  end

  def self.calls_per_day_data_count(data, es_result)
    can_see_finances = data[:options][:can_see_finances]
    es_result.each do |bucket|
      date = bucket['key_as_string']
      total_calls = bucket['doc_count'].to_d
      good_calls = bucket['answered_calls']['doc_count'].to_d
      failed_calls = total_calls - good_calls
      total_billsec = bucket['answered_calls']['total_billsec']['value'].to_d
      total_partner_price = (bucket['answered_calls']['total_partner_price']['value'].to_d) * data[:options][:exchange_rate]
      total_reseller_price = (bucket['answered_calls']['total_reseller_price']['did_inc_price']['value'].to_d + bucket['answered_calls']['total_reseller_price']['reseller_price_admin_provider']['reseller_price']['value'].to_d) * data[:options][:exchange_rate]
      total_provider_price = (bucket['answered_calls']['total_provider_price']['provider_price_admin_provider']['provider_price']['value'].to_d - bucket['answered_calls']['total_provider_price']['did_prov_price']['value'].to_d) * data[:options][:exchange_rate]
      total_user_price = (bucket['answered_calls']['total_user_price_admin']['did_inc_price']['value'].to_d + bucket['answered_calls']['total_user_price_admin']['user_price']['value'].to_d + bucket['answered_calls']['total_user_price_reseller']['did_inc_price']['value'].to_d + bucket['answered_calls']['total_user_price_reseller']['user_price_admin_provider']['reseller_price']['value'].to_d) * data[:options][:exchange_rate]

      to_row = {
          date: "#{date}T00:00:00-00:00",
          calls: total_calls,
          duration: total_billsec,
          acd: (total_billsec / good_calls),
          asr: ((good_calls / total_calls) * 100),
          fail: failed_calls,
          fail_percent: ((failed_calls / total_calls) * 100),
          price: total_user_price,
          provider_price: total_provider_price,
          profit: (total_user_price - total_provider_price),
          reseller_price: total_reseller_price,
          partner_price: total_partner_price,
          partner_profit: (total_reseller_price - total_partner_price)
      }


      if data[:options][:usertype] == 'partner'
        to_row[:margin] = (((total_reseller_price - total_partner_price) / total_reseller_price) * 100)
        to_row[:markup] = (((total_reseller_price / total_partner_price) * 100) - 100)
      else
        to_row[:margin] = (((total_user_price - total_provider_price) / total_user_price) * 100)
        to_row[:markup] = (((total_user_price / total_provider_price) * 100) - 100)
      end

      to_row[:price] = to_row[:provider_price] = to_row[:profit] = to_row[:margin] = to_row[:markup] = 0.0/0 if !can_see_finances

      [:acd, :asr, :fail_percent, :margin, :markup].each do |key|
        to_row[key] = 0.to_d if to_row[key].nan? || to_row[key].infinite?
      end

      data[:table_rows] << to_row

      data[:table_totals][:calls] += total_calls
      data[:table_totals][:duration] += total_billsec
      data[:table_totals][:fail] += failed_calls
      data[:table_totals][:price] += to_row[:price]
      data[:table_totals][:provider_price] += to_row[:provider_price]
      data[:table_totals][:reseller_price] += to_row[:reseller_price]
      data[:table_totals][:partner_price] += to_row[:partner_price]
    end

    data[:table_totals][:acd] = (data[:table_totals][:duration] / (data[:table_totals][:calls] - data[:table_totals][:fail]))
    data[:table_totals][:asr] = (((data[:table_totals][:calls] - data[:table_totals][:fail]) / data[:table_totals][:calls]) * 100)
    data[:table_totals][:fail_percent] = ((data[:table_totals][:fail] / data[:table_totals][:calls]) * 100)
    data[:table_totals][:profit] = (data[:table_totals][:price] - data[:table_totals][:provider_price])
    data[:table_totals][:partner_profit] = (data[:table_totals][:reseller_price] - data[:table_totals][:partner_price])

    if data[:options][:usertype] == 'partner'
      data[:table_totals][:margin] = (((data[:table_totals][:reseller_price] - data[:table_totals][:partner_price]) / data[:table_totals][:reseller_price]) * 100)
      data[:table_totals][:markup] = (((data[:table_totals][:reseller_price] / data[:table_totals][:partner_price]) * 100) - 100)
    else
      data[:table_totals][:margin] = can_see_finances ? (((data[:table_totals][:price] - data[:table_totals][:provider_price]) / data[:table_totals][:price]) * 100) : 0.0/0
      data[:table_totals][:markup] = can_see_finances ? (((data[:table_totals][:price] / data[:table_totals][:provider_price]) * 100) - 100) : 0.0/0
    end

    [:acd, :asr, :fail_percent, :margin, :markup].each do |key|
      data[:table_totals][key] = 0.to_d if data[:table_totals][key].nan? || data[:table_totals][key].infinite?
    end

    return data
  end

  def self.calls_per_day_totals_format(data)
    data[:table_totals][:calls] = data[:table_totals][:calls].to_i
    data[:table_totals][:fail] = data[:table_totals][:fail].to_i

    data[:table_totals][:duration] = nice_time(data[:table_totals][:duration], true)
    data[:table_totals][:acd] = nice_time(data[:table_totals][:acd], true)

    [:price, :provider_price, :profit, :reseller_price, :partner_price, :partner_profit].each do |key|
      data[:table_totals][key] = nice_number_with_separator(
          data[:table_totals][key], data[:options][:number_digits], data[:options][:number_decimal]
      )
    end

    [:asr, :fail_percent, :margin, :markup].each do |key|
      data[:table_totals][key] = nice_number_with_separator(
          data[:table_totals][key], 2, data[:options][:number_decimal]
      )
    end

    return data
  end
end
