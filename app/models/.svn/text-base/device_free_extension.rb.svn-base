# -*- encoding : utf-8 -*-
# Free extensions for Devices
class DeviceFreeExtension < ActiveRecord::Base
  attr_protected

  def self.take_extension(extension = nil)
    free_extension = order(:extension).first
    if free_extension.present?
      extension = free_extension.extension.to_s
      free_extension.delete
      return extension
    else
      return Device.new_free_extension
    end
  end

  def self.renew_extensions(extension)
    free_extension = where('CONVERT(extension, CHAR) = ?', extension).first
    if free_extension.present?
      extension = free_extension.extension.to_s
      free_extension.delete
    end
    extension
  end

  def self.insert_free_extensions
    DeviceFreeExtension.delete_all

    free_extensions = self.free_extensions[0..9999]
    if free_extensions.present?
      ActiveRecord::Base.connection.execute("
        INSERT IGNORE INTO device_free_extensions (`extension`) VALUES (#{free_extensions.join('),(')});
      ")
    end
  end

  def self.free_extensions
    range_min, range_max = Confline.get_device_range_values ||= [0, 1]

    devices_username = ActiveRecord::Base.connection.select_values("
      SELECT username AS taken_extension
      FROM devices
      WHERE (username REGEXP '^[0-9]+$' = 1 AND username BETWEEN #{range_min} AND #{range_max})
    ")

    devices_extension = ActiveRecord::Base.connection.select_values("
      SELECT extension AS taken_extension
      FROM devices
      WHERE (extension REGEXP '^[0-9]+$' = 1 AND extension BETWEEN #{range_min} AND #{range_max})
    ")

    extlines_exten = ActiveRecord::Base.connection.select_values("
      SELECT exten AS taken_extension
      FROM extlines
      WHERE (exten REGEXP '^[0-9]+$' = 1 AND exten BETWEEN #{range_min} AND #{range_max})
    ")

    taken_extensions_array = (devices_username + devices_extension + extlines_exten).map(&:to_i)

    free_extensions = []

    while range_min + 1000000 < range_max do
      free_extensions.concat((range_min..(range_min += 1000000)).to_a - taken_extensions_array)
      break if free_extensions.size >= 10000
    end

    if (free_extensions.size < 10000) && (range_min <= range_max)
      free_extensions.concat((range_min..range_max).to_a - taken_extensions_array)
    end

    free_extensions
  end
end
