# -*- encoding : utf-8 -*-
# Simple User Group Rights mapping
class SimpleUserGroupRight < ActiveRecord::Base
  attr_protected
  belongs_to :simple_user_right
  belongs_to :simple_user_group

  def self.simple_user_permissions(user)
    user_group_id = user.simple_user_group_id

    if user_group_id == 0
      SimpleUserRight.get_full_access
    else
      permissions_access_level = self.where(simple_user_group_id: user.simple_user_group_id).all
      SimpleUserRight.get_permissions(permissions_access_level)
    end
  end

  # Used to distinguish whether permissions exist at all, so that particular alert messages would be shown.
  def self.simple_user_all_permissions
    permissions_access_level = self.where(simple_user_group_id: 0).all
    SimpleUserRight.get_permissions(permissions_access_level)
  end
end
