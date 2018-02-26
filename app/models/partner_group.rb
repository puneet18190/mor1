# -*- encoding : utf-8 -*-
# Partner Groups
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# There are no Partner Groups in GUI, everything is set to default Rights and Group
# This was made only for easier implementation of Partner Groups in future
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
class PartnerGroup < ActiveRecord::Base
  attr_protected

  has_many :partners
  has_many :partner_group_rights, dependent: :destroy
  has_many :partner_rights, through: :partner_group_rights

  before_validation :remove_whitespaces

  validates :name,
            uniqueness: {message: _('Partner_Group_name_must_be_unique')},
            presence: {message: _('Partner_Group_name_cannot_be_blank')}

  after_create :create_permissions

  before_destroy :no_partners_assigned


  def create_permissions
    PartnerRight.all.each do |permission|
      self.partner_group_rights.create({
                                           partner_right_id: permission.id,
                                           value: 0
                                       })
    end
  end

  def update_rights(rights)
    rights.map do |name, value|
      partner_right_id = PartnerRight.where(name: name).first.id
      mgr = PartnerGroupRight.where({
                                        partner_group_id: id,
                                        partner_right_id: partner_right_id
                                    }).first
      if mgr.present?
        mgr.value = value
        mgr.save
      else
        PartnerGroupRight.create({partner_group_id: id, partner_right_id: partner_right_id, value: value})
      end
    end
  end

  private

  def remove_whitespaces
    [:name, :comment].each { |value| self[value].to_s.strip! }
  end

  def no_partners_assigned
    unless partners.count.zero?
      errors.add(:partners_assigned, _('it_has_assigned_Partners')) && (return false)
    end
  end
end
