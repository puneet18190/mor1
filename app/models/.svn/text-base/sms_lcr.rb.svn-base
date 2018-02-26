# -*- encoding : utf-8 -*-
class SmsLcr < ActiveRecord::Base

  attr_protected


  def sms_providers(order = nil)
    if order
      if order.to_s.downcase == 'asc'
        sql = "SELECT sms_providers.* FROM sms_providers, sms_lcrproviders WHERE sms_providers.id = sms_lcrproviders.sms_provider_id AND sms_lcrproviders.sms_lcr_id = #{self.id} ORDER BY sms_lcrproviders.priority ASC;"
      elsif order.to_s.downcase == 'desc'
        sql = "SELECT sms_providers.* FROM sms_providers, sms_lcrproviders WHERE sms_providers.id = sms_lcrproviders.sms_provider_id AND sms_lcrproviders.sms_lcr_id = #{self.id} ORDER BY sms_lcrproviders.priority DESC"
      end
    else
      sql = "SELECT sms_providers.* FROM sms_providers, sms_lcrproviders WHERE sms_providers.id = sms_lcrproviders.sms_provider_id AND sms_lcrproviders.sms_lcr_id = #{self.id} ORDER BY sms_providers.name ASC;"
    end

    return SmsProvider.find_by_sql(sql)
  end

  def add_sms_provider(prov)
    priority = 1
    if order.to_s == 'priority'
      last_priority = SmsLcrprovider.where(sms_lcr_id: id).maximum(:priority)
      priority = last_priority ? last_priority + 1 : 0
    end
    sql = 'INSERT INTO sms_lcrproviders (sms_lcr_id, sms_provider_id, priority) VALUES (\'' + id.to_s + '\', \'' + prov.id.to_s + '\', \'' + priority.to_s + '\')'
    ActiveRecord::Base.connection.insert(sql)
  end

  def remove_sms_provider(prov_id)
    sql = "DELETE FROM sms_lcrproviders WHERE sms_lcr_id = '" + id.to_s + "' AND sms_provider_id = '" + prov_id.to_s + "'"
    ActiveRecord::Base.connection.insert(sql)
    # This fill order all sms providers priorities after removing
    if order.to_s == 'priority'
      all_providers = SmsLcrprovider.where(sms_lcr_id: id).order(:priority)
      all_providers.each_with_index do |provider, index|
        provider.priority = index
        provider.save
      end
    end
  end

  def sms_provider_active(provider_id)
    sql = "SELECT active FROM sms_lcrproviders WHERE sms_lcr_id = '#{id}' AND sms_provider_id = '#{provider_id}' "
    res = ActiveRecord::Base.connection.select_value(sql)
    res.to_s == '1'
  end
end
