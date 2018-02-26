# -*- encoding : utf-8 -*-
# Translation identifier
class Translation < ActiveRecord::Base
  has_many :user_translations, dependent: :destroy

  attr_protected

  def self.default
    translation = order(:position).first

    translation ? translation.name : 'English'
  end
end
