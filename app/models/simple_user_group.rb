# -*- encoding : utf-8 -*-
# Simple User Groups
class SimpleUserGroup < ActiveRecord::Base
  attr_protected

  has_many :users
  has_many :simple_user_group_rights, dependent: :destroy
  has_many :simple_user_rights, through: :simple_user_group_rights

  before_validation :remove_whitespaces

  validates :name,
            uniqueness: {message: _('User_Group_name_must_be_unique'), scope: :owner_id},
            presence: {message: _('User_Group_name_cannot_be_blank')}

  after_create :create_permissions

  before_destroy :no_simple_users_assigned

  def create_permissions
    SimpleUserRight.all.each do |permission|
      self.simple_user_group_rights.create({simple_user_right_id: permission.id, value: 0})
    end
  end

  def update_rights(rights)
    rights.map do |name, value|
      simple_user_right_id = SimpleUserRight.where(name: name).first.id
      sugr = SimpleUserGroupRight.where({simple_user_group_id: id, simple_user_right_id: simple_user_right_id}).first
      if sugr.present?
        sugr.value = value
        sugr.save
      else
        SimpleUserGroupRight.create({simple_user_group_id: id, simple_user_right_id: simple_user_right_id, value: value})
      end
    end
  end

  private

  def remove_whitespaces
    [:name, :comment].each { |value| self[value].to_s.strip! }
  end

  def no_simple_users_assigned
    unless users.count.zero?
      errors.add(:simple_users_assigned, _('it_has_assigned_Users')) && (return false)
    end
  end
end
