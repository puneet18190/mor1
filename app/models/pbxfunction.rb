# -*- encoding : utf-8 -*-
class Pbxfunction < ActiveRecord::Base

  attr_protected

  has_many :dialplans, :class_name => 'Dialplan', :foreign_key => 'data1'
  belongs_to :user

  before_save :pbx_before_save

  def pbx_before_save
    self.user_id = User.current.id
  end

  def dialplans
    Dialplan.where("data1 = #{self.id}").order("#{self.name}").all
  end

  def Pbxfunction.pbx_functions_order_by(params, options)
    hash = params[:order_by] && params[:order_desc] ? params : options

    case hash[:order_by].to_s.strip
    when "extension"
      order_by = " dialplans.data2 "
    when "name"
      order_by = " dialplans.name "
    when "pbx_function_name"
      order_by = " dialplans.data1 "
    when "call_will_be_billed_to_user/device"
      order_by = " dialplans.data5 "
    when "details"
      order_by = " dialplans.data3 "
    when 'pbx_pool'
      order_by = " dialplans.data13"
    else
      order_by = "dialplans.name"
      hash[:order_desc] = 1
    end

    order_by << (hash[:order_desc].to_i == 0 ? ' ASC' : ' DESC')
    options[:order_desc], options[:order_by] = hash[:order_desc], hash[:order_by]

    order_by
  end

  def self.get_pbx_functions(reseller = false)
    where_clause = 'name != "ringgroupid"'
    where_clause += ' AND allow_resellers = 1' if reseller

    Pbxfunction.where(where_clause).order('pf_type ASC')
  end
end
