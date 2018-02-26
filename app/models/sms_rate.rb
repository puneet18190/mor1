# -*- encoding : utf-8 -*-
# SMS rates
class SmsRate < ActiveRecord::Base
  attr_protected

  belongs_to :sms_tariff
  has_many :sms_ratedetails, -> { order(start_time: :asc) }

  def destination
    Destination.where(prefix: prefix).first
  end
end
