#-*- encoding : utf-8 -*-
module EsHgcStats
  extend UniversalHelpers

  def self.get_data(options = {})
    calls, graph =
        {calls: [], total_calls: 0}, {calls: "\"", hangupcausecode: ''}

    # Country code is hidden in ES until a good solution is found.
    country_code = options[:country_code]
    provider_id = options[:provider_id]
    user_id = options[:user_id]
    current_user = options[:current_user]
    device_id = options[:device_id]

    es_options = {}
    es_options[:provider_id] = provider_id if provider_id.to_i >= 0
    es_options[:user_id] = user_id unless user_id == -1
    es_options[:is_reseller] = current_user.usertype == 'reseller'
    es_options[:reseller_id] = current_user.id if es_options[:is_reseller]
    es_options[:device_id] = device_id if device_id.to_i >= 0

    if user_id < 1 && current_user.usertype == 'accountant' && current_user.show_only_assigned_users.to_i == 1
      es_options[:show_only_assigned_users] = 1
      current_acc_id = current_user.id
      es_options[:user_array] = User.where(usertype: 'user', responsible_accountant_id: current_acc_id).pluck(:id)
      es_options[:reseller_array] = User.where(usertype: 'reseller', responsible_accountant_id: current_acc_id).pluck(:id)
    end

    seconds_offset = (Time.zone.now.utc_offset().second - Time.now.utc_offset().second).to_i
    utc_offset = ActiveSupport::TimeZone.seconds_to_utc_offset(seconds_offset)
    es_options[:utc_offset] = utc_offset

    es_hgc = Elasticsearch.safe_search_mor_calls(ElasticsearchQueries.es_hangup_cause_codes_stats_query(options[:a1], options[:a2], es_options))
    es_hgc_good_calls = Elasticsearch.safe_search_mor_calls(ElasticsearchQueries.es_hangup_cause_codes_stats_calls_query(options[:a1], options[:a2], es_options.merge({good_calls: true})))
    es_hgc_bad_calls = Elasticsearch.safe_search_mor_calls(ElasticsearchQueries.es_hangup_cause_codes_stats_calls_query(options[:a1], options[:a2], es_options.merge({bad_calls: true})))
    return [calls, graph] if es_hgc.blank? || es_hgc_good_calls.blank? || es_hgc_bad_calls.blank?

    calls[:total_calls] = es_hgc['hits']['total'].to_i

    es_hgc['aggregations']['grouped_by_hgc']['buckets'].each do |bucket|
      hangup_cause_code = bucket['key'].to_i
      hangup_cause_code_calls = bucket['doc_count'].to_i
      hangup_cause = Hangupcausecode.where(code: hangup_cause_code).first

      # Table Data
      calls[:calls] << {
          hc_code: hangup_cause_code, calls: hangup_cause_code_calls,
          hc_id: hangup_cause.try(:id).to_s, hc_description: hangup_cause.try(:description).to_s
      }

      # Graph Pie
      graph[:calls] << "#{hangup_cause_code};#{hangup_cause_code_calls};false\\n"
    end

    # Graph Bar
    hgc_good_bad_calls = []
    es_hgc_good_calls['aggregations']['dates']['buckets'].each do |bucket|
      date = bucket['key_as_string'].to_s
      good_calls = bucket['doc_count'].to_i

      hgc_good_bad_calls << {date: date, good_calls: good_calls, bad_calls: 0}
    end

    es_hgc_bad_calls['aggregations']['dates']['buckets'].each do |bucket|
      date = bucket['key_as_string'].to_s
      bad_calls = bucket['doc_count'].to_i

      if hgc_good_bad_calls.find { |dates| dates[:date] == date }.try(:[]=, :bad_calls, bad_calls)
      else
        hgc_good_bad_calls << {date: date, good_calls: 0, bad_calls: bad_calls}
      end
    end

    hgc_good_bad_calls.each do |date|
      graph[:hangupcausecode] << "#{date[:date]};#{date[:good_calls]};#{date[:bad_calls]}\\n"
    end

    if calls[:total_calls] <= 0
      graph[:calls] << "#{_('No_result')};1;false\\n\""
    else
      graph[:calls] << "\""
    end
    graph[:hangupcausecode] = _('No_result') if graph[:hangupcausecode].blank?

    return calls, graph
  end
end
