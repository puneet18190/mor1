# -*- encoding : utf-8 -*-
class Call < ActiveRecord::Base
  include SqlExport
  include CsvImportDb
  extend UniversalHelpers
  belongs_to :user
  belongs_to :provider
  belongs_to :device, foreign_key: 'accountcode'
  has_many :cc_actions
  has_one :recording, primary_key: 'uniqueid', foreign_key: 'uniqueid'
  has_one :call_detail
  belongs_to :card
  belongs_to :server

  has_and_belongs_to_many :cs_invoices

  validates_presence_of :calldate, :message => _("Calldate_cannot_be_blank")

  attr_protected

  #def device
  #  Device.find(self.accountcode)nice_billsec
  #end
  #
  # Nasty hack to overide provider method. Used in CallController.advanced_list and coresponding view.
  # MK: provider is only Termination provider, if some method needs did provider, then it should use did_provider method
  # MK: callertype=Local/Outside does not show correctly if call is outgoing or incomming, MOR also has calls which are incoming+outgoing at the same time
  alias_method :provider_by_id, :provider

  def call_log_request
    "/usr/local/mor/mor_call_log \"#{uniqueid}\""
  end

  def provider
    #if self.callertype == 'Local' #outgoing call
    return Provider.where(id: self.provider_id.to_i).first
    #end
    #if self.callertype == 'Outside' #incoming call
    #  return Provider.find(:first, :conditions => "id = #{self.did_provider_id}")
    #end
    #return nil
  end

  def did_provider
    return Provider.where(id: self.did_provider_id.to_i).first
  end

  def nice_billsec
    #it is used to show correct billsec for flat-rates call, because call.billsec = 0 for flatrates, but real_billsec > 0
    # billsec = 0 because to do not ruin rerating and to handle call which part is billed by flat-rate, another part by normal rate
    billsec = self.billsec
    billsec = self.real_billsec.ceil if billsec == 0 and self.real_billsec > 1
    billsec
  end

  def nice_user_billsec
    billsec = self.user_billsec
    billsec = self.real_billsec.ceil if billsec == 0 and self.real_billsec > 1
    billsec
  end

  def Call.nice_billsec_sql
    current_user = User.current

    if current_user.is_user? and Confline.get_value("Invoice_user_billsec_show", current_user.owner.id).to_i == 1
      "CEIL(user_billsec) as 'nice_billsec'"
    elsif current_user.is_partner?
      "CEIL(IF(partner_billsec > 0, partner_billsec, 0)) as 'nice_billsec'"
    else
      "IF((billsec = 0 AND real_billsec > 1), CEIL(real_billsec), billsec) as 'nice_billsec'"
    end
  end

  def Call.nice_answered_cond_sql(search_not = true)
    if User.current.usertype.to_s == 'user' and Confline.get_value('Change_ANSWER_to_FAILED_if_HGC_not_equal_to_16_for_Users').to_i == 1
      if search_not
        " (calls.disposition='ANSWERED' AND calls.hangupcause='16') "
      else
        " (calls.disposition='ANSWERED' OR (calls.disposition='ANSWERED' AND calls.hangupcause!='16') ) "
      end
    else
      " calls.disposition='ANSWERED' "
    end
  end

  def Call.nice_failed_cond_sql
    if User.current.usertype.to_s == 'user' and Confline.get_value('Change_ANSWER_to_FAILED_if_HGC_not_equal_to_16_for_Users').to_i == 1
      " (calls.disposition='FAILED' OR (calls.disposition='ANSWERED' and calls.hangupcause!='16')) "
    else
      " calls.disposition='FAILED' "
    end
  end

  def Call.nice_disposition
    if User.current.usertype.to_s == 'user' and Confline.get_value('Change_ANSWER_to_FAILED_if_HGC_not_equal_to_16_for_Users').to_i == 1
      " IF(calls.disposition  = 'ANSWERED',IF((calls.disposition='ANSWERED' AND calls.hangupcause='16'), 'ANSWERED', 'FAILED'),disposition)"
    else
      " calls.disposition"
    end
  end

  def reseller
    res = nil
    res = User.where(id: reseller_id).first if reseller_id.to_i > 0
    res
  end

  def destinations
    de = nil
    de = Destination.find(self.prefix) if self.prefix and self.prefix.to_i > 0
    de
  end

  def peerip
    self.call_detail.try :peerip
  end

  def recvip
    self.call_detail.try :recvip
  end

  def sipfrom
    self.call_detail.try :sipfrom
  end

  def uri
    self.call_detail.try :uri
  end

  def useragent
    self.call_detail.try :useragent
  end

  def peername
    self.call_detail.try :peername
  end

  def t38passthrough
    self.call_detail.try :t38passthrough
  end

  # Returns hash with call debuginfo
  def getDebugInfo
    debuginfo = {}

    [:peerip, :recvip, :sipfrom, :useragent, :peername, :uri, :t38passthrough].each do |key|
      debuginfo[key.to_s] = send(key).to_s
    end

    debuginfo
  end

  def Call::total_calls_by_direction_and_disposition(start_date, end_date, users = [])
    #parameters:
    #  start_date - min date for filtering out calls, expected to be date/datetime
    #    instance or date/datetime as string
    #  end_date - max date for filtering out calls, expected to be date instance or date as
    #    string.
    #  users - array of user id's
    #returns - array of hashs. total call count for incoming and outgoing, answered, not answered,
    #  busy and failed calls grouped by disposition and direction originated or received by
    #  specified users. if no users were specified - for all users
    Call.total_calls_by([], {:outgoing => true, :incoming => true}, start_date, end_date, {:direction => true, :disposition => true}, users)
  end

  def Call::answered_calls_day_by_day(start_date, end_date, users = [], options = {})
    if options[:es_enabled]
      es_options = {utc_offset: Time.now.in_time_zone(User.current.time_zone).formatted_offset}
      raw_calls = []
      calls_by_day = Elasticsearch.safe_search_mor_calls(ElasticsearchQueries.es_answered_calls_day_by_day(options[:es_session_from], options[:es_session_till], es_options, users))
      total_billsec = 0
      calls_by_day['aggregations']['dates']['buckets'].each do |bucket|
        raw_calls << {'total_calls' => bucket['doc_count'], 'total_billsec' => bucket['total_billsec']['value'], calldate: Time.parse(bucket['key_as_string'])}
        total_billsec += bucket['total_billsec']['value']
      end
      average_billsec = calls_by_day['hits']['total'] == 0 ? nil : total_billsec / calls_by_day['hits']['total']
      raw_calls << {'total_calls' => calls_by_day['hits']['total'], 'total_billsec' => total_billsec, 'average_billsec' => average_billsec}
    else
      raw_calls = Call.total_calls_by(['ANSWERED'], {:outgoing => true, :incoming => true}, start_date, end_date, {:date => true}, users)
    end
    totals = raw_calls.pop
    tz = User.current.time_zone

    start_time = Time.parse(start_date).in_time_zone(tz).strftime('%F')
    end_time = Time.parse(end_date).in_time_zone(tz).strftime('%F')

    dates = (start_time.to_date..end_time.to_date).map{ |date| date.strftime("%F") }
    calls =[]
    t_billsec =[]
    avg_billsec =[]

    date_get = lambda do |i|
      (Time.parse(start_date).in_time_zone(tz) + (i).days).strftime("%F %T")
    end

    dates.each_with_index do |date, i|
      interval = raw_calls.select do |summary|
        date = summary[:calldate].strftime("%F %T")
        date >= date_get[i] && date < date_get[i+1]
      end

      unless interval.blank?
        if options[:es_enabled]
          call_count  = interval.collect.sum['total_calls']
          billsec  = interval.collect.sum['total_billsec']
        else
          call_count  = interval.collect(&:total_calls).sum
          billsec     = interval.collect(&:total_billsec).sum
        end

        calls       << call_count
        t_billsec   << billsec
        avg_billsec << (billsec / call_count)
      else
        calls       << 0
        t_billsec   << 0
        avg_billsec << 0
      end
    end

    return dates, calls, t_billsec, avg_billsec, totals
  end

  def Call::total_calls_by(disposition, direction, start_date, end_date, group_options = [], users = [])
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
    select << "SUM(calls.billsec) AS 'total_billsec'"
    select << "AVG(calls.billsec) AS 'average_billsec'"

    condition = []
    condition << "calls.calldate BETWEEN '#{start_date.to_s}' AND '#{end_date.to_s}'"
    #if disposition is not specified or it is all 4 types(answered, failed, busy, no answer),
    #there is no need to filter it
    condition << "calls.disposition IN ('#{disposition.join(', ')}')" if !disposition.empty? and disposition.length < 4

    join = []
    if users.empty?
      if direction.include?(:incoming) and direction.include?(:outgoing)
        condition << "calls.user_id IS NOT NULL"
      else
        condition << 'calls.user_id != -1 AND calls.user_id IS NOT NULL' if direction.include?(:outgoing)
        condition << 'calls.user_id = -1' if direction.include?(:incoming)
      end
    else
      #no mater weather we are allready checking devices for user_id, call.user_id might still be NULL, else we would select
      #to many failed calls
      condition << "calls.user_id IS NOT NULL"
      if direction.include?(:outgoing) and direction.include?(:incoming)
        condition << "(dst_devices.user_id IN (#{users.join(', ')}) OR src_devices.user_id IN (#{users.join(', ')}))"
      end
      if direction.include?(:incoming)
        join << 'LEFT JOIN devices dst_devices ON calls.dst_device_id = dst_devices.id'
        condition << "dst_devices.user_id IN (#{users.join(', ')}" if !direction.include?(:outgoing)
      end
      if direction.include?(:outgoing)
        join << 'LEFT JOIN devices src_devices ON calls.src_device_id = src_devices.id'
        condition << "src_devices.user_id IN (#{users.join(', ')})" if !direction.include?(:incoming)
      end
    end

    #dont group at all, group by date, direction and/or disposition
    #accordingly, we should select those fields from table
    group = []
    if group_options[:date]
      select << "(calls.calldate) AS 'calldate'"
      group << 'year(calldate), month(calldate), day(calldate), hour(calldate)'
    end
    if group_options[:disposition]
      select << 'calls.disposition'
      group << 'calls.disposition' if group_options[:disposition]
    end

    if group_options[:direction]
      if users.empty?
        select << "IF(calls.user_id  = -1, 'incoming', 'outgoing') AS 'direction'"
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
      statistics = Call.select(select.join(', ')).joins(join.join(' ')).where(condition.join(' AND ')).group(group.join(', ')).all
      statistics.each do |st|
        st.calldate = (st.calldate.to_time + Time.zone.now.utc_offset().second - Time.now.utc_offset().second).to_s(:db) if !st.calldate.blank?
      end
    else
      statistics = Call.select(select.join(', ')).joins(join.join(' ')).where(condition.join(' AND ')).group(group.join(', ')).all
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

  def self.es_total_calls_by(start_date, end_date, users = [], user_perspective = false)
    statistics = []
    total = 0

    es_detailed_calls = Elasticsearch.safe_search_mor_calls(ElasticsearchQueries.es_all_users_detailed_calls_query(start_date, end_date, users, user_perspective))
    return false if es_detailed_calls.blank?

    es_detailed_calls['aggregations']['incoming_calls_filter']['grouped_by_disposition']['buckets'].each do |bucket|
      total += bucket['doc_count']
      statistics << {'total_calls' => bucket['doc_count'], 'disposition' => bucket['key'], 'direction' => 'incoming'}
    end
    es_detailed_calls['aggregations']['outgoing_calls_filter']['grouped_by_disposition']['buckets'].each do |bucket|
      total += bucket['doc_count']
      statistics << {'total_calls' => bucket['doc_count'], 'disposition' => bucket['key'], 'direction' => 'outgoing'}
    end
    statistics << {'total_calls' => total}
    statistics
  end

  def self.es_search_aggregates(from, till, options, terminator_id)
    search_by_originator = options[:originator_id] != 'none'
    search_by_terminator = options[:terminator] != '-1'
    search_by_prefix = options[:prefix].present?
    search_by_destinationgroup = options[:country] != '-1'
    total_results = {}
    aggregates = []
    %i(total_records user_billed user_billed_with_tax terminator_billed user_billed_billsec
        terminator_billed_billsec billsec answered_calls total_calls asr acd).each{ |key| total_results[key] = 0 }

    get_aggregate_data = proc do |bucket, aggregate_data|
      unless bucket['answered_calls']['doc_count'] < options[:answered_calls].to_i
        aggregate = {}
        aggregate[:originator_id] = aggregate_data[:aggregate_originator_id]
        aggregate[:nice_user] = aggregate_data[:aggregate_nice_user]
        aggregate[:name] = aggregate_data[:aggregate_name]
        aggregate[:prefix] = aggregate_data[:prefix]
        aggregate[:destination_group] = aggregate_data[:destination_group]
        total_results[:total_records] += 1
        total_results[:user_billed] += aggregate[:user_billed] = bucket['total_originator_price']['value']
        total_results[:user_billed_with_tax] += aggregate[:user_billed_with_tax] = bucket['total_originator_price']['value'] * options[:exchange_rate]
        total_results[:terminator_billed] += aggregate[:terminator_billed] = bucket['total_terminator_price']['value'] * options[:exchange_rate]
        total_results[:user_billed_billsec] += aggregate[:user_billed_billsec] = bucket['total_originator_billsec']['value']
        total_results[:terminator_billed_billsec] += aggregate[:terminator_billed_billsec] = bucket['total_terminator_billsec']['value']
        total_results[:billsec] += aggregate[:billsec] = bucket['total_billsec']['value']
        total_results[:answered_calls] += aggregate[:answered_calls] = bucket['answered_calls']['doc_count']
        total_results[:total_calls] += aggregate[:total_calls] = bucket['doc_count']
        aggregate[:asr] = aggregate[:answered_calls].to_d / aggregate[:total_calls].to_d
        aggregate[:acd] = aggregate[:answered_calls] > 0 ? aggregate[:billsec] / aggregate[:answered_calls] : 0


        aggregates << aggregate
      end
    end

    grouped_by_prefix = proc do |aggregation, aggregate_data|
      aggregation['grouped_by_prefix']['buckets'].each do |bucket|
        aggregate_data[:prefix] = bucket['key']
        get_aggregate_data.call(bucket, aggregate_data)
      end
    end

    grouped_by_terminator = proc do |aggregation, aggregate_data|
      aggregation['grouped_by_terminator']['buckets'].each do |bucket|
        aggregate_data[:aggregate_name] = terminator_id == 0 ? Terminator.where(id: Provider.where(id: bucket['key']).first.try(:terminator_id)).first.try(:name).to_s : Terminator.find(terminator_id).name

        search_by_prefix ? grouped_by_prefix.call(bucket, aggregate_data) : get_aggregate_data.call(bucket, aggregate_data)
      end
    end

    grouped_by_originator = proc do |aggregation, aggregate_data|
      aggregation['grouped_by_originator']['buckets'].each do |bucket|
        aggregate_data[:aggregate_originator_id] = bucket['key']
        aggregate_data[:aggregate_nice_user] = bucket['key'] == -1 ? '' : User.where(id: bucket['key']).first.try(:nice_name)
        if search_by_terminator
          grouped_by_terminator.call(bucket, aggregate_data)
        elsif search_by_prefix
          grouped_by_prefix.call(bucket, aggregate_data)
        else
          get_aggregate_data.call(bucket, aggregate_data)
        end
      end
    end

    grouped_by_destination = proc do |aggregation|
      aggregate_data = {}
      aggregation['grouped_by_dg_id']['buckets'].each do |bucket|
        aggregate_data[:destination_group] = Destinationgroup.where(id: bucket['key']).first.try(:name) || _('Unknown')
        if search_by_originator
          grouped_by_originator.call(bucket, aggregate_data)
        elsif search_by_terminator
          grouped_by_terminator.call(bucket, aggregate_data)
        elsif search_by_prefix
          grouped_by_prefix.call(bucket, aggregate_data)
        else
          get_aggregate_data.call(bucket, aggregate_data)
        end
      end
    end

    es_result = Elasticsearch.safe_search_mor_calls(ElasticsearchQueries.es_aggregates(from, till, options))
    aggregation = es_result['aggregations']

    if search_by_destinationgroup
      grouped_by_destination.call(aggregation)
    elsif search_by_originator
      grouped_by_originator.call(aggregation, {})
    elsif search_by_terminator
      grouped_by_terminator.call(aggregation, {})
    elsif search_by_prefix
      grouped_by_prefix.call(aggregation, {})
    end

    total_results[:average_asr] = total_results[:answered_calls].to_f / total_results[:total_calls].to_f
    total_results[:average_acd] = total_results[:answered_calls] > 0 ? total_results[:billsec] / total_results[:answered_calls] : 0

    [aggregates, total_results]
  end

  def Call::summary_by_terminator(cond, terminator_cond, order_by, user)
    cond2 = []

    if user.usertype == 'reseller'
      provider_billsec = "SUM(IF(c.disposition = 'ANSWERED', c.reseller_billsec, 0)) AS 'provider_billsec'"
      provider_price = SqlExport.replace_price("SUM(IF(c.disposition = 'ANSWERED', #{SqlExport.reseller_provider_price_sql.gsub("calls.", "c.").gsub("providers.", "p.")}, 0))", {:reference => 'provider_price'})
      cond2 << "u.owner_id = #{user.id}"
    else
      provider_billsec = "SUM(IF(c.disposition = 'ANSWERED', c.provider_billsec, 0)) AS 'provider_billsec'"
      provider_price = SqlExport.replace_price("SUM(#{SqlExport.admin_provider_price_sql.gsub("providers.", "p.").gsub("calls.", "c.")} - c.did_prov_price)", {:reference => 'provider_price'})
    end

    #limit terminators to allowed ones.
    term_ids = user.load_terminators_ids
    if terminator_cond.blank?
      if term_ids.size == 0
        cond2 << "p.terminator_id = 0"
      else
        cond2 << "p.terminator_id IN (#{term_ids.join(", ")})"
      end
    else
      cond2 << "p.terminator_id = #{terminator_cond.to_s}"
    end

    sql = "SELECT #{SqlExport.nice_user_sql("u")}, " +
    't.name AS provider_name, ' +
    'p.id AS prov_id, ' +
    'COUNT(*) AS total_calls, ' +
    "SUM(IF(c.disposition = 'ANSWERED', 1, 0)) AS answered_calls, " +
    "SUM(IF(c.disposition = 'ANSWERED', c.user_billsec, 0)) AS exact_billsec, " +
    "#{[provider_billsec, provider_price].join(",\n ")}, " +
    'SUM(c.billsec) AS billsec, SUM(c.provider_billsec) AS provider_billsec, ' +
    'SUM(c.did_prov_price) AS did_prov_price, ' +
    'SUM(c.reseller_billsec) AS reseller_billsec, ' +
    'SUM(c.did_inc_price) AS did_inc_price ' +
    "FROM ( SELECT c.* FROM calls c WHERE " + cond.join(" AND ").gsub("calls.", "c.") + " ) c " +
    'JOIN providers p ON (c.provider_id = p.id) ' +
    'JOIN devices d ON (c.src_device_id = d.id) ' +
    'JOIN users u ON (d.user_id = u.id) ' +
    'JOIN terminators t ON (t.id = p.terminator_id) ' +
    "WHERE (" + cond2.join(" AND ")+ ") " +
    "GROUP BY t.id #{order_by.size > 0 ? 'ORDER BY ' +order_by : ''};"

    Call.find_by_sql(sql)
  end

  def Call::summary_by_originator(cond, terminator_cond, order_by, user)
    cond2 = []

    if user.usertype == 'reseller'
      cond2 << "u.owner_id = #{user.id}"
      originator_billsec= "SUM(IF(c.user_billsec IS NULL AND c.disposition = 'ANSWERED', 0, c.user_billsec)) AS 'originator_billsec'"
      originator_price = "SUM(IF(c.user_price IS NULL AND c.disposition = 'ANSWERED', 0, #{SqlExport.replace_price(SqlExport.user_price_sql.gsub("calls.", "c."))})) AS 'originator_price'"
      originator_price_with_vat = SqlExport.replace_with_tax("SUM(#{SqlExport.summary_originator_price_with_vat("IF(c.user_price IS NULL AND c.disposition = 'ANSWERED', 0, #{SqlExport.replace_price(SqlExport.user_price_sql.gsub("calls.", "c."))})")})", {:reference => 'originator_price_with_vat'})
    else
      originator_billsec= "SUM(IF(owner_id = 0 AND c.disposition = 'ANSWERED', IF(c.user_billsec IS NULL, 0, c.user_billsec), if(c.reseller_billsec IS NULL, 0, c.reseller_billsec))) AS 'originator_billsec'"
      originator_price = "SUM(#{SqlExport.replace_price(SqlExport.admin_user_price_no_dids_sql.gsub("providers.", "p.").gsub("calls.", "c."))}) AS 'originator_price'"
      originator_price_with_vat = SqlExport.replace_with_tax("SUM(#{SqlExport.summary_originator_price_with_vat(SqlExport.replace_price(SqlExport.admin_user_price_no_dids_sql.gsub("providers.", "p.").gsub("calls.", "c.")))})", {:reference => 'originator_price_with_vat'})
    end

    #limit terminators to allowed ones.
    term_ids = user.load_terminators_ids
    if terminator_cond.blank?
      if term_ids.size == 0
        cond2 << "p.terminator_id = 0"
      else
        cond2 << "p.terminator_id IN (#{term_ids.join(", ")})"
      end
    else
      cond2 << "p.terminator_id = #{terminator_cond.to_s}"
    end

    sql = "
    SELECT
    #{SqlExport.nice_user_sql("u")},

    SUM(c.total_calls) AS total_calls,
    SUM(IF(c.disposition = 'ANSWERED', 1,0)) AS 'answered_calls',
    d.user_id AS 'dev_user_id',
    SUM(IF(c.disposition = 'ANSWERED', c.billsec, 0)) AS 'exact_billsec',
    #{[originator_billsec, originator_price, originator_price_with_vat].join(",\n")}

    FROM (
      SELECT c.provider_id, c.reseller_id, c.src_device_id, c.disposition,
        COUNT(c.id) AS total_calls, SUM(c.billsec) AS billsec,
        SUM(c.user_billsec) AS user_billsec, SUM(c.reseller_billsec) AS reseller_billsec,
        SUM(c.user_price) AS user_price, SUM(c.reseller_price) AS reseller_price,
        SUM(c.did_inc_price) AS did_inc_price
      FROM calls c FORCE INDEX (calldate)
      WHERE (" + cond.join(" AND ").gsub("calls.", "c.") + ")
      GROUP BY c.provider_id, c.reseller_id, c.src_device_id, c.disposition
    ) c

    JOIN providers p ON p.id = c.provider_id
    LEFT JOIN devices d ON c.src_device_id = d.id
    LEFT JOIN users u ON u.id = d.user_id
    LEFT JOIN taxes ON (taxes.id = u.tax_id)
    WHERE(" + cond2.join(" AND ")+ ")
    GROUP BY d.user_id
    #{order_by.size > 0 ? 'ORDER BY ' +order_by : ''}
    "
    Call.find_by_sql(sql)
  end

  def Call.calls_order_by(params, options)
    case options[:order_by].to_s.strip
      when "time" then
        order_by = "calls.calldate"
      when "src" then
        order_by = "calls.src"
      when "dst" then
        order_by = "calls.dst"
      when "nice_billsec" then
        order_by = "nice_billsec"
      when "hgc" then
        order_by = "calls.hangupcause"
      when "server" then
        order_by = "calls.server_id"
      when "p_name" then
        order_by = "providers.name"
      when "p_rate" then
        order_by = "calls.provider_rate"
      when "p_price" then
        order_by = "calls.provider_price"
      when "reseller" then
        order_by = "nice_reseller"
      when "r_rate" then
        order_by = "calls.reseller_rate"
      when "r_price" then
        order_by = "calls.reseller_price"
      when "user" then
        order_by = "nice_user"
      when "u_rate" then
        order_by = "calls.user_rate"
      when "u_price" then
        order_by = "calls.user_price"
      when "number" then
        order_by = "dids.did"
      when "d_provider" then
        order_by = "calls.did_prov_price"
      when "d_inc" then
        order_by = "calls.did_inc_price"
      when "d_owner" then
        order_by = "calls.did_price"
      when "prefix" then
        order_by = "calls.prefix"
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
        order_by = 'calls.calldate'
    end
    if order_by != ""
      order_by += (options[:order_desc].to_i == 0 ? " ASC" : " DESC")
    end
    return order_by
  end

  def call_log
    c_l = CallLog.where(uniqueid: self.uniqueid).first
    return c_l
  end

  def Call.last_calls(options={})
    cond, var, jn = Call.last_calls_parse_params(options)
    select = ["calls.*", Call.nice_billsec_sql]
    select << SqlExport.nice_user_sql
    #select << 'calls.user_id, users.first_name, users.last_name, card_id, cards.number'
    select << Call.nice_disposition + ' AS disposition'

    #if reseller pro - change common use provider price, rate to reseller tariff rate, price

    select << "(#{SqlExport.reseller_rate_sql} * #{options[:exchange_rate]} ) AS reseller_rate_exrate"

    if options[:current_user].usertype == 'reseller'
      unless User.current.try(:owner).is_partner?
        select << "(IF(users.owner_id = #{options[:current_user].id}, 0, did_price) * #{options[:exchange_rate]} ) AS did_price_exrate"
        select << "(IF(users.owner_id = #{options[:current_user].id}, did_inc_price, 0) * #{options[:exchange_rate]} ) AS did_inc_price_exrate"
        select << "(did_prov_price * #{options[:exchange_rate]} ) AS did_prov_price_exrate"
      end
      if options[:current_user].reseller_allow_providers_tariff?
        select << "(#{SqlExport.reseller_provider_rate_sql} * #{options[:exchange_rate]} ) AS provider_rate_exrate"
        select << "(#{SqlExport.reseller_provider_price_sql} * #{options[:exchange_rate]} ) AS provider_price_exrate"
      end
      select << "(#{SqlExport.user_price_no_dids_sql} * #{options[:exchange_rate]} ) AS user_price_exrate"
      select << "(#{SqlExport.reseller_price_no_dids_sql} * #{options[:exchange_rate]} ) AS reseller_price_exrate"
      select << "(#{SqlExport.user_rate_sql} * #{options[:exchange_rate]} ) AS user_rate_exrate"
      select << "(#{SqlExport.reseller_profit_no_dids_sql(options[:current_user])} * #{options[:exchange_rate]} ) AS profit"
    elsif options[:current_user].usertype == 'partner'
      select << "(#{SqlExport.partner_price_sql} * #{options[:exchange_rate]} ) AS partner_price"
      select << "(#{SqlExport.user_price_no_dids_sql} * #{options[:exchange_rate]} ) AS user_price_exrate"
      select << "(#{SqlExport.reseller_price_no_dids_sql} * #{options[:exchange_rate]} ) AS reseller_price_exrate"
      select << "(#{SqlExport.user_rate_sql} * #{options[:exchange_rate]} ) AS user_rate_exrate"
      select << "(#{SqlExport.reseller_profit_no_dids_sql(options[:current_user])} * #{options[:exchange_rate]} ) AS profit"
    else
      ['did_price', 'did_inc_price', 'did_prov_price'].each { |co| select << "(#{co} * #{options[:exchange_rate]} ) AS #{co}_exrate" }
      if options[:current_user].usertype == 'user'
        # If user is making call to himself, he must pay both DID prices: incoming and owner.
        select << "(IF(calls.user_id = #{options[:current_user].id}, #{SqlExport.user_price_sql}, 0) + IF(calls.dst_user_id = #{options[:current_user].id}, #{SqlExport.user_did_price_sql}, 0)) * #{options[:exchange_rate]} AS user_price_exrate"
        select << "(#{SqlExport.user_rate_sql} * #{options[:exchange_rate]} ) AS user_rate_exrate"
      else
        select << "(#{SqlExport.user_price_no_dids_sql} * #{options[:exchange_rate]} ) AS user_price_exrate"
        select << "(#{SqlExport.admin_reseller_price_no_dids_sql} * #{options[:exchange_rate]} ) AS reseller_price_exrate"
        select << "(#{SqlExport.admin_user_rate_sql} * #{options[:exchange_rate]} ) AS user_rate_exrate"
        select << "(#{SqlExport.admin_provider_rate_sql} * #{options[:exchange_rate]}) AS provider_rate_exrate "
        select << "(#{SqlExport.admin_provider_price_sql} * #{options[:exchange_rate]} ) AS provider_price_exrate"
        select << "(#{SqlExport.admin_profit_sql} + calls.did_price + calls.did_prov_price) * #{options[:exchange_rate]} AS profit"
      end
    end
    select << "IF(resellers.id > 0, #{SqlExport.nice_user_sql("resellers", nil)}, '') AS 'nice_reseller'"
    if options[:show_device_and_cid].to_i == 1
      select << "CONCAT(src_device.device_type, '/', src_device.extension, ' (', IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(src_device.callerid, '<', -1), '>', 1), ''), ')') AS nice_src_device"
      jn << "LEFT JOIN devices AS src_device ON (src_device.id = calls.src_device_id)"
    end
    selected_page = options[:page].to_i - 1
    selected_page = 1 if (selected_page < 0)
    Call.select(select.join(", \n")).
        joins(jn.join(" \n")).
        where([cond.join(" \nAND "), *var]).
        order(ActiveRecord::Base::sanitize(options[:order])[1..-2]).
        limit("#{(selected_page * options[:items_per_page].to_i).to_i}, #{options[:items_per_page].to_i}").to_a

  end

  def self.last_calls_total_count(options = {})
    cond = Call.last_calls_raw_conditions(options)

    if cond.present?
      # 11118 Revert till better solution
      cond, var, jn = Call.last_calls_parse_params(options)
      return Call.select("COUNT(*) as total_calls").joins(jn.join(" \n")).where([cond.join(' AND '), *var]).first.total_calls.to_i

      # sql_statement = "SELECT
      #                    COUNT(all_calls.id) as total_calls
      #                  FROM
      #                    (SELECT calls.id, calls.calldate
      #                      FROM calls
      #                      WHERE #{cond.join(' AND ')}
      #                     ) as all_calls
      #                  WHERE #{date_condition} LIMIT 1"
    else
      date_condition = "(all_calls.calldate BETWEEN '#{options[:from]}' AND '#{options[:till]}')"
      current_user = options[:current_user]
      date_condition << " AND all_calls.callertype = 'Outside'" if current_user.is_user? && current_user.stats_from_user_perspective == 1
      sql_statement  = "SELECT
                          COUNT(all_calls.id) as total_calls
                        FROM calls AS all_calls
                        WHERE #{date_condition} LIMIT 1"
      return Call.connection.select_all(sql_statement)[0]['total_calls'].to_i
    end
  end

  def Call.last_calls_csv(options={})
    show_did_user = Confline.get_value("Show_DID_User_in_Last_Calls", 0).to_i
    dstuser = show_did_user.to_i == 1 ? 'diduser' : 'dstuser'
    cond, var, jn = Call.last_calls_parse_params(options)
    s =[]
    format = Confline.get_value('Date_format', (options[:current_user].usertype == 'reseller' ? options[:current_user].id : options[:current_user].owner_id)).try(:gsub, 'M', 'i')
    csv_full_src = true if options[:show_full_src].to_i == 1
    # calldate2 - because something overwites calldate when changing date format
    time_offset = options[:current_user].time_offset
    if options[:api].to_i == 1
      format = '%Y-%m-%d %H:%i:%S'
      s << SqlExport.column_escape_null(SqlExport.nice_date('calls.calldate', {:format => format, :offset => 0}), "calldate2")
      s << SqlExport.column_escape_null('calls.uniqueid', 'uniqueid')
    else
      s << SqlExport.column_escape_null(SqlExport.nice_date('calls.calldate', {:format => format, :offset => time_offset}), "calldate2")
    end

    unless csv_full_src
      nice_name = options[:cdr_template_id] ? 'clid' : 'src'
      s << SqlExport.column_escape_null("calls.src", "#{nice_name}")
    end

    if options[:pdf].to_i == 1
      s << SqlExport.column_escape_null("calls.clid", "clid")
    elsif csv_full_src
      s << SqlExport.nice_src(options[:cdr_template_id])
    end
    options[:current_user].usertype == 'user' ? s << SqlExport.hide_dst_for_user_sql(options[:current_user], "csv", SqlExport.column_escape_null("calls.localized_dst"), {:as => "dst"}) : s << SqlExport.column_escape_null("calls.localized_dst", "dst")
    if options[:current_user].usertype != 'reseller'
      s << SqlExport.column_escape_null("calls.prefix", "prefix")
    end
    s << "CONCAT(#{SqlExport.column_escape_null("directions.name")}, ' ', #{SqlExport.column_escape_null("destinations.name")}) as destination"
    s << Call.nice_billsec_sql

    if options[:current_user].usertype != 'user' or (Confline.get_value('Show_HGC_for_Resellers').to_i == 1 and options[:current_user].usertype == 'reseller')
      s << SqlExport.column_escape_null("CONCAT(#{SqlExport.column_escape_null("calls.disposition")}, '(', #{SqlExport.column_escape_null("calls.hangupcause")}, ')')", 'dispod')
    else
      s << SqlExport.column_escape_null(Call.nice_disposition, 'dispod')
    end
    if options[:current_user].usertype == "admin" or options[:current_user].usertype == "accountant"
      s << SqlExport.column_escape_null("calls.server_id", "server_id")
      s << SqlExport.column_escape_null("providers.name", "provider_name")
      if options[:can_see_finances]
        s << SqlExport.replace_dec_round("(IF(calls.provider_rate IS NULL, 0, #{SqlExport.admin_provider_rate_sql}) * #{options[:exchange_rate]} )", options[:column_dem], 'provider_rate')
        s << SqlExport.replace_dec_round("(IF(calls.provider_price IS NULL, 0, #{SqlExport.admin_provider_price_sql}) * #{options[:exchange_rate]} )", options[:column_dem], 'provider_price')
      end
      if Confline.get_value('RS_Active').to_i == 1
        nice_reseller = "IF(resellers.id != 0,IF(LENGTH(resellers.first_name+resellers.last_name) > 0, CONCAT(resellers.first_name, ' ',resellers.last_name ), resellers.username), ' ')"
        s << "IF(#{nice_reseller} IS NULL, ' ', #{nice_reseller}) as 'nice_reseller'"
        if options[:can_see_finances]
          s << SqlExport.replace_dec_round("(#{SqlExport.admin_reseller_rate_sql} * #{options[:exchange_rate]} ) ", options[:column_dem], 'reseller_rate')
          s << SqlExport.replace_dec_round("(#{SqlExport.admin_reseller_price_no_dids_sql} * #{options[:exchange_rate]} ) ", options[:column_dem], 'reseller_price')
        end
      end

      s << "IF(calls.card_id = 0, IF (calls.user_id = -1 AND calls.dst_device_id > 0, IF(LENGTH(CONCAT(#{dstuser}.first_name, #{dstuser}.last_name)) > 0, CONCAT(#{dstuser}.first_name, ' ', #{dstuser}.last_name), IFNULL(#{dstuser}.username, '')), IF(users.first_name = '' and users.last_name = '', users.username, (#{SqlExport.nice_user_sql('users', false)}))), CONCAT('Card#', IF(cards.number IS NULL, '', cards.number))) as 'user'"
      if options[:show_device_and_cid].to_i == 1
        s << "CONCAT(src_device.device_type, '/', src_device.extension, ' (', SUBSTRING_INDEX(SUBSTRING_INDEX(src_device.callerid, '<', -1), '>', 1), ')') AS nice_src_device"
        jn << "LEFT JOIN devices AS src_device ON (src_device.id = calls.src_device_id)"
      end
      if options[:can_see_finances]
        s << SqlExport.replace_dec_round("(IF(calls.user_rate IS NULL, 0, #{SqlExport.user_rate_sql}) * #{options[:exchange_rate]} )", options[:column_dem], 'user_rate')
        s << SqlExport.replace_dec_round("(IF(calls.user_price IS NULL, 0, #{SqlExport.user_price_no_dids_sql}) * #{options[:exchange_rate]} ) ", options[:column_dem], 'user_price')
      end
      s << "IF(dids.did IS NULL, '' , dids.did) AS 'did'"
      if options[:can_see_finances]
        s << SqlExport.replace_dec_round("(IF(calls.did_prov_price IS NULL, 0, calls.did_prov_price) * #{options[:exchange_rate]} ) ", options[:column_dem], 'did_prov_price')
        s << SqlExport.replace_dec_round("(IF(calls.did_inc_price IS NULL, 0, calls.did_inc_price) * #{options[:exchange_rate]} ) ", options[:column_dem], 'did_inc_price')
        s << SqlExport.replace_dec_round("(IF(calls.did_price IS NULL, 0 , calls.did_price) * #{options[:exchange_rate]} ) ", options[:column_dem], 'did_price')
      end

      if options[:cdr_template_id].present? || options[:automatic_cdr_export].present?
        s << SqlExport.column_escape_null('calls.id', 'id')
        s << SqlExport.column_escape_null('calls.src', 'src')
        s << SqlExport.column_escape_null('calls.dst', 'dst_original')
        s << SqlExport.column_escape_null('calls.duration', 'duration')
        s << SqlExport.column_escape_null('calls.billsec', 'billsec')
        s << SqlExport.column_escape_null('calls.disposition', 'disposition')
        s << SqlExport.column_escape_null('calls.accountcode', 'accountcode')
        s << SqlExport.column_escape_null('calls.uniqueid', 'uniqueid')
        s << SqlExport.column_escape_null('calls.dst_device_id', 'dst_device_id')
        s << SqlExport.column_escape_null('calls.provider_id', 'provider_id')
        s << SqlExport.column_escape_null('calls.provider_billsec', 'provider_billsec')
        s << SqlExport.column_escape_null('calls.user_id', 'user_id')
        s << SqlExport.column_escape_null('calls.reseller_id', 'reseller_id')
        s << SqlExport.column_escape_null('calls.reseller_billsec', 'reseller_billsec')
        s << SqlExport.column_escape_null('calls.card_id', 'card_id')
        s << SqlExport.column_escape_null('calls.hangupcause', 'hangupcause')
        s << SqlExport.column_escape_null('calls.did_provider_id', 'did_provider_id')
        s << SqlExport.column_escape_null('calls.originator_ip', 'originator_ip')
        s << SqlExport.column_escape_null('calls.terminator_ip', 'terminator_ip')
        s << SqlExport.column_escape_null('calls.real_duration', 'real_duration')
        s << SqlExport.column_escape_null('calls.real_billsec', 'real_billsec')
        s << SqlExport.column_escape_null('calls.did_billsec', 'did_billsec')
        s << SqlExport.column_escape_null('calls.dst_user_id', 'dst_user_id')
        s << SqlExport.column_escape_null('calls.partner_id', 'partner_id')
        s << SqlExport.column_escape_null('calls.partner_price', 'partner_price')
        s << SqlExport.column_escape_null('calls.partner_rate', 'partner_rate')
        s << SqlExport.column_escape_null('calls.partner_billsec', 'partner_billsec')
      end

    end
    if options[:current_user].show_billing_info == 1 and options[:can_see_finances]
      if options[:current_user].usertype == 'reseller'
        if User.current.own_providers.to_i == 0
          s << SqlExport.replace_dec_round("(#{SqlExport.reseller_rate_sql} * #{options[:exchange_rate]} ) ", options[:column_dem], 'self_cost_rate')
          s << SqlExport.replace_dec_round("(#{SqlExport.reseller_price_no_dids_sql} * #{options[:exchange_rate]} ) ", options[:column_dem], 'self_cost_price')
        end
        if options[:current_user].reseller_allow_providers_tariff?
          s << 'providers.id AS provider_id' if options[:provider]
          provider_name_cnd = "IF(providers.common_use = 1, CONCAT('#{_('Provider')} ', providers.id), providers.name)"
          s << SqlExport.column_escape_null("IF(providers.user_id = 0 AND providers.common_use = 0, 'admin', #{provider_name_cnd})", 'provider_name')
          s << SqlExport.replace_dec_round("(IF(calls.provider_rate IS NULL, 0, #{SqlExport.reseller_provider_rate_sql}) * #{options[:exchange_rate]} )", options[:column_dem], 'provider_rate')
          s << SqlExport.replace_dec_round("(IF(calls.provider_price IS NULL, 0, #{SqlExport.reseller_provider_price_sql}) * #{options[:exchange_rate]} ) ", options[:column_dem], 'provider_price')
        end
        s << "IF(calls.card_id = 0, IF (calls.user_id = -1 AND calls.dst_device_id > 0, IF(LENGTH(CONCAT(#{dstuser}.first_name, #{dstuser}.last_name)) > 0, CONCAT(#{dstuser}.first_name, ' ', #{dstuser}.last_name), IFNULL(#{dstuser}.username, '')), IF(users.first_name = '' and users.last_name = '', users.username, (#{SqlExport.nice_user_sql('users', false)}))), CONCAT('Card#', IF(cards.number IS NULL, '', cards.number))) as 'user'"
        if options[:show_device_and_cid].to_i == 1
          s << "CONCAT(src_device.device_type, '/', src_device.extension, ' (', SUBSTRING_INDEX(SUBSTRING_INDEX(src_device.callerid, '<', -1), '>', 1), ')') AS nice_src_device"
          jn << "LEFT JOIN devices AS src_device ON (src_device.id = calls.src_device_id)"
        end
        s << SqlExport.replace_dec_round("(#{SqlExport.user_rate_sql} * #{options[:exchange_rate]} ) ", options[:column_dem], 'user_rate')
        s << SqlExport.replace_dec_round("(IF(#{SqlExport.user_price_no_dids_sql} != 0 , (#{SqlExport.user_price_no_dids_sql}), 0) * #{options[:exchange_rate]} ) ", options[:column_dem], 'user_price')
        s << "IF(dids.did IS NULL , '' , dids.did) AS 'did'"
        s << SqlExport.replace_dec_round("(IF(calls.did_inc_price IS NULL OR users.owner_id = #{options[:current_user].id}, calls.did_inc_price, 0) * #{options[:exchange_rate]} ) ", options[:column_dem], 'did_inc_price')
        s << SqlExport.replace_dec_round("(IF(calls.did_price IS NULL OR users.owner_id != #{options[:current_user].id}, calls.did_price, 0) * #{options[:exchange_rate]} ) ", options[:column_dem], 'did_price')
      elsif options[:current_user].usertype == 'user'
        if options[:show_device_and_cid].to_i == 1
          s << "CONCAT(src_device.device_type, '/', src_device.extension, ' (', SUBSTRING_INDEX(SUBSTRING_INDEX(src_device.callerid, '<', -1), '>', 1), ')') AS nice_src_device"
          jn << "LEFT JOIN devices AS src_device ON (src_device.id = calls.src_device_id)"
        end
        s << SqlExport.replace_dec_round("((IF(calls.user_id = #{options[:current_user].id},#{SqlExport.user_price_sql},calls.did_price)) * #{options[:exchange_rate]} ) ", options[:column_dem], "user_price")
      end
    end

    if options[:current_user].usertype == "admin" or options[:current_user].usertype == "accountant"
      if options[:can_see_finances]
        s << SqlExport.replace_dec_round("((#{SqlExport.admin_profit_sql} + calls.did_price + calls.did_prov_price) * #{options[:exchange_rate]})", options[:column_dem], 'profit')
      end
    elsif options[:current_user].usertype == 'reseller'
      if options[:can_see_finances]
        s << SqlExport.replace_dec_round("(#{SqlExport.reseller_profit_no_dids_sql(options[:current_user])} * #{options[:exchange_rate]})", options[:column_dem], 'profit')
      end
    end

    jn << "LEFT JOIN destinations ON (destinations.prefix = IF(calls.prefix IS NULL, '', calls.prefix))" if options[:s_country].blank?
    jn << 'LEFT JOIN directions ON (directions.code = destinations.direction_code)'

    filename = "Last_calls-#{options[:current_user].id.to_s.gsub(" ", "_")}-#{options[:from].gsub(" ", "_").gsub(":", "_")}-#{options[:till].gsub(" ", "_").gsub(":", "_")}-#{DateTime.now.strftime('%Q').to_i}"
    sql = "SELECT * "
    if options[:pdf].to_i == 0 && options[:test] != 1 && options[:cdr_template_id].blank?
      sql += " INTO OUTFILE '/tmp/#{filename}.csv'
            FIELDS TERMINATED BY '#{options[:collumn_separator]}'
            ESCAPED BY '#{"\\\\"}'
        LINES TERMINATED BY '#{"\\n"}' "
    end
    #Call.last_calls_parse_params might return "LEFT JOIN destinations ..."
    #if condition below is met, in that case we should not join destinations again
    #it is very important to join tables in this paricular order DO NOT CHANGE IT

    order_by = options[:order] || 'calldate'

    sql += " FROM ((SELECT #{s.join(', ')}
             FROM calls "
    sql += jn.join(' ')
    sql += "WHERE #{ ActiveRecord::Base.sanitize_sql_array([cond.join(' AND '), *var])} ORDER BY #{order_by.gsub('nice_user', 'user')} )) AS C"

    test_content = ""
    if options[:cdr_template_id].present?
      BackgroundTask.cdr_export_template(
          {
              template_id: options[:cdr_template_id], user_id: options[:current_user].id,
              sql: sql, from: options[:from], till: options[:till]
          }
      )
      return false
    elsif options[:test].to_i == 1
      mysql_res = ActiveRecord::Base.connection.select_all(sql)
      test_content = mysql_res.to_a.to_json
    else
      if options[:pdf].to_i == 1
        filename = Call.find_by_sql(sql)
      else
        # Export MySQL query into outfile without headers
        ActiveRecord::Base.connection.execute(sql)

        # Append headers to first line of .csv file
        one_row =  "SELECT #{s.join(', ')} FROM calls #{jn.join(' ')} LIMIT 1"
        columns = ActiveRecord::Base.connection.select_all(one_row).columns
        headers = self.last_calls_csv_headers
        headers = columns.map { |name| "#{headers[name] || name}" }

        filename = load_file_through_database(filename) if Confline.get_value('Load_CSV_From_Remote_Mysql').to_i == 1

        file_path_old = "/tmp/#{filename}.csv"
        filename = filename << '_2'
        file_path_new = "/tmp/#{filename}.csv"

        File.open(file_path_new, 'w') do |fo|
          fo.puts "#{headers.join(options[:collumn_separator])}\n"
          File.foreach(file_path_old) do |li|
            fo.puts li
          end
        end
      end
    end
    return filename, test_content
  end

  def self.last_calls_csv_partner(options)
    show_did_user = Confline.get_value("Show_DID_User_in_Last_Calls", 0).to_i
    dstuser = show_did_user.to_i == 1 ? 'diduser' : 'dstuser'
    is_test = options[:test].to_i == 1
    is_pdf = options[:pdf].to_i == 1
    current_user_id = options[:current_user].try(:id)

    cond, var, jn = Call.last_calls_parse_params(options)
    s =[]
    format = Confline.get_value('Date_format', current_user_id).gsub('M', 'i')
    csv_full_src = true if options[:show_full_src].to_i == 1
    #calldate2 - because something overwites calldate when changing date format
    time_offset = options[:current_user].time_offset
    s << SqlExport.column_escape_null(SqlExport.nice_date('calls.calldate', {format: format, offset: time_offset}), 'calldate2')
    unless csv_full_src
      s << SqlExport.column_escape_null('calls.src', 'src')
    end
    if csv_full_src or is_pdf
      s << SqlExport.column_escape_null("calls.clid", "clid")
    end
    s << SqlExport.column_escape_null('calls.localized_dst', 'dst')
    s << Call.nice_billsec_sql
    s << SqlExport.column_escape_null("CONCAT(#{SqlExport.column_escape_null("calls.disposition")}, '(', #{SqlExport.column_escape_null("calls.hangupcause")}, ')')", 'dispod')
    s << SqlExport.column_escape_null('calls.server_id', 'server_id')
    s << SqlExport.replace_dec_round("(IF(calls.partner_rate IS NULL, 0, calls.partner_rate) * #{options[:exchange_rate]} )", options[:column_dem], 'partner_rate')
    s << SqlExport.replace_dec_round("(IF(calls.partner_price IS NULL, 0, calls.partner_price) * #{options[:exchange_rate]} ) ", options[:column_dem], 'partner_price')
    nice_reseller = "IF(resellers.id != 0,IF(LENGTH(resellers.first_name+resellers.last_name) > 0, CONCAT(resellers.first_name, ' ',resellers.last_name ), resellers.username), ' ')"
    s << "IF(#{nice_reseller} IS NULL, ' ', #{nice_reseller}) as 'nice_reseller'"
    s << SqlExport.replace_dec_round("(#{SqlExport.admin_reseller_rate_sql} * #{options[:exchange_rate]} ) ", options[:column_dem], 'reseller_rate')
    s << SqlExport.replace_dec_round("(#{SqlExport.admin_reseller_price_no_dids_sql} * #{options[:exchange_rate]} ) ", options[:column_dem], 'reseller_price')
    s << "IF(calls.card_id = 0, IF (calls.user_id = -1 AND calls.dst_device_id > 0, IF(LENGTH(CONCAT(#{dstuser}.first_name, #{dstuser}.last_name)) > 0, CONCAT(#{dstuser}.first_name, ' ', #{dstuser}.last_name), IFNULL(#{dstuser}.username, '')), IF(users.first_name = '' and users.last_name = '', users.username, (#{SqlExport.nice_user_sql('users', false)}))), CONCAT('Card#', IF(cards.number IS NULL, '', cards.number))) as 'user'"
    if options[:show_device_and_cid].to_i == 1
      s << "CONCAT(src_device.device_type, '/', src_device.extension, ' (', SUBSTRING_INDEX(SUBSTRING_INDEX(src_device.callerid, '<', -1), '>', 1), ')') AS nice_src_device"
      jn << "LEFT JOIN devices AS src_device ON (src_device.id = calls.src_device_id)"
    end
    s << SqlExport.replace_dec_round("(IF(calls.user_rate IS NULL, 0, #{SqlExport.user_rate_sql}) * #{options[:exchange_rate]} )", options[:column_dem], 'user_rate')
    s << SqlExport.replace_dec_round("(IF(calls.user_price IS NULL, 0, #{SqlExport.user_price_no_dids_sql}) * #{options[:exchange_rate]} ) ", options[:column_dem], 'user_price')
    s << SqlExport.replace_dec_round("(#{SqlExport.reseller_profit_no_dids_sql(options[:current_user])} * #{options[:exchange_rate]})", options[:column_dem], 'profit')


    filename = "Last_calls-#{current_user_id.to_s.gsub(" ", "_")}-#{options[:from].gsub(" ", "_").gsub(":", "_")}-#{options[:till].gsub(" ", "_").gsub(":", "_")}-#{DateTime.now.strftime('%Q').to_i}"
    sql = "SELECT * "


    if !is_pdf && !is_test && options[:cdr_template_id].blank?
      sql += " INTO OUTFILE '/tmp/#{filename}.csv'
            FIELDS TERMINATED BY '#{options[:collumn_separator]}'
            ESCAPED BY '#{"\\\\"}'
        LINES TERMINATED BY '#{"\\n"}' "
    end
    #Call.last_calls_parse_params might return "LEFT JOIN destinations ..."
    #if condition below is met, in that case we should not join destinations again
    #it is very important to join tables in this paricular order DO NOT CHANGE IT

    # setting headers
    jn << "LEFT JOIN destinations ON destinations.prefix = IFNULL(calls.prefix, '') " if options[:s_country].blank?
    jn << 'LEFT JOIN directions ON directions.code = (destinations.direction_code)'

    string_condition = s.join(', ')
    joins = jn.join(' ')
    one_row =  "SELECT #{string_condition} FROM calls #{joins} LIMIT 1"
    columns = ActiveRecord::Base.connection.select_all(one_row).columns

    headers = self.last_calls_csv_partner_headers
    headers = columns.map { |name| "'#{headers[name] || name}' AS  '#{name}'" }
    header_sql = 'SELECT ' + headers.join(', ') + ' UNION ALL ' if options[:csv]

    sql += " FROM (#{header_sql.to_s} (SELECT #{string_condition}
             FROM calls "
    sql += joins
    sql += "WHERE #{ ActiveRecord::Base.sanitize_sql_array([cond.join(' AND '), *var])} ORDER BY #{options[:order].gsub('nice_user', 'user')} )) AS C"

    test_content = ""

    if options[:cdr_template_id].present?
      BackgroundTask.cdr_export_template(
          {
              template_id: options[:cdr_template_id], user_id: options[:current_user].id,
              sql: sql, from: options[:from], till: options[:till]
          }
      )
      return false
    elsif is_test
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

  def Call.calls_for_load_stats(options = {})
    cond = ["(calldate BETWEEN '#{options[:a1]}' AND '#{options[:a2]}')"]
    is_user_reseller = !!options[:current_user].try(:is_reseller?)

    if (options[:s_server].to_i != -1) && !is_user_reseller
      cond << "(server_id = #{options[:s_server]})"
    end

    if options[:s_user].to_i != -1
      cond << "(user_id = #{options[:s_user]})"

      if options[:s_device].to_i != -1
        cond << "(src_device_id = #{options[:s_device]})"
      end
    end

    case options[:s_direction].to_s
      when 'outgoing'
        cond << '(did_id = 0)'
      when 'incoming'
        cond << "(did_id > 0 AND callertype = 'Local')"
      when 'mixed'
        cond << "(did_id > 0 AND callertype = 'Outside')"
    end

    if options[:s_provider].to_i != -1
      cond << "(provider_id = #{options[:s_provider]})"
    end

    if !options[:s_did].blank? && !is_user_reseller
      cond << "(dst = '#{options[:s_did]}')"
    end

    if is_user_reseller
      cond << "(calls.reseller_id = #{options[:current_user].id} OR calls.user_id = #{options[:current_user].id} OR calls.dst_user_id = #{options[:current_user].id})"
    end

    all_calls = ActiveRecord::Base.connection.select_all("
      SELECT DATE_FORMAT((calldate + INTERVAL #{options[:current_user].time_offset} SECOND), '%H:%i') AS call_minute, COUNT(id) AS calls
      FROM `calls`
      WHERE #{cond.join(' AND ')}
      GROUP BY call_minute ORDER BY call_minute;
    ")

    answered_calls = ActiveRecord::Base.connection.select_all("
      SELECT TIME_TO_SEC(DATE_FORMAT((calldate + INTERVAL #{options[:current_user].time_offset} SECOND), '%H:%i:00')) DIV 60 AS time_index_from,
             ((duration DIV 60) + IF((duration % 60) > 0, 1, 0)) AS minute_duration,
             COUNT(id) AS calls_count
      FROM calls
      WHERE #{cond.join(' AND ')} AND disposition = 'ANSWERED'
      GROUP BY time_index_from, minute_duration
      ORDER BY time_index_from;
    ")

    highest_duration = where("#{cond.join(' AND ')}").where(disposition: 'ANSWERED').maximum(:duration)

    return all_calls, answered_calls, highest_duration
  end

  def Call.calls_for_providers_stats(options = {})
    cond = options[:reseller?] ? "AND (calls.reseller_id = #{options[:user_id]} OR calls.user_id = #{options[:user_id]} ) " : ''
    cond << "AND calls.prefix LIKE #{ActiveRecord::Base::sanitize(options[:s_prefix].to_s)} " if options[:s_prefix].present?

    sql = "
    SELECT DATE_FORMAT(calldate, '%Y-%m-%d') AS date,
           SUM(IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec))) AS billsec,
           COUNT(id) AS calls_count
    FROM calls
    WHERE (calldate BETWEEN '#{options[:date_from]}' AND '#{options[:date_till]}')
          AND ((provider_id = #{options[:prov_id]} AND callertype = 'Local') OR (provider_id = #{options[:prov_id]} AND callertype = 'Outside'))
          AND disposition = 'ANSWERED' #{cond}
    GROUP BY date
    ORDER BY date;
    "
    answered_calls = ActiveRecord::Base.connection.select_all(sql)

    sql = "
    SELECT DATE_FORMAT(calldate, '%Y-%m-%d') AS date,
           SUM(IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec))) AS billsec,
           COUNT(id) AS all_calls_count
    FROM calls
    WHERE (calldate BETWEEN '#{options[:date_from]}' AND '#{options[:date_till]}')
          AND ((provider_id = #{options[:prov_id]} AND callertype = 'Local') OR (provider_id = #{options[:prov_id]} AND callertype = 'Outside'))
          #{cond}
    GROUP BY date
    ORDER BY date;
    "
    all_calls = ActiveRecord::Base.connection.select_all(sql)

    s = "SELECT DATE_FORMAT(calldate, '%Y-%m-%d') AS 'date', "
    if options[:admin?]
      s << "SUM(provider_price) AS 'selfcost_price', "
      s << "SUM(IF(reseller_id > 0, reseller_price, user_price)) AS 'sel_price'"
    else
      s << "SUM(IF(providers.common_use = 1, reseller_price,provider_price)) AS 'selfcost_price', "
      s << "SUM(user_price) AS 'sel_price'"
    end

    sql = "
    #{s}
    FROM calls
    LEFT JOIN providers ON (providers.id = calls.provider_id)
    WHERE ((calls.provider_id = #{options[:prov_id]} AND calls.callertype = 'Local') OR (calls.did_provider_id = #{options[:prov_id]} AND calls.callertype = 'Outside'))
          AND disposition = 'ANSWERED'
          AND calldate BETWEEN '#{options[:date_from]}'
          AND '#{options[:date_till]}'
          #{cond}
    GROUP BY date
    ORDER BY date;
    "
    costs = ActiveRecord::Base.connection.select_all(sql)

    merged_results = []
    all_calls.each_with_index do |val, index|
      if val.present? && answered_calls[index].present? && costs[index].present?
        merged_results.push(val.merge(answered_calls[index].merge(costs[index])))
      end
    end

    merged_results
  end

  def self.country_stats_download_table_csv(params, user)
    require 'csv'

    filename = "Country_stats-#{params[:search_time][:from]}-#{params[:search_time][:till]}-#{Time.now.to_i}".gsub(/( |:)/, '_')
    sep, dec = user.csv_params
    table_data = JSON.parse(params[:table_content])

    CSV.open('/tmp/' + filename + '.csv', 'w', {col_sep: sep, quote_char: "\""}) do |csv|
      csv << [_('Destination_Group'), _('Calls'), _('Time'), _('Price'), _('User_price'), _('Profit')]

      table_data.each_with_index do |line|
        csv << [
            line[_('Destination_Group')],
            line[_('Calls')].to_i,
            nice_time(line[_('Time')].to_i),
            line[_('Price')].gsub(/(,|;)/, '.').to_f.to_s.gsub('.', dec),
            line[_('User_price')].gsub(/(,|;)/, '.').to_f.to_s.gsub('.', dec),
            line[_('Profit')].gsub(/(,|;)/, '.').to_f.to_s.gsub('.', dec)
        ]
      end
    end

    return filename
  end

  def Call.cardgroup_aggregate(options={})
    group_by = []
    options[:destination_grouping] == 1 ? group_by << "destinations.direction_code, destinations.prefix" : group_by << "destinations.direction_code"
    extrate = options[:exrate]
    cardgroup_any = options[:cardgroup] == "any"
    group_by << "cards.cardgroup_id" if cardgroup_any

    cond = ["calldate BETWEEN ? AND ?"]
    var = [options[:from], options[:till]]
    if  options[:prefix].to_s != ""
      cond << "calls.prefix LIKE ?"
      var << options[:prefix].gsub(/[^0-9]/, "").to_s + "%"
    end

    if cardgroup_any
      cond << "cards.cardgroup_id IN (SELECT id FROM cardgroups WHERE owner_id = ?)"
      var << options[:user_id]
    else
      cond << "cards.cardgroup_id = ?"
      var << options[:cardgroup].to_i
    end

    s = []

    if options[:csv].to_i == 0
      s << "IF(calls.prefix = '', '#{_('Calls_To_Dids')}', calls.prefix ) AS prefix, directions.name as 'dir_name', destinations.direction_code AS 'code', destinations.name AS 'dest_name'"
    else
      if options[:destination_grouping].to_i == 1
        s << SqlExport.column_escape_null("CONCAT(directions.name, ' ', destinations.name, ' (',  calls.prefix, ') ' )", "direct_name", "#{_('Calls_To_Dids')}")
      else
        s << SqlExport.column_escape_null("CONCAT(directions.name, ' (',  calls.prefix, ') ')", "direct_name", "#{_('Calls_To_Dids')}")
      end
    end
    s << "cardgroups.name AS  'cardgroup_name'"
    s << SqlExport.column_escape_null("SUM(IF(calls.disposition = 'ANSWERED',  IF(calls.hangupcause = 16, calls.billsec, 0), 0))", 'duration', 0)
    s << SqlExport.column_escape_null("SUM(IF(calls.disposition = 'ANSWERED', IF(calls.hangupcause = 16, 1, 0),0))", 'answered_calls', 0)
    s << SqlExport.column_escape_null("COUNT(*)", 'total_calls', 0)
    s << SqlExport.column_escape_null("SUM(IF(calls.disposition = 'ANSWERED', IF(calls.hangupcause = 16, 1, 0),0))/COUNT(*)*100", 'asr', 0)
    s << SqlExport.column_escape_null("SUM(IF(calls.disposition = 'ANSWERED',  IF(calls.hangupcause = 16, calls.billsec, 0), 0))/SUM(IF(calls.disposition = 'ANSWERED', IF(calls.hangupcause = 16, 1, 0),0))", 'acd', 0)
    s << SqlExport.column_escape_null("SUM(calls.user_price) * #{extrate}", "user_price", 0)
    # If user is simple not RSPRO reseller, provider price must be reseller price not provider price
    price = options[:simple_reseller] ? 'calls.reseller_price' : 'calls.provider_price'
    s << SqlExport.column_escape_null("SUM(#{price}) * #{extrate}", "provider_price", 0)
    s << SqlExport.column_escape_null("(SUM(calls.user_price) - SUM(#{price})) * #{extrate}", 'profit', 0)
    s << SqlExport.column_escape_null("IF((SUM(calls.user_price) != 0 OR SUM(#{price}) != 0),(((SUM(calls.user_price) - SUM(#{price})) / SUM(calls.user_price)) * 100),0)", 'margin', 0)
    s << SqlExport.column_escape_null("IF((SUM(calls.user_price) != 0 OR SUM(#{price}) != 0),(((SUM(calls.user_price) / SUM(#{price})) * 100 ) - 100), 0)", 'markup', 0)
    order = !options[:order].to_s.blank? ? 'ORDER BY ' + options[:order] : ''
    group = group_by.size > 0 ? 'GROUP BY ' +group_by.join(", ") : ''

    jn = ["LEFT JOIN devices ON (calls.src_device_id = devices.id)", "LEFT JOIN users ON (users.id = devices.user_id)", "JOIN cards ON (cards.id = calls.card_id)", "LEFT JOIN cardgroups ON (cardgroups.id = cards.cardgroup_id)", "LEFT JOIN destinations ON (destinations.prefix = calls.prefix)", "LEFT JOIN directions ON (directions.code = destinations.direction_code)"]

    if options[:csv].to_i == 1
      filename = "Cardgroups_aggregate-#{options[:from].gsub(" ", "_").gsub(":", "_")}-#{options[:till].gsub(" ", "_").gsub(":", "_")}-#{Time.now().to_i}"
      sql = "SELECT * "
      if options[:test].to_i != 1
        sql += " INTO OUTFILE '/tmp/#{filename}.csv'
            FIELDS TERMINATED BY '#{options[:collumn_separator]}' OPTIONALLY ENCLOSED BY '#{''}'
            ESCAPED BY '#{"\\\\"}'
        LINES TERMINATED BY '#{"\\n"}' "
      end
      sql += " FROM (SELECT #{s.join(', ')} FROM calls #{jn.join(' ')}  WHERE #{ ActiveRecord::Base.sanitize_sql_array([cond.join(' AND '), *var])} #{group}  #{order}  ) as C"

      data = ''
      if options[:test].to_i == 1
        mysql_res = ActiveRecord::Base.connection.select_all(sql)
        MorLog.my_debug(sql)
        MorLog.my_debug("------------------------------------------------------------------------")
        MorLog.my_debug(mysql_res.to_yaml)
        data << mysql_res.to_json
      else
        mysql_res = ActiveRecord::Base.connection.execute(sql)
      end
      return filename, data
    else
      sql = "SELECT #{s.join(', ')} FROM calls #{jn.join(' ')}  WHERE #{ ActiveRecord::Base.sanitize_sql_array([cond.join(' AND '), *var])}  #{group}  #{order} "
      mysql_res = Call.find_by_sql(sql)
      return mysql_res
    end
  end

  def Call.analize_cdr_import(name, options)
    CsvImportDb.log_swap('analyze')
    MorLog.my_debug("CSV analyze_file #{name}", 1)
    arr = {}
    current_user = User.current.id
    arr[:calls_in_db] = Call.where({:reseller_id => current_user}).size.to_i
    arr[:clis_in_db] = Callerid.joins('JOIN devices ON (devices.id = callerids.device_id) JOIN users ON (devices.user_id = users.id)').where("users.owner_id = #{current_user}").size.to_i

    if options[:step] and options[:step] == 8
      arr[:step] = 8
      ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 0, nice_error = 0 where id > 0")
    else
      ActiveRecord::Base.connection.execute("UPDATE #{name} SET not_found_in_db = 0, f_error = 0, nice_error = 0 where id > 0")
    end

    if options[:imp_clid] and options[:imp_clid] >= 0
      #set flag on not found and count them
      str = if options[:create_callerid].to_i.zero?
              'f_error = 1, nice_error = 8'
            else
              'not_found_in_db = 1'
            end
      found_clis = ActiveRecord::Base.connection.select_all("SELECT col_#{options[:imp_clid]} FROM #{name}  JOIN callerids ON (callerids.cli = replace(col_#{options[:imp_clid]}, '\\r', ''))
                                                                                                            JOIN devices ON devices.id = callerids.device_id
                                                                                                            JOIN users ON users.id = devices.user_id
                                                                                                            JOIN users owners ON users.owner_id = owners.id
                                                                                                            WHERE users.owner_id = #{current_user} OR (#{current_user} = 0 AND owners.usertype = 'reseller' AND owners.own_providers = 0)")
      idsclis = ["'not_found'"]
      found_clis.each { |id| idsclis << id["col_#{options[:imp_clid]}"].to_s }
      ActiveRecord::Base.connection.execute("UPDATE #{name} SET #{str} where col_#{options[:imp_clid]}  not in (#{idsclis.compact.join(',')})")
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
', '') REGEXP '^[0-9]+$' = 0")
      if User.current.is_admin?
        ActiveRecord::Base.connection.execute("UPDATE #{name}
                                             JOIN callerids ON (callerids.cli = col_#{options[:imp_clid]})
                                             JOIN devices ON (callerids.device_id = devices.id)
                                             JOIN users ON (devices.user_id = users.id)
                                             JOIN users AS owners ON (users.owner_id = owners.id)
                                             SET f_error = 1, nice_error=7, #{name}.owner_id=owners.id
                                             WHERE owners.own_providers = 1")
      end
    end
    cond = options[:import_user] ? " AND user_id = #{options[:import_user]} " : '' #" calls.cli "
    ActiveRecord::Base.connection.execute("UPDATE #{name} JOIN calls ON (calls.calldate = timestamp(replace(col_#{options[:imp_calldate]}, '\\r', '')) ) SET f_error = 1, nice_error = 2 WHERE dst = replace(col_#{options[:imp_dst]}, '\\r', '') and billsec = replace(col_#{options[:imp_billsec]}, '\\r', '')  #{cond} and f_error = 0")

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
    arr[:file_lines] = options[:file_lines]
    return arr
  end

  def Call.insert_cdrs_from_csv(name, options)
    provider = Provider.includes(:tariff).where("providers.id = #{options[:import_provider]}").first if options[:imp_provider_id].to_i < 0

    if options[:import_user]
      res = ActiveRecord::Base.connection.select_all("SELECT *, devices.id as dev_id FROM #{name} JOIN devices ON (devices.id = #{options[:import_device]}) WHERE f_error = 0 and do_not_import = 0")
    else
      res = ActiveRecord::Base.connection.select_all("SELECT *, devices.id as dev_id FROM #{name} JOIN callerids ON (callerids.cli = replace(col_#{options[:imp_clid]}, '\\r', '')) JOIN devices ON (callerids.device_id = devices.id) WHERE f_error = 0 and do_not_import = 0")
    end

    imported_cdrs = 0
    for r in res
      billsec = r["col_#{options[:imp_billsec]}"].to_i
      call = Call.new(:billsec => billsec, :dst => CsvImportDb.clean_value(r["col_#{options[:imp_dst]}"].to_s).gsub(/[^0-9]/, ""), :calldate => r["col_#{options[:imp_calldate]}"], :card_id => 0)

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
        disposition = 'ANSWERED' if billsec > 0
        disposition = 'NO ANSWER' if billsec == 0
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

      #If Provider ID Should Be Imported FROM CSV
      if options[:imp_provider_id].to_i > -1
        call.provider_id =  CsvImportDb.clean_value(r["col_#{options[:imp_provider_id]}"]).gsub(/[^0-9]/, "")
      else
        call.provider_id = provider.id
      end

      call.localized_dst = call.dst

      user = User.find(call.user_id)

      call.reseller_id = user.owner_id
      call = call.count_cdr2call_details(call.provider.tariff_id , user, 0, true) if call.valid?

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

  def count_cdr2call_details(selfcost_tariff_id, user_id, user_test_tariff_id = 0, importing = false, include_reseller_users = false, rerating_type = 'admin_user')
    @prov_exchange_rate_cache ||= {}
    @tariffs_cache ||= {}

    if user_id.class == User
      user = user_id
      user_id = user.id
    else
      user = User.includes(:tariff).where("users.id = #{user_id}").first
    end

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
    calldatetime = self.calldate.strftime('%Y-%m-%d %H:%M:%S')

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

                                #V ticket #8547
      if loc_tariff_id.to_i > 0 #and user_test_tariff_id.to_i == 0
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
      temp_prefix = ""
      user_billsec = 0

      s_prefix = ""
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
        dst.length.times { |i| dst_array << dst[0, i+1] }
        if dst_array.size > 0
          sql =
              "SELECT prefix, ratedetails.rate,   ratedetails.increment_s, ratedetails.min_time, ratedetails.connection_fee "+
                  "FROM  rates JOIN ratedetails ON (ratedetails.rate_id = rates.id  AND (ratedetails.daytype = '#{daytype}' OR ratedetails.daytype = '' ) AND '#{time}' BETWEEN ratedetails.start_time AND ratedetails.end_time) " +
                  "WHERE prefix IN ('#{dst_array.join("', '")}') AND rates.tariff_id = #{selfcost_tariff_id} AND (rates.effective_from <= '#{calldatetime}' OR rates.effective_from IS NULL) ORDER BY LENGTH(prefix) DESC, rates.effective_from DESC LIMIT 1;"
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
        price, max_rate, user_exchange_rate, temp_prefix, user_billsec = self.count_call_rating_details_for_user(tariff, time, daytype, dst, user, calldatetime)
        MorLog.my_debug "USER: call_id: #{self.id}, user_price: #{price}, max_rate: #{max_rate}, exchange_rate: #{user_exchange_rate}, tmp_prefix: #{temp_prefix}, user_billsec: #{user_billsec}"

        #====================== data for RESELLER ==============

        if self.reseller_id.to_i > 0

          reseller = User.where(id: self.reseller_id.to_i).first
          tariff = @tariffs_cache["t_#{reseller.tariff_id.to_i}".to_sym] ||= Tariff.where(id: reseller.tariff_id.to_i).first if reseller

          common_use_provider =  Application.common_use_provider(self.provider_id)

          # In Case Common Use Provider present his Tariff should be used instead of reseller tariff
          tariff = Tariff.where(id: common_use_provider.tariff_id.to_i).first if common_use_provider.present?

          if reseller and tariff
            res_price, res_max_rate, res_exchange_rate, res_temp_prefix, res_billsec = self.count_call_rating_details_for_user(tariff, time, daytype, dst, reseller, calldatetime)
            MorLog.my_debug "RESELLER: call_id: #{self.id}, user_price: #{res_price}, max_rate: #{res_max_rate}, exchange_rate: #{res_exchange_rate}, tmp_prefix: #{res_temp_prefix}, user_billsec: #{res_billsec}"
          end
        end


      end # own_did == 0

      # ========= Calculation ===========

      if !include_reseller_users && user.is_reseller?
        if self.reseller_id.to_i > 0
          self.reseller_rate = res_max_rate / res_exchange_rate
          self.reseller_billsec = res_billsec
          self.reseller_price = 0
        end

        if self.disposition.to_s.upcase == 'ANSWERED'
          self.provider_price = s_price / prov_exchange_rate if importing
          self.user_price = price / user_exchange_rate

          if self.reseller_id.to_i > 0
            self.reseller_price = res_price / res_exchange_rate
          end
        end

        return self
      elsif own_did == 0
        #new
        if rerating_type != 'admin_reseller'
          self.user_rate = max_rate / user_exchange_rate
          self.user_billsec = user_billsec
          self.user_price = 0
        end
        if importing
          self.provider_rate = s_rate / prov_exchange_rate
          self.provider_billsec = s_billsec
          self.provider_price = 0
        end

        #call.dst = orig_dst
        self.localized_dst = dst

        if self.reseller_id.to_i > 0 && rerating_type != 'reseller_user'
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

        if self.disposition.to_s.upcase == 'ANSWERED'
          #        call.prov_price = s_price
          #        call.price = price

          #new
          self.provider_price = s_price / prov_exchange_rate if importing

          self.user_price = price / user_exchange_rate if rerating_type != 'admin_reseller'

          if self.reseller_id.to_i > 0 && rerating_type != 'reseller_user'
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
    end
    else
      MorLog.my_debug "#{Time.now.to_s(:db)}  SQL not found--------------------------------------------"
      MorLog.my_debug sql
    end
    self
  end


  def count_call_rating_details_for_user(tariff, time, daytype, dst, user, calldatetime = nil)
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

      dst_array = []
      dst.length.times { |i| dst_array << dst[0, i+1] }
      sql = "SELECT prefix,
                     ratedetails.rate,
                     ratedetails.increment_s,
                     ratedetails.min_time,
                     ratedetails.connection_fee as 'cf'
              FROM rates
              JOIN ratedetails ON (ratedetails.rate_id = rates.id
                                   AND (ratedetails.daytype =  '#{daytype}' OR ratedetails.daytype = '' )
                                   AND '#{time}' BETWEEN ratedetails.start_time AND ratedetails.end_time
                                  )
        WHERE prefix IN ('#{dst_array.join("', '")}')
                  AND rates.tariff_id = #{tariff.id}
                    AND (rates.effective_from <= '#{calldatetime}' OR rates.effective_from IS NULL)
              ORDER BY LENGTH(prefix) DESC, rates.effective_from DESC
              LIMIT 1;"


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

  def toggle_processed
    self.processed = processed == 0 ? 1 : 0
    save
  end

  def pcap_file_request
    "/usr/local/mor/mor_pcap '#{calldate.strftime('%Y-%m-%d %H:%M:%S')}' '#{dst}' "\
      "'#{src}' '#{originator_ip}' '#{terminator_ip}' '#{id}'"
  end

  def self.last_calls_raw_conditions(options={})
    cond = []

    is_user_blank = !options[:user]
    if options[:current_user].is_reseller? && is_user_blank
      user_ids = User.available_ids("users.owner_id = #{options[:current_user].id}")

      reseller_condition = " calls.reseller_id = #{options[:current_user].id} OR calls.user_id = #{options[:current_user].id} "
      reseller_condition << " OR calls.user_id IN (#{user_ids}) OR calls.dst_user_id IN (#{user_ids})" if user_ids.present?

      cond << "(#{reseller_condition})"
    end

    if options[:current_user].is_partner? && is_user_blank
      id = options[:current_user].id
      cond << "(calls.partner_id = #{id})"
    end

    if options[:current_user].try(:usertype) == 'accountant' && options[:current_user].try(:show_only_assigned_users) == 1
      resp_acc = User.where(id: options[:current_user].id).first
      resp_acc_users = resp_acc.responsible_accountant_users(include_owner_users: true).pluck(:id).join(', ')
      resp_acc_user_devices = resp_acc.responsible_accountant_user_devices(include_owner_users: true).pluck(:id).join(', ')

      resp_acc_users = '-2' if resp_acc_users.blank?
      resp_acc_user_devices = '-2' if resp_acc_user_devices.blank?

      cond << "(calls.user_id IN (#{resp_acc_users})
                OR calls.dst_user_id IN (#{resp_acc_users})
                OR calls.reseller_id IN (#{resp_acc_users})
                OR calls.src_device_id IN (#{resp_acc_user_devices})
                OR calls.dst_device_id IN (#{resp_acc_user_devices})
               )"
    end

    if options[:call_type] != "all"
      if ['answered', 'failed'].include?(options[:call_type].to_s)
        cond << Call.nice_answered_cond_sql if options[:call_type].to_s == 'answered'
        cond << Call.nice_failed_cond_sql if options[:call_type].to_s == 'failed'
      else
        cond << "calls.disposition = '#{options[:call_type]}'"
      end
    end

    hgc_option = options[:hgc]
    if hgc_option
      cond << "calls.hangupcause = '#{hgc_option.code}'"
    end

    destination_options = options[:destination]
    unless destination_options.blank?
      cond << "localized_dst like '#{destination_options}'"
    end

    if options[:s_reseller_did] != 'all' and !options[:s_reseller_did].blank?
      reseller_dids_ids = Did.available_ids("dids.reseller_id = #{options[:s_reseller_did]}")
      cond << "calls.did_id IN (#{reseller_dids_ids})" if reseller_dids_ids.present?
    end

    device_option = options[:device]
    if device_option.present?
      device_id = device_option.id
      cond << "(calls.dst_device_id = #{device_id} OR calls.src_device_id = #{device_id})"
    end

    if options[:user]
      current_user = options[:current_user]
      user_id = options[:user].id

      user_condition = "calls.user_id = #{user_id} OR calls.dst_user_id = #{user_id}"

      is_not_reseller = !current_user.is_reseller?
      if is_not_reseller
        cards_ids = Card.available_ids("cards.user_id = #{user_id}")

        user_condition << " OR calls.card_id IN (#{cards_ids}) " if cards_ids.present?
        if is_not_reseller && !current_user.is_user?
          devices_ids = Device.available_ids("devices.user_id = #{user_id}")

          user_condition << " OR calls.dst_device_id IN (#{devices_ids}) " if devices_ids.present?
        end
      end
      cond << "(#{user_condition})"
      cond << "calls.callertype = 'Outside'" if current_user.is_user? && current_user.stats_from_user_perspective == 1
    end

    search_did_pattern = options[:s_did_pattern].to_s.strip
    did_option = options[:did]
    if did_option
      cond << "calls.did_id = #{did_option.id}"
    elsif search_did_pattern.present?
      dids_ids = Did.available_ids("dids.did LIKE #{ActiveRecord::Base::sanitize(search_did_pattern)}")
      cond << "calls.did_id IN (#{dids_ids})" if dids_ids.present?
    end

    #find_calls_only_with_did
    if options[:only_did].to_i == 1
      cond << 'calls.did_id > 0'
    end

    if options[:provider] or options[:did_provider]
      prov_condition = ""
      prov_condition << "calls.provider_id = #{options[:provider].id}" if options[:provider]
      prov_condition << " and " if options[:provider] and options[:did_provider]
      prov_condition << "calls.did_provider_id = #{options[:did_provider].id}" if options[:did_provider]
      cond << prov_condition
    end

    reseller_option = options[:reseller]
    if reseller_option
      cond << "calls.reseller_id = #{reseller_option.id}"
    end

    if options[:source] and not options[:source].blank?
      cond << "(calls.src LIKE '#{options[:source]}' OR calls.clid LIKE '#{options[:source]}')"
    end

    search_card_number = options[:s_card_number].to_s.strip
    unless search_card_number.blank?
      cards_ids = Card.available_ids("cards.number LIKE '#{search_card_number}'")
      cond << "card_id IN (#{cards_ids})" if cards_ids.present?
    end

    serach_card_pin = options[:s_card_pin].to_s.strip
    unless serach_card_pin.blank?
      cards_ids = Card.available_ids("cards.pin LIKE '#{serach_card_pin}'")
      cond << "card_id IN (#{cards_ids})" if cards_ids.present?
    end

    search_card_id = options[:s_card_id].to_s.strip
    unless search_card_id.blank?
      cond << "calls.card_id LIKE '#{search_card_id}'"
    end

    return cond
  end

  def self.es_system_stats(show_assign_users, current_user)
    data = {total: 0, answered: 0, busy: 0, no_answer: 0, failed: 0}

    es_options = {show_assign_users: show_assign_users}

    if show_assign_users
      current_acc_id = current_user.id.to_i
      es_options[:users_array] = User.where(usertype: 'user', responsible_accountant_id: current_acc_id).pluck(:id)
      es_options[:resellers_array] = User.where(usertype: 'reseller', responsible_accountant_id: current_acc_id).pluck(:id)
    end

    es_calls_system_stats = Elasticsearch.safe_search_mor_calls(ElasticsearchQueries.calls_system_stats(es_options))
    return data if es_calls_system_stats.blank? || es_calls_system_stats['aggregations'].blank?

    data = {
        total: es_calls_system_stats['hits']['total'],
        answered: es_calls_system_stats['aggregations']['answered']['doc_count'],
        busy: es_calls_system_stats['aggregations']['busy']['doc_count'],
        no_answer: es_calls_system_stats['aggregations']['no_answer']['doc_count'],
    }
    data[:failed] = data[:total] - data[:answered] - data[:busy] - data[:no_answer]

    return data
  end

  private

  def Call.last_calls_parse_params(options={})
    jn = ['LEFT JOIN users ON (calls.user_id = users.id)',
          'LEFT JOIN users AS resellers ON (calls.reseller_id = resellers.id)',
          'LEFT JOIN dids ON (calls.did_id = dids.id)',
          'LEFT JOIN users AS diduser ON (dids.user_id = diduser.id)',
          'LEFT JOIN devices AS dstdevice ON (calls.dst_device_id = dstdevice.id)',
          'LEFT JOIN users AS dstuser ON (dstdevice.user_id = dstuser.id)',
          'LEFT JOIN cards ON (calls.card_id = cards.id)',
          SqlExport.left_join_reseler_providers_to_calls_sql
    ]
    cond = ["(calls.calldate BETWEEN ? AND ?)"]
    var = [options[:from], options[:till]]
    did = options[:did]

    if options[:current_user].try(:usertype) == 'accountant' && options[:current_user].try(:show_only_assigned_users) == 1
      resp_acc = User.where(id: options[:current_user].id).first
      resp_acc_users = resp_acc.responsible_accountant_users(include_owner_users: true).pluck(:id).join(', ')
      resp_acc_user_devices = resp_acc.responsible_accountant_user_devices(include_owner_users: true).pluck(:id).join(', ')

      resp_acc_users = '-1' if resp_acc_users.blank?
      resp_acc_user_devices = '-1' if resp_acc_user_devices.blank?

      cond << "(calls.user_id IN (#{resp_acc_users})
                OR calls.dst_user_id IN (#{resp_acc_users})
                OR calls.reseller_id IN (#{resp_acc_users})
                OR calls.src_device_id IN (#{resp_acc_user_devices})
                OR calls.dst_device_id IN (#{resp_acc_user_devices})
               )"
    end

    if options[:current_user].usertype == "reseller" && !options[:user]
      jn << "LEFT JOIN users AS dst_users ON (dst_users.id = calls.dst_user_id)"
      cond << "(calls.reseller_id = ? OR calls.user_id = ? OR users.owner_id = ? OR dst_users.owner_id = ?)"
      var += ([options[:current_user].id] * 4)
    end

    if options[:current_user].usertype == 'partner' && !options[:user]
      id = options[:current_user].id
      cond << "(calls.partner_id = #{id})"
    end

    if options[:call_type] != "all"
      if ['answered', 'failed'].include?(options[:call_type].to_s)
        cond << Call.nice_answered_cond_sql if options[:call_type].to_s == 'answered'
        cond << Call.nice_failed_cond_sql if options[:call_type].to_s == 'failed'
      else
        cond << "calls.disposition = ?"
        var << options[:call_type]
      end
    end

    if options[:hgc]
      cond << "calls.hangupcause = ?"
      var << options[:hgc].code
    end

    unless options[:destination].blank?
      cond << "localized_dst like ?"
      var << "#{options[:destination]}"
    end

    if options[:s_reseller_did] != 'all' and !options[:s_reseller_did].blank?
      cond << "dids.reseller_id = ?"
      var << options[:s_reseller_did]
    end

    if options[:s_country] and !options[:s_country].blank?
      cond << "destinations.direction_code = ? "; var << options[:s_country]
      jn << 'LEFT JOIN destinations ON (calls.prefix = destinations.prefix)'
    end

    if options[:device].present? && options[:device].id
      device_id = options[:device].id
      cond << "(calls.dst_device_id = ? OR calls.src_device_id = ?)"
      var += [device_id, device_id]
    end

    if options[:user]
      current_user = options[:current_user]
      user_id = options[:user].id
      if current_user.is_reseller?
        cond << "(calls.user_id = ? OR calls.dst_user_id = ?)"
        var += [user_id, user_id]
      elsif current_user.is_user?
        cond << "(calls.user_id = ? OR calls.dst_user_id = ? OR cards.user_id = ?)"
        cond << "(calls.callertype = 'Outside')" if current_user.stats_from_user_perspective == 1
        var += ([user_id] * 3)
      else
        jn << "LEFT JOIN devices AS dst_device ON (dst_device.id = calls.dst_device_id)"
        cond << "(calls.user_id = ? OR dst_device.user_id = ? OR calls.dst_user_id = ? OR cards.user_id = ?)"
        var += ([user_id] * 4)
      end
    end

    if did
      cond << "calls.did_id = ?"
      var << did.id
    elsif !options[:s_did_pattern].to_s.strip.blank?
      cond << "dids.did LIKE ?"
      var << options[:s_did_pattern].to_s.strip
    end

    #find_calls_only_with_did
    if options[:only_did] and options[:only_did].to_i == 1
      cond<<"calls.did_id > ?"
      var << '0'
    end

    if options[:provider] or options[:did_provider]
      c = ""
      c << "calls.provider_id = ?" if options[:provider]
      c << " and " if options[:provider] and options[:did_provider]
      c << "calls.did_provider_id = ?" if options[:did_provider]
      cond << c
      var += [options[:provider].id] if options[:provider]
      var += [options[:did_provider].id] if options[:did_provider]
    end

    if options[:reseller]
      cond << "calls.reseller_id = ?"
      var << options[:reseller].id
    end

    if options[:source] and not options[:source].blank?
      cond << "(calls.src LIKE ? OR calls.clid LIKE ?)"
      2.times { var << options[:source] }
    end
    # this is nasty but oh well.

    unless options[:s_card_number].to_s.strip.blank?
      cond << "cards.number LIKE ?"
      var << options[:s_card_number]
    end

    unless options[:s_card_pin].to_s.strip.blank?
      cond << "cards.pin LIKE ?"
      var << options[:s_card_pin]
    end

    unless options[:s_card_id].to_s.strip.blank?
      cond << "calls.card_id LIKE ?"
      var << options[:s_card_id]
    end

    return cond, var, jn
  end

  def self.last_calls_csv_headers
    {
      'calldate2' => _('Date'),
      'uniqueid' => _('UniqueID'),
      'src' => _('Source'),
      'nice_src' => _('Called_from'),
      'clid' => _('Called_from'),
      'dst' => _('Called_to'),
      'prefix' => _('Prefix'),
      'destination' => _('Destination'),
      'nice_billsec' => _('Duration'),
      'dispod' => _('hangup_cause'),
      'server_id' => _('Server'),
      'provider_name' => _('Provider_name'),
      'provider_rate' => _('Provider_rate'),
      'provider_price' => _('Provider_price'),
      'nice_reseller' => _('Reseller'),
      'reseller_rate' => _('Reseller_rate'),
      'reseller_price' => _('Reseller_price'),
      'self_cost_rate' => _('Self-Cost_Rate'),
      'self_cost_price' => _('Self-Cost_Price'),
      'user' => _('User'),
      'nice_src_device' => _('Device'),
      'user_rate' => _('User_rate'),
      'user_price' => _('User_price'),
      'did' => _('DID_Number'),
      'did_prov_price' => _('DID_provider_price'),
      'did_inc_price' => _('DID_incoming_price'),
      'did_price' => _('DID_Price'),
      'provider_id' => _('Provider_ID'),
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
      'partner_rate' => _('Self-Cost_Rate'),
      'partner_price' => _('Self-Cost_Price'),
      'nice_reseller' => _('Reseller'),
      'reseller_rate' => _('Reseller_rate'),
      'reseller_price' => _('Reseller_price'),
      'user' => _('User'),
      'nice_src_device' => _('Device'),
      'user_rate' => _('User_rate'),
      'user_price' => _('User_price'),
      'did' => _('DID_Number'),
      'did_prov_price' => _('DID_provider_price'),
      'did_inc_price' => _('DID_incoming_price'),
      'did_price' => _('DID_Price'),
      'profit' => _('Profit')
    }
  end

  def self.nice_user(user)
    if user
      nice_name = "#{user.first_name} #{user.last_name}"
      nice_name = user.username.to_s if nice_name.length < 2
      return nice_name
    end
    return ''
  end
end
