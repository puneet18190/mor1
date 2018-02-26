#-*- encoding : utf-8 -*-
module EsCountryStats
  extend UniversalHelpers

  def self.get_data(options = {})
    data, es_options = country_stats_variables(options)

    data[:options][:can_see_finances] = options[:can_see_finances]

    es_country_stats = Elasticsearch.safe_search_mor_calls(ElasticsearchQueries.country_stats_query(es_options))

    country_stats_data_prepare(data, es_country_stats, es_options[:is_reseller])
  end

  def self.country_stats_variables(options = {})
    data = {
        table_rows: [],
        table_totals: {calls: 0, time: 0, price: 0, user_price: 0, profit: 0},
        graphs: {time: "\"", profit: "\"", income: "\""},
        options: {}
    }

    s_user_id = options[:s_user_id]
    current_user = options[:current_user]

    es_options = {from: options[:from], till: options[:till]}
    es_options[:user_id] = s_user_id unless s_user_id == -1
    es_options[:is_reseller] = current_user.try(:usertype) == 'reseller'
    es_options[:reseller_id] = current_user.id if es_options[:is_reseller]

    if s_user_id.to_i < 1 && current_user.usertype == 'accountant' && current_user.show_only_assigned_users.to_i == 1
      es_options[:show_only_assigned_users] = 1
      current_acc_id = current_user.id
      es_options[:user_array] = User.where(usertype: 'user', responsible_accountant_id: current_acc_id).pluck(:id)
      es_options[:reseller_array] = User.where(usertype: 'reseller', responsible_accountant_id: current_acc_id).pluck(:id)
    end

    data[:options].merge!(default_formatting_options(current_user))

    return data, es_options
  end

  def self.country_stats_data_prepare(data, es_country_stats, is_reseller)
    # If query to ES failed or no data found, return no data
    if es_country_stats.blank? || es_country_stats['aggregations']['grouped_by_dg_id']['buckets'].blank?
      data[:graphs].each_key { |key| data[:graphs][key] << "#{_('No_result')};1;false\\n" }
    else
      data = country_stats_data_count(
          data,
          es_country_stats['aggregations']['grouped_by_dg_id']['buckets'],
          is_reseller
      )
      data = country_stats_graphs(data)
    end

    country_stats_totals_format(data)
  end

  def self.country_stats_data_count(data, es_result, is_reseller)
    es_result.each do |bucket|
      calls = bucket['doc_count'].to_i
      total_billsec = bucket['total_billsec']['value'].to_d
      total_provider_price = bucket['total_provider_price']['value'].to_d * data[:options][:exchange_rate]
      total_user_price = bucket['total_user_price']['value'].to_d * data[:options][:exchange_rate]
      total_reseller_price = bucket['total_reseller_price']['value'].to_d * data[:options][:exchange_rate]
      total_did_inc_price = bucket['total_did_inc_price']['value'].to_d * data[:options][:exchange_rate]

      destination_group = Destinationgroup.where(id: bucket['key'].to_i).first
      destination_group_name = destination_group.try(:name)

      if destination_group_name.blank?
        bucket['key'].to_i > 0 ? destination_group_name = 'Destination Group missing' : destination_group_name = 'Unassigned Destination'
      end

      to_row = {
          destination_group_id: destination_group.try(:id),
          flag: destination_group.try(:flag).try(:downcase),
          destination_group_name: destination_group_name,
          calls: calls,
          time: total_billsec
      }

      if is_reseller
        to_row[:price] = total_reseller_price
        to_row[:user_price] = total_user_price + total_did_inc_price
      else
        to_row[:price] = total_provider_price
        to_row[:user_price] = total_user_price
      end

      to_row[:profit] = to_row[:user_price] - to_row[:price]

      data[:table_rows] << to_row

      data[:table_totals][:calls] += calls
      data[:table_totals][:time] += total_billsec
      data[:table_totals][:price] += to_row[:price]
      data[:table_totals][:user_price] += to_row[:user_price]
      data[:table_totals][:profit] += to_row[:profit]
    end

    return data
  end

  def self.country_stats_graphs(data)
    data = country_stats_graphs_time(data)
    data = country_stats_graphs_income(data)
    data = country_stats_graphs_profit(data)

    return data
  end

  def self.country_stats_graphs_time(data)
    graph_time_percent = data[:table_totals][:time] * 0.025
    other_time = 0

    data[:table_rows].each do |row|
      if row[:time] < graph_time_percent
        other_time += row[:time]
      else
        data[:graphs][:time] << "#{row[:destination_group_name]};#{row[:time].to_i / 60};false\\n"
      end
    end

    if other_time > 0
      data[:graphs][:time] << "#{_('Others')};#{other_time.to_i / 60};false\\n"
    end

    return data
  end

  def self.country_stats_graphs_income(data)
    graph_income_percent = data[:table_totals][:user_price] * 0.025
    other_income = 0

    data[:table_rows].each do |row|
      next if row[:user_price] <= 0

      if row[:user_price] < graph_income_percent
        other_income += row[:user_price]
      else
        data[:graphs][:income] << "#{row[:destination_group_name]};#{nice_number_with_separator(row[:user_price], data[:options][:number_digits], '.')};false\\n"
      end
    end

    if other_income > 0
      data[:graphs][:income] << "#{_('Others')};#{nice_number_with_separator(other_income, data[:options][:number_digits], '.')};false\\n"
    end

    return data
  end

  def self.country_stats_graphs_profit(data)
    graph_profit_percent = data[:table_totals][:profit] * 0.025
    other_profit = 0

    data[:table_rows].each do |row|
      next if row[:profit] <= 0

      if row[:profit] < graph_profit_percent
        other_profit += row[:profit]
      else
        data[:graphs][:profit] << "#{row[:destination_group_name]};#{nice_number_with_separator(row[:profit], data[:options][:number_digits], '.')};false\\n"
      end
    end

    if other_profit > 0
      data[:graphs][:profit] << "#{_('Others')};#{nice_number_with_separator(other_profit, data[:options][:number_digits], '.')};false\\n"
    end

    return data
  end

  def self.country_stats_totals_format(data)
    data[:graphs].each_key { |key| data[:graphs][key] << "\"" }

    data[:table_totals][:time] = nice_time(data[:table_totals][:time])

    [:price, :user_price, :profit].each do |key|
      data[:table_totals][key] = nice_number_with_separator(
          data[:table_totals][key], data[:options][:number_digits], data[:options][:number_decimal]
      )
    end

    return data
  end
end
