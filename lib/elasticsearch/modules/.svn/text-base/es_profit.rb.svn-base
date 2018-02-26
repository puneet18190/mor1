#-*- encoding : utf-8 -*-
module EsProfit
  extend UniversalHelpers

  def self.get_data(options = {})
    data, es_options = profit_variables(options)

    es_profit = Elasticsearch.safe_search_mor_calls(ElasticsearchQueries.profit(es_options))
    return data[:table_totals] if es_profit.blank? || es_profit['aggregations'].blank?

    profit_data_prepare(data, es_profit)
  end

  def self.profit_variables(options)
    data = {
        table_totals: {
            total_calls: 0, answered: 0, busy: 0, no_answer: 0, error: 0, total_answer_percent: 0,
            total_not_ans_percent: 0, total_busy_percent: 0, total_error_percent: 0, total_duration: 0,
            total_call_duration: 0, total_call_price: 0, total_did_price: 0, total_did_price: 0,
            total_call_selfprice: 0, active_users: 0, total_selfcost_percent: 0, total_profit:0,
            total_profit_percent: 0, avg_profit_call_min: 0, avg_profit_call: 0, avg_profit_day: 0,
            avg_profit_user: 0, sub_price: 0, s_total_profit: 0, total_percent: 0
        },
        options: {from: options[:session_from] ,
                  till: options[:session_till] ,
                  till_sub: options[:session_till_for_subsc]
        }
    }

    current_user = options[:current_user]
    seconds_offset = (Time.zone.now.utc_offset().second - Time.now.utc_offset().second).to_i
    utc_offset = ActiveSupport::TimeZone.seconds_to_utc_offset(seconds_offset)
    user_id = options[:s_user_id].to_i
    users = User.where('id = ? OR owner_id = ?', user_id, user_id).pluck(:id)

    es_options = {
        from: options[:from], till: options[:till],
        utc_offset: utc_offset,
        usertype: current_user.usertype,
        current_user_id: current_user.id
    }

    # Users if we are looking for them
    es_options[:user_id] = users if options[:s_user_id].to_i != -1
    # This is user type that i looking for
    es_options[:s_usertype] = data[:options][:s_user_type] = User.where(id: options[:s_user_id]).first.usertype.to_s if options[:s_user_id].to_i != -1


    accountant_id = options[:responsible_accountant_id]
    if accountant_id > 0 && accountant_id.present? && options[:s_user_id].to_i == -1
      es_options[:user_id]= User.where(responsible_accountant_id: accountant_id).pluck(:id)
    end

    data[:options][:s_user_id] = user_id
    data[:options][:accountant_id] = accountant_id
    data[:options].merge!(default_formatting_options(current_user, {show_currency: options[:show_currency]}))
    return data, es_options
  end

  def self.profit_data_prepare(data, es_profit)
    current_user = data[:options][:usertype]
    s_usertype = data[:options][:s_user_type]
    # Top of the table
    # Answered calls are those "calls.disposition = 'ANSWERED' AND calls.hangupcause = 16"
    answered = es_profit['aggregations']['for_all']['answered']['succesfull']['doc_count'].to_i
    no_answer = es_profit['aggregations']['for_all']['no_answer']['doc_count'].to_i
    busy = es_profit['aggregations']['for_all']['busy']['doc_count'].to_i
    # Error calls are disposition = 'FAILED' + "calls.disposition = 'ANSWERED' AND calls.hangupcause = 16"
    failed = es_profit['aggregations']['for_all']['failed']['doc_count'].to_i
    ansewered_not_failed = es_profit['aggregations']['for_all']['answered']['doc_count'].to_i
    unsuccesful = ansewered_not_failed - answered
    error = failed + unsuccesful

    total_calls = answered + no_answer + busy + error
    calls_not_nul = total_calls > 0


    if current_user == 'partner'
      total_duration = es_profit['aggregations']['for_all']['answered']['total_reseller_billsec']['value']
    else
      total_duration_not_nul = es_profit['aggregations']['for_all']['answered']['succesfull']['billsec_not_nul']['billsec']['value'].to_d
      total_duration_nul = es_profit['aggregations']['for_all']['answered']['succesfull']['billsec_nul']['real_billsec']['value'].to_d
      total_duration = total_duration_not_nul + total_duration_nul
    end

    if total_duration != 0
      total_answer_percent = answered.to_d * 100 / total_calls.to_d
      total_not_ans_percent = no_answer.to_d * 100 / total_calls.to_d
      total_busy_percent = busy.to_d * 100 / total_calls.to_d
      total_error_percent = error.to_d * 100 / total_calls.to_d
    end

    total_call_duration = total_duration / answered

    # midle
    total_user_price = es_profit['aggregations']['for_all']['answered']['total_user_price']['value']
    total_did_inc_price = es_profit['aggregations']['for_all']['answered']['total_did_inc_price']['value']

    if ['user', 'reseller', 'partner'].include?(s_usertype)
      total_did_price = es_profit['aggregations']['for_user']['total_did_price_for_user']['value'] * data[:options][:exchange_rate]
    else
      total_did_price = es_profit['aggregations']['for_all']['answered']['total_did_price']['value'] * data[:options][:exchange_rate]
    end

    total_did_prov_price = es_profit['aggregations']['for_all']['answered']['total_did_prov_price']['value']
    total_provider_price = es_profit['aggregations']['for_all']['answered']['total_provider_price']['value']
    total_reseller_price = es_profit['aggregations']['for_all']['answered']['total_reseller_price']['value']
    total_partner_price = es_profit['aggregations']['for_all']['answered']['total_partner_price']['value']
    total_users = es_profit['aggregations']['for_all']['answered']['total_users']['value']
    total_users_for_admin = es_profit['aggregations']['for_all']['answered']['total_users_for_admin']['total_users_for_admin_value']['value']
    total_resellers = es_profit['aggregations']['for_all']['answered']['total_resellers']['value']
    total_resellers_for_admin = es_profit['aggregations']['for_all']['answered']['total_resellers_for_admin']['total_resellers_for_admin_value']['value']
    total_partners_for_admin = es_profit['aggregations']['for_all']['answered']['total_partners_for_admin']['total_partners_for_admin_value']['value']

    if current_user == 'reseller'
      total_call_selfprice = total_reseller_price * data[:options][:exchange_rate]
    elsif current_user == 'partner'
      total_call_selfprice = total_partner_price * data[:options][:exchange_rate]
    else
      total_call_selfprice = (total_provider_price - total_did_prov_price) * data[:options][:exchange_rate]
    end

    if current_user == 'admin'
      user_price_for_admin = es_profit['aggregations']['for_all']['answered']['total_user_prices_for_admin']['user_price_for_admin']['value']
      reseller_price_for_admin = es_profit['aggregations']['for_all']['answered']['total_reseller_prices_for_admin']['reseller_price_for_admin']['value']
      if s_usertype == 'reseller'
        total_call_price = total_reseller_price * data[:options][:exchange_rate]
        active_users = total_resellers_for_admin
      elsif s_usertype == 'partner'
        total_call_price = total_partner_price * data[:options][:exchange_rate]
        active_users = total_partners_for_admin
      else
        total_call_price = (user_price_for_admin + reseller_price_for_admin + total_did_inc_price + total_partner_price) * data[:options][:exchange_rate]
        active_users = total_users_for_admin + total_resellers_for_admin + total_partners_for_admin
      end
    elsif current_user == 'partner'
      total_call_price = total_reseller_price * data[:options][:exchange_rate]
      active_users = total_resellers
    else
      total_call_price = (total_user_price + total_did_inc_price) * data[:options][:exchange_rate]
      active_users = total_users
    end

    total_profit = total_call_price - total_call_selfprice + (current_user == 'admin' ? total_did_price : 0)
    total_percent = total_profit != 0 ? 100 : 0

    #bottom side
    date_from = data[:options][:from]
    date_till = data[:options][:till]
    date_till_subsc = data[:options][:till_sub]

    total_profit_percent = total_profit.to_d != 0 ? total_profit.to_d * 100 / total_call_price.to_d : 0
    total_selfcost_percent = total_percent - total_profit_percent
    if total_duration != 0
      total_duration_min = total_duration.to_d / 60
      avg_profit_call_min = total_profit.to_d / total_duration_min
      avg_profit_call = total_profit.to_d / answered.to_d
      days = (date_till.to_date - date_from.to_date).to_i == 0 ? 1 : (date_till.to_date - date_from.to_date).to_i
      avg_profit_day = total_profit.to_d / (date_till.to_date - date_from.to_date + 1).to_i
      avg_profit_user = total_profit.to_d / active_users.to_d
    end

    # subscription
    is_reseller = current_user == 'reseller'
    s_total_profit = total_profit
    unless current_user == 'partner'
      res = Stat.find_services_for_profit(is_reseller, date_from, date_till_subsc, data[:options][:accountant_id], data[:options][:s_user_id])
      sub_price = 0
      sub_price = Stat.find_subs_params(res, date_from, date_till_subsc, sub_price) * data[:options][:exchange_rate]
      s_total_profit += sub_price
    end

    data[:table_totals] = {total_calls: total_calls, answered: answered, busy: busy, no_answer: no_answer, error: error,
                           total_answer_percent: total_answer_percent.to_d, total_not_ans_percent: total_not_ans_percent,
                           total_busy_percent: total_busy_percent, total_error_percent: total_error_percent, total_duration: total_duration,
                           total_call_duration: total_call_duration, total_call_price: total_call_price,
                           total_did_price: total_did_price, total_percent: total_percent,
                           total_call_selfprice: total_call_selfprice, active_users: active_users,
                           total_selfcost_percent: total_selfcost_percent, total_profit: total_profit,
                           total_profit_percent: total_profit_percent, avg_profit_call_min: avg_profit_call_min,
                           avg_profit_call: avg_profit_call, avg_profit_day: avg_profit_day,
                           avg_profit_user: avg_profit_user, sub_price: sub_price, s_total_profit: s_total_profit}

    return data[:table_totals]
  end
end
