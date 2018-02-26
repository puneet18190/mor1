# -*- encoding : utf-8 -*-
# Partner Rights
class PartnerRight < ActiveRecord::Base
  attr_protected

  has_many :partner_group_rights
  has_many :partner_groups, through: :partner_group_rights

  def self.get_permissions(permissions_access_level)
    permissions = default_permissions
    right_method_map = permissions_id_method_map

    permissions_access_level.each do |permission_access_level|
      right_method_map.select do |right_method|
        if right_method[:partner_right_id] == permission_access_level.partner_right_id
          permissions << send(right_method[:method], permission_access_level.value) if respond_to? right_method[:method]
        end
      end
    end

    permissions.flatten
  end

  private

  def self.permissions_id_method_map
    []
  end

  def self.id_by_name(name)
    where(name: name.to_s).first.try(:id) || 0
  end

  def self.default_permissions
    [
        {controller: :accounting, action: :user_invoices},
        {controller: :accounting, action: :invoices},
        {controller: :accounting, action: :generate_invoices},
        {controller: :accounting, action: :generate_invoice_csv},
        {controller: :accounting, action: :generate_invoice_pdf},
        {controller: :accounting, action: :generate_invoice_detailed_pdf},
        {controller: :accounting, action: :invoice_delete},
        {controller: :accounting, action: :delete_all},
        {controller: :accounting, action: :user_invoice_details},
        {controller: :accounting, action: :invoice_details},
        {controller: :accounting, action: :invoice_recalculate},
        {controller: :accounting, action: :pay_invoice},
        {controller: :accounting, action: :sent_invoice},
        {controller: :accounting, action: :send_invoices},
        {controller: :accounting, action: :update_invoice_details},
        {controller: :accounting, action: :export_invoice_to_xlsx},
        {controller: :accounting, action: :generate_invoice_detailed_csv},
        {controller: :accounting, action: :generate_invoices_status},
        {controller: :accounting, action: :invoice_details_list},
        {controller: :accounting, action: :invoices_recalculation},
        {controller: :accounting, action: :invoices_recalculation_status},
        {controller: :callc, action: :change_currency},
        {controller: :callc, action: :login},
        {controller: :callc, action: :logout},
        {controller: :callc, action: :main},
        {controller: :destination_groups, action: :destinations},
        {controller: :destination_groups, action: :dg_list_user_destinations},
        {controller: :destination_groups, action: :retrieve_destinations_remote},
        {controller: :devices, action: :ajax_get_user_devices},
        {controller: :devices, action: :cli_user_devices},
        {controller: :functions, action: :login_as_execute},
        {controller: :functions, action: :partner_settings},
        {controller: :functions, action: :partner_settings_change},
        {controller: :functions, action: :tax_change},
        {controller: :functions, action: :check_separator},
        {controller: :payments, action: :list},
        {controller: :payments, action: :manual_payment},
        {controller: :payments, action: :manual_payment_status},
        {controller: :payments, action: :manual_payment_finish},
        {controller: :payments, action: :payments_csv},
        {controller: :payments, action: :delete_payment},
        {controller: :payments, action: :change_description},
        {controller: :payments, action: :personal_payments},
        {controller: :stats, action: :calls_per_day},
        {controller: :stats, action: :last_calls_stats},
        {controller: :stats, action: :old_calls_stats},
        {controller: :stats, action: :last_calls},
        {controller: :stats, action: :action_log},
        {controller: :stats, action: :action_processed},
        {controller: :stats, action: :action_log_mark_reviewed},
        {controller: :stats, action: :profit},
        {controller: :stats, action: :generate_profit_pdf},
        {controller: :services, action: :subscriptions_list},
        {controller: :services, action: :subscription_new},
        {controller: :services, action: :subscriptions},
        {controller: :services, action: :subscription_create},
        {controller: :services, action: :subscription_edit},
        {controller: :services, action: :subscription_confirm_destroy},
        {controller: :services, action: :subscription_destroy},
        {controller: :services, action: :subscription_update},
        {controller: :services, action: :list},
        {controller: :services, action: :new},
        {controller: :services, action: :create},
        {controller: :services, action: :edit},
        {controller: :services, action: :destroy},
        {controller: :tariffs, action: :list},
        {controller: :tariffs, action: :directions_list},
        {controller: :tariffs, action: :change_tariff_for_users},
        {controller: :tariffs, action: :update_tariff_for_users},
        {controller: :tariffs, action: :rate_try_to_add},
        {controller: :tariffs, action: :ghost_percent_edit},
        {controller: :tariffs, action: :rate_details},
        {controller: :tariffs, action: :rate_destroy},
        {controller: :tariffs, action: :ratedetail_edit},
        {controller: :tariffs, action: :ratedetail_update},
        {controller: :tariffs, action: :ratedetail_destroy},
        {controller: :tariffs, action: :ratedetails_manage},
        {controller: :tariffs, action: :make_user_tariff},
        {controller: :tariffs, action: :make_user_tariff_status},
        {controller: :tariffs, action: :make_user_tariff_wholesale},
        {controller: :tariffs, action: :make_user_tariff_status_wholesale},
        {controller: :tariffs, action: :new},
        {controller: :tariffs, action: :create},
        {controller: :tariffs, action: :edit},
        {controller: :tariffs, action: :update},
        {controller: :tariffs, action: :check_prefix_availability},
        {controller: :tariffs, action: :destroy},
        {controller: :tariffs, action: :tariffs_list},
        {controller: :tariffs, action: :import_csv},
        {controller: :tariffs, action: :rates_list},
        {controller: :tariffs, action: :user_rates},
        {controller: :tariffs, action: :user_rates_list},
        {controller: :tariffs, action: :delete_all_rates},
        {controller: :tariffs, action: :rate_new},
        {controller: :tariffs, action: :rate_new_quick},
        {controller: :tariffs, action: :rate_new_by_direction},
        {controller: :tariffs, action: :user_arates_full},
        {controller: :tariffs, action: :user_ard_time_edit},
        {controller: :tariffs, action: :user_arates},
        {controller: :tariffs, action: :user_rate_update},
        {controller: :tariffs, action: :user_rates_update},
        {controller: :tariffs, action: :artg_destroy},
        {controller: :tariffs, action: :ard_manage},
        {controller: :tariffs, action: :user_rate_destroy},
        {controller: :tariffs, action: :import_csv2},
        {controller: :tariffs, action: :rate_new_by_direction_add},
        {controller: :tariffs, action: :bad_rows_from_csv},
        {controller: :tariffs, action: :zero_rates_from_csv},
        {controller: :tariffs, action: :generate_user_rates_csv},
        {controller: :tariffs, action: :generate_providers_rates_csv},
        {controller: :tariffs, action: :generate_personal_rates_csv},
        {controller: :tariffs, action: :generate_personal_rates_pdf},
        {controller: :tariffs, action: :generate_personal_wholesale_rates_pdf},
        {controller: :tariffs, action: :generate_personal_wholesale_rates_csv},
        {controller: :tariffs, action: :user_rates_detailed},
        {controller: :tariffs, action: :update_rates},
        {controller: :tariffs, action: :update_rates_by_destination_mask},
        {controller: :users, action: :get_users_map},
        {controller: :users, action: :personal_details},
        {controller: :users, action: :update_personal_details},
        {controller: :users, action: :list},
        {controller: :users, action: :hide},
        {controller: :users, action: :hidden},
        {controller: :users, action: :create},
        {controller: :users, action: :new},
        {controller: :users, action: :edit},
        {controller: :users, action: :update},
        {controller: :users, action: :destroy},
        {controller: :users, action: :custom_rates},
        {controller: :users, action: :user_custom_rate_add_new},
        {controller: :users, action: :user_delete_custom_rate},
        {controller: :users, action: :user_acustrates_full},
        {controller: :users, action: :user_acustrates},
        {controller: :users, action: :user_custom_rate_update},
        {controller: :users, action: :user_ard_time_edit},
        {controller: :users, action: :ard_manage},
        {controller: :users, action: :artg_destroy},
        {controller: :users, action: :get_partner_resellers_map}
    ]
  end
end
