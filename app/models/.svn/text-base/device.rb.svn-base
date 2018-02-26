# -*- encoding : utf-8 -*-
class Device < ActiveRecord::Base
  attr_protected
  # this is based on http://www.ruby-forum.com/topic/101557
  self.inheritance_column = :_type_disabled # we have devices.type column for asterisk 1.8 support,
                                            # so we need this to allow such column

  # setter for the "type" column
  def device_ror_type=(type)
    self[:type] = type
  end

  attr_accessor :device_ip_authentication_record
  attr_accessor :device_old_name_record
  attr_accessor :device_old_server_record
  attr_accessor :tmp_codec_cache

  belongs_to :user
  has_many :extlines, -> { order('exten ASC, priority ASC') }
  has_many :dids
  has_many :devicecodecs
  belongs_to :devicegroup
  has_many :callerids
  belongs_to :location
  has_one :voicemail_box
  has_many :callflows
  has_many :pdffaxemails
  has_one :provider
  belongs_to :server
  has_many :activecalls, foreign_key: 'src_device_id'
  has_many :ringgroups_devices
  has_many :devicerules
  has_many :server_devices, dependent: :destroy
  has_many :servers, through: :server_devices
  belongs_to :primary_did, class_name: 'Did'

  before_validation :check_device_username, :check_device_range, on: :create

  validates_presence_of :name, message: _('Device_must_have_name')
  validates_presence_of :extension, message: _('Device_must_have_extension')
  validates_format_of :max_timeout, with: /\A[0-9]+\z/,
                      message: _('Device_Call_Timeout_must_be_greater_than_or_equal_to_0')
  validates_numericality_of [:time_limit_per_day, :max_timeout], only_integer: true
  validates :callgroup, numericality: {only_integer: true}, allow_nil: true,
                        inclusion: {in: 0..63, message: _('Call_Group_bad_range')}
  validates :pickupgroup, numericality: {only_integer: true}, allow_nil: true,
                          inclusion: {in: 0..63, message: _('Pickup_Group_bad_range')}
  validates_numericality_of :port, message: _('Port_must_be_number'),
   	                            if: Proc.new{ |value| not value.port.blank? }
  # before_create :check_callshop_user
  before_save :uniqueness_check, :validate_extension_from_pbx,
              :ensure_server_id, :random_password, :check_and_set_defaults,
              :check_password, :ip_must_be_unique_on_save, :check_language,
              :check_location_id, :check_dymanic_and_ip,
              :validate_trunk, :ast18, :t38pt_normalize, :validate_outbound_proxy
  before_update :uniqueness_check, :validate_fax_device_codecs
  after_create :create_codecs, :device_after_create
  after_save :device_after_save#, :prune_device #do not prune devices after save!
  # it abuses AMI and crashes live calls (#11709)!
  # prune_device is done in device_update->application_controller->configure_extensions->prune_device

  # Resellers are allowed to assign dids to trunk only if appropriate settings is set by admin.
  # In case device allready has assigned dids, it cannot be set to trunk if reseller does not have
  # rights to assign dids to trunk.
  def validate_trunk
    if self.user and self.user.owner.usertype == 'reseller'
      allowed_to_assign_did = self.user.owner.allowed_to_assign_did_to_trunk?
      has_assigned_did = (not self.dids.empty?)
      if self.is_trunk? and has_assigned_did and not allowed_to_assign_did
        self.errors.add(:trunk, _('Did_is_assigned_to_device'))
        return false
      end
    end
  end

  # Device may be blocked by core if there are more than one simultaneous call
  def block_callerid?
    (block_callerid.to_i > 1)
  end

  # Only valid arguments for block_callerid is 0 or integer greater than 1
  # if params  are invalid we set it to 0

  # Params
  # *simalutaneous_calls* limit of simultaneous calls when core should automaticaly
  #   block device
  def block_callerid=(simultaneous_calls)
    simultaneous_calls = simultaneous_calls.to_s.strip.to_i
    simultaneous_calls = simultaneous_calls < 2 ? 0 : simultaneous_calls
    write_attribute(:block_callerid, simultaneous_calls)
  end


  # Note that this method is written mostly thinking about using it in views so dont
  # expect any logic beyound that.

  # Returns
  # *simultaneous_calls* if block_callerid is set to smth less than 2 retun empty string
  #   else return that number
  def block_callerid
    simultaneous_calls = read_attribute(:block_callerid).to_i
    simultaneous_calls < 2 ? '' : simultaneous_calls
  end

  def is_trunk?
    return self.istrunk.to_i > 0
  end

  # true if srtp encryption is set for device, otherwise false
  def srtp_encryption?
    self.encryption.to_s == 'yes'
  end

  # if username is blank it means that ip authentication is enabled and there's
  # no need to check for valid passwords.
  # server device is an exception, so there's no need to check whether it's pass is valid or not.
  # TODO: each device type should have separate class. there might be PasswordlessDevice
  def check_password
    unless server_device? or username.blank? or provider or
      ['dahdi', 'virtual', 'h323'].include?(device_type.downcase)
      if name and secret.to_s == name.to_s
        errors.add(:secret, _('Name_And_Secret_Cannot_Be_Equal'))
        return false
      end

      if self.secret.to_s.length < 8 and Confline.get_value("Allow_short_passwords_in_devices").to_i == 0
        errors.add(:secret, _('Password_is_too_short'))
        return false
      end
    end
  end

  def validate_fax_device_codecs
    valid_codecs_count = self.codecs.count { |codec| ['alaw', 'ulaw'].include? codec.try(:name) }
    if fax? and valid_codecs_count == 0
      self.errors.add(:devicecodecs, 'Fax_device_has_to_have_at_least_one_codec_enabled')
      return false
    else
      return true
    end
  end

  def validate_extension_from_pbx
    if user && Dialplan.where(dptype: "pbxfunction", data2: extension, data6: user.pbx_pool_id).first
      errors.add(:extension, _('Device_extension_must_be_unique'))
      return false
    end
  end

  def check_language
    if self.language.to_s.blank?
      self.language = 'en'
    end
  end

  def check_location_id
    if self.user and self.user.owner_id != 0
      #if old location id - create and set
      value = Confline.get_value("Default_device_location_id", self.user.owner_id)
      if value.blank? or value.to_i == 1 or !value
        owner = User.where(id: self.user.owner_id).first
        owner.after_create_localization
      else
        #if new - only update devices with location 1
        self.user.owner.update_resellers_device_location(value)
      end
    end
  end

  def check_and_set_defaults
    if self.device_type
      if ['sip', 'iax2'].include?(self.device_type.downcase)
        self.nat ||= 'yes'
        self.canreinvite ||= 'no'
      end
    end
  end

  # checks if server with such id exists
  def ensure_server_id
    if self.server_id.blank? or !Server.where(id: self.server_id).first
      default = Confline.get_value('Default_device_server_id')
      if default.present? and Server.where(id: default).first.present?
        self.server_id = default
      else
        if server = Server.order("id ASC").first
          first_server_id = server.id
          Confline.set_value("Default_device_server_id", first_server_id)
          self.server_id = first_server_id
        else
          errors.add(:server, _('Server_Not_Found'))
          return false
        end
      end
    end
  end

  def check_callshop_user(flash)
    if user and user.callshops.size.to_i != 0 and user.devices.size.to_i > 0 and
      Confline.get_value('CS_Active').to_i == 1
      flash += " <br> " + _('User_in_CallShop_can_have_only_one_Device_creating_more_is_dangerous')
    end
    return flash
  end

  def random_password
    if (fax? or virtual?) and secret.blank?
      self.secret = ApplicationController::random_password(10).to_s
    end
  end

  # converting callerid like "name" <number> to number
  def callerid_number
    cid = callerid
    cidn = ''

    if callerid and cid.index('<') and cid.index('>') and cid.index('<') >= 0 and cid.index('>') > 0
      cidn = cid[cid.index('<')+1, cid.index('>')-cid.index('<')-1]
    end

    cidn
  end

  def check_device_username
    if self.username_must_be_unique_on_creation
      username = self.username; name = self.username
      while Device.where(username: username).first
        username = self.generate_rand_name(name, 2)
      end
      self.username = username
    end

    if virtual?
      username = self.username;
      while Device.where(username: username).first
        username = self.generate_rand_name('', 12)
      end
      self.username = username
    end
  end

  def generate_rand_name(string, size)
    chars = '123456789abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ'
    str = ''
    size.times { |int| str << chars[rand(chars.length)] }
    string + str
  end

  def Device.clis_order_by(options)
    case options[:order_by].to_s
      when 'cli'
        order_by = 'callerids.id'
      when 'device'
        order_by = 'devices.name'
      when 'description'
        order_by = 'callerids.description'
      when 'added_at'
        order_by = 'callerids.created_at'
      when 'updated_at'
        order_by = 'callerids.updated_at'
      when 'comment'
        order_by = 'callerids.comment'
      when 'ivr'
        order_by = 'ivrs.id'
    end

    if order_by
      case options[:order_desc]
        when 0
          order_by += ' ASC'
        when 1
          order_by += ' DESC'
      end
    end

    return order_by
  end


  # Every device has to have ONE voicemail box, so after saveing it we should create
  # voicemail. lookin' at device_after_create and thinking it's plain stupid, huh?
  # Note that i do not check whether self.user is not nil, because if it would be nil,
  # it would mean that referential integrity was broken and so miskate was made by breaking it
  # not by trusting that it wouldnt be broken.
  def device_after_save
    write_attribute(:accountcode, id)
    sql = "UPDATE devices SET accountcode = id WHERE id = #{id};"
    ActiveRecord::Base.connection.update(sql)
    user = self.user
    if user && self.voicemail_box.blank?
      email = Confline.get_value("Default_device_voicemail_box_email", user.owner_id)
      email = user.address.email if user.address && user.address.email.to_s.size > 0
      default_vm_delete = Confline.get_value('Default_device_delete_vm', user.owner_id)
      create_vm(extension, Confline.get_value("Default_device_voicemail_box_password", user.owner_id), user.first_name + " " + user.last_name, email, default_vm_delete)
    end
  end

  def reload_sip_keeprt
    server = Server.where(id: self.server_id).first

    if server.server_type == 'asterisk'
      server.ami_cmd("sip reload keeprt")
    end
  end

  def device_after_create
    #device_after_save
    if self.user
      user = self.user
      curr_id = User.current ? User.current.id : self.user.owner_id
      Action.add_action_hash(curr_id, {target_id: id, target_type: 'device', action: 'device_created'})
      #------- VM ----------
      email = Confline.get_value('Default_device_voicemail_box_email', user.owner_id)
      email = user.address.email if user.address && user.address.email.to_s.size > 0
      default_vm_delete = Confline.get_value('Default_device_delete_vm', user.owner_id)
      create_vm(extension, Confline.get_value("Default_device_voicemail_box_password", user.owner_id), user.first_name + " " + user.last_name, email, default_vm_delete)
      dev = user.devices.size.to_i #Device.count(:all, :conditions=>"user_id = #{user.id}")
      if dev.to_i == 1
        user.primary_device_id = id
        user.save
      end
      self.update_cid(Confline.get_value('Default_device_cid_name', user.owner_id), Confline.get_value('Default_device_cid_number', user.owner_id)) unless self.callerid
    end

    if virtual?
      self.extension = self.username = self.name = 'virtual_' + self.id.to_i.to_s
      self.save
    end

    if h323?
      self.username = ''
      self.secret = ''
      if !self.name.include?('ipauth')
        name = self.generate_rand_name('ipauth', 8)
        while Device.where(['name= ? and id != ?', name, self.id]).first
          name = self.generate_rand_name('ipauth', 8)
        end
        self.name = name
      end
      self.save
    end
  end


  #================== CODECS =========================


  def create_codecs
    owner = self.user_id > 0 ? self.user.owner_id : 0

    # If device is fax always auto set ulaw and alaw. #9351
    if fax?
      (0..1).each do | index |
        pc = Devicecodec.new({
          codec_id: (index + 1),
          device_id: self.id,
          priority: index
        })
        pc.save
      end
    else
      for codec in Codec.all
        if Confline.get_value("Default_device_codec_#{codec.name}", owner).to_i == 1
          pc = Devicecodec.new
          pc.codec_id = codec.id
          pc.device_id = self.id
          pc.priority = Confline.get_value2("Default_device_codec_#{codec.name}", owner).to_i
          pc.save
        end
      end
    end

    self.update_codecs
  end

  def codec?(codec)
    sql = "SELECT codecs.name FROM devicecodecs, codecs WHERE devicecodecs.device_id = '" + self.id.to_s + "' AND devicecodecs.codec_id = codecs.id GROUP BY codecs.name HAVING COUNT(*) = 1"
    self.tmp_codec_cache = (self.tmp_codec_cache || ActiveRecord::Base.connection.select_values(sql))
    self.tmp_codec_cache.include? codec.to_s
  end

  def codecs
    res = Codec.select("*").joins("LEFT JOIN devicecodecs ON (devicecodecs.codec_id = codecs.id)").where("devicecodecs.device_id = #{self.id.to_s}").order("devicecodecs.priority").all
    codecs = []

    for cods in 0..res.size-1
      codecs << Codec.where(id: res[cods]['codec_id']).first
    end

    codecs
  end

  def codecs_order(type)
    cond = fax? ? ' AND codecs.name IN ("alaw", "ulaw") ' : ''
    Codec.find_by_sql("SELECT codecs.*,  IF(devicecodecs.priority is null, 100, devicecodecs.priority)  as bb FROM codecs  LEFT Join devicecodecs on (devicecodecs.codec_id = codecs.id and devicecodecs.device_id = #{self.id.to_i})  where codec_type = '#{type}' #{cond} ORDER BY bb asc, codecs.id")
  end


  def update_codecs_with_priority(codecs, ifsave = true)
    dev_c = {}
    Devicecodec.where(["device_id = ?", id]).all.each { |codec| dev_c[codec.codec_id] = codec.priority; codec.destroy }
    Codec.all.each { |codec| Devicecodec.new(codec_id: codec.id, device_id: id,
                                               priority: dev_c[codec.id].to_i).save if codecs[codec.name] == "1" }
    self.update_codecs(ifsave)
  end

  def update_codecs(ifsave = true)
    cl = []
    # If device is fax always auto set ulaw and alaw. #9351
    if fax?
      self.allow = 'alaw;ulaw'
    else
      self.codecs.each { |codec| cl << codec.try(:name) }
      cl << "all" if cl.size.to_i == 0
      self.allow = cl.join(';')
    end
    self.save if ifsave
  end

  #================== END OF CODECS =========================

  def update_cid(cid_name, cid_number, ifsave = true)
    cid_name = '' if not cid_name
    cid_number = '' if not cid_number

    self.callerid = nil unless self.callerid

    if cid_name.length > 0 and cid_number.length > 0
      self.callerid = "\"" + cid_name.to_s + "\"" + " <" + cid_number.to_s + ">"
    end

    if cid_name.length > 0 and cid_number.length == 0
      self.callerid = "\"" + cid_name.to_s + "\""
    end

    if cid_name.length == 0 and cid_number.length == 0
      self.callerid = ''
    end

    if cid_name.length == 0 and cid_number.length > 0
      self.callerid = "<" + cid_number.to_s + ">"
    end

    self.save if ifsave
  end

  #======================= CALLS =============================

  def all_calls
    Call.where(src_device_id: self.id)
  end

  def any_calls
    Call.where(src_device_id: self.id).limit(1)
  end

  def calls(type, date_from, date_till)
    #possible types:
    # all +
    #    local
    #    external
    #       incoming
    #         missed +
    #         missed_not_processed +
    #       outgoing
    #         answered
    #         failed
    #           busy
    #           no_answer
    #           error
    if type == "all"
      @calls = Call.where(["src_device_id =? " + date_query(date_from, date_till), self.id]).order(calldate: :desc).all
    end

    if type == "answered"
      @calls = Call.where(["billsec > 0 AND src_device_id = ? AND disposition = 'ANSWERED' " + date_query(date_from, date_till), self.id]).order(" calldate DESC").all
    end

    if type == "noanswer"
      @calls = Call.where(["src_device_id = ? AND disposition = 'NO ANSWER' " + date_query(date_from, date_till), self.id]).order(" calldate DESC").all
    end

    if type == "failed"
      @calls = Call.where(["src_device_id = ? AND disposition = 'FAILED' " + date_query(date_from, date_till), self.id]).order(" calldate DESC").all
    end

    if type == "busy"
      @calls = Call.where(["src_device_id = ? AND disposition = 'BUSY' " + date_query(date_from, date_till), self.id]).order(" calldate DESC").all
    end

    if type == "missed"
      @calls = Call.where(["src_device_id =? AND disposition != 'ANSWERED' " + date_query(date_from, date_till), self.id]).order(" calldate DESC").all
    end

    if type == "missed_not_processed"
      @calls = Call.where(["processed = '0' AND src_device_id =? AND disposition != 'ANSWERED' " + date_query(date_from, date_till), self.id]).order(" calldate DESC").all
    end

    #---incoming---

    if type == "all_inc"
      @calls = Call.where(["dst_device_id =? " + date_query(date_from, date_till), self.id]).order(" calldate DESC").all
    end

    if type == "answered_inc"
      @calls = Call.where(["billsec > 0 AND dst_device_id = ? AND disposition = 'ANSWERED' " + date_query(date_from, date_till), self.id]).order(" calldate DESC").all
    end

    if type == "noanswer_inc"
      @calls = Call.where(["dst_device_id = ? AND disposition = 'NO ANSWER' " + date_query(date_from, date_till), self.id]).order(" calldate DESC").all
    end

    if type == "failed_inc"
      @calls = Call.where(["dst_device_id = ? AND disposition = 'FAILED' " + date_query(date_from, date_till), self.id]).order(" calldate DESC").all
    end

    if type == "busy_inc"
      @calls = Call.where(["dst_device_id = ? AND disposition = 'BUSY' " + date_query(date_from, date_till), self.id]).order(" calldate DESC").all
    end

    if type == "missed_inc"
      @calls = Call.where(["dst_device_id =? AND disposition != 'ANSWERED' " + date_query(date_from, date_till), self.id]).order(" calldate DESC").all
    end

    if type == "missed_not_processed_inc"
      @calls = Call.where(["processed = '0' AND dst_device_id =? AND disposition != 'ANSWERED' " + date_query(date_from, date_till), self.id]).order(" calldate DESC").all
    end

    #--not used---

    if type == "incoming"
      @calls = Call.where(["user_price >= 0 AND dst_device_id =? " + date_query(date_from, date_till), self.id]).order(" calldate DESC").all
    end

    if type == "outgoing"
      @calls = Call.where(["user_price >= 0 AND src_device_id =? " + date_query(date_from, date_till), self.id]).order(" calldate DESC").all
    end

    @calls
  end

  def total_calls(type, date_from, date_till)
    if type == "all"
      t_calls = Call.where(["(src_device_id = ? OR dst_device_id =?) AND user_id IS NOT NULL " + date_query(date_from, date_till), self.id, self.id]).order(" calldate DESC").count
    end

    if type == "answered"
      t_calls = Call.where(["billsec > 0 AND src_device_id = ? AND #{Call.nice_answered_cond_sql} " + date_query(date_from, date_till), self.id]).order(" calldate DESC").count
    end

    if type == "answered_out"
      t_calls = Call.where(["src_device_id = ? AND #{Call.nice_answered_cond_sql} " + date_query(date_from, date_till), self.id]).order(" calldate DESC").count
    end

    if type == "no_answer_out"
      t_calls = Call.where(["src_device_id = ? AND disposition = 'NO ANSWER' " + date_query(date_from, date_till), self.id]).order(" calldate DESC").count
    end

    if type == "busy_out"
      t_calls = Call.where(["src_device_id = ? AND disposition = 'BUSY' " + date_query(date_from, date_till), self.id]).order(" calldate DESC").count
    end

    if type == "failed_out"
      t_calls = Call.where(["src_device_id = ?  AND user_id IS NOT NULL AND #{Call.nice_failed_cond_sql} " + date_query(date_from, date_till), self.id]).order(" calldate DESC").count
    end

    if type == "answered_inc"
      t_calls = Call.where(["dst_device_id = ? AND #{Call.nice_answered_cond_sql} " + date_query(date_from, date_till), self.id]).order(" calldate DESC").count
    end

    if type == "no_answer_inc"
      t_calls = Call.where(["dst_device_id = ? AND disposition = 'NO ANSWER' " + date_query(date_from, date_till), self.id]).order(" calldate DESC").count
    end

    if type == "busy_inc"
      t_calls = Call.where(["dst_device_id = ? AND disposition = 'BUSY' " + date_query(date_from, date_till), self.id]).order(" calldate DESC").count
    end

    if type == "failed_inc"
      t_calls = Call.where(["dst_device_id = ? AND #{Call.nice_failed_cond_sql} " + date_query(date_from, date_till), self.id]).order(" calldate DESC").count
    end


    if type == "missed_not_processed"
      t_calls = Call.where(["processed = '0' AND dst_device_id =? AND #{Call.nice_answered_cond_sql(false)}" + date_query(date_from, date_till), self.id]).order(" calldate DESC").count
    end

    if type == "incoming"
      t_calls = Call.where(["dst_device_id =? " + date_query(date_from, date_till), self.id]).order(" calldate DESC").count
    end

    if type == "outgoing"
      t_calls = Call.where(["src_device_id =? AND user_id IS NOT NULL " + date_query(date_from, date_till), self.id]).order(" calldate DESC").count
    end

    t_calls
  end

  def total_duration(type, date_from, date_till)
    call_nice_answered_cond_sql = Call.nice_answered_cond_sql
    if type == 'answered' || type == 'answered_out'
      t_duration = Call.where(["billsec > 0 AND src_device_id = ? AND #{call_nice_answered_cond_sql} " + date_query(date_from, date_till), id]).order(" calldate DESC").sum(:duration)
    end

    if type == "answered_inc"
      t_duration = Call.where(["billsec > 0 AND dst_device_id = ? AND #{call_nice_answered_cond_sql} " + date_query(date_from, date_till), id]).order(" calldate DESC").sum(:duration)
    end

    t_duration = 0 if t_duration == nil
    t_duration
  end


  def total_billsec(type, date_from, date_till)

    if type == "answered"
      #t_billsec = Call.sum(:billsec, :conditions => ["calls.card_id = 0 AND billsec > 0 AND src_device_id = ? AND disposition = 'ANSWERED' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
      sql = "SELECT sum(billsec) AS sum_billsec2 FROM calls WHERE (billsec > 0 AND src_device_id = '#{self.id}' AND #{Call.nice_answered_cond_sql} #{date_query(date_from, date_till)}) ORDER BY calldate DESC"
      res = ActiveRecord::Base.connection.select_one(sql)
      t_billsec = res['sum_billsec'].to_i
    end

    if type == "answered_out"
      #t_billsec = Call.sum(:billsec, :conditions => ["calls.card_id = 0 AND billsec > 0 AND src_device_id = ? AND disposition = 'ANSWERED' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
      sql = "SELECT sum(billsec) AS sum_billsec FROM calls WHERE (billsec > 0 AND src_device_id = '#{self.id}' AND #{Call.nice_answered_cond_sql} #{date_query(date_from, date_till)}) ORDER BY calldate DESC"
      res = ActiveRecord::Base.connection.select_one(sql)
      t_billsec = res['sum_billsec'].to_i
    end

    if type == "answered_inc"
      #t_billsec = Call.sum(:billsec, :conditions => ["calls.card_id = 0 AND billsec > 0 AND dst_device_id = ? AND disposition = 'ANSWERED' " + date_query(date_from, date_till), self.id], :order => " calldate DESC")
      sql = "SELECT sum(billsec) AS sum_billsec FROM calls WHERE (billsec > 0 AND dst_device_id = '#{self.id}' AND #{Call.nice_answered_cond_sql} #{date_query(date_from, date_till)}) ORDER BY calldate DESC"
      res = ActiveRecord::Base.connection.select_one(sql)
      t_billsec = res['sum_billsec'].to_i
    end

    t_billsec = 0 if t_billsec == nil
    t_billsec
  end


  # forms sql part for date selection

  def date_query(date_from, date_till)
    # date query
    if date_from == ''
      date_sql = ''
    else
      if date_from.length > 11
        date_sql = "AND calldate BETWEEN '#{date_from.to_s}' AND '#{date_till.to_s}'"
      else
        date_sql = "AND calldate BETWEEN '" + date_from.to_s + " 00:00:00' AND '" + date_till.to_s + " 23:59:59'"
      end
    end
    date_sql
  end

  def destroy_everything
    err = []
    if self.all_calls.size == 0

      for email in self.pdffaxemails do
        email.destroy
      end

      for cid in self.callerids do
        cid.destroy
      end

      Extline.delete_all(["device_id = ?", self.id])

      err = self.prune_device_in_all_servers(nil, 0, 1, 1)

      self.destroy_vm
      self.destroy
    end
    err
  end


  def prune_device_in_all_servers(dv_name = nil, reload = 1, sip = 1, iax2 = 1)
    dv_name = name if dv_name.nil?
    err= []
    # clean Realtime mess
    servers = Server.all
    for server in servers
      begin
        server.prune_peer(dv_name, reload, sip, iax2, self.id)
      rescue SystemExit => error
        err << error.message
      end
    end

    err
  end

  def prune_device_in_server(dv_name = nil, reload = 1, serverid = nil, sip = 1, iax2 = 1)
    dv_name = name if dv_name.nil?
    serverid = server_id if serverid.nil?
    err= []
    # clean Realtime mess http://trac.kolmisoft.com/trac/ticket/5092
    server = Server.where(id: serverid).first
    begin
      server.prune_peer(dv_name, reload, sip, iax2, self.id) if server
    rescue SystemExit => error
      err << error.message
    end
    err
  end

  #put value into file for debugging
  def my_debug(msg)
    File.open(Debug_File, "a") { |file_line|
      file_line << msg.to_s
      file_line << "\n"
    }
  end

  #--------------- VoiceMail--------------
  def voicemail_box
    VoicemailBox.where("device_id = #{id}").first if id
  end

  def destroy_vm
    if voicemail_box
      vm_id = voicemail_box.id
      sql = "DELETE FROM voicemail_boxes WHERE uniqueid = '#{vm_id}'"
      res = ActiveRecord::Base.connection.update(sql)
      #self.voicemail_box.destroy
    end
  end

  # Check if device is a detectable fax
  def has_fax_detect
    flow = Callflow.where(["data = ? and data2 = 'fax' and action = 'fax_detect'", self.id]).all
    return flow if flow.size > 0
    return nil
  end

  # Check if device has calls forwarded to it
  def has_forwarded_calls
    flow = Callflow.where(["data = ? and data2 = 'local' and action = 'forward'", self.id]).all
    return flow if flow.size > 0
    return nil
  end

  def dialplans
    return Dialplan.where("(dptype = 'authbypin' and data5 = '#{id}') or (dptype != 'authbypin' and data3 = '#{id}')")
  end

  # Check if device is used by location rules
  def used_by_location_rules
    Locationrule.where(device_id: self.id).first
  end

  def used_by_queues
    AstQueue.where(failover_action: 'device', failover_data: self.id).first
  end

  def used_by_queue_agent
    QueueAgent.where(device_id: self.id).first
  end

  def used_by_alerts
    Alert.where(check_type: 'device', check_data: self.id).first
  end

  def uniqueness_check
    next_id = "SELECT auto_increment FROM information_schema.tables WHERE table_name='devices'"
    self_id = self.id || ActiveRecord::Base.connection.select_value(next_id).to_i
    if self.provider
      fields	= %w{ username secret ipaddr port device_type }
      matches	= ["device_id != ? AND providers.user_id != #{User.current.id}", self_id]
    else
      fields	= %w{ username } # Why only username?
      matches	= ["host = 'dynamic' AND devices.id != ?", self_id]
    end

    query 	= Hash[fields.map {|field| [field.to_sym, self[field.to_sym].to_s] }]

    message = _('Device_Username_Must_Be_Unique')

    filter_active	= Confline.get_value("Disalow_Duplicate_Device_Usernames", 0).to_i == 1

    dublicate_device = Device.joins('LEFT JOIN providers on providers.device_id = devices.id')
                             .where(matches).where(query)
                             .reject{ |dev| not self.provider and dev.username.blank? }.first

    if filter_active && dublicate_device
      if admin?
        if dublicate_device.try(:user_id).to_i > 0 || dublicate_device.provider.try(:user_id).to_i > 0
          message << ". #{_('Username_has_already_been_taken_by')} " +
                     " #{nice_device_user(dublicate_device)} in #{dublicate_device.provider ? _('Provider') : _('Device')}: #{dublicate_device.nice_device}"
        else
          message << ". #{_('Username_has_already_been_taken_by')} #{dublicate_device.user_id}  #{_('Provider')}: #{dublicate_device.nice_device}"
        end
      end

      message << " <a id='exception_info_link' href='http://wiki."\
              "kolmisoft.com/index.php/Authentication' target='_blank'><"\
              "img alt='Help' src='#{Web_Dir}/images/icons/help.png'"\
              "title='#{_('Help')}' /></a>"

      errors.add(:username, message)

      return false
    end
  end

  def username_must_be_unique_on_creation
    self.device_ip_authentication_record.to_i == 0 and Confline.get_value("Disalow_Duplicate_Device_Usernamess").to_i == 1 and (!self.provider or self.provider.user_id != User.current.id)
  end

  def dynamic?
    (ipaddr.blank? or ipaddr.to_s == '0.0.0.0') ? true : false
  end

  def ip_must_be_unique_on_save
    idi = self.id
    help_link = "<a id='exception_info_link' href='http://wiki."\
              "kolmisoft.com/index.php/Authentication' target='_blank'><"\
              "img alt='Help' src='#{Web_Dir}/images/icons/help.png'"\
              "title='#{_('Help')}' /></a>"
    message = if admin?
                "#{_('IP_Port_combination_used_by')} #{_('User')}: "
              else
                "#{_('This_IP_is_not_available')}. #{help_link}"
              end

    is_admin_or_reseller = %w[admin reseller].include? User.current.try(:usertype)
    is_end_user = User.current.try(:usertype) == 'user'

    curr_id = User.current.try(:id) || self.user.try(:owner_id)

    cond = if ipaddr.blank?
             ['devices.id != ? AND host = ? AND providers.user_id != ? and ipaddr != "" and ipaddr != "0.0.0.0" and devices.port=?', idi, host, curr_id, port]
           else
             ['devices.id != ? AND (host = ? OR ipaddr = ?) AND providers.user_id != ? and ipaddr != "" and ipaddr != "0.0.0.0" and devices.port=?', idi, host, ipaddr, curr_id, port]
           end

    #    check device wihs is provider with providers devices
    providers_device_with_ip = Device.joins("JOIN providers ON (providers.device_id = devices.id)").where(cond).first

    if self.device_ip_authentication_record.to_i == 1 && self.provider && providers_device_with_ip && !virtual?
      if admin?
        link = "<a href='#{Web_Dir}/users/edit/#{providers_device_with_ip.provider.user.id}'>"\
          "#{nice_device_user(providers_device_with_ip)}</a>"
        message << " #{link} in Provider: #{providers_device_with_ip.nice_device}. #{help_link}"
      end
      errors.add(:ip_authentication, message)
      return false
    end

    #      check self device  or another devices with ip auth on
    condd = self.device_ip_authentication_record.to_i == 1 ? '' : ' and devices.username = "" '

    cond_second = if ipaddr.blank?
               # check device host with another owner devices
               ['devices.id != ? AND host = ? and users.owner_id != ?  and user_id != -1 and ipaddr != "" and ipaddr != "0.0.0.0" and devices.port=?' + condd, idi, host, curr_id, port]
             else
               # check device IP and Host with another owner devices
               ['devices.id != ? AND (host = ? OR ipaddr = ?) and users.owner_id != ? and user_id != -1 and ipaddr != "" and ipaddr != "0.0.0.0" and devices.port=?' + condd, idi, host, ipaddr, curr_id, port]
             end

    #    check device IP with another user providers IP's with have ip auth on, 0.0.0.0 not included
    device_with_ip = Device.joins("JOIN users ON (user_id = users.id)").where(cond_second).first

    if (device_with_ip && !Application.allow_duplicate_ip_port?) && !self.dynamic? && !virtual? && !is_end_user
      if admin?
        link = "<a href='#{Web_Dir}/users/edit/#{device_with_ip.user.owner_id}'>"\
          "#{nice_device_user(device_with_ip)}</a>"
        message << " #{link} in Device: #{device_with_ip.nice_device}. #{help_link}"
      end
      errors.add(:ip_authentication, message)
      return false
    end

    #    check device IP with another user providers IP's with have ip auth on, 0.0.0.0 not included
    provider_with_ip = Provider.joins("JOIN devices ON (providers.device_id = devices.id)").where(["server_ip = ? and devices.username = '' AND server_ip != '' AND devices.id != ? AND ipaddr != '' AND providers.user_id != ? and ipaddr != '' and devices.port=?", ipaddr, idi, curr_id, port]).first

    if provider_with_ip && !virtual?
      if admin?
        link = "<a href='#{Web_Dir}/users/edit/#{provider_with_ip.user.id}'>"\
          "#{nice_device_user(provider_with_ip)}</a>"
        message << " #{link} in Provider: #{nice_provider(provider_with_ip)}. #{help_link}"
      end

      errors.add(:ip_authentication, message)
      return false
    end


    #    check device with providers port, dont allow dublicates in providers and devices combinations
    if self.provider
      cond_third = if ipaddr.blank?
                ['devices.id != ? AND host = ? and ipaddr != "" and ipaddr != "0.0.0.0" and devices.port=? AND providers.id IS NULL' + condd, idi, host, port]
              else
                ['devices.id != ? AND (host = ? OR ipaddr = ?) and ipaddr != "" and ipaddr != "0.0.0.0" and devices.port=? AND providers.id IS NULL' + condd, idi, host, ipaddr, port]
              end
      device_with_ip = Device.joins(['JOIN users ON (user_id = users.id) LEFT JOIN providers ON (providers.device_id = devices.id)']).where(cond_third).first

      if device_with_ip && !virtual?
        link = "<a href='#{Web_Dir}/devices/device_edit/#{device_with_ip.id}'>"\
          "#{device_with_ip.nice_device}</a>"
        message_cec = if is_admin_or_reseller
          "#{_("IP_Port_combination_used_by")} #{_('Device')}: #{link}. #{help_link}"
        else
          "#{_('This_IP_is_not_available')}.2 #{help_link}"
        end
        errors.add(:ip_authentication, message_cec)
        return false
      end

    else
      cond_third = if ipaddr.blank?
                ['devices.id != ? AND host = ? and ipaddr != "" and ipaddr != "0.0.0.0" and devices.port=? ' + condd, idi, host, port]
              else
                ['devices.id != ? AND (host = ? OR ipaddr = ?) and ipaddr != "" and ipaddr != "0.0.0.0" and devices.port=?' + condd, idi, host, ipaddr, port]
              end
      used_by_provider = Provider.joins(['JOIN devices ON (device_id = devices.id)']).where(cond_third).first
      if used_by_provider && !virtual?
        link = "<a href='#{Web_Dir}/providers/edit/#{used_by_provider.id}'>"\
          "#{nice_provider(used_by_provider)}</a>"
        message_cec = if is_admin_or_reseller
          "#{_('IP_Port_combination_used_by')} #{_('Provider')}: #{link}. #{help_link}"
        else
          "#{_('This_IP_is_not_available')}.3 #{help_link}"
        end
        errors.add(:ip_authentication, message_cec)
        return false
      end
    end
  end

  def check_dymanic_and_ip
    if username.blank? and host.to_s == 'dynamic'
      errors.add(:host, _("When_IP_Authentication_checked_Host_cannot_be_dynamic"))
      return false
    end
  end

  def username_must_be_unique
    Confline.get_value("Disalow_Duplicate_Device_Usernames").to_i == 1 and self.device_ip_authentication_record.to_i == 0 and !self.provider
  end

  def provider_device_username_unique?
    Confline.get_value("Disalow_Duplicate_Device_Usernames").to_i == 1 and self.device_ip_authentication_record.to_i == 0 and self.provider and !self.username.blank?
  end

  def Device.validate_perims(options={})
    permits = "0.0.0.0/0.0.0.0"
    if options[:ip_first].size > 0 and options[:mask_first].size > 0
      unless Device.validate_ip(options[:ip_first].to_s) and Device.validate_ip(options[:mask_first].to_s)
        return nil
      end
      permits = options[:ip_first].strip + "/" + options[:mask_first].strip
      if options[:ip_second].size > 0 and options[:mask_second].size > 0
        unless Device.validate_ip(options[:ip_second]) and Device.validate_ip(options[:mask_second])
          return nil
        end
        permits += ";" + options[:ip_second].strip + "/" + options[:mask_second].strip
        if options[:ip_third].size > 0 and options[:mask_third].size > 0
          unless Device.validate_ip(options[:ip_third]) and Device.validate_ip(options[:mask_third])
            return nil
          end
          permits += ";" + options[:ip_third].strip + "/" + options[:mask_third].strip
        end
      end
    end
    return permits
  end

  def Device.validate_permits_ip(ip_arr)
    err = true

    ip_arr.each { |ip|
      if ip.present? and !Device.validate_ip(ip)
        err = false
      end
    }

    return err
  end

  def Device::validate_ip(ip)
    ip.gsub(/(^(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:[.](?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}$)/, '').to_s.length == 0 ? true : false
  end

  def Device.find_all_for_select(current_user_id = nil, options={})
    join = (options[:include_did].to_i == 1 ) ? ' JOIN dids ON (dids.device_id = devices.id) ' : ''

    if current_user_id
      select_clause = options[:count].present? ? 'COUNT(devices.id) AS count_all' :
        'devices.id, devices.description, devices.extension, ' +
        'devices.device_type, devices.istrunk, devices.name, devices.ani, devices.username'
      Device.select(select_clause)
            .joins("LEFT JOIN users ON (users.id = devices.user_id) #{join}")
           .where(["device_type != 'FAX' AND (users.owner_id = ? OR users.id = ?) AND name not like 'mor_server_%' AND user_id > -1", current_user_id, current_user_id]).all
    else
      Device.select("id, description, extension, device_type, istrunk, name, ani, username")
            .where("device_type != 'FAX' AND name not like 'mor_server_%' AND user_id > -1")
            .joins(join).all
    end
  end

  def load_device_types(options = {})
    Devicetype.all.map { |type|
      (options.has_key?(type.name) and options[type.name] == false and self.device_type != type.name) ? nil : type
    }.compact
  end

  def perims_split
    ip_first = ''
    mask_first = ''
    ip_second = ''
    mask_second = ''
    ip_third = ''
    mask_third = ''

    data = permit.split(';')

    if data[0]
      rp = data[0].split('/')
      ip_first = rp[0]
      mask_first = rp[1]
    end

    if data[1]
      rp = data[1].split('/')
      ip_second = rp[0]
      mask_second = rp[1]
    end

    if data[2]
      rp = data[2].split('/')
      ip_third = rp[0]
      mask_third = rp[1]
    end

    return ip_first, mask_first, ip_second, mask_second, ip_third, mask_third
  end


  def Device.calleridpresentation
    [
        [_('Presentation_Allowed_Not_Screened'), 'allowed_not_screened'], [_('Presentation_Allowed_Passed_Screen'), 'allowed_passed_screen'],
        [_('Presentation_Allowed_Failed_Screen'), 'allowed_failed_screen'], [_('Presentation_Allowed_Network_Number'), 'allowed'],
        [_('Presentation_Prohibited_Not_Screened'), 'prohib_not_screened'], [_('Presentation_Prohibited_Passed_Screen'), 'prohib_passed_screen'],
        [_('Presentation_Prohibited_Failed_Screen'), 'prohib_failed_screen'], [_('Presentation_Prohibited_Network_Number'), 'prohib'],
        [_('Number_Unavailable'), 'unavailable']
    ]
  end

  def validate_before_destroy(current_user, allow_edit)
    notice = ''

    unless user
      notice = _("User_was_not_found")
    end

    if current_user.usertype == 'accountant' and !allow_edit and notice.blank?
      notice = _('You_have_no_editing_permission')
    end

    if self.has_fax_detect and notice.blank?
      notice = _('Cant_delete_device_has_fax_detect')
    end

    if self.has_forwarded_calls and notice.blank?
      notice = _('Cant_delete_device_has_forwarded_calls')
    end

    if self.any_calls.size > 0 and notice.blank?
      notice = _('Cant_delete_device_has_calls')
    end

    if self.dialplans.size > 0 and notice.blank?
      notice = _('Cant_delete_device_has_dialplans')
    end

    if self.used_by_location_rules and notice.blank?
      notice = _('One_or_more_location_rules_are_using_this_device')
    end

    if self.used_by_queues and notice.blank?
      notice = _('Device_assigned_to_queues')
    end

    if self.used_by_queue_agent and notice.blank?
      notice = _('Device_assigned_to_queue_agents')
    end

    if self.used_by_alerts and notice.blank?
      notice = _('Device_assigned_to_alerts')
    end

    notice
  end

  def destroy_all
    Extline.delete_all(["device_id = ?", id])

    #deleting association with dids
    if dids = Did.where(device_id: id).all
      for did in dids
        did.device_id = "0"
        did.save
      end
    end

    #destroying device connection to servers
    for server_dev in ServerDevice.where("device_id = ?", id).all
      server_dev.destroy
    end

    #destroying codecs
    for device_cod in Devicecodec.where(device_id: id).all
      device_cod.destroy
    end

    #destroying rules
    for dev_rule in Devicerule.where(device_id: id).all
      dev_rule.destroy
    end

    user = user
    self.destroy_everything
  end

  def Device.validate_before_create(current_user, user, params, allow_dahdi, allow_virtual)
    notice = ''

    unless user
      notice = _('User_was_not_found')
    end

    if current_user.usertype == 'accountant' and notice.blank?
      right_hash ={}
      group = current_user.acc_group

      if group
        rights = AccRight.select("acc_rights.name, acc_group_rights.value").
            joins("LEFT JOIN acc_group_rights ON (acc_group_rights.acc_right_id = acc_rights.id AND acc_group_rights.acc_group_id = #{group.id})").
            where(["acc_rights.right_type = ?", group.group_type]).all
        short = {'accountant' => 'acc', 'reseller' => 'res'}
        rights.each { |right|
          name = "#{short[current_user.usertype]}_#{right[:name].downcase}".to_sym
          if right[:value].nil?
            right_hash[name] = 0
          else
            right_hash[name] = ((right[:value].to_i >= 2 and group.only_view) ? 1 : right[:value].to_i)
          end
        }

        params = current_user.sanitize_device_params_by_accountant_permissions(right_hash, params, self.dup)
      else
        right_hash[:acc_device_create] = 0
      end

      if notice.blank? and right_hash[:acc_device_create] != 2
        notice = _('Dont_be_so_smart')
      end
    end

    params[:device][:description].try(:strip!)
    params_device_pin = params[:device][:pin] = params[:device][:pin].try(:strip)
    params_device_extension = params[:device][:extension]
    params_device_groupid = params[:device][:devicegroup_id]
    params_device_max_timeout = params[:device][:max_timeout].try(:strip)

    if  notice.blank? and params_device_extension and Device.where(["extension = ?", params_device_extension]).first
      notice = _('Extension_is_used')
    else
      #pin
      if  notice.blank? and (Device.where([" pin = ?", params_device_pin]).first and params_device_pin.to_s != "")
        notice = _('Pin_is_already_used')
      end

      if  notice.blank? and !params_device_pin.to_s.blank? and params_device_pin.to_s.strip.scan(/[^0-9 ]/).compact.size > 0
        notice = _('Pin_must_be_numeric')
      end
    end

    if notice.blank? and params_device_groupid and !Devicegroup.where({id: params_device_groupid, user_id: user.id}).first
      notice = _('Device_group_invalid')
    end

    type_array = ['SIP', 'IAX2', 'FAX', 'H323', '']
    type_array << "dahdi" if allow_dahdi
    type_array << "Virtual" if allow_virtual

    if notice.blank? and !type_array.include?(params[:device][:device_type].to_s)
      notice = _('Device_type_invalid')
    end

    if params_device_max_timeout.present?
      if notice.blank? && params_device_max_timeout.scan(/[^0-9 ]/).compact.size > 0
        notice = ('Device_Call_Timeout_must_be_greater_than_or_equal_to_0')
      else
        params[:device][:max_timeout] = params_device_max_timeout.to_i
      end
    end

    return notice, params
  end

  # only SIP and IAX devices can have name. but only first two can be authenticated by ip.
  # users can not see SIP/IAX2 device's username if ip
  # authentication is set. and we determine whether ip auth is set by checking if username is empty.

  # *Returns*
  #   *boolean* true or false depending whether we should show username or not
  def show_username?
    (not username.blank? and (sip? or iax2?))
  end

  def dids_numbers
    numbers = []
    dids.each { |did_n| numbers << did_n.did } if dids.try(:size).to_i > 0
    numbers
  end

  def cid_number
    numbers = []
    self.callerids.each { |cid_n| numbers << [cid_n.cli, cid_n.id] } if self.callerids and self.callerids.size.to_i > 0
    numbers
  end

  def device_caller_id_number
    device_caller_id_number = 1
    device_caller_id_number = 3 if cid_from_dids.to_i == 1
    device_caller_id_number = 4 if control_callerid_by_cids.to_i != 0
    device_caller_id_number = 5 if callerid_advanced_control.to_i == 1
    device_caller_id_number = 7 if callerid_number_pool_id.to_i != 0
    device_caller_id_number = 8 if try(:copy_name_to_number).to_i != 0
    device_caller_id_number
  end

  # check whether device belongs to server

  # *Returns*
  # boolean - true if device belongs to server, else false
  def server_device?
    self.name =~ /mor_server_\d+/ ? true : false
  end

  DefaultPort={'SIP' => 5060, 'IAX2' => 4569, 'H323' => 1720}

=begin
  Check whether port is valid for supplied technology, at this moment only ilegal
  ports are those that are less than 1.

  *Returns*
  +valid+ true if port is valid, else false
=end
  def self.valid_port?(port, technology)
    if port.to_i < 1
      return false
    elsif technology == 'SIP'
      return true
    elsif technology == 'IAX'
      return true
    else
      return true
    end
  end

  def device_old_name
    @device_old_name_record
  end

  def device_old_server
    @device_old_server_record
  end

  def set_old_name
    self.device_old_name_record = name
    self.device_old_server_record = server_id
  end

=begin
  Check whether device belongs to provider. This would mean that
  device cannot have user associated with it.
  UPDATE: Seems like that's not true, if provider is assigned to user,
  then provider device's user_id is set to that user. Support said that
  they just check device.name

  *Returns*
  +boolean+ true if device belongs to provider, othervise false
=end
  def belongs_to_provider?
    self.user_id == -1 or self.name =~ /^prov/
  end

=begin
  Set time limit per day option for the device. In database it is saved in seconds but this
  method is expecting minutes tu be passed to it. If negative or none numeric params would be
  passed it will be converted to 0. if float would be passed as param, decimal part would be
  striped.

  *Params*
  +minutes+ integer, time interval in minutes.
=end
  def time_limit_per_day=(minutes)
    minutes = (minutes.to_i < 0) ? 0 : minutes.to_i
    seconds = minutes * 60
    write_attribute(:time_limit_per_day, seconds)
  end

  # Get time limit per day expressed in minutes. In database it is saves in seconds, sho we just
  # convert to minutes by deviding by 60. Obviuosly this is OOD mistake, we should use so sort of
  # 'time interval' instance..

  # +minutes+ integer, time interval in minutes
  def time_limit_per_day
    (read_attribute(:time_limit_per_day) / 60).to_i
  end

  def is_dahdi?
    return dahdi?
  end

  def create_server_devices(servers)
    if servers
      servers_amount = []
      servers.each { |serv|
        first_server = serv[0].to_i
        server_dev = ServerDevice.where("server_id = #{first_server} AND device_id = #{id}").first
        if not server_dev
          server_device = ServerDevice.new({:server_id => first_server, :device_id => id})
          server_device.save
        end
        servers_amount << first_server
      }
      ActiveRecord::Base.connection.execute("DELETE FROM server_devices WHERE device_id = '#{id}' AND server_id NOT IN (#{servers_amount.join(',')})")
    end
  end

  def reassign_device_relation(type = :asterisk)
    ServerDevice.delete_all(device_id: id)

    servers = Server.where(server_type: type).all
    servers.each do |server|
      ServerDevice.create(server_id: server.id, device_id: id)
    end

    if type == :sip_proxy
      self.update_attribute(:server_id, servers.first.try(:id).to_i)
    end
  end

  def ast18
    # tweaks for Asterisk 1.8
    self.auth = "md5" if self.device_type.upcase == "IAX2"
  end

  # this method just cleans server from device
  # used in device_update action
  # only when device name or server_id changes
  def sip_prune_realtime_peer(device_name, device_server_id)
    return if self.device_type != "SIP"

    server = Server.find_by(id: device_server_id.to_s)
    if server and server.active == 1
      begin
        rami_server = Rami::Server.new({'host' => server.server_ip, 'username' => server.ami_username, 'secret' => server.ami_secret})
        rami_server.console = 1
        rami_server.event_cache = 100
        rami_server.run
        client = Rami::Client.new(rami_server)
        client.set_timeout(3)

        tmp = client.command("sip prune realtime peer " + device_name.to_s)

        client.respond_to?(:stop) ? client.stop : false
      rescue SystemExit
        MorLog.my_debug('Rami tried connecting to Asterisk but failed.')
        return false
      end
    end
  end

  def self.validate_ip_address_format(params, device, device_update_errors, prov, api = 0)
    #Somehow someone decided that pass provider as parameter and name it device is a good idea.
    #Don't be fooled device - it's not provider device, it's just provider, in case it's called from providers controller.

    #If device uses ip authentication it cannot be dynamic and valid host must be specified

    if params[:ip_authentication].to_i == 1
      ip = params[:host].to_s.strip
      port = params[:port].to_s.strip

      # define ip address type
      ip_address_format = Device.define_ip_address_format(ip)
      # validating single IP address
      if (ip_address_format == 1) && (ip.blank? || !ip.match(/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/))
        device.errors.add(:ip_authentication_error, _('must_specify_proper_host_if_ip_single_format'))
        device_update_errors += 1
      end

      # validating IP address mask (prefix must be in range [24-32])
      if ip_address_format == 2
        if !(24..32).member?(ip[-2,2].to_i)
          device.errors.add(:ip_authentication_error, _('ip_prefix_size_should_be_between_24_and_32'))
          device_update_errors += 1
        end
      end

      # validating IP address range (xxx.xxx.xxx.xxx-yyy, xxx<yyy, xxx in range [0-254], yyy in range [0-255])
      if ip_address_format == 3
        ip_range = ip.split('.').last.split('-')
        range_start = ip_range.first.to_i
        range_end = ip_range.last.to_i

        if ( !(0..254).member?(range_start)) || ( !(1..255).member?(range_end)) || (range_start >= range_end)
          device.errors.add(:ip_authentication_error, _('must_specify_proper_host_if_ip_range_format'))
          device_update_errors += 1
        end
      end

      unless ip == ''
        if ip.split('.').all? {|member| member == '0'}
            device.errors.add(:ip_authentication_error, _('Invalid_IP_address'))
             device_update_errors += 1
        end
      end

      if api == 0
        if params[:zero_port].to_i != 1
          if prov.to_i !=1
            # Should only validate Devices, not providers
            begin
              port = Integer(port) # If string is invalid integer representation, exception is raised
              raise ArgumentError if port <= 0
            rescue ArgumentError
              device.errors.add(:ip_authentication_error, _('Port_format_invalid'))
              device_update_errors += 1
            end
          else
            if port.blank? || port.to_s.strip == '0'
              device.errors.add(:ip_authentication_error, _('Provider_port_is_not_valid'))
              device_update_errors += 1
            end
          end
        else
          device.port = 0
        end
      end

      unless Application.allow_duplicate_ip_port?
        # Validating IP uniquesness, IP + Port should be unique in system
        if port.present?
          condition = 'host = ? AND port = ? AND id != ?'
          self_id = device.id
          if params[:controller] == 'providers'
            condition << ' AND user_id != -1 '
            self_id = device.try(:device).try(:id)
          end

          dupl = where(condition, ip, params[:port], self_id).first
          if dupl
           unless dupl.user_id == -1 && Provider.where(device_id: dupl.id).blank?
            message = "#{_('Device_ip_auth_not_unique')}. "
            user_id = dupl.user_id
            device_id = dupl.id
            curr_user = User.current
            curr_usertype = curr_user.usertype
            # If used by provider

            if user_id == -1
              device_prov = Provider.find_by device_id: device_id
              owner = User.find(device_prov.user_id)
              owner_id = owner.id
              device_nice_name = "#{device_prov.name}"
              link = "<a href='#{Web_Dir}/providers/edit/#{device_prov.id}'>"\
                "#{device_nice_name}</a>"
            # If user by device
            else
              owner = User.find(user_id).owner
              owner_id = owner.id
              device_prov = Device.find(device_id)
              device_nice_name = "#{device_prov.device_type}/"\
                "#{device_prov.extension}"
              link = "<a href='#{Web_Dir}/devices/device_edit/#{device_id}'>"\
                "#{device_nice_name}</a>"
            end
            is_admin = curr_usertype == 'admin'
            # If current user owns a device/provider
            if curr_user.id == owner_id
              if is_admin || owner.can_own_providers?
                message << "#{_('Device_ip_used_by_device_provider')}: "
              else
                message << "#{_('Device_ip_used_by_device')}: "
              end
              message << link
            # If current user doesn not own  but is an admin
            elsif is_admin
              message << "#{_('Device_ip_used_by_user')}: "
              owner_first_name = owner.first_name
              owner_last_name = owner.last_name
              if owner_first_name != '' && owner_last_name != ''
                nice_username = "#{owner_first_name} #{owner_last_name}"
              else
                nice_username = "#{owner.username}"
              end
              message << "<a href='#{Web_Dir}/users/edit/#{owner_id}'>"\
                "#{nice_username}</a>"
              message << " #{_('Device_provider')}: #{device_nice_name}."
            # If current user is a simple reseller
            else
              message << "#{_('Device_ip_used_by_other_user')}."
            end
            message << " <a id='exception_info_link' href='http://wiki."\
              "kolmisoft.com/index.php/Authentication' target='_blank'><"\
              "img alt='Help' src='#{Web_Dir}/images/icons/help.png'"\
              "title='#{_('Help')}' /></a>"

            device.errors.add(
              :ip_authentication_error,
              message)
            device_update_errors += 1
          end
         end
        end
      end
    end

    return device, device_update_errors
  end

  def self.define_ip_address_format(ip)
    ip_address_format = 1
    ip_address_format = 2 if ip.match(/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[0-9]{1,2}$/)
    ip_address_format = 3 if ip.match(/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\-[0-9]{1,3}$/)

    return ip_address_format
  end

  def adjust_insecurities(ccl_active, params, switched_auth = false)
    if ccl_active
      self.insecure = sip? ? 'port,invite' : 'no'
    else
      insecurities = []
      insecurities << 'port' if params[:insecure_port]
      insecurities << 'invite' if params[:insecure_invite]
      insecurities << 'no' if insecurities.blank?

      self.insecure = insecurities.join(',')
    end
  end

  def ipauth_insecurities_on_create
    if name.include?('ipauth') && sip?
      self.insecure = 'port,invite'
    end
  end

  def validate_outbound_proxy
    self.outboundproxy = nil if self.outboundproxy.to_s.strip == ''
  end

  def set_server(device, ccl_active, sip_proxy_server, reseller)
    if ccl_active && sip?
      device.server = sip_proxy_server
    elsif reseller
      first_srv = Server.first.id
      def_asterisk = Confline.get_value('Resellers_server_id').to_i
      def_asterisk = first_srv if def_asterisk.to_i == 0
      device.server_id = def_asterisk
    end
  end

  def set_ports(params_port)
    device_type = self.device_type

    unless (Device.valid_port? self.port, device_type)
      self.port = case device_type
                    when 'IAX2'
                      4569
                    when 'SIP'
                      5060
                    end
    end

    self.port = 1720 if h323? && !(Device.valid_port? params_port, device_type)
    self.proxy_port = self.port
  end

  def create_server_relations(device, sip_proxy_server, ccl_active)
    # if device type = SIP and device host = dynamic and ccl_active = 1 it must be assigned to sip_proxy server
    device_id, server_id, device_type = [self.id, self.server_id, self.device_type]
    serv_dev = ServerDevice.where("server_id = ? AND device_id = ?", server_id, device_id).first

    if sip? && sip_proxy_server && ccl_active
      unless serv_dev
        server_device = ServerDevice.new_relation(sip_proxy_server.id, device_id)
        server_device.save
      end
    elsif (ccl_active && device_type == 'Virtual') || device_type == 'FAX'
      Device.server_device_relations(device)
    else
      unless serv_dev
        server_device = ServerDevice.new_relation(server_id, device_id)
        server_device.save
      end
    end
  end

  def virtual?
    device_type == 'Virtual'
  end

  def self.server_device_relations(device)
    asterisk_servers = Server.where(server_type: 'asterisk').pluck(:id)
    asterisk_servers.each do |server_id|
      unless ServerDevice.where(server_id: server_id, device_id: device.id).first
        server_device = ServerDevice.new_relation(server_id, device.id)
        server_device.save
      end
    end
  end

  def self.available_ids(condition)
    self.connection.select_all("SELECT devices.id FROM devices WHERE #{condition}").to_a.map{|record| record["id"] }.join(', ')
  end

  def update_extline_appdata(new_extension, old_extension)
    # updates device ringgroups extlines appdata
    extensions = RinggroupsDevice.select('distinct dialplans.data2').joins("left join devices on device_id = devices.id").
                      joins("left join users on users.id = devices.user_id").
                      joins("left join dialplans on dialplans.data1 = ringgroup_id").
                      where("devices.id = #{self.id} AND dialplans.dptype = 'ringgroup'").all.pluck(:data2)
    extensions.each do |extension|
      appdata = Extline.where("exten = '#{extension}' AND app = 'Dial'").first.appdata
      appdata = appdata.split('&').map! do |data|
        device_extension = data[/\/\d+@/]
        if device_extension.present?
          device_extension = device_extension[1, device_extension.length - 2]
          pool = data[/@\S*mor_local/]
          pool_id = pool == '@mor_local' ? 1 : pool[/\d+/]
          device_pool_id = self.user.pbx_pool_id == 0 ? 1 : self.user.pbx_pool_id
          if device_extension == old_extension && pool_id.to_i == device_pool_id.to_i
            data.gsub!(/\/\S+@/, "/#{new_extension}@")
          end
          data
        else
          # appdata is old format which calls for ringgroup.update_exline
          ringgroups = Ringgroup.joins('LEFT JOIN ringgroups_devices ON ringgroups_devices.ringgroup_id = ringgroups.id').
                    joins('JOIN devices on devices.id = ringgroups_devices.device_id').
                    where("devices.id = #{self.id}").all
          ringgroups.each do |ringgroup|
            ringgroup.update_exline
          end
          return false
        end
      end
      appdata = appdata.join('&')
      Extline.where(exten: extension).update_all(appdata: appdata)
    end
  end

  # Send email device_changes_announcement for Device User Owner and Responsible Accountant
  def send_email_device_changes_announcement
    device_user = user
    user_owner, user_resp_acc = device_user.owner, device_user.responsible_accountant
    user_owner_id = user_owner.id
    inform_device_create_update = Confline.get_value('Inform_when_Devices_are_created_or_updated', user_owner_id).to_i

    if inform_device_create_update == 1
      MorLog.my_debug('Sending email - device_changes_announcement')
      MorLog.my_debug("Device - id: #{id}, owner username: #{device_user.username}")

      email_template = Email.where(name: 'device_changes_announcement', owner_id: user_owner_id).first
      email_from = Confline.get_value('Email_from', user_owner_id).to_s
      variables = Email.email_variables(device_user, self)

      email_status = send_device_changes_announcement(email_template, email_from, user_owner, variables)
      MorLog.my_debug('Device User Owner send status:')
      MorLog.my_debug(email_status)

      if user_resp_acc.present?
        email_status = send_device_changes_announcement(email_template, email_from, user_resp_acc, variables)
        MorLog.my_debug('Device User Responsible Accountant send status:')
        MorLog.my_debug(email_status)
      end
    end
  end

  def nice_device
    nice_dev = ''

    if self.user_id == -1
      provider = Provider.where(device_id: self.id).first
      nice_dev = provider.tech.to_s
      nice_dev <<  '/' + provider.name.to_s if provider.name and !nice_dev.include?(provider.name.to_s)
    else
      nice_dev = self.device_type.to_s
      nice_dev <<  '/' + self.name.to_s if self.name and !nice_dev.include?(self.name.to_s)
    end

    nice_dev
  end

  def blocked_ip_status
    BlockedIP.check_if_blocked(ipaddr)
  end

  def self.system_stats
    response = {
        total: self.count,
        types: Devicetype.pluck(:name),
        fax: self.where(device_type: 'FAX').count
    }

    response[:types].each do |type|
      response[type.to_sym] = self.where(device_type: type).count
    end

    response
  end

  def self.system_stats_for_acc(current_user_id)
   users =  User.where(usertype: ['user', 'reseller']).where(responsible_accountant_id: current_user_id).pluck(:id)
   users = User.responsible_accountant_users(current_user_id).pluck(:id)
    response = {
        total: self.where(user_id: users).count,
        types: Devicetype.pluck(:name),
        fax: self.where(device_type: 'FAX', user_id: users).count
    }

    response[:types].each do |type|
      response[type.to_sym] = self.where(device_type: type, user_id: users).count
    end

    response
  end

  def self.new_free_extension
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

    return (((range_min..range_max).to_a - taken_extensions_array).first || range_max).to_s
  end

  def adjust_for_api(device_type)
    self.port = DefaultPort[device_type] if port == 0
    self.fromuser = nil if fromuser.blank?
    self.fromdomain = nil if fromdomain.blank?
    self.insecure = 'no' if insecure.blank?
    self.description ||= self.comment || ''
    self.use_ani_for_cli = 0 if use_ani_for_cli.blank?
    self.forward_did_id = -1 if forward_did_id == 0
    self.subscribemwi = 'no' if subscribemwi.blank?
    self.encryption = 'no' if encryption.blank?

    server_device = ServerDevice.find_by(server_id: server_id, device_id: id)
    ServerDevice.new_relation(server_id, id).save unless server_device.present?

    save
  end

  def can_change_dynamic_info?
    (iax2? || sip?) && host.to_s == 'dynamic' && !self.provider && !self.server_device?
  end

  def device_password_valid?(password)
    device_pass = password.to_s
    !username.blank? && device_pass != name.to_s &&
      !(device_pass.length < 8 &&
    Confline.get_value('Allow_short_passwords_in_devices').to_i == 0)
  end

  def device_name_valid?(device_name)
    !%w(anonymous unknown).include?(device_name.downcase) &&
      device_name != secret.to_s &&
      !(Confline.get_value('Disalow_Duplicate_Device_Usernames', 0).to_i == 1 &&
    Device.where(name: device_name).first.present?)
  end

  private

  def send_device_changes_announcement(email, email_from, user, variables)
    user_id = user.usertype == 'accountant' ? 0 : user.id
    status = _('email_not_sent')

    if Confline.get_value('Email_Sending_Enabled', 0).to_i == 1
      smtp_server = Confline.get_value('Email_Smtp_Server', user_id).to_s.strip
      smtp_user = Confline.get_value('Email_Login', user_id).to_s.strip
      smtp_pass = Confline.get_value('Email_Password', user_id).to_s.strip
      smtp_port = Confline.get_value('Email_Port', user_id).to_s.strip

      smtp_connection =  "'#{smtp_server}:#{smtp_port}'"
      smtp_connection << " -xu '#{smtp_user}' -xp '#{smtp_pass}'" if smtp_user.present?

      to = user.try(:email)
      email_body = EmailsController::nice_email_sent(email, variables)

      begin
        if user.not_blocked_and_in_group
          system_call = ApplicationController::send_email_dry(email_from.to_s, to.to_s, email_body, email.subject.to_s, '', smtp_connection, email[:format])
          unless (defined?(NO_EMAIL) && (NO_EMAIL.to_i == 1))
            status = _('Email_sent') if system("#{system_call} &")
          end
        end
      rescue
        return status
      end
    else
      status = _('Email_disabled')
    end

    status
  end

  # Note INSERT IGNORE INTO, thats because voicemail boxes should have unique constraint set, so if
  # one tries to insert duplicate record, no exception would be risen and INSERT stetement would be ignored
  def create_vm(mailbox, pass, fullname, email, remove)
    vm = (self.voicemail_box.blank? ? VoicemailBox.new : self.voicemail_box)
    vm.device_id = self.id
    vm.mailbox = mailbox
    vm.password = pass
    vm.callback = ''
    vm.dialout = ''
    vm.pager = ''
    fullname = fullname.gsub("'", '')
    vm.context = 'default'
    if email
      vm.email = email
    else
      vm.email = Confline.get_value('Company_Email')
    end
    #vm.save

    if self.voicemail_box.blank?
      sql = "INSERT IGNORE INTO voicemail_boxes (device_id, mailbox, password, fullname, context, email, pager, dialout, callback, `delete`) VALUES ('#{self.id}', '#{mailbox}', '#{pass}', '#{fullname}', 'default', '#{vm.email}', '', '', '', '#{remove}');"
      res = ActiveRecord::Base.connection.insert(sql)
    end
    vm = VoicemailBox.where("device_id = '#{self.id}' AND fullname = '#{fullname}' AND email = '#{vm.email}'").first

    vm
  end

  # ticket #5133
  def cid_number=(value)
    @cid_number = value
  end

  def Device.integrity_recheck_devices
    ccl_active = Confline.get_value('CCL_Active').to_i
    Device.where("(insecure = 'port,invite' OR insecure = 'port' OR insecure = 'invite') AND host = 'dynamic' AND device_type = 'SIP'").count > 0 and ccl_active == 0 ? 1 : 0
  end

  def t38pt_normalize
    if ['fec', 'redundancy', 'none'].include? self.t38pt_udptl
        self.t38pt_udptl = 'yes,' << self.t38pt_udptl
    end
  end

  def nice_provider(provider)
    nice_dev = ''
    nice_dev = provider.tech.to_s
    nice_dev <<  '/' + provider.name.to_s if provider.name and !nice_dev.include?(provider.name.to_s)
    nice_dev
  end

  def nice_device_user(device)
    if device.user_id == -1
      device = Provider.where(device_id: device.id).first
    end
    device_user = User.where(id: device.user_id).first
    return unless device_user.present?
    device_user = device_user.owner if device_user.owner_id.to_i != 0
    dev_user = device_user.username.to_s
    dev_user = device_user.first_name.to_s + " " + device_user.last_name.to_s if device_user.first_name.to_s.length + device_user.last_name.to_s.length > 0
    dev_user
  end

  def extension_is_unique?(ext)
    extension_in_extlines = Extline.select(:exten).where(exten: ext).first
    extension_in_devices = Device.select(:extension).where(extension: ext).first
    extension_in_queues = AstQueue.select(:extension).where(extension: ext).first

    if extension_in_extlines || extension_in_devices || extension_in_queues
      errors.add(:extension, _('Such_extension_exists'))
    end

    return errors.size.zero?
  end

  def admin?
    User.current.try(:usertype) == 'admin'
  end

  def fax?
    device_type == 'FAX'
  end

  def sip?
    device_type == "SIP"
  end

  def h323?
    device_type == 'H323'
  end

  def iax2?
    device_type == 'IAX2'
  end

  def dahdi?
    device_type == 'dahdi'
  end

  def self.find_istrunk_and_ani(trunk)
    case trunk
    when 1
      [1, 0]
    when 2
      [1, 1]
    else
      [0, 0]
    end
  end

  def check_device_range
    free_extensions = DeviceFreeExtension.free_extensions
    filter_active = Confline.get_value('Disalow_Duplicate_Device_Usernames', 0).to_i == 1

    if free_extensions.blank? && filter_active
      errors.add(:username, _('There_are_no_more_free_names'))
      return false
    end
  end
end
