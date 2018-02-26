# -*- encoding : utf-8 -*-
# Ringgroup - Collection of Asterisk extensions
class Ringgroup < ActiveRecord::Base
  attr_protected

  belongs_to :user
  has_many :ringgroups_devices, dependent: :delete_all
  has_one :dialplan, -> { where(dptype: 'ringgroup') }, foreign_key: 'data1'
  belongs_to :did

  before_save :set_user_id
  before_destroy :destroy_dialplans

  validates_presence_of :name, message: _('Name_cannot_be_blank'), on: :save

  def set_user_id
    self.user_id = User.current.id
  end

  def destroy_dialplans
    if dialplan
      delete_extline
      dialplan.delete
    end
  end

  def delete_extline
    exten = dialplan.data2
    context = dialplan.data6.to_i != 1 ? "pool_#{dialplan.data6}_mor_local" : 'mor_local'
    Extline.delete_all(['exten = ? AND app = ? AND context = ?', exten, 'Dial', context])
  end

  def devices
    Device.joins("Left join ringgroups_devices on (ringgroups_devices.device_id = devices.id)").where(["ringgroup_id=? AND name not like 'mor_server_%'", id]).order('priority ASC').all
  end

  def free_devices(dev_id = -1)
    if dev_id.to_i > 0
      Device.select('devices.*').where(['id NOT IN (SELECT device_id FROM ringgroups_devices WHERE ringgroup_id = ?) AND user_id = ? AND name not like "mor_server_%"', id, dev_id]).all
    else
      Device.select('devices.*').where(['id NOT IN (SELECT device_id FROM ringgroups_devices WHERE ringgroup_id = ?) AND name not like "mor_server_%"', id]).all
    end
  end

  def update_exline(ext = -1, own_ext = '', own_id = '')
    devices = self.devices
    appdata = ''

    if devices
      devices.each_with_index { |device, index|
        pool_id = device.user.try(:pbx_pool_id)
        mor_local_app = pool_id <= 1 ? 'mor_local' : "pool_#{pool_id}_mor_local"
        # all devices will be dialed over Local, not only Virtual for CCL compatibility
        # if d.device_type.to_s == 'Virtual'
        mor_local =
          if index > 0
            appdata += "&Local/#{device.extension}@#{mor_local_app}/n"
          else
            appdata += "Local/#{device.extension}@#{mor_local_app}/n"
          end
        # else
          # if i > 0
          #  appdata += "&#{d.device_type}/#{d.name}"
          # else
          #  appdata += "#{d.device_type}/#{d.name}"
          # end
        # end
      }
    end
    appdata += "|#{self[:timeout]}|#{self.options}"
    context = dialplan.data6.to_i != 1 ? "pool_#{dialplan.data6}_mor_local" : 'mor_local'
    pool_id = own_id.present? ? own_id : pbx_pools_id
    exten = own_ext.present? ? own_ext : self.dialplan.data2
    old_context = pool_id.to_i != 1 ? "pool_#{pool_id}_mor_local" : 'mor_local'
    ### CHANGE EXTLINES IF POOL OR EXT CHANGED WHILE EDITING
    if own_ext.present? || ext == -1
      Extline.delete_all(['exten = ? AND app = ? AND context = ?', exten, 'Dial', old_context])
      Extline.delete_all(['exten = ? AND app = ? AND context = ?', exten, 'Goto', old_context])
      Extline.delete_all(['exten = ? AND app = ? AND context = ?', exten, 'Set', old_context])
    end

    i = 1
    if !cid_prefix.blank?
      Extline.mcreate(context, i, 'Set', "CALLERID(NAME)=#{cid_prefix}${CALLERID(NAME)}", self.dialplan.data2, '0')
      i += 1
    end
    Extline.mcreate(context, i, 'Dial', appdata, self.dialplan.data2, '0')
    i += 1
    Extline.mcreate(context, i, 'Goto', "mor|#{self.did.did}|1", self.dialplan.data2, '0') if self.did_id != 0
  end

  def Ringgroup.ringgroups_order_by(options)
    order_by = case options[:order_by].to_s.strip
                 when 'extension'
                   ' dialplans.data2 '
                 when 'pbx_pool'
                   ' ringgroups.pbx_pools_id '
                 when 'name'
                   ' dialplans.name '
                 when 'comment'
                   ' ringgroups.comment '
                 when 'ring_time'
                   ' ringgroups.timeout '
                 when 'options'
                   ' ringgroups.options '
                 when 'strategy'
                   ' ringgroups.strategy '
                 when 'prefix'
                   ' ringgroups.cid_prefix '
                 else
                   options[:order_desc] = 1
                   ' dialplans.name '
               end

    order_by << (options[:order_desc].to_i == 0 ? 'ASC' : 'DESC') if order_by.present?

    order_by
  end

  def self.is_extension_valid?(pool_id, ext, own_ext = '', own_id = '')
    return true if (ext == own_ext && pool_id.to_i == own_id.to_i) and ext.present?
    context = pool_id.to_i == 1 ? 'mor_local' : "pool_#{pool_id}_mor_local"
    used_extensions = Extline.where(context: context).all.to_a.map(&:exten)
    return false if used_extensions.include?(ext)
    return true
  end

  def device_sort_variables(user)
    self.update_exline
    devices = self.devices
    users = User.all
    dids = user.dids_for_select('free')
    free_dids = Did.free_dids_for_select(self.did_id)
    dialplan = self.dialplan
    extlines = Extline.where(['exten = ? AND app IN ("Set", "Dial", "Goto")', dialplan.data2]).order('priority ASC')
    return devices, users, dids, free_dids, dialplan, extlines
  end
end
