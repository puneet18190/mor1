# -*- encoding : utf-8 -*-
class User < ActiveRecord::Base

  include SqlExport
  include UniversalHelpers
  include UtilityHelper
  include ElasticsearchQueries
  require 'digest/sha2'
  require 'uri'
  require 'net/http'

  attr_protected

  cattr_accessor :current
  cattr_accessor :current_user

  cattr_accessor :system_time_offset
  scope :first_owned_by, ->(id, owner_id) { where(id: id, owner_id: owner_id).first }

  has_many :devices, -> { includes([:user, :provider]).where("devices.accountcode != 0 and devices.name not like 'mor_server_%'") }
  has_many :sip_devices, -> { where("devices.accountcode != 0 and devices.name not like 'mor_server_%' AND device_type = 'SIP'") }, class_name: 'Device' , foreign_key: 'user_id'
  has_many :actions
  belongs_to :lcr
  belongs_to :tariff
  belongs_to :sms_lcr
  has_many :lcrs
  has_many :phonebooks
  belongs_to :address
  has_many :devicegroups, -> { order(:added) }
  has_many :subscriptions, -> { order(:added) }
  has_many :payments, -> { where('card = 0').order('card = 0') }
  has_many :campaigns, -> { order(:name) }
  has_many :sms_campaigns, -> { order(:name) }
  has_many :invoices, -> { order(:period_start) }
  has_many :customrates
  has_many :vouchers
  #has_many :emails
  has_many :dids
  has_many :usergroups, dependent: :destroy
  belongs_to :tax, dependent: :destroy
  belongs_to :acc_group
  has_many :groups
  has_many :usergroups
  has_many :cs_invoices, -> { where(["state = 'unpaid'"]) }
  has_many :all_cs_invoices, class_name: 'CsInvoice'
  #has_and_belongs_to_many :callshops, :join_table => "usergroups", :association_foreign_key => "group_id"
  has_many :callshops, through: :usergroups, foreign_key: 'group_id', source: :group

  has_many :providers, dependent: :destroy
  has_many :terminators, dependent: :destroy
  has_many :user_translations, -> { order('user_translations.position ASC') }, dependent: :destroy
  has_many :dialplans, dependent: :destroy
  has_many :pbxfunctions, dependent: :destroy
  belongs_to :currency
  belongs_to :quickforwards_rule
  has_many :quickforwards_rules, -> { order(:name) }
  has_many :locations, -> { order(:name) }
  # warning balance sound
  has_one :ivr_sound_file, foreign_key: 'warning_balance_sound_file_id'
  has_many :ivrs
  has_many :ivr_timeperiods
  has_many :ivr_voices
  has_many :ivr_sound_files
  has_many :cron_settings
  has_many :ringgroups, -> { includes([:dialplan, :did]) }
  has_many :common_use_providers
  has_many :cards
  has_many :sms_tariffs, -> { where(purpose: 'user_wholesale').order('name ASC') }, class_name: 'Tariff', foreign_key: :owner_id
  has_many :sms_provider_tariffs, -> { where(purpose: 'provider').order('name ASC') }, class_name: 'Tariff', foreign_key: :owner_id
  has_many :quickforwarddids
  belongs_to :sms_tariff, class_name: 'Tariff', foreign_key: :sms_tariff_id
  belongs_to :owner, class_name: 'User', foreign_key: 'owner_id'
  belongs_to :responsible_accountant, class_name: 'User', foreign_key: 'responsible_accountant_id'
  belongs_to :pbx_pool
  has_many :owned_tariffs, class_name: 'Tariff', foreign_key: 'owner_id'
  belongs_to :simple_user_group, foreign_key: :simple_user_group_id

  validates_uniqueness_of :username, message: _('Username_has_already_been_taken')
  validates_presence_of :username, message: _('Username_cannot_be_blank')
  #validates :balance_min, :numericality => {:message => _('Minimal_balance_numerical'), :allow_blank => true}
  #validates :balance_max, :numericality => {:message => _('Maximal_balance_numerical'), :allow_blank => true}
  #validates_presence_of :first_name, :last_name

  before_save :user_before_save
  before_save :check_min_max_balance
  before_create :user_before_create
  before_create :new_user_balance, if: lambda {|user| not user.registration }

  after_create :after_create_localization, :after_create_user, :create_balance_payment, :partner_set_default_group
  after_save :after_create_localization, :check_address

  scope :find_by_email, ->(email, owner_id = 0) { where("addresses.email = '#{email}' AND users.owner_id = #{owner_id}").joins('LEFT JOIN addresses ON addresses.id = users.address_id') }

  attr_accessor :imported_user, :registration

  M2_EMAILS = [:main_email, :noc_email, :billing_email, :rates_email]

  def after_create_localization
    #uses resellers id
    if is_reseller?
      locations = Location.where("user_id = #{id} AND name = 'Default location'").first

      if locations.blank?
        #create new default location  if reseller has no localization
        create_reseller_localization
      else
        #if reseller has localization but default location id = 1, it means he has no new default location. lets create it
        value = Confline.get_value('Default_device_location_id', id)

        if locations.id != value.to_i and (!value.blank? or value != 1)
          Confline.set_value('Default_device_location_id', locations.id, id) if value.to_i == 1
        elsif value.blank? or value.to_i == 1
          create_reseller_localization
        end
      end
      create_reseller_conflines
      create_reseller_emails

    end
  end

  def after_create_user
    devgroup = Devicegroup.new
    devgroup.init_primary(id, 'primary', address_id)
    Action.add_action_hash(
      (User.current.try(:id) || self.get_correct_owner_id),
      {target_id: id, target_type: 'user', action: 'user_created'}
      )

    if is_reseller?
      create_reseller_inv_page_limit
    elsif is_partner?
      create_partner_conflines
      create_reseller_CSV_params
      create_invoice_xlsx_conflines
    end
  end

  def create_reseller_inv_page_limit
    %w[Invoice_page_limit Prepaid_Invoice_page_limit].each { |name| Confline.set_value(name, 20, id) }
  end

  def check_address
    unless address
      a = Address.create()
      self.address_id = a.id
      self.save
    end
  end

  def create_balance_payment
    if self.balance.to_d != 0.to_d
      payment = Payment.create_for_user(self, { description: 'balance on user creation',
        paymenttype: 'initial balance',
        currency: Currency.get_default.name,
        amount: read_attribute(:balance).to_d })
      payment.save
    end
  end

  def partner_set_default_group
    (self.partner_group_id = 1) and (self.save) if is_partner? && (self.partner_group_id == 0)
  end

  def create_reseller_localization
    #uses resellers id
    loc = Location.new(name: 'Default location', user_id: id)
    loc.user_id = id
    loc.save
    #delete confline if exists device with location id = 1 and replace with new location id
    Confline.delete_all("owner_id = #{id} and name = 'Default_device_location_id'")
    Confline.new_confline('Default_device_location_id', loc.id, id)
    all_default_rules = Locationrule.where('location_id = 1').all

    all_default_rules.each do |default_rules|
      rule = Locationrule.new({ name: default_rules.name, enabled: 1, lr_type: default_rules.lr_type })
      rule.location_id = loc.id
      rule.cut = default_rules.cut if default_rules.cut
      rule.add = default_rules.add if default_rules.add
      rule.minlen = default_rules.minlen if !default_rules.minlen.blank?
      rule.maxlen = default_rules.maxlen if !default_rules.maxlen.blank?
      rule.save
    end
    #and update devices
    update_resellers_device_location(loc.id)
  end

  # Uses new default location id and resellers id
  def update_resellers_device_location(locationid)
    ActiveRecord::Base.connection.execute("
      UPDATE devices JOIN users ON (devices.user_id = users.id AND users.owner_id = #{id})
      SET location_id = #{locationid.to_i} WHERE location_id = 1
    ")
    ActiveRecord::Base.connection.execute("
      UPDATE devices JOIN providers ON (devices.id = providers.device_id AND providers.user_id = #{id})
      SET location_id = #{locationid.to_i} WHERE location_id = 1
    ")
    update_resellers_cardgroup_location(locationid)
  end

  def update_resellers_cardgroup_location(locationid)
    #uses new default location id and resellers id
    Cardgroup.where("owner_id = #{id} and location_id = 1").update_all("location_id = #{locationid}")
  end

  def user_before_save
    if recordings_email.to_s.length > 0 && !Email.address_validation(recordings_email)
      errors.add(:email, _('Please_enter_correct_recordings_email'))
      return false
    end

    if warning_balance_email
      if warning_balance_email.to_s.length > 0 && !Email.address_validation(warning_balance_email)
        errors.add(:email, _('Please_enter_correct_warning_balance_email'))
        return false
      end


      dublicate, dublicate_email = no_dublicate_warning_emails(warning_balance_email)
      unless dublicate
        errors.add(:email, _('email_space') + dublicate_email + _('Is_already_used'))
        return false
      end


    end

    if usertype.to_s != 'reseller'
      own_providers = 0
    end
    #only admin's user can have responsible_accountant_id set to some other value than -1
    #invalid_value = (responsible_accountant_id != -1 and (not is_user? or owner_id != 0))
    if self.try(:responsible_accountant_id).to_i != -1 && !User.where(usertype: 'accountant', hidden: 0, id: self.try(:responsible_accountant_id).to_i).first
      errors.add(:email, _('Responsible_accountant_is_invalid'))
      return false
    end

    self.uniquehash = ApplicationController::random_password(10) if self.uniquehash.to_s.blank?
  end

  def self.default_blacklist_params(params)
    if params[:routing_threshold].to_i == -2
      params[:routing_threshold] = params[:routing_threshold_2] = params[:routing_threshold_3] = -1
    else
      params[:routing_threshold] = params[:routing_threshold].to_i
      params[:routing_threshold_2] = params[:routing_threshold_2].to_i
      params[:routing_threshold_3] = params[:routing_threshold_3].to_i
    end

    if params[:blacklist_lcr].to_i == -2
      params[:blacklist_lcr] = params[:blacklist_lcr_2] = params[:blacklist_lcr_3] = -1
    end

    params
  end


  def user_before_create
    if password == Digest::SHA1.hexdigest('')
      errors.add(:password, _('Please_enter_password'))
      return false
    end

    if password == Digest::SHA1.hexdigest(username) and !self.imported_user
      errors.add(:password, _('Please_enter_password_not_equal_to_username'))
      return false
    end
  end

  def default_translation
    if is_admin? or is_reseller?
      trans = user_translations.includes([:translation]).where('user_translations.active = 1').
        order('user_translations.position ASC').first

      if trans
        trans.translation
      else
        owner.default_translation
      end
    else
      owner.default_translation
    end
  end

  def active_translations
    if is_admin? or is_reseller?
      trans = user_translations.includes([:translation]).where('user_translations.active = 1').
        order('user_translations.position ASC').all

      unless trans and trans.size != 0
        owner.active_translations
      else
        trans.collect(&:translation)
      end
    else
      owner.active_translations
    end
  end

  def all_translations
    if is_admin? or is_reseller?
      trans = user_translations.includes([:translation]).all

      unless trans and trans.size != 0
        owner.active_translations.collect(&:translation)
      else
        trans.collect(&:translation)
      end
    else
      owner.active_translations.collect(&:translation)
    end
  end

  def load_user_translations
    ut = user_translations

    unless ut and ut.size != 0
      clone_owner_translations
      return user_translations(true)
    end

    ut
  end

  def clone_owner_translations
    UserTranslation.where(user_id: owner_id).all.each do |ut|
      UserTranslation.create(user_id: id, translation_id: ut.translation_id, position: ut.position, active: ut.active)
    end
  end

  def hide_destination_end
    if attributes['hide_destination_end'] == -1
      Confline.get_value('Hide_Destination_End', owner_id).to_i
    else
      attributes['hide_destination_end']
    end
  end
=begin
  Check whether user is admin type, only one user can be system admin,
  valid admin user has to got id = 0 and his usertype has to be set to 'admin'

  *Returns*
  +boolean+ - true if user is admin, otherwise false
=end
  def is_admin?
    usertype == 'admin' and id == 0
  end

  def is_accountant?
    usertype == 'accountant'
  end

  def is_reseller?
    usertype == 'reseller'
  end

  def is_partner?
    usertype == 'partner'
  end

  def is_user?
    usertype == 'user'
  end

  def is_partners_reseller?
    is_reseller? && owner.usertype == 'partner'
  end

  def fax_devices
    Device.where("user_id = #{id} AND device_type = 'FAX' AND name not like 'mor_server_%'").all
  end

  def reseller_users(reseller_active = false, reseller_pro_active = false)
    if (own_providers == 0 && !reseller_active || (own_providers == 1 && !reseller_pro_active))
      User.where(owner_id: id).limit(2)
    else
      User.select("*, #{SqlExport.nice_user_sql}").where("owner_id = #{id}").order('nice_user ASC').all
    end
  end

  def all_calls
    Call.where(user_id: id)
  end

  def calls_or_calls_in_aggregates_present
    Call.where(user_id: id).present? || OldCall.where(user_id: id).present? || Aggregate.where(user_id: id).present?
  end

  def groups
    Group.find_by_sql ["SELECT groups.* FROM groups, usergroups WHERE groups.id = usergroups.group_id AND usergroups.user_id = ? ORDER BY groups.name ASC", id]
  end

  def calls(type, date_from, date_till, direction = 'outgoing', order_by = 'calldate', order = 'DESC', device = nil, options = {})
    calls = []
    # ------ handle call type --------
    call_type_sql = " AND disposition = '#{type}' "

    if type == 'all'
      call_type_sql = ''
    end
    # special case
    if type[0..5] == 'missed'
      call_type_sql = ' AND disposition != \'ANSWERED\''

      if type[7..19] == 'not_processed'
        call_type_sql += ' AND processed = 0 '
      end
    end

    # ---------- handle device ---------
    incoming_direction = direction == 'incoming'
    device_sql = ''

    if device
      device_sql = incoming_direction ? " AND dst_device_id = #{device.id} " : " AND src_device_id = #{device.id} "
    end

    # ---------- handle Hangupcausecode ---------
    hgc_sql= options[:hgc] ? " AND calls.hangupcause = #{options[:hgc].code} " : ''

    # -------- handle resellers ---------
    reseller_sql = ''

    find = ['calls.*']
    find << "DATE_FORMAT(calldate, \"%Y-%m-%d %H:%i:%S\") as `formated_calldate`" if options[:format_calldate]
    from = []

    if options[:providers] == true
      find << 'providers.name as \'provider_name\''
      from << 'LEFT JOIN providers ON (providers.id = calls.provider_id)'
    end

    if options[:destinations] == true
      find << 'destinations.name AS \'destination_name\''
      find << 'directions.name AS \'direction_name\''

      from << 'LEFT JOIN destinations ON (destinations.prefix = calls.prefix)'
      from << 'LEFT JOIN directions ON (directions.code = destinations.direction_code)'
    end

    if options[:count] == true
      find = ['COUNT(*) AS \'total_count\'']
    end
    # -------- retrieve calls -----------
    sql = "SELECT #{ find.join(',') } FROM calls #{from.join(' ')} "

    if incoming_direction #incoming calls
      sql += "JOIN devices ON (devices.id = calls.dst_device_id) LEFT JOIN dids ON (calls.did_id = dids.id) WHERE (calls.card_id = 0 AND (((devices.user_id = #{id}) OR (dids.user_id = #{id})) #{reseller_sql} )#{call_type_sql} #{device_sql} #{hgc_sql} AND ((calldate BETWEEN '#{date_from.to_s}' AND '#{date_till.to_s}')))  ORDER BY #{order_by} #{order} #{ 'LIMIT ' + options[:offset].to_s + ', ' + options[:limit].to_s if (options[:limit] and options[:offset])};"
    else # outgoing calls
      sql += "WHERE (calls.card_id = 0 AND (calls.user_id = #{id} #{reseller_sql}) #{call_type_sql} #{device_sql} #{hgc_sql} AND ((calldate BETWEEN '#{date_from.to_s}' AND '#{date_till.to_s}'))) ORDER BY #{order_by} #{order} #{ 'LIMIT ' + options[:offset].to_s + ', ' + options[:limit].to_s if (options[:limit] and options[:offset]) };"
    end

    Call.find_by_sql(sql)
  end

  # Similar to @user.calls. Instead it returns total number of calls and sum of basic calls params.
  def calls_total_stats(type, date_from, date_till, direction = 'outgoing', device = nil, usertype = 'user', hgc =nil)
    calls = []

    # ------ handle call type --------
    call_type_sql = " AND disposition = '#{type}' "
    call_type_sql = '' if type == 'all'

    # special case
    if type[0..5] == 'missed'
      call_type_sql = " AND disposition != 'ANSWERED'"

      if type[7..19] == 'not_processed'
        call_type_sql += ' AND processed = 0 '
      end
    end

    # ---------- handle device ---------
    device_sql = ''
    if device
      if direction == 'incoming'
        device_sql= " AND dst_device_id = #{device.id} "
      else
        device_sql = " AND src_device_id = #{device.id} "
      end
    end

    # ---------- handle Hangupcausecode ---------
    hgc_sql = hgc ? " AND hangupcause = #{hgc.code} " : ''
    # -------- handle resellers ---------
    reseller_sql = ''

    # -------- retrieve calls -----------
    sql = "SELECT COUNT(*) AS 'total_calls', " +
      "SUM(IF(calls.disposition = 'ANSWERED', 1, 0)) AS 'total_answered_calls', " +
      "SUM(IF(calls.disposition = 'ANSWERED',calls.duration, 0)) AS 'total_duration', " +
      "SUM(IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) )) AS 'total_billsec', " +
      "SUM(IF(calls.user_billsec > 0, calls.user_billsec, CEIL(calls.real_billsec) )) AS 'total_user_billsec', " +
      "SUM(IF(calls.disposition = 'ANSWERED',#{SqlExport.replace_price('calls.user_price')}, 0)) AS 'total_user_price', " +
      "SUM(IF(calls.disposition = 'ANSWERED',#{SqlExport.replace_price('calls.provider_price')}, 0)) AS 'total_provider_price', " +
      "SUM(IF(calls.disposition = 'ANSWERED',#{SqlExport.replace_price('calls.reseller_price')}, 0)) AS 'total_reseller_price', " +
      "SUM(IF(calls.disposition = 'ANSWERED',#{SqlExport.replace_price('calls.did_price')}, 0)) AS 'total_did_price', " +
      "SUM(IF(calls.disposition = 'ANSWERED',#{SqlExport.replace_price('calls.did_prov_price')}, 0)) AS 'total_did_prov_price', " +
      "SUM(IF(calls.disposition = 'ANSWERED',#{SqlExport.replace_price('calls.did_inc_price')}, 0)) AS 'total_did_inc_price' FROM calls "

    if direction == 'incoming'
      #incoming calls
      sql += "JOIN devices ON (devices.id = calls.dst_device_id) LEFT JOIN dids ON (calls.did_id = dids.id) WHERE (calls.card_id = 0 AND (devices.user_id = #{id} OR (dids.user_id = #{id}) )#{call_type_sql} #{device_sql} #{hgc_sql} AND ((calldate BETWEEN '#{date_from.to_s}' AND '#{date_till.to_s}')));"
    else
      # outgoing calls
      sql += "WHERE (calls.card_id = 0 AND (calls.user_id = #{id} #{reseller_sql}) #{call_type_sql} #{device_sql} #{hgc_sql} AND ((calldate BETWEEN '#{date_from.to_s}' AND '#{date_till.to_s}')));"
    end

    calls = Call.find_by_sql(sql)
    calls[0]
  end

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

  def total_calls(type, date_from, date_till)
    t_calls = 0
    for dev in devices
      t_calls += dev.total_calls(type, date_from, date_till)
    end
    t_calls
  end

  def total_duration(type, date_from, date_till)
    t_duration = 0
    devices.each { |dev| t_duration += dev.total_duration(type, date_from, date_till) }

    t_duration
  end

  def total_billsec(type, date_from, date_till)
    t_billsec = 0
    devices.each { |dev| t_billsec += dev.total_billsec(type, date_from, date_till) }

    t_billsec
  end

  def manager_in_groups
    groups = []
    groups.each { |group| groups << group if group.gusertype(self) == 'manager' }

    groups
  end

  def last_login
    Action.where(user_id: id, action: 'login').order('date DESC').first
  end

  def normative_perc(date)
    date_s = date.to_time.to_s(:db)
    date_e = (date.to_time + 23.hour + 59.minute + 59.second).to_s(:db)

    sql = 'SELECT users.id, users.calltime_normative as \'normative\', ' +
      'COUNT(distinct calls.id) as \'calls\', SUM(calls.duration) as \'duration\'' +
      'FROM users join devices on (users.id = devices.user_id AND users.id = '+ id.to_s + ') ' +
      'left join calls on ((calls.src_device_id = devices.id OR calls.dst_device_id = devices.id)' +
      'AND calls.calldate BETWEEN \'' + date_s + '\' AND \'' + date_e + '\') AND disposition = \'ANSWERED\''+
      'GROUP BY users.id, users.calltime_normative'

    res = ActiveRecord::Base.connection.select_all(sql)

    tn = 0

    if res[0]
      tn = (res[0]['duration'].to_d * 100 / (res[0]['normative'].to_d * 3600)) if res[0]['normative'].to_d > 0
    end

    tn.round.to_s
  end

  def new_calls(date)
    calls, test_data = Call.last_calls_csv({:user => self, :from => date.to_s + ' 00:00:00', :till => date.to_s + ' 23:59:59', :call_type => 'answered', :current_user => self, :pdf => 1, :order => 'calldate'})

    calls
  end

  def months_normative(month)
    date_s = month.to_s
    sql = 'SELECT SUM(calls.duration) * 100 / (B.total_days * users.calltime_normative * 3600) AS \'percent\' '+
      'FROM calls join devices ON ((calls.src_device_id = devices.id OR calls.dst_device_id = devices.id) AND ' +
      'devices.user_id = \'' + id.to_s + '\') join users ON (users.id = devices.user_id) join ' +
      '(SELECT COUNT(A.days) AS \'total_days\' ' +
      'FROM (SELECT SUBSTRING(calls.calldate,1,10) AS \'days\' ' +
      'FROM calls join devices ON ((calls.src_device_id = devices.id OR calls.dst_device_id = devices.id) AND devices.user_id = \'' + id.to_s + '\') ' +
      'WHERE calls.calldate BETWEEN \'' + date_s + '-01 00:00:00\' AND \'' + date_s + '-31 23:59:59\' AND calls.disposition = \'ANSWERED\' ' +
      'GROUP BY SUBSTRING(calls.calldate,1,10)) 	AS A ) 	AS B ' +
      'WHERE calls.calldate BETWEEN \'' + date_s + '-01 00:00:00\' AND \'' + date_s + '-31 23:59:59\' AND calls.disposition = \'ANSWERED\' ' +
      ' GROUP BY B.total_days, users.calltime_normative '

    res = ActiveRecord::Base.connection.select_all(sql)
    mn = res[0] ? res[0]['percent'].to_i : 0

    #saving to temporary table
    month_plan_perc = mn
    month_plan_updated = Time.now
    save

    mn.to_i.to_s
  end

  def this_months_normative
    month_plan_perc
  end

  def primary_device_group
    Devicegroup.where("user_id = #{id}").order('added ASC').first
  end

  def destroy_everything
    conflines = Confline.where(["owner_id = '#{id}'"]).all

    conflines.each { |conf| conf.destroy }

    devices.each do |dev|
      if dev.provider
        dev.user_id = -1
        dev.save
      else
        dev.destroy_everything
      end
    end

    devicegroups.destroy_all
    address.destroy if address
    customrates.destroy_all
    destroy
  end

  def email
    address ? address.email.to_s : ''
  end

  def forwards_before_call
    Callflow.find_by_sql("SELECT callflows.* FROM callflows JOIN devices ON (devices.user_id = #{id} AND callflows.device_id = devices.id) WHERE action = 'forward' AND cf_type = 'before_call' AND data2 = 'local';")
  end

  # create conflines to user, if conflines exist they will be set to admin values
  def create_reseller_conflines
    resellers_device_location = Confline.get_value('Default_device_location_id', id)

    if is_reseller? and Confline.get_value('Default_device_type', id).to_s.blank?
      Confline.delete_all("owner_id = #{id} AND name like 'Default_device%'")
      create_reseller_payments
      create_reseller_location_id(resellers_device_location)
      create_reseller_default_device
      create_reseller_CSV_params
      create_reseler_emails
      create_invoice_xlsx_conflines
    end


    if is_partners_reseller?
      create_partners_reseller_various
    end
  end

  def create_partners_reseller_various
    %w[Date_format Logout_link Show_only_main_page Show_forgot_password Show_device_and_cid_in_last_calls].each { |name|
      Confline.new_confline(name, Confline.get_value(name, owner_id), id)
    }
  end

  def create_reseller_payments
    %w[Show_Rates_Without_Tax WebMoney_Enabled].each { |name| Confline.new_confline(name, owner_id, id) }

    %w[Company Company_Email Version Copyright_Title Admin_Browser_Title Logo_Picture Paypal_Default_Currency
      WebMoney_Default_Currency WebMoney_SIM_MODE Paypal_Enabled PayPal_Email PayPal_Default_Amount
      PayPal_Min_Amount PayPal_Test WebMoney_Purse WebMoney_Default_Amount WebMoney_Min_Amount WebMoney_Test].each { |name|
        Confline.new_confline(name, Confline.get_value(name, owner_id), id)
      }
  end

  def create_reseller_location_id(resellers_device_location)
    # set device location id to resellers default location id if exists or use admins Global location id
    device_location_id = resellers_device_location.present? ? resellers_device_location :
      Confline.get_value('Default_device_location_id', owner_id)
    Confline.new_confline('Default_device_location_id', device_location_id, id)
  end

  def create_reseller_default_device
    %w[Default_device_timeout Default_device_record Default_device_call_limit Default_device_nat
      Default_device_voicemail_active Default_device_trustrpid Default_device_sendrpid Default_device_t38pt_udptl
      Default_device_promiscredir Default_device_progressinband Default_device_videosupport
      Default_device_allow_duplicate_calls Default_device_tell_balance Default_device_tell_time
      Default_device_tell_rtime_when_left Default_device_repeat_rtime_every Default_device_permits
      Default_device_qualify Default_device_host Default_device_ipaddr Default_device_port Default_device_regseconds
      Default_device_canreinvite Default_device_istrunk Default_device_ani Default_device_callgroup
      Default_device_pickupgroup Default_device_fromuser Default_device_fromdomain Default_device_insecure
      Default_device_process_sipchaninfo Default_device_voicemail_box_email Default_device_voicemail_box_password
      Default_device_fake_ring Default_device_use_ani_for_cli
      Default_setting_device_caller_id_number Default_device_cid_name Default_device_cid_number
      Default_device_type Default_device_dtmfmode Default_device_works_not_logged].each { |name|
        Confline.new_confline(name, Confline.get_value(name, current_user.try(:is_partner?) ? 0 : owner_id), id)
      }

    Codec.all.each do |codec|
      name = "Default_device_codec_#{codec.name}"
      Confline.new_confline(name, Confline.get_value(name, current_user.try(:is_partner?) ? 0 : owner_id), id)
    end
  end

  def create_reseller_CSV_params
    %w[CSV_Separator CSV_Decimal].each { |name| Confline.new_confline(name, Confline.get_value(name, owner_id), id) }
  end

  def create_reseler_emails
    %w[Email_Batch_Size Email_Smtp_Server Email_Domain Email_Login Email_Password Email_port].each { |name|
      Confline.new_confline(name, Confline.get_value(name, owner_id), id)
    }

    %w[Email_Login Email_Password].each { |name| Confline.set_value2(name, 1, id) }
  end

  def create_partner_conflines
    %w[Company Company_Email Version Copyright_Title Admin_Browser_Title Logo_Picture ].each { |name|
        Confline.new_confline(name, Confline.get_value(name), id)
      }
  end

  def create_invoice_xlsx_conflines
    names_of_cell = invoice_xlsx_cells_names + ['inv_debt', 'inv_debt_tax', 'inv_total_amount_due']
    default_cells = default_invoice_xlsx_cells
    owner_conflines_exists = Confline.where("name LIKE 'Cell_x6_inv_%' AND owner_id = ?", owner_id).first.present?

    names_of_cell.each do |cell_name|
      value = ''
      name = 'Cell_x6_' + cell_name
      if owner_conflines_exists
        # looking for owners values
        value = Confline.get_value(name, owner_id) # unless (id == 0)
      else
        # looking for admins values
        value = Confline.get_value(name, 0) # if !value.present? && (owner_id != 0)
        # setting default value
        value = default_cells[cell_name] unless value.present?
      end

      Confline.new_confline(name, value, id) if value.present?
    end
  end

  def User.exists_resellers_confline_settings(id)
    con = Confline.where("name = 'Email_Login' AND owner_id = #{id}").first
    reseller = User.where(id: id).first

    unless con
      reseller.create_reseler_emails
    else
      reseller.check_reseller_emails
    end
  end

  def create_xlsx_conflines_if_not_exists
    xlsx_conflines_exists = Confline.where("name LIKE 'Cell_x6_inv_%' AND owner_id = ?", id).first.present?
    create_invoice_xlsx_conflines unless xlsx_conflines_exists
  end

  def create_reseller_emails
    emails = Email.select("emails.*").
        joins("LEFT JOIN (select * from emails where owner_id = #{id} and template =1) as b ON (b.name = emails.name)").
        where("emails.owner_id = 0 AND emails.template = 1 AND b.id IS NULL AND emails.name != 'warning_balance_email_local'").all

    emails.each do |email|
      Email.create(
        name: email.name,
        subject: email.subject,
        body: email.body,
        template: 1,
        date_created: Time.now.to_s,
        owner_id: id
      )
    end
  end

  def check_reseller_emails
    con = Confline.where(["name = 'Email_From' and owner_id=?", id]).first

    if con
      con.name = "Email_from"
      con.save
    end

    emails = Email.select("emails.*").
        joins("LEFT JOIN (select * from emails where owner_id = #{id} and template =1) as b ON (b.name = emails.name)").
        where("emails.owner_id = 0 AND emails.template = 1 AND b.id IS NULL AND emails.name != 'warning_balance_email_local'").all

    emails.each do |email|
      MorLog.my_debug("FIXING RESELLER EMAILS: #{id} Email not found: #{email.id}")
      Email.create(
        name: email.name,
        subject: email.subject,
        body: email.body,
        template:1,
        date_created: Time.now.to_s,
        owner_id: id
      )
    end
  end

  def check_default_user_conflines
    if is_reseller?
      conflines = Confline.where("name LIKE 'Default_device%' AND owner_id = 0").all
      for confline in conflines
        if not Confline.where("name = '#{confline.name}' AND owner_id = #{id}").first
          Confline.new_confline(confline.name, confline.value, id)
        end
      end
    end
  end

  def User::get_hash(user_id)
    user = User.find(user_id.to_i)
    return user.uniquehash if user and user.uniquehash and user.uniquehash.length > 0
    user.uniquehash = ApplicationController::random_password(10)
    user.save
    return user.uniquehash
  end

  #Returns user hash. If user has no hash yet generates new one and returns it.
  def get_hash
    return(uniquehash) if (uniquehash and uniquehash.length > 0)
    uniquehash = ApplicationController::random_password(10)
    self.save
    return uniquehash
  end

  #debug
  #put value into file for debugging
  def my_debug(msg)
    File.open(Debug_File, "a") { |f|
      f << msg.to_s
      f << "\n"
    }
  end

  def get_owner()
    User.find(owner_id)
  end

  def primary_device
    Device.where(id: primary_device_id).first
  end

  def quick_stats(current_month, last_day, current_day, current_user_id)
    month_calls, month_billsec, month_selfcost, month_cost, month_did_owner_cost = 0, 0, 0, 0, 0
    day_calls, day_billsec, day_selfcost, day_cost, day_did_owner_cost = 0, 0, 0, 0, 0

    month_from = current_month + '-01 00:00:00'
    month_till = current_month + "-#{last_day} 23:59:59"
    where_month = "'#{self.system_time(month_from)}' AND '#{self.system_time(month_till)}'"

    day_from = current_day + ' 00:00:00'
    day_till = current_day + ' 23:59:59'
    where_day = "'#{self.system_time(day_from)}' AND '#{self.system_time(day_till)}'"

    es_month = {from: self.system_time(month_from).split.join('T'), till: self.system_time(month_till).split.join('T')}
    es_day = {from: self.system_time(day_from).split.join('T'), till: self.system_time(day_till).split.join('T')}

    if is_admin?
      month_calls, month_billsec, month_selfcost, month_revenue, month_profit, month_did_owner_cost =
          es_admin_quick_stats(es_month)

      day_calls, day_billsec, day_selfcost, day_revenue, day_profit, day_did_owner_cost =
          es_admin_quick_stats(es_day)
    elsif is_reseller?
      month_calls, month_billsec, month_selfcost, month_revenue, month_profit =
          es_reseller_quick_stats(es_month, current_user_id)

      day_calls, day_billsec, day_selfcost, day_revenue, day_profit =
          es_reseller_quick_stats(es_day, current_user_id)
    else
      show_user_billsec = (Confline.get_value('Invoice_user_billsec_show', owner.id).to_i == 1) && (is_user?)

      month_calls, month_billsec = es_user_quick_stats(es_month, current_user_id, show_user_billsec)
      day_calls, day_billsec = es_user_quick_stats(es_day, current_user_id, show_user_billsec)
    end

    [month_calls, month_billsec, month_selfcost, month_revenue, month_profit, month_did_owner_cost,
      day_calls, day_billsec, day_selfcost, day_revenue, day_profit, day_did_owner_cost]
  end

  # finds total outgoing calls made by this user and price for these calls in period
  # period is in string format date-time
  def own_outgoing_calls_stats_in_period(period_start, period_end, calldate_index = 0)
    total_calls = 0
    calls_price = 0
    zero_calls_sql = invoice_zero_calls_sql
    up = SqlExport.user_price_sql

    val = ActiveRecord::Base.connection.select_all("SELECT count(calls.id) as calls, SUM(#{up}) as price FROM calls LEFT JOIN dids on dids.id = calls.did_id AND calls.dst = dids.did WHERE dids.did IS NULL AND disposition = 'ANSWERED' and calls.user_id = #{id} AND calldate BETWEEN '#{period_start}' AND '#{period_end}' #{zero_calls_sql};")

    if val
      total_calls += val[0]['calls'].to_i
      calls_price += val[0]['price'].to_d
    end

    [total_calls.to_i, calls_price.to_d]
  end

  def own_outgoing_calls_stats_to_dids_in_period(period_start, period_end, calldate_index = 0)
    total_calls = 0
    calls_price = 0
    up = SqlExport.user_price_sql
    zero_calls_sql = invoice_zero_calls_sql(up)

    val = ActiveRecord::Base.connection.select_all("SELECT count(calls.id) as calls, SUM(#{up}) as price FROM calls LEFT JOIN dids on dids.id = calls.did_id AND calls.dst = dids.did WHERE dids.did IS NOT NULL AND disposition = 'ANSWERED' and calls.user_id = #{id} AND calldate BETWEEN '#{period_start}' AND '#{period_end}' #{zero_calls_sql};")

    if val
      total_calls += val[0]['calls'].to_i
      calls_price += val[0]['price'].to_d
    end

    [total_calls.to_i, calls_price.to_d]
  end


  # finds total outgoing calls made by this reseller users and price for these calls in period
  # period is in string format date-time
  def users_outgoing_calls_stats_in_period(period_start, period_end, calldate_index = 0)
    total_calls = 0
    calls_price = 0

    if is_reseller?
      owner_type_condition = 'calls.reseller_id'
      sum_sql = SqlExport.admin_reseller_price_sql
      zero_calls_sql = iinvoice_zero_calls_sql(SqlExport.reseller_price_sql)
    else
      owner_type_condition = 'calls.partner_id'
      sum_sql = SqlExport.partner_price_sql
      zero_calls_sql = invoice_zero_calls_sql(SqlExport.partner_price_sql)
    end

    sql = "SELECT count(calls.id) as calls, SUM(#{sum_sql}) as price
           FROM calls
           #{SqlExport.left_join_reseler_providers_to_calls_sql}
           LEFT JOIN devices ON (dst_device_id = devices.id)
           LEFT JOIN users ON (devices.user_id = users.id)
           WHERE disposition = 'ANSWERED'
           and (#{owner_type_condition} = #{id})
           AND calldate BETWEEN '#{period_start}' AND '#{period_end}' #{zero_calls_sql}"
    res = ActiveRecord::Base.connection.select_all(sql)

    if res[0]
      total_calls = res[0]["calls"].to_i
      calls_price = res[0]["price"].to_d
    end

    unless is_partner?
      # DID Owner Cost - when resellers user is dst_user_id
      sql2 = "SELECT count(calls.id) as calls, SUM(#{SqlExport.admin_reseller_price_no_dids_sql} + did_price) as price
             FROM calls
             #{SqlExport.left_join_reseler_providers_to_calls_sql}
             LEFT JOIN devices ON (dst_device_id = devices.id)
             LEFT JOIN users ON (devices.user_id = users.id)
             WHERE disposition = 'ANSWERED'
             and (users.owner_id = #{id})
             AND calldate BETWEEN '#{period_start}' AND '#{period_end}' #{zero_calls_sql}"
      res2 = ActiveRecord::Base.connection.select_all(sql2)

      if res2[0]
        total_calls_dst = res2[0]["calls"].to_i
        calls_price_dst = res2[0]["price"].to_d
      end
    end
    return total_calls, calls_price, total_calls_dst, calls_price_dst
  end

  # finds total incoming calls RECEIVED by this user and price for these calls in period
  # period is in string format date-time
  def incoming_received_calls_stats_in_period(period_start, period_end, calldate_index = 0)

    total_calls = 0
    calls_price = 0

    # this sql is SLOOOOOWWWW on DB with millions of calls, time goes over 45s, OUCH!!!
    #sql = "SELECT count(calls.id) as calls, #{SqlExport.replace_price("SUM(#{SqlExport.user_price_sql})", {:reference => 'price'})}
    #              FROM calls
    #              JOIN devices ON (calls.dst_device_id = devices.id)
    #              WHERE disposition = 'ANSWERED' AND calldate BETWEEN '#{period_start}' AND '#{period_end}' AND devices.user_id = #{id} AND calls.did_price > 0;"

    # what is really sad - that this does not calculate invoice calls correctly at all....
    # no need to include calls.user_price + calls.did_inc_price into Incoming RECEIVED calls

    # this sql uses calls.dst_user_id field which allows increase speed a lot
    sql = "SELECT count(calls.id) as calls, SUM(#{SqlExport.user_did_price_sql}) AS price
                  FROM calls
                  WHERE disposition = 'ANSWERED' AND calldate BETWEEN '#{period_start}' AND '#{period_end}' AND calls.dst_user_id = #{id}> 0;"

    res = ActiveRecord::Base.connection.select_all(sql)

    if res[0]
      total_calls = res[0]["calls"]
      calls_price = res[0]["price"]
    end

    return total_calls.to_i, calls_price.to_d
  end

  # finds total incoming calls MADE by this user and price for these calls in period (DID incoming)
  # period is in string format date-time
  def incoming_made_calls_stats_in_period(period_start, period_end, calldate_index = 0)
    total_calls = 0
    calls_price = 0

    # this sql is SLOOOOOWWWW on DB with millions of calls, time goes over 45s, OUCH!!!
    #sql = "SELECT count(calls.id) as calls, #{SqlExport.replace_price("SUM(#{SqlExport.user_price_sql})", 'price')}
    #              FROM calls
    #              JOIN devices ON (calls.src_device_id = devices.id)
    #              WHERE disposition = 'ANSWERED' AND calldate BETWEEN '#{period_start}' AND '#{period_end}' AND devices.user_id = #{id} AND calls.did_inc_price > 0;"

    # this sql uses calls.dst_user_id field which allows increase speed a lot
    sql = "SELECT count(calls.id) as calls, #{SqlExport.replace_price("SUM(#{SqlExport.user_price_sql})", {:reference => 'price'})}
                  FROM calls
                  WHERE disposition = 'ANSWERED' AND calldate BETWEEN '#{period_start}' AND '#{period_end}' AND calls.dst_user_id = #{id} AND calls.did_inc_price > 0;"

    res = ActiveRecord::Base.connection.select_all(sql)

    if res[0]
      total_calls = res[0]["calls"]
      calls_price = res[0]["price"]
    end

    return total_calls.to_i, calls_price.to_d
  end

  # finds subscriptions in given period
  # period is in string format date-time
  def subscriptions_in_period(period_start, period_end, is_a_day = nil)
    period_start = period_start.to_s(:db) if period_start.class == Time or period_start.class == Date
    period_end = period_end.to_s(:db) if period_end.class == Time or period_end.class == Date
    if is_a_day.to_s != 'invoices'
      day_sql = !is_a_day.to_s.blank? ? " AND services.periodtype = 'day' "  : " AND services.periodtype != 'day' "
    else
      day_sql = ''
    end
    subs = Subscription.where(["(? BETWEEN activation_start AND activation_end OR ? BETWEEN activation_start AND activation_end OR (activation_start > ? AND activation_end < ?) OR (activation_start < ? AND activation_end IS NULL))  AND subscriptions.user_id = ?  #{day_sql} AND services.servicetype != 'dynamic_flat_rate'", period_start, period_end, period_start, period_end, period_end,self.id]).includes(:service).references(:service).all
    subs
  end

  # gets parameters for CSV file
  def csv_params
    owner_id = owner_id
    owner_id = id if is_reseller?
    sep = Confline.get_value('CSV_Separator', owner_id).to_s
    dec = Confline.get_value('CSV_Decimal', owner_id).to_s

    sep = Confline.get_value('CSV_Separator', 0).to_s if sep.to_s.length == 0
    dec = Confline.get_value('CSV_Decimal', 0).to_s if dec.to_s.length == 0

    sep = ',' if sep.blank?
    dec = '.' if dec.blank?

    return sep, dec
  end

  def create_default_device(options={})
    owner_id = self.owner_id
    fextension = options[:free_ext]
    options_device_type = options[:device_type].to_s

    device = devices.new({
      devicegroup_id: options[:dev_group].to_i, context: 'mor_local',
      device_type: options_device_type, extension: fextension, pin: options[:pin].to_s,
      secret: options[:secret].to_s
      })

    device.description = options[:description] if options[:description]
    device.device_ip_authentication_record = options[:device_ip_authentication_record] if options[:device_ip_authentication_record]
    device.works_not_logged = Confline.get_value("Default_device_works_not_logged", owner_id).to_i

    owner = User.where(id: owner_id).first
    # after this value should be default location and reseller gets new default location if did not have it
    owner.after_create_localization if owner && (owner_id != 0)

    # if reseller and location id == 1, create default location and set new location id
    set_location_id = owner.locations.where(id: options[:device_location_id].to_i).first.try(:id) || Confline.get_value("Default_device_location_id", owner_id)

    if (set_location_id.blank? or set_location_id.to_i == 1) and owner and owner.is_reseller?
      device.check_location_id
      device.location_id = Confline.get_value("Default_device_location_id", owner_id).to_i
    else
      device.location_id = set_location_id.blank? ? 0 : set_location_id
    end

    # these have to be updated if device type is not FAX
    if %w[SIP IAX2 H323 dahdi Virtual].include? options_device_type
      device.callerid = options[:callerid].to_s if options[:callerid]
      device.record = Confline.get_value("Default_device_record", owner_id).to_i
      device.callgroup = Confline.get_value("Default_device_callgroup", owner_id).to_s.blank? ? nil : Confline.get_value("Default_device_callgroup", owner_id).to_i
      device.pickupgroup = Confline.get_value("Default_device_pickupgroup", owner_id).to_s.blank? ? nil : Confline.get_value("Default_device_pickupgroup", owner_id).to_i
      device.istrunk = Confline.get_value("Default_device_istrunk", owner_id).to_i
      device.tell_balance = Confline.get_value("Default_device_tell_balance", owner_id).to_i
      device.tell_time = Confline.get_value("Default_device_tell_time", owner_id).to_i
      device.tell_rtime_when_left = Confline.get_value("Default_device_tell_rtime_when_left", owner_id).to_i
      device.repeat_rtime_every = Confline.get_value("Default_device_repeat_rtime_every", owner_id).to_i
      device.ani = Confline.get_value("Default_device_ani", owner_id).to_i
      device.process_sipchaninfo = Confline.get_value("Default_device_process_sipchaninfo", owner_id).to_i
      device.call_limit = Confline.get_value("Default_device_call_limit", owner_id)
      device.recording_to_email = Confline.get_value("Default_device_recording_to_email", owner_id).to_i
      device.record_forced = Confline.get_value("Default_device_record_forced", owner_id).to_i
      device.enable_mwi = Confline.get_value("Default_device_enable_mwi", owner_id).to_i
      device.subscribemwi = Confline.get_value("Default_device_subscribemwi", owner_id)
      device.tell_rate = Confline.get_value("Default_device_tell_rate", owner_id).to_i
      device.custom_sip_header = Confline.get_value("Default_device_custom_sip_header", owner_id).to_s
      device.recording_keep = Confline.get_value("Default_device_recording_keep", owner_id).to_i
      device.recording_email = Confline.get_value("Default_device_recording_email", owner_id).to_s
      device.time_limit_per_day = Confline.get_value("Default_device_time_limit_per_day", owner_id).to_s
      device.qf_tell_balance = Confline.get_value("Default_device_qf_tell_balance", owner_id).to_i
      device.qf_tell_time = Confline.get_value("Default_device_qf_tell_time", owner_id).to_i

      # these have to be updated if device type is not FAX or Virtual
      if options_device_type != 'Virtual'
        device.dtmfmode = Confline.get_value("Default_device_dtmfmode", owner_id).to_s
        device.fake_ring = Confline.get_value("Default_device_fake_ring", owner_id).to_i
        device.block_callerid = Confline.get_value("Default_device_block_callerid", owner_id).to_i
        device.cps_call_limit = Confline.get_value("Default_device_cps_call_limit", owner_id).to_i
        device.cps_period = Confline.get_value("Default_device_cps_period", owner_id).to_i

        # these have to be updated if device type is SIP or IAX2
        if %w[SIP IAX2].include? options_device_type
          device.transfer = Confline.get_value("Default_device_canreinvite", owner_id).to_s
          device.nat = Confline.get_value("Default_device_nat", owner_id).to_s
          device.canreinvite = Confline.get_value("Default_device_canreinvite", owner_id).to_s
          device.fromuser = Confline.get_value("Default_device_fromuser", owner_id).to_s
          device.fromdomain = Confline.get_value("Default_device_fromdomain", owner_id).to_s
          device.trustrpid = Confline.get_value("Default_device_trustrpid", owner_id).to_s
          device.sendrpid = Confline.get_value("Default_device_sendrpid", owner_id).to_s
          device.progressinband = Confline.get_value("Default_device_progressinband", owner_id).to_s
          device.videosupport = Confline.get_value("Default_device_videosupport", owner_id).to_s
          device.promiscredir = Confline.get_value("Default_device_promiscredir", owner_id).to_s
          device.promiscredir = "no" if device.promiscredir.to_s != "yes" and device.promiscredir.to_s != "no"
          device.transport = Confline.get_value("Default_device_transport", owner_id).to_s
          device.transport = 'udp' if !['tcp', 'udp', 'tcp,udp', 'udp,tcp', 'tls'].include?(device.transport)
          device.encryption = Confline.get_value("Default_device_encryption", owner_id)
        end
      end
    end

    if %w[SIP IAX2 H323 dahdi Virtual FAX].include? options_device_type
      device.timeout = Confline.get_value("Default_device_timeout", owner_id)
      device.allow_duplicate_calls = Confline.get_value("Default_device_allow_duplicate_calls", owner_id).to_i
      device.change_failed_code_to = Confline.get_value("Default_device_change_failed_code_to", owner_id).to_i
      device.max_timeout = Confline.get_value("Default_device_max_timeout", owner_id).to_i
      device.language = Confline.get_value("Default_device_language", owner_id).to_s

      # these have to be updated if device type is not Virtual or dahdi
      if options_device_type != 'dahdi'
        device.qualify = Confline.get_value("Default_device_qualify", owner_id)

        # these have to be updated if device type is not Virtual, dahdi or H323
        if options_device_type != 'H323'
          device.t38pt_udptl = Confline.get_value("Default_device_t38pt_udptl", owner_id).to_s
        end
      end
    end

    device.grace_time = Confline.get_value("Default_device_grace_time", owner_id).to_s
    device.server_id = Confline.get_value("Default_device_server_id")
    device.voicemail_active = Confline.get_value("Default_device_voicemail_active", owner_id).to_i
    device.permit = Confline.get_value("Default_device_permits", owner_id).to_s

    device.host, device.ipaddr, device.port = if options_device_type == 'H323'
                                                ['', '', '1720']
                                              else
                                                [
                                                  'dynamic',
                                                  Confline.get_value('Default_device_ipaddr', owner_id).to_s,
                                                  Confline.get_value('Default_device_port', owner_id).to_i
                                                ]
                                               end

    device.regseconds = Confline.get_value("Default_device_regseconds", owner_id).to_i
    device.insecure = Confline.get_value("Default_device_insecure", owner_id).to_s if options_device_type == 'SIP'
    device.use_ani_for_cli = Confline.get_value("Default_device_use_ani_for_cli", owner_id)
    device.trunk = Confline.get_value("Default_device_trunk", owner_id) if options_device_type == 'IAX2'
    device.calleridpres = Confline.get_value("Default_device_calleridpres", owner_id)
    device.anti_resale_auto_answer = Confline.get_value("Default_device_anti_resale_auto_answer", owner_id).to_i
    device.works_not_logged = 1 unless device.works_not_logged
    device.cid_from_dids = Confline.get_value("Default_setting_device_caller_id_number", owner_id).to_i == 3 ? 1 : 0
    device.control_callerid_by_cids = Confline.get_value("Default_setting_device_caller_id_number", owner_id).to_i == 4 ? 1 : 0
    device.callerid_advanced_control = Confline.get_value("Default_setting_device_caller_id_number", owner_id).to_i == 5 ? 1 : 0

    if options_device_type == 'SIP'
      session_expires = Confline.get_value("Default_device_session-expires", owner_id).to_i
      session_minse = Confline.get_value("Default_device_session-minse", owner_id).to_i
      session_refresher = Confline.get_value("Default_device_session-refresher", owner_id).to_s
      session_timers = Confline.get_value("Default_device_session-timers", owner_id).to_s

      device['session-timers'] = session_timers if session_timers.present?
      device['session-refresher'] = session_refresher if session_refresher.present?
      device['session-expires'] = session_expires if session_expires > 0
      device['session-minse'] = session_minse if session_minse > 0
    end

    device.username = options[:username] ? options[:username] : fextension
    device.name = options[:username] ? options[:username] : fextension

    device.save

    while device.errors.messages[:extension].present?
      new_extension = DeviceFreeExtension.take_extension
      device.extension = new_extension
      if options[:username].blank?
        device.username = new_extension
        device.name = new_extension
      end

      device.save
    end

    if device.save
      #------- VM ----------
      pass = Confline.get_value("Default_device_voicemail_box_password", owner_id)
      pass = random_digit_password(4) if pass.to_s.length == 0

      email = Confline.get_value("Default_device_voicemail_box_email", owner_id)
      address = address
      email = address.email if address and address.email.to_s.size > 0



      device.update_cid(Confline.get_value("Default_device_cid_name", owner_id), Confline.get_value("Default_device_cid_number", owner_id), false) unless device.callerid
      primary_device_id = device.id
      # configure_extensions(device.id)
    end

    device
  end

  def assign_default_tax(taxs={}, opt ={})
    options = { save: true }.merge(opt)

    new_tax = if !taxs or taxs == {}
                if owner_id == 0
                  Confline.get_default_tax(0)
                else
                  User.where(id: owner_id).first.get_tax.dup
                end
              else
                Tax.new(taxs)
              end

    new_tax.save if options[:save] == true
    self.tax_id = new_tax.id
    self.tax = new_tax
    self.save if options[:save] == true
  end

  def random_digit_password(size = 8)
    chars = ((0..9).to_a)
    (1..size).collect { |char| chars[rand(chars.size)] }.join
  end

  def get_tax
    self.assign_default_tax if tax.nil?
    self.tax
  end

  def get_tax_value
    user_tax = self.get_tax
    tax = 1
    if user_tax.compound_tax == 1
      for index in 1..4
        tax = tax * (1 + eval("user_tax.tax#{index}_value") / 100) if eval("user_tax.tax#{index}_enabled") == 1
      end
    else
      tax_multiplier = 0
      for index in 1..4
        tax_multiplier += eval("user_tax.tax#{index}_value") if eval("user_tax.tax#{index}_enabled") == 1
      end
      tax = tax + (tax_multiplier / 100)
    end
    tax
  end

  def user_type
    postpaid == 1 ? "postpaid" : "prepaid"
  end

  def pay_subscriptions(year, month, day=nil, is_a_day = nil)
    changed = 0
    all_data = []
    MorLog.my_debug("---#{username}-----------------------------------------")

    return all_data if blocked.to_i == 1
    time = Time.mktime(year, month, (day ? day.to_i : 1), 23, 59, 59)
    time = time.next_month if user_type == 'prepaid' && day.nil?

    MorLog.my_debug("  #{time.year}-#{time.month}")
    #sorry about this nasty.. since i wouldn't want to rewrite mehod
    #that does who knows what i jus pass day param and check whether
    #is is nil or not. if nil it means we're paying for monthly subscriptions
    #else we're paying daily subscriptions
    if day
      period_start_with_time = time.change(hour: 0, min: 0, sec: 0)
      period_end_with_time = time.change(hour: 23, min: 59, sec: 59)
    else
      period_start_with_time = time.beginning_of_month
      period_end_with_time = time.end_of_month.change(hour: 23, min: 59, sec: 59)
    end

    subscriptions = self.subscriptions_in_period(period_start_with_time, period_end_with_time, is_a_day)
    MorLog.my_debug("  Found subscriptions : #{subscriptions.size}")
    MorLog.my_debug("  period_start_with_time : #{period_start_with_time}")
    MorLog.my_debug("  period_end_with_time : #{period_end_with_time}")

    disallow_balance_negative = Confline.get_value('Disallow_prepaid_user_balance_drop_below_zero', owner_id).to_i
    do_not_block_when_below_zero = Confline.get_value('do_not_block_users_when_balance_below_zero_on_subscription').to_i

    total_sub_balance = 0
    subscriptions.each { |sub|
      if !Action.where(["action = 'subscription_paid' AND user_id = ? AND data = ? AND target_id = ?",
        id, "#{time.year}-#{time.month}#{('-' + time.day.to_s) if day}", sub.id]).first

        changed = 1
        sub_price = sub.price_for_period(period_start_with_time, period_end_with_time)

        # if setting does not allow dropping bellow zero and balance got bellow 0
        balance_left = balance - sub_price - total_sub_balance
        if user_type == 'prepaid' && balance_left.to_d < 0.to_d && disallow_balance_negative == 1
          # and block user
          MorLog.my_debug("  Blocking prepaid user and sending email")
          self.block_and_send_email
        else
          # pay subsciption
          user = User.find(id)
          currency =  user.owner.currency
          Action.new(user_id: id, target_id: sub.id, target_type: "subscription", date: Time.now,
            action: "subscription_paid", data: "#{time.year}-#{time.month}#{('-' + time.day.to_s) if day}",
            data2: sub_price, data3: currency.name).save
          total_sub_balance += sub_price
        end

        MorLog.my_debug("  Paying subscription: #{sub.service.name} Price: #{sub_price} balance left #{balance}")
        all_data << {price: sub_price, subscription: sub, msg: 'Paid now'}
        Payment.subscription_payment(self, sub_price)

        # what is the purpose of this Action? It marks subscription
        # as paid for next month and ruins the billing!
        # Action.new(:user_id => id, :target_id => sub.id, :target_type =>"subscription",
        # :date => Time.now, :action => "subscription_paid",
        # :data => "#{Time.now.year}-#{Time.now.month}", :data2=>sub_price).save
      else
        MorLog.my_debug("  Service already paid: #{sub.service.name}")
        #all_data << {:price => 0, :price_with_tax => 0, :subscription => sub, :msg => "Alraedy payed"}
      end
    }
    self.balance -= total_sub_balance
    if self.postpaid? && (balance + credit < 0) &&
      !self.credit_unlimited? && do_not_block_when_below_zero == 0
      changed = 1
      MorLog.my_debug("  Blocking postpaid user and sending email")
      self.block_and_send_email
    end

    self.save if changed.to_i == 1
    MorLog.my_debug("-END-#{username}-----------------------------------------")

    return all_data
  end

  def user_calls_to_csv(options={})
    options[:hide_finances] ||= false
    sep, dec = csv_params

    disposition = []

    incoming_direction = options[:direction] == 'incoming'

    if incoming_direction
      disposition << " ((devices.user_id = #{id} )  OR (dids.user_id = #{id}))"
      disposition << " calls.dst_device_id = #{options[:device].id} " if options[:device]
    else
      disposition << " calls.user_id = #{id}"
      disposition << " calls.src_device_id = #{options[:device].id} " if options[:device]
    end

    disposition << " disposition = '#{options[:call_type]}' " if options[:call_type] != "all"
    disposition << " calls.hangupcause = #{options[:hgc].code} " if options[:hgc]
    disposition << " calls.card_id = 0"
    disposition << " calldate BETWEEN '#{options[:date_from]}' AND '#{options[:date_till]}'"

    default_currency = options[:default_currency]
    show_currency = options[:show_currency]
    if default_currency != show_currency
      curr3er = Currency.select("exchange_rate as 'ex'").conditions("name = '#{show_currency}'").first
    end

    #fm1 = " ROUND("
    #fm2 =" ,#{options[:nice_number_digits]}) "

    r1 = dec == "." ? "" : "replace("
    r2 = dec == "." ? "" : ", '.', '#{dec}')"
    n1 = "#{r1}"
    n2 = "#{r2}"
    c1 = default_currency != show_currency ? " * #{curr3er.ex.to_d} " : ""

    select = []
    select2 = []
    headers = []

    options_usertype_is_admin = options[:usertype] == 'admin'

    format = Confline.get_value('Date_format', owner_id).gsub('M', 'i')
    headers << "'#{_('Date')}'" + ' AS calldate'
    headers << "'#{_('Called_from')}'" + ' AS src'
    headers << "'#{_('Called_to')}'" + ' AS dst'
    headers << "'#{_('Direction')}'" + ' AS direction'
    headers << "'#{_('Provider')}'" + ' AS prov_name' if options_usertype_is_admin
    headers << "'#{_('Duration')}'" + ' AS duration'
    headers << "'#{_('hangup_cause')}'" + ' AS disposition'
    select2 << SqlExport.nice_date('calldate', {:reference => 'calldate', :format => format, :tz => options[:tx]})
    select2 << "src, dst, direction"
    select2 << "prov_name" if options_usertype_is_admin
    select2 << "duration, disposition"

    select << "calls.calldate"
    select << "IF(#{options[:show_full_src].to_i} = 1 AND CHAR_LENGTH(clid)>0 AND clid REGEXP'\"' , CONCAT(src, '  ' ,REPLACE(SUBSTRING_INDEX(clid, '\"', 2), '\"', '('), ')'), src) as 'src'"

    options[:usertype] == 'user' ? select << SqlExport.hide_dst_for_user_sql(self, "csv", "calls.dst", {:as => "dst"}) : select << "calls.dst"

    select << "CONCAT(IF(directions.name IS NULL, '',directions.name), ' ', IF(destinations.name IS NULL, '',destinations.name)) as 'direction'"
    select << "IF(providers.name IS NULL, '', providers.name) as 'prov_name' " if options_usertype_is_admin
    select << "IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) ) as 'duration'"
    select << "calls.disposition"
    unless options[:hide_finances]
      if incoming_direction
        if options_usertype_is_admin
          headers << "'#{_('User_price')}'" + ' AS user_price3'
          select2 << SqlExport.replace_price("#{n1}user_price3#{n2}", {:reference => 'user_price3'})
          # select2 << SqlExport.replace_price("#{n1}provider_price3#{n2}", {:reference => 'provider_price3'})
          headers << "'#{_('DID_Price')}'" + ' AS did_price3'
          select2 << SqlExport.replace_price("#{n1}did_price3#{n2}", {:reference => 'did_price3'})
          # select2 << SqlExport.replace_price("#{n1}(user_price3+provider_price3+did_price3)#{n2}", {:reference => 'profit'})
          headers << "'#{_('Profit')}'" + ' AS profit'
          select2 << SqlExport.replace_price("#{n1}(user_price3+did_price3)#{n2}", {:reference => 'profit'})
          select << "#{n1}calls.did_prov_price#{c1}#{n2} as 'user_price3'"
          select << "#{n1}calls.did_inc_price#{c1}#{n2} as 'provider_price3'"
          select << "#{n1}calls.did_price#{c1}#{n2} as 'did_price3'"
        end
        if options[:usertype] == "reseller"
          headers << "'#{_('DID_Price')}'" + ' AS did_price3'
          select2 << SqlExport.replace_price("#{n1}did_price3#{n2}", {:reference => 'did_price3'})
          select << "#{n1}calls.did_price#{c1}#{n2} as 'did_price3'"
        end
        if options[:usertype] == "user"
          headers << "'#{_('User_price')}'" + ' AS user_price3'
          select2 << SqlExport.replace_price("#{n1}user_price3#{n2}", {:reference => 'user_price3'})
          select << "#{n1} calls.did_price #{c1} #{n2} as 'user_price3'"
        end
      else
        headers << "'#{_('User_price')}'" + ' AS user_price3'
        select2 << SqlExport.replace_price("#{n1}user_price3#{n2}", {:reference => 'user_price3'})
        select << "#{n1} calls.user_price #{c1} #{n2} as 'user_price3'" if options[:usertype] != "admin"
        if options_usertype_is_admin
          headers << "'#{_('Provider_price')}'" + ' AS provider_price3'
          headers << "'#{_('Profit')}'" + ' AS profit'
          select2 << SqlExport.replace_price("#{n1}provider_price3#{n2}", {:reference => 'provider_price3'})
          select2 << SqlExport.replace_price("#{n1}(user_price3-provider_price3)#{n2}", {:reference => 'profit'})
          select << "IF(calls.reseller_id > 0, calls.reseller_price#{c1} , calls.user_price#{c1}) as 'user_price3'"
          select << "IF(calls.provider_price IS NOT NULL, calls.provider_price#{c1}, 0) as 'provider_price3'"
        end
        if options[:usertype] == "reseller"
          headers << "'#{_('Provider_price')}'" + ' AS provider_price3'
          select2 << SqlExport.replace_price("#{n1}provider_price3#{n2}", {:reference => 'provider_price3'})
          select << "IF(calls.reseller_id = 0, calls.user_price#{c1}, calls.reseller_price#{c1}) as 'provider_price3'"
          headers << "'#{_('Profit')}'" + ' AS profit'
          select2 << SqlExport.replace_price("#{n1}(user_price3-provider_price3)#{n2}", {:reference => 'profit'})
        end
        if options[:usertype] != "user"
          headers << "'#{_('Margin')}'" + ' AS m1'
          headers << "'#{_('Markup')}'" + ' AS m2'
          select2 << "IF( (((user_price3-provider_price3) / user_price3 ) *100) IS NULL, 0,  #{n1}(((user_price3-provider_price3) / user_price3 ) *100) #{n2}) as 'm1'"
          select2 << "IF(( ((user_price3 / provider_price3) *100)-100 ) IS NULL, 0 ,   #{n1}( ((user_price3 / provider_price3) *100)-100 )#{n2}) as 'm2'"
        end
      end
    end
    if options_usertype_is_admin
      select << "calls.originator_ip as 'oip'"
      select << "calls.terminator_ip as 'tip'"
      select << "IF(calls.real_duration = 0, duration, real_duration) as 'real_duration2'"
      select << "IF(calls.real_billsec = 0, billsec, real_billsec) as 'real_billsec2'"

      headers << "'#{_('Originator_IP')}'" + ' AS oip'
      headers << "'#{_('Terminator_IP')}'" + ' AS tip'
      headers << "'#{_('Real_Duration')}'" + ' AS real_duration2'
      headers << "'#{_('Real_Billsec')}'" + ' AS real_billsec2'

      select2 << "oip"
      select2 << "tip"
      select2 << "#{n1}real_duration2#{n2} as real_duration2"
      select2 << "#{n1}real_billsec2#{n2} as real_billsec2"
    end

    jn = []
    jn << "LEFT JOIN destinations ON (calls.prefix = destinations.prefix)"
    jn << "LEFT JOIN directions ON (directions.code = destinations.direction_code)"
    jn << "JOIN devices ON (devices.id = calls.dst_device_id)" if incoming_direction
    jn << "LEFT JOIN dids ON (calls.did_id = dids.id)" if incoming_direction
    jn << "LEFT JOIN providers ON (providers.id = calls.provider_id)" if options_usertype_is_admin

    filename = "CDR-#{id.to_s.gsub(" ", "_")}-#{options[:date_from].gsub(" ", "_").gsub(":", "_")}-#{options[:date_till].gsub(" ", "_").gsub(":", "_")}-#{Time.now().to_f.to_s.gsub(".", "")}-#{options[:direction]}-#{show_currency}"

    sql = "SELECT * "
    if options[:test] != 1
      sql += " INTO OUTFILE '/tmp/#{filename}.csv'
            FIELDS TERMINATED BY '#{sep}' OPTIONALLY ENCLOSED BY '#{''}'
            ESCAPED BY '#{"\\\\"}'
        LINES TERMINATED BY '#{"\\n"}' "
    end
    disp = disposition.join(" AND ")
    disp = "(#{disp}) OR (calls.reseller_id = #{id} AND calldate BETWEEN '#{options[:date_from]}' AND '#{options[:date_till]}')" if options[:reseller].to_i == 1

    # adding headers
    header_sql = "SELECT " + headers.join(', ') + ' UNION ALL '

    sql += " FROM ("+
        "#{header_sql.to_s} SELECT #{select2.join(" , ")}  FROM
            ((SELECT #{select.join(" , ")}
      FROM calls  #{jn.join(" ")}
      WHERE #{disp}
      ORDER BY calls.calldate DESC)) as temp_a) as temp_c;"

    test_content = ''

    #  MorLog.my_debug(sql)
    if options[:test].to_i == 1
      mysql_res = ActiveRecord::Base.connection.select_all(sql)
      test_content = mysql_res.to_a.to_json
    else
      mysql_res = ActiveRecord::Base.connection.execute(sql)
    end
    return filename, test_content
  end

  def user_last_calls_order(options={})
    cond = []
    cond << "(calldate BETWEEN '#{options[:from]}' AND '#{options[:till]}')"
    cond << "(dst_device_id = #{options[:device].id} OR src_device_id = #{options[:device].id})" if options[:device].to_i > 0
    cond << " disposition = '#{options[:call_type]}' " if options[:call_type] != "all"
    cond << " calls.hangupcause = #{options[:hgc].code} " if options[:hgc]

    cond << "(calls.reseller_id = '#{id}' OR devices.user_id = '#{id}')" if is_reseller?
    cond << "devices.user_id = '#{id}'" if is_user?

    jn = []
    jn << 'LEFT JOIN users ON (calls.user_id = users.id)'
    jn << 'LEFT JOIN users AS resellers ON (calls.reseller_id = resellers.id)'
    jn << 'LEFT JOIN providers ON (calls.provider_id = providers.id)'
    jn << 'LEFT JOIN dids ON (calls.did_id = dids.id)'
    jn << 'LEFT JOIN cards ON (calls.card_id = cards.id)'
    jn << 'JOIN devices ON (calls.src_device_id = devices.id OR calls.dst_device_id = devices.id)' if !is_admin? and !is_accountant?
    jn2 = 'JOIN devices ON (calls.src_device_id = devices.id OR calls.dst_device_id = devices.id)' if !is_admin? and !is_accountant?
    select = is_reseller? ? ' DISTINCT calls.*' : 'calls.*'

    if options[:csv] == 1
      s =[]
      format = Confline.get_value('Date_format', owner_id).gsub('M', 'i')
      s << SqlExport.nice_date('calldate', {:reference => 'calldate', :format => format, :tz => time_offset})
      s << "calls.src"
      options[:usertype] == 'user' ? s << SqlExport.hide_dst_for_user_sql(self, "csv", "calls.dst", {:as => "dst"}) : s << "calls.dst"
      s << "IF(calls.billsec = 0, IF(calls.real_billsec = 0, 0, calls.real_billsec) ,calls.billsec)"
      if !is_user? || (Confline.get_value('Show_HGC_for_Resellers').to_i == 1 and is_reseller?)
        s << "CONCAT(calls.disposition, '(', calls.hangupcause, ')')"
      else
        s << 'calls.disposition'
      end
      if is_admin? || is_accountant?
        s << "calls.server_id"
        s << "IF(providers.name IS NULL, '', providers.name)"
        s << "IF(calls.provider_rate IS NULL, 0, calls.provider_rate), IF(calls.provider_price IS NULL, 0, calls.provider_price)" if options[:can_see_finances]
        if Confline.get_value('RS_Active').to_i == 1
          s << "CONCAT(resellers.first_name, ' ',resellers.last_name )"
          s << "IF(calls.reseller_rate IS NULL, 0 , #{SqlExport.replace_price('calls.reseller_rate')}), IF(calls.reseller_price IS NULL, 0 , #{SqlExport.replace_price('calls.reseller_price')})" if options[:can_see_finances]
        end

        s << "IF(calls.card_id = 0 ,CONCAT(IF(users.first_name IS NULL, ' ', users.first_name), ' ', IF(users.last_name IS NULL, ' ', users.last_name)  ), CONCAT('Card/#', cards.number))"
        s << "IF(calls.user_rate IS NULL, 0, #{SqlExport.replace_price('calls.user_rate')}), IF(calls.user_price IS NULL, 0, #{SqlExport.replace_price('calls.user_price')})" if options[:can_see_finances]
        s << "IF(dids.did IS NULL, '' , dids.did)"
        s << "IF(calls.did_prov_price IS NULL, 0, #{SqlExport.replace_price('calls.did_prov_price')}), IF(calls.did_price IS NULL, 0 , #{SqlExport.replace_price('calls.did_price')})" if options[:can_see_finances]
      end
      if show_billing_info == 1 and options[:can_see_finances]
        if is_reseller?
          s << "IF(calls.reseller_price != 0 , IF(calls.reseller_price IS NULL, 0, #{SqlExport.replace_price('calls.reseller_price')}), IF(calls.did_price IS NULL, 0, #{SqlExport.replace_price('calls.did_price')}))"
        end
        if is_user?
          s << "IF(calls.user_price != 0 , IF(calls.user_price IS NULL, 0, #{SqlExport.replace_price('calls.user_price')}), IF(calls.did_price IS NULL, 0, #{SqlExport.replace_price('calls.did_price')}))"
        end
      end
      filename = "Last_calls-#{id.to_s.gsub(" ", "_")}-#{options[:from].gsub(" ", "_").gsub(":", "_")}-#{options[:till].gsub(" ", "_").gsub(":", "_")}-#{Time.now().to_i}"
      sep, dec = csv_params
      sql = "SELECT * "
      if options[:test] != 1
        sql += " INTO OUTFILE '/tmp/#{filename}.csv'
            FIELDS TERMINATED BY '#{sep}' OPTIONALLY ENCLOSED BY '#{''}'
            ESCAPED BY '#{"\\\\"}'
        LINES TERMINATED BY '#{"\\n"}' "
      end
      sql += " FROM (SELECT #{s.join(', ')} FROM calls  #{jn.join(' ')}  WHERE #{cond.join(' AND ')} ORDER BY #{options[:order]} ) as C"

      if options[:test].to_i == 1
        mysql_res = ActiveRecord::Base.connection.select_all(sql)
        filename += mysql_res.to_yaml.to_s
      else
        mysql_res = ActiveRecord::Base.connection.execute(sql)
      end
      return filename
    else
      calls = Call.select(select).where(cond.join(' AND ')).joins(jn.join(' ')).order(options[:order]).limit("#{((options[:page].to_i - 1) * options[:items_per_page]).to_i}, #{options[:items_per_page]}").all
      calls_t = Call.where(cond.join(' AND ')).joins(jn2).count
      return calls, calls_t.to_i
    end
  end

  def update_voicemail_boxes
    device_ids = Device.select("id").where(["user_id = ?", id]).all.map(&:id)
    VoicemailBox.where("device_id in (#{device_ids.join(", ")})").update_all(["fullname = ?", [first_name.to_s, last_name.to_s].join(" ")]) if device_ids.size > 0
  end

  def User.check_users_balance
    User.where("warning_email_active = '1' AND (" +
                    "(warning_email_sent = '1' AND balance > warning_email_balance) OR " +
                    "(warning_email_sent_admin = '1' AND balance > warning_email_balance_admin) OR " +
                    "(warning_email_sent_manager = '1' AND balance > warning_email_balance_manager))").all.each do |user|
      Application.reset_user_warning_email_sent_status(user)
    end
  end

  def get_invoices_status
    invoice = send_invoice_types

    if (invoice % 2) == 1
      prepaid = prepaid? ? 'Prepaid_' : ''
      invoice = Confline.get_value("#{prepaid}Invoice_default").to_i
    end

    # XLSX
    i8 = (invoice >= 512) ? 512 : 0
    invoice = invoice - i8
    # Calls CSV
    i7 = (invoice >= 256) ? 256 : 0
    invoice = invoice - i7
    # By CallerID CSV
    i6 = (invoice >= 128) ? 128 : 0
    invoice = invoice - i6
    # By Destinations CSV
    i5 = (invoice >= 64) ? 64 : 0
    invoice = invoice - i5
    # By CallerID PDF
    i4 = (invoice >= 32) ? 32 : 0
    invoice = invoice - i4
    # Detailed CSV
    i3 = (invoice >= 16) ? 16 : 0
    invoice = invoice - i3
    # Detailed PDF
    i2 = (invoice >= 8) ? 8 : 0
    invoice = invoice - i2
    # Simplified CSV
    i1 = (invoice >= 4) ? 4 : 0
    invoice = invoice - i1
    # Simplified PDF
    i0 = (invoice >= 2) ? 2 : 0

    [i0, i1, i2, i3, i4, i5, i6, i7, i8]
  end

  def User.find_all_for_select(owner_id = nil, options ={})
    opts = {:select => "id, username, first_name, last_name, usertype, #{SqlExport.nice_user_sql}", :order => "nice_user"}
    opts[:select] += ", "+options[:select] unless options[:select].blank?
    if owner_id and
        if options[:exclude_owner] == true
          opts[:conditions] = ["users.owner_id = ? AND hidden=0", owner_id]
        else
          opts[:conditions] = ["users.id = ? or users.owner_id = ? AND hidden=0", owner_id, owner_id]
        end
    end

    return User.select(opts[:select]).where(opts[:conditions]).order(opts[:order]).all
  end

  def find_all_for_select(options = {})
    User.find_all_for_select(id, options)
  end

  def activecalls
    Activecall.joins("LEFT JOIN devices ON activecalls.src_device_id = devices.id OR activecalls.dst_device_id = devices.id LEFT JOIN users ON devices.user_id = users.id").where(["devices.user_id = ?", id]).all
  end

  def booth_status
    # we assume that booth is occupied if user has present calls
    @booth_status ||= if cs_invoices.any? && activecalls_since(cs_invoices.first.created_at, {:ongoing => true}).any?
                        'occupied'
                        # we assume that booth is reserved if there are invoices but there are no calls
                      elsif cs_invoices.any?
                        'reserved'
                      else
                        'free'
                      end

    @booth_status
  end

  def activecalls_since(time, options = {})
    Activecall.joins("LEFT JOIN devices ON activecalls.src_device_id = devices.id OR activecalls.dst_device_id = devices.id LEFT JOIN users ON devices.user_id = users.id").
        where(["devices.user_id = ? AND start_time > ? #{"AND answer_time IS NOT NULL" if options[:ongoing]}", id, time.strftime("%Y-%m-%d %H:%M:%S")]).all
  end

  def active_booth_calls
    returning call_count = 0 do
      active_calls = calls("answered", cs_invoices.first.created_at.strftime("%Y-%m-%d %H:%M:%S"), Time.now.strftime("%Y-%m-%d %H:%M:%S"))
      call_count = active_calls.size if active_calls.any?
    end
  end

  def can_send_sms?
    out = true
    if sms_service_active == 0 or not sms_tariff or not sms_lcr
      out = false
    end
    out
  end

  def reseller_allow_providers_tariff?
    is_reseller? && own_providers == 1
  end

  def is_allow_manage_providers?
    is_admin? || reseller_allow_providers_tariff?
  end

  def can_own_providers?
    own_providers == 1
  end


  # reseller is allowed view hangup cause statistics if he can have own providers(that mean rs pro has to be enabled)
  # and global setting allowing to view hgc statistics is set to true.
  # It would be errorneus to use this method on any other user that's type is not reseller.
  def reseller_allowed_to_view_hgc_stats?
    if !self.is_reseller?
      raise 'User type error'
    else
      Confline.get_value('Show_HGC_for_Resellers').to_i == 1 && (self.reseller_allow_providers_tariff? || !Confline.get_value('RS_Active').to_i == 1)
    end
  end

  def load_lcrs(arr = {})
    if is_accountant?
      if arr.include?(:conditions)
        arr[:conditions].first << ' AND user_id = 0 '
      else
        arr[:conditions] = 'user_id = 0'
      end

      if arr[:first].present?
        Lcr.select(arr[:select] || '*').where(arr[:conditions]).order(arr[:order]).limit(arr[:limit]).first
      else
        Lcr.select(arr[:select] || '*').where(arr[:conditions]).order(arr[:order]).limit(arr[:limit]).all
      end
    else
      if !own_providers? and is_reseller?
        if arr.include?(:conditions)
          arr[:conditions].first << " AND id = #{lcr_id} "
        else
          arr[:conditions] = "id = #{lcr_id}"
        end

        if arr[:first].present?
          Lcr.select(arr[:select] || '*').where(arr[:conditions]).order(arr[:order]).limit(arr[:limit]).first
        else
          Lcr.select(arr[:select] || '*').where(arr[:conditions]).order(arr[:order]).limit(arr[:limit]).all
        end
      else
        if arr[:first].present?

          lcrs.select(arr[:select] || '*').where(arr[:conditions]).order(arr[:order]).limit(arr[:limit]).first
        else
          lcrs.select(arr[:select] || '*').where(arr[:conditions]).order(arr[:order]).limit(arr[:limit]).all
        end
      end
    end
  end

  def safe_attributtes(params, user_id, current_user)
    if ['reseller', 'user'].include?(usertype)
      allow_params = [:time_zone ,:recording_hdd_quota, :recordings_email,:spy_device_id, :currency_id, :password, :warning_email_balance, :warning_email_hour, :first_name, :last_name, :clientid, :taxation_country, :vat_number, :acc_group_id]
      allow_params += [:accounting_number, :generate_invoice, :username, :tariff_id, :postpaid, :call_limit, :blocked, :agreement_number, :language, :warning_balance_sound_file_id, :warning_balance_call, :quickforwards_rule_id] if is_reseller? and self.id.to_i != user_id.to_i
      allow_params += [:lcr_id] if params[:lcr_id] and reseller_allow_providers_tariff? and self.id.to_i != user_id.to_i and current_user.load_lcrs({first: true, conditions: "id = #{params[:lcr_id]}"})
      unless check_for_own_providers
        allow_params +=[:hide_destination_end, :cyberplat_active]
      end
      return params.reject { |key, value| !allow_params.include?(key.to_sym) }
    else
      return params
    end
  end

  def load_providers(arr = {})
    if is_reseller?
      if arr.include?(:where)
        arr[:conditions] << " AND (user_id = #{id} OR (common_use = 1 and providers.id IN (SELECT provider_id FROM common_use_providers where reseller_id = #{id})))"
        arr[:conditions] << " AND (user_id = #{id} OR (common_use = 1 and providers.id IN (SELECT provider_id FROM common_use_providers where reseller_id = #{id})))"
      else
        arr[:conditions] = "(user_id = #{id} OR (common_use = 1 and providers.id IN (SELECT provider_id FROM common_use_providers where reseller_id = #{id})))"
      end
      Provider.select(arr[:select] || '*').where(arr[:conditions]).order(arr[:order]).all
    else
      providers.select(arr[:select] || '*').where(arr[:conditions]).order(arr[:order]).all
    end
  end

  # also counts providers for terminator
  def load_terminators
    if is_reseller?
      Terminator.find_by_sql("SELECT terminators.*, count(providers.id) AS providers_size
FROM terminators
LEFT JOIN providers ON (providers.terminator_id = terminators.id)
WHERE terminators.user_id = #{id} or providers.common_use = 1 AND providers.id IN (SELECT provider_id FROM common_use_providers where reseller_id = #{id})
GROUP BY terminators.id;")
    else
      Terminator.find_by_sql("SELECT terminators.*, count(providers.id) AS providers_size
FROM terminators
LEFT JOIN providers ON (providers.terminator_id = terminators.id)
WHERE terminators.user_id = 0
GROUP BY terminators.id;")
    end
  end

  def load_terminator(term_id)
    if is_reseller?
      Terminator.find_by_sql("SELECT terminators.* FROM terminators
WHERE terminators.id = #{term_id} AND (terminators.user_id = #{id} OR terminators.id IN
(SELECT terminator_id FROM providers WHERE providers.common_use = 1))
LIMIT 1;")[0]
    else
      Terminator.where(["terminators.id = ? AND terminators.user_id = 0", term_id]).first
    end
  end

  def load_terminators_ids
    if is_reseller?
      Terminator.find_by_sql("SELECT terminators.id
FROM terminators
LEFT JOIN providers ON (providers.terminator_id = terminators.id)
WHERE terminators.user_id = #{id} or providers.common_use = 1
GROUP BY terminators.id;").map { |t| t.id }
    else
      Terminator.where(["terminators.user_id = 0",]).all.map(&:id)
    end
  end

  def check_for_own_providers
    o = false
    if reseller_allow_providers_tariff? or (usertype == 'user' and owner and owner.reseller_allow_providers_tariff?)
      o = true
    end
    return o
  end

#(current_user.usertype == 'admin')? @users = current_user.load_users(:all, :conditions => ["users.owner_id = ?", current_user.id])  : @users = current_user.load_users(:all, {})
  def load_users(arr = {})
    if arr.include?(:select)
      arr[:select] += " #{SqlExport.nice_user_sql}"
    else
      arr[:select] = "*, #{SqlExport.nice_user_sql}"
    end

    arr[:order] = 'nice_user'

    if is_reseller?
      if arr.include?(:conditions)
        arr[:conditions] += " AND (user_id = #{id} AND hidden = 0)"
      else
        arr[:conditions] = "owner_id = #{id} AND hidden = 0"
      end
      if arr[:first].present?
        User.select(arr[:select] || '*').includes(arr[:include]).where(arr[:conditions]).order(arr[:order]).first
      else
        User.select(arr[:select] || '*').includes(arr[:include]).where(arr[:conditions]).order(arr[:order]).all
      end
    else
      current_user_id = is_accountant? ? 0 : current_user.id
      arr[:conditions] = ["users.owner_id = ?", current_user_id]
      if arr[:first].present?
        User.select(arr[:select] || '*').includes(arr[:include]).where(arr[:conditions]).order(arr[:order]).first
      else
        User.select(arr[:select] || '*').includes(arr[:include]).where(arr[:conditions]).order(arr[:order]).all
      end
    end
  end

  def load_users_devices(arr = {})
    if is_reseller?
      arr[:joins] ||= ''
      arr[:joins] += 'LEFT JOIN users ON (devices.user_id = users.id)'
      arr[:select] = 'devices.*'
      where_clause = "users.owner_id = #{id}"
      where_clause += ' AND users.hidden = 0' unless arr[:status] == 'closed'

      if arr.include?(:conditions)
          arr[:conditions] << " AND (#{where_clause})"
      else
          arr[:conditions] = where_clause
      end
    end

    if arr[:first].present?
      Device.select(arr[:select] || '*').includes(arr[:include]).where(arr[:conditions]).joins(arr[:joins]).order(arr[:order]).first
    else
      Device.select(arr[:select] || '*').includes(arr[:include]).where(arr[:conditions]).joins(arr[:joins]).order(arr[:order]).all
    end
  end

  def load_dids(arr = {})
    if is_reseller?
      if arr.include?(:conditions)
        arr[:conditions] += " AND (dids.reseller_id = #{id})"
      else
        if arr
          arr[:conditions] = "dids.reseller_id = #{id}"
        else
          arr[:conditions] = "dids.reseller_id = #{id}"
        end
      end
    end

    if arr[:first].present?
      Did.where(arr[:conditions]).order(arr[:order]).first
    else
      Did.where(arr[:conditions]).order(arr[:order]).all
    end
  end

  def User.users_order_by(params, options)
    case options[:order_by].to_s.strip
      when 'acc'
        order_by = 'users.id'
      when 'nice_user'
        order_by = 'nice_user'
      when 'user'
        order_by = 'nice_user'
      when 'username'
        order_by = 'users.username'
      when 'usertype'
        order_by = 'users.usertype'
      when 'balance'
        order_by = 'users.balance'
      when 'account_type'
        order_by = 'users.postpaid'
      else
        order_by = options[:order_by]
    end
    if order_by != ''
      order_by += (options[:order_desc].to_i == 0 ? ' ASC' : ' DESC')
    end
    return order_by
  end

  def convert_curr(rate)
    rate * User.current.currency.exchange_rate.to_d
  end

  def raw_balance
    read_attribute(:balance).to_d
  end

  def raw_balance=(value)
    write_attribute(:balance, value.to_d)
  end

  def raw_balance_min
    read_attribute(:balance_min).to_d
  end

  def raw_balance_max
    read_attribute(:balance_max).to_d
  end

  # converted attributes for user in current user currency
  def balance
    b = read_attribute(:balance)
    if User.current.try(:currency).present?
      b.to_d * User.current.currency.exchange_rate.to_d
    else
      b.to_d
    end
  end

  def balance_min
    b = read_attribute(:balance_min)
    if User.current.try(:currency).present?
      b.to_d * User.current.currency.exchange_rate.to_d
    else
      b.to_d
    end
  end

  def balance_max
    b = read_attribute(:balance_max)
    if User.current.try(:currency).present?
      b.to_d * User.current.currency.exchange_rate.to_d
    else
      b.to_d
    end
  end

  def balance= value
    if User.current.try(:currency).present?
      b = (value.to_d / User.current.currency.exchange_rate.to_d).to_d
    else
      b = value
    end
    write_attribute(:balance, b)
  end

  def balance_min= value
    if User.current.try(:currency).present?
      b = (value.to_d / User.current.currency.exchange_rate.to_d).to_d
    else
      b = value
    end
    write_attribute(:balance_min, b)
  end

  def balance_max= value
    if User.current.try(:currency).present?
      b = (value.to_d / User.current.currency.exchange_rate.to_d).to_d
    else
      b = value
    end
    write_attribute(:balance_max, b)
  end

  def credit
    credit_value = read_attribute(:credit)
    if User.current.try(:currency).present?
      credit_value.to_d != -1.to_d ? credit_value.to_d * User.current.currency.exchange_rate.to_d : -1.to_d
    else
      credit_value
    end
  end

  def daily_credit_limit
    daily_credit_limit_value = read_attribute(:daily_credit_limit)
    if User.current.try(:currency).present?
      daily_credit_limit_value.to_d != 0.to_d ? daily_credit_limit_value.to_d * User.current.currency.exchange_rate.to_d : 0.to_d
    else
      daily_credit_limit_value
    end
  end

  # TODO: prepaid user cannot have credit set especialy if credit is something invalid
  # like 20, -1 etc. maybe 0 could be set but i doubt that, cause PREPAID USER DOES
  # NOT HAVE CREDIT how is it posible to set something one does not have??? well at
  # least we should rise exception, if not hide this method. but not today cause this
  # might break to many things
  def credit= value
    #if prepaid?
    #raise "Cannot set credit for prepaid user"
    if User.current.try(:currency).present?
      c = value == -1 ? -1 : (value.to_d / User.current.currency.exchange_rate.to_d).to_d
    else
      c = value
    end
    write_attribute(:credit, c)
  end

  def daily_credit_limit= value
    if User.current.try(:currency).present?
      c = value == 0 ? 0 : (value.to_d / User.current.currency.exchange_rate.to_d).to_d
    else
      c = value
    end
    write_attribute(:daily_credit_limit, c)
  end

  def warning_email_balance
    warning_balance = read_attribute(:warning_email_balance)
    if User.current.try(:currency).present?
      warning_balance.to_d * User.current.currency.exchange_rate.to_d
    else
      warning_balance.to_d
    end
  end

  def warning_email_balance= value
    warning_balance = if User.current.try(:currency).present?
                        (value.to_d / User.current.currency.exchange_rate.to_d).to_d
                      else
                        value
                      end
    write_attribute(:warning_email_balance, warning_balance)
  end

  def warning_email_balance_admin
    warning_balance = read_attribute(:warning_email_balance_admin)
    if User.current.try(:currency).present?
      warning_balance.to_d * User.current.currency.exchange_rate.to_d
    else
      warning_balance.to_d
    end
  end

  def warning_email_balance_admin= value
    warning_balance = if User.current.try(:currency).present?
                        (value.to_d / User.current.currency.exchange_rate.to_d).to_d
                      else
                        value
                      end
    write_attribute(:warning_email_balance_admin, warning_balance)
  end

    def warning_email_balance_manager
    warning_balance = read_attribute(:warning_email_balance_manager)
    if User.current.try(:currency).present?
      warning_balance.to_d * User.current.currency.exchange_rate.to_d
    else
      warning_balance.to_d
    end
  end

  def warning_email_balance_manager= value
    warning_balance = if User.current.try(:currency).present?
                        (value.to_d / User.current.currency.exchange_rate.to_d).to_d
                      else
                         value
                      end
    write_attribute(:warning_email_balance_manager, warning_balance)
  end

  def fix_when_is_rendering
    if User.current and self
      self.balance = self.balance.to_d * User.current.currency.exchange_rate.to_d
      self.credit = self.credit.to_d * User.current.currency.exchange_rate.to_d if credit != -1
      self.daily_credit_limit = self.daily_credit_limit.to_d * User.current.currency.exchange_rate.to_d if daily_credit_limit != 0
      self.warning_email_balance = self.warning_email_balance.to_d * User.current.currency.exchange_rate.to_d
    end
  end

  def find_sound_files_for_ivrs(id = nil)
    if id
      res = ivr_sound_files.where({:ivr_voice_id => id}).all
    else
      res = ivr_sound_files
    end
    if res == nil or res.size == 0
      return {}
    else
      res = res.select(:path).distinct
    end
    res
  end

  def load_tariffs
    owner = get_correct_owner_id

    #@sms_tariffs = SmsTariff.find(:all, :conditions => "(tariff_type = 'user') AND owner_id = '#{owner}' ", :order => "tariff_type ASC, name ASC")
    Tariff.where("owner_id = '#{owner}' ").order('purpose ASC, name ASC').all
  end

  def User.create_from_registration(params, owner, reg_ip, free_ext, pin, pasw, nan, api=0)
    owner_id = owner.id
    user = Confline.get_default_object(User, owner_id)
    # to skip balance conversion like in user creation from GUI.
    user.registration = true

    user.recording_enabled = 0 if !user.recording_enabled
    user.recording_forced_enabled = 0 if !user.recording_forced_enabled
    user.username = params[:username]
    user.password = Digest::SHA1.hexdigest(params[:password])
    user.first_name = params[:first_name]

    api_call = api.to_i == 1

    if api_call
      call_limit, credit_limit = params[:call_limit], params[:credit_limit]


      params_usertype = params[:usertype]
      params_permission_group = params[:permission_group]
      params_accounting_number = params[:accounting_number]
      params_currency_id = params[:currency_id]
      params_tariff = params[:tariff]

      user.usertype = params_usertype.to_s if params_usertype.present?
      user.acc_group_id = params_permission_group.to_i if params_permission_group.present?
      user.accounting_number = params_accounting_number if params_accounting_number.present?
      user.currency_id = params_currency_id.to_i if params_currency_id.present?
      user.tariff_id = params_tariff.to_i if params_tariff.present?
      if call_limit.present?
        user.call_limit = (/^[0-9]+$/ === call_limit.to_s) ? call_limit.to_i : 0
      end
      if credit_limit.present?
        credit_limit_integer = credit_limit.to_i
        user.credit = ((credit_limit_integer == -1) || (/^[0-9]+$/ === credit_limit.to_s)) ? credit_limit_integer : 0
      end
    else
      user.credit = 0 if user.prepaid?
      user.acc_group_id = 0
      user.is_user?
    end
    user.last_name = params[:last_name]
    user.clientid = params[:client_id] if params[:client_id].to_s != ""
    user.agreement_date = Time.now.to_s(:db)
    user.agreement_number = nan
    user.vat_number = params[:vat_number] if params[:vat_number].to_s != ""
    user.owner_id = owner_id
    user.allow_loss_calls = Confline.get_value('Default_User_allow_loss_calls', owner_id)
    user.hide_non_answered_calls = Confline.get_value('Default_User_hide_non_answered_calls', owner_id).to_i
    user.allow_change_callerid = Confline.get_value('Default_User_allow_change_callerid', owner_id).to_i
    user.allow_login_receive_email = Confline.get_value('Default_User_allow_login_receive_email', owner_id).to_i


    #looking at code below and thinking 'FUBAR'? well mor currencies/money
    #is FUBAR, that's just a hack to get around. ticket #5041
    user.balance = owner.to_system_currency(owner.to_system_currency(user.balance))

    owner = User.where(:id => owner_id).first

    param_lcr_id = params[:lcr_id].to_i
    if owner_id == 0
      if owner.load_lcrs({first: true, conditions: ['id=?', param_lcr_id]})
        user.lcr_id = param_lcr_id
      end
    else
      if owner and owner.own_providers.to_i == 1
        lcr_id = Confline.get_value("Default_User_lcr_id", owner_id)
        if owner.load_lcrs({first: true, conditions: ['id=?', lcr_id]})
          lcr_id = param_lcr_id != 0 ? param_lcr_id : Confline.get_value("Default_User_lcr_id", owner_id)
          if owner.load_lcrs({first: true, conditions: ['id=?', lcr_id]})
            user.lcr_id = lcr_id
          end
        else
          user.lcr_id = owner.lcr_id if owner
        end
      else
        user.lcr_id = owner.lcr_id if owner
      end
    end


    params_country_id = params[:country_id]
    params_state = params[:state]
    params_county = params[:county]
    params_city = params[:city]
    params_postcode = params[:postcode]
    params_address = params[:address]
    params_phone = params[:phone]
    params_mob_phone = params[:mob_phone]
    params_fax = params[:fax]
    params_email = params[:email]
    params_password = params[:password]


    address = Confline.get_default_object(Address, owner_id)
    address.direction_id = params_country_id if params_country_id.present?
    address.state = params_state if params_state.present?
    address.county = params_county if params_county.present?
    address.city = params_city if params_city.present?
    address.postcode = params_postcode if params_postcode.present?
    address.address = params_address if params_address.present?
    address.phone = params_phone if params_phone.present?
    address.mob_phone = params_mob_phone if params_mob_phone.present?
    address.fax = params_fax if params_fax.present?
    address.email = params_email if params_email.present?
    address.email = nil if address.email.to_s.blank?
    address.save
    #If registering through API, taxation country by default is same
    #as country. ticket #5071
    user.taxation_country = address.direction_id

    tax = Confline.get_default_object(Tax, owner_id)
    tax.save
    user.tax = tax

    user_address_id = address.id

    user.address_id = user_address_id

    return false unless user.save
    # my_debug @user.to_yaml
    dev_group = Devicegroup.new({ user_id: user.id,
                                  address_id: user_address_id,
                                  name: 'primary',
                                  added: Time.now,
                                  primary: 1})
    dev_group.save

    dev_params = {device_type: params[:device_type], dev_group: dev_group.id, free_ext: free_ext, pin: pin}
    dev_params[:device_location_id] = params[:device_location_id] if params[:device_location_id]
    if Confline.get_value("Allow_registration_username_passwords_in_devices").to_i == 1
      dev_params.merge!({:secret => params_password, :username => user.username})
    else
      dev_params.merge!({:secret => pasw})
    end
    device = user.create_default_device(dev_params)
    free_ext = device.extension.to_s

    if params[:caller_id]
      device.callerid = '<' + params[:caller_id].to_s.strip + '>'
    end

    device.adjust_for_api(dev_params[:device_type])
    user.save

    cb = Confline.get_value('CALLB_Active').to_i == 1 ? 1 : 0

    device_id = device.id

    current_time = Time.now

    if params_mob_phone.to_s.gsub(/[^0-9]/, '').length > 0
      Callerid.create({cli: params_mob_phone.to_s.gsub(/[^0-9]/, ''), device_id: device_id, description: 'Mobile Phone', email_callback: cb, added_at: current_time})
    end
    if params_phone.to_s.gsub(/[^0-9]/, '').length > 0
      Callerid.create({cli: params_phone.to_s.gsub(/[^0-9]/, ''), device_id: device_id, description: 'Phone', email_callback: cb, added_at: current_time})
    end
    if params_fax.to_s.gsub(/[^0-9]/, '').length > 0
      Callerid.create({cli: params_fax.to_s.gsub(/[^0-9]/, ''), device_id: device_id, description: 'Fax', email_callback: cb, added_at: current_time})
    end

    begin
      variables = {params: params_password, reg_ip: reg_ip, free_ext: free_ext}
      if api_call
        a = Thread.new {
          send_email_to_user, report = EmailsController.send_user_email_after_registration(user, device, variables)
          EmailsController.send_owner_email_after_registration(user, device, variables)
          ActiveRecord::Base.connection.close
        }
      else
        send_email_to_user, report = EmailsController.send_user_email_after_registration(user, device, variables)
        EmailsController.send_owner_email_after_registration(user, device, variables)
      end
      notice = nil
      if report
     #   notice = _('Email_not_sent_because_bad_system_configurations')
      end
    end

    return user, send_email_to_user, device, notice
  end

  def User.validate_from_registration(params, owner_id = 0, api = 0)
    notice = nil
    # tmp user for model methods
    user = User.new
    user.owner_id = owner_id.to_i
    params_password = params[:password]
    params_username = params[:username]
    params_country_id = params[:country_id]

    bad_password = params_password.present? && params_password.to_s.strip.length < user.minimum_password
    strong_password = User.strong_password?(params_password) || params_password.blank?

    if params_username.to_s.blank?
      notice = _('Please_enter_username')
    end

    if User.where(["username = ?", params_username]).first && notice.blank?
      notice = _('Such_username_is_already_taken')
    end

    if params_password != params[:password2] && notice.blank?
      notice = _('Passwords_do_not_match')
    end

    if Confline.get_value("Allow_registration_username_passwords_in_devices").to_i == 1
      if params[:password].to_s.length < 8 && Confline.get_value("Allow_short_passwords_in_devices").to_i == 0
        notice = _('Device_password_is_too_short')
      end
    end

    notice = _('Password_must_be_strong') unless strong_password
    notice = _('Password_must_be_longer', (user.minimum_password-1)) if bad_password

    if params_username && params_username.to_s.strip.length < user.minimum_username
      notice = _('Username_must_be_longer', (user.minimum_username-1))
    end


    if params_password.blank? && notice.blank?
      notice = _('Please_enter_password')
    end

    if params_password == params_username && notice.blank?
      notice = _('Please_enter_password_not_equal_to_username')
    end

    if params[:first_name].blank? && notice.blank?
      notice = _('Please_enter_first_name')
    end

    if params[:last_name].blank? && notice.blank?
      notice = _('Please_enter_last_name')
    end

    if api.to_i == 1
      unless ['accountant','reseller','user'].include?(params[:usertype].to_s)
        params[:usertype] = 'user'
      end

      params_usertype = params[:usertype]

      if params_usertype == 'accountant' || params_usertype == 'reseller'
        if params[:permission_group].blank?
          notice = _('Permissions_group_not_selected')
        end
        if params[:permission_group].present? && !AccGroup.where(id: params[:permission_group].to_i, group_type: params_usertype.to_s).first
          notice = _('Permissions_group_not_found')
        end
      else
        params[:permission_group] = 0
      end
    end

    if (params_country_id.blank? || !Direction.where({:id => params_country_id}).first) && notice.blank?
      notice = _('Please_select_country')
    end

    if (params[:email].blank? || !Email.address_validation(params[:email])) && notice.blank?
      notice = _('Please_enter_email')
    end

    if Confline.get_value('allow_identical_email_addresses_to_different_users', 0).to_i == 0 && !params[:email].to_s.blank? && Address.where(['email=?', params[:email]]).first && notice.blank?
      notice = _('This_email_address_is_already_in_use')
    end

    if params[:mob_phone].to_s.gsub(/[^0-9]/, "").length > 0 && notice.blank?
      if Callerid.where({:cli => params[:mob_phone].to_s.gsub(/[^0-9]/, "")}).count.to_i > 0
        notice = _('User_with_mobile_phone_already_exists')
      end
    end

    if params[:phone].to_s.gsub(/[^0-9]/, "").length > 0 && notice.blank?
      if Callerid.where({:cli => params[:phone].to_s.gsub(/[^0-9]/, "")}).count.to_i > 0
        notice = _('User_with_phone_already_exists')
      end
    end

    if params[:fax].to_s.gsub(/[^0-9]/, "").length > 0 && notice.blank?
      if Callerid.where({:cli => params[:fax].to_s.gsub(/[^0-9]/, "")}).size > 0
        notice = _('User_with_fax_already_exists')
      end
    end

    if (!params[:device_type] || !['SIP', 'IAX2', 'Virtual'].include?(params[:device_type])) && notice.blank?
      notice = _('Enter_device_type')
    end

    param_lcr_id = params[:lcr_id]
    if param_lcr_id && (!param_lcr_id.to_s.match(/^[0-9]+$/) ||
      !user.owner.load_lcrs({ first: true, conditions: "id = #{param_lcr_id}" }))
      notice = _('Lcr_was_not_found')
    end

    dev_loc_id = params[:device_location_id]
    if dev_loc_id && !user.owner.locations.where(id: params[:device_location_id].to_i).first
      notice = _('Location_was_not_found')
    end

    u = User.where(["uniquehash = ?", params[:id]]).first
    if (!params[:id] || !u) && notice.blank?
      notice = _('Dont_be_so_smart')
    else
      if Confline.where("owner_id = #{u.id} AND name LIKE 'Default_User_%'").size.to_i == 0
        notice = _('Default_user_is_not_present')
      elsif ((!Tariff.where({:owner_id => u.id}).first || !Tariff.where({:id => Confline.get_value('Default_user_tariff_id', u.id)}).first) && notice.blank?)
        notice = _('Tariff_not_found_cannot_create')
      else
        #if u.usertype != 'reseller' && u.own_providers != 0
        u_id = u
        u_id = u = User.where(["id=?", 0]).first if u.usertype == 'reseller' && u.own_providers.to_i == 0
        if ((!u_id.lcrs.first || !u_id.lcrs.where(id: Confline.get_value('Default_user_lcr_id', u_id.id)).first) && notice.blank?)
          notice = _('Default_user_does_not_have_LCR')
        end
        #end
      end
    end

    if notice.blank? && Confline.get_value("Registration_Enable_VAT_checking", u.id).to_i == 1
      if params[:vat_number] && params_country_id
        dr = Direction.where({:id => params_country_id}).first
        if params[:vat_number].blank?
          if Confline.get_value("Registration_allow_vat_blank", u.id).to_i == 0
            notice = _('Please_fill_field_TAX_Registration_Number')
          end
        else
          dr_code_first_letters = dr.code.to_s[0..1]
          if  dr && ['BG', 'CS', 'DA', 'DE', 'EL', 'EN', 'ES', 'ET', 'FI', 'FR', 'HU', 'IT', 'LT', 'LV', 'MT', 'NL', 'PL', 'PT', 'RO', 'SK', 'SL', 'SV'].include?(dr_code_first_letters)
            notice = _('TAX_Registration_Number_is_not_valid') if  !User.check_vat_for_user(params[:vat_number], dr_code_first_letters)
          end
        end
      end
    end

    # tmp user destroy
    user.destroy

    notice
  end

  def update_from_edit(params, current_user, tax_from_params, rec_a, api = 0)
    user_old = self.dup
    pool_old = self.pbx_pool_id
    api_call = (api == 1)
    invoice_types = 0

    if api_call
      # Simplified PDF: 2, Simplified CSV: 4, Detailed PDF: 8, Detailed CSV: 16, By CallerID PDF: 32,
      # By Destinations CSV: 64, By CallerID CSV:128, Calls CSV: 256, XLSX: 512
      [:i1, :i2, :i3, :i4, :i5, :i6, :i7, :i8, :i9].each { |key| invoice_types += params[key].to_i if params[key] }
      self.send_invoice_types = invoice_types if params[:i1] || params[:i2] || params[:i3] || params[:i4] ||
        params[:i5] || params[:i6] || params[:i7] || params[:i8] || params[:i9]
    else
      [:simplified_pdf, :simplified_csv, :i2, :i3, :i4, :i5, :i6, :i7, :xlsx].each { |key| invoice_types += params[key].to_i }
      self.send_invoice_types = invoice_types
    end

    # Accountant can not modify user's pbx pool therefore set pbx_pool_id param to current user's pbx_pool_id
    if current_user.is_accountant?
      params[:user][:pbx_pool_id] = pool_old
    end

    update_extline_appdata(params[:user][:pbx_pool_id]) if pool_old != params[:user][:pbx_pool_id].to_i
    params[:user].delete(:usertype) # AS: usertype can't be changed since MOR x4
    params[:user][:routing_threshold] = params[:user][:routing_threshold].to_i
    update_attributes(current_user.safe_attributtes(params[:user], id, current_user))

    Action.add_action_hash(current_user.id, {:action => 'user_edited', :target_id => id, :target_type => "user"})
    if api_call
      if params[:unlimited] and params[:unlimited].to_i == 1
        self.credit = -1
      else
        self.credit = params[:credit].to_s.gsub(/[,;]/, '.').to_d if params[:credit]
        self.credit = 0 if credit < 0 if params[:credit]
      end
    else
      if params[:unlimited].to_i == 1 and self.postpaid == 1
        self.credit = -1
      else
        self.credit = params[:credit].to_s.gsub(/[,;]/, '.').to_d if params[:credit]
        self.credit = 0 if credit < 0
      end

      if params[:daily_unlimited].to_i == 1
        self.daily_credit_limit = 0
      else
        self.daily_credit_limit = params[:daily_credit_limit].to_s.gsub(/[,;]/, '.').to_d
        self.daily_credit_limit = 0 if daily_credit_limit < 0
      end

      if postpaid?
        #prepaid user cannot have minimal charge enabled
        #if minimal charge is 0 it means it is disabled
        #so if minimal charge is not numeric or was not even supplied we convert
        #it to 0 and dont bother any more.
        #view should take case that passed value is numeric or empty string,
        #so no need to check for that either.
        #but minimal charge daytime must be supplied if minimal charge is enabled.
        #if it is disabled set datetime to nil
        self.minimal_charge = params[:minimal_charge_value].to_i
        if params[:user][:postpaid] == 0
          self.minimal_charge = 0
          self.minimal_charge_start_at = nil
        elsif params[:minimal_charge_value].to_i != 0 and params[:minimal_charge_date]
          year = params[:minimal_charge_date][:year].to_i
          month = params[:minimal_charge_date][:month].to_i
          self.minimal_charge_start_at = Time.gm(year, month, 1, 0, 0, 0)
        elsif params[:minimal_charge_value].to_i == 0
          self.minimal_charge_start_at = nil
        else
          #set to current datetime, when saveing model, it should cause error
          #because when minimal charge is disabled datetime should be disabled
          self.minimal_charge_start_at = Time.gm(Time.now.year, Time.now.month, 1, 0, 0, 0)
        end
      end
    end

    if self and user_old
      if tariff_id.to_i != user_old.tariff_id.to_i
        tariff = nil
        tariff = Tariff.where(["id = ?", tariff_id.to_i]).first if self and tariff_id.to_i > 0
        !tariff ? tariff_name = "" : tariff_name = tariff.name

        tariff_old = nil
        tariff_old = Tariff.where(["id = ?", user_old.tariff_id.to_i]).first if user_old and user_old.tariff_id.to_i > 0
        !tariff_old ? tariff_old_name = "" : tariff_old_name = tariff_old.name

        Action.add_action_hash(current_user.id, {:action => 'user_tariff_changed', :target_id => id, :target_type => "user", :data => tariff_old_name, :data2 => tariff_name})
      end

      if user_old.user_type != user_type
        Action.add_action_hash(current_user.id, {:action => 'user_type_change_to', :target_id => id, :target_type => "user", :data => user_type})
      end

      if user_old.postpaid != postpaid
        Action.add_action_hash(current_user.id, {:action => 'postpaid_change_to', :target_id => id, :target_type => "user", :data => postpaid})
      end

      if user_old.credit != credit
        Action.add_action_hash(current_user.id, {:action => 'user_credit_change', :target_id => id, :target_type => "user", :data => user_old.credit, :data2 => credit})
      end

      if user_old.lcr_id != lcr_id
        Action.add_action_hash(current_user.id, {:action => 'user_lcr_change', :target_id => id, :target_type => "user", :data => user_old.lcr_id, :data2 => lcr_id})
      end

      update_voicemail_boxes if (user_old.first_name != first_name) or (user_old.last_name != last_name)
    end


    params_password = params[:password].try(:[], :password)
    self.password = Digest::SHA1.hexdigest(params_password) if params_password.present?

    if (api_call and params[:agr_date][:year] and params[:agr_date][:month] and params[:agr_date][:day]) or api != 1
      self.agreement_date = params[:agr_date][:year].to_s + '-' + params[:agr_date][:month].to_s + "-" + params[:agr_date][:day].to_s if params[:agr_date]
    end


    params_block_at_date = params[:block_at_date]
    params_block_at_date_year = params_block_at_date[:year] if params_block_at_date
    params_block_at_date_month = params_block_at_date[:month] if params_block_at_date
    params_block_at_date_day = params_block_at_date[:day] if params_block_at_date
    if (api_call and params_block_at_date_year and params_block_at_date_month and params_block_at_date_day) or api != 1
      self.block_at = params_block_at_date_year.to_s + "-" + params_block_at_date_month.to_s + "-" + params_block_at_date_day.to_s if params_block_at_date
    end

    params_block_at_conditional = params[:block_at_conditional]
    if (api_call and params_block_at_conditional) or api != 1
      self.block_at_conditional = params_block_at_conditional.to_i
    end

    params_allow_loss_calls = params[:allow_loss_calls]
    if (api_call and params_allow_loss_calls) or api != 1
      self.allow_loss_calls = params_allow_loss_calls.to_i
    end

    params_allow_change_callerid = params[:allow_change_callerid]
    if (api_call && params_allow_change_callerid) || api != 1 && !current_user.is_accountant?
      self.allow_change_callerid = params_allow_change_callerid.to_i
    end

    params_hide_non_answered_calls = params[:hide_non_answered_calls]
    if (api_call && params_hide_non_answered_calls) || api != 1 && !current_user.is_accountant?
      self.hide_non_answered_calls = params_hide_non_answered_calls.to_i
    end

    params_warning_email_active = params[:warning_email_active]
    if (api_call and params_warning_email_active) or api != 1
      self.warning_email_active = params_warning_email_active.to_i
    end

    params_warning_email_balance = params[:warning_email_balance]
    if (api_call and params_warning_email_balance) or api != 1
      self.warning_email_sent = 0 if warning_email_balance.to_d != params_warning_email_balance.to_d
    end

    params_show_zero_calls = params[:show_zero_calls]
    if (api_call and params_show_zero_calls) or api != 1
      self.invoice_zero_calls = params_show_zero_calls.to_i
    end

    allow_login_receive_email = params[:allow_login_receive_email]
    if (api_call && allow_login_receive_email) or api != 1
      self.allow_login_receive_email = allow_login_receive_email.to_i
    end

    stats_from_user_perspective = params[:user][:stats_from_user_perspective]
 	if (api_call && stats_from_user_perspective) or api != 1
 		self.stats_from_user_perspective = stats_from_user_perspective.to_i
 	end
    #provider = params[:provider].to_i

    #self.tax = Tax.new(tax_from_params)
    #self.tax.save

    unless self.tax
      self.assign_default_tax
    end

    self.tax.update_attributes(tax_from_params)
    self.tax.save

    if is_reseller?
      if (api_call and params[:own_providers]) or api != 1
        self.own_providers = params[:own_providers].to_i
      end

      # force resellers to have uniquehash
      self.uniquehash = ApplicationController::random_password(10) if self.uniquehash.to_s.blank?

      # this piece of code is not necessary because following code changes lcr_id for all user of reseller
      # change LCR for all users of reseller
      if user_old.own_providers.to_i != self.own_providers.to_i and params[:own_providers].to_i == 1
        new_blank_lcr = Lcr.create(name: 'BLANK', user_id: self.id)

        User.where(["owner_id = ?", id]).all.each { |res_user|
          res_user.lcr_id = new_blank_lcr.id
          res_user.save
        }

        Cardgroup.where(["owner_id = ?", id]).all.each { |cg|
          cg.lcr_id = new_blank_lcr.id
          cg.save
        }
      elsif params[:own_providers].to_i == 0
        Action.add_action_hash(current_user.id, {:action => 'reseller_lcr_change', :target_id => id, :target_type => "user", :data => user_old.lcr_id, :data2 => lcr_id})

        User.where(["owner_id = ?", id]).all.each { |res_user|
          res_user.lcr_id = lcr_id
          res_user.save
        }

        Cardgroup.where(["owner_id = ?", id]).all.each { |cg|
          cg.lcr_id = lcr_id
          cg.save
        }
      end
    end

    # if admin changes partners lcr_id, lcr_id must be changed for resellers that partner owns
    # and for users that those resellers owns if thay are not rspro
    if is_partner?
      User.where(owner_id: id).all.each do |partner_user|
        partner_user.lcr_id = lcr_id
        partner_user.save

        if partner_user.own_providers.to_i == 0
          User.where(owner_id: partner_user.id).all.each do |partner_user_user|
            partner_user_user.lcr_id = lcr_id
            partner_user_user.save
          end
        end
      end
    end

    if (api_call and params[:block_conditional_use]) or api != 1
      self.block_conditional_use = params[:block_conditional_use].to_i
    end

    if rec_a
      if (api_call and params[:recording_enabled]) or api != 1 && !current_user.is_accountant?
        self.recording_enabled = params[:recording_enabled].to_i
      end

      if (api_call and params[:recording_forced_enabled]) or api != 1 && !current_user.is_accountant?
        self.recording_forced_enabled = params[:recording_forced_enabled].to_i
      end

      if (api_call and params[:user][:recording_hdd_quota]) or api != 1 && !current_user.is_accountant?
        self.recording_hdd_quota = params[:user][:recording_hdd_quota].to_d * 1048576
      end
    end

	  if address
      address.update_attributes(params[:address])
    else
      a = Address.create(params[:address])
      self.address_id = a.id
    end

    self.responsible_accountant_id = ((params[:user][:responsible_accountant_id].to_i < 1) ? self.responsible_accountant_id : params[:user][:responsible_accountant_id].to_i)
    if params[:warning_email_active]
      if params[:user] and params[:date]
        self.warning_email_hour = params[:user][:warning_email_hour].to_i != -1 ? params[:date][:user_warning_email_hour].to_i : params[:user][:warning_email_hour].to_i
      end
    end

    if pool_old != params[:user][:pbx_pool_id].to_i
      asterisk_reload_devices
      update_context_for_user(self, params[:user][:pbx_pool_id], pool_old)
      self.update_voicemail_boxes_mailbox(params[:user][:pbx_pool_id])
      self.update_voicemail_extlines(params[:user][:pbx_pool_id])
    end
    user_pbx_pool_id = params[:user][:pbx_pool_id]
    self.pbx_pool_id = ((user_pbx_pool_id.to_i < 0 || !user_pbx_pool_id.present?) ? self.pbx_pool_id : params[:user][:pbx_pool_id].to_i)

    self.comment = params[:user][:comment]
    self.simple_user_group_id = params[:simple_user_group_id] if params[:simple_user_group_id].present? && is_user?
    self.save
    self
  end

  def validate_from_update(current_user, params, allow_edit, api = 0)
    notice = ''
    co = current_user.is_accountant? ? 0 : current_user.id
    if current_user.is_accountant? and !allow_edit
      notice = _('You_have_no_editing_permission')
    end

    if current_user.is_reseller? and !params[:user][:usertype].blank? and params[:user][:usertype].to_s != "user"
      notice = _('Dont_be_so_smart')
    end

    if current_user.is_accountant? and !params[:user][:usertype].blank? and params[:user][:usertype] == "admin"
      notice = _('Dont_be_so_smart')
    end

    params_tariff_id = params[:user][:tariff_id]
    if current_user.is_reseller? && (Confline.reseller_can_use_admins_rates? || tariff_id.to_s == params_tariff_id)
      tariff = Tariff.where({:id => params_tariff_id, :owner_id => [co, 0]}).where("purpose != 'provider'").first
    else
      tariff = Tariff.where({:id => params_tariff_id, :owner_id => co}).first
    end

    if !params_tariff_id.blank? and !tariff
      notice = _('Tariff_not_found')
    end

    if params[:user][:pbx_pool_id] and (params[:user][:pbx_pool_id].to_i != 0) and !PbxPool.where(id: params[:user][:pbx_pool_id], owner_id: current_user.id).first
      notice = _('pbx_pool_was_not_found')
    end

    params_pswd = params[:pswd]
    notice = _('Password_must_be_strong') unless User.strong_password?(params_pswd) || params_pswd.blank?

    if params_pswd.present? && params_pswd.to_s.strip.length < self.minimum_password
      notice = _('Password_must_be_longer', (self.minimum_password-1))
    end

    if params[:u9] and params[:u9].strip.length < self.minimum_username
      notice = _('Username_must_be_longer', (self.minimum_username-1))
    end

    param_lcr_id = params[:u1]
    if param_lcr_id and !owner.load_lcrs({first: true, conditions: ['id=?', param_lcr_id]})
      notice = _('Lcr_was_not_found')
    end

    param_u31 = params[:u31]

    if param_u31
      if !is_user_viable_for_res_acc?(param_u31, params[:user_id], current_user) || param_u31 == '-1'
         params[:user][:responsible_accountant_id] = param_u31
      else
        notice = _('Responsible_accountant_is_invalid')
      end
    end

    params_quickforward_rule_id = params[:user][:quickforwards_rule_id]
    if params_quickforward_rule_id && params_quickforward_rule_id.to_i != 0
      if (Confline.get_value('Allow_Resellers_to_use_Admin_Quick_Forward_Rules').to_i == 1) || (quickforwards_rule_id == params_quickforward_rule_id.to_i)
        user_id = [current_user.id, 0]
      else
        user_id = current_user.id
      end

      rule = QuickforwardsRule.where(id: params_quickforward_rule_id, user_id: user_id).first

      notice = 'Quickforward Rule was not found' unless rule
    end

    params[:user] = params[:user].each_value(&:strip!)
    params[:address] = params[:address].each_value(&:strip!) if params[:address]

    params[:user] = User.default_blacklist_params(params[:user])

    params[:user].delete(:balance)

    if (api == 1 and params[:user][:generate_invoice]) or api != 1
      params[:user][:generate_invoice] = params[:user][:generate_invoice].to_i == 1 ? 1 : 0
    end

    if (api == 1 and params[:user][:cyberplat_active]) or api != 1
      params[:user][:cyberplat_active] = params[:cyberplat_active].to_i == 1 ? 1 : 0
    end

    if params[:user][:call_limit]
      params[:user][:call_limit] = params[:user][:call_limit].strip.to_i < 0 ? 0 : params[:user][:call_limit].strip
    end

    params[:user][:stats_from_user_perspective] = params[:user][:stats_from_user_perspective].to_i > 0 ? 1 : 0 if params[:user][:stats_from_user_perspective]

    if (api == 1 and params[:accountant_type]) or api != 1
      params[:user][:acc_group_id] = ["accountant", "reseller"].include?(params[:user][:usertype]) ? params[:accountant_type].to_i : (0 if api != 1)
    end

    # privacy
    if params[:privacy]
      if api == 1
        params[:user][:hide_destination_end] = !params[:privacy][:gui] and !params[:privacy][:csv] and !params[:privacy][:pdf] ? (-1 if params[:privacy][:global].to_i == 1) : params[:privacy].values.sum { |v| v.to_i }
      else
        params[:user][:hide_destination_end] = params[:privacy][:global].to_i == 1 ? -1 : params[:privacy].values.sum { |v| v.to_i }
      end
    end

    params[:usertype] = usertype if params[:usertype] and !['user', 'accountant', 'reseller'].include?(params[:usertype])

    ['tax2_enabled', 'tax3_enabled', 'tax4_enabled', 'own_providers', 'recording_enabled', 'recording_forced_enabled',
     'compound_tax', 'show_zero_calls', 'unlimited', 'daily_unlimited', 'block_conditional_use', 'warning_email_active'].each { |p|
      params[p.to_sym] = params[p.to_sym].to_i > 0 ? 1 : (0 if params[p.to_sym])
      }

    params[:user][:warning_balance_call] = params[:user][:warning_balance_call].to_i > 0 ? 1 : 0 if params[:user][:warning_balance_call]
    params[:user][:generate_invoice] = params[:user][:generate_invoice].to_i > 0 ? 1 : 0 if params[:user][:generate_invoice]
    params[:user][:billing_period] = ['weekly', 'bi-weekly', 'monthly'].include?(params[:billing_period]) ? params[:billing_period].to_s : 'monthly'
    params[:user][:invoice_grace_period] = params[:invoice_grace_period] if params[:invoice_grace_period]
    params[:user][:postpaid] = (params[:user][:postpaid].to_i > 0) ? 1 : 0 if params[:user][:postpaid]
    params[:user][:hidden] = params[:user][:hidden].to_i > 0 ? 1 : 0 if params[:user][:hidden]
    params[:user][:blocked] = params[:user][:blocked].to_i > 0 ? 1 : 0 if params[:user][:blocked]
    params[:user][:hide_non_answered_calls] = params[:user][:hide_non_answered_calls].to_i > 0 ? 1 : 0 if params[:user][:hide_non_answered_calls]
    params[:user][:allow_change_callerid] = params[:user][:allow_change_callerid].to_i > 0 ? 1 : 0 if params[:user][:allow_change_callerid]
    params[:privacy][:global] = params[:privacy][:global].to_i > 0 ? 1 : 0 if params[:privacy]
    params[:user][:allow_login_receive_email] = params[:user][:allow_login_receive_email].to_i > 0 ? 1 : 0 if params[:user][:allow_login_receive_email]

    if current_user.is_accountant?
      s ={}
      group = current_user.acc_group
      rights = AccRight.select("acc_rights.name, acc_group_rights.value").
          joins("LEFT JOIN acc_group_rights ON (acc_group_rights.acc_right_id = acc_rights.id AND acc_group_rights.acc_group_id = #{group.id})").
          where("acc_rights.right_type = 'accountant'").all

      short = {"accountant" => "acc", "reseller" => "res"}
      rights.each { |right|
        name = "#{short[current_user.usertype]}_#{right[:name].downcase}".to_sym
        if right[:value].nil?
          s[name] = 0
        else
          s[name] = ((right[:value].to_i >= 2 and group.only_view) ? 1 : right[:value].to_i)
        end
      }

      params = current_user.sanitize_user_params_by_accountant_permissions(s, params, self.dup)
      #'user[warning_balance_call]', 'user[generate_invoice]', 'privacy[global]',
    end

    return notice, params
  end

  def sanitize_user_params_by_accountant_permissions(session, params, user = nil)
    if is_accountant?
      if session[:acc_user_create_opt_1] != 2
        params[:password] = nil
      end
      {:acc_user_create_opt_2 => [:usertype],
       :acc_user_create_opt_3 => [:lcr_id],
       :acc_user_create_opt_4 => [:tariff_id],
       :acc_user_create_opt_5 => [:balance],
       :acc_user_create_opt_6 => [:postpaid, :hidden],
       :acc_user_create_opt_7 => [:call_limit]
      }.each { |option, fields|
        fields.each { |field| params[:user].except!(field) if session[option] != 2 }
      }
      params[:password] = nil if user and user.is_admin?
    end

    params
  end

  def sanitize_device_params_by_accountant_permissions(session, params, user = nil)
    if is_accountant?
      params[:device] = params[:device].except(:pin) if session[:acc_device_pin].to_i != 2 if params[:device]
      params[:device] = params[:device].except(:extension) if session[:acc_device_edit_opt_1] != 2 if params[:device]
      if session[:acc_device_edit_opt_2] != 2 and params[:device]
        params[:device] = params[:device].except(:name)
        params[:device] = params[:device].except(:secret)
      end
      params = params.except(:cid_name) if session[:acc_device_edit_opt_3] != 2 if !params.blank?
      params = params.except(:cid_number) if session[:acc_device_edit_opt_4] != 2 if !params.blank?
    end
    params
  end

  def dids_for_select(status = nil)
    cond = ["dids.id > 0"]
    var = []
    cond << "dids.reseller_id = ?" and var << id if is_reseller?
    cond << "status = '#{status}' and reseller_id = 0" if !status.blank? and status == 'free'
    cond << "device_id != 0 or dialplan_id != 0" if !status.blank? and status == 'assigned'
    Did.where([cond.join(" AND ")].concat(var)).order("dids.did ASC")
  end

  def show_active_calls?
    (['user', 'reseller'].include?(usertype) and Confline.get_value("Show_Active_Calls_for_Users").to_i == 1) or ['admin', 'accountant'].include?(usertype)
  end

  def check_translation
    trans = Translation.joins("LEFT JOIN (select translation_id from user_translations where user_id = #{id}) as ua ON (translations.id = translation_id )").where("ua.translation_id is null").all
    if trans and trans.size.to_i > 0
      trans.each { |t|
        u = UserTranslation.new({:translation_id => t.id, :user_id => id, :position => t.position, :active => 0})
        u.save
      }
    end
  end

  def user_time(time)
    time + time_offset.second
  end

  #class << self # Class methods
  #  alias :all_columns :columns
  #  def columns
  #    all_columns.reject {|c| c.name == 'time_zone'}
  #  end
  #end

  # def time_zone
  #   self[:time_zone]
  # end

  # def time_zone=(s)
  #   self[:time_zone] = s
  # end

 # *Returns*
 #  integer - difference in hours between user time and system time
  def time_offset
    Time.zone.now.utc_offset().second - Time.now.utc_offset().second
  end

  def system_time(time, only_date = 0)
    t = time.class == 'Time' ? time : time.to_time
    if only_date == 0
      (t - Time.zone.now.utc_offset().second + Time.now.utc_offset().second).to_s(:db)
    else
      (t - Time.zone.now.utc_offset().second + Time.now.utc_offset().second).to_date.to_s(:db)
    end
  end

  def User.get_zones
    # Keys are Rails TimeZone names, values are TZInfo identifiers
    m = [
        ["(GMT-11:00) International Date Line West, Midway Island, Samoa", "International Date Line West", -11.0],
        #["(GMT-11:00) Midway Island"	,	"Midway Island", -11],
        #["(GMT-11:00) Samoa"	,	"Samoa", -11],
        ["(GMT-10:00) Hawaii", "Hawaii", -10.0],
        ["(GMT-09:00) Alaska", "Alaska", -9.0],
        ["(GMT-08:00) Pacific Time (US & Canada), Tijuana", "Pacific Time (US & Canada)", -8.0],
        #["(GMT-08:00) Tijuana"	,	"Tijuana", -8],
        ["(GMT-07:00) Arizona, Chihuahua, Mazatlan, Mountain Time (US & Canada)", "Arizona", -7.0],
        #["(GMT-07:00) Chihuahua"	,	"Chihuahua", -7],
        #["(GMT-07:00) Mazatlan"	,	"Mazatlan", -7],
        #["(GMT-07:00) Mountain Time (US & Canada)"	,	"Mountain Time (US & Canada)", -7],
        ["(GMT-06:00) Central Time (US & Canada), Guadalajara, Mexico City, Saskatchewan", "Central America", -6.0],
        #["(GMT-06:00) Central Time (US & Canada)"	,	"Central Time (US & Canada)", -6],
        #["(GMT-06:00) Guadalajara"	,	"Guadalajara", -6],
        #["(GMT-06:00) Mexico City"	,	"Mexico City", -6],
        #["(GMT-06:00) Monterrey"	,	"Monterrey", -6],
        #["(GMT-06:00) Saskatchewan"	,	"Saskatchewan", -6],
        ["(GMT-05:00) Bogota, Eastern Time (US & Canada), Indiana (East), Lima, Quito", "Bogota", -5.0],
        #["(GMT-05:00) Eastern Time (US & Canada)"	,	"Eastern Time (US & Canada)", -5],
        #["(GMT-05:00) Indiana (East)"	,	"Indiana (East)", -5],
        #["(GMT-05:00) Lima"	,	"Lima", -5],
        #["(GMT-05:00) Quito"	,	"Quito", -5],
        ["(GMT-04:30) Caracas", "Caracas", -4.5],
        ["(GMT-04:00) Atlantic Time (Canada), Georgetown, La Paz, Santiago", "Atlantic Time (Canada)", -4.0],
        #			["(GMT-04:00) Georgetown"	,	"Georgetown", -4],
        #			["(GMT-04:00) La Paz"	,	"La Paz", -4],
        #			["(GMT-04:00) Santiago"	,	"Santiago", -4],
        ["(GMT-03:30) Newfoundland", "Newfoundland", -3.5],
        ["(GMT-03:00) Brasilia, Buenos Aires, Greenland", "Brasilia", -3.0],
        #			["(GMT-03:00) Buenos Aires"	,	"Buenos Aires", -3],
        #			["(GMT-03:00) Greenland"	,	"Greenland", -3],
        ["(GMT-02:00) Mid-Atlantic", "Mid-Atlantic", -2.0],
        ["(GMT-01:00) Azores, Cape Verde Is", "Azores", -1.0],
        #			["(GMT-01:00) Cape Verde Is."	,	"Cape Verde Is.", -1],
        ["(GMT+00:00) Casablanca, Dublin, Edinburgh, Lisbon, London, Monrovia", "Casablanca", 0.0],
        #			["(GMT+00:00) Dublin"	,	"Dublin", 0],
        #			["(GMT+00:00) Edinburgh"	,	"Edinburgh", 0],
        #			["(GMT+00:00) Lisbon"	,	"Lisbon", 0],
        #			["(GMT+00:00) London"	,	"London", 0],
        #			["(GMT+00:00) Monrovia"	,	"Monrovia", 0],
        #["(GMT+00:00) UTC"	,	"UTC", 0],
        ["(GMT+01:00) Amsterdam, Belgrade, Berlin, Madrid, Paris, Prage,  Rome ", "Amsterdam", 1.0],
        #			["(GMT+01:00) Belgrade"	,	"Belgrade", 1],
        #			["(GMT+01:00) Berlin"	,	"Berlin", 1],
        #			["(GMT+01:00) Bern"	,	"Bern", 1],
        #			["(GMT+01:00) Bratislava"	,	"Bratislava", 1],
        #			["(GMT+01:00) Brussels"	,	"Brussels",1],
        #			["(GMT+01:00) Budapest"	,	"Budapest",1],
        #			["(GMT+01:00) Copenhagen"	,	"Copenhagen",1],
        #			["(GMT+01:00) Ljubljana"	,	"Ljubljana",1],
        #			["(GMT+01:00) Madrid"	,	"Madrid",1],
        #			["(GMT+01:00) Paris"	,	"Paris",1],
        #			["(GMT+01:00) Prague"	,	"Prague",1],
        #			["(GMT+01:00) Rome"	,	"Rome",1],
        #			["(GMT+01:00) Sarajevo"	,	"Sarajevo",1],
        #			["(GMT+01:00) Skopje"	,	"Skopje",1],
        #			["(GMT+01:00) Stockholm"	,	"Stockholm",1],
        #			["(GMT+01:00) Vienna"	,	"Vienna",1],
        #			["(GMT+01:00) Warsaw"	,	"Warsaw",1],
        #			["(GMT+01:00) West Central Africa"	,	"West Central Africa",1],
        #			["(GMT+01:00) Zagreb"	,	"Zagreb",1],
        ["(GMT+02:00) Athens, Cairo, Helsinki, Istanbul, Kyiv, Minsk, Riga, Tallinn, Vilnius", "Athens", 2.0],
        #			["(GMT+02:00) Bucharest"	,	"Bucharest",2],
        #			["(GMT+02:00) Cairo"	,	"Cairo",2],
        #			["(GMT+02:00) Harare"	,	"Harare",2],
        #			["(GMT+02:00) Helsinki"	,	"Helsinki",2],
        #			["(GMT+02:00) Istanbul"	,	"Istanbul",2],
        #			["(GMT+02:00) Jerusalem"	,	"Jerusalem",2],
        #			["(GMT+02:00) Kyiv"	,	"Kyiv",2],
        #			["(GMT+02:00) Minsk"	,	"Minsk",2],
        #			["(GMT+02:00) Pretoria"	,	"Pretoria",2],
        #			["(GMT+02:00) Riga"	,	"Riga",2],
        #			["(GMT+02:00) Sofia"	,	"Sofia",2],
        #			["(GMT+02:00) Tallinn"	,	"Tallinn",2],
        #			["(GMT+02:00) Vilnius"	,	"Vilnius",2],
        ["(GMT+03:00) Baghdad, Kuwait, Nairobi, Riyadh", "Baghdad", 3.0],
        #			["(GMT+03:00) Kuwait"	,	"Kuwait",3],
        #			["(GMT+03:00) Nairobi"	,	"Nairobi",3],
        #			["(GMT+03:00) Riyadh"	,	"Riyadh",3],
        ["(GMT+03:30) Tehran", "Tehran", 3.5],
        ["(GMT+04:00) Abu Dhabi, Baku, Moscow, Muscat, Tbilisi, Volgograd, Yerevan", "Abu Dhabi", 4.0],
        #			["(GMT+04:00) Baku"	,	"Baku",4],
        #			["(GMT+04:00) Moscow"	,	"Moscow",4],
        #			["(GMT+04:00) Muscat"	,	"Muscat",4],
        #			["(GMT+04:00) St. Petersburg"	,	"St. Petersburg",4],
        #			["(GMT+04:00) Tbilisi"	,	"Tbilisi",4],
        #			["(GMT+04:00) Volgograd"	,	"Volgograd",4],
        #			["(GMT+04:00) Yerevan"	,	"Yerevan",4],
        #["(GMT+04:30) Kabul"	,	"Kabul",4.5],
        ["(GMT+05:00) Islamabad, Karachi, Tashkent", "Islamabad", 5.0],
        #			["(GMT+05:00) Karachi"	,	"Karachi",5],
        #			["(GMT+05:00) Tashkent"	,	"Tashkent",5],
        ["(GMT+05:30) Chennai, Kolkata, Mumbai, New Delhi, Sri Jayawardenepura", "Chennai", 5.5],
        #["(GMT+05:30) Kolkata"	,	"Kolkata",5.5],
        #["(GMT+05:30) Mumbai"	,	"Mumbai",5.5],
        #["(GMT+05:30) New Delhi"	,	"New Delhi",5.5],
        #["(GMT+05:30) Sri Jayawardenepura"	,	"Sri Jayawardenepura",5.5],
        ["(GMT+05:45) Kathmandu", "Kathmandu", 5.75],
        ["(GMT+06:00) Almaty, Astana, Dhaka, Ekaterinburg", "Almaty", 6.0],
        #			["(GMT+06:00) Astana"	,	"Astana",6],
        #			["(GMT+06:00) Dhaka"	,	"Dhaka",6],
        #			["(GMT+06:00) Ekaterinburg"	,	"Ekaterinburg",6],
        ["(GMT+06:30) Rangoon", "Rangoon", 6.5],
        ["(GMT+07:00) Bangkok, Hanoi, Jakarta, Novosibirsk", "Bangkok", 7.0],
        #			["(GMT+07:00) Hanoi"	,	"Hanoi",7],
        #			["(GMT+07:00) Jakarta"	,	"Jakarta",7],
        #			["(GMT+07:00) Novosibirsk"	,	"Novosibirsk",7],
        ["(GMT+08:00) Beijing, Hong Kong, Krasnoyarsk, Kuala Lumpur, Perth, Singapore, Taipei", "Beijing", 8.0],
        #			["(GMT+08:00) Chongqing"	,	"Chongqing",8],
        #			["(GMT+08:00) Hong Kong"	,	"Hong Kong",8],
        #			["(GMT+08:00) Krasnoyarsk"	,	"Krasnoyarsk",8],
        #			["(GMT+08:00) Kuala Lumpur"	,	"Kuala Lumpur",8],
        #			["(GMT+08:00) Perth"	,	"Perth",8],
        #			["(GMT+08:00) Singapore"	,	"Singapore",8],
        #			["(GMT+08:00) Taipei"	,	"Taipei",8],
        #			["(GMT+08:00) Ulaan Bataar"	,	"Ulaan Bataar",8],
        #			["(GMT+08:00) Urumqi"	,	"Urumqi",8],
        ["(GMT+09:00) Irkutsk, Osaka, Sapporo, Seoul, Tokyo", "Irkutsk", 9.0],
        #			["(GMT+09:00) Osaka"	,	"Osaka",9],
        #			["(GMT+09:00) Sapporo"	,	"Sapporo",9],
        #			["(GMT+09:00) Seoul"	,	"Seoul",9],
        #			["(GMT+09:00) Tokyo"	,	"Tokyo",9],
        ["(GMT+09:30) Adelaide, Darwin", "Adelaide", 9.5],
        #["(GMT+09:30) Darwin"	,	"Darwin",9.5],
        ["(GMT+10:00) Brisbane, Canberra, Hobart, Melbourne, Port Moresby, Sydney, Yakutsk", "Brisbane", 10.0],
        #			["(GMT+10:00) Canberra"	,	"Canberra",10],
        #			["(GMT+10:00) Guam"	,	"Guam",10],
        #			["(GMT+10:00) Hobart"	,	"Hobart",10],
        #			["(GMT+10:00) Melbourne"	,	"Melbourne",10],
        #			["(GMT+10:00) Port Moresby"	,	"Port Moresby",10],
        #			["(GMT+10:00) Sydney"	,	"Sydney",10],
        #			["(GMT+10:00) Yakutsk"	,	"Yakutsk",10],
        ["(GMT+11:00) New Caledonia, Vladivostok", "New Caledonia", 11.0],
        #			["(GMT+11:00) Vladivostok"	,	"Vladivostok",11],
        ["(GMT+12:00) Auckland, Fiji, Kamchatka, Magadan, Marshall Is., Solomon Is., Wellington", "Auckland", 12.0],
        #			["(GMT+12:00) Fiji"	,	"Fiji",12],
        #			["(GMT+12:00) Kamchatka"	,	"Kamchatka",12],
        #			["(GMT+12:00) Magadan"	,	"Magadan",12],
        #			["(GMT+12:00) Marshall Is."	,	"Marshall Is.",12],
        #			["(GMT+12:00) Solomon Is."	,	"Solomon Is.",12],
        #			["(GMT+12:00) Wellington"	,	"Wellington",12],
        ["(GMT+13:00) Nuku'alofa", "Nuku'alofa", 13.0]]
    #}.each { |name, zone| name.freeze; zone.freeze }
    #m #.freeze.sort
  end

=begin rdoc
  check wheter user can see did in active calls. only admin has right to set this option, so
  what all users(resellers) will see depends only on admins settings

  *Returns*
  * +boolean+ - true or false depending on admin's settings
=end
  def active_calls_show_did?
    Confline.active_calls_show_did?
  end

  def minimum_password
    min = Confline.get_value("Default_User_password_length", self.get_correct_owner_id_if_reseller).to_i
    min = 6 if min < 6
    min = 8 if min < 8 && User.use_strong_password?
    min
  end

  def minimum_username
    min = Confline.get_value("Default_User_username_length", self.get_correct_owner_id_if_reseller).to_i
    min = 1 if min < 1
    min
  end

  def alow_device_types_dahdi_virt
    return (usertype != "reseller" or (Confline.get_value("Resellers_Allow_Use_dahdi_Device", 0).to_i != 0)), (usertype != "reseller" or (Confline.get_value("Resellers_Allow_Use_Virtual_Device", 0).to_i != 0))
  end

  def get_correct_owner_id_if_reseller
    owner.is_reseller? ? owner_id : 0
  end

  def get_correct_owner_id
    if is_accountant? || is_admin?
      return 0
    elsif is_reseller? || is_partner?
      return id
    else
      return owner_id
    end
  end

  # This method is for api. It was changed because parter api settings comes from admin
  def get_correct_owner_id_for_api
    if is_accountant? || is_admin?
      return 0
    elsif is_reseller?
      return id
    else
      return owner_id
    end
  end

  def get_corrected_owner_id
    (is_accountant? || is_admin?) ? 0 : id
  end

  def get_price_calculation_sqls
    if is_reseller? or owner_id != 0
      up = SqlExport.user_price_sql
      rp = SqlExport.reseller_price_sql
      pp = SqlExport.reseller_provider_price_sql
    else
      up = SqlExport.admin_user_price_sql
      rp = SqlExport.admin_reseller_price_sql
      pp = SqlExport.admin_provider_price_sql
    end
    return up, rp, pp
  end

  def invoice_zero_calls_sql(up = 'calls.user_price')
    invoice_zero_calls.to_i == 0 ? " AND #{up} > 0 " : ""
  end


  # Check whether postpaid user has unlimited credit.
  # TODO: there is smth fishy in db, postpaid users user.credit is equals
  # to -1. so guess what result would this method return if you would ask
  # postpaid user whehter he has unlimited credit. TRUE!! but this is standard
  # in mor, fixing this might break smth.
  # TODO: should i raise exception if user is not prepaid? conceptualy
  # prepaid user cannot event know about such thing as unlimited credit,
  # he does not event have credit. this might break a lot of things.
  def credit_unlimited?
    #if prepaid?
    #  raise "Prepaid users do not have credit"
    credit == -1
  end

  def daily_credit_unlimited?
    daily_credit_limit == 0
  end

=begin
  Check whether user is of postpaid type

  *Returns*
  *boolean* - true or false depending on wheter user is postpaid
=end
  def postpaid?
    postpaid.to_i == 1
  end

=begin
  Check whether user is of prepaid type

  *Returns*
  *boolean* - true or false depending on wheter user is prepaid
=end
  def prepaid?
    not postpaid?
  end

=begin
  Information whether user is postpaid or prepaid in database is saved in database
  in as int - 0 for prepaid, 1 for postpaid. prepaid user cannot have any credit, so it
  is set to 0.
  Notice that 1)credit is set to 0 when user is set to prepaid and 2) when credit is set
  we check whether user is prepaid(and should rise exception) or not.
  TODO: should express to others that though i doublt whether it has any sense, cause user
  does not have credit(NULL, VOID etc), but not has credit equal to 0.
=end
  def set_prepaid
    credit = 0
    postpaid = 0
  end

  # Information whether user is postpaid or prepaid in database is saved in database
  # in as int - 0 for prepaid, 1 for postpaid.
  def set_postpaid
    postpaid = 1
  end

=begin
  Check whether minimal charge for this user is enabled

  *Returns*
  *boolean* - true or false depending on wheter minimal charge is enabled or disabled
=end
  def minimal_charge_enabled?
    minimal_charge != 0
  end

  # converted attributes for user in given currency exrate
  def converted_minimal_charge(exr)
    b = read_attribute(:minimal_charge)
    b.to_d * exr.to_d
  end

=begin
  havin issues trying to turn off rails timezone conversion, but writing
  attribute manual helps to sovle this issue.
=end
  def minimal_charge_start_at=(value)
    value = (value.respond_to?(:strftime) ? value.strftime('%F %H:%M:%S') : value)
    write_attribute(:minimal_charge_start_at, value)
  end

=begin
  Check whether minimal charge should be added to invoice. answer depends on whether
  minimal charge is enabled and whether invoice period is greater than setting when
  to start chargeing minimal amount. but user cannot definetly decide that - he knows
  only that minimal charge is enabled or not and that it would be logical to add minimal amount
  to invoice that's period ends earlyer than minimal charge starts.
  we're checking whether minimal_charge_start_at is not nill even when minimal_charge is enabled
  but there CANNOT be a situation where minimal charge is enabled, but date is not specified.

  *Returns*
  *boolean* - true or false depending whether minimal charge should be added to invoice
=end
  def add_on_minimal_charge? invoice_period_end
    minimal_charge_enabled? and minimal_charge_start_at and minimal_charge_start_at < invoice_period_end #Time.parse('2001-01-01 00:00:00') < invoice_period_end#Date.parse(minimal_charge_start_at) < invoice_period_end
  end

  def credit_notes(items_per_page=nil, offset=0, order_by='user_name', desc=1)
    condition = ['owner_id = ?', get_correct_owner_id]
    if ['user_name', 'number', 'issue_date', 'status', 'pay_date', 'price'].include? order_by
      order_by = order_by + " " + (desc == 1 ? "DESC" : "ASC")
    end
    if items_per_page
      CreditNote.includes(:user).where(condition).references(:user).limit(items_per_page).offset(offset).order(order_by).all
    else
      CreditNote.includes(:user).where(condition).references(:user).order(order_by).all
    end
  end

  def credit_note_count
    condition = ['owner_id = ?', get_correct_owner_id]
    CreditNote.includes(:user).where(condition).references(:user).count
  end

=begin
  Convert amount from user currency to system currency.
  Note to future developers - do not check whether user has associated currency,
  if he has not, this would be a major bug, all hell should brake loose.

  *Params*
  +value+ amount in user's currency

  *Returns*
  +value_in_system_currency+ float, amount converted to system currency
=end
  def to_system_currency(value)
    value.to_d / currency.exchange_rate.to_d
  end

=begin
  Check whether accountant user has rights to edit specified permission

  *Params*
  +permission+ permission name. same name as it is saved in database

  *Returns*
  +allow_edit+ boolean, true if accountant is allowed to edit
=end
  def accountant_allow_edit(permission)
    return accountant_right(permission) == 2
  end

=begin
  Check whether accountant user has rights to read specified permission

  *Params*
  +permission+ permission name. same name as it is saved in database

  *Returns*
  +allow_edit+ boolean, true if accountant is allowed to read or edit
=end
  def accountant_allow_read(permission)
    return accountant_right(permission) > 0
  end

  def user_allow_read(permission)
    return user_right(permission) > 0
  end

=begin
  Check whether reseller user has rights to edit specified permission

  *Params*
  +permission+ permission name. same name as it is saved in database

  *Returns*
  +allow_edit+ boolean, true if reseller is allowed to read
=end
  def reseller_allow_edit(permission)
    return reseller_right(permission) == 2
  end

=begin
  Check whether reseller user has rights to read specified permission

  *Params*
  +permission+ permission name. same name as it is saved in database

  *Returns*
  +allow_edit+ boolean, true if reseller is allowed to read
=end
  def reseller_allow_read(permission)
    return reseller_right(permission) > 0
  end

  def reseller_right(permission)
    if not is_reseller?
      raise "User is not reseller"
    elsif acc_group
      right = acc_group.acc_group_rights.includes(:acc_right).where("acc_rights.name = '#{permission}'").references(:acc_right).first
      if right
        return right.value.to_i
      else
        return 0
      end
    else
      return 0
    end
  end

=begin
  Check what permission has accountant - read, write or disabled
  If user is not accountant exception will be rised.
  If user has no rights, this means that referential integrity in database is broken,
  but since it is normal in mor, jus return 0 meaning that user has no rights
  User might have acc group but some rights may be not added(or permissiona name was
  invalid) in that case return 0

  *Params*
  +permission+ permission name. same name as it is saved in database

  *Returns*
  +permission+ integer, value specified in database.

=end
  def accountant_right(permission)
    if not is_accountant?
      raise "User is not accountant"
    elsif acc_group
      right = acc_group.acc_group_rights.includes(:acc_right).where("acc_rights.name = '#{permission}'").references(:acc_right).first
      if right
        return right.value.to_i
      else
        return 0
      end
    else
      return 0
    end
  end

  def user_right(permission)
    if not is_user?
      raise "User ir not user"
    elsif simple_user_group
      right = simple_user_group.simple_user_group_rights.includes(:simple_user_right).where("simple_user_rights.name = '#{permission}'").references(:simple_user_right).first
      if right
        return right.value.to_i
      else
        return 0
      end
    else
      return 0
    end
  end

=begin
  Check whether reseller has any common use providers. It would be invalid to call
  this methon on user that cannot have providers, so exception should be rised.

  *Returns*
  +boolean+ true if reseller has common use providers, otherwise false
=end
  def has_own_providers?
    if is_reseller?
      common_use_provider_count > 0
    else
      raise "User is not reseller, he cannot have providers"
    end
  end

=begin
  Get users(resellers) that have only common to this user(reseller) providers. If this user has
  any own providers he it is not posible for him to have providers common with any other user.
  If this user is not reseller raise an exception.

  *Returns*
  +Array of User instances+ all resellers that have common providers or nil if reseller has no
  other resellers that would have common providers.
=end
  def resellers_with_common_providers
    if is_reseller?
      if has_own_providers?
        return nil
      else
        #this query selects all resellers that have no own providers, hence
        #'usertype = 'reseller' AND provider_id IS NULL'
        #and joins them with common use providers of all resellers, hence that nasty
        #JOIN (SELECT ... GROUP BY reseller_id) provider_list
        #then we can filter only those users that have no own providers(but they have
        #common use providers) by comparing 'lists' of common use providers with list
        #of 'self' common use provider 'list'.
        query = "SELECT users.*, provider_list
                FROM   users
                LEFT JOIN providers ON(users.id = providers.user_id)
                JOIN (SELECT reseller_id,
                GROUP_CONCAT(provider_id ORDER BY provider_id) provider_list
                FROM   common_use_providers
                GROUP BY reseller_id) common_use_providers ON reseller_id = users.id
                WHERE usertype = 'reseller' AND
                users.id != #{id} AND
                providers.id IS NULL AND
                provider_list = (SELECT GROUP_CONCAT(provider_id ORDER BY provider_id)
                FROM   common_use_providers
                WHERE reseller_id = #{id}
                GROUP BY reseller_id)"
        User.find_by_sql(query)
      end
    else
      raise "User is not reseller, he cannot have providers"
    end
  end

  def integrity_recheck_user
    default_user_warning = false

    df = Confline.get_default_user_pospaid_errors
    default_user_warning = true if df and df.count.to_i > 0 #Confline.get_value('Default_User_allow_loss_calls', id).to_i == 1 and Confline.get_value('Default_User_postpaid', id).to_i == 1

    users_postpaid_and_loss_calls = User.where(["postpaid = 1 and allow_loss_calls = 1"]).all

    if users_postpaid_and_loss_calls.size > 0 or default_user_warning
      return 1
    else
      Confline.set_value("Integrity_Check", 0)
      return 0
    end

  end

  def User.check_vat_for_user(vat = '', country = '')
    out = false
    begin
      uri = URI.parse('http://ec.europa.eu/taxation_customs/vies/viesquer.do')
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri)
      request.set_form_data({'ms' => country, 'vat' => vat, 'iso' => country, 'requesterMs' => '', 'requesterIso' => '---', 'requesterVat' => ''})
      response = http.request(request)
      out = response.body.include?('Yes, valid VAT number')
    rescue

    end

    return out
  end

  def blocked?
    blocked == 1
  end


=begin
  Add some amount to user's balance.
  Note that after changeing balance we immediately save data to database, since we dont use
  transactions that's least what we should do. If adding amount to balance or creating
  payment fails - we do our best to revert everything... but still without using
  transactions there are lot's of ways to fail.
  Note that amount is expected to be in system's default currency, if not payment amount
  might be giberish.

  *Params*
  +amount+ amount to be added to balance and payment created with amount and tax in
   this users currency.

  *Returns*
  +boolean+ true changeing balance and creating payment succeeded, otherwise false.
     Note that no transactions are used, so if smth goes wrong data might be corrupted.
=end
  def add_to_balance(amount, payment_type='Manual')
    self.balance += amount
    if self.save
      exchange_rate = Currency.count_exchange_rate(Currency.get_default.name, currency.name)
      amount *= exchange_rate
      if payment_type == 'card_refill'
        tax_amount = 0
      else
        tax_amount = self.get_tax.count_tax_amount(amount)
      end
      payment = Payment.create_for_user(self, {:paymenttype => payment_type, :amount => amount, :tax => tax_amount, :shipped_at => Time.now, :date_added => Time.now, :completed => 1, :currency => currency.name})
      if payment.save
        return true
      else
        self.balance -= amount
        self.save
        return false
      end
    else
      return false
    end
  end

  def balance_with_vat
    self.get_tax.apply_tax(self.balance)
  end

  def call_shop_active?
    Confline.get_value('CS_Active').to_i == 1
  end

  def is_callshop_manager?
    (call_shop_active? && self.usergroups.includes(:group).where("usergroups.gusertype = 'manager' and groups.grouptype = 'callshop'").references(:group).first)
  end

  def callshop_manager_group
    if call_shop_active?
      self.usergroups.includes(:group).where("usergroups.gusertype = 'manager' and groups.grouptype = 'callshop'").references(:group).first
    else
      return nil
    end
  end

  def block_and_send_email
    users = [self, owner]
    em= Email.where(["name = 'block_when_no_balance' AND owner_id = ?", owner_id]).first
    variables = Email.email_variables(self)

    begin
      num = EmailsController::send_email(em, Confline.get_value("Email_from", owner_id), users, variables)
    rescue
      MorLog.my_debug('Failed to send email to the user')
    end

    # num = Email.send_email(em, users, Confline.get_value("Email_from", owner_id), 'send_email', {:assigns=>variables, :owner=>variables[:owner]})
    if num.to_s != _('Email_sent')
      Action.add_action_second(id, "error", 'Cant_send_email', num.to_s.gsub('<br>', ''))
    end

    Action.new(:user_id => id, :date => Time.now, :action => "user_blocked", :data => "insufficient funds").save
    self.blocked = 1
  end

  def allowed_to_assign_did_to_trunk?
    (Confline.get_value('Resellers_Allow_Assign_DID_To_Trunk').to_i == 1)
  end


  # Check whethter accountant can see financial data.
  # Note that this method can return valid results only if called on user that
  # is accountant, hence if user is not an accountant exception will be risen.
  def can_see_finances?
    accountant_allow_read('see_financial_data')
  end


  # Checks user devices for sip type device
  def have_sip_device?
    sip_devices.where(host: 'dynamic').try(:size).to_i > 0
  end


  # Returns 0/1/2 value of permmission
  def simple_get_acc_res_permission(permission)
    unless acc_group
      return 0
    end
    right = acc_group.acc_group_rights.includes(:acc_right).where("acc_rights.name = '#{permission}'").references(:acc_right).first if is_accountant? or is_reseller?
    if right
      return right.value.to_i
    else
      return 0
    end
  end

  def accountant_users
    User.where(responsible_accountant_id: id).all
  end

  def registered_during_period(period_end)
    user_created_at_action = Action.where(:action => 'user_created', :target_id => self.id).first
    # If user doesn't have a creation date, probably means this is a testing environment
    if user_created_at_action.nil?
      return true
    else
      user_created_at = Time.parse(user_created_at_action.date.to_s)
      period_end = Time.parse(period_end)
    end
    if user_created_at < period_end
      return true
    else
      return false
    end
  end

  def registered_at
    registration_action = Action.where(:action => 'user_created', :target_id => self.id).first
    if !registration_action.nil?
      return registration_action.date
    else
      return nil
    end
  end

  def update_balance(amount)
    self.raw_balance += amount.to_d
    save
  end

  def get_email_to_address
    email
  end

  def mark_logged_in
    self.logged = 1
    save
  end

  def mark_logged_out
    self.logged = 0
    save
  end

  def self.recover_password(email)
    message = ''
    successful = false
    address = Address.where('email LIKE ?', "%#{email}%").includes(:user).all
    if !address.blank?
      if address.size == 1
        user = address.first.user
        if user && user.id != 0
          owner_id = user.owner_id
          password = UtilityHelper.random_password(12)
          email = Email.where(name: 'password_reminder', owner_id: owner_id).first
          variables = Email.email_variables(user, nil, {owner: owner_id, login_password: password})
          begin
            result = EmailsController::send_email(email, Confline.get_value("Email_from", owner_id), [user], variables)
            if result.to_s.gsub('<br>', '') != _('Email_sent')
              result = ''
              message = (_('Cannot_change_password') + "<br />" + _('Email_not_sent_because_bad_system_configurations')).html_safe
            end
          end
          if result.to_s.include?(_('Email_sent'))
            user.password = Digest::SHA1.hexdigest(password)
            if user.save
              message = _('Password_changed_check_email_for_new_password') + '  ' + user.email
              successful = true
            else
              message = _('Cannot_change_password')
            end
          end
        else
          message = _('Cannot_change_password')
        end
      else
        message = _('Email_is_used_by_multiple_users_Cannot_reset_password')
      end
    else
      message = _('Email_was_not_found')
    end
    return message, successful
  end


  def update_recordings_permissions(params, num)
    new = params[:"recording_enabled_#{num}"].to_i.to_s+params[:"recording_forced_enabled_#{num}"].to_i.to_s+params[:"recording_hdd_quota_#{num}"].to_s+params[:"recordings_email_#{num}"].to_s
    old = self.recording_enabled.to_s + self.recording_forced_enabled.to_s + self.recording_hdd_quota.to_s + self.recordings_email.to_s
    if new != old
      self.recording_enabled = params[:"recording_enabled_#{num}"].to_i
      self.recording_forced_enabled = params[:"recording_forced_enabled_#{num}"].to_i
      self.recording_hdd_quota = params[:"recording_hdd_quota_#{num}"].to_d * 1048576
      self.recordings_email = params[:"recordings_email_#{num}"]
      self.save
    end
  end

  def m2_emails
    emails = [self.main_email, self.noc_email, self.billing_email, self.rates_email]
    email_enum = [0, 1, 2, 3]

    emails.zip(email_enum).reject {|value| value.first.blank? || value.last.blank? }
  end

  def m2_email
    self.try(:[], M2_EMAILS[@m2_email_enum.to_i])
  end

  def m2_email=(enum)
    @m2_email_enum = enum
  end

  # Froms condition  from params and session for listing in recordings returns users, size
  def User.list_for_recordings(params, session)
    search = params[:search_on].try(:to_i) || 0
    page = params[:page].try(:to_i) || 1
    search_username = params[:s_username] || ""
    search_fname = params[:s_first_name] || ""
    search_lname = params[:s_last_name] || ""
    search_aggrnumber = params[:s_aggr_number] || ""
    search_sub = params[:sub_s].try(:to_i) || -1
    search_type = params[:user_type] || -1
    search_account_number = params[:s_acc_number] || ""
    search_clientid = params[:s_clientid] || ""

    if session[:usertype] == "accountant"
      owner = User.where(id: session[:user_id].to_i).get_owner.id.to_i
    else
      owner = session[:user_id]
    end
    cond = " hidden = 0 AND owner_id = '#{owner}' "
    cond += " AND users.username LIKE '#{search_username}%' " if search_username.length > 0

    cond += " AND first_name LIKE '#{search_fname}%' " if search_fname.length > 0

    cond += ' AND ' if cond.length > 0 and search_lname.length > 0
    cond += " last_name LIKE '#{search_lname}%' " if search_lname.length > 0

    cond += ' AND ' if cond.length > 0 and search_aggrnumber.length > 0
    cond += " agreement_number LIKE '#{search_aggrnumber}%' " if search_aggrnumber.length > 0

    cond += " AND accounting_number LIKE '#{search_account_number}%' " if search_account_number.length > 0
    cond += " AND usertype = '#{search_type}' " if search_type.to_i != -1

    cond += " AND clientid LIKE '#{search_clientid}%' " if search_clientid.length > 0

    users = []
    if search_sub > -1
      cond2 = ''
      cond2 = ' subs = 0' if search_sub == 0
      cond2 = ' subs > 0' if search_sub == 1
      size = User.find_by_sql("select count(*) as number from (SELECT count(subscriptions.id) as subs , users.id AS users_id FROM users LEFT OUTER JOIN subscriptions ON subscriptions.user_id = users.id WHERE (#{cond}) GROUP BY users.id) as temp_table WHERE #{cond2}")[0]["number"].to_i
      users = User.find_by_sql("
      SELECT * FROM(
      SELECT users.*, count(subscriptions.id) as subs
      FROM users LEFT JOIN subscriptions ON subscriptions.user_id = users.id
      WHERE (#{cond}) GROUP BY users.id ORDER BY users.first_name ASC) AS temp_table WHERE (#{cond2})
      LIMIT #{(page-1)*session[:items_per_page]}, #{session[:items_per_page]}")
    else
      size = User.where(cond).size
      users = User.where(cond).order('users.first_name ASC').limit(session[:items_per_page]).offset((page-1)*session[:items_per_page]).all if cond.length > 0
    end
    return users, size
  end

  def User.member_toggle_login(params)
    action = ''
      user = User.where(:id => params[:member]).first
      if user.logged == 1 and params[:laction] == "logout"
        user.logged = 0
        action = 'logout'
      end

      if user.logged == 0 and params[:laction] == "login"
        user.logged = 1
        action = 'login'
      end
      user.save
      return user, action
  end

  def group_member_type(group)
    usergroup = Usergroup.where(["user_id = ? AND group_id = ?", self.id, group.id]).first
    managers = usergroup.group.manager_users.size

    if usergroup.gusertype == "manager"
      usergroup.gusertype = "user"
      self.blocked = 1
    else
      if managers == 0 and self.is_user?
        usergroup.gusertype = 'manager'
        usergroup.position = 0
        self.blocked = 0
      end
    end
    usergroup.save
    self.save
  end

  def self.find_global_thresholds
    bl_global_threshold = Confline.get_value('default_routing_threshold', 0)
    bl_global_threshold_2 = Confline.get_value('default_routing_threshold_2', 0)
    bl_global_threshold_3 = Confline.get_value('default_routing_threshold_3', 0)
    bl_global_threshold = _('Disabled') if bl_global_threshold.to_i <= 0
    bl_global_threshold_2 = _('Disabled') if bl_global_threshold_2.to_i <= 0
    bl_global_threshold_3 = _('Disabled') if bl_global_threshold_3.to_i <= 0

    return bl_global_threshold, bl_global_threshold_2, bl_global_threshold_3
  end

  def self.find_global_lcrs
    bl_default_lcr = Confline.get_value('default_blacklist_lcr', 0).to_i
    bl_default_lcr_2 = Confline.get_value('default_blacklist_lcr_2', 0).to_i
    bl_default_lcr_3 = Confline.get_value('default_blacklist_lcr_3', 0).to_i
    bl_default_lcr = (bl_default_lcr.to_i <= 0) ? _('None') : Lcr.where(id: bl_default_lcr.to_i).first.try(:name)
    bl_default_lcr_2 = (bl_default_lcr_2.to_i <= 0) ? _('None') : Lcr.where(id: bl_default_lcr_2.to_i).first.try(:name)
    bl_default_lcr_3 = (bl_default_lcr_3.to_i <= 0) ? _('None') : Lcr.where(id: bl_default_lcr_3.to_i).first.try(:name)

    return bl_default_lcr, bl_default_lcr_2, bl_default_lcr_3
  end

  def sms_subscription(tariff_id, lcr_id)
    status = ''
    action_hash = {}
    if self.sms_service_active == 0
      self.sms_service_active = 1
      self.sms_lcr_id = lcr_id
      self.sms_tariff_id = tariff_id
      status = _('User_subscribed_to_sms_service') + ": " + nice_user(self)
      action_hash = {action:'User_subscribed_to_sms_service', data: tariff_id, target_id: self.id, target_type: 'User'}
    else
      self.sms_service_active = 0
      status = _('User_unsubscribed_from_sms_service') + ": " + nice_user(self)
      action_hash = {action: 'User_unsubscribed_from_sms_service', target_id: self.id, target_type: 'User'}
    end
    self.save
    return action_hash, status
  end

  def lcr_update(params, usertype)
    updated = true
    self.sms_lcr_id = params[:lcr_id] if %w[admin accountant].include?(usertype)
    self.sms_tariff_id = params[:tariff_id]

    if  self.save
      Action.add_action_hash(User.current, {:action=>'sms_lcr_changed_for_user', :data=>self.id, :target_id=>self.sms_lcr_id, :target_type=>'sms_lcr'} )
      if  self.is_reseller? && is_admin?
        users = User.where({:owner_id => self.id})
        if users and users.size.to_i > 0
          for user in users
            user.sms_lcr_id = params[:lcr_id]
            if user.save
              Action.add_action_hash(User.current, {:action=>'sms_lcr_changed_for_user', :data=>user.id, :target_id=>user.sms_lcr_id, :target_type=>'sms_lcr'}  )
            end
          end
        end
      end
    else
      updated = false
    end
    updated
  end

  def change_warning_balance_currency
    exchange_rate = User.current.currency.exchange_rate.to_d
    self.warning_email_balance *= exchange_rate
    self.warning_email_balance_admin *= exchange_rate
    self.warning_email_balance_manager *= exchange_rate
  end

  def fix_values_with_currencies
    exchange_rate = User.current.currency.exchange_rate.to_d
    self.credit *= exchange_rate unless self.credit == -1
    self.daily_credit_limit *= exchange_rate unless self.daily_credit_limit == -1
  end

  def fix_currencies
    exchange_rate = User.current.currency.exchange_rate.to_d
    self.credit /= exchange_rate unless self.credit == -1
    self.daily_credit_limit /= exchange_rate unless self.daily_credit_limit == -1
  end

  # returns found user for api
  def self.api_rate_get_user(params_u, username)
    params_user = self.where(username: params_u).first
    selected_user = self.where(username: username).first
    user_is_reseller = params_user.is_reseller?
    # /billing/api/rate_get?prefix=54
    if selected_user.blank? || params_user.blank?
      return nil
    end

    # /billing/api/rate_get?u=user&username=anybody&prefix=54 or
    # /billing/api/rate_get?u=reseller&username=reseller&prefix=54
    if params_user.is_user? || (user_is_reseller && params_u == username)
      return params_user
    end

    # /billing/api/rate_get?u=reseller&username=user_admin&prefix=54
    if user_is_reseller && selected_user.owner_id == 0 &&
      Confline.reseller_can_use_admins_rates?
      return selected_user
    end

    # /billing/api/rate_get?u=anybody&username=admin/accountant&prefix=54
    if selected_user.is_accountant? || selected_user.is_admin?
      return nil
    end

    # /billing/api/rate_get?u=admin&username=anybody&prefix=54
    if params_user.is_admin?
      return self.where(:username => username, owner_id: 0).first
    end

    # /billing/api/rate_get?u=accountant&...
    if params_user.is_accountant?
      if ['Tariff_manage','see_financial_data'].all?{|right| params_user.simple_get_acc_res_permission(right) != 0}
        return self.where(:username => username, owner_id: 0).first
      else
        return nil
      end
    end

    return self.where(:username => username, owner_id: params_user.id).first
  end

  def has_reseller_sms_permission?
    permission_group_id = nil
    owner = User.where(id: owner_id).first
    if self.is_reseller?
      permission_group_id = self.acc_group_id
    elsif owner.try(:is_reseller?)
      permission_group_id = owner.acc_group_id
    end
    if !permission_group_id.blank?
      permission =  AccGroupRight.select(:value).joins(:acc_group).joins(:acc_right).where("nice_name = 'SMS' AND group_type = 'reseller' AND acc_groups.id = #{permission_group_id}").first
    end
    permission.try(:value).to_i == 2
  end

  def modified_owner_id
    is_accountant? ? 0 : id
  end

  def generate_api_user_details(doc, user_logged)
    country = Direction.where(:id => taxation_country).first
    doc.page {
      doc.pagename("#{_('Personal_details')}")
      doc.language("en")
      doc.userid("#{id}")
      doc.details {
        doc.main_detail {
          postpaid == 1 ? doc.account("#{_('Postpaid')}") : doc.account("#{_('Prepaid')}")
          doc.balance("#{Application.nice_number(balance) } #{Currency.get_default.name}")
          #ticket #4913, there's a rumor that api wil be rewriten, thats the only viable
          #reason to add these elements, cause this mess wil be thrown away soon
          doc.balance_number(balance.to_s)
          doc.balance_currency(Currency.get_default.name)
          credit != -1 ? doc.credit("#{ Application.nice_number(credit.to_s) }") : doc.credit("#{ _('Unlimited')}")
          doc.pbx_pool_id(pbx_pool_id.to_s) if (user_logged.is_admin? or (user_logged.is_reseller? and user_logged.reseller_allow_read('pbx_functions')))
          doc.hide_non_answered_calls(hide_non_answered_calls.to_s) if (user_logged.is_admin? or user_logged.is_reseller?) and is_user?
        }
        doc.other_details {
          doc.username("#{username}")
          doc.first_name("#{first_name}")
          doc.surname("#{last_name}")
          doc.personalid("#{clientid}")
          doc.agreement_number("#{agreement_number}")
          ad = agreement_date || Time.now
          doc.agreement_date("#{ad.strftime("%Y-%m-%d")}")
              doc.taxation_country("#{country.name[0, 22]}") if country
              doc.vat_reg_number("#{vat_number}")
              doc.vat_percent("#{vat_percent}")
          doc.call_limit("#{call_limit}")
        }
        if address
          doc.registration {
          doc.reg_address("#{address.address}")
          doc.reg_postcode("#{address.postcode}")
          doc.reg_city("#{address.city}")
          doc.reg_country("#{address.county}")
          doc.reg_state("#{address.state}")
          doc.reg_direction("#{address.email}")
          doc.reg_phone("#{address.phone}")
          doc.reg_mobile("#{address.mob_phone}")
          doc.reg_fax("#{address.fax}")
          doc.reg_email("#{address.email}")
          }
        end
        if %w[admin reseller partner user].include?(usertype.to_s)
          user_i = get_invoices_status
          doc.invoices {
            doc.generate_invoices("#{generate_invoice}") unless is_admin?
            doc.invoice_xlsx("#{user_i[8] == 512 ? 1 : 0}")
            doc.simplified_pdf("#{user_i[0] == 2 ? 1 : 0}")
            doc.simplified_csv("#{user_i[1] == 4 ? 1 : 0}")
            doc.detailed_pdf("#{user_i[2] == 8 ? 1 : 0}")
            doc.detailed_csv("#{user_i[3] == 16 ? 1 : 0}")
            if is_user? || is_admin?
              doc.by_callerid_pdf("#{user_i[4] == 32 ? 1 : 0}")
              doc.by_callerid_csv("#{user_i[6] == 128 ? 1 : 0}")
              doc.by_destinations("#{user_i[5] == 64 ? 1 : 0}")
              doc.calls("#{user_i[7] == 256 ? 1 : 0}")
            end
            doc.show_zero_calls("#{invoice_zero_calls}") unless is_admin?
          }
          doc.warning_balance {
            doc.active("#{warning_email_active}")
            doc.send_email_when_balance_drops_lower_than {
              doc.user("#{warning_email_balance}")
              if user_logged.is_admin? && !is_admin?
                doc.admin("#{warning_email_balance_admin}")
                doc.responsible_accountant("#{warning_email_balance_manager}")
              end
            }
            doc.warning_email_hour("#{warning_email_hour}")
          }
        end
      }
    }
    doc
  end

  def ignore_global_alerts?
    ignore_global_alerts.to_i == 1 if defined?(ignore_global_alerts)
  end

  def allow_manage_providers_tariffs?
    is_admin? || reseller_allow_providers_tariff? || (is_accountant? && accountant_allow_read('Tariff_manage'))
  end

  def self.responsible_acc
    User.where(:hidden => '0', :usertype =>'accountant').order('username')
  end

  def self.responsible_acc_for_list
    responsible_accountants = User.select('accountants.*').
                              joins('JOIN users accountants ON (accountants.id = users.responsible_accountant_id)').
                              where("accountants.hidden = 0 and accountants.usertype = 'accountant'").
                              group('accountants.id').order('accountants.username')

    return responsible_accountants
  end

  def self.first_resellers_ids
    first_reseller_id, first_reseller_pro_id = User.where(usertype: 'reseller', own_providers: 0).first.try(:id),
                                               User.where(usertype: 'reseller', own_providers: 1).first.try(:id)
  end

  def toggle_hidden
    if self.hidden.to_i == 1
      self.hidden = 0
    else
      self.hidden = 1
    end
    self.save
    self.hidden.to_i
  end

  def self.seek_by_filter(current_user, user_str, style, params = {})
    options = params[:options] || {}
    output = []
    cond = options.present? && options[:show_admin].present? ? ['users.id >= 0'] : ['users.id > 0']
    var = []

    if options.present? && options[:user_owner].present?
      current_user_id = options[:user_owner].to_i
    else
      current_user_id = current_user.is_accountant? ? 0 : current_user.id
    end

    cond << 'hidden = 0' if options.present? && !options[:not_hidden] || options.blank?
    if options.present? && options[:include_owner].to_s == 'true'
      cond << "(users.id = #{current_user_id} OR users.owner_id = #{current_user_id})"
    else
      if current_user.is_partner?
          if options.present? && options[:partners_resellers]
            partner_resellers = User.where(owner_id: current_user_id, usertype: 'reseller').all.to_a
            cond << 'users.owner_id IN (?)' and var << "#{partner_resellers.map { |res| res.id }.join(',')}"
          else
            cond << "users.owner_id = #{current_user_id}"
          end
      else
        cond << 'users.owner_id = ?' and var << current_user_id if (!current_user.is_admin? && !current_user.is_accountant?) ||
                                                                 (options.present? && !options[:show_reseller_users]) ||
                                                                 (options.present? && options[:show_owned_users_only])
      end
    end
    cond << "users.usertype = 'user'" if options.present? && options[:show_users_only]
    cond << "users.usertype != 'reseller'" if options.present? && options[:hide_resellers]

    if user_str.to_s != ''
      name_cond = []
      name_cond << 'users.username LIKE ?' and var << user_str + '%'
      name_cond << "CONCAT(users.first_name, ' ', users.last_name) LIKE ?" and var << user_str + '%'
      name_cond << 'users.last_name LIKE ?' and var << user_str + '%'
      cond << "(#{name_cond.join(' OR ')})"
    end

    seek = []

    if options.present? && options[:hide_partner_scope]
      cond << "((users.usertype != 'reseller' OR users.owner_id = #{current_user_id}) AND users.usertype != 'partner')"
    end

    if options.present? && options[:hide_partners]
      cond << "users.usertype != 'partner'"
    end

    if options.present? && options[:show_optionals]
      options[:show_optionals].each do |option|
        seek << ["<tr><td id=""#{option.downcase}"" #{style}>" << _("#{option}") << '</td></tr>']
      end
    end

    if options.present? && options[:hide_accountants]
      cond << "users.usertype != 'accountant'"
    end

    if params[:responsible_accountant_id].present? && params[:responsible_accountant_id] != '-1'
      cond << "responsible_accountant_id = #{params[:responsible_accountant_id]}"
    elsif options.present? && options[:responsible_accountant_id].present?
      cond << "responsible_accountant_id = #{options[:responsible_accountant_id]}"
    elsif options.present? && options[:responsible_accountant_including_owner_users].present?
      resp_acc_users = current_user.responsible_accountant_users(include_owner_users: true).pluck(:id).join(', ')
      resp_acc_users = '-1' if resp_acc_users.blank?

      cond << "id IN (#{resp_acc_users})"
    end

    if options.present? && options[:show_users_with_devices_only]
      seeker = User.joins(:devices).select("users.id, users.usertype, users.username, #{SqlExport.nice_user_sql}").where([cond.join(' AND ')].concat(var))
      seeker_count = seeker.size
      seeker = seeker.order('nice_user ASC').group('users.id, nice_user')
    else
      seeker = User.select("users.id, users.usertype, users.username, #{SqlExport.nice_user_sql}").where([cond.join(' AND ')].concat(var))
      seeker_count = seeker.size
      seeker = seeker.order('nice_user ASC')
    end

    seek << seeker.limit(20).map { |user| ["<tr><td usertype='" << user.usertype.to_s <<  "' id='" << user.id.to_s << "' #{style}>" << ((options.present? && options[:show_usernames]) ? user[:username] : user[:nice_user]) << '</td></tr>'] }

    output << seek
    total_users = seeker_count
    if total_users > 20
      output << "<tr><td id='-2' #{style}>" << _('Found') << " " << (total_users - 20).to_s << ' ' << _('more') << '</td></tr>'
    elsif total_users == 0
      output << ["<tr><td id='-2' #{style}>" << _('No_value_found') << '</td></tr>']
    end

    return output, total_users
  end

  def correct_owner
    return 0 if self.is_accountant? || self.is_admin?
    return self.id if self.is_reseller?
    return self.owner_id
  end

  def api_currency
    self.currency = nil
  end

  def self.users_for_users_list(options, owner, reseller_active, reseller_pro_active, acc_show_assigned_users = -1)

    sub_positive = options[:sub_s].to_i > -1

    select = ["users.*", "tariffs.purpose", "#{SqlExport.nice_user_sql}"]
    select << 'addresses.city, addresses.county'
    select << 'lcrs.name AS lcr_name'
    select << 'tariffs.name AS tariff_name'
    select << 'acc_groups.name AS acc_group_name'
    select << "count(subscriptions.id) as 'subscriptions_count'" if sub_positive

    cond = ["users.hidden = 0 AND users.id != 0 AND users.owner_id = #{owner}"]
    cond << "users.usertype = '#{options[:user_type]}'" if options[:user_type].present? && options[:user_type].to_i != -1
    cond << "users.id = #{options[:s_id].to_i}" if options[:s_id].present? && options[:s_id].to_i != -1
    cond << "users.agreement_number LIKE #{ActiveRecord::Base::sanitize(options[:s_agr_number])}" if options[:s_agr_number].present?
    cond << "users.accounting_number LIKE #{ActiveRecord::Base::sanitize(options[:s_acc_number])}" if options[:s_acc_number].present?
    cond << "email LIKE #{ActiveRecord::Base::sanitize(options[:s_email])}" if options[:s_email].present?
    if acc_show_assigned_users == -1 && options[:responsible_accountant_id].present? && options[:responsible_accountant_id] != '-1'
      cond << "users.responsible_accountant_id = '#{options[:responsible_accountant_id]}'"
    end
    cond << "users.first_name LIKE #{ActiveRecord::Base::sanitize(options[:s_first_name])}" if options[:s_first_name].present?
    cond << "users.username LIKE #{ActiveRecord::Base::sanitize(options[:s_username])}" if options[:s_username].present?
    cond << "users.last_name LIKE #{ActiveRecord::Base::sanitize(options[:s_last_name])}" if options[:s_last_name].present?
    cond << "users.clientid LIKE #{ActiveRecord::Base::sanitize(options[:s_clientid])}" if options[:s_clientid].present?

    if current_user.is_admin? && (( !reseller_active) || ( !reseller_pro_active))
      first_reseller_id, first_reseller_pro_id = User.first_resellers_ids
      condition = ["users.usertype != 'reseller'"] if !reseller_active
      condition << ["users.id = #{first_reseller_id}"] if first_reseller_id && !reseller_active
      condition = ['users.own_providers = 0'] if !reseller_pro_active && reseller_active
      condition << ["users.id = #{first_reseller_pro_id}"] if first_reseller_pro_id
      cond << '(' + condition.join(' OR ') + ')'
    end

    joins = []
    joins << 'LEFT JOIN addresses ON (users.address_id = addresses.id)' if options[:s_email].present?
    joins << 'LEFT JOIN subscriptions ON (users.id = subscriptions.user_id)' if sub_positive
    joins << 'LEFT JOIN tariffs ON users.tariff_id = tariffs.id'

    # we need to left join acc_groups, addreses and lcrs. When COUNTING users this data is irelevant,
    # so no need for extra joins there
    # Select addresses.county(that's right), addresses.city, lcrs.name, tariffs.name, acc_groups_name
    # so that rails wouldnt generate extra queries.

    joins << 'LEFT JOIN addresses ON users.address_id = addresses.id' if options[:s_email].blank?
    joins << 'LEFT JOIN lcrs ON users.lcr_id = lcrs.id'
    joins << 'LEFT JOIN acc_groups ON users.acc_group_id = acc_groups.id'

    group_by = "users.id HAVING subscriptions_count#{options[:sub_s].to_i == 0 ? " = 0" : " > 0"}" if sub_positive

    search = ((cond.size > 1 || sub_positive) ? 1 : 0)
    cond << "users.responsible_accountant_id = '#{acc_show_assigned_users}'" if acc_show_assigned_users != -1
    users = User.select(select.join(",")).joins(joins.join(" ")).where(cond.join(" AND ")).group(group_by)

    return users, search
  end

  def last_calls_stats_partner(options)
    user = User.where(id: options[:s_user_id]).first if options[:s_user_id].present? && (options[:s_user_id] != '-2')

    if user
      device = Device.where(id: options[:s_device]).first if options[:s_device] != 'all' && options[:s_device].present?
      devices = user.devices(conditions: "device_type != 'FAX'")
    else
      device, devices = [[], []]
    end

    providers = Provider.find_all_for_select
    provider = Provider.where(id: options[:s_provider]).first if options[:s_provider].to_i > 0
    did = Did.where(id: options[:s_did]).first if options[:s_did] != 'all' && options[:s_did].present?
    hgc = Hangupcausecode.where(id: options[:s_hgc]).first if options[:s_hgc].to_i > 0
    hgcs = Hangupcausecode.find_all_for_select
    did_provider = Provider.where(:id => options[:s_did_provider]).first if options[:s_did_provider].to_i > 0
    resellers_sql = "SELECT #{SqlExport.nice_user_sql}, id FROM users WHERE usertype = 'reseller' AND owner_id = #{id} ORDER BY nice_user"
    resellers = ActiveRecord::Base.connection.select(resellers_sql)
    resellers_with_dids = User.joins('JOIN dids ON (users.id = dids.reseller_id)').where("usertype = 'reseller' AND owner_id = #{id}").group('users.id')
    resellers = [] if !resellers
    reseller = User.where(id: options[:s_reseller]).first if options[:s_reseller] != 'all' && options[:s_reseller].present?
    return user, devices, device, hgcs, hgc, did, providers, provider, reseller, resellers, resellers_with_dids, did_provider
  end

  def location_for_device_update(location_id, old_location_id)
    owner_id = self.get_corrected_owner_id
    location = Location.where(id: location_id)
    location =  if is_reseller? && (Confline.reseller_may_use_admin_location_rules || location_id == old_location_id)
                  location.where(user_id: [owner_id, 0])
                else
                  location.where(user_id: owner_id)
                end
    location.first.try(:id)
  end

  def check_reseller_conflines
    if !Confline.where(["name LIKE 'Default_device_%' AND owner_id = ?", self.id]).first
      self.create_reseller_conflines
    end
  end

  def nice_name
    nice_name = "#{first_name} #{last_name}"
    nice_name = username.to_s if nice_name.length < 2

    nice_name
  end

  def self.new_user_for_test
    user = User.order('id desc').first.dup
    user.username = user.username.to_s + 'no_adr'
    user.tax_id = 999999
    user.address = nil
  end

  def self.available_ids(condition)
    self.connection.select_all("SELECT users.id FROM users WHERE #{condition}").map(){|record| record["id"] }.join(', ')
  end

  def pbx_functions_size
    self.dialplans.where(dptype: 'pbxfunction').size
  end

  def time_now_in_tz
    Time.now.in_time_zone(self.time_zone) rescue Time.now
  end

  def where_clause_for_subscriptions_get(params)
    sub_user_id = self.get_corrected_owner_id
    where_clause = []
    where_clause << "(users.owner_id = #{sub_user_id} OR subscriptions.user_id = #{sub_user_id})" unless self.is_admin?

    # service_id
    params_service_id = params[:service_id]
    service_id = params_service_id.to_s.strip if params_service_id.present?
    where_clause << " subscriptions.service_id = '#{service_id}'" if service_id.present? && service_id != 'all'

    # memo
    params_subscription_memo = params[:subscription_memo]
    subscription_memo = params_subscription_memo.to_s.strip if params_subscription_memo.present?
    where_clause << " subscriptions.memo = '#{subscription_memo}'" if subscription_memo

    # user_id
    param_user_id = params[:user_id]
    user_id = param_user_id.to_s.strip if param_user_id.present?
    where_clause << " subscriptions.user_id = #{user_id}" if user_id.present? && user_id != 'all'

    # activation_start and activation_end
    period_start = params[:subscription_activation_start].present? ? DateTime.strptime(params[:subscription_activation_start].to_s, '%s').strftime('%Y-%m-%d %H:%M:%S').to_s : ''
    period_end = params[:subscription_activation_end].present? ? DateTime.strptime(params[:subscription_activation_end].to_s, '%s').strftime('%Y-%m-%d %H:%M:%S').to_s : ''
    until_canceled = 'subscriptions.activation_end IS NULL' if params[:subscription_until_canceled].present? && params[:subscription_until_canceled].to_s == '1'

    if period_start.present? && period_end.present? && until_canceled.present?
      where_clause << " (subscriptions.activation_start >= '#{period_start}') AND (subscriptions.activation_end <= '#{period_end}' OR #{until_canceled})"
    elsif period_start.present? && period_end.present? && !until_canceled.present?
      where_clause << " (subscriptions.activation_start >= '#{period_start}') AND (subscriptions.activation_end <= '#{period_end}')"
    elsif period_start.present? && !period_end.present? && until_canceled.present?
      where_clause << " (subscriptions.activation_start >= '#{period_start}' AND #{until_canceled})"
    elsif period_start.present? && !period_end.present? && !until_canceled.present?
      where_clause << " (subscriptions.activation_start >= '#{period_start}' OR subscriptions.activation_end IS NULL)"
    else
      if until_canceled.present?
        where_clause << " #{until_canceled}"
      elsif period_end.present?
        where_clause << " (subscriptions.activation_end <= '#{period_end}')"
      end
    end

    where_clause.join(' AND ')
  end

  def update_voicemail_boxes_mailbox(pbx_pool_id)
    devices = self.devices
    devices.each do |device|
      voicemail_box = device.voicemail_box
      if voicemail_box
        voicemail_box.context = pbx_pool_id.to_i > 1 ? "pool_#{pbx_pool_id}" : "default"
        voicemail_box.save
      end
    end
  end

  def update_voicemail_extlines(pbx_pool_id)
    devices = self.devices
    devices.each do |device|
      pool = pbx_pool_id.to_i > 1 ? "@pool_#{pbx_pool_id}" : ''
      Extline.where("appdata LIKE '%mor_voicemail%' AND device_id = #{device.id}").update_all(appdata: "mor_voicemail,${EXTEN}#{pool},1")
    end
  end


  def responsible_accountant_users(options = {})
    users = User.where(responsible_accountant_id: id)

    if options[:include_owner_users].present? && users.present?
      users = User.where("responsible_accountant_id = #{id} OR owner_id IN (#{users.pluck(:id).join(', ')})")
    end

    users
  end

  def responsible_accountant_user_devices(options = {})
    users = responsible_accountant_users({include_owner_users: options[:include_owner_devices].present?}).pluck(:id)
    users = [-2] if users.blank?

    Device.where(user_id: users)
  end

  def user_sms_service_subscribe(current_user, params_sms_lcr_id, params_sms_tariff_id)
    self.sms_service_active = 1

    # Reseller users can use only Admin's assigned LCR
    if self.owner.is_reseller?
      self.sms_lcr_id = SmsLcr.where(id: "#{self.owner.sms_lcr_id}").first.try(:id)
    else
      self.sms_lcr_id = SmsLcr.where(id: "#{current_user.is_reseller? ? current_user.sms_lcr_id : params_sms_lcr_id}").first.try(:id)
    end

    self.sms_tariff_id = SmsTariff.where(id: params_sms_tariff_id).first.try(:id)
    self.save
  end

  def self.strong_password?(password)
    # /^(?=.*\d)(?=.*\p{Lu})(?=.*\p{Ll}).+$/ Explained:
    #   \d - numbers from range [0-9]
    #   \p - unicode characters {Lu} - uppercase, {Ll} - lowercase
    if User.use_strong_password?
      return true if /\p{Hebrew}|\p{Arabic}/ =~ password
      /^(?=.*\d)(?=.*\p{Lu})(?=.*\p{Ll}).+$/ =~ password ? true : false
    else
      true
    end
  end

  def self.system_stats(current_user)
    show_assign_users = current_user.is_accountant? && current_user.show_only_assigned_users.to_i == 1
    response = {
        admins: self.where(usertype: :admin).count,
        partners: self.where(usertype: :partner).count,
        resellers: show_assign_users ? self.responsible_accountant_resellers(current_user).count : self.where(usertype: :reseller).count,
        accountants: self.where(usertype: :accountant).count,
        simple_users: show_assign_users ? self.responsible_accountant_users(current_user).count : self.where(usertype: :user).count,
        postpaid: show_assign_users ? self.responsible_accountant_pay_type(1, current_user) : self.where(postpaid: 1).count,
        prepaid: show_assign_users ? self.responsible_accountant_pay_type(0, current_user) : self.where(postpaid: 0).count,
        total: 0
    }
    [:admins, :partners, :resellers, :accountants, :simple_users].each { |key| response[:total] += response[key].to_i }

    response
  end

  def self.get_all_users_for_api(user)
    user_id = user.id
    if user.is_admin?
      User.where('id != ?', 0)
    elsif user.is_reseller?
      User.where('usertype != ? AND owner_id = ?', 'accountant', user_id)
    elsif user.is_accountant?
      User.where('id != ? AND usertype != ?', 0, 'accountant')
    else
      # parners resellers and their users
      owner_id = [user_id]
      p_resellers = User.where(owner_id: user_id).pluck(:id)
      owner_id << p_resellers.presence
      User.where(owner_id: owner_id).all
    end
  end

  def not_blocked_and_in_group
    # allow when its not blocked, its blocked but it is in group or its blocked but user setting
    # "Allow to login and receive emails" checked
    blocked == 0 || (blocked == 1 && (groups.first || allow_login_receive_email == 1))
  end


  def self.use_strong_password?
    Confline.get_value('Use_strong_passwords_for_users', 0).to_i == 1 || Confline.get_value('Use_strong_passwords_for_users', 0).blank?
  end

  def acc_assigned_to_user?(user_id)
    User.where(id: user_id, responsible_accountant_id: self.id).first
  end

  private

  def self.responsible_accountant_users(current_user)
    resellers = self.responsible_accountant_resellers(current_user).pluck(:id)
    self.where('usertype = ? AND (responsible_accountant_id = ? OR owner_id IN (?))', 'user', current_user.id, resellers)
  end

  def self.responsible_accountant_resellers(current_user)
     self.where(usertype: :reseller, responsible_accountant_id: current_user.id)
  end

  def self.responsible_accountant_pay_type(pay_type, current_user)
    resellers = responsible_accountant_resellers(current_user).pluck(:id)
    self.where('postpaid = ? AND (responsible_accountant_id = ? OR owner_id IN (?))', pay_type, current_user.id, resellers).count
  end

  # Number of common use providers that this user can use. Only reseller can have common use
  # providers, returning something as nil, false, 0 would not be appropriat if this user cannot
  # have providers at all, in that case we raise exception.

  # *Returns*
  # +integer+ 0 or more depending on how much common use providers are associated with reseller
  def common_use_provider_count
    if is_reseller?
      Provider.where(["user_id = #{id}"]).size.to_i
    else
      raise "User is not reseller, he cannot have providers"
    end
  end

  def save_with_balance
    @save_with_balance_record
  end

  def new_user_balance
    # A.S: To convert set balance to default system currency. #7856
    self.balance		  = self.convert_curr(self.balance)
    self.warning_email_balance = self.convert_curr(self.warning_email_balance)
    self.warning_email_balance_admin = self.convert_curr(self.warning_email_balance_admin)
    self.warning_email_balance_manager = self.convert_curr(self.warning_email_balance_manager)
  end

  def check_min_max_balance
    if self.balance_min and self.balance_max and self.balance_min > self.balance_max
      errors.add(:min_balance, _('minimal_balance_must_be_grater_than_maximal'))
      return false
    end
  end

  def User.financial_status(options)
    users = self.select(:id, :username, :first_name, :last_name, :balance, :balance_min, :balance_max, :warning_email_active, :warning_email_balance, SqlExport.nice_user_sql)
    id, min_balance, max_balance = options[:id], options[:balance_min], options[:balance_max]
    where_sentence = []
    where_sentence << "id = #{id}" if id.present?
    where_sentence << "balance >= #{min_balance}" if min_balance.present?
    where_sentence << "balance <= #{max_balance}" if max_balance.present?
    where_sentence << "owner_id = #{current_user.id} && usertype NOT IN ('admin', 'accountant')"
    if options[:order_by]
      order = options[:order_desc].to_i.zero? ? ' ASC' : ' DESC'
      users = users.order(options[:order_by] + order)
    end
    users = users.where(where_sentence.join(" AND "))
    users
  end

  def update_context_for_user(user, pbx_pool_id, old_pool_id)
    old_pool_context, new_pool_context = pbx_pool_context(old_pool_id), pbx_pool_context(pbx_pool_id)

    Extline.joins("LEFT JOIN (SELECT user_id, id FROM devices) AS user_device ON extlines.device_id = user_device.id").
    where("user_id = #{user.id}").
    update_all(context: new_pool_context)
    Device.where(user_id: user.id).update_all(context: new_pool_context)
    update_ivr_extlines = "UPDATE extlines SET appdata = REPLACE(appdata, '#{old_pool_context}', '#{new_pool_context}')
      WHERE appdata LIKE '#{old_pool_context}%' AND context LIKE 'ivr_block%';"
    ActiveRecord::Base.connection.execute(update_ivr_extlines)
  end

  def pbx_pool_context(pool_id)
    pool_id.to_i > 1 ? "pool_#{pool_id}_mor_local" : 'mor_local'
  end

  def update_extline_appdata(pbx_pool_id)
    extensions = RinggroupsDevice.select('distinct dialplans.data2').
                                  joins('left join devices on device_id = devices.id').
                                  joins('left join users on users.id = devices.user_id').
                                  joins('left join dialplans on dialplans.data1 = ringgroup_id').
                                  where("users.id = #{self.id} AND dialplans.dptype = 'ringgroup'").to_a

    extensions.each do |exten|
      extension = exten.data2
      extliness = Extline.select('extlines.id, extlines.appdata').where(exten: extension, app: 'Dial')

      extliness.each do |extl|
        appdata = extl.appdata.split('&').map! do |data|
          if data.include?('mor_local')
            device_extension = data[/\/.+@/].to_s
            device_extension = device_extension[1, device_extension.length - 2]
            pool = data[/@\S*mor_local/]
            pool_id = pool == '@mor_local' ? 1 : pool[/\d+/]
            device = Device.joins('left join users on users.id = user_id').
            where("extension = '#{device_extension}' AND users.pbx_pool_id = #{pool_id}").first

            if device && device.user_id == self.id
              context = pbx_pool_id.to_i <= 1 ? 'mor_local' : "pool_#{pbx_pool_id}_mor_local"
              data.gsub!(/@\S+\//, "@#{context}/")
            end
          end
          data
        end
      appdata = appdata.join('&')
      Extline.where(id: extl.id, exten: extension, app: 'Dial').update_all(appdata: appdata)
      end
    end
  end

  def asterisk_reload_devices
    devices = self.devices
    devices.each do |device|
      device.prune_device_in_all_servers(device.name, 1, 1, 0) if device.device_type == "SIP"
      device.sip_prune_realtime_peer(device.name, device.server_id)
    end
  end

  def self.sanitaze_sql_input(param)
    return param.gsub("'", "\\\\'")
  end

  def sql_for_quick_stats(where_query, current_user_id)
    " SELECT
      aggregates.calls_count, aggregates.duration, aggregates.selfcost,
      aggregates.revenue, (aggregates.revenue - aggregates.selfcost) AS 'profit'
      FROM
      (
        SELECT
          SUM(answered_calls) AS calls_count,
          SUM(CEIL(user_billed_billsec)) AS duration,
          SUM(terminator_billed) AS selfcost,
          SUM(user_billed) AS revenue
        FROM aggregates
        JOIN time_periods ON aggregates.time_period_id = time_periods.id
        LEFT JOIN users ON aggregates.user_id = users.id
        WHERE time_periods.from_date BETWEEN #{where_query} AND variation = 1 AND users.owner_id = #{current_user_id}
      ) aggregates;"
  end

  def sql_for_did_owner_price(where_query, current_user_id)
    " SELECT sum(user_billed) AS did_owner_cost FROM aggregates
      JOIN time_periods ON aggregates.time_period_id = time_periods.id
      LEFT JOIN users ON aggregates.user_id = users.id
      WHERE time_periods.from_date BETWEEN #{where_query} AND variation = 12 AND users.owner_id = #{current_user_id};"
  end

  def sql_for_selfcost_for_reseller(where_query, current_user_id)
    " SELECT sum(user_billed) AS selfcost FROM aggregates
      JOIN time_periods ON aggregates.time_period_id = time_periods.id
      WHERE time_periods.from_date BETWEEN #{where_query} AND variation = 1 AND user_id = #{current_user_id};"
  end

  def sql_for_quick_stats_user(where_query, current_user_id, billsec_sql)
    " SELECT SUM(answered_calls) AS calls_count, SUM(#{billsec_sql}) AS duration FROM aggregates
      JOIN time_periods ON aggregates.time_period_id = time_periods.id
      WHERE time_periods.from_date BETWEEN #{where_query} AND variation = 1 AND user_id = #{current_user_id};"
  end

  def es_admin_quick_stats(es_period)
    from_users = Elasticsearch.safe_search_mor_calls(es_admin_quick_stats_from_users_query(es_period[:from], es_period[:till]))
    from_resellers = Elasticsearch.safe_search_mor_calls(es_admin_quick_stats_from_resellers_query(es_period[:from], es_period[:till]))
    from_partners = Elasticsearch.safe_search_mor_calls(es_admin_quick_stats_from_partners_query(es_period[:from], es_period[:till]))
    return false if from_users.blank? || from_resellers.blank? || from_partners.blank?

    calls = from_users['hits']['total'] + from_resellers['hits']['total'] + from_partners['hits']['total']
    from_users_aggr = from_users['aggregations']
    from_resellers_aggr = from_resellers['aggregations']
    from_partners_aggr = from_partners['aggregations']
    total_duration = from_users_aggr['total_billsec']['value'] + from_resellers_aggr['total_billsec']['value'] +
      from_partners_aggr['total_billsec']['value']

    self_cost = from_users_aggr['total_provider_price']['value'] - from_users_aggr['total_did_prov_price']['value'] +
      from_resellers_aggr['total_provider_price']['value'] - from_resellers_aggr['total_did_prov_price']['value'] +
      from_partners_aggr['total_provider_price']['value'] - from_partners_aggr['total_did_prov_price']['value']

    revenue = (from_users_aggr['total_user_price']['value'] + from_users_aggr['total_did_inc_price']['value']) +
      (from_resellers_aggr['total_reseller_price']['value'] + from_resellers_aggr['total_did_inc_price']['value']) +
      (from_partners_aggr['total_partner_price']['value'] + from_partners_aggr['total_did_inc_price']['value'])

    did_owner_cost = from_users_aggr['total_did_price']['value'] +
      from_resellers_aggr['total_did_price']['value'] +
      from_partners_aggr['total_did_price']['value']
    profit = revenue - self_cost + did_owner_cost

    [calls, total_duration, self_cost, revenue, profit, did_owner_cost]
  end

  def es_reseller_quick_stats(es_period, reseller_id)
    stats = Elasticsearch.safe_search_mor_calls(es_reseller_quick_stats_query(es_period[:from], es_period[:till], reseller_id))
    return false if stats.blank?

    calls = stats['hits']['total']
    total_duration = stats['aggregations']['total_billsec']['value']
    self_cost = stats['aggregations']['total_reseller_price']['value']
    revenue = stats['aggregations']['total_user_price']['value'] + stats['aggregations']['total_did_inc_price']['value']
    profit = revenue - self_cost

    return calls, total_duration, self_cost, revenue, profit
  end

  def es_user_quick_stats(es_period, user_id, show_user_billsec = false)
    stats = Elasticsearch.safe_search_mor_calls(es_user_quick_stats_query(es_period[:from], es_period[:till], user_id))
    return false if stats.blank?

    calls = stats['hits']['total']
    total_duration = stats['aggregations'][(show_user_billsec ? 'user_billsec' : 'total_billsec')]['value']

    return calls, total_duration
  end

  def is_user_viable_for_res_acc?(param, user_id, current_user)
     (!User.where(usertype: 'accountant', hidden: 0, id: param.to_i).first ||
     current_user.owner_id != 0 ||
     User.where(usertype: 'accountant', id: user_id).first ||
     User.where(usertype: 'partner', id: user_id).first ||
     User.where(usertype: 'admin', id: user_id).first)
  end

  def no_dublicate_warning_emails(warning_email)
    unless allow_duplicate_emails?
      not_self = "AND id != '#{self.address.id}'" unless address.nil?
      addresses_all = Address.where("email != 'null' #{not_self}").pluck(:email)

      # Simple users emails
      addressses = []
      addresses_all.each do |address|
        addressses << address.downcase.split(';').reject(&:blank?)
      end

      # All warning balance emails
      not_self_user = "AND id != '#{self.id}'" unless id.nil?
      warning_emails = User.where("warning_balance_email != 'null' #{not_self_user}").pluck(:warning_balance_email)
      warning_emails.each do |emails|
       addressses << emails.downcase.split(';').reject(&:blank?)
      end

      emails = warning_email.split(';').reject(&:blank?)
      splitted_emails = addressses.flatten.collect(&:strip)
        emails.each do |mail|
          mail.gsub!(/\s+/, '')
          if splitted_emails.include?(mail.downcase)
            return false, mail
          end
        end
      end
    true
  end

  def allow_duplicate_emails?
    Confline.get_value('allow_identical_email_addresses_to_different_users', 0).to_i == 1
  end

  def self.find_users_for_faxes(options, items_per_page, order_by, conditions)
    select("users.*,
      #{SqlExport.nice_user_sql},
      SUM(pdffaxes.status = 'no_tif') AS no_tif,
      SUM(pdffaxes.status = 'good') AS good,
      SUM(pdffaxes.status = 'pdf_size_0') AS pdf_size,
      SUM(pdffaxes.size) AS total_size,
      (count(pdffaxes.id)) AS totals")
      .where("users.hidden = 0 AND users.usertype = 'user'
        AND (receive_time BETWEEN '#{options[:session_from_datetime]}'
        AND '#{options[:session_till_datetime]}'
        OR pdffaxes.receive_time is NULL)")
      .where(conditions)
      .joins('JOIN devices ON (devices.user_id = users.id)')
      .joins('LEFT JOIN pdffaxes ON (pdffaxes.device_id = devices.id)')
      .limit("#{options[:fpage]}, #{items_per_page.to_i}")
      .order(order_by)
      .group('users.id')
  end
end
