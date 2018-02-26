# -*- encoding : utf-8 -*-
class PbxPool < ActiveRecord::Base

  attr_protected

  has_many :users
  before_destroy :validate_delete

  validates :name, presence: {
                       message: _('Name_cannot_be_blank')
                   },
                   uniqueness: {
                       case_sensitive: false,
                       message: _('Name_must_be_unique')
                   }
  after_commit :create_extlines, :reload_dialplan_in_asterisk
  after_destroy :delete_extlines, :reload_dialplan_in_asterisk


  def validate_delete
    pbx_pool_user = User.where(pbx_pool_id: self.id).first

    unless pbx_pool_user.blank?
      errors.add(:pbx_pool_user, _('pbx_pool_is_in_use'))
    end

    return errors.size > 0 ? false : true
  end

  def PbxPool.pbx_pools_order_by(params, options)
    case options[:order_by].to_s.strip
    when "id"
      order_by = " pbx_pools.id "
    when "name"
      order_by = " pbx_pools.name "
    # atkomentuoti, kai bus sukurtas numbers pridėjimas
    #when "numbers"
    #  order_by = " num "
    when "comment"
      order_by = " pbx_pools.comment "
    else
      options[:order_by] ? order_by = "pbx_pools.id" : order_by = "pbx_pools.id"
      options[:order_desc] = 1
    end
    order_by << " ASC" if options[:order_desc].to_i == 0 and order_by != ""
    order_by << " DESC" if options[:order_desc].to_i == 1 and order_by != ""

    return order_by
  end

  def self.for_dropdown
    self.where("owner_id = #{User.current.get_correct_owner_id} OR id = 1").all.to_a.sort_by!{|pool| pool.name.downcase}.map{|pool| [pool.name, pool.id]}
  end

  def create_extlines
    context = make_context_name

    vm_server = Confline.get_value('VM_Server_Active').to_i
    local_ext = Confline.get_value('VM_Retrieve_Extension')
    server_ext = Confline.get_value('VM_Server_Retrieve_Extension')

    ext = vm_server == 1 ? server_ext : local_ext

    Extline.import(
      [:context, :exten, :priority, :app, :appdata, :device_id],
      [
        [context, '*89', 1, 'VoiceMailMain', '', 0],
        [context, '*89', 2, 'Hangup', '', 0],
        [context, ext, 1, 'AGI', 'mor_acc2user', 0],
        [context, ext, 2, 'VoiceMailMain', 's${MOR_EXT}', 0],
        [context, ext, 3, 'Hangup', '', 0],
        [context, '_*X.', 1, 'Goto', 'mor_local,${EXTEN},1', 0],
        [context, '_X.', 1, 'Goto', 'mor_local,${EXTEN},1', 0]
      ]
      )
  end

  def delete_extlines
    Extline.delete_all(context: make_context_name)
  end

  def make_context_name
    pbx_pool_id = self.id
    "pool_#{pbx_pool_id}_mor_local"
  end

  def reload_dialplan_in_asterisk
    servers_for_reload = Server.where(active: 1, server_type: 'asterisk').all.to_a
    servers_for_reload.each { |server| server.ami_cmd('dialplan reload') }
  end

  def extension_count
    count = 0
    self.users.each do |user|
      count += user.devices.to_a.count{ |device| device.device_type != 'Virtual' }
    end
    count += Dialplan.where("(dptype = 'ringgroup' OR dptype = 'queue' OR dptype = 'pbxfunction') AND data6 = #{self.id}").all.size
    count
  end

  def pool_objects
    objects = []
    self.users.each do |user|
      user.devices.each do |device|
        objects << device if device.device_type != 'Virtual'
      end
    end
    (objects << Dialplan.select('dptype as type, data2 as extension, name, data1, id').where("(dptype = 'ringgroup' OR dptype = 'queue' OR dptype = 'pbxfunction') AND data6 = #{self.id}").all).flatten!
    objects
  end
end
