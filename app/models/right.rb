# -*- encoding : utf-8 -*-
# User rights
class Right < ActiveRecord::Base
  has_many :role_rights, dependent: :delete_all
  validates_uniqueness_of :controller, scope: :action

  attr_protected

  def self.update_right_permissions(rights)
    RoleRight.transaction do

      rights.each do |right|
        MorLog.my_debug("OH SNAP #{right.role_rights.size}") if right.role_rights.size != 5
        right.role_rights.each do |rr|

          MorLog.my_debug(rr.to_yaml) if right.id == 75
          MorLog.my_debug(params["Setting_#{rr.role_id}_#{right.id}".to_sym].to_i) if right.id == 75
          if rr.permission != params["Setting_#{rr.role_id}_#{right.id}".to_sym].to_i
            rr.permission = params["Setting_#{rr.role_id}_#{right.id}".to_sym].to_i
            rr.save
            MorLog.my_debug("SAVE Setting_#{rr.role_id}_#{right.id} - #{params["Setting_#{rr.role_id}_#{right.id}".to_sym].to_i}")
          end

        end
        if right.saved == 1
          right.saved = 0
          right.save
        end
      end
    end
  end

  def self.update_role_rights(role)
    Right.all.each do |right|
      role_right = right
      role_right.permission = (role.name.downcase == 'admin' ? 1 : 0)
      role_right.save
    end
  end
end
