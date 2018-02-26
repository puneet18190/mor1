# -*- encoding : utf-8 -*-
# Validation controller.
class ValidationController < ApplicationController

  def validate
    user_stats = validate_users
    device_stats = validate_devices
    provider_stats = validate_providers
    resellers_emails_stats = validate_resellers_emails
    Action.new(:user_id => 0, :date => Time.now.to_s(:db), :action => "system_validated").save
    render :text => "Users:\n#{user_stats}\n\nDevices:\n#{device_stats}\n\nProviders:\n#{provider_stats}\n\nResellers_emails:\n#{resellers_emails_stats}"
  end

  private
  def validate_users
    @users = User.includes([:address]).all
    @total_users = @users.size
    @validated_users = 0
    @still_invalid = 0
    @users.each { |user|
      user_id, time_now = user.id, Time.now.to_s(:db)
      unless user.save
        MorLog.my_debug("")
        MorLog.my_debug("INVALID USER: #{user_id}")

        if !user.address
          MorLog.my_debug("FIXING USER: #{user_id} User has no address")
          user.create_address
        end

        user_address_email = user.address.email
        if user_address_email and user_address_email.to_s.length > 0 and !Email.address_validation(user_address_email)
          Action.new(:user_id => user_id, :date => time_now, :action => 'user_validated', :data => 'email_deleted', :data2 => user_address_email).save
          MorLog.my_debug("FIXING USER: #{user_id} Wrong address.email: #{user_address_email}")
          user.address.email = nil if user_address_email.to_s.blank?
          user.address.save
        end

        user_recordings_email = user.recordings_email
        if user_recordings_email.to_s.length > 0 and !Email.address_validation(user_recordings_email)
          Action.new(:user_id => user_id, :date => time_now, :action => 'user_validated', :data => 'recordings_email_deleted', :data2 => user_recordings_email).save
          MorLog.my_debug("FIXING USER: #{user_id} Wrong recordings_email")
          user.recordings_email = ''
        end

        if user.save
          MorLog.my_debug("VALIDATED USER: #{user_id}")
          @validated_users += 1
        else
          str = ''
          user.errors.each { |key, value| str += " #{value}" }
          Action.add_error(user_id, ("User_still_invalid. #{str}")[0..255])
          MorLog.my_debug("NOT VALIDATED USER: #{user_id}")
          @still_invalid += 1
        end
      end
    }
    return "  Total users: #{@total_users}\n  Validated users: #{@validated_users}\n  Still invalid: #{@still_invalid}"
  end

  def validate_devices
    @devices = Device.all
    @total_devices = @devices.size
    @still_invalid = 0
    @devices.each { |device|
      device_id = device.id
      unless device.save
        MorLog.my_debug("")
        MorLog.my_debug("INVALID DEVICE: #{device_id}")
        if device.save
          MorLog.my_debug("VALIDATED DEVICE: #{device_id}")
        else
          str = ""
          device.errors.each { |key, value| str += " #{value}" }
          Action.new(:date => Time.now.to_s(:db), :target_id => device_id, :target_type => "device", :action => "error", :data => ("Device_still_invalid. " + str)[0..255], :processed => 0).save
          MorLog.my_debug("NOT VALIDATED DEVICE: #{device_id}")
          @still_invalid += 1
        end
      end
    }
    return "  Total devices: #{@total_devices}\n  Still invalid: #{@still_invalid}"
  end

  def validate_providers
    @providers, @validated_providers, @still_invalid = Provider.all, 0, 0
    @total_providers = @providers.size
    time_now = Time.now.to_s(:db)
    @providers.each { |provider|
      provider_id = provider.id
      unless provider.save
        MorLog.my_debug('')
        MorLog.my_debug("INVALID PROVIDER: #{provider_id}")

        provider.errors.each { |key, value|
          if key.to_s == "server_ip"
            provider_server_ip = provider.server_ip
            MorLog.my_debug("FIXING PROVIDER: #{provider_id} Wrong server_ip: #{provider_server_ip}")
            Action.new(:target_id => provider_id, :target_type => "provider", :date => time_now, :action => "provider_validated", :data => "server_ip_changer", :data2 => provider_server_ip, :data3 => "").save
            provider.server_ip = ''
          end
          if provider.name == ""
            MorLog.my_debug("FIXING PROVIDER: #{provider_id} Missing name")
            Action.new(:target_id => provider_id, :target_type => "provider", :date => time_now, :action => "provider_validated", :data => "creating_provider_name", :data2 => "Provider_#{provider_id}").save
            provider.name = "Provider_#{provider_id}"
          end
          if key.to_s == "port"
            provider_port = provider.port
            MorLog.my_debug("FIXING PROVIDER: #{provider_id} Wrong port: #{provider_port}")
            Action.new(:target_id => provider_id, :target_type => "provider", :date => time_now, :action => "provider_validated", :data => "cleaning_port", :data2 => provider_port, :data3 => provider_port.to_s.gsub(/[^0-9]/, "")).save
            provider.port = provider.port.to_s.gsub(/[^0-9]/, "")
          end
        }

        if provider.save
          MorLog.my_debug("VALIDATED PROVIDER: #{provider_id}")
          @validated_providers += 1
        else
          str = ""
          provider.errors.each { |key, value| str += " #{value}" }
          Action.new(:date => time_now, :target_id => provider_id, :target_type => "provider", :action => "error", :data => ("Provider_still_invalid. " + str)[0..255], :processed => 0).save
          MorLog.my_debug("NON VALIDATED PROVIDER: #{provider_id}")
          @still_invalid += 1
        end
      end
    }

    return "  Total providers: #{@total_providers}\n  Validated providers: #{@validated_providers}\n  Still invalid: #{@still_invalid}"
  end

  def validate_resellers_emails
    # No functionality currently exists for seperating admin template emails from reseller's, using a SQL condition local_warning_balance_email
    @emails = Email.where("owner_id = 0 AND template = 1 AND name != 'warning_balance_email_local'").size
    @em_s = @emails.to_i - 2
    @resellers = User.select("users.* , COUNT(emails.id) as 'em_size'").
                      where("usertype = 'reseller' AND template = 1").
                      joins("JOIN emails ON (emails.owner_id = users.id)").
                      group("users.id").to_a

    @total_resellers = @resellers.size
    @validated_resellers = 0
    @still_invalid = 0
    @resellers.each { |reseller|

      if reseller.em_size.to_i != @em_s.to_i
        reseller.check_reseller_emails
        @validated_resellers +=1
      end
    }
    return "  Total Resellers: #{@total_resellers}\n  Validated resellers: #{@validated_resellers}\n  Still invalid: #{@still_invalid}"
  end
end

