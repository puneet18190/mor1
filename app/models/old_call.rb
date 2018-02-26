# -*- encoding : utf-8 -*-
class OldCall < ActiveRecord::Base

  include SqlExport
  include CsvImportDb
  belongs_to :user
  belongs_to :provider
  belongs_to :device, :foreign_key => "accountcode"
  has_many :cc_actions
  has_one :recording
  belongs_to :card
  belongs_to :server

  has_and_belongs_to_many :cs_invoices

  validates_presence_of :calldate, :message => _("Calldate_cannot_be_blank")

  attr_accessible :calldate

  # Nasty hack to overide provider method. Used in CallController.advanced_list and coresponding view.
  # MK: provider is only Termination provider, if some method needs did provider, then it should use did_provider method
  # MK: callertype=Local/Outside does not show correctly if call is outgoing or incomming, MOR also has calls which are incoming+outgoing at the same time
  alias_method :provider_by_id, :provider

  def self.table_name()
    "calls_old"
  end

  attr_protected

  def provider
    #if self.callertype == 'Local' #outgoing call
    Provider.where("id = #{self.provider_id.to_i}").first
    #end
    #if self.callertype == 'Outside' #incoming call
    #  return Provider.find(:first, :conditions => "id = #{self.did_provider_id}")
    #end
    #return nil
  end

  def did_provider
    Provider.where("id = #{self.did_provider_id.to_i}").first
  end

  def nice_billsec
    #it is used to show correct billsec for flat-rates call, because call.billsec = 0 for flatrates, but real_billsec > 0
    # billsec = 0 because to do not ruin rerating and to handle call which part is billed by flat-rate, another part by normal rate
    billsec = self.billsec
    billsec = self.real_billsec.ceil if billsec == 0 and self.real_billsec > 0
    billsec
  end

  def OldCall.nice_billsec_sql
    current_user = User.current

    if current_user.is_user? and Confline.get_value("Invoice_user_billsec_show", current_user.owner.id).to_i == 1
      "CEIL(user_billsec) as 'nice_billsec'"
    elsif current_user.is_partner?
      "CEIL(partner_billsec) as 'nice_billsec'"
    else
      "IF((billsec = 0 AND real_billsec > 0), CEIL(real_billsec), billsec) as 'nice_billsec'"
    end
  end

  def OldCall.nice_answered_cond_sql(search_not = true)
    if User.current.usertype.to_s == 'user' and Confline.get_value('Change_ANSWER_to_FAILED_if_HGC_not_equal_to_16_for_Users').to_i == 1
      if search_not
        " (calls_old.disposition='ANSWERED' AND calls_old.hangupcause='16') "
      else
        " (calls_old.disposition='ANSWERED' OR (calls_old.disposition='ANSWERED' AND calls_old.hangupcause!='16') ) "
      end
    else
      " calls_old.disposition='ANSWERED' "
    end
  end

  def OldCall.nice_failed_cond_sql
    if User.current.usertype.to_s == 'user' and Confline.get_value('Change_ANSWER_to_FAILED_if_HGC_not_equal_to_16_for_Users').to_i == 1
      " (calls_old.disposition='FAILED' OR (calls_old.disposition='ANSWERED' and calls_old.hangupcause!='16')) "
    else
      " calls_old.disposition='FAILED' "
    end
  end

  def OldCall.nice_disposition
    if User.current.usertype.to_s == 'user' and Confline.get_value('Change_ANSWER_to_FAILED_if_HGC_not_equal_to_16_for_Users').to_i == 1
      " IF(calls_old.disposition  = 'ANSWERED',IF((calls_old.disposition='ANSWERED' AND calls_old.hangupcause='16'), 'ANSWERED', 'FAILED'),disposition)"
    else
      " calls_old.disposition"
    end
  end


  def reseller
    res = nil
    res = User.where("id = #{self.reseller_id}").first if self.reseller_id.to_i > 0
    res
  end

  def destinations
    de = nil
    de = Destination.find(self.prefix) if self.prefix and self.prefix.to_i > 0
    de
  end

  def OldCall::total_calls_by_direction_and_disposition(start_date, end_date, users = [])
    #parameters:
    #  start_date - min date for filtering out calls, expected to be date/datetime
    #    instance or date/datetime as string
    #  end_date - max date for filtering out calls, expected to be date instance or date as
    #    string.
    #  users - array of user id's
    #returns - array of hashs. total call count for incoming and outgoing, answered, not answered,
    #  busy and failed calls grouped by disposition and direction originated or received by
    #  specified users. if no users were specified - for all users
    OldCall.total_calls_by([], {:outgoing => true, :incoming => true}, start_date, end_date, {:direction => true, :disposition => true}, users)
  end

  def OldCall::answered_calls_day_by_day(start_date, end_date, users = [])
    #parameters:
    #  start_date - min date for filtering out calls, expected to be date/datetime
    #    instance or date/datetime as string
    #  end_date - max date for filtering out calls, expected to be date instance or date as
    #    string.
    #  users - array of user id's
    #returns answered call count, total billsec, and average billsec for everyday in datetime
    #interval for specified users or if no user is specified - for all users
    day_by_day_stats = OldCall.total_calls_by(['ANSWERED'], {:outgoing => true, :incoming => true}, start_date, end_date, {:date => true}, users)

    start_date = (start_date.to_time + Time.zone.now.utc_offset().second - Time.now.utc_offset().second).to_s(:db)
    end_date = (end_date.to_time + Time.zone.now.utc_offset().second - Time.now.utc_offset().second).to_s(:db)

    start_date = Date.strptime(start_date, "%Y-%m-%d").to_date
    end_date = Date.strptime(end_date, "%Y-%m-%d").to_date
    date = []
    calls = []
    billsec = []
    avg_billsec = []
    index = 0
    i = 0
    start_date.upto(end_date) do |day|
      day_stats = day_by_day_stats[i]
      if day_stats and day_stats['calldate'] and day.to_date == day_stats['calldate'].to_date
        date[index] = day_stats['calldate'].strftime("%Y-%m-%d")
        calls[index] = day_stats['total_calls'].to_i
        billsec[index] = day_stats['total_billsec'].to_i
        avg_billsec[index] = day_stats['average_billsec'].to_i
        i += 1
      else
        date[index] = day
        calls[index] = 0
        billsec[index] = 0
        avg_billsec[index] = 0
      end
      index += 1
    end

    calls << day_by_day_stats.last['total_calls']
    billsec << day_by_day_stats.last['total_billsec']
    avg_billsec << day_by_day_stats.last['average_billsec']

    return date, calls, billsec, avg_billsec
  end

  def OldCall::total_calls_by(disposition, direction, start_date, end_date, group_options = [], users = [])
    #parameters:
    #  disposition - expected array of dispositions deffined as
    #    strings(why not incapsulate strings by creating class Disposition?)
    #  direction - call direction(outgoing, incoming or both) expected array
    #    of posible directions as contstans or whatever it is:/(again why not
    #    incapsulate it in separate class?)
    #  start_date - min date for filtering out calls, expected to be date/datetime
    #    instance or date/datetime as string
    #  end_date - max date for filtering out calls, expected to be date instance or date as
    #    string. if datetime or datetime sring will be passed QUERY WILL FAIL
    #  users - array of user id's, if not supplied, but direction is it will default to all
    #    incoming and/or outgoing calls
    #returns:
    #  whatever Calls.find returns, and the last element in array will be totals/averages of all fetched values
    select = []
    select << "COUNT(*) AS 'total_calls'"
    select << "SUM(calls_old.billsec) AS 'total_billsec'"
    select << "AVG(calls_old.billsec) AS 'average_billsec'"

    condition = []
    condition << "calls_old.calldate BETWEEN '#{start_date.to_s}' AND '#{end_date.to_s}'"
    #if disposition is not specified or it is all 4 types(answered, failed, busy, no answer),
    #there is no need to filter it
    condition << "calls_old.disposition IN ('#{disposition.join(', ')}')" if !disposition.empty? and disposition.length < 4

    join = []
    if users.empty?
      if direction.include?(:incoming) and direction.include?(:outgoing)
        condition << "calls_old.user_id IS NOT NULL"
      else
        condition << 'calls_old.user_id != -1 AND calls_old.user_id IS NOT NULL' if direction.include?(:outgoing)
        condition << 'calls_old.user_id = -1' if direction.include?(:incoming)
      end
    else
      #no mater weather we are allready checking devices for user_id, call.user_id might still be NULL, else we would select
      #to many failed calls
      condition << "calls_old.user_id IS NOT NULL"
      if direction.include?(:outgoing) and direction.include?(:incoming)
        condition << "(dst_devices.user_id IN (#{users.join(', ')}) OR src_devices.user_id IN (#{users.join(', ')}))"
      end
      if direction.include?(:incoming)
        join << 'LEFT JOIN devices dst_devices ON calls_old.dst_device_id = dst_devices.id'
        condition << "dst_devices.user_id IN (#{users.join(', ')}" if !direction.include?(:outgoing)
      end
      if direction.include?(:outgoing)
        join << 'LEFT JOIN devices src_devices ON calls_old.src_device_id = src_devices.id'
        condition << "src_devices.user_id IN (#{users.join(', ')})" if !direction.include?(:incoming)
      end
    end

    #dont group at all, group by date, direction and/or disposition
    #accordingly, we should select those fields from table
    group = []
    if group_options[:date]
      select << "(calls_old.calldate) AS 'calldate'"
      if Time.zone.now().utc_offset.to_i == 0
        group << 'FLOOR((UNIX_TIMESTAMP(calls_old.calldate)) / 86400)' # grouping by intervals of exact 24 hours
      else
        group << 'year(calldate), month(calldate), (day(calldate) + FLOOR(HOUR(calldate) / 24)) ORDER BY calldate ASC'
      end
    end
    if group_options[:disposition]
      select << 'calls_old.disposition'
      group << 'calls_old.disposition' if group_options[:disposition]
    end

    if group_options[:direction]
      if users.empty?
        select << "IF(calls_old.user_id  = -1, 'incoming', 'outgoing') AS 'direction'"
        group << 'direction'
      else
        if direction.include?(:incoming)
          select << "IF(dst_devices.user_id IN (#{users.join(', ')}), 'incoming', 'outgoing') AS 'direction'"
          group << 'direction'
        end
        if direction.include?(:outgoing) and !direction.include?(:incoming)
          select << "IF(src_device.user_id IN (#{users.join(', ')}), 'outgoing', 'incoming') AS 'direction'"
          group << 'direction'
        end
      end
    end

    if group_options[:date]
      statistics = OldCall.select(select.join(', ')).joins(join.join(' ')).where(condition.join(' AND ')).group(group.join(', ')).all
      statistics.each do |st|
        st.calldate = (st.calldate.to_time + Time.zone.now.utc_offset().second - Time.now.utc_offset().second).to_s(:db) if !st.calldate.blank?
      end
    else
      statistics = OldCall.select(select.join(', ')).joins(join.join(' ')).where(condition.join(' AND ')).group(group.join(', ')).all
    end

    #calculating total billsec, total calls and average billsec
    total_calls = 0
    total_billsec = 0
    for stats in statistics
      total_calls += stats['total_calls'].to_i
      total_billsec += stats['total_billsec'].to_i
    end
    average_billsec = total_calls == 0 ? 0 : total_billsec/total_calls

    #return array of hashs, bet we should definetly return some sort of Statistics class
    statistics << {'total_calls' => total_calls, 'total_billsec' => total_billsec, 'average_billsec' => average_billsec}
  end

  def OldCall::summary_by_terminator(cond, terminator_cond, order_by, user)
    if user.usertype == "reseller"
      provider_billsec = "SUM(IF(calls_old.disposition = 'ANSWERED', calls_old.reseller_billsec, 0)) AS 'provider_billsec'"
      provider_price = SqlExport.replace_price("SUM(#{SqlExport.calls_old_reseller_provider_price_sql})", {:reference => 'provider_price'})
      cond << "users.owner_id = #{user.id}"
    else
      provider_billsec = "SUM(IF(calls_old.disposition = 'ANSWERED', calls_old.provider_billsec, 0)) AS 'provider_billsec'"
      provider_price = SqlExport.replace_price("SUM(#{SqlExport.calls_old_admin_provider_price_sql} - calls_old.did_prov_price)", {:reference => 'provider_price'})
    end

    #limit terminators to allowed ones.
    term_ids = user.load_terminators_ids
    if term_ids.size == 0
      cond << "provider.terminator_id = 0"
    else
      cond << "provider.terminator_id IN (#{term_ids.join(", ")})"
    end

    sql = "
    SELECT
    #{SqlExport.nice_user_sql},
    provider.name AS 'provider_name',
    provider.id AS 'prov_id',
    COUNT(*) AS 'total_calls',
    SUM(IF(calls_old.disposition = 'ANSWERED', 1,0)) AS 'answered_calls',
    SUM(IF(calls_old.disposition = 'ANSWERED', calls_old.billsec, 0)) AS 'exact_billsec',
    #{[provider_billsec, provider_price].join(",\n ")}

    FROM calls_old  FORCE INDEX (calldate)
    LEFT JOIN devices ON (calls_old.src_device_id = devices.id)
    LEFT JOIN users ON (users.id = devices.user_id)
    INNER JOIN (
      SELECT providers.id, terminators.name, providers.terminator_id
      FROM providers
       INNER JOIN terminators ON (providers.terminator_id = terminators.id) #{terminator_cond.to_s == '' ? '' : ' WHERE terminators.id = '+ terminator_cond.to_s })
      AS provider ON (provider.id = calls_old.provider_id)
    LEFT JOIN destinations ON (destinations.prefix = calls_old.prefix)
    LEFT JOIN directions ON (destinations.direction_code = directions.code)
    #{SqlExport.calls_old_left_join_reseler_providers_to_calls_sql}
    WHERE(" + cond.join(" AND ")+ ")
    GROUP BY provider.name
    #{order_by.size > 0 ? 'ORDER BY ' +order_by : ''}
    "

    OldCall.find_by_sql(sql)
  end

=begin rdoc
=end

  def OldCall::summary_by_originator(cond, terminator_cond, order_by, user)
    if user.usertype == "reseller"
      cond << "users.owner_id = #{user.id}"
      originator_billsec= "SUM(IF(calls_old.user_billsec IS NULL AND calls_old.disposition = 'ANSWERED', 0, calls_old.user_billsec)) AS 'originator_billsec'"
      originator_price = "SUM(IF(calls_old.user_price IS NULL AND calls_old.disposition = 'ANSWERED', 0, #{SqlExport.replace_price(SqlExport.calls_old_user_price_sql)})) AS 'originator_price'"
      originator_price_with_vat = SqlExport.replace_price("SUM(#{SqlExport.summary_originator_price_with_vat("IF(calls_old.user_price IS NULL AND calls_old.disposition = 'ANSWERED', 0, #{SqlExport.replace_price(SqlExport.calls_old_user_price_sql)})")})", {:reference => 'originator_price_with_vat'})
    else
      originator_billsec= "SUM(IF(owner_id = 0 AND calls_old.disposition = 'ANSWERED', IF(calls_old.user_billsec IS NULL, 0, calls_old.user_billsec), if(calls_old.reseller_billsec IS NULL, 0, calls_old.reseller_billsec))) AS 'originator_billsec'"
      originator_price = "SUM(#{SqlExport.replace_price(SqlExport.calls_old_admin_user_price_no_dids_sql)}) AS 'originator_price'"
      originator_price_with_vat = SqlExport.replace_price("SUM(#{SqlExport.summary_originator_price_with_vat(SqlExport.replace_price(SqlExport.calls_old_admin_user_price_no_dids_sql))})", {:reference => 'originator_price_with_vat'})
    end

    #limit terminators to allowed ones.
    term_ids = user.load_terminators_ids
    if term_ids.size == 0
      cond << "provider.terminator_id = 0"
    else
      cond << "provider.terminator_id IN (#{term_ids.join(", ")})"
    end

    sql = "
    SELECT
    #{SqlExport.nice_user_sql},

    COUNT(*) AS 'total_calls',
    SUM(IF(calls_old.disposition = 'ANSWERED', 1,0)) AS 'answered_calls',
    devices.user_id AS 'dev_user_id',
    SUM(IF(calls_old.disposition = 'ANSWERED', calls_old.billsec, 0)) AS 'exact_billsec',
    #{[originator_billsec, originator_price, originator_price_with_vat].join(",\n")}
    FROM calls_old FORCE INDEX (calldate)
    LEFT JOIN devices ON (calls_old.src_device_id = devices.id)
    LEFT JOIN users ON (users.id = devices.user_id)
    INNER JOIN (
    SELECT providers.id, terminators.name, providers.terminator_id
    FROM providers
    INNER JOIN terminators ON (providers.terminator_id = terminators.id) #{terminator_cond.to_s == '' ? '' : ' WHERE terminators.id = '+ terminator_cond.to_s })
    AS provider ON (provider.id = calls_old.provider_id)
    LEFT JOIN destinations ON (destinations.prefix = calls_old.prefix)
    LEFT JOIN directions ON (destinations.direction_code = directions.code)
    LEFT JOIN taxes ON (taxes.id = users.tax_id)
    #{SqlExport.calls_old_left_join_reseler_providers_to_calls_sql}
    WHERE(" + cond.join(" AND ")+ ")
    GROUP BY devices.user_id
    #{order_by.size > 0 ? 'ORDER BY ' +order_by : ''}
    "
    OldCall.find_by_sql(sql)
  end

  def OldCall.calls_order_by(params, options)
    case options[:order_by].to_s.strip
      when "time" then
        order_by = "calls_old.calldate"
      when "src" then
        order_by = "calls_old.src"
      when "dst" then
        order_by = "calls_old.dst"
      when "nice_billsec" then
        order_by = "nice_billsec"
      when "hgc" then
        order_by = "calls_old.hangupcause"
      when "server" then
        order_by = "calls_old.server_id"
      when "p_name" then
        order_by = "providers.name"
      when "p_rate" then
        order_by = "calls_old.provider_rate"
      when "p_price" then
        order_by = "calls_old.provider_price"
      when "reseller" then
        order_by = "nice_reseller"
      when "r_rate" then
        order_by = "calls_old.reseller_rate"
      when "r_price" then
        order_by = "calls_old.reseller_price"
      when "user" then
        order_by = "nice_user"
      when "u_rate" then
        order_by = "calls_old.user_rate"
      when "u_price" then
        order_by = "calls_old.user_price"
      when "number" then
        order_by = "dids.did"
      when "d_provider" then
        order_by = "calls_old.did_prov_price"
      when "d_inc" then
        order_by = "calls_old.did_inc_price"
      when "d_owner" then
        order_by = "calls_old.did_price"
      when "prefix" then
        order_by = "calls_old.prefix"
      when "direction" then
        order_by = "destinations.direction_code"
      when "destination" then
        order_by = "destinations.name"
      when "duration" then
        order_by = "duration"
      when "answered_calls" then
        order_by = "answered_calls"
      when "total_calls" then
        order_by = "total_calls"
      when "cardgroup" then
        order_by = "cardgroups.name"
      when "asr" then
        order_by = "asr"
      when "acd" then
        order_by = "acd"
      when "markup" then
        order_by = "markup"
      when "margin" then
        order_by = "margin"
      when "user_price" then
        order_by = "user_price"
      when "provider_price" then
        order_by = "provider_price"
      when "profit" then
        order_by = "profit"
      else
        order_by = options[:order_by]
    end
    if order_by != ""
      order_by += (options[:order_desc].to_i == 0 ? " ASC" : " DESC")
    end
    return order_by
  end


  def call_log
    c_l = CallLog.where(["uniqueid = ?", self.uniqueid]).first
    return c_l
  end

  def OldCall.last_calls(options={})
    cond, var, jn = OldCall.last_calls_parse_params(options)
    select = ["calls_old.*", OldCall.nice_billsec_sql]
    select << SqlExport.nice_user_sql
    #select << 'calls.user_id, users.first_name, users.last_name, card_id, cards.number'
    select << OldCall.nice_disposition + ' AS disposition'

    ['did_price', 'did_inc_price', 'did_prov_price'].each { |co| select << "(#{co} * #{options[:exchange_rate]}) AS #{co}_exrate" } if options[:current_user].usertype != 'partner'

    #if reseller pro - change common use provider price, rate to reseller tariff rate, price

    select << "(#{SqlExport.calls_old_reseller_rate_sql} * #{options[:exchange_rate]} ) AS reseller_rate_exrate"

    if options[:current_user].usertype == 'reseller'
      unless User.current.try(:owner).is_partner?
        select << "(IF(users.owner_id = #{options[:current_user].id}, 0, did_price) * #{options[:exchange_rate]} ) AS did_price_exrate"
        select << "(IF(users.owner_id = #{options[:current_user].id}, did_inc_price, 0) * #{options[:exchange_rate]} ) AS did_inc_price_exrate"
        select << "(did_prov_price * #{options[:exchange_rate]} ) AS did_prov_price_exrate"
      end
      if options[:current_user].reseller_allow_providers_tariff?
        select << "(#{SqlExport.calls_old_reseller_provider_rate_sql} * #{options[:exchange_rate]} ) AS provider_rate_exrate"
        select << "(#{SqlExport.calls_old_reseller_provider_price_sql} * #{options[:exchange_rate]} ) AS provider_price_exrate"
      end
      select << "(#{SqlExport.calls_old_user_price_no_dids_sql} * #{options[:exchange_rate]} ) AS user_price_exrate"
      select << "(#{SqlExport.calls_old_reseller_price_no_dids_sql} * #{options[:exchange_rate]} ) AS reseller_price_exrate"
      select << "(#{SqlExport.calls_old_user_rate_sql} * #{options[:exchange_rate]} ) AS user_rate_exrate"
      select << "(#{SqlExport.calls_old_reseller_profit_no_dids_sql(options[:current_user])} * #{options[:exchange_rate]} ) AS profit"
    elsif options[:current_user].usertype == 'partner'
      select << "(#{SqlExport.calls_old_partner_price_sql} * #{options[:exchange_rate]} ) AS partner_price"
      select << "(#{SqlExport.calls_old_user_price_no_dids_sql} * #{options[:exchange_rate]} ) AS user_price_exrate"
      select << "(#{SqlExport.calls_old_reseller_price_no_dids_sql} * #{options[:exchange_rate]} ) AS reseller_price_exrate"
      select << "(#{SqlExport.calls_old_user_rate_sql}  * #{options[:exchange_rate]} ) AS user_rate_exrate"
      select << "(#{SqlExport.calls_old_reseller_profit_no_dids_sql(options[:current_user])} * #{options[:exchange_rate]} ) AS profit"
    else
      if options[:current_user].usertype == 'user'
        select << "(IF(calls_old.user_id = #{options[:current_user].id}, #{SqlExport.calls_old_user_price_sql}, #{SqlExport.calls_old_user_did_price_sql}) * #{options[:exchange_rate]} ) AS user_price_exrate"
        select << "(#{SqlExport.calls_old_user_rate_sql} * #{options[:exchange_rate]} ) AS user_rate_exrate"
      else
        select << "(#{SqlExport.calls_old_user_price_no_dids_sql} * #{options[:exchange_rate]} ) AS user_price_exrate"
        select << "(#{SqlExport.calls_old_admin_reseller_price_no_dids_sql} * #{options[:exchange_rate]} ) AS reseller_price_exrate"
        select << "(#{SqlExport.calls_old_admin_user_rate_sql} * #{options[:exchange_rate]} ) AS user_rate_exrate"
        select << "(#{SqlExport.calls_old_admin_provider_rate_sql} * #{options[:exchange_rate]}) AS provider_rate_exrate "
        select << "(#{SqlExport.calls_old_admin_provider_price_sql} * #{options[:exchange_rate]} ) AS provider_price_exrate"
        select << "(#{SqlExport.calls_old_admin_profit_sql} + calls_old.did_price + calls_old.did_prov_price) * #{options[:exchange_rate]} AS profit"
      end
    end

    select << "IF(resellers.id > 0, #{SqlExport.nice_user_sql("resellers", nil)}, '') AS 'nice_reseller'"
    OldCall.select(select.join(", \n")).
            where([cond.join(" \nAND "), *var]).
            joins(jn.join(" \n")).
            order(options[:order]).
            limit("#{((options[:page].to_i - 1) * options[:items_per_page].to_i).to_i}, #{options[:items_per_page].to_i}").to_a
  end


  def self.last_calls_total_count(options = {})
    cond = self.last_calls_raw_conditions(options)

    date_condition = "(all_calls.calldate BETWEEN '#{options[:from]}' AND '#{options[:till]}')"

    if cond.present?
      sql_statement = "SELECT
                         COUNT(all_calls.id) as total_calls
                       FROM
                         (SELECT calls_old.id, calls_old.calldate
                           FROM calls_old
                           WHERE #{cond.join(' AND ')}
                          ) as all_calls
                       WHERE #{date_condition} LIMIT 1"
    else
      sql_statement  = "SELECT
                          COUNT(all_calls.id) as total_calls
                        FROM calls_old AS all_calls
                        WHERE #{date_condition} LIMIT 1"
    end

    self.connection.select_all(sql_statement)[0]['total_calls'].to_i
  end

  def OldCall.last_calls_total_stats(options={})
    options[:exchange_rate] ||= 1
    cond, var, jn = OldCall.last_calls_parse_params(options)
    #if reseller pro - change common use provider price, rate to reseller tariff rate, price
    if options[:current_user].usertype == 'reseller'
      prov_price = "(SUM(#{SqlExport.calls_old_reseller_provider_price_sql} * #{options[:exchange_rate].to_d})) as total_provider_price"
      profit = "(SUM(IF(calls_old.user_id = #{options[:current_user].id}, 0, #{SqlExport.calls_old_reseller_profit_no_dids_sql(options[:current_user])}) * #{options[:exchange_rate].to_d})) AS total_profit"

      user_price = SqlExport.calls_old_user_price_no_dids_sql
      reseller_price = SqlExport.calls_old_reseller_price_no_dids_sql
      did_inc_price = "SUM(IF(users.owner_id = #{options[:current_user].id}, did_inc_price, 0) * #{options[:exchange_rate].to_d}) as total_did_inc_price"
      did_price = "SUM(IF(users.owner_id = #{options[:current_user].id}, 0, did_price) * #{options[:exchange_rate].to_d}) as total_did_price"
    elsif options[:current_user].usertype == 'partner'
      prov_price = "(SUM(#{SqlExport.calls_old_reseller_provider_price_sql} * #{options[:exchange_rate].to_d} )) as total_provider_price"
      profit = "(SUM(IF(calls_old.user_id = #{options[:current_user].id}, 0, #{SqlExport.calls_old_reseller_profit_no_dids_sql(options[:current_user])}) * #{options[:exchange_rate].to_d})) AS total_profit"

      user_price = SqlExport.calls_old_user_price_no_dids_sql
      reseller_price = SqlExport.calls_old_reseller_price_no_dids_sql
      partner_price = "SUM(#{SqlExport.old_call_partner_price_no_dids_sql} * #{options[:exchange_rate].to_d})  as total_partner_price, "
      did_inc_price = "SUM(IF(users.owner_id = #{options[:current_user].id}, did_inc_price, 0) * #{options[:exchange_rate].to_d}) as total_did_inc_price"
      did_price = "SUM(IF(users.owner_id = #{options[:current_user].id}, 0, did_price) * #{options[:exchange_rate].to_d}) as total_did_price"
    else
      prov_price = "(SUM(#{SqlExport.calls_old_admin_provider_price_sql} * #{options[:exchange_rate].to_d})) as total_provider_price"
      profit = "(SUM( (#{SqlExport.calls_old_admin_profit_sql} + calls_old.did_price + calls_old.did_prov_price) * #{options[:exchange_rate].to_d})) AS total_profit"

      user_price = SqlExport.calls_old_user_price_no_dids_sql
      reseller_price = SqlExport.calls_old_admin_reseller_price_no_dids_sql
      did_inc_price = "SUM(did_inc_price * #{options[:exchange_rate].to_d}) as total_did_inc_price"
      did_price = "SUM(did_price * #{options[:exchange_rate].to_d}) as total_did_price"
    end
    if User.current.is_user? and Confline.get_value("Invoice_user_billsec_show", User.current.owner.id).to_i == 1
      billsec_sql = "CEIL(user_billsec)"
    elsif User.current.is_partner?
      billsec_sql = "CEIL(partner_billsec)"
    else
      billsec_sql = "IF((billsec = 0 AND real_billsec > 0), CEIL(real_billsec), billsec)"
    end

    did_and_prov_prices = "SUM(did_price * #{options[:exchange_rate].to_d})  AS total_did_price,
						  SUM(did_prov_price * #{options[:exchange_rate].to_d})  AS total_did_prov_price,"

    OldCall.select(" COUNT(*) AS total_calls,
                     SUM(#{billsec_sql}) AS total_duration,
                     SUM(IF(calls_old.user_id = #{options[:current_user].id}, #{SqlExport.calls_old_user_price_sql}, #{options[:current_user].usertype == "user" ? SqlExport.calls_old_user_did_price_sql : options[:current_user].usertype == 'partner' ? SqlExport.calls_old_user_price_no_dids_sql : SqlExport.calls_old_user_price_sql}) * #{options[:exchange_rate].to_d})  as total_user_price_with_dids,
                     SUM(#{user_price} * #{options[:exchange_rate].to_d}) AS total_user_price,
                     SUM(#{reseller_price} * #{options[:exchange_rate].to_d}) AS total_reseller_price,
                     #{partner_price}
                     SUM(#{SqlExport.calls_old_admin_reseller_price_no_dids_sql} * #{options[:exchange_rate].to_d}) AS total_reseller_price_with_dids,
                     SUM(did_prov_price * #{options[:exchange_rate].to_d}) AS total_did_prov_price,
                     #{did_price}, #{did_inc_price}, #{prov_price}, #{profit}").
            where([cond.join(' AND '), *var]).
            joins(jn.join(" \n")).first
  end

  def OldCall.last_calls_csv(options={})
    cond, var, jn = OldCall.last_calls_parse_params(options)
    s =[]
    format = Confline.get_value('Date_format', (options[:current_user].usertype == 'reseller' ? options[:current_user].id : options[:current_user].owner_id)).gsub('M', 'i')
    csv_full_src = true if options[:show_full_src].to_i == 1
    #calldate2 - because something overwites calldate when changing date format
    time_offset = options[:current_user].time_offset
    s << SqlExport.column_escape_null(SqlExport.nice_date('calls_old.calldate', {:format => format, :offset => time_offset}), "calldate2")
    unless csv_full_src
      s << SqlExport.column_escape_null("calls_old.src", "src")
    end
    if csv_full_src or options[:pdf].to_i == 1
      s << SqlExport.column_escape_null("calls_old.clid", "clid")
    end
    options[:current_user].usertype == 'user' ? s << SqlExport.hide_dst_for_user_sql(options[:current_user], "csv", SqlExport.column_escape_null("calls_old.localized_dst"), {:as => "dst"}) : s << SqlExport.column_escape_null("calls_old.localized_dst", "dst")

    if options[:current_user].usertype != 'reseller'
      s << SqlExport.column_escape_null("calls_old.prefix", "prefix")
    end
    s << "CONCAT(#{SqlExport.column_escape_null("directions.name")}, ' ', #{SqlExport.column_escape_null("destinations.name")}) as destination"
    s << OldCall.nice_billsec_sql

    if options[:current_user].usertype != 'user' or (Confline.get_value('Show_HGC_for_Resellers').to_i == 1 and options[:current_user].usertype == 'reseller')
      s << "CONCAT(#{SqlExport.column_escape_null("calls_old.disposition")}, '(', #{SqlExport.column_escape_null("calls_old.hangupcause")}, ')') AS dispod"
    else
      s << SqlExport.column_escape_null(OldCall.nice_disposition, 'dispod')
    end
    if options[:current_user].usertype == "admin" or options[:current_user].usertype == "accountant"
      s << SqlExport.column_escape_null("calls_old.server_id", "server_id")
      s << SqlExport.column_escape_null("providers.name", "provider_name")
      if options[:can_see_finances]
        s << SqlExport.replace_dec("(IF(providers.user_id > 0, 0, IFNULL(#{SqlExport.calls_old_admin_provider_rate_sql}, 0)) * #{options[:exchange_rate]} )", options[:column_dem], 'provider_rate')
        s << SqlExport.replace_dec("(IF(providers.user_id > 0, 0, IFNULL(#{SqlExport.calls_old_admin_provider_price_sql}, 0)) * #{options[:exchange_rate]} )", options[:column_dem], 'provider_price')
      end
      if Confline.get_value('RS_Active').to_i == 1
        nice_reseller = "IF(resellers.id != 0,IF(LENGTH(resellers.first_name + resellers.last_name) > 0, CONCAT(resellers.first_name, ' ',resellers.last_name ), resellers.username), ' ')"
        s << "IFNULL(#{nice_reseller}, ' ') AS 'nice_reseller'"
        if options[:can_see_finances]
          s << SqlExport.replace_dec("(#{SqlExport.calls_old_admin_reseller_rate_sql} * #{options[:exchange_rate]} ) ", options[:column_dem], 'reseller_rate')
          s << SqlExport.replace_dec("(#{SqlExport.calls_old_admin_reseller_price_no_dids_sql} * #{options[:exchange_rate]} ) ", options[:column_dem], 'reseller_price')
        end
      end

      s << "IF(calls_old.card_id = 0 ,IFNULL(NULLIF(CONCAT_WS(' ', NULLIF(users.first_name, ''), NULLIF(users.last_name, '')), ''), users.username), CONCAT('Card#', IF(cards.number IS NULL, '', cards.number))) as 'user'"
      if options[:can_see_finances]
        s << SqlExport.replace_dec("(IFNULL(#{SqlExport.calls_old_user_rate_sql}, 0) * #{options[:exchange_rate]} )", options[:column_dem], 'user_rate')
        s << SqlExport.replace_dec("(IFNULL(#{SqlExport.calls_old_user_price_no_dids_sql}, 0) * #{options[:exchange_rate]} ) ", options[:column_dem], 'user_price')
      end
      s << "IFNULL(dids.did, '') AS did"
      if options[:can_see_finances]
        s << SqlExport.replace_dec("(IFNULL(calls_old.did_prov_price, 0) * #{options[:exchange_rate]} ) ", options[:column_dem], 'did_prov_price')
        s << SqlExport.replace_dec("(IFNULL(calls_old.did_inc_price, 0) * #{options[:exchange_rate]} ) ", options[:column_dem], 'did_inc_price')
        s << SqlExport.replace_dec("(IFNULL(calls_old.did_price, 0) * #{options[:exchange_rate]} ) ", options[:column_dem], 'did_price')
      end
    end
    if options[:current_user].show_billing_info == 1 and options[:can_see_finances]
      if options[:current_user].usertype == 'reseller'
        if options[:current_user].reseller_allow_providers_tariff?
          provider_name_cnd = "IF(providers.common_use = 1, CONCAT('#{_('Provider')} ', providers.id), providers.name)"
          s << SqlExport.column_escape_null("IF(providers.user_id = 0 AND providers.common_use = 0, 'admin', #{provider_name_cnd})", 'provider_name')
          if options[:can_see_finances]
            #if reseller pro - change common use provider price, rate to reseller tariff rate, price
            s << SqlExport.replace_dec("(IFNULL(#{SqlExport.calls_old_reseller_provider_rate_sql}, 0) * #{options[:exchange_rate]} )", options[:column_dem], 'provider_rate')
            s << SqlExport.replace_dec("(IFNULL(#{SqlExport.calls_old_reseller_provider_price_sql}, 0) * #{options[:exchange_rate]} ) ", options[:column_dem], 'provider_price')
          end
        end
        s << SqlExport.replace_dec("(#{SqlExport.calls_old_reseller_rate_sql} * #{options[:exchange_rate]} ) ", options[:column_dem], 'reseller_rate')
        s << SqlExport.replace_dec("(#{SqlExport.calls_old_reseller_price_no_dids_sql} * #{options[:exchange_rate]} ) ", options[:column_dem], 'reseller_price')
        s << "IF(calls_old.card_id = 0, IFNULL(NULLIF(CONCAT_WS(' ', NULLIF(users.first_name, ''), NULLIF(users.last_name, '')), ''), users.username), CONCAT('Card#', IFNULL(cards.number, ''))) as 'user'"
        s << SqlExport.replace_dec("(#{SqlExport.calls_old_user_rate_sql} * #{options[:exchange_rate]} ) ", options[:column_dem], 'user_rate')
        s << SqlExport.replace_dec("(IF(#{SqlExport.calls_old_user_price_no_dids_sql} != 0 , (#{SqlExport.calls_old_user_price_no_dids_sql}), 0) * #{options[:exchange_rate]} ) ", options[:column_dem], 'user_price')

        s << "IFNULL(dids.did, '') AS did"

        s << SqlExport.replace_dec("(IF(calls_old.did_inc_price IS NULL OR users.owner_id = #{options[:current_user].id}, calls_old.did_inc_price, 0) * #{options[:exchange_rate]} ) ", options[:column_dem], 'did_inc_price')
        s << SqlExport.replace_dec("(IF(calls_old.did_price IS NULL OR users.owner_id != #{options[:current_user].id}, 0, calls_old.did_price) * #{options[:exchange_rate]} ) ", options[:column_dem], 'did_price')
      elsif options[:current_user].usertype == 'user'
        s << SqlExport.replace_dec("((IF(calls_old.user_id = #{options[:current_user].id},#{SqlExport.calls_old_user_price_sql},calls_old.did_price)) * #{options[:exchange_rate]} ) ", options[:column_dem], "user_price")
      end
    end

    if options[:current_user].usertype == "admin" or options[:current_user].usertype == "accountant"
      if options[:can_see_finances]
        s << SqlExport.replace_dec("((#{SqlExport.calls_old_admin_profit_sql} + calls_old.did_price + calls_old.did_prov_price) * #{options[:exchange_rate]})", options[:column_dem], 'profit')
      end
    elsif options[:current_user].usertype == 'reseller'
      if options[:can_see_finances]
        s << SqlExport.replace_dec("(#{SqlExport.calls_old_reseller_profit_sql(options[:current_user])} * #{options[:exchange_rate]})", options[:column_dem], 'profit')
      end
    end

    filename = "Last_calls_old-#{options[:current_user].id.to_s.gsub(" ", "_")}-#{options[:from].gsub(" ", "_").gsub(":", "_")}-#{options[:till].gsub(" ", "_").gsub(":", "_")}-#{Time.now().to_i}"
    sql = "SELECT * "
    if options[:pdf].to_i == 0 and options[:test] != 1
      sql += " INTO OUTFILE '/tmp/#{filename}.csv'
            FIELDS TERMINATED BY '#{options[:collumn_separator]}'
            ESCAPED BY '#{"\\\\"}'
        LINES TERMINATED BY '#{"\\n"}' "
    end
    #OldCall.last_calls_parse_params might return "LEFT JOIN destinations ..."
    #if condition below is met, in that case we should not join destinations again
    #it is very important to join tables in this paricular order DO NOT CHANGE IT

    jn << "LEFT JOIN destinations ON destinations.prefix = IFNULL(calls_old.prefix, '') " if options[:s_country].blank?
    jn << 'LEFT JOIN directions ON directions.code = (destinations.direction_code)'

    one_row =  "SELECT #{s.join(', ')} FROM calls_old #{jn.join(' ')} LIMIT 1"
    columns = ActiveRecord::Base.connection.select_all(one_row).columns

    headers = self.last_calls_csv_headers
    headers = columns.map { |name| "'#{headers[name] || name}' AS  '#{name}'" }
    header_sql = 'SELECT ' + headers.join(', ') + ' UNION ALL ' if options[:csv]

    sql += " FROM ( #{header_sql.to_s} (SELECT #{s.join(', ')}
             FROM calls_old FORCE INDEX (calldate)"
    sql += jn.join(' ')
    sql += "WHERE #{ ActiveRecord::Base.sanitize_sql_array([cond.join(' AND '), *var])} ORDER BY #{options[:order]} )) as C"

    test_content = ""
    if options[:test].to_i == 1
      mysql_res = ActiveRecord::Base.connection.select_all(sql)
      test_content = mysql_res.to_a.to_json
    else
      if options[:pdf].to_i == 1
        filename = OldCall.find_by_sql(sql)
      else
        ActiveRecord::Base.connection.execute(sql)
      end

    end
    return filename, test_content
  end

  def self.last_calls_csv_partner(options)
    cond, var, jn = OldCall.last_calls_parse_params(options)
    is_test = options[:test].to_i == 1
    is_pdf = options[:pdf].to_i == 1

    search_string = []

    format = Confline.get_value('Date_format', options[:current_user].id).gsub('M', 'i')
    csv_full_src = true if options[:show_full_src].to_i == 1
    #calldate2 - because something overwites calldate when changing date format
    time_offset = options[:current_user].time_offset
    search_string << SqlExport.column_escape_null(SqlExport.nice_date('calls_old.calldate', {format: format, offset: time_offset}), 'calldate2')
    unless csv_full_src
      search_string << SqlExport.column_escape_null('calls_old.src', 'src')
    end
    if csv_full_src or is_pdf
      search_string << SqlExport.column_escape_null("calls_old.clid", "clid")
    end
    search_string << SqlExport.column_escape_null('calls_old.localized_dst', 'dst')
    search_string << OldCall.nice_billsec_sql
    search_string << SqlExport.column_escape_null("CONCAT(#{SqlExport.column_escape_null("calls_old.disposition")}, '(', #{SqlExport.column_escape_null("calls_old.hangupcause")}, ')')", 'dispod')
    search_string << SqlExport.column_escape_null('calls_old.server_id', 'server_id')
    search_string << SqlExport.replace_dec("(IF(calls_old.partner_rate IS NULL, 0, calls_old.partner_rate) * #{options[:exchange_rate]} )", options[:column_dem], 'partner_rate')
    search_string << SqlExport.replace_dec("(IF(calls_old.partner_price IS NULL, 0, calls_old.partner_price) * #{options[:exchange_rate]} ) ", options[:column_dem], 'partner_price')
    nice_reseller = "IF(resellers.id != 0,IF(LENGTH(resellers.first_name+resellers.last_name) > 0, CONCAT(resellers.first_name, ' ',resellers.last_name ), resellers.username), ' ')"
    search_string << "IF(#{nice_reseller} IS NULL, ' ', #{nice_reseller}) as 'nice_reseller'"
    search_string << SqlExport.replace_dec("(#{SqlExport.calls_old_reseller_rate_sql} * #{options[:exchange_rate]} ) ", options[:column_dem], 'reseller_rate')
    search_string << SqlExport.replace_dec("(#{SqlExport.calls_old_reseller_price_no_dids_sql} * #{options[:exchange_rate]} ) ", options[:column_dem], 'reseller_price')
    search_string << "IF(calls_old.card_id = 0 ,IF(users.first_name = '' and users.last_name = '', users.username, (#{SqlExport.nice_user_sql('users', false)})), CONCAT('Card#', IF(cards.number IS NULL, '', cards.number))) as 'user'"
    search_string << SqlExport.replace_dec("(IF(calls_old.user_rate IS NULL, 0, #{SqlExport.calls_old_user_rate_sql}) * #{options[:exchange_rate]} )", options[:column_dem], 'user_rate')
    search_string << SqlExport.replace_dec("(IF(calls_old.user_price IS NULL, 0, #{SqlExport.calls_old_user_price_no_dids_sql}) * #{options[:exchange_rate]} ) ", options[:column_dem], 'user_price')
    search_string << SqlExport.replace_dec("(#{SqlExport.calls_old_reseller_profit_no_dids_sql(options[:current_user])} * #{options[:exchange_rate]})", options[:column_dem], 'profit')


    filename = "Last_calls_old-#{options[:current_user].id.to_s.gsub(" ", "_")}-#{options[:from].gsub(" ", "_").gsub(":", "_")}-#{options[:till].gsub(" ", "_").gsub(":", "_")}-#{DateTime.now.strftime('%Q').to_i}"
    sql = "SELECT * "
    if !is_pdf and !is_test
      sql += " INTO OUTFILE '/tmp/#{filename}.csv'
            FIELDS TERMINATED BY '#{options[:collumn_separator]}'
            ESCAPED BY '#{"\\\\"}'
        LINES TERMINATED BY '#{"\\n"}' "
    end
    #Call.last_calls_old_parse_params might return "LEFT JOIN destinations ..."
    #if condition below is met, in that case we should not join destinations again
    #it is very important to join tables in this paricular order DO NOT CHANGE IT

    jn << "LEFT JOIN destinations ON destinations.prefix = IFNULL(calls_old.prefix, '') " if options[:s_country].blank?
    jn << 'LEFT JOIN directions ON directions.code = (destinations.direction_code)'
    # setting headers

    string_cond = search_string.join(', ')
    joins = jn.join(' ')

    one_row =  "SELECT #{string_cond} FROM calls_old #{joins} LIMIT 1"
    columns = ActiveRecord::Base.connection.select_all(one_row).columns

    headers = self.last_calls_csv_partner_headers
    headers = columns.map { |name| "'#{headers[name] || name}' AS  '#{name}'" }
    header_sql = 'SELECT ' + headers.join(', ') + ' UNION ALL ' if options[:csv]

    sql += " FROM (#{header_sql.to_s} (SELECT #{string_cond}
             FROM calls_old "
    sql += joins
    sql += "WHERE #{ ActiveRecord::Base.sanitize_sql_array([cond.join(' AND '), *var])} ORDER BY #{options[:order].gsub('nice_user', 'user')} )) AS C"

    test_content = ''
    if is_test
      mysql_res = ActiveRecord::Base.connection.select_all(sql)
      test_content = mysql_res.to_a.to_json
    else
      if is_pdf
        filename = Call.find_by_sql(sql)
      else
        ActiveRecord::Base.connection.execute(sql)
      end
    end
    return filename, test_content
  end

  def OldCall.calls_for_laod_stats(options={})
    cond= ['calldate BETWEEN ? AND ?']
    var = [options[:a1], options[:a2]]

    if options[:s_server].to_i != -1 and options[:current_user].usertype != 'reseller'
      cond << 'server_id = ?'; var << options[:s_server]
    end

    if options[:s_user].to_i != -1
      cond << 'user_id = ? '; var << options[:s_user] # AND b.user_id = '#{@search_user}' "
      if options[:s_device].to_i != -1
        cond << 'src_device_id = ?'; var << options[:s_device] # AND b.src_device_id = '#{@search_device}'"
      end
    end

    if options[:s_reseller].to_i != -1
      cond << 'calls_old.reseller_id = ? '; var << options[:s_reseller]
    end

    if options[:s_direction] != -1
      case options[:s_direction].to_s
        when "outgoing"
          cond << 'did_id= 0'
        when "incoming"
          cond << "did_id > 0 AND callertype = 'Local'"
        when "mixed"
          cond << "did_id > 0 AND callertype = 'Outside'"
      end
    end

    if options[:s_provider].to_i != -1
      cond << 'provider_id = ?'; var << options[:s_provider]
    end
    if options[:s_did].to_i != -1 and options[:current_user].usertype != 'reseller'
      cond << "did_id= ?"; var << options[:s_did]
    end

    if options[:current_user].usertype == "reseller"
      cond << "(calls_old.reseller_id = ? OR calls_old.user_id = ? OR calls_old.dst_user_id = ?)"
      var += [options[:current_user].id, options[:current_user].id, options[:current_user].id]
    end

    c2 = OldCall.select('calldate, duration').where([cond.join(' AND ').to_s] + var).to_a
    cond << "disposition = 'ANSWERED'"
    calls1 = OldCall.select('calldate, duration').where([cond.join(' AND ').to_s] + var).to_a
    return calls1, c2
  end

  def OldCall.country_stats(options={})

    cond = []
    var = []

    if options[:user_id]
      if options[:user_id] != "-1"
        cond << 'calls_old.user_id = ? '
        var << options[:user_id]
      end
    end

    if options[:current_user].usertype == "reseller"
      cond << "(calls_old.reseller_id = ? OR calls_old.user_id = ? OR calls_old.dst_user_id = ?)"
      var += [options[:current_user].id, options[:current_user].id, options[:current_user].id]
      user_price = SqlExport.replace_price(SqlExport.calls_old_user_price_sql)
      provider_price =SqlExport.replace_price(SqlExport.calls_old_reseller_provider_price_sql)
    else
      user_price = SqlExport.replace_price(SqlExport.admin_user_price_sql)
      provider_price =SqlExport.replace_price(SqlExport.calls_old_admin_provider_price_sql)
    end

    cond << "calls_old.calldate BETWEEN ? AND ?"
    var += ["#{options[:a1]}", "#{options[:a2]}"]

    cond << 'calls_old.disposition = "ANSWERED"'

    calls_all = OldCall.where([cond.join(' AND ').to_s] + var).
                          select("COUNT(*) as 'calls_old', SUM(IF(calls_old.billsec > 0, calls_old.billsec, CEIL(calls_old.real_billsec) )) as 'billsec', SUM(#{provider_price}) as 'selfcost', SUM(#{user_price}) as 'price', SUM(#{user_price}-#{provider_price}) as calls_profit").
                          joins("LEFT JOIN destinations ON (destinations.prefix = calls_old.prefix) JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) #{SqlExport.calls_old_left_join_reseler_providers_to_calls_sql}").first


    calls = OldCall.where([cond.join(' AND ').to_s] + var).
                      select("destinations.direction_code as 'direction_code', destinationgroups.id, destinationgroups.flag as 'dg_flag', destinationgroups.name as 'dg_name', COUNT(*) as 'calls', SUM(IF(calls_old.billsec > 0, calls_old.billsec, CEIL(calls_old.real_billsec) )) as 'billsec', SUM(#{provider_price}) as 'selfcost', SUM(#{user_price}) as 'price'").
                      joins("LEFT JOIN destinations ON (destinations.prefix = calls_old.prefix) JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) #{SqlExport.calls_old_left_join_reseler_providers_to_calls_sql}").
                      group('destinationgroups.id').
                      order('destinationgroups.name ASC').to_a

    calls_for_pie_graph = OldCall.
                                    where([cond.join(' AND ').to_s] + var).
                                    select("destinationgroups.name as 'dg_name',SUM(IF(calls_old.billsec > 0, calls_old.billsec, CEIL(calls_old.real_billsec) )) as 'billsec'").
                                    joins("LEFT JOIN destinations ON (destinations.prefix = calls_old.prefix) JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) #{SqlExport.calls_old_left_join_reseler_providers_to_calls_sql}").
                                    group('destinationgroups.id').
                                    order('billsec desc').to_a

    calls_for_price = OldCall.
                                where([cond.join(' AND ').to_s] + var).
                                select("destinationgroups.name as 'dg_name', SUM(#{user_price}) as 'price'").
                                joins("LEFT JOIN destinations ON (destinations.prefix = calls_old.prefix) JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) #{SqlExport.calls_old_left_join_reseler_providers_to_calls_sql}").
                                group('destinationgroups.id').
                                order('price desc').to_a

    calls_for_profit = OldCall.
                                 where([cond.join(' AND ').to_s] + var).
                                 select("destinationgroups.name as 'dg_name', SUM(#{user_price}-#{provider_price}) as calls_profit",).
                                 joins("LEFT JOIN destinations ON (destinations.prefix = calls_old.prefix) JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) #{SqlExport.calls_old_left_join_reseler_providers_to_calls_sql}").
                                 group('destinationgroups.id').
                                 order('calls_profit desc').to_a

    #---------- Graphs ------------
    #    Countries times for pie
    all = 0
    country_times_pie= "\""
    if calls_for_pie_graph and calls_for_pie_graph.size.to_i > 0
      calls_for_pie_graph.each_with_index { |c, i|
        pull = i == 1 ? 'true' : 'false'
        if i < 6
          country_times_pie += c.dg_name.to_s + ";" + (c.billsec.to_i / 60).to_s + ";" + pull + "\\n"
        else
          all += c.billsec
        end
      }
      country_times_pie += _('Others') + ";" + (all.to_i / 60).to_s + ";false\\n"
    else
      country_times_pie += _('No_result') + ";1;false\\n"
    end
    country_times_pie += "\""

    #------- Countries profit graph ----------
    all = 0
    countries_profit_pie = "\""
    if calls_for_profit and calls_for_profit.size.to_i > 0
      calls_for_profit.each_with_index { |c, i|
        pull = i == 1 ? 'true' : 'false'
        if i < 6
          countries_profit_pie += c.dg_name.to_s + ";" + (Email.nice_number(c.calls_profit.to_d)).to_s + ";" + pull + "\\n"
        else
          all += c.calls_profit.to_d
        end
      }
      countries_profit_pie+= _('Others') + ";" + Email.nice_number(all.to_d > 0.to_d ? all.to_d : 0).to_s + ";false\\n"
    else
      countries_profit_pie+= _('No_result') + ";1;false\\n"
    end
    countries_profit_pie += "\""

    #------- Countries incomes graph ----------
    all = 0
    countries_incomes_pie = "\""
    if calls_for_price and calls_for_price.size.to_i > 0
      calls_for_price.each_with_index { |c, i|
        pull = i == 1 ? 'true' : 'false'
        if i < 6
          countries_incomes_pie += c.dg_name.to_s + ";" + Email.nice_number(c.price.to_d).to_s + ";" + pull + "\\n"
        else
          all += c.price.to_d
        end
      }
      countries_incomes_pie+= _('Others') + ";" + Email.nice_number(all.to_d).to_s + ";false\\n"
    else
      countries_incomes_pie+= _('No_result') + ";1;false\\n"
    end
    countries_incomes_pie += "\""

    return calls, country_times_pie, countries_profit_pie, countries_incomes_pie, calls_all

  end

  def OldCall.hangup_cause_codes_stats(options={})
    cond = []; var = []

    if options[:user_id].to_i != -1
      cond << 'calls_old.user_id = ? '; var << options[:user_id]
    end

    if options[:device_id].to_i != -1
      cond << "(calls_old.src_device_id = ? OR calls_old.dst_device_id = ?)"
      var +=[options[:device_id].to_i, options[:device_id].to_i]
    end

    if options[:provider_id].to_i != -1
      cond << "((calls_old.provider_id = ? and calls_old.callertype = 'Local') OR (calls_old.did_provider_id = ? and calls_old.callertype = 'Outside'))"
      var +=[options[:provider_id].to_i, options[:provider_id].to_i]
    end

    des = ''
    if options[:country_code] and !options[:country_code].blank?
      cond << "destinations.direction_code = ? "; var << options[:country_code]
      des = 'LEFT JOIN destinations ON (calls_old.prefix = destinations.prefix)'
    end

    if options[:current_user].usertype == "reseller"
      cond << "(calls_old.reseller_id = ? OR calls_old.user_id = ? OR calls_old.dst_user_id = ?)"
      var += [options[:current_user].id, options[:current_user].id, options[:current_user].id]
    end

    cond << "calls_old.calldate BETWEEN ? AND ?"
    var += [options[:a1].to_s, options[:a2].to_s]

    sql = "SELECT calls_hc.hc_code, calls_hc.calls, hangupcausecodes.id, hangupcausecodes.code, hangupcausecodes.description FROM(
              SELECT calls_old.hangupcause AS 'hc_code', count(calls_old.id) AS 'calls' FROM calls #{des} WHERE #{ ActiveRecord::Base.sanitize_sql_array([cond.join(' AND '), *var])} GROUP BY hc_code) AS calls_hc
           LEFT JOIN hangupcausecodes ON (calls_hc.hc_code = hangupcausecodes.code) ORDER BY hc_code ASC"

    calls = OldCall.find_by_sql(sql)

    sql2 = "SELECT calls_hc.hc_code, calls_hc.calls, hangupcausecodes.id, hangupcausecodes.code, hangupcausecodes.description FROM(
              SELECT calls_old.hangupcause AS 'hc_code', count(calls_old.id) AS 'calls' FROM calls #{des} WHERE #{ ActiveRecord::Base.sanitize_sql_array([cond.join(' AND '), *var])} GROUP BY hc_code) AS calls_hc
           LEFT JOIN hangupcausecodes ON (calls_hc.hc_code = hangupcausecodes.code) ORDER BY calls DESC"

    code_calls = OldCall.find_by_sql(sql2)

    format = Confline.get_value('Date_format', options[:current_user].owner_id).gsub('%H:%M:%S', '')

    date_period = []
    a1 = !options[:a1].blank? ? options[:a1] : '2004'
    a2 = !options[:a2].blank? ? options[:a2] : Date.today.to_s
    a2 = a1 if a1.to_date > a2.to_date
    a1.to_date.upto(a2.to_date) do |date|
      date_period << "select '#{date.to_s}' as call_date2"
    end

    day_calls = OldCall.find_by_sql(
        "SELECT * FROM (SELECT * FROM (SELECT * FROM (#{date_period.join(" UNION ")}) AS v) AS d) AS u
        LEFT JOIN (SELECT DATE(calldate) as call_date, #{SqlExport.nice_date('DATE(calldate)', {:reference => 'call_date_formated', :format => format, :tz => options[:current_user].time_offset})}, SUM(IF(calls_old.hangupcause = '16', 1,0)) as 'calls', SUM(IF(calls_old.hangupcause != '16', 1,0)) as 'b_calls' FROM calls
                    LEFT JOIN hangupcausecodes ON (calls_old.hangupcause = hangupcausecodes.code ) #{des}
                    WHERE #{ ActiveRecord::Base.sanitize_sql_array([(cond+["calls_old.hangupcause != ''"]).join(' AND '), *var])}
                    GROUP BY call_date ) AS p ON (u.call_date2 = DATE(p.call_date) )")

    #---------- Graphs ------------
    #    Hangup causes codes for pie
    all = 0
    hcc_pie= "\""
    calls_size = 0
    if code_calls and code_calls.size.to_i > 0
      code_calls.each_with_index { |c, i|
        pull = i == 1 ? 'true' : 'false'
        if i < 6
          hcc_pie += c.hc_code.to_s + ";" + (c.calls.to_i).to_s + ";" + pull + "\\n"
        else
          all += c.calls.to_i
        end
        calls_size +=c.calls.to_i
      }
      hcc_pie += _('Others') + ";" + all.to_s + ";false\\n"
    else
      hcc_pie += _('No_result') + ";1;false\\n"
    end
    hcc_pie += "\""

    #    Hangup causes codes for line
    hcc_graph = []
    day_calls.each_with_index { |c, i|
      hcc_graph << c.call_date_formated.to_s + ";" + c.calls.to_i.to_s + ";"+c.b_calls.to_i.to_s
    }

    return calls, hcc_pie, hcc_graph.join("\\n"), calls_size
  end

  def OldCall.country_stats_csv(options={})

    cond = ["calls_old.calldate BETWEEN ? AND ?  AND calls_old.disposition = 'ANSWERED' "]
    var =[options[:from].to_s + ' 00:00:00', options[:till].to_s + ' 23:59:59']
    jn = ['LEFT JOIN destinations ON (destinations.prefix = calls_old.prefix)', "JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id)#{SqlExport.calls_old_left_join_reseler_providers_to_calls_sql}"]
    if options[:s_user].to_i != -1
      cond << 'calls_old.user_id = ? '; var << options[:s_user]
    end

    if options[:current_user].usertype == "reseller"
      cond << "(calls_old.reseller_id = ? OR calls_old.user_id = ? OR calls_old.dst_user_id = ?)"
      var += [options[:current_user].id, options[:current_user].id, options[:current_user].id]
      user_price = SqlExport.replace_price(SqlExport.calls_old_user_price_sql)
      provider_price =SqlExport.replace_price(SqlExport.calls_old_reseller_provider_price_sql)
    else
      user_price = SqlExport.replace_price(SqlExport.calls_old_admin_user_price_sql)
      provider_price = SqlExport.replace_price(SqlExport.calls_old_admin_provider_price_sql)
    end
    s =[]

    s << SqlExport.replace_sep("destinationgroups.name", options[:collumn_separator], nil, "dg_name")
    s << SqlExport.column_escape_null("COUNT(*)", 'calls')
    s << SqlExport.column_escape_null("SUM(IF(calls_old.billsec > 0, calls_old.billsec, CEIL(calls_old.real_billsec) ))", 'billsec')
    unless options[:hide_finances]
      s << SqlExport.column_escape_null("SUM(#{provider_price})", 'selfcost')
      s << SqlExport.column_escape_null("SUM(#{user_price})", 'price')
      s << SqlExport.column_escape_null("SUM(#{user_price} - #{provider_price})", 'profit')
    end

    filename = "Country_stats-#{options[:from].gsub(" ", "_").gsub(":", "_")}-#{options[:till].gsub(" ", "_").gsub(":", "_")}-#{Time.now().to_i}"
    sql = "SELECT * "
    if options[:test] != 1
      sql += " INTO OUTFILE '/tmp/#{filename}.csv'
            FIELDS TERMINATED BY '#{options[:collumn_separator]}' OPTIONALLY ENCLOSED BY '#{''}'
            ESCAPED BY '#{"\\\\"}'
        LINES TERMINATED BY '#{"\\n"}' "
    end
    sql += " FROM (SELECT #{s.join(', ')} FROM calls #{jn.join(' ')}  WHERE #{ ActiveRecord::Base.sanitize_sql_array([cond.join(' AND '), *var])} GROUP BY destinationgroups.id ORDER BY destinationgroups.name ASC ) as C"

    test_content = ""
    if options[:test].to_i == 1
      mysql_res = ActiveRecord::Base.connection.select_all(sql)
      MorLog.my_debug(sql)
      MorLog.my_debug("------------------------------------------------------------------------")
      MorLog.my_debug(mysql_res.to_yaml)
      test_content = mysql_res.to_json
    else
      mysql_res = ActiveRecord::Base.connection.execute(sql)
    end
    return filename, test_content
  end

  def OldCall.cardgroup_aggregate(options={})
    group_by = []
    options[:destination_grouping] == 1 ? group_by << "destinations.direction_code, destinations.prefix" : group_by << "destinations.direction_code"
    group_by << "cards.cardgroup_id" if options[:cardgroup] == "any"

    cond = ["calldate BETWEEN ? AND ?"]
    var = [options[:from], options[:till]]
    if  options[:prefix].to_s != ""
      cond << "calls_old.prefix LIKE ?"
      var << options[:prefix].gsub(/[^0-9]/, "").to_s + "%"
    end

    if options[:cardgroup] == "any"
      cond << "cards.cardgroup_id IN (SELECT id FROM cardgroups WHERE owner_id = ?)"
      var << options[:user_id]
    else
      cond << "cards.cardgroup_id = ?"
      var << options[:cardgroup].to_i
    end

    search_string = []

    if options[:csv].to_i == 0
      search_string << "IF(calls_old.prefix = '', '#{_('Calls_To_Dids')}', calls_old.prefix ) AS prefix, directions.name as 'dir_name', destinations.direction_code AS 'code', destinations.name AS 'dest_name'"
    else
      if options[:destination_grouping].to_i == 1
        search_string << SqlExport.column_escape_null("CONCAT(directions.name, ' ', destinations.name, ' (',  calls_old.prefix, ') ' )", "direct_name", "#{_('Calls_To_Dids')}")
      else
        search_string << SqlExport.column_escape_null("CONCAT(directions.name, ' (',  calls_old.prefix, ') ')", "direct_name", "#{_('Calls_To_Dids')}")
      end
    end
    search_string << "cardgroups.name AS  'cardgroup_name'"
    search_string << SqlExport.column_escape_null("SUM(IF(calls_old.disposition = 'ANSWERED', calls_old.billsec, 0))", 'duration', 0)
    search_string << SqlExport.column_escape_null("SUM(IF(calls_old.disposition = 'ANSWERED', 1,0))", 'answered_calls', 0)
    search_string << SqlExport.column_escape_null("COUNT(*)", 'total_calls', 0)
    search_string << SqlExport.column_escape_null("SUM(IF(calls_old.disposition = 'ANSWERED', 1,0))/COUNT(*)*100", 'asr', 0)
    search_string << SqlExport.column_escape_null("SUM(IF(calls_old.disposition = 'ANSWERED', calls_old.billsec, 0))/SUM(IF(calls_old.disposition = 'ANSWERED', 1,0))", 'acd', 0)
    search_string << SqlExport.column_escape_null("SUM(calls_old.provider_price)", "provider_price", 0)
    search_string << SqlExport.column_escape_null("SUM(calls_old.user_price)", "user_price", 0)
    search_string << SqlExport.column_escape_null("SUM(calls_old.user_price) - SUM(calls_old.provider_price)", 'profit', 0)
    search_string << SqlExport.column_escape_null("IF((SUM(calls_old.user_price) != 0 OR SUM(calls_old.provider_price) != 0),(((SUM(calls_old.user_price) - SUM(calls_old.provider_price)) / SUM(calls_old.user_price)) * 100),0)", 'margin', 0)
    search_string << SqlExport.column_escape_null("IF((SUM(calls_old.user_price) != 0 OR SUM(calls_old.provider_price) != 0),(((SUM(calls_old.user_price) / SUM(calls_old.provider_price)) * 100 ) - 100), 0)", 'markup', 0)
    order = !options[:order].to_s.blank? ? 'ORDER BY ' + options[:order] : ''
    group = group_by.size > 0 ? 'GROUP BY ' +group_by.join(", ") : ''

    jn = ["LEFT JOIN devices ON (calls_old.src_device_id = devices.id)", "LEFT JOIN users ON (users.id = devices.user_id)", "JOIN cards ON (cards.id = calls_old.card_id)", "LEFT JOIN cardgroups ON (cardgroups.id = cards.cardgroup_id)", "LEFT JOIN destinations ON (destinations.prefix = calls_old.prefix)", "LEFT JOIN directions ON (directions.code = destinations.direction_code)"]

    if options[:csv].to_i == 1
      filename = "Cardgroups_aggregate-#{options[:from].gsub(" ", "_").gsub(":", "_")}-#{options[:till].gsub(" ", "_").gsub(":", "_")}-#{Time.now().to_i}"
      sql = "SELECT * "
      if options[:test].to_i != 1
        sql += " INTO OUTFILE '/tmp/#{filename}.csv'
            FIELDS TERMINATED BY '#{options[:collumn_separator]}' OPTIONALLY ENCLOSED BY '#{''}'
            ESCAPED BY '#{"\\\\"}'
        LINES TERMINATED BY '#{"\\n"}' "
      end
      sql += " FROM (SELECT #{search_string.join(', ')} FROM calls #{jn.join(' ')}  WHERE #{ ActiveRecord::Base.sanitize_sql_array([cond.join(' AND '), *var])} #{group}  #{order}  ) as C"

      test_content = ''
      if options[:test].to_i == 1
        mysql_res = ActiveRecord::Base.connection.select_all(sql)
        MorLog.my_debug(sql)
        MorLog.my_debug("------------------------------------------------------------------------")
        MorLog.my_debug(mysql_res.to_yaml)
        test_content = mysql_res.to_a.to_json
      else
        mysql_res = ActiveRecord::Base.connection.execute(sql)
      end
      return filename
    else
      sql = "SELECT #{search_string.join(', ')} FROM calls #{jn.join(' ')}  WHERE #{ ActiveRecord::Base.sanitize_sql_array([cond.join(' AND '), *var])}  #{group}  #{order} "
      mysql_res = OldCall.find_by_sql(sql)
      return mysql_res
    end
  end

  def OldCall.analize_cdr_import(name, options)
    CsvImportDb.log_swap('analyze')
    MorLog.my_debug("CSV analyze_file #{name}", 1)
    arr = {}
    current_user = User.current.id
    arr[:calls_in_db] = OldCall.where({:reseller_id => current_user}).size.to_i
    arr[:clis_in_db] = Callerid.joins('JOIN devices ON (devices.id = callerids.device_id) JOIN users ON (devices.user_id = users.id)').where("users.owner_id = #{current_user}").size.to_i

    if options[:step] and options[:step] == 8
      arr[:step] = 8
      ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 0, nice_error = 0 where id > 0")
    else
      ActiveRecord::Base.connection.execute("UPDATE #{name} SET not_found_in_db = 0, f_error = 0, nice_error = 0 where id > 0")
    end

    if options[:imp_clid] and options[:imp_clid] >= 0
      #set flag on not found and count them
      found_clis = ActiveRecord::Base.connection.select_all("SELECT col_#{options[:imp_clid]} FROM #{name} JOIN callerids ON (callerids.cli = replace(col_#{options[:imp_clid]}, '\\r', ''))")
      idsclis = ["'not_found'"]
      found_clis.each { |id| idsclis << id["col_#{options[:imp_clid]}"].to_s }
      ActiveRecord::Base.connection.execute("UPDATE #{name} SET not_found_in_db = 1 where col_#{options[:imp_clid]}  not in (#{idsclis.compact.join(',')})")
    end


    #set flag on bad dst | code : 3
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 3 where replace(replace(col_#{options[:imp_dst]}, '\\r', ''), '
', '') REGEXP '^[0-9]+$' = 0  and f_error = 0")
    #set flag on bad calldate | code : 4
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 4 where replace(replace(col_#{options[:imp_calldate]}, '\\r', ''), '
', '') REGEXP '^[0-9 :-]+$' = 0 and f_error = 0 ")
    #set flag on bad billsec | code : 5
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 5 where replace(replace(col_#{options[:imp_billsec]}, '\\r', ''), '
', '') REGEXP '^[0-9]+$' = 0 and f_error = 0")
    if  options[:imp_provider_id].to_i > -1
    #set flag on bad Provider ID | code : 6
      prov_id =
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 6 where replace(replace(col_#{options[:imp_provider_id]}, '\\r', ''), '
', '') NOT IN (SELECT providers.id FROM providers WHERE hidden = 0 AND (user_id = #{current_user} OR (common_use = 1 and providers.id IN (SELECT provider_id FROM common_use_providers where reseller_id = #{current_user})))) and f_error = 0")
    end

    #set flag on bad clis and count them
    unless options[:import_user]
      ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 1 where replace(replace(col_#{options[:imp_clid]}, '\\r', ''), '
', '') REGEXP '^[0-9]+$' = 0 and not_found_in_db = 1")
    end
    cond = options[:import_user] ? " AND user_id = #{options[:import_user]} " : '' #" calls.cli "
    ActiveRecord::Base.connection.execute("UPDATE #{name} JOIN calls ON (calls_old.calldate = timestamp(replace(col_#{options[:imp_calldate]}, '\\r', '')) ) SET f_error = 1, nice_error = 2 WHERE dst = replace(col_#{options[:imp_dst]}, '\\r', '') and billsec = replace(col_#{options[:imp_billsec]}, '\\r', '')  #{cond} and f_error = 0")

    arr[:cdr_in_csv_file] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} where f_error = 0").to_i
    arr[:bad_cdrs] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} where f_error = 1").to_i
    arr[:bad_clis] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} where f_error = 1").to_i
    if options[:step] and options[:step] == 8
      arr[:new_clis_to_create] = ActiveRecord::Base.connection.select_value("SELECT COUNT(DISTINCT(col_#{options[:imp_clid]})) FROM #{name}  WHERE nice_error != 1 and not_found_in_db = 1").to_i if options[:imp_clid] and options[:imp_clid] >= 0
      arr[:clis_to_assigne] = Callerid.where({:device_id => -1}).size.to_i
    else
      arr[:new_clis_to_create] = ActiveRecord::Base.connection.select_value("SELECT COUNT(DISTINCT(col_#{options[:imp_clid]})) FROM #{name} LEFT JOIN callerids on (callerids.cli = replace(col_#{options[:imp_clid]}, '\\r', '')) WHERE nice_error != 1 and callerids.id is null and not_found_in_db = 1").to_i if options[:imp_clid] and options[:imp_clid] >= 0
      arr[:clis_to_assigne] = Callerid.where({:device_id => -1}).size.to_i + arr[:new_clis_to_create].to_i
    end

    arr[:existing_clis_in_csv_file] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} where not_found_in_db = 0 and f_error = 0").to_i
    arr[:new_clis_in_csv_file] = ActiveRecord::Base.connection.select_value("SELECT COUNT(DISTINCT(col_#{options[:imp_clid]})) FROM #{name} where not_found_in_db = 1").to_i if options[:imp_clid] and options[:imp_clid] >= 0
    arr[:cdrs_to_insert] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} where f_error = 0").to_i
    return arr
  end

  def OldCall.insert_cdrs_from_csv(name, options)
    provider = Provider.includes([:tariff]).where(["providers.id = ?", options[:import_provider]]).first if options[:imp_provider_id].to_i < 0

    if options[:import_user]
      res = ActiveRecord::Base.connection.select_all("SELECT *, devices.id as dev_id FROM #{name} JOIN devices ON (devices.id = #{options[:import_device]}) WHERE f_error = 0 and do_not_import = 0")
    else
      res = ActiveRecord::Base.connection.select_all("SELECT *, devices.id as dev_id FROM #{name} JOIN callerids ON (callerids.cli = replace(col_#{options[:imp_clid]}, '\\r', '')) JOIN devices ON (callerids.device_id = devices.id) WHERE f_error = 0 and do_not_import = 0")
    end

    imported_cdrs = 0
    for r in res
      billsec = r["col_#{options[:imp_billsec]}"].to_i
      call = OldCall.new(:billsec => billsec, :dst => CsvImportDb.clean_value(r["col_#{options[:imp_dst]}"].to_s).gsub(/[^0-9]/, ""), :calldate => r["col_#{options[:imp_calldate]}"], :card_id => 0)

      # A: Hack for the mess that gets created with speedup.sql
      call.lastapp    =	""	if call.attributes.has_key? 'lastapp'
      call.lastdata   =	""	if call.attributes.has_key? 'lastdata'
      call.uniqueid   =	""	if call.attributes.has_key? 'uniqueid'
      call.channel    =	""	if call.attributes.has_key? 'channel'
      call.dcontext   =	""	if call.attributes.has_key? 'dcontext'
      call.dstchannel =	""	if call.attributes.has_key? 'dstchannel'
      call.userfield  =	""	if call.attributes.has_key? 'userfield'

      duration = CsvImportDb.clean_value(r["col_#{options[:imp_duration]}"]).to_i
      duration = billsec if duration == 0 or options[:imp_duration] == -1
      disposition = ""
      disposition = CsvImportDb.clean_value r["col_#{options[:imp_disposition]}"] if options[:imp_disposition] > -1
      if disposition.length == 0
        disposition = "ANSWERED" if billsec > 0
        disposition = "NO ANSWER" if billsec == 0
      end

      call.clid = CsvImportDb.clean_value r["col_#{options[:imp_clid]}"] if options[:imp_clid] > -1
      call.clid = "" if call.clid.to_s.length == 0

      call.src = CsvImportDb.clean_value(r["col_#{options[:imp_src_number]}"]).gsub(/[^0-9]/, "") if options[:imp_src_number] > -1
      call.src = call.clid.to_i.to_s if call.src.to_s.length == 0
      call.src = "" if call.src.to_s.length == 0

      call.duration = duration

      call.disposition = disposition
      call.accountcode = r['dev_id']
      call.src_device_id = r['dev_id']
      call.user_id = r['user_id']
      call.provider_id = options[:imp_provider_id].to_i > -1 ? CsvImportDb.clean_value(r["col_#{options[:imp_provider_id]}"]).gsub(/[^0-9]/, "") : provider.id
      call.localized_dst = call.dst

      user = User.find(call.user_id)

      call.reseller_id = user.owner_id
      call = call.count_cdr2call_details(options[:imp_provider_id].to_i > -1 ? call.provider.tariff_id : provider.tariff_id, user) if call.valid?

      if call.save
        user.balance -= call.user_price
        user.save
        imported_cdrs += 1
      end
    end

    errors = ActiveRecord::Base.connection.select_all("SELECT * FROM #{name} where f_error = 1")
    return imported_cdrs, errors
  end


  # counts details for the call imported from csv
  #
  # Upgrade: selfcost_tariff_id and user_id can be Tariff or User objects so
  # not to perform find and not to stress database.
  #

  def count_cdr2call_details(selfcost_tariff_id, user_id, user_test_tariff_id = 0)
    @prov_exchange_rate_cache ||= {}
    @tariffs_cache ||= {}

    if user_id.class == User
      user = user_id
      user_id = user.id
    else
      user = User.where(["users.id = ?", user_id]).includes([:tariff]).first
    end
    #logger.info user.to_yaml

    # testing tariff
    if user_test_tariff_id > 0
      tariff = Tariff.where(:id => user_test_tariff_id).first
      CsvImportDb.clean_value "Using testing tariff with id: #{user_test_tariff_id}"
    else
      tariff = user.tariff
    end
    dst = CsvImportDb.clean_value self.dst.to_s #.gsub(/[^0-9]/, "")
    device_id = self.accountcode
    time = self.calldate.strftime("%H:%M:%S")

    if selfcost_tariff_id.class == Tariff
      prov_tariff = selfcost_tariff_id
      selfcost_tariff_id = prov_tariff.id
      @tariffs_cache["t_#{selfcost_tariff_id}".to_sym] ||= prov_tariff
    else
      prov_tariff = @tariffs_cache["t_#{selfcost_tariff_id}".to_sym] ||= Tariff.find(selfcost_tariff_id)
    end

    prov_exchange_rate = @prov_exchange_rate_cache["p_#{prov_tariff.id}".to_sym] ||= prov_tariff.exchange_rate

    #my_debug ""

    # get daytype and localization settings
    day = self.calldate.to_s(:db)
    sql = "SELECT  A.*, (SELECT IF((SELECT daytype FROM days WHERE date = '#{day}') IS NULL, (SELECT IF(WEEKDAY('#{day}') = 5 OR WEEKDAY('#{day}') = 6, 'FD', 'WD')), (SELECT daytype FROM days WHERE date = '#{day}')))   as 'dt' FROM devices JOIN locations ON (locations.id = devices.location_id) LEFT JOIN (SELECT * FROM locationrules WHERE  enabled = 1 AND lr_type = 'dst' AND LENGTH('#{dst}') BETWEEN minlen AND maxlen AND (SUBSTRING('#{dst}',1,LENGTH(cut)) = cut OR LENGTH(cut) = 0 OR ISNULL(cut)) ORDER BY location_id DESC ) AS A ON (A.location_id = locations.id OR A.location_id = 1) WHERE devices.id = #{device_id} ORDER BY LENGTH(cut) DESC LIMIT 1;"
    res = ActiveRecord::Base.connection.select_one(sql)
    if res and res['device_id'].blank? and res['did_id'].blank?
      daytype = res['dt']
      loc_add = res['add']
      loc_cut = res['cut']
      loc_tariff_id = res['tariff_id']

      if loc_tariff_id.to_i > 0 and user_test_tariff_id.to_i == 0
        # change tariff because of localization
        tariff = @tariffs_cache["t_#{loc_tariff_id}".to_sym] ||= Tariff.where(:id => loc_tariff_id).first
      end

      #my_debug sql
      #my_debug "calldate: #{day}, time: #{time}, daytype: #{daytype}, loc_add: #{loc_add}, loc_cut: #{loc_cut}, loc_add: #{loc_add}, src: #{call.src}, dst: #{dst}, tariff_id: #{tariff_id}, self_tariff_id: #{selfcost_tariff_id}"
      #localization
      #      start = 0
      #      start = loc_cut.length if loc_cut
      orig_dst = dst
      #      dst = loc_add.to_s + dst[start, dst.length]
      dst = Location.nice_locilization(loc_cut, loc_add, orig_dst)

      MorLog.my_debug "Before Localication: #{orig_dst}, after localization-> dst: #{dst}, cut: #{loc_cut.to_s}, add: #{loc_add.to_s} "

      # initial values

      price = 0
      max_rate = 0
      user_exchange_rate = 1
      temp_prefix = ''
      user_billsec = 0

      s_prefix = ''
      s_rate = 0
      s_increment = 1
      s_min_time = 0
      s_conn_fee = 0

      s_billsec = 0
      s_price = 0


      # checking maybe called to own DID?

      did = nil
      did = Did.where("did = '#{dst}' AND dids.user_id = #{user_id}").first

      own_did = 0
      own_did = 1 if did

      if own_did == 1
        MorLog.my_debug 'Call to own DID - call will not be charged'
        user_billsec = self.billsec
        self.dst_device_id = did.device_id
        if user_billsec > 0
          self.hangupcause = 16
        else
          self.hangupcause = 0
        end
        self.did_id = did.id
        self.real_duration = user_billsec
        self.real_billsec = user_billsec
        self.reseller_id = user.owner_id
      end


      if own_did == 0
        #data for selfcost
        dst_array = []
        dst.length.times { |index| dst_array << dst[0, index + 1] }
        if dst_array.size > 0
          sql =
              "SELECT A.prefix, ratedetails.rate,   ratedetails.increment_s, ratedetails.min_time, ratedetails.connection_fee "+
                  "FROM  rates JOIN ratedetails ON (ratedetails.rate_id = rates.id  AND (ratedetails.daytype = '#{daytype}' OR ratedetails.daytype = '' ) AND '#{time}' BETWEEN ratedetails.start_time AND ratedetails.end_time) JOIN (SELECT destinations.* FROM  destinations " +
                  "WHERE destinations.prefix IN ('#{dst_array.join("', '")}') ORDER BY LENGTH(destinations.prefix) DESC) " +
                  "as A ON (A.id = rates.destination_id) WHERE rates.tariff_id = #{selfcost_tariff_id} ORDER BY LENGTH(A.prefix) DESC LIMIT 1;"
        end

        #my_debug sql
        res = ActiveRecord::Base.connection.select_one(sql)

        if res
          s_prefix = res['prefix']
          s_rate = res['rate'].to_d
          s_increment = res['increment_s'].to_i
          s_min_time = res['min_time'].to_i
          s_conn_fee = res['connection_fee'].to_d
        end

        s_increment = 1 if s_increment == 0
        if (self.billsec % s_increment == 0)
          s_billsec = (self.billsec / s_increment).floor * s_increment
        else
          s_billsec = ((self.billsec / s_increment).floor + 1) * s_increment
        end
        s_billsec = s_min_time if s_billsec < s_min_time
        s_price = (s_rate * s_billsec) / 60 + s_conn_fee

        #   MorLog.my_debug "PROVIDER's: prefix: #{s_prefix}, rate: #{s_rate}, increment: #{s_increment}, min_time: #{s_min_time}, conn_fee: #{s_conn_fee}, billsec: #{s_billsec}, price: #{s_price}, exchange_rate = #{prov_exchange_rate}"

        #====================== data for USER ==============
        price, max_rate, user_exchange_rate, temp_prefix, user_billsec = self.count_call_rating_details_for_user(tariff, time, daytype, dst, user)
        MorLog.my_debug "USER: call_id: #{self.id}, user_price: #{price}, max_rate: #{max_rate}, exchange_rate: #{user_exchange_rate}, tmp_prefix: #{temp_prefix}, user_billsec: #{user_billsec}"

        #====================== data for RESELLER ==============

        if self.reseller_id.to_i > 0

          reseller = User.where("id = #{self.reseller_id.to_i}").first
          tariff = @tariffs_cache["t_#{reseller.tariff_id.to_i}".to_sym] ||= Tariff.where("id = #{reseller.tariff_id.to_i}").first if reseller

          common_use_provider =  Application.common_use_provider(self.provider_id)

          # In Case Common Use Provider present his Tariff should be used instead of reseller tariff
          tariff = Tariff.where(id: common_use_provider.tariff_id.to_i).first if common_use_provider.present?

          if reseller and tariff
            res_price, res_max_rate, res_exchange_rate, res_temp_prefix, res_billsec = self.count_call_rating_details_for_user(tariff, time, daytype, dst, reseller)
            MorLog.my_debug "RESELLER: call_id: #{self.id}, user_price: #{res_price}, max_rate: #{res_max_rate}, exchange_rate: #{res_exchange_rate}, tmp_prefix: #{res_temp_prefix}, user_billsec: #{res_billsec}"
          end

        end


      end # own_did == 0

      # ========= Calculation ===========


      #new
      self.provider_rate = s_rate / prov_exchange_rate
      self.user_rate = max_rate / user_exchange_rate

      self.provider_billsec = s_billsec
      self.user_billsec = user_billsec

      self.provider_price = 0
      self.user_price = 0

      #call.dst = orig_dst
      self.localized_dst = dst


      if self.reseller_id.to_i > 0
        self.reseller_rate = res_max_rate / res_exchange_rate
        self.reseller_billsec = res_billsec
        self.reseller_price = 0
      end

      #call.prefix = res[0]["prefix"] if res[0]

      if temp_prefix.to_s.length > s_prefix.to_s.length
        self.prefix = temp_prefix
      else
        self.prefix = s_prefix
      end

      if !res_temp_prefix.blank? and self.prefix
        if self.reseller_id.to_i > 0 and res_temp_prefix.to_s.length > self.prefix.to_s.length
          self.prefix = res_temp_prefix
        end
      end


      #need to find prefix for error fixing when no prefix is in calls table - this should not happen anyways, so maybe no fix is neccesary?

      if self.disposition == "ANSWERED"
        #        call.prov_price = s_price
        #        call.price = price

        #new
        self.provider_price = s_price / prov_exchange_rate
        self.user_price = price / user_exchange_rate

        if self.reseller_id.to_i > 0
          self.reseller_price = res_price / res_exchange_rate
        end

      end

      # tmp hack to handle dids for reseller
      # disabled because
=begin
      if call.did_id.to_i > 0

        call.provider_rate = 0
        call.provider_price = 0

        call.user_price = 0
        call.user_rate = 0

        call.reseller_rate = 0
        call.reseller_price = 0

      end
=end
    else
      MorLog.my_debug "#{Time.now.to_s(:db)}  SQL not found--------------------------------------------"
      MorLog.my_debug sql
    end
    self
  end


  def count_call_rating_details_for_user(tariff, time, daytype, dst, user)
    @count_call_rating_details_for_user_exchange_rate_cache ||= {}
    if tariff.purpose == "user"

      #  sql =   "SELECT A.prefix, aratedetails.* FROM  rates JOIN aratedetails ON (aratedetails.rate_id = rates.id ) JOIN destinationgroups " +
      #"ON (destinationgroups.id = rates.destinationgroup_id) JOIN (SELECT destinations.* FROM  destinations " +
      #"WHERE destinations.prefix=SUBSTRING('#{dst}', 1, LENGTH(destinations.prefix)) ORDER BY LENGTH(destinations.prefix) DESC LIMIT 1) as A " +
      #"ON (A.destinationgroup_id = destinationgroups.id) WHERE rates.tariff_id = #{tariff_id} ORDER BY aratedetails.id ASC"

      dst_array = []
      dst.length.times { |i| dst_array << dst[0, i+1] }
      sql = "SELECT B.prefix as 'prefix', aid, afrom, adur, atype, around, aprice, acid, acfrom, acdur, actype, acround, acprice " +
          "FROM (SELECT A.prefix, aratedetails.id as 'aid', aratedetails.from as 'afrom', aratedetails.duration as 'adur', aratedetails.artype as 'atype', aratedetails.round as 'around', aratedetails.price as 'aprice', acustratedetails.id as 'acid', acustratedetails.from as 'acfrom', acustratedetails.duration as 'acdur', acustratedetails.artype as 'actype', acustratedetails.round as 'acround', acustratedetails.price as 'acprice', SUM(acustratedetails.id) as 'sacid'  " +
          "FROM  rates JOIN aratedetails ON (aratedetails.rate_id = rates.id  AND '#{time}' BETWEEN aratedetails.start_time AND aratedetails.end_time AND (aratedetails.daytype = '#{daytype}' OR aratedetails.daytype = ''))  " +
          "JOIN destinationgroups ON (destinationgroups.id = rates.destinationgroup_id)     " +
          "JOIN (SELECT destinations.* FROM  destinations WHERE destinations.prefix IN ('#{dst_array.join("', '")}')  AND destinationgroup_id IN (SELECT rates.destinationgroup_id from rates where rates.tariff_id = #{tariff.id})" +
          "ORDER BY LENGTH(destinations.prefix) DESC LIMIT 1) as A ON (A.destinationgroup_id = destinationgroups.id)  " +
          "LEFT JOIN customrates ON (customrates.destinationgroup_id = destinationgroups.id AND customrates.user_id = #{user.id})  " +
          "LEFT JOIN acustratedetails ON (acustratedetails.customrate_id = customrates.id  AND '#{time}' BETWEEN acustratedetails.start_time AND acustratedetails.end_time AND (acustratedetails.daytype = '#{daytype}' OR acustratedetails.daytype = ''))  " +
          "WHERE rates.tariff_id = #{tariff.id} GROUP BY aratedetails.id, acustratedetails.id ) AS B GROUP BY IF(B.sacid > 0,B.acid,B.aid)  " +
          "ORDER BY acfrom ASC, actype ASC, afrom ASC, atype ASC "

      #      sql = "SELECT B.prefix as 'prefix', aid, afrom, adur, atype, around, aprice, acid, acfrom, acdur, actype, acround, acprice FROM (
      #                SELECT * FROM (
      #                   SELECT A.prefix, aratedetails.id as 'aid', aratedetails.from as 'afrom', aratedetails.duration as 'adur', aratedetails.artype as 'atype', aratedetails.round as 'around', aratedetails.price as 'aprice', acustratedetails.id as 'acid', acustratedetails.from as 'acfrom', acustratedetails.duration as 'acdur', acustratedetails.artype as 'actype', acustratedetails.round as 'acround', acustratedetails.price as 'acprice', SUM(acustratedetails.id) as 'sacid' FROM rates
      #                          JOIN aratedetails ON (aratedetails.rate_id = rates.id  AND '#{time}' BETWEEN aratedetails.start_time AND aratedetails.end_time AND (aratedetails.daytype = '#{daytype}' OR aratedetails.daytype = ''))  " +
      #"JOIN destinationgroups ON (destinationgroups.id = rates.destinationgroup_id)     " +
      #"JOIN (SELECT destinations.* FROM  destinations WHERE destinations.prefix IN ('#{dst_array.join("', '")}')) as A ON (A.destinationgroup_id = destinationgroups.id)  " +
      #"LEFT JOIN customrates ON (customrates.destinationgroup_id = destinationgroups.id AND customrates.user_id = #{user.id})  " +
      #                         "LEFT JOIN acustratedetails ON (acustratedetails.customrate_id = customrates.id  AND '#{time}' BETWEEN acustratedetails.start_time AND acustratedetails.end_time AND (acustratedetails.daytype = '#{daytype}' OR acustratedetails.daytype = ''))  " +
      #                         "WHERE rates.tariff_id = #{tariff.id} AND aid is not null ORDER BY LENGTH(prefix) DESC LIMIT 1
      #               ) AS C GROUP BY aid, acid
      #             ) AS B GROUP BY IF(B.sacid > 0,B.acid,B.aid)
      #             ORDER BY acfrom ASC, actype ASC, afrom ASC, atype ASC;#"

      #my_debug sql

      res = ActiveRecord::Base.connection.select_all(sql)

      custom_rates = 0
      billsec = 0
      price = 0
      max_rate = 0.0
      for r in res

        if res[0]['acid'] and res[0]['acid'].to_i > 0
          #my_debug "custom rates"

          custom_rates = 1


          r_from = r['acfrom']
          r_duration = r['acdur']
          r_artype = r['actype']
          r_round = r['acround']
          r_price = r['acprice']
          cr = true
        else
          #my_debug "no custom rates"


          r_from = r['afrom']
          r_duration = r['adur']
          r_artype = r['atype']
          r_round = r['around']
          r_price = r['aprice']
          cr = false
        end


        #         MorLog.my_debug "from: #{r_from}, duration: #{r_duration}, artype: #{r_artype}, round: #{r_round}, price: #{r_price}"

        if r_from.to_i <= self.billsec
          #this arate is suitable for this call
          if r_artype == "minute"
            #my_debug "1. minute, price: #{price}"
            max_rate = r_price.to_d if max_rate < r_price.to_d

            #count the time frame for us to bill
            if r_duration.to_i == (-1)
              #unlimited frame end
              #my_debug call.billsec.to_i
              billsec = self.billsec.to_i - r_from.to_i + 1
            else
              if self.billsec < (r_from.to_i + r_duration.to_i)
                billsec = self.billsec - r_from.to_i + 1
              else
                billsec = r_duration.to_i
              end
            end

            #my_debug "2. minute, price: #{price}, billsec: #{billsec}"

            #round time frame
            #              if (billsec % r_round.to_i) == 0
            #if round is 0, mistake in db?- must be changed to 1
            if r_round.to_i == 0
              r_round = 1
            end
            billsec = (billsec.to_d / r_round.to_d).ceil * r_round.to_i
            #my_debug "==0"
            #my_debug((billsec.to_d / r_round.to_d)).to_s
            #              else
            #my_debug "!=0"
            #                billsec = ((billsec.to_d / r_round.to_d) + 1).ceil * r_round.to_i
            #              end

            #my_debug "3. minute, price: #{price}, billsec: #{billsec}"
            #my_debug((r_price.to_d * billsec.to_d) / 60  ).to_s
            #count the price for the time frame
            price += (r_price.to_d * billsec.to_d) / 60

            #my_debug "4. minute, price: #{price}"
          else #event

            price += r_price.to_d
            billsec = 0
            #my_debug "5. event, price: #{price}"
          end #minute-event
        end #suitable arate
      end


      user_billsec = 0
      total_arates = res.size
      lfrom = res[total_arates - 1]["afrom"].to_i if cr == false
      lfrom = res[total_arates - 1]["acfrom"].to_i if cr == true
      if res.size > 0
        if (billsec + lfrom) > self.billsec
          user_billsec = billsec
        else
          user_billsec = self.billsec
        end

      end

      if custom_rates == 1
        user_exchange_rate = 1
      else
        user_exchange_rate = @count_call_rating_details_for_user_exchange_rate_cache["te_#{tariff.id}".to_sym] ||= tariff.exchange_rate
      end

      temp_prefix = ""
      temp_prefix = res[0]["prefix"] if res[0]

    else #tariff.purpose == "user_wholesale"

         #======================= user wholesale ===============

      sql = "SELECT A.prefix, ratedetails.rate, ratedetails.increment_s, ratedetails.min_time, ratedetails.connection_fee as 'cf' FROM  rates JOIN ratedetails ON (ratedetails.rate_id = rates.id  AND (ratedetails.daytype =  '#{daytype}' OR ratedetails.daytype = '' )  AND '#{time}' BETWEEN ratedetails.start_time AND ratedetails.end_time) JOIN (SELECT destinations.* FROM  destinations WHERE destinations.prefix=SUBSTRING('#{dst}', 1, LENGTH(destinations.prefix)) ORDER BY LENGTH(destinations.prefix) DESC) as A ON (A.id = rates.destination_id) WHERE rates.tariff_id = #{tariff.id} LIMIT 1;"


      #my_debug sql

      res = ActiveRecord::Base.connection.select_one(sql)

      uw_prefix = ""
      uw_rate = 0
      uw_increment = 1
      uw_min_time = 0
      uw_conn_fee = 0

      if res
        uw_prefix = res['prefix']
        uw_rate = res['rate'].to_d
        uw_increment = res['increment_s'].to_i
        uw_min_time = res['min_time'].to_i
        uw_conn_fee = res['cf'].to_d
      end

      uw_billsec = 0
      uw_price = 0

      uw_increment = 1 if uw_increment == 0

      if (self.billsec % uw_increment == 0)
        uw_billsec = (self.billsec / uw_increment).floor * uw_increment
      else
        uw_billsec = ((self.billsec / uw_increment).floor + 1) * uw_increment
      end
      uw_billsec = uw_min_time if uw_billsec < uw_min_time

      #my_debug (call.billsec.to_d / uw_increment)
      #my_debug (call.billsec.to_d / uw_increment).floor
      #my_debug (call.billsec / uw_increment).floor * uw_increment
      #my_debug uw_billsec

      uw_price = (uw_rate * uw_billsec) / 60 + uw_conn_fee

      price = uw_price
      max_rate = uw_rate
      user_exchange_rate = @count_call_rating_details_for_user_exchange_rate_cache["te_#{tariff.id}".to_sym] ||= tariff.exchange_rate
      temp_prefix = uw_prefix
      user_billsec = uw_billsec
    end
    return price, max_rate, user_exchange_rate, temp_prefix, user_billsec
  end


  def OldCall.summary_by_dids(user, order, options)
    group_by = []
    options[:dids_grouping] == 1 ? group_by << "calls_old.did_provider_id" : group_by << "dids.user_id, dids.device_id"


    cond = ["calldate BETWEEN ? AND ?"]
    var = [options[:from], options[:till]]


    jn = ["JOIN dids ON (dids.id = calls_old.did_id)", "LEFT JOIN devices ON (dids.device_id = devices.id)", "LEFT JOIN users ON (users.id = dids.user_id)",  "LEFT JOIN providers ON (calls_old.did_provider_id = providers.id)"]

    if  options[:did].to_s != ""  and options[:d_search].to_i == 1
      cond << "dids.did LIKE ?"
      var << options[:did].to_s.strip + "%" #options[:did].gsub(/[^0-9]/, "").to_s + "%"
    end

    if  options[:did_search_from].to_s != "" and options[:did_search_till].to_s != "" and options[:d_search].to_i == 2
      cond << "dids.did BETWEEN ? AND ?"
      var << options[:did_search_from].to_s.strip #options[:did_search_from].gsub(/[^0-9]/, "").to_s
      var << options[:did_search_till].to_s.strip #options[:did_search_till].gsub(/[^0-9]/, "").to_s
    end

    if  options[:provider].to_s != "any"
      cond << "calls_old.did_provider_id = ?"
      var << options[:provider].to_i
    end

    if  options[:user_id].to_s != "any"
      cond << "dids.user_id = ?"
      var << options[:user_id].to_i
    end

    if !options[:device_id].blank? and options[:device_id].to_s != "all"
      cond << "dids.device_id = ?"
      var << options[:device_id].to_i
    end

    if options[:sdays].to_s != 'all'
      cond << 'DAYOFWEEK(calls_old.calldate) IN (1,7)'  if  options[:sdays].to_s == 'fd'
      cond << 'DAYOFWEEK(calls_old.calldate) IN (2,3,4,5,6)'  if  options[:sdays].to_s == 'wd'
    end

    if options[:period].to_i != -1
      didrate = Didrate.where({:id=>options[:period]}).first
      if didrate
      cond << 'TIME(calls_old.calldate) BETWEEN ? AND ?'
      var << didrate.start_time.strftime("%H:%M:%S")
      var << didrate.end_time.strftime("%H:%M:%S")
        end
    end

    s = []

    s << "#{SqlExport.nice_user_sql}, providers.user_id as prov_owner_id, calls_old.did_id, dids.did, providers.name, dids.comment, calls_old.did_provider_id, dids.user_id, dids.device_id, users.owner_id as user_owner_id "
    s << SqlExport.column_escape_null("COUNT(*)", 'total_calls', 0)

    s << SqlExport.column_escape_null("SUM(calls_old.billsec)", 'dids_billsec', 0)
    s << SqlExport.column_escape_null("SUM(calls_old.did_inc_price)", "inc_price", 0)
    s << SqlExport.column_escape_null("SUM(calls_old.did_prov_price)", "d_prov_price", 0)
    s << SqlExport.column_escape_null("SUM(calls_old.did_price)", 'own_price', 0)

    order = !order.to_s.blank? ? 'ORDER BY ' + order : ''
    group = group_by.size > 0 ? 'GROUP BY ' +group_by.join(", ") : ''




      sql = "SELECT #{s.join(', ')} FROM calls #{jn.join(' ')}  WHERE #{ ActiveRecord::Base.sanitize_sql_array([cond.join(' AND '), *var])}  #{group}  #{order} "
      mysql_res = OldCall.find_by_sql(sql)
      return mysql_res

  end

  private

  def self.last_calls_raw_conditions(options={})
    cond = []
    is_user_blank = !options[:user]
    current_user = options[:current_user]
    if current_user.is_reseller? && is_user_blank
      user_ids = User.available_ids("users.owner_id = #{options[:current_user].id}")

      reseller_condition = " calls_old.reseller_id = #{options[:current_user].id} OR calls_old.user_id = #{options[:current_user].id} "
      reseller_condition << " OR calls_old.user_id IN (#{user_ids}) OR calls_old.dst_user_id IN (#{user_ids})" if user_ids.present?

      cond << "(#{reseller_condition})"
    end

    if current_user.is_partner? && is_user_blank
      id = options[:current_user].id
      cond << "(calls_old.partner_id = #{id})"
    end

    if options[:current_user].try(:usertype) == 'accountant' && options[:current_user].try(:show_only_assigned_users) == 1
      resp_acc = User.where(id: options[:current_user].id).first
      resp_acc_users = resp_acc.responsible_accountant_users(include_owner_users: true).pluck(:id).join(', ')
      resp_acc_user_devices = resp_acc.responsible_accountant_user_devices(include_owner_users: true).pluck(:id).join(', ')

      resp_acc_users = '-2' if resp_acc_users.blank?
      resp_acc_user_devices = '-2' if resp_acc_user_devices.blank?

      cond << "(calls_old.user_id IN (#{resp_acc_users})
                OR calls_old.dst_user_id IN (#{resp_acc_users})
                OR calls_old.reseller_id IN (#{resp_acc_users})
                OR calls_old.src_device_id IN (#{resp_acc_user_devices})
                OR calls_old.dst_device_id IN (#{resp_acc_user_devices})
               )"
    end

    if options[:call_type] != "all"
      if ['answered', 'failed'].include?(options[:call_type].to_s)
        cond << OldCall.nice_answered_cond_sql if options[:call_type].to_s == 'answered'
        cond << OldCall.nice_failed_cond_sql if options[:call_type].to_s == 'failed'
      else
        cond << "calls_old.disposition = '#{options[:call_type]}'"
      end
    end

    hgc_option = options[:hgc]
    if hgc_option
      cond << "calls_old.hangupcause = '#{hgc_option.code}'"
    end

    detination_option = options[:destination]
    unless detination_option.blank?
      cond << "localized_dst like '#{detination_option}'"
    end

    if options[:s_reseller_did] != 'all' and !options[:s_reseller_did].blank?
      dids_ids = Did.available_ids("dids.reseller_id = #{options[:s_reseller_did]}")
      cond << "calls_old.did_id IN (#{dids_ids})" if dids_ids.present?
    end

    if options[:device].try(:id)
      device_id = options[:device].id
      cond << "(calls_old.dst_device_id = #{device_id} OR calls_old.src_device_id = #{device_id})"
    end

    if options[:user]
      current_user = options[:current_user]
      user_id = options[:user].id

      user_condition = "calls_old.user_id = #{user_id} OR calls_old.dst_user_id = #{user_id}"

      if current_user.is_user?
        cards_ids = Card.available_ids("cards.user_id = #{user_id}")

        user_condition << " OR calls_old.card_id IN (#{cards_ids}) " if cards_ids.present?
        cond << "(#{user_condition})"
      elsif !current_user.is_reseller? || !current_user.is_user?
        cards_ids = Card.available_ids("cards.user_id = #{user_id}")
        devices_ids = Device.available_ids("devices.user_id = #{user_id}")

        user_condition << " OR calls_old.card_id IN (#{cards_ids}) " if cards_ids.present?
        user_condition << " OR calls_old.dst_device_id IN (#{devices_ids}) " if devices_ids.present?
      end
      cond << "(#{user_condition})"
    end

    did_option = options[:did]
    search_did_pattern = options[:s_did_pattern].to_s.strip
    if did_option
      cond << "calls_old.did_id = #{did_option.id}"
    elsif search_did_pattern.present?
      dids_ids = Did.available_ids("dids.did LIKE '#{search_did_pattern}'")
      cond << "calls_old.did_id IN (#{dids_ids})" if dids_ids.present?
    end

    #find_calls_old_only_with_did
    if options[:only_did].to_i == 1
      cond << 'calls_old.did_id > 0'
    end

    if options[:provider] or options[:did_provider]
      provider_cond = ""
      provider_cond << "calls_old.provider_id = #{options[:provider].id}" if options[:provider]
      provider_cond << " and " if options[:provider] and options[:did_provider]
      provider_cond << "calls_old.did_provider_id = #{options[:did_provider].id}" if options[:did_provider]
      cond << provider_cond
    end

    reseller_option = options[:reseller]
    if reseller_option
      cond << "calls_old.reseller_id = #{reseller_option.id}"
    end

    source_option = options[:source]
    if source_option.present?
      cond << "(calls_old.src LIKE '#{source_option}' OR calls_old.clid LIKE '#{source_option}')"
    end

    serach_card_number = options[:s_card_number].to_s.strip
    unless serach_card_number.blank?
      cards_ids = Card.available_ids("cards.number LIKE '#{serach_card_number}'")
      cond << "card_id IN (#{cards_ids})" if cards_ids.present?
    end

    search_card_pin = options[:s_card_pin].to_s.strip
    unless search_card_pin.blank?
      cards_ids = Card.available_ids("cards.pin LIKE '#{search_card_pin}'")
      cond << "card_id IN (#{cards_ids})" if cards_ids.present?
    end

    search_card_id = options[:s_card_id].to_s.strip
    unless search_card_id.blank?
      cond << "calls_old.card_id LIKE '#{search_card_id}'"
    end

    return cond
  end

  def OldCall.last_calls_parse_params(options={})
    jn = ['LEFT JOIN users ON (calls_old.user_id = users.id)',
          'LEFT JOIN users AS resellers ON (calls_old.reseller_id = resellers.id)',
          'LEFT JOIN dids ON (calls_old.did_id = dids.id)',
          'LEFT JOIN cards ON (calls_old.card_id = cards.id)',
          SqlExport.calls_old_left_join_reseler_providers_to_calls_sql
    ]
    cond = ["(calls_old.calldate BETWEEN ? AND ?)"]
    var = [options[:from], options[:till]]

    if options[:current_user].try(:usertype) == 'accountant' && options[:current_user].try(:show_only_assigned_users) == 1
      resp_acc = User.where(id: options[:current_user].id).first
      resp_acc_users = resp_acc.responsible_accountant_users(include_owner_users: true).pluck(:id).join(', ')
      resp_acc_user_devices = resp_acc.responsible_accountant_user_devices(include_owner_users: true).pluck(:id).join(', ')

      resp_acc_users = '-1' if resp_acc_users.blank?
      resp_acc_user_devices = '-1' if resp_acc_user_devices.blank?

      cond << "(calls_old.user_id IN (#{resp_acc_users})
                OR calls_old.dst_user_id IN (#{resp_acc_users})
                OR calls_old.reseller_id IN (#{resp_acc_users})
                OR calls_old.src_device_id IN (#{resp_acc_user_devices})
                OR calls_old.dst_device_id IN (#{resp_acc_user_devices})
               )"
    end

    if options[:current_user].usertype == "reseller" and !options[:user]
      jn << "LEFT JOIN users AS dst_users ON (dst_users.id = calls_old.dst_user_id)"
      cond << "(calls_old.reseller_id = ? OR calls_old.user_id = ? OR users.owner_id = ? OR dst_users.owner_id = ?)"
      var += ([options[:current_user].id] * 4)
    end

    if options[:current_user].usertype == 'partner' && !options[:user]
      cond << '(calls_old.partner_id = ?)'
      var += [options[:current_user].id]
    end

    if options[:call_type] != "all"
      if ['answered', 'failed'].include?(options[:call_type].to_s)
        cond << OldCall.nice_answered_cond_sql if options[:call_type].to_s == 'answered'
        cond << OldCall.nice_failed_cond_sql if options[:call_type].to_s == 'failed'
      else
        cond << "calls_old.disposition = ?"
        var << options[:call_type]
      end
    end

    if options[:hgc]
      cond << "calls_old.hangupcause = ?"
      var << options[:hgc].code
    end

    unless options[:destination].blank?
      cond << "localized_dst like ?"
      var << "#{options[:destination]}%"
    end

    if options[:s_reseller_did] != 'all' and !options[:s_reseller_did].blank?
      cond << "dids.reseller_id = ?"
      var << options[:s_reseller_did]
    end

    if options[:s_country] and !options[:s_country].blank?
      cond << "destinations.direction_code = ? "; var << options[:s_country]
      jn << 'LEFT JOIN destinations ON (calls_old.prefix = destinations.prefix)'
    end

    if options[:device].present? && options[:device].id
      cond << "(calls_old.dst_device_id = ? OR calls_old.src_device_id = ?)"
      var += [options[:device].id, options[:device].id]
    end

    if options[:user]
      user_id = options[:user].id
      if options[:current_user].usertype == "reseller"
        cond << "(calls_old.user_id = ? OR calls_old.dst_user_id = ?)"
        var += [user_id, user_id]
      else
        jn << "LEFT JOIN devices AS dst_device ON (dst_device.id = calls_old.dst_device_id)"
        cond << "(calls_old.user_id = ? OR dst_device.user_id = ? OR calls_old.dst_user_id = ?)"
        var += [options[:user].id, options[:user].id, options[:user].id]
      end
    end

    if options[:did]
      cond << "calls_old.did_id = ?"
      var << options[:did].id
    elsif !options[:s_did_pattern].to_s.strip.blank?
      cond << "dids.did LIKE ?"
      var << '%' + options[:s_did_pattern].to_s.strip + '%'
    end

    #find_calls_only_with_did
    if options[:only_did] and options[:only_did].to_i == 1
      cond<<"calls_old.did_id > ?"
      var << '0'
    end

    if options[:provider] or options[:did_provider]
      c = ""
      c << "(" if options[:provider] and options[:did_provider]
      c << "calls_old.provider_id = ?" if options[:provider]
      c << " or " if options[:provider] and options[:did_provider]
      c << "calls_old.did_provider_id = ?" if options[:did_provider]
      c << ")" if options[:provider] and options[:did_provider]
      cond << c
      var += [options[:provider].id] if options[:provider]
      var += [options[:did_provider].id] if options[:did_provider]
    end

    if options[:reseller]
      cond << "calls_old.reseller_id = ?"
      var << options[:reseller].id
    end

    if options[:source] and not options[:source].blank?
      cond << "calls_old.src LIKE ?"
      var << '%' + options[:source] + '%'
    end
    # this is nasty but oh well.

    unless options[:s_card_number].to_s.strip.blank?
      cond << "cards.number LIKE ?"
      var << options[:s_card_number]
    end

    unless options[:s_card_pin].to_s.strip.blank?
      cond << "cards.pin = ?"
      var << options[:s_card_pin]
    end

    unless options[:s_card_id].to_s.strip.blank?
      cond << "calls_old.card_id = ?"
      var << options[:s_card_id]
    end

    return cond, var, jn
  end

  def self.last_calls_csv_headers
    {
      'calldate2' => _('Date'),
      'Source' => _('Called_from'),
      'clid' => _('Called_to'),
      'dst' => _('Called_to'),
      'prefix' => _('Prefix'),
      'destination' => _('Destination'),
      'nice_billsec' => _('Duration'),
      'dispod' => _('hangup_cause'),
      'server_id' => _('Server'),
      'nice_reseller' => _('Reseller'),
      'did_prov_price' => _('DID_provider_price'),
      'provider_name' => _('Provider_name'),
      'provider_rate' => _('Provider_rate'),
      'provider_price' => _('Provider_price'),
      'reseller_rate' => _('Reseller_rate'),
      'reseller_price' => _('Reseller_price'),
      'user' => _('User_name'),
      'user_rate' => _('User_rate'),
      'did' => _('DID_Number'),
      'did_inc_price' => _('DID_Number'),
      'did_price' => _('DID_Price'),
      'user_price' => _('User_price'),
      'profit' => _('Profit')
    }
  end

  def self.last_calls_csv_partner_headers
    {
      'calldate2' => _('Time'),
      'src' => _('Source'),
      'clid' => _('Called_from'),
      'dst' => _('Called_to'),
      'nice_billsec' => _('Duration'),
      'dispod' => _('hangup_cause'),
      'server_id' => _('Server'),
      'partner_price' => _('Self-Cost_Price'),
      'partner_rate' => _('Self-Cost_Rate'),
      'nice_reseller' => _('Reseller'),
      'reseller_rate' => _('Reseller_rate'),
      'reseller_price' => _('Reseller_price'),
      'user' => _('User'),
      'user_rate' => _('User_rate'),
      'user_price' => _('User_price'),
      'did' => _('DID_Number'),
      'did_prov_price' => _('DID_provider_price'),
      'did_inc_price' => _('DID_incoming_price'),
      'did_price' => _('DID_Price'),
      'profit' => _('Profit')
    }
  end
end