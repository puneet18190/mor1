# -*- encoding : utf-8 -*-
class Day < ActiveRecord::Base
  attr_protected
  def self.daytype(date)
    find_by(date: date.strftime('%Y-%m-%d')).try(:daytype) == 'FD' ? 'WD' : 'FD'
  end
end
