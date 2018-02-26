# -*- encoding : utf-8 -*-
# For ActiveRecord relation
class VoicemailBox < ActiveRecord::Base

  attr_protected

  primary_key = 'uniqueid'
  belongs_to :device

  validates_uniqueness_of :device_id

  class << self # Class methods
    alias :all_columns :columns

    def columns
      all_columns
    end
  end

  def self.delete
    self[:delete]
  end

  def self.delete=(param)
    self[:delete] = param
  end
end
