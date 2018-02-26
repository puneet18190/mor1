# -*- encoding : utf-8 -*-
class Devicegroup < ActiveRecord::Base
  belongs_to :user
  belongs_to :address
  has_many :devices
  attr_accessible :id, :user_id, :address_id, :name, :added, :primary

  def init_primary(user_id, name, user_address_id)
    self.user_id = user_id
    self.name = name
    self.added = Time.now
    self.primary = 1
    self.address_id = user_address_id
    self.save
  end

  def destroy_everything
    if self.address
      self.address.destroy
    end
    self.destroy
  end
end
