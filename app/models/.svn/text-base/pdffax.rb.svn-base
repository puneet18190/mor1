# -*- encoding : utf-8 -*-
# pdffaxes table
class Pdffax < ActiveRecord::Base
  attr_protected

  def self.total_faxes(options, conditions)
    select("SUM(pdffaxes.status = 'no_tif') AS no_tif,
    SUM(pdffaxes.status = 'good') AS good,
    SUM(pdffaxes.status = 'pdf_size_0') AS pdf_size,
    SUM(pdffaxes.size) AS total_size")
      .joins('JOIN devices ON (pdffaxes.device_id = devices.id)')
      .joins('JOIN users ON (devices.user_id = users.id)')
      .where("users.hidden = 0 AND users.usertype = 'user'
    AND (receive_time BETWEEN '#{options[:session_from_datetime]}'
    AND '#{options[:session_till_datetime]}' OR pdffaxes.receive_time is NULL)")
      .where(conditions).first
  end
end
