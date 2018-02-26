#-*- encoding : utf-8 -*-
module EsDidsStats
  extend UniversalHelpers

  # Performs ES query, returns formatted result
  # Params:
  #   +options+:: query options
  # Returns:
  #   ready-to-view response data
  def self.get_data(options = {})
    # Prepare options for the query
    data, es_options = es_dids_stats_variables(options)
    # Perform the query
    es_dids_stats = Elasticsearch.safe_search_mor_calls(
        ElasticsearchQueries.dids_stats(es_options), { search_type: false })
    # Get the final result
    es_dids_stats_prepare(data, es_dids_stats)
  end

  # Prepares conditional for the ES and further computations.
  # Params:
  #   +options+:: options to be prepared
  # Returns:
  #   result structure hash and prepared options
  def self.es_dids_stats_variables(options = {})
    # Result hash structure:
    data = { table_rows: [], table_totals: {
        total_calls: 0, total_did_inc_price: 0, total_did_price: 0,
        total_did_prov_price: 0, total_profit: 0 }, options: {}
    }
    # Prepare conditionals
    es_options = { from: options[:from], till: options[:till] }

    # Prepare options
    unless %w[-2, -1].include?(options[:user_id])
      data[:options][:user_id] = options[:user_id].to_i
    end

    unless options[:provider_id].to_i == -1
      data[:options][:provider_id] = options[:provider_id].to_i
    end

    current_user = options[:current_user]
    data[:options][:can_see_finances] = options[:can_see_finances]
    data[:options][:seconds_offset] = (Time.zone.now.utc_offset().second - Time.now.utc_offset().second).to_i
    data[:options].merge!(default_formatting_options(current_user, { show_currency: options[:show_currency] }))

    return data, es_options
  end

  # Prepares ES response for the views. Calls the aggregations and
  #   formatting methods
  # Params:
  #   +data+:: a hash to store final results (has a defined structure:
  #   look at: es_dids_stats_variables)
  #   +es_dids_stats_response+:: response by ES look at elasticsearch_queries.rb
  # Returns:
  #   Formatted and ready-to-view data hash
  def self.es_dids_stats_prepare(data, es_dids_stats_response)
    # Take the grouped ES buckets (by did_id)
    did_id_buckets = es_dids_stats_response['aggregations']['group_by_did_id']['buckets'] if es_dids_stats_response.present?
    # Aggregate, fill with relational data and format the fields
    data = es_dids_stats_data_count(data, did_id_buckets) if did_id_buckets.present?
    es_dids_stats_totals_format(data)
  end

  # Aggregates data fields and connects all the SQL relations for a a given
  #   hash of ES collected calls !grouped by did_id!.
  # Params:
  #   +data+:: a hash to store final results (has a defined structure:
  #   look at: es_dids_stats_variables)
  #   +did_id_buckets+:: grouped by did_id ES response buckets hash
  # Returns:
  #   aggregated and filled with relational data hash
  def self.es_dids_stats_data_count(data, did_id_buckets)
    # Here we cache data about each did. We can avoid additional
    #   SQL operations when did id is present in a cache.
    dids_cache = {}
    # For each grouped ES response element do:
    did_id_buckets.each do |bucket|

      # DID id lies under the key element since grouped by did_id.
      did_id = bucket['key'].to_i
      # Collect the corresponding DID data:
      did = Did.where(id: did_id).first

      did_provider_id = did.try(:provider_id)
      # Skip the results which are not satisfying the search
      options_user_id = data[:options][:user_id]
      options_provider_id = data[:options][:provider_id]
      next if (options_user_id.present? && options_user_id != did.try(:user_id)) ||
          (options_provider_id.present? && options_provider_id != did_provider_id)

      # Number of calls:
      calls = bucket['doc_count'].to_i

      # Financial data:
      can_see_finances = data[:options][:can_see_finances]
      exchange_rate = data[:options][:exchange_rate]

      if can_see_finances
        did_inc_price = bucket['total_did_inc_price']['value'].to_d * exchange_rate
        did_price = bucket['total_did_price']['value'].to_d * exchange_rate
        did_prov_price = bucket['total_did_prov_price']['value'].to_d * exchange_rate
      else
        did_inc_price = did_price = did_prov_price = 0
      end

      # Load a cache record or create a new one and store it if needed
      did = dids_cache[did_id] ||= {
          did: { id: did_id, did: did.try(:did) },
          comment: did.try(:comment),
          provider: { id: did_provider_id, name: Provider.where(id: did_provider_id).first.try(:name) },
          # Date of the DID assignment:
          date: ActiveRecord::Base.connection.select_value(
              "SELECT date FROM actions
          WHERE data = #{did_id} AND action LIKE 'did_assigned%'
          ORDER BY date DESC LIMIT 1")
      }

      # Note: sum is suitable here because the rates can be negative too.
      #  Thus the profit remains logical.
      profit = can_see_finances ? did_price + did_prov_price + did_inc_price : 0

      # Store the collected did data:
      data[:table_rows] << {
          did: did[:did],
          comment: did[:comment],
          provider: did[:provider],
          date: did[:date],
          calls: calls,
          did_inc_price: did_inc_price ,
          did_price: did_price,
          did_prov_price: did_prov_price,
          profit: profit,
      }

      # Aggregate the total fields:
      data[:table_totals][:total_did_inc_price] += did_inc_price
      data[:table_totals][:total_did_price] += did_price
      data[:table_totals][:total_did_prov_price] += did_prov_price
      data[:table_totals][:total_profit] += profit
      data[:table_totals][:total_calls] += calls
    end
    data
  end

  # Formats the numeric values due to settings
  # Params:
  #   +data+ aggregated data to format
  # Returns:
  #   formatted data
  def self.es_dids_stats_totals_format(data)
    options = data[:options]
    # Make the numeric data look good and corresponding the user settings.
    data[:table_totals].except(:total_calls).each do |key, val|
      data[:table_totals][key] = nice_number_with_separator(
          val, options[:number_digits], options[:number_decimal])
    end
    data
  end
end
