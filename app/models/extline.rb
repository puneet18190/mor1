# -*- encoding : utf-8 -*-
class Extline < ActiveRecord::Base
  attr_accessible :id ,:context ,:exten ,:priority ,:app ,:appdata ,:device_id

  attr_protected

  #creating extension by parameters
  def self.mcreate(context, priority, app, appdata, extension, device_id)

    sep = ','
    if appdata == "$[$[\"${DIALSTATUS}\" = \"CHANUNAVAIL\"]|$[\"${DIALSTATUS}\" = \"CONGESTION\"]]?301"
      # do not touch this line, here | means OR operator
      rappdata = appdata
    else
      rappdata = appdata.to_s.gsub('|', ',')
    end

    extension_to_database = extension.present? ? extension.to_s : 'empty_extension'

    ext = self.new(:context => context, :exten => extension_to_database, :priority => priority, :app => app, :appdata => rappdata, :device_id => device_id)
    ext.save
    ext
  end

  def self.update_timeout(timeout_response, timeout_digit)
    if (1..60).include?(timeout_response.to_i) and (1..60).include?(timeout_digit.to_i)
      cond = "exten = ? AND context = ? AND priority IN (2, 3) AND appdata like ?"
      Extline.where([cond, '_X.', "mor", 'TIMEOUT(response)%']).
          update_all({:appdata => "TIMEOUT(response)=#{timeout_response.to_i}"})
      Extline.where([cond, '_X.', "mor", 'TIMEOUT(digit)%']).
          update_all({:appdata => "TIMEOUT(digit)=#{timeout_digit.to_i}"})
    else
      return false
    end
  end
end
