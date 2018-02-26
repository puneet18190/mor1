#-*- encoding : utf-8 -*-
module EsAggregates
  extend UniversalHelpers

  def self.get_data(options = {})
    data, es_options = variables(options)

    es_aggregates = Elasticsearch.safe_search_mor_calls(ElasticsearchQueries.aggregates(es_options))

    aggregates_data_prepare(data, es_aggregates)
  end

  def self.variables(options = {})
    data = {
        table_rows: [],
        table_totals: {
            billed_originator: 0, billed_originator_with_tax: 0, billed_terminator: 0,
            billed_duration_originator: 0, billed_duration_terminator: 0, duration: 0,
            answered_calls: 0, total_calls: 0, asr: 0, acd: 0
        },
        options: {
            answered_calls: options[:answered_calls].to_i,
            group_by: []
        }
    }

    current_user = options[:current_user]

    seconds_offset = (Time.zone.now.utc_offset().second - Time.now.utc_offset().second).to_i
    utc_offset = ActiveSupport::TimeZone.seconds_to_utc_offset(seconds_offset)

    es_options = {
        from: options[:from], till: options[:till],
        utc_offset: utc_offset,
        hour_offset: seconds_offset / 3600,
        group_by: []
    }

    if options[:originator_id].to_i > 0 || options[:originator_id].to_i == -2
      es_options[:user] = options[:originator_id] if options[:originator_id].to_i > 0
      es_options[:group_by] << {group_name: 'agg_by_user', group_field: 'user_id'}
      data[:options][:group_by] << :originator
    end

    if options[:terminator].to_i >= 0
      es_options[:providers] = Provider.where(terminator_id: options[:terminator]).pluck(:id) if options[:terminator].to_i > 0
      es_options[:group_by] << {group_name: 'agg_by_provider', group_field: 'provider_id'}
      data[:options][:group_by] << :terminator
    end

    if options[:destination_group].to_i >= 0
      es_options[:destinationgroup_id] = options[:destination_group] if options[:destination_group].to_i > 0
      es_options[:group_by] << {group_name: 'agg_by_dg', group_field: 'destinationgroup_id'}
      data[:options][:group_by] << :destination_group
    end

    if options[:prefix].present?
      es_options[:prefix] = options[:prefix]
      es_options[:group_by] << {group_name: 'agg_by_prefix', group_field: 'prefix'}
      data[:options][:group_by] << :prefix

      if options[:destination_group].to_i < 0
        es_options[:group_by] << {group_name: 'agg_by_dg', group_field: 'destinationgroup_id'}
        data[:options][:group_by] << :destination_group
      end
    end

    if options[:s_user_id].to_i == 0 && current_user.usertype == 'accountant' && current_user.show_only_assigned_users.to_i == 1
      es_options[:show_only_assigned_users] = 1
      current_acc_id = current_user.id
      es_options[:user_array] = User.where(usertype: 'user', responsible_accountant_id: current_acc_id).pluck(:id)
      es_options[:reseller_array] = User.where(usertype: 'reseller', responsible_accountant_id: current_acc_id).pluck(:id)
    end

    es_options[:use_real_billsec] = true if options[:use_real_billsec].to_i > 0
    es_options[:user_perspective] = true if options[:from_user_perspective].to_i > 0

    data[:options][:es_group_by] = es_options[:group_by]
    data[:options].merge!(default_formatting_options(current_user))

    return data, es_options
  end

  def self.aggregates_data_prepare(data, es_aggregates)
    if es_aggregates.present? && es_aggregates['aggregations'].present?
      groups = data[:options][:es_group_by]
      group_levels = groups.size

      data_out = []
      es_aggregates['aggregations'][groups[0][:group_name]]['buckets'].each do |level_one_data|
        input = {}
        input[groups[0][:group_field]] = level_one_data['key']

        if group_levels > 1
          level_one_data[groups[1][:group_name]]['buckets'].each do |level_two_data|
            input[groups[1][:group_field]] = level_two_data['key']
            add_input_values(data_out, input, level_two_data) if group_levels == 2

            if group_levels > 2
              level_two_data[groups[2][:group_name]]['buckets'].each do |level_three_data|
                input[groups[2][:group_field]] = level_three_data['key']
                add_input_values(data_out, input, level_three_data) if group_levels == 3

                if group_levels > 3
                  level_three_data[groups[3][:group_name]]['buckets'].each do |level_four_data|
                    input[groups[3][:group_field]] = level_four_data['key']
                    add_input_values(data_out, input, level_four_data) if group_levels == 4
                  end
                end
              end
            end
          end
        end

        add_input_values(data_out, input, level_one_data) if group_levels == 1
      end

      data_out = group_providers_into_terminators(data_out) if data[:options][:group_by].include?(:terminator)

      if data_out.present?
        data_cache = {dg_name: {}, user: {}}

        data_out.each do |data_row|
          answered_calls = data_row['answered_calls']
          next if answered_calls < data[:options][:answered_calls]
          total_calls = data_row['total_calls']
          billed_originator = data_row['billed_originator'] * data[:options][:exchange_rate]
          billed_terminator = data_row['billed_terminator'] * data[:options][:exchange_rate]
          billed_duration_originator = data_row['billed_duration_originator']
          billed_duration_terminator = data_row['billed_duration_terminator']
          duration = data_row['duration']

          to_row = {
              billed_originator: billed_originator,
              billed_originator_with_tax: 0.to_d,
              billed_terminator: billed_terminator,
              billed_duration_originator: billed_duration_originator,
              billed_duration_terminator: billed_duration_terminator,
              duration: duration,
              answered_calls: answered_calls,
              total_calls: total_calls,
              asr: ((answered_calls.to_d / total_calls.to_d) * 100),
              acd: (duration / answered_calls.to_d)
          }
          [:asr, :acd].each { |key| to_row[key] = 0.to_d if to_row[key].nan? || to_row[key].infinite? }

          dg_id = data_row['destinationgroup_id']
          if dg_id.present?
            destination_group_name = Destinationgroup.where(id: dg_id).first.try(:name)
            if dg_id.to_i == 0
              to_row[:destination_group] = 'Unassigned Destination'
            elsif dg_id.to_i > 0 && destination_group_name.blank?
              to_row[:destination_group] = 'Destination Group missing'
            else
              to_row[:destination_group] = data_cache[:dg_name][dg_id] ||= destination_group_name
            end
          end

          prefix = data_row['prefix']
          if prefix.present?
            to_row[:prefix] = prefix
          end

          user_id = data_row['user_id']
          if user_id.present?
            user = data_cache[:user][user_id] ||= User.select("#{SqlExport.nice_user_name_sql}, users.*").where(id: user_id).first
            to_row[:originator] = user.try(:nicename)
            to_row[:originator_id] = user_id

            to_row[:billed_originator_with_tax] = user.get_tax.apply_tax(data_row['billed_originator']) * data[:options][:exchange_rate] if user.present?
          end

          terminator = data_row['terminator']
          if terminator.present?
            to_row[:terminator] = terminator
          end

          [
              :billed_originator, :billed_originator_with_tax, :billed_terminator, :billed_duration_originator,
              :billed_duration_terminator, :duration, :answered_calls, :total_calls
          ].each { |key| data[:table_totals][key] += to_row[key] }
          data[:table_rows] << to_row
        end

        data[:table_totals][:asr] = ((data[:table_totals][:answered_calls].to_d / data[:table_totals][:total_calls].to_d) * 100)
        data[:table_totals][:acd] = (data[:table_totals][:duration] / data[:table_totals][:answered_calls].to_d)
        [:asr, :acd].each do |key|
          data[:table_totals][key] = 0.to_d if data[:table_totals][key].nan? || data[:table_totals][key].infinite?
        end

        totals_format(data)
      end
    end

    data
  end

  def self.add_input_values(data_out, input, level_data)
    input['billed_originator'] = level_data['agg_by_answered']['total_originator_price']['value'].to_d
    input['billed_terminator'] = level_data['agg_by_answered']['total_terminator_price']['value'].to_d
    input['billed_duration_originator'] = level_data['agg_by_answered']['total_originator_billsec']['value'].to_d
    input['billed_duration_terminator'] = level_data['agg_by_answered']['total_terminator_billsec']['value'].to_d
    input['duration'] = level_data['agg_by_answered']['total_billsec']['value'].to_d
    input['answered_calls'] = level_data['agg_by_answered']['doc_count'].to_i
    input['total_calls'] = level_data['doc_count'].to_i

    data_out.push(input.clone)
  end

  def self.group_providers_into_terminators(data_with_providers)
    terminator_cache = {}
    data_grouped_into_terminators = {}

    data_with_providers.each do |row|
      provider_id = row['provider_id'].to_i

      terminator_id = Provider.where(id: provider_id).first.try(:terminator_id).to_s
      terminator = terminator_cache[terminator_id] ||= Terminator.select(:id, :name).where(id: terminator_id).first

      group_key = "#{row['destinationgroup_id']}|#{row['prefix']}|#{row['user_id']}|#{terminator.try(:id)}"

      if data_grouped_into_terminators[group_key].present?
        %w[billed_originator billed_terminator billed_duration_originator billed_duration_terminator duration answered_calls total_calls].each do |key|
          data_grouped_into_terminators[group_key][key] += row[key]
        end
      else
        data_grouped_into_terminators[group_key] = row
        data_grouped_into_terminators[group_key].delete('provider_id')
        data_grouped_into_terminators[group_key]['terminator_id'] = terminator.try(:id)
        data_grouped_into_terminators[group_key]['terminator'] = terminator.present? ? terminator.try(:name) : "<i>(#{_('Unassigned_Providers')})</i>".html_safe
      end
    end

    data_grouped_into_terminators.values
  end

  def self.totals_format(data)
    [:billed_originator, :billed_originator_with_tax, :billed_terminator].each do |key|
      data[:table_totals][key] = nice_number_with_separator(
          data[:table_totals][key], data[:options][:number_digits], data[:options][:number_decimal]
      )
    end

    [:billed_duration_originator, :billed_duration_terminator, :duration, :acd].each do |key|
      data[:table_totals][key] = nice_time(data[:table_totals][key], true)
    end

    [:answered_calls, :total_calls].each do |key|
      data[:table_totals][key] = data[:table_totals][key].to_i
    end

    data[:table_totals][:asr] = nice_number_with_separator(data[:table_totals][:asr], 2, data[:options][:number_decimal])
  end
end
