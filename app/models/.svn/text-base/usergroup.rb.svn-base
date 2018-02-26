# -*- encoding : utf-8 -*-
# Call Shop User groups
class Usergroup < ActiveRecord::Base
  attr_protected

  attr_accessible :id, :user_id, :group_id, :gusertype, :position

  belongs_to :group
  belongs_to :user

  before_create :check_manager_size_in_group

  def check_manager_size_in_group
    if gusertype == 'manager' && Usergroup.where(group_id: group_id, gusertype: 'manager').present?
      errors.add(:gusertype, _('Call_Shop_can_have_only_one_manager')) && (return false)
    end
  end
end
