# -*- encoding : utf-8 -*-
# Ringgroup devices
class RinggroupsDevice < ActiveRecord::Base

  attr_protected

  belongs_to :ringroup
  belongs_to :device
end
