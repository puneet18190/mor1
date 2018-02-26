# -*- encoding : utf-8 -*-
# Blocked Servers' IP
class BlockedIP < ActiveRecord::Base
  attr_protected

  def validate_ip_for_blocking
    # IP correct
    return false if blocked_ip.blank? || blocked_ip.gsub(/(^(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:[.](?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}$)/, '').to_s.length > 0

    # IP unique per Server
    return false if BlockedIP.where(blocked_ip: blocked_ip, server_id: server_id).present?

    # IP not used in any server
    return false if Server.pluck(:server_ip).include?(blocked_ip)

    # IP not Private (RFC1918)
    return false if /^(?:10|127|172\.(?:1[6-9]|2[0-9]|3[01])|192\.168)\..*/.match(blocked_ip)

    # IP not local
    return false if `/sbin/ifconfig -a`.include?(blocked_ip) || `/sbin/ip addr show`.include?(blocked_ip)
    true
  end

  def self.monitorings_blocked_ips
    select("
      blocked_ips.id AS id, blocked_ip, blocked_ips.server_id,
      CONCAT('ID: ', blocked_ips.server_id, ', IP: ', servers.server_ip) AS server, chain AS reason
    ")
    .joins('LEFT JOIN servers ON servers.id = blocked_ips.server_id')
    .where(unblock: 0)
    .order('server ASC, blocked_ip ASC')
  end

  def self.check_if_blocked(ip = '')
    joins('LEFT JOIN servers ON servers.id = blocked_ips.server_id').
        where(blocked_ip: ip.to_s, unblock: 0).present?
  end

  def country
    Iplocation.get_location(blocked_ip).try(:country).to_s
  end

  def direction_code(from_country = country)
    Direction.where(name: from_country).first.try(:code).to_s
  end

  def unblock
    update_column(:unblock, 1)
  end
end
