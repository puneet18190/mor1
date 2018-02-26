# -*- encoding : utf-8 -*-
# Used for Dynamic Blacklist Functionality scoring
class IpNewScore < ActiveRecord::Base
  validates_numericality_of :score, only_integer: true

  def self.table_name
    'bl_ip_new_score'
  end

  attr_protected

  def self.default_score
    where(value: 'default').first.try(:score)
  end
end
