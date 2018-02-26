# -*- encoding : utf-8 -*-
class Cclineitem < ActiveRecord::Base
  attr_protected

  belongs_to :cardgroup
  belongs_to :ccorder, dependent: :destroy
  belongs_to :card

  def self.for_cardgroup(cardgroup)
    self.new(quantity: 1, cardgroup: cardgroup, price: cardgroup.price)
  end
end
