module ApiRequiredParams
  def self.method_is_defined_in_required_params_module(method)
    required_params_for_api_method.has_key?(method.to_s.to_sym)
  end

  def self.get_required_params_for_api_method(method)
    required_params_for_api_method[method.to_s.to_sym] ||= []
  end

  # here you must add new api method with required params for it (in order that is specified in ticket)
  # note, that you can create array of strings as %w[param_one param_two]
  # for example: %w[param_one param_two] == ['param_one', 'param_two']
  def self.required_params_for_api_method
    {
      subscription_delete: %w[subscription_id subscription_delete_action],
      subscriptions_get: %w[],
      subscription_update: %w[subscription_id],
      user_sms_service_subscribe: %w[user_id sms_tariff_id],
      voucher_use: %w[voucher_number],
      did_subscription_stop: %w[dids_id],
      calling_card_update: %w[card_id],
      cc_group_create: %w[name],
      calling_cards_get: %w[],
      calling_card_update: %w[card_id],
      cc_groups_get: %w[],
      calling_cards_create: %w[card_group_id cards_from cards_till],
      cc_group_update: %w[cc_group_id],
      user_sms_get: %w[],
      recordings_get: %w[],
      device_update: %w[device authentication username host port],
      pbx_pool_create: %w[name],
      users_get: %w[u p],
      quickstats_get: %w[u]
    }
  end
end
