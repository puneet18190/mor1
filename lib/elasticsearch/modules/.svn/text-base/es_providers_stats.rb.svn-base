#-*- encoding : utf-8 -*-
module EsProvidersStats
  extend UniversalHelpers

  def self.es_providers(options = {})
    data, es_options = es_providers_variables(options)
    data, providers = es_providers_prepare_providers(data)
    es_providers_data_count(data, es_options, providers)
  end

  def self.es_providers_variables(options = {})
    data = {
        options: {
            current_user: options[:current_user],
            can_see_finances: options[:can_see_finances],
            hide_providers_without_calls: options[:hide_providers_without_calls],
            show_hidden_providers: options[:show_hidden_providers]
        },
        table_rows: [],
        table_totals: {
            calls: 0, duration: 0, answered: 0, no_answer: 0, busy: 0, failed: 0, failed_locally: 0, asr: 0, acd: 0,
            price: 0, user_price: 0, profit: 0
        }
    }

    current_user = options[:current_user]
    es_options = {from: options[:from], till: options[:till]}
    es_options[:user_id] = current_user.id
    es_options[:prefix] = options[:prefix].presence
    es_options[:provider_id] = options[:provider_id].presence

    es_options[:is_reseller] = current_user.usertype == 'reseller'

    data[:options].merge!(default_formatting_options(current_user, {show_currency: options[:show_currency]}))

    return data, es_options
  end

  def self.es_providers_prepare_providers(data)
    current_user = data[:options][:current_user]

    providers_where =
        if %w[admin accountant].include?(current_user.usertype)
          "user_id = #{current_user.id}"
        else
          "(user_id = #{current_user.id} OR (common_use = 1 AND id IN (SELECT provider_id FROM common_use_providers WHERE reseller_id = #{current_user.id})))"
        end
    providers_where << ' AND hidden = 0' if data[:options][:show_hidden_providers].to_i == 0

    Provider.select(:id, :name, :tech, :common_use).where(providers_where).each do |provider|
      provider_id = provider.id
      provider.name = provider.common_use_provider_name_for_reseller(current_user.id) if provider.common_use == 1 && current_user.usertype == 'reseller'
      data[:table_rows] << {
          provider: provider.name, type: provider.tech, provider_id: provider_id, provider_stats: provider_id,
          hgc_stats: provider_id, calls: 0, duration: 0, answered: 0, no_answer: 0, busy: 0, failed: 0,
          failed_locally: 0, price: 0, user_price: 0, asr: 0, acd: 0
      }
    end

    providers = {
        common_use: Provider.where(providers_where + ' AND common_use = 1').pluck(:id),
        non_common_use: Provider.where(providers_where + ' AND common_use = 0').pluck(:id)
    }

    return data, providers
  end

  def self.es_providers_data_count(data, es_options, providers)
    current_user = data[:options][:current_user]

    # Where calls.provider_id AND providers.common_use = 1
    provider_common_use = Elasticsearch.safe_search_mor_calls(ElasticsearchQueries.stats_by_provider(es_options.merge(providers_id: providers[:common_use])))
    # Where calls.provider_id AND providers.common_use = 0
    provider_non_common_use = Elasticsearch.safe_search_mor_calls(ElasticsearchQueries.stats_by_provider(es_options.merge(providers_id: providers[:non_common_use])))
    # Where calls.did_provider_id AND providers.common_use = 1
    did_provider_common_use = Elasticsearch.safe_search_mor_calls(ElasticsearchQueries.stats_by_provider(es_options.merge(did_provider: true, providers_id: providers[:common_use])))
    # Where calls.did_provider_id AND providers.common_use = 0
    did_provider_non_common_use = Elasticsearch.safe_search_mor_calls(ElasticsearchQueries.stats_by_provider(es_options.merge(did_provider: true, providers_id: providers[:non_common_use])))

    es_providers_common_use = []
    es_providers_non_common_use = []

    es_providers_common_use << provider_common_use['aggregations']['group_by_provider_id']['buckets'] if provider_common_use.present? && provider_common_use['aggregations'].present?
    es_providers_non_common_use << provider_non_common_use['aggregations']['group_by_provider_id']['buckets'] if provider_non_common_use.present? && provider_non_common_use['aggregations'].present?
    es_providers_common_use << did_provider_common_use['aggregations']['group_by_provider_id']['buckets'] if did_provider_common_use.present? && did_provider_common_use['aggregations'].present?
    es_providers_non_common_use << did_provider_non_common_use['aggregations']['group_by_provider_id']['buckets'] if did_provider_non_common_use.present? && did_provider_non_common_use['aggregations'].present?

    es_providers_common_use.flatten.each do |es_provider|
      es_provider_id = es_provider['key'].to_i
      calls = es_provider['doc_count'].to_i
      duration = es_provider['answered_calls']['total_provider_billsec']['value'].to_d
      answered = es_provider['answered_calls']['doc_count'].to_i
      no_answer = es_provider['no_answer']['doc_count'].to_i
      busy = es_provider['busy']['doc_count'].to_i
      failed = es_provider['failed']['doc_count'].to_i
      failed_locally = es_provider['failed_locally']['doc_count'].to_i

      provider_price = es_provider['answered_calls']['total_provider_price']['value'].to_d
      reseller_price = es_provider['answered_calls']['total_reseller_price']['value'].to_d
      sell_price_admin = (es_provider['answered_calls']['total_sell_price_admin_reseller_price']['reseller_price']['value'].to_d + es_provider['answered_calls']['total_sell_price_admin_user_price']['user_price']['value'].to_d)
      sell_price_reseller = es_provider['answered_calls']['total_sell_price_reseller']['value'].to_d

      rows_index = data[:table_rows].index(data[:table_rows].select{ |item| item[:provider_id] == es_provider_id }.first)

      data[:table_rows][rows_index][:calls] += calls
      data[:table_rows][rows_index][:duration] += duration
      data[:table_rows][rows_index][:answered] += answered
      data[:table_rows][rows_index][:no_answer] += no_answer
      data[:table_rows][rows_index][:busy] += busy
      data[:table_rows][rows_index][:failed] += failed
      data[:table_rows][rows_index][:failed_locally] += failed_locally

      price, user_price =
          if %w[admin accountant].include?(current_user.usertype)
            if data[:options][:can_see_finances]
              [provider_price, sell_price_admin]
            else
              [0, 0]
            end
          else
            if current_user.try(:reseller_allow_providers_tariff?)
              [reseller_price, sell_price_reseller]
            else
              [0, 0]
            end
          end

      data[:table_rows][rows_index][:price] += price
      data[:table_rows][rows_index][:user_price] += user_price
    end

    es_providers_non_common_use.flatten.each do |es_provider|
      es_provider_id = es_provider['key'].to_i
      calls = es_provider['doc_count'].to_i
      duration = es_provider['answered_calls']['total_provider_billsec']['value'].to_d
      answered = es_provider['answered_calls']['doc_count'].to_i
      no_answer = es_provider['no_answer']['doc_count'].to_i
      busy = es_provider['busy']['doc_count'].to_i
      failed = es_provider['failed']['doc_count'].to_i
      failed_locally = es_provider['failed_locally']['doc_count'].to_i

      provider_price = es_provider['answered_calls']['total_provider_price']['value'].to_d
      reseller_price = es_provider['answered_calls']['total_reseller_price']['value'].to_d
      sell_price_admin = (es_provider['answered_calls']['total_sell_price_admin_reseller_price']['reseller_price']['value'].to_d + es_provider['answered_calls']['total_sell_price_admin_user_price']['user_price']['value'].to_d)
      sell_price_reseller = es_provider['answered_calls']['total_sell_price_reseller']['value'].to_d

      rows_index = data[:table_rows].index(data[:table_rows].select{ |item| item[:provider_id] == es_provider_id }.first)

      data[:table_rows][rows_index][:calls] += calls
      data[:table_rows][rows_index][:duration] += duration
      data[:table_rows][rows_index][:answered] += answered
      data[:table_rows][rows_index][:no_answer] += no_answer
      data[:table_rows][rows_index][:busy] += busy
      data[:table_rows][rows_index][:failed] += failed
      data[:table_rows][rows_index][:failed_locally] += failed_locally

      price, user_price =
          if %w[admin accountant].include?(current_user.usertype)
            if data[:options][:can_see_finances]
              [provider_price, sell_price_admin]
            else
              [0, 0]
            end
          else
            if current_user.try(:reseller_allow_providers_tariff?)
              [provider_price, sell_price_reseller]
            else
              [0, 0]
            end
          end

      data[:table_rows][rows_index][:price] += price
      data[:table_rows][rows_index][:user_price] += user_price
    end

    data[:table_rows].delete_if { |provider_row| provider_row[:calls] == 0 } if data[:options][:hide_providers_without_calls].to_i == 1

    (data[:table_rows].size).times do |row_index|
      data[:table_rows][row_index][:asr] = (data[:table_rows][row_index][:answered].to_f / data[:table_rows][row_index][:calls].to_f) * 100
      data[:table_rows][row_index][:acd] = data[:table_rows][row_index][:duration].to_f / data[:table_rows][row_index][:answered].to_f
      [:asr, :acd].each { |key| data[:table_rows][row_index][key] = 0.to_d if data[:table_rows][row_index][key].nan? || data[:table_rows][row_index][key].infinite? }


      [:price, :user_price].each do |key|
        data[:table_rows][row_index][key] = data[:table_rows][row_index][key] * data[:options][:exchange_rate]
      end

      data[:table_rows][row_index][:profit] = data[:table_rows][row_index][:user_price] - data[:table_rows][row_index][:price]

      [:calls, :duration, :answered, :no_answer, :busy, :failed, :failed_locally, :price, :user_price, :profit].each do |key|
        data[:table_totals][key] += data[:table_rows][row_index][key]
      end
    end

    data[:table_totals][:asr] = ((data[:table_totals][:answered].to_f) / data[:table_totals][:calls].to_f) * 100
    data[:table_totals][:acd] = data[:table_totals][:duration].to_f / data[:table_totals][:answered].to_f
    [:asr, :acd].each do |key|
      data[:table_totals][key] = 0.to_d if data[:table_totals][key].nan? || data[:table_totals][key].infinite?
    end

    es_providers_totals_format(data)
  end

  def self.es_providers_totals_format(data)
    [:calls, :answered, :no_answer, :busy, :failed, :failed_locally].each do |key|
      data[:table_totals][key] = data[:table_totals][key].to_i
    end

    [:duration, :acd].each do |key|
      data[:table_totals][key] = nice_time(data[:table_totals][key], true)
    end

    [:price, :user_price, :profit].each do |key|
      data[:table_totals][key] = nice_number_with_separator(
          data[:table_totals][key], data[:options][:number_digits], data[:options][:number_decimal]
      )
    end

    [:asr].each do |key|
      data[:table_totals][key] = nice_number_with_separator(
          data[:table_totals][key], 2, data[:options][:number_decimal]
      )
    end

    data
  end

  def self.es_provider_stats(options = {})
    data, es_options = es_providers_variables(options)

    es_providers_stats_data_count(data, es_options)
  end

  def self.es_providers_stats_data_count(data, es_options)
    provider_calls = Elasticsearch.safe_search_mor_calls(ElasticsearchQueries.provider_stats(es_options))
    did_provider_calls = Elasticsearch.safe_search_mor_calls(ElasticsearchQueries.provider_stats(es_options.merge(did_provider: true)))

    if provider_calls.present? && provider_calls['aggregations'].present?
      calls = provider_calls['hits']['total'].to_i
      answered = provider_calls['aggregations']['answered_calls']['doc_count'].to_i
      no_answer = provider_calls['aggregations']['no_answer']['doc_count'].to_i
      busy = provider_calls['aggregations']['busy']['doc_count'].to_i
      failed = provider_calls['aggregations']['failed']['doc_count'].to_i
      failed_locally = provider_calls['aggregations']['failed_locally']['doc_count'].to_i

      data[:table_totals][:calls] += calls
      data[:table_totals][:answered] += answered
      data[:table_totals][:no_answer] += no_answer
      data[:table_totals][:busy] += busy
      data[:table_totals][:failed] += (failed + failed_locally)
    end

    if did_provider_calls.present? && did_provider_calls['aggregations'].present?
      calls = did_provider_calls['hits']['total'].to_i
      answered = did_provider_calls['aggregations']['answered_calls']['doc_count'].to_i
      no_answer = did_provider_calls['aggregations']['no_answer']['doc_count'].to_i
      busy = did_provider_calls['aggregations']['busy']['doc_count'].to_i
      failed = did_provider_calls['aggregations']['failed']['doc_count'].to_i
      failed_locally = did_provider_calls['aggregations']['failed_locally']['doc_count'].to_i

      data[:table_totals][:calls] += calls
      data[:table_totals][:answered] += answered
      data[:table_totals][:no_answer] += no_answer
      data[:table_totals][:busy] += busy
      data[:table_totals][:failed] += (failed + failed_locally)
    end

    data[:table_totals][:asr] = ((data[:table_totals][:answered].to_f) / data[:table_totals][:calls].to_f) * 100
    data[:table_totals][:no_asr_pr] = ((data[:table_totals][:no_answer].to_f) / data[:table_totals][:calls].to_f) * 100
    data[:table_totals][:busy_pr] = ((data[:table_totals][:busy].to_f) / data[:table_totals][:calls].to_f) * 100
    data[:table_totals][:failed_pr] = ((data[:table_totals][:failed].to_f) / data[:table_totals][:calls].to_f) * 100

    [:asr, :no_asr_pr, :busy_pr, :failed_pr].each do |key|
      data[:table_totals][key] = 0.to_d if data[:table_totals][key].nan? || data[:table_totals][key].infinite?
      data[:table_totals][key] = nice_number_with_separator(data[:table_totals][key], 2, data[:options][:number_decimal])
    end

    data
  end
end
