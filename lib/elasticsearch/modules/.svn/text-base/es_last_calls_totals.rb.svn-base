#-*- encoding : utf-8 -*-
module EsLastCallsTotals

  @options = {}

  def self.get_data(options)
    return data_init if options[:usertype].blank?

    @options = options
    @options[:usertype] = @options[:usertype].to_sym

    case @options[:usertype]
      when :admin
        admin_totals
      when :reseller
        reseller_totals
      when :partner
        partner_totals
      when :accountant
        admin_totals
      when :user
        user_totals
      else
        data_init
    end
  end

  private

  def self.data_init
    {
      total_duration: 0, total_partner_price: 0, total_provider_price: 0,
      total_reseller_price: 0, total_user_price: 0, total_did_prov_price: 0,
      total_did_inc_price: 0, total_did_price: 0, total_profit: 0, total_calls: 0
    }
  end

  def self.admin_totals
    @options.merge!(default_options)

    # Accountant case is added to the Admin's case because of similarities
    if @options[:usertype] == :accountant
      resp_acc = User.where(id: @options[:current_user][:id]).first
      if resp_acc.present? && resp_acc.show_only_assigned_users == 1
        @options[:resp_acc_user_ids] = resp_acc.responsible_accountant_users(include_owner_users: true).pluck(:id)
        @options[:resp_acc_user_ids] = [-1] if @options[:resp_acc_user_ids].empty?
        @options[:resp_acc_device_ids] = resp_acc.responsible_accountant_user_devices(include_owner_users: true).pluck(:id)
        @options[:resp_acc_device_ids] = [-1] if @options[:resp_acc_device_ids].empty?
      end
    end

    response = Elasticsearch.safe_search_mor_calls(ElasticsearchQueries.last_calls_totals_admin(@options))
    data = data_init
    aggs = response.present? ? response['aggregations'] : nil
    data[:total_calls] = response['hits']['total'] if response.present?

    if aggs.present?
      exrate = @options[:exchange_rate]
      # Total duration
      data[:total_duration] = aggs['total_duration']['value']

      # Total Provider price = Call Provider price - Reseller PRO Provider price
      provider_price = aggs['total_provider_price']['value']
      rspro_provider_price = aggs['calls_by_rspros']['total_rspro_provider_price']['value']
      data[:total_provider_price] = (provider_price - rspro_provider_price) * exrate

      # Total Reseller price = Call Reseller price - Reseller PRO price
      reseller_price = aggs['total_reseller_price']['value']
      rspro_price =  aggs['calls_by_rspros']['total_rspro_price']['value']
      data[:total_reseller_price] = (reseller_price - rspro_price) * exrate

      # Total User price
      data[:total_user_price] = aggs['total_user_price']['value'] * exrate

      # Total DID prices
      data[:total_did_prov_price] = aggs['total_did_prov_price']['value'] * exrate
      data[:total_did_inc_price] = aggs['total_did_inc_price']['value'] * exrate
      data[:total_did_price] = aggs['total_did_price']['value'] * exrate

      # Total profit = profit from Partners + profit from Resellers + profit from Users -
      #   - Reseller PRO profit - Provider price + DID profit
      profit_from_partners = aggs['calls_by_partners']['total_profit_from_partners']['value']
      profit_from_resellers = aggs['non_partner_calls']['calls_by_resellers']['total_profit_from_resellers']['value']
      profit_from_users = aggs['calls_by_users']['total_profit_from_users']['value']
      rspro_profit = aggs['non_partner_calls']['calls_by_resellers']['calls_by_rspros']['total_rspro_profit']['value']

      data[:total_profit] = (profit_from_partners + profit_from_resellers + profit_from_users - rspro_profit) * exrate -
          data[:total_provider_price] + data[:total_did_prov_price] + data[:total_did_inc_price] + data[:total_did_price]
    end
    data
  end

  def self.reseller_totals
    @options.merge!(default_options)
    # Current-Reseller-owned Users' ids
    @options[:user_ids] = User.where(owner_id: @options[:current_user][:id]).pluck(:id)

    response = Elasticsearch.safe_search_mor_calls(ElasticsearchQueries.last_calls_totals_reseller(@options))
    data = data_init
    aggs = response.present? ? response['aggregations'] : nil
    data[:total_calls] = response['hits']['total'] if response.present?

    if aggs.present?
      exrate = @options[:exchange_rate]
      # Total duration
      data[:total_duration] = aggs['total_duration']['value']

      # Total Self-cost = Call Resellers price - Reseller PRO Provider price
      reseller_price = aggs['total_reseller_price']['value']
      rspro_provider_price = aggs['calls_by_rspros']['total_rspro_provider_price']['value']
      rspro_price = aggs['calls_by_rspros']['total_rspro_price']['value']

      # Total User price
      data[:total_user_price] = aggs['total_user_price']['value'] * exrate

      # Reseller PRO case
      if @options[:current_user][:own_providers] == 1
        # Provider price = Reseller price + Reseller PRO provider price - Reseller PRO price
        provider_price = (reseller_price + rspro_provider_price - rspro_price) * exrate
        data[:total_provider_price] = provider_price
        # Total profit = profit from Users - Reseller Provider price
        data[:total_profit] = data[:total_user_price] - provider_price
      else # Simple Reseller case
        # Reseller Self-cost = Reseller price - Reseller PRO price
        self_cost = (reseller_price - rspro_price) * exrate
        data[:total_reseller_price] = self_cost
        # Total profit = profit from Users - Reseller Self-cost - Reseller PRO price
        data[:total_profit] = data[:total_user_price] - self_cost - rspro_provider_price * exrate
      end

      # Total DID prices
      data[:total_did_inc_price] = aggs['calls_by_owned_users']['total_did_inc_price']['value'] * exrate
      data[:total_did_price] = aggs['calls_not_by_owned_users']['total_did_price']['value'] * exrate
    end
    data
  end

  def self.partner_totals
    @options.merge!(default_options)

    response = Elasticsearch.safe_search_mor_calls(ElasticsearchQueries.last_calls_totals_partner(@options))
    data = data_init
    aggs = response.present? ? response['aggregations'] : nil
    data[:total_calls] = response['hits']['total'] if response.present?

    if aggs.present?
      exrate = @options[:exchange_rate]
      # Total duration
      data[:total_duration] = aggs['total_duration']['value']

      # Total Self-cost = Calls Partners' price - Reseller PRO Providers' price
      partner_price = aggs['total_partner_price']['value']
      rspro_partner_price = aggs['calls_by_rspros']['total_rspro_partner_price']['value']
      data[:total_partner_price] = (partner_price - rspro_partner_price) * exrate

      # Total Resellers' price = Calls Resellers' price - Reseller PRO Providers' price
      reseller_price = aggs['total_reseller_price']['value']
      rspro_reseller_price = aggs['calls_by_rspros']['total_rspro_reseller_price']['value']
      data[:total_reseller_price] = (reseller_price - rspro_reseller_price) * exrate

      # Total User price
      data[:total_user_price] = aggs['total_user_price']['value'] * exrate

      # Total profit = profit from Resellers' - Partners's Self-cost + Reseller PROs' price
      rspro_provider_price = aggs['calls_by_rspros']['total_rspro_provider_price']['value']
      data[:total_profit] = data[:total_reseller_price] - data[:total_partner_price] +
          (rspro_provider_price - rspro_partner_price) * exrate
    end
    data
  end

  def self.user_totals
    # We need less options than default
    @options[:card_ids] = Card.where(user_id: @options[:current_user][:id])
    @options[:s_hgc].blank? ? [] : Hangupcausecode.where(id: @options[:s_hgc]).first.try(:code)
    if Confline.get_value('Invoice_user_billsec_show', @options[:current_user][:owner_id]).to_i == 1
      @options[:user_billsec_script] = 'Math.ceil(doc.user_billsec.value)'
    else
      @options[:user_billsec_script] = 'doc.billsec.value == 0 && doc.real_billsec.value > 1 ? Math.ceil(doc.real_billsec.value) : doc.billsec.value'
    end

    response = Elasticsearch.safe_search_mor_calls(ElasticsearchQueries.last_calls_totals_user(@options))
    data = data_init
    aggs = response.present? ? response['aggregations'] : nil
    data[:total_calls] = response['hits']['total'] if response.present?

    if aggs.present?
      exrate = @options[:exchange_rate]
      # Total duration
      data[:total_duration] = aggs['total_duration']['value']

      # Total User price = Calls made by a current User price and DID price +
      #   Calls answered by a current User price
      data[:total_user_price] = (aggs['calls_made_by_user']['total_user_call_price']['value'] +
          aggs['calls_made_by_user']['total_user_call_did_price']['value'] +
          aggs['calls_answered_by_user']['total_user_call_did_price']['value']) * exrate
    end
    data
  end

  def self.default_options
    # Ids of Providers which belong to Resellers PRO
    @options[:rspro_prov_ids] = Confline.get_value('RSPRO_Active').to_i == 1 ? Provider.where('user_id > 0').pluck(:id) : []
    # Ids of Devices which belong to a User from search
    @options[:device_ids] = @options[:s_user_id].blank? ? [] : Device.where(user_id: @options[:s_user_id]).pluck(:id)
    # Hangup Cause Code by id from search
    @options[:hangup] = @options[:s_hgc].blank? ? [] : Hangupcausecode.where(id: @options[:s_hgc]).first.try(:code)
    # Ids of DIDs due to parameters from search
    @options[:did_ids] = did_ids
    # Ids of Cards due to parameters from search
    @options[:card_ids] = card_ids
    @options
  end

  def self.did_ids
    did_cond = []
    did_vals = []
    # Construct a single query for getting the DID ids
    unless @options[:s_did_pattern].blank?
      did_cond << 'did LIKE ?'
      did_vals << @options[:s_did_pattern]
    end
    unless @options[:s_reseller_did].blank? || @options[:s_reseller_did] == 'all'
      did_cond << 'reseller_id = ?'
      did_vals << @options[:s_reseller_did]
    end
    # Do not perform mysql unless there is a condition
    did_cond.empty? ? [] : Did.where(did_cond.join(' AND '), *did_vals).pluck(:id)
  end

  def self.card_ids
    card_cond = []
    card_vals = []
    # Construct a single query for getting the Card ids
    unless @options[:s_user_id].blank? || %w(-2 -1).include?(@options[:s_user_id])
      card_cond << 'user_id = ?'
      card_vals << @options[:s_user_id]
    end

    unless @options[:s_card_number].blank?
      card_cond << 'number LIKE ?'
      card_vals << @options[:s_card_number]
    end

    unless @options[:s_card_pin].blank?
      card_cond << 'pin LIKE ?'
      card_vals << @options[:s_card_pin]
    end

    if @options[:s_card_id].to_s.gsub('%', '').length > 0
      card_cond << 'id LIKE ?'
      card_vals << @options[:s_card_id]
    else
      @options[:s_card_id] = ''
    end

    # Do not perform mysql unless there is a condition
    card_cond.empty? ? [] : Card.where(card_cond.join(' AND '), *card_vals).pluck(:id)
  end
end
