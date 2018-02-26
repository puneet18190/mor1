#!/usr/bin/env ruby

ENV['RAILS_ENV'] = ARGV.first || ENV['RAILS_ENV'] || 'production'
require File.expand_path(File.dirname(__FILE__) + '/../../config/environment')

now = Time.now
puts "MASS SMS Start: #{now}"

time = now.strftime('%T')
campaigns = SmsCampaign.where("status = 'enabled' AND start_time < '#{time}' AND stop_time > '#{time}'").to_a
puts "Found #{campaigns.size} campaigns\n"

campaigns.each do |campaign|
  user = User.where(id: campaign.user_id).first
  adactions = campaign.sms_adactions.where(priority: 1).limit(1)
  campaign_device = campaign.device

  numbers = campaign.sms_adnumbers.where(status: 'new')
  send_numbers = numbers.to_a

  numbers.update_all(status: 'executed')

  send_numbers.each do |number|
    # Get daytype and localization settings
    sms_number, usable_location = number.number, 'A.location_id = locations.id'
    date = now.strftime('%F')

    if campaign.owner.usertype == 'reseller'
      usable_location << ' AND A.location_id != 1'
    elsif !campaign_device.location
      usable_location << ' OR A.location_id = 1'
    end

    sql = "
    SELECT A.*,
          (SELECT IF(
                     (SELECT daytype FROM days WHERE date = '#{date}') IS NULL,
                     (SELECT IF(
                                WEEKDAY('#{date}') = 5 OR WEEKDAY('#{date}') = 6,
                                'FD',
                                'WD'
                               )),
                     (SELECT daytype FROM days WHERE date = '#{date}')
                    )
          ) AS 'dt'
    FROM devices
    JOIN locations ON (locations.id = devices.location_id)
    LEFT JOIN (SELECT *
               FROM locationrules
               WHERE enabled = 1
                     AND lr_type = 'dst'
                     AND LENGTH('#{sms_number}') BETWEEN minlen AND maxlen
                     AND (
                          SUBSTRING('#{sms_number}', 1, LENGTH(cut)) = cut
                          OR LENGTH(cut) = 0
                          OR ISNULL(cut)
                         )
               ORDER BY LENGTH(cut) DESC
              ) AS A ON (#{usable_location})
    WHERE devices.id = #{campaign_device.id}
    "

    res = ActiveRecord::Base.connection.select_one(sql)

    @daytype = res['dt']
    @loc_add = res['add']
    @loc_cut = res['cut']
    @loc_rule = res['name']
    @loc_lcr_id = res['lcr_id']
    @loc_tariff_id = res['tariff_id']
    @loc_device_id = res['device_id']

    loc_dst = Location.nice_locilization(@loc_cut, @loc_add, sms_number)

    adactions.each do |adaction|
      puts sms_number
      puts loc_dst
      puts adaction.data2
      puts user.sms_lcr.name
      number.executed_time = Time.now
      number.completed_time = ''

      # Form a Providers queue
      sms_providers = SmsProvider.find_providers_by_lcr(user.sms_lcr.id, sms_number, user)
      # Create a message
      sms = SmsMessage.create(sending_date: Time.now, user_id: user.id, reseller_id: user.owner_id, number: sms_number, sms_campaign_id: campaign.id)

      begin
        if sms_providers.present?
          # Try sending via each Provider in a queue till the message passes
          sms_providers.each do |provider|
            puts "TRYING provider: id = #{provider['providers_id']}"
            sms.sms_send(user, user.sms_tariff, loc_dst, user.sms_lcr, adaction.data2.to_i, adaction.data,
              { smsprovider: provider, src: campaign.callerid.to_s, unicode: adaction.data3.to_s })
            break if sms.status_code == 0
            puts 'FAILED'
          end
        else
          sms.sms_send(user, user.sms_tariff, loc_dst, user.sms_lcr, adaction.data2.to_i, adaction.data,
            { src: campaign.callerid.to_s, unicode: adaction.data3.to_s })
        end
      rescue Errno::ECONNREFUSED => err
        sms.status_code = '009'
        puts err
      rescue => err
        sms.status_code = '001'
        puts err
      ensure
        sms.save
      end

      if sms.sms_status_code == 'sent'
        number.status = 'completed'
        number.completed_time = Time.now
      end
    end

    number.save
  end
end

puts "MASS SMS End: #{Time.now}"
