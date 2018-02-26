# -*- encoding : utf-8 -*-
# A Terminator is a group of Providers
class Terminator < ActiveRecord::Base
  attr_protected :user_id

  has_many :providers
  belongs_to :user

  after_destroy :dissociate_providers

  def assignable_providers(user)
    user_id = user.id

    assigned_where, unassigned_where =
        if user.usertype == 'reseller'
          [
              ['terminator_id = ? AND (user_id = ? OR (common_use = 1 AND id IN (SELECT provider_id FROM common_use_providers WHERE reseller_id = ?)))', id, user_id, user_id],
              ['terminator_id = 0 AND user_id = ?', user_id]
          ]
        else
          [
              ['terminator_id = ? AND (user_id = ? OR common_use = 1)', id, user_id],
              ['terminator_id = 0 AND (user_id = ? OR common_use = 1)', user_id]
          ]
        end

    [Provider.where(assigned_where).order(:name), Provider.where(unassigned_where).order(:name)]
  end

  private

  def dissociate_providers
    Provider.where(terminator_id: id).update_all(terminator_id: 0)
  end
end
