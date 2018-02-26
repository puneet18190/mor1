# -*- encoding : utf-8 -*-
class Aggregate < ActiveRecord::Base
  attr_protected

  extend UniversalHelpers
  belongs_to :user
  belongs_to :reseller, class_name: 'User', foreign_key: 'reseller_id'
  belongs_to :time_period
  has_one :destinationgroup

  def self.calls_per_hour_data_totals(cph_day)
    {
        user_call_attempts: cph_day.sum(&:user_call_attempts),
        answered_calls: cph_day.sum(&:answered_calls),
        user_acd: cph_day.inject(0) { |sum, call| sum + call.try(:user_acd).to_i },
        admin_call_attempts: cph_day.sum(&:admin_call_attempts),
        admin_acd: cph_day.inject(0) { |sum, call| sum + call.try(:admin_acd).to_i },
        duration: cph_day.inject(0) { |sum, call| sum + call.try(:duration).to_i }
    }
  end
end
