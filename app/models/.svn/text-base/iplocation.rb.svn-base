# -*- encoding : utf-8 -*-
# Getting location by IP
class Iplocation < ActiveRecord::Base
  require 'net/http'
  require 'uri'

  attr_protected

  validates_presence_of :latitude, :longitude, :ip

  def approve
    update_attribute(:approved, 1)
  end

  def admin_ip_send_email_authorization
    url = "#{Web_URL}/#{Web_Dir}/callc/admin_ip_access?id=#{uniquehash}"
    body = "Unauthorized IP: #{ip} tried to login as Admin to your system #{Web_URL}.<br/><br/>"
    body << "If you want to authorize this IP press this link: <a href=\"#{url}\">#{url}</a><br/><br/>"
    body << "If you want to block this IP press this link: <a href=\"#{url}&block_ip=1\">#{url}&block_ip=1</a>"

    admin_email_to = User.find(0).try(:email).to_s

    if Confline.get_value('Email_Sending_Enabled', 0).to_i == 1 && admin_email_to.present?
      smtp_server = Confline.get_value('Email_Smtp_Server', 0).to_s.strip
      smtp_user = Confline.get_value('Email_Login', 0).to_s.strip
      smtp_pass = Confline.get_value('Email_Password', 0).to_s.strip
      smtp_port = Confline.get_value('Email_Port', 0).to_s.strip

      from = Confline.get_value('Email_from', 0).to_s
      begin
        system_call = ApplicationController::send_email_dry(from, admin_email_to, body, 'Admin IP authorization request', '', "'#{smtp_server.to_s}:#{smtp_port.to_s}' -xu '#{smtp_user.to_s}' -xp '#{smtp_pass.to_s}'", 'html')

        if defined?(NO_EMAIL) && NO_EMAIL.to_i == 1
          # do nothing
        else
          system(system_call)
        end
      rescue
      end
    end
  end

  def block_ip
    Server.all.each do |server|
      BlockedIP.create(blocked_ip: ip, server_id: server.id, chain: 'Unauthorized Admin IP', unblock: 2)
    end
  end

  def self.admin_ip_find_or_create(ip)
    where("ip = ? AND uniquehash != ''", ip).first || create(ip: ip, created_at: Time.now, uniquehash: ApplicationController::random_password(30))
  end

  def self.get_location_from_hostip(ip, loc)
    if check_ip(ip)
      loc.ip = ip
      begin
        mas = Net::HTTP.get_response('api.hostip.info', "/get_html.php?ip=#{ip}&position=true").body
        if mas.present?
          mas = mas.split("\n")
          loc.country = mas[0].to_s.split(':')[1].to_s.split('(')[0].to_s.strip.titlecase if mas[0].split(':')[1].to_s.strip.present?
          loc.city = mas[1].to_s.split(':')[1].to_s.strip.titlecase if mas[1].split(':')[1].strip.present?
          loc.latitude = mas[2].split(':')[1].to_d
          loc.longitude = mas[3].split(':')[1].to_d
        else
          self.reset_location(loc)
        end
      rescue => exc
        MorLog.my_debug("IpLocation error: #{exc.to_yaml}")
        self.reset_location(loc)
      end
    end
    loc
  end

  def self.get_location_from_whatismyipaddress(ip, loc)
    if check_ip(ip)
      loc.ip = ip
      begin
        url = URI.parse('http://whatismyipaddress.com/ip/' + ip.to_s)
        # Build the params string
        req = Net::HTTP::Get.new(url.path)
        req.add_field(
            'user-agent',
            'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.83 Safari/535.11'
        )
        res = Net::HTTP.new(url.host, url.port).start { |http| http.request(req) }.body

        if res.present?
          lat = res.match(/<tr><th>Latitude:<\/th><td>(.*)<\/td><\/tr>/)
          lon = res.match(/<tr><th>Longitude:<\/th><td>(.*)<\/td><\/tr>/)
          lat = res.match(/<tr><th>Latitude:<\/th><td>\n(.*)&nbsp;&nbsp;/) if lat.blank?
          lon = res.match(/<tr><th>Longitude:<\/th><td>\n(.*)&nbsp;&nbsp;/) if lon.blank?
          cit = res.match(/<tr><th>City:<\/th><td>(.*)<\/td><\/tr>/)
          cou = res.match(/<tr><th>Country:<\/th><td>(.*)<\/td><\/tr>/)
          loc.longitude = lon[1].to_d if lon
          loc.latitude = lat[1].to_d if lat
          loc.city = cit[1].to_s.strip.titlecase if cit
          loc.country = cou[1].to_s.gsub(/<img.*>/, '').strip.titlecase.gsub(/Republic Of /, '') if cou
        else
          self.reset_location(loc)
        end
      rescue => exc
        MorLog.my_debug("IpLocation error: #{exc.to_yaml}")
        self.reset_location(loc)
      end
    end
    loc
  end

  def self.get_location_from_ip_address(ip, loc)
    if check_ip(ip)
      loc.ip = ip
      begin
        url = URI.parse('http://www.ip-adress.com/ip_tracer/' + ip.to_s)
        # Build the params string
        req = Net::HTTP::Get.new(url.path)
        req.add_field(
            'user-agent',
            'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.83 Safari/535.11'
        )
        res = Net::HTTP.new(url.host, url.port).start { |http| http.request(req) }.body

        if res.present?
          cou = res.match(/<th>IP address country:<\/th>\r\n<td>\r\n(.*)<\/td>\r\n<\/tr>/)
          cit = res.match(/<th>IP address city:<\/th>\r\n<td>\r\n(.*)<\/td>\r\n<\/tr>/)
          lat = res.match(/<th>IP address latitude:<\/th>\r\n<td>\r\n(.*)<\/td>\r\n<\/tr>/)
          lon = res.match(/<th>IP address longitude:<\/th>\r\n<td>\r\n(.*)<\/td>\r\n<\/tr>/)
          loc.country = cou[1].gsub(/<img.*>/, '').strip.titlecase if cou
          loc.city = cit[1].strip.titlecase if cit
          loc.longitude = lon[1].strip.to_d if lon
          loc.latitude = lat[1].strip.to_d if lat
        else
          self.reset_location(loc)
        end
      rescue => exc
        MorLog.my_debug("IpLocation error: #{exc.to_yaml}")
        self.reset_location(loc)
      end
    end
    loc
  end

  def self.get_location_from_google_geo(dst, dir, loc, prefix)
    return loc if dst == '' && dir == ''

    begin
      res = JSON.parse(
          Net::HTTP.get_response(
            URI.parse(
              URI.escape("http://maps.googleapis.com/maps/api/geocode/json?address=#{dir}&output=csv&sensor=false")
            )
          ).body
      )['results'].first['geometry']['location']

      if res
        loc.ip = prefix
        loc.latitude = res['lat'].to_d
        loc.longitude = res['lng'].to_d
        loc.city = ''
        loc.country = dir.lstrip
      end

    rescue => exc
      MorLog.my_debug("IpLocation error: #{exc.to_yaml}")
      loc.ip = prefix
      self.reset_location(loc)
    end
    loc
  end

  def self.get_location(ip, prefix = nil)
    loc = where(ip: ip).first
    return loc if loc

    loc = new
    if ip.to_s == ''
      loc.latitude = 0
      loc.longitude = 0
      return loc
    end

    if prefix == nil
      loc.latitude = 0
      loc.longitude = 0

      if loc.latitude == 0 && loc.longitude == 0
        loc = Iplocation.get_location_from_whatismyipaddress(ip, loc)
        MorLog.my_debug("from whatismyipaddress\n#{loc.to_yaml}")
      end

      if loc.latitude == 0 && loc.longitude == 0
        loc = Iplocation.get_location_from_ip_address(ip, loc)
        MorLog.my_debug("from ip_address\n#{loc.to_yaml}")
      end
    else
      dst = Destination.where(prefix: ip).first
      if dst
        loc = get_location_from_google_geo(dst.name.to_s, dst.direction.try(:name).to_s, loc, ip)
      end
    end
    loc.save
    loc
  end

  def self.check_ip(ip)
    ip_splitted = ip.try(:split, '.')
    if ip_splitted.try(:size) == 4
      ip_splitted.each do |digit|
        next if digit =~ /^[0-9]+$/ && digit.to_i.between?(0, 255)
        return false
      end
      return ip_splitted[3].to_i.between?(1, 254) ? true : false
    else
      false
    end
  end

  private

  def self.reset_location(loc)
    loc.country = ''
    loc.city = ''
    loc.latitude = 0
    loc.longitude = 0
  end
end
