# -*- encoding : utf-8 -*-
# User roles
class Role < ActiveRecord::Base
  attr_accessible :name
  has_many :role_rights, dependent: :delete_all
end
