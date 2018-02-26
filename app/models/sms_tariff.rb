# -*- encoding : utf-8 -*-
# SMS tariffs
class SmsTariff < ActiveRecord::Base

  attr_accessible :id, :name, :tariff_type, :owner_id, :currency

  has_many :sms_rates, dependent: :destroy
  has_many :sms_providers
  has_many :users
  before_destroy :s_before_destroy

  validates_uniqueness_of :name, message: _('Name_must_be_unique'), scope: [:owner_id]
  validates_presence_of :name, message: _('Name_cannot_be_blank')

  def s_before_destroy
    if sms_providers.try(:size) > 0
      errors.add(:sms_providers, _('SMS_Tariff_assigned_to_provider'))
      return false
    end
    if users.try(:size) > 0
      errors.add(:sms_providers, _('SMS_Tariff_assigned_to_user'))
      return false
    end

    true
  end

  def rates_by_st(st, sql_start, per_page, options={})
    ex_r = options[:exchange_rate] ? options[:exchange_rate] : 1
    SmsRate.find_by_sql ["SELECT sms_rates.*, (sms_rates.price * #{ex_r}) AS 'curr_price' FROM destinations, sms_rates, directions WHERE sms_rates.sms_tariff_id = ? AND destinations.prefix = sms_rates.prefix AND directions.code = destinations.direction_code AND directions.name like ? GROUP BY sms_rates.id ORDER BY directions.name ASC, destinations.prefix ASC LIMIT " + sql_start.to_s + "," + per_page.to_s, self.id, st.to_s+'%']
  end

  def free_destinations_by_st(st, limit = nil, offset = 0)
    st = st.to_s
    destination_ids = self.destinations.where("directions.name like #{ActiveRecord::Base::sanitize(st + '%')}").collect(&:id)

    query = Destination.select('destinations.*, directions.name AS direction_name, directions.code AS direction_code').
                         joins('JOIN directions ON(directions.code = destinations.direction_code)').
                         where("directions.name like #{ActiveRecord::Base::sanitize(st + '%')}")

    query = query.where("destinations.id NOT IN (#{destination_ids.join(',')})") unless destination_ids.blank?

    adests = query.order('directions.name ASC, destinations.prefix ASC').
                   limit(limit || 1000000).
                   offset(offset).all

    actual_adest_count = query.to_a.size
    limit ? [adests, actual_adest_count] : adests
  end

  def destinations
    Destination.select('destinations.*').from('destinations, sms_tariffs, sms_rates, directions').where(['sms_rates.sms_tariff_id = ? AND directions.code = destinations.direction_code AND destinations.prefix = sms_rates.prefix', self.id]).group('destinations.id').order('destinations.prefix ASC')
  end

  def add_new_rate(prefix, rate_value)
    SmsRate.create(sms_tariff_id: id, prefix: prefix, price: rate_value)
  end

  def delete_all_rates
    SmsRate.where(sms_tariff_id: id).delete_all
  end
end
