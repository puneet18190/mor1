# -*- encoding : utf-8 -*-
class DailyCurrency < ActiveRecord::Base
  attr_protected

  def currencies_update(date = Time.now.strftime('%F'))
    self.added = date
    # Drop first two columns (id, added), so that only currency names would be left
    currencies_to_update = self.attribute_names.drop(2)

    currencies_to_update.each do |currency_to_update|
      # Get currency exchange rate from today's Currency db
      currency_rate = Currency.where(name: currency_to_update).first.try(:exchange_rate)
      # Assign that exchange rate
      self.assign_attributes(Hash[currency_to_update, currency_rate.to_d])
    end
  end
end
