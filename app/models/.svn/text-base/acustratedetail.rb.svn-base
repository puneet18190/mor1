# -*- encoding : utf-8 -*-
# Custom Rates model (Retail)
class Acustratedetail < ActiveRecord::Base
  attr_protected

  belongs_to :customrate

  def action_on_change(user)
    return if previous_changes.empty?
    Action.acustratedetail_change(user, self)
  end
end
