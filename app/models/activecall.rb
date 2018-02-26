# -*- encoding : utf-8 -*-
# Active Calls model
class Activecall < ActiveRecord::Base
  attr_accessible :id, :server_id, :uniqueid, :start_time, :answer_time, :transfer_time, :src,
    :dst, :src_device_id, :dst_device_id, :channel, :dstchannel, :prefix, :provider_id, :did_id,
    :user_id, :owner_id, :localized_dst, :card_id, :user_rate, :lega_codec, :legb_codec, :pdd, :destination_name,
    :direction_code

  belongs_to :provider
  belongs_to :user
  belongs_to :did
  belongs_to :server

  def src_device
    Device.where(id: self.src_device_id).first
  end

  def dst_device
    Device.where(id: dst_device_id).first
  end

  def destination
    Destination.where(prefix: self.prefix).first
  end

  def duration
    answer_time ? Time.now.getlocal - Time.parse(answer_time.to_s) : ''
  end

  def get_user_rate(user = nil, destination = nil)
#    user = self.user unless user
#    destination = self.destination unless destination
#
#    user_rate = nil
#    user_rate = self.user_rate
#    unless user_rate and destination
#      rate = Rate.find(:first, :include => [:ratedetails], :conditions => ["rates.tariff_id = ? AND rates.destination_id = ?", user.tariff_id, destination.id]).ratedetails[0]
#      user_rate = rate.rate.to_d
#    end
    user_rate = self.user_rate ? self.user_rate.to_d : 0.to_d
    return User.current.get_rate(user_rate)
  end

  def Activecall.count_for_user(user, show_answered = false)
    hide_active_calls_longer_than = Confline.get_value('Hide_active_calls_longer_than', 0).to_i
    hide_active_calls_longer_than = 24 if hide_active_calls_longer_than.zero?
    only_answered = 'AND (activecalls.answer_time IS NOT NULL)' if show_answered
    if user and user.id and user.usertype
      if user.usertype == "admin" or user.usertype == 'accountant'
        return Activecall.where("(DATE_ADD(activecalls.start_time, INTERVAL #{hide_active_calls_longer_than} HOUR) > NOW()) #{only_answered}").count
      else
        if user.usertype == "reseller"
          # reseller
          user_sql = " WHERE (activecalls.user_id = #{user.id} OR dst_usr.id = #{user.id} OR  activecalls.owner_id = #{user.id} OR dst_usr.owner_id =  #{user.id}) AND (DATE_ADD(activecalls.start_time, INTERVAL #{hide_active_calls_longer_than} HOUR) > NOW()) #{only_answered}"
        else
          # user
          user_sql = " WHERE (activecalls.user_id = #{user.id} OR dst_usr.id = #{user.id}) AND (DATE_ADD(activecalls.start_time, INTERVAL #{hide_active_calls_longer_than} HOUR) > NOW()) #{only_answered}"
        end
        sql = "
        SELECT COUNT(*)
        FROM activecalls
        LEFT JOIN devices AS dst ON (dst.id = activecalls.dst_device_id)
        LEFT JOIN users AS dst_usr ON (dst_usr.id = dst.user_id)
        #{user_sql}"
        return ActiveRecord::Base.connection.select_value(sql)
      end
    end
    return 0
  end

  def update_by_destination
    if prefix.present?
      destination = @@destinations_cache[prefix.try(:to_sym)]
      # logger.info "FOUND0: #{destination.try(:name)}  #{destination.try(:direction_code).to_s}"
      unless destination.present?
        destination = Application.find_closest_destinations(prefix)
        @@destinations_cache[prefix.to_sym] = destination
      end
      # logger.info "FOUND: #{destination.try(:name)}  #{destination.try(:direction_code).to_s}"
      self.destination_name = destination.try(:name).to_s
      self.direction_code = destination.try(:direction_code).to_s
    end
  end

  def self.update_calls_by_destinations(calls)
    @@destinations_cache = {}
    calls.each{ |active_call| active_call.update_by_destination }
    @@destinations_cache = {}
  end
end
