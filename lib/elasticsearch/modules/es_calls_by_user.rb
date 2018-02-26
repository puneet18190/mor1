#-*- encoding : utf-8 -*-
module EsCallsByUser
  extend UniversalHelpers

  def self.get_data(options)
    data, es_options = calls_by_user_variables(options)
    all_calls = {}

    current_user = options[:current_user]

    all_calls[:es_calls_by_user] = Elasticsearch.safe_search_mor_calls(ElasticsearchQueries.calls_by_user(es_options))
    all_calls[:es_calls_by_reseller] = Elasticsearch.safe_search_mor_calls(ElasticsearchQueries.calls_by_user_reseller(es_options)) if current_user.is_admin? || current_user.is_partner? || current_user.is_accountant?
    all_calls[:es_calls_by_partner] = Elasticsearch.safe_search_mor_calls(ElasticsearchQueries.calls_by_user_partner(es_options)) if current_user.is_admin? || current_user.is_accountant?

    calls_by_user_data_prepare(data, all_calls, es_options)
  end

  def self.calls_by_user_variables(options = {})
    data = {
        table_rows: [],
        table_totals: {
            balance: 0, answered_calls: 0, call_attempts: 0, billsec: 0, acd: 0, asr: 0,
            price: 0, provider_price: 0, profit: 0, margin: 0, markup: 0
        },
        options: {exrate: options[:exrate]}
    }

    current_user = options[:current_user]

    options[:user_id] = User.where("#{options[:users]}").pluck(:id)
    options[:reseller_id] = User.where("#{options[:resellers]}").pluck(:id) if current_user.is_admin? || current_user.is_partner? || current_user.is_accountant?
    options[:partner_id] = User.where("#{options[:partners]}").pluck(:id) if current_user.is_admin? || current_user.is_accountant?

    data[:options].merge!(default_formatting_options(current_user))

    [data, options]
  end

  def self.calls_by_user_data_prepare(data, all_calls, options)
    # all calls containt
    # all_calls[:es_calls_by_user]
    # all_calls[:es_calls_by_reseller]
    # all_calls[:es_calls_by_partner]
    data = fill_calls_by_user_data_with_blank_users(data, options)
    # sutvarko viska
    current_user = options[:current_user]

    es_calls_by_user =  all_calls[:es_calls_by_user] if current_user.is_reseller? || current_user.is_admin? || current_user.is_accountant?
    es_calls_by_reseller = all_calls[:es_calls_by_reseller] if current_user.is_partner? || current_user.is_admin? || current_user.is_accountant?
    es_calls_by_partner = all_calls[:es_calls_by_partner] if current_user.is_admin? || current_user.is_accountant?

    buckets = []
    buckets += es_calls_by_user['aggregations']['group_by_user_id']['buckets'] if defined?(es_calls_by_user) && es_calls_by_user.present?
    buckets += es_calls_by_reseller['aggregations']['group_by_reseller_id']['buckets'] if defined?(es_calls_by_reseller) && es_calls_by_reseller.present?
    buckets += es_calls_by_partner['aggregations']['group_by_partner_id']['buckets'] if defined?(es_calls_by_partner) && es_calls_by_partner.present?

    if buckets.present?
      data = calls_by_user_data_count(data, buckets)
    end

    calls_by_user_totals_format(data)
  end

  def self.fill_calls_by_user_data_with_blank_users(data, options)
    all_users = []
    current_user = options[:current_user]
    all_users += options[:user_id] if current_user.is_admin? || current_user.is_reseller? || current_user.is_accountant?
    all_users += options[:reseller_id] if current_user.is_admin? || current_user.is_partner? || current_user.is_accountant?
    all_users += options[:partner_id] if current_user.is_admin? || current_user.is_accountant?

    all_users.each do |user_id|
      user = User.where(id: user_id).first
      to_row = {
          user_id: user_id,
          nice_user_and_id: "#{nice_user(user).to_s} #{user_id.to_s}",
          balance: user.raw_balance * options[:exrate],
          answered_calls: 0,
          call_attempts: 0,
          billsec: 0,
          acd: 0,
          asr: 0,
          price: 0,
          provider_price: 0,
          profit: 0,
          margin: 0,
          markup: 0
      }
      data[:table_totals][:balance] += to_row[:balance]
      data[:table_rows] << to_row
    end
    data
  end

  def self.calls_by_user_data_count(data, buckets)
    keys = []
    buckets.each do |bucket|
      user_id = bucket['key'].to_i
      call_attempts = bucket['doc_count'].to_d
      answered_calls = bucket['answered_calls']['doc_count'].to_d
      billsec = bucket['answered_calls']['total_billsec']['value'].to_d
      price = bucket['answered_calls']['total_user_price']['value'].to_d * data[:options][:exrate]
      provider_price = bucket['answered_calls']['total_provider_price']['value'].to_d * data[:options][:exrate]

      acd = billsec / answered_calls
      asr = answered_calls / call_attempts * 100
      profit = price - provider_price
      margin = profit / price * 100
      markup = (price / provider_price * 100) - 100

      rows_index = data[:table_rows].index(data[:table_rows].select{|item| item[:user_id] == user_id }.first)

      data[:table_rows][rows_index][:answered_calls] = answered_calls
      data[:table_rows][rows_index][:call_attempts] = call_attempts
      data[:table_rows][rows_index][:billsec] = billsec
      data[:table_rows][rows_index][:acd] = acd
      data[:table_rows][rows_index][:asr] = asr
      data[:table_rows][rows_index][:price] = price
      data[:table_rows][rows_index][:provider_price] = provider_price
      data[:table_rows][rows_index][:profit] = profit
      data[:table_rows][rows_index][:margin] = margin
      data[:table_rows][rows_index][:markup] = markup

      %i[acd asr margin markup].each do |key|
        data[:table_rows][rows_index][key] = 0.to_d if data[:table_rows][rows_index][key].nan? || data[:table_rows][rows_index][key].infinite?
      end

      # balance: 0, answered_calls: 0, call_attempts: 0, billsec: 0, adc: 0, asr: 0,
      # price: 0, provider_price: 0, profit: 0, margin: 0, markup: 0

      data[:table_totals][:answered_calls] += answered_calls
      data[:table_totals][:call_attempts] += call_attempts
      data[:table_totals][:billsec] += billsec
      data[:table_totals][:price] += price
      data[:table_totals][:provider_price] += provider_price
    end
    data[:table_totals][:profit] += data[:table_totals][:price] - data[:table_totals][:provider_price]
    data[:table_totals][:acd] += data[:table_totals][:billsec] / data[:table_totals][:answered_calls]
    data[:table_totals][:asr] += data[:table_totals][:answered_calls] / data[:table_totals][:call_attempts] * 100
    data[:table_totals][:margin] += (data[:table_totals][:profit] / data[:table_totals][:price]) * 100
    data[:table_totals][:markup] += (data[:table_totals][:price] / data[:table_totals][:provider_price] * 100) - 100

    %i[acd asr margin markup].each do |key|
      data[:table_totals][key] = 0.to_d if data[:table_totals][key].nan? || data[:table_totals][key].infinite?
    end

    data
  end

  def self.calls_by_user_totals_format(data)
    data[:table_totals][:answered_calls] = data[:table_totals][:answered_calls].to_i
    data[:table_totals][:call_attempts] = data[:table_totals][:call_attempts].to_i

    data[:table_totals][:billsec] = nice_time(data[:table_totals][:billsec], true)
    data[:table_totals][:acd] = nice_time(data[:table_totals][:acd], true)

    %i[balance price provider_price profit].each do |key|
      data[:table_totals][key] = nice_number_with_separator(
          data[:table_totals][key], data[:options][:number_digits], data[:options][:number_decimal]
      )
    end

    %i[asr margin markup].each do |key|
      data[:table_totals][key] = nice_number_with_separator(
          data[:table_totals][key], 2, data[:options][:number_decimal]
      )
    end

    data
  end
end
