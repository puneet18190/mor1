# -*- encoding : utf-8 -*-
# Number Model for Number Pools
class Number < ActiveRecord::Base
  attr_accessible :number, :number_pool_id
  belongs_to :number_pool
  validates_numericality_of :number, message: _('number_must_be_number')

  def self.numbers_order_by(options)
    order_by = options[:order_by].to_s.strip
    return 'id' unless %w(id number).include?(order_by)
    order_by << (options[:order_desc].to_i == 0 ? ' ASC' : ' DESC')
  end

  def self.retrieve(wcard, order)
    (wcard.present? ? where('number LIKE ?', wcard) : all).order(order)
  end
end
