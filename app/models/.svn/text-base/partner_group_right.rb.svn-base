# -*- encoding : utf-8 -*-
# Partner Group Rights mapping
class PartnerGroupRight < ActiveRecord::Base
  attr_protected
  belongs_to :partner_right
  belongs_to :partner_group

  def self.partner_permissions(partner)
    permissions_access_level = self.where(partner_group_id: partner.partner_group_id).all
    partner_permissions = PartnerRight.get_permissions(permissions_access_level)
    return partner_permissions
  end

  # Used to distinguish whether permissions exist at all, so that particular alert messages would be shown.
  def self.partner_all_permissions
    permissions_access_level = self.where(partner_group_id: 0).all
    PartnerRight.get_permissions(permissions_access_level)
  end
end
