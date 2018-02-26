# -*- encoding : utf-8 -*-
# Simple User Rights
class SimpleUserRight < ActiveRecord::Base
  attr_protected

  has_many :simple_user_group_rights
  has_many :simple_user_groups, through: :simple_user_group_rights

  def self.get_permissions(permissions_access_level)
    permissions = default_permissions
    right_method_map = permissions_id_method_map

    permissions_access_level.each do |permission_access_level|
      right_method_map.select do |right_method|
        if right_method[:simple_user_right_id] == permission_access_level.simple_user_right_id
          permissions << send(right_method[:method], permission_access_level.value) if respond_to? right_method[:method]
        end
      end
    end

    permissions.flatten
  end

  def self.get_full_access
    permissions = default_permissions

    permissions_id_method_map.each do |right_method|
      permissions << send(right_method[:method], 2) if respond_to?(right_method[:method])
    end

    permissions.flatten
  end

  private

  def self.permissions_id_method_map
    [
        {simple_user_right_id: id_by_name('Personal_details'), method: :personal_details},
        {simple_user_right_id: id_by_name('Devices'), method: :devices},
        {simple_user_right_id: id_by_name('Rates'), method: :rates},
        {simple_user_right_id: id_by_name('Payments'), method: :payments},
        {simple_user_right_id: id_by_name('Invoices'), method: :invoices},
        {simple_user_right_id: id_by_name('Financial_statements'), method: :financial_statements},
        {simple_user_right_id: id_by_name('Subscriptions'), method: :subscriptions},
        {simple_user_right_id: id_by_name('Calls'), method: :calls},
        {simple_user_right_id: id_by_name('Active_calls'), method: :active_calls},
        {simple_user_right_id: id_by_name('Graphs'), method: :graphs},
        {simple_user_right_id: id_by_name('Recordings'), method: :recordings},
        {simple_user_right_id: id_by_name('DIDs'), method: :dids},
        {simple_user_right_id: id_by_name('CLIs'), method: :clis},
        {simple_user_right_id: id_by_name('PhoneBook'), method: :phonebook},
        {simple_user_right_id: id_by_name('Quick_Forwards'), method: :quick_forwards},
        {simple_user_right_id: id_by_name('Faxes'), method: :faxes},
        {simple_user_right_id: id_by_name('Callback'), method: :callback},
        {simple_user_right_id: id_by_name('Auto_Dialer'), method: :auto_dialer},
        {simple_user_right_id: id_by_name('Search'), method: :search}
    ]
  end

  def self.id_by_name(name)
    where(name: name.to_s).first.try(:id) || 0
  end

  def self.default_permissions
    [
        {controller: :callc, action: :change_currency},
        {controller: :callc, action: :login},
        {controller: :callc, action: :logout},
        {controller: :callc, action: :show_quick_stats},
        {controller: :callc, action: :main_quick_stats},
        {controller: :callc, action: :quick_stats_active_calls},
        {controller: :sms, action: :sms},
        {controller: :sms, action: :prefix_finder_find},
        {controller: :sms, action: :send_sms},
        {controller: :sms, action: :sms_list},
        {controller: :sms, action: :user_rates},
        {controller: :smsautodialer, action: :user_campaigns},
        {controller: :smsautodialer, action: :campaign_numbers},
        {controller: :smsautodialer, action: :import_numbers_from_file},
        {controller: :smsautodialer, action: :delete_all_numbers},
        {controller: :smsautodialer, action: :campaign_change_status},
        {controller: :smsautodialer, action: :campaign_actions},
        {controller: :smsautodialer, action: :campaign_edit},
        {controller: :smsautodialer, action: :campaign_update},
        {controller: :smsautodialer, action: :action_add},
        {controller: :smsautodialer, action: :play_rec},
        {controller: :smsautodialer, action: :action_destroy},
        {controller: :smsautodialer, action: :action_edit},
        {controller: :smsautodialer, action: :action_update},
        {controller: :smsautodialer, action: :campaign_new},
        {controller: :smsautodialer, action: :redial_all_failed_calls},
        {controller: :smsautodialer, action: :campaign_statistics},
        {controller: :smsautodialer, action: :campaign_destroy},
        {controller: :smsautodialer, action: :bad_numbers_from_csv},
        {controller: :smsautodialer, action: :number_destroy},
        {controller: :smsautodialer, action: :export_call_data_to_csv},
        {controller: :smsautodialer, action: :campaign_create},
        {controller: :vouchers, action: :voucher_use},
        {controller: :vouchers, action: :voucher_status},
        {controller: :vouchers, action: :voucher_pay},
        {controller: :cardgroups, action: :user_list},
        {controller: :cards, action: :user_list},
        {controller: :cardgroups, action: :cards_to_csv},
        {controller: :cards, action: :card_active},
        {controller: :cards, action: :bullk_for_activate},
        {controller: :cards, action: :bulk_confirm},
        {controller: :cards, action: :card_active_bulk},
        {controller: :stats, action: :cc_call_list},
        {controller: :functions, action: :test_file_upload},
        {controller: :stats, action: :user_logins},
        {controller: :callc, action: :main},
        {controller: :callc, action: :main_for_pda}
    ]
  end

  def self.personal_details(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
            {controller: :users, action: :personal_details},
            {controller: :users, action: :update_personal_details}
        ]
    end
  end

  def self.devices(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
            {controller: :devices, action: :user_devices},
            {controller: :devices, action: :callflow},
            {controller: :devices, action: :user_device_edit},
            {controller: :devices, action: :user_device_update},
            {controller: :devices, action: :callflow_edit},
            {controller: :devices, action: :try_to_forward_device},
            {controller: :devices, action: :device_forward}
        ]
    end
  end

  def self.rates(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
            {controller: :tariffs, action: :user_rates},
            {controller: :tariffs, action: :generate_personal_rates_csv},
            {controller: :tariffs, action: :generate_personal_wholesale_rates_csv},
            {controller: :destination_groups, action: :dg_list_user_destinations},
            {controller: :tariffs, action: :user_rates_detailed},
            {controller: :tariffs, action: :generate_personal_wholesale_rates_pdf},
            {controller: :tariffs, action: :generate_personal_rates_pdf}
        ]
    end
  end

  def self.payments(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
            {controller: :payments, action: :personal_payments},
            {controller: :payments, action: :paypal},
            {controller: :payments, action: :ouroboros},
            {controller: :payments, action: :ouroboros_pay},
            {controller: :payments, action: :webmoney},
            {controller: :payments, action: :webmoney_fail},
            {controller: :payments, action: :webmoney_pay},
            {controller: :payments, action: :paypal_pay},
            {controller: :payments, action: :paysera},
            {controller: :payments, action: :paysera_pay}
        ]
    end
  end

  def self.invoices(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
            { controller: :accounting, action: :user_invoices },
            { controller: :accounting, action: :user_invoice_details },
            { controller: :accounting, action: :generate_invoice_csv },
            { controller: :accounting, action: :generate_invoice_pdf },
            { controller: :accounting, action: :generate_invoice_detailed_pdf },
            { controller: :accounting, action: :export_invoice_to_xlsx },
            { controller: :accounting, action: :generate_invoice_detailed_csv },
            { controller: :accounting, action: :generate_invoice_by_cid_csv },
            { controller: :accounting, action: :generate_invoice_by_cid_pdf },
            { controller: :accounting, action: :invoice_details_list }
        ]
    end
  end

  def self.financial_statements(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
            {controller: :accounting, action: :financial_statements}
        ]
    end
  end

  def self.subscriptions(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
            {controller: :services, action: :user_subscriptions}
        ]
    end
  end

  def self.calls(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
            {controller: :stats, action: :last_calls_stats},
            {controller: :stats, action: :new_calls_list},
            {controller: :stats, action: :new_calls},
            {controller: :stats, action: :call_list_to_csv},
            {controller: :stats, action: :last_calls}
        ]
    end
  end

  def self.active_calls(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
            {controller: :stats, action: :active_calls},
            {controller: :stats, action: :active_calls_count},
            {controller: :stats, action: :active_calls_show},
            {controller: :functions, action: :spy_channel}
        ]
    end
  end

  def self.graphs(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
            {controller: :stats, action: :user_stats}
        ]
    end
  end

  def self.recordings(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
            {controller: :recordings, action: :list_recordings},
            {controller: :recordings, action: :update_recording},
            {controller: :recordings, action: :edit_recording},
            {controller: :recordings, action: :destroy},
            {controller: :recordings, action: :play_recording},
            {controller: :recordings, action: :get_recording}
        ]
    end
  end

  def self.dids(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
            {controller: :dids, action: :did_edit},
            {controller: :dids, action: :did_update},
            {controller: :dids, action: :personal_dids}
        ]
    end
  end

  def self.clis(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
            {controller: :devices, action: :user_device_clis},
            {controller: :devices, action: :cli_user_delete},
            {controller: :devices, action: :cli_user_edit},
            {controller: :devices, action: :cli_user_update},
            {controller: :devices, action: :cli_user_add}
        ]
    end
  end

  def self.phonebook(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
            {controller: :phonebooks, action: :list},
            {controller: :phonebooks, action: :index},
            {controller: :phonebooks, action: :destroy},
            {controller: :phonebooks, action: :edit},
            {controller: :phonebooks, action: :update},
            {controller: :phonebooks, action: :new},
            {controller: :phonebooks, action: :create},
            {controller: :phonebooks, action: :show},
            {controller: :phonebooks, action: :add_new}
        ]
    end
  end

  def self.quick_forwards(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
            {controller: :dids, action: :quickforwarddids},
            {controller: :dids, action: :quickforwarddid_edit},
            {controller: :dids, action: :quickforwarddid_update},
            {controller: :dids, action: :quickforwarddid_destroy}
        ]
    end
  end

  def self.faxes(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
            {controller: :stats, action: :faxes_list}
        ]
    end
  end

  def self.callback(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
            {controller: :functions, action: :callback},
            {controller: :functions, action: :activate_callback}
        ]
    end
  end

  def self.auto_dialer(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
            {controller: :autodialer, action: :user_campaigns},
            {controller: :autodialer, action: :campaign_numbers},
            {controller: :autodialer, action: :import_numbers_from_file},
            {controller: :autodialer, action: :delete_all_numbers},
            {controller: :autodialer, action: :campaign_change_status},
            {controller: :autodialer, action: :campaign_actions},
            {controller: :autodialer, action: :campaign_edit},
            {controller: :autodialer, action: :campaign_update},
            {controller: :autodialer, action: :action_add},
            {controller: :autodialer, action: :play_rec},
            {controller: :autodialer, action: :action_destroy},
            {controller: :autodialer, action: :action_edit},
            {controller: :autodialer, action: :action_update},
            {controller: :autodialer, action: :campaign_new},
            {controller: :autodialer, action: :redial_all_failed_calls},
            {controller: :autodialer, action: :campaign_statistics},
            {controller: :autodialer, action: :campaign_destroy},
            {controller: :autodialer, action: :bad_numbers_from_csv},
            {controller: :autodialer, action: :number_destroy},
            {controller: :autodialer, action: :export_call_data_to_csv},
            {controller: :autodialer, action: :reactivate_number},
            {controller: :autodialer, action: :campaign_create}
        ]
    end
  end

  def self.search(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
            {controller: :stats, action: :search},
            {controller: :stats, action: :prefix_finder_find},
            {controller: :stats, action: :rate_finder_find},
            {controller: :stats, action: :prefix_finder_find_country}
        ]
    end
  end
end
