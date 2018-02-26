# -*- encoding : utf-8 -*-
class Callerid < ActiveRecord::Base
  attr_protected
  belongs_to :device
  belongs_to :ivr

  validate :cli_uniqueness
  validates_presence_of :cli, :message => _('Please_enter_details')
  validates_numericality_of :cli, :message => _("CLI_must_be_number")
  validates_presence_of :device, :message => _('Please_select_user')

  before_destroy :validate_device

  def validate_device
    return true unless device
    if device.control_callerid_by_cids.to_i == id
      errors.add(:device, _('CID_is_assigned_to_Device'))
      return false
    end
  end

  def Callerid.use_for_callback(cli, status)
    cli_id = cli.id

    if status.to_i == 1
      sql = "UPDATE callerids SET callerids.email_callback = '0'
           WHERE device_id = '#{cli.device_id}' AND callerids.id != '#{cli_id}'"
      sql2= "UPDATE callerids SET callerids.email_callback = '1'
           WHERE callerids.id = '#{cli_id}'"
      ActiveRecord::Base.connection.update(sql)
      ActiveRecord::Base.connection.update(sql2)
    else
      sql2= "UPDATE callerids SET callerids.email_callback = '0'
           WHERE callerids.id = '#{cli_id}'"
      ActiveRecord::Base.connection.update(sql2)
    end
  end

  def Callerid.set_callback_from_emails(old_callerid, new_callerid)

    cli3 = Callerid.where(cli: old_callerid, email_callback: '1').first
    if  cli3
      cli = Callerid.wheres(cli: new_callerid).first
      if cli
        MorLog.my_debug "changed: #{old_callerid} to #{new_callerid}"
        Callerid.use_for_callback(cli, 1)
      else
        MorLog.my_debug "Create new Callerid, Callerid.cli=#{new_callerid}"
        cli2 = Callerid.new
        cli2.cli = new_callerid
        cli2.device_id = cli3.device_id
        cli2.description = ""
        cli2.comment = ""
        cli2.banned = 0
        cli2.added_at = Time.now
        cli2.save
        MorLog.my_debug "changed with creating: #{old_callerid} to #{new_callerid}"
        Callerid.use_for_callback(cli2, 1)
      end

      Action.add_action_second(0, "email_callback_change", "completed", "#{old_callerid} changed to #{new_callerid}")

    else
      MorLog.my_debug "Email Callback ERROR: #{old_callerid} not found or not allowed for email callback, dst: #{new_callerid}"
      Action.add_action_second(0, "email_callback_change", "error", "#{old_callerid} not found or not allowed for email callback, dst: #{new_callerid}")

    end
  end

  def Callerid.create_from_csv(name, options)
    CsvImportDb.log_swap('analize')
    MorLog.my_debug("CSV create_clids_from_csv #{name}", 1)
    options_imp_clid = options[:imp_clid]

    usa_sql = "INSERT INTO callerids (cli, device_id, description, created_at)
    SELECT DISTINCT(replace(col_#{options_imp_clid}, '\\r', '')), '-1', 'this cli created from csv', '#{Time.now.to_s(:db)}'  FROM #{name}
    LEFT JOIN callerids on (callerids.cli = replace(col_#{options_imp_clid}, '\\r', ''))
    WHERE not_found_in_db = 1 and nice_error != 1 and callerids.id is null"
    #MorLog.my_debug usa_sql
    begin
      ActiveRecord::Base.connection.execute(usa_sql)
      ActiveRecord::Base.connection.select_value("SELECT COUNT(DISTINCT(replace(col_#{options_imp_clid}, '\\r', ''))) FROM #{name} WHERE not_found_in_db = 1 and nice_error != 1 ").to_i
    rescue
      0
    end
  end

  def cli_uniqueness
    # Check for duplicates
    destroy_redundant_clis
    existing_cli = Callerid.where(cli: cli.to_s.gsub(/\s/, '')).where.not(id: id).first
    return false unless existing_cli

    # Provide an error message if there are valid callerids with the same cli
    user = existing_cli.device.try(:user)
    owner_id = user.try(:owner_id)
    link_nice_user = ->(user) do
      nice_name = "#{user.try(:first_name)} #{user.try(:last_name)}"
      if nice_name.gsub(' ', '').blank?
        nice_name = user.try(:username).to_s
      end
      "<a href=#{Web_Dir + "/users/edit/#{user.id}"}>#{nice_name}</a>"
    end
    if User.current.present?
      current_user_id = User.current.id.to_i
      if owner_id.to_i == current_user_id
        errors.add(:cli_uniqueness, _('cli_exists_assigned', link_nice_user.call(user)))
      else
        user_owner = User.where(id: owner_id).first
        if user_owner.try(:owner_id).to_i == current_user_id
          errors.add(:cli_uniqueness, _('cli_exists_assigned', link_nice_user.call(user_owner)))
        else
          errors.add(:cli_uniqueness, _('cli_already_exists'))
        end
      end
    end
  end

  def destroy_redundant_clis
    # Delete matching callerids with a device that does not exist
    existing_clis = Callerid.where(cli: cli.to_s.gsub(/\s/, '')).where.not(id: id)
    existing_clis.each { |cli| cli.destroy unless cli.device }
  end

  def banned_status
    self.banned = (self.banned.to_i == 1 ? 0 : 1)
    self.created_at = Time.now unless self.created_at
  end

  def prepare_new_cli(cli, device)
    self.assign_attributes({
      cli: cli,
      device: device,
      description: '',
      added_at: Time.now,
      banned: 0,
      created_at: Time.now,
      updated_at: Time.now,
      ivr: nil,
      comment: '',
      email_callback: 0
    })
  end

  def self.create_cli(params)
    cli = self.new(
      cli: params[:cli_number],
      device_id: params[:device_id],
      comment: params[:comment].to_s,
      banned: params[:banned].to_i,
      added_at: Time.now
      )

    cli.description = params[:cli_description].presence
    cli.ivr_id = params[:ivr_id].presence
    cli
  end
end
