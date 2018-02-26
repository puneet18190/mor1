# -*- encoding : utf-8 -*-
# Advanced Rates model (Retail)
class Aratedetail < ActiveRecord::Base
  attr_protected

  belongs_to :rate

  def action_on_change(user)
    return if previous_changes.empty?
    Action.ratedetail_change(user, self)
  end
end
