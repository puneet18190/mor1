# -*- encoding : utf-8 -*-
class Tariff < ActiveRecord::Base
  include CsvImportDb
  include UniversalHelpers

  attr_protected

  has_many :rates
  has_many :providers
  has_many :users
  has_many :sms_providers
  has_many :cardgroups
  has_many :common_use_providers
  has_many :locationrules
  has_many :origination_points, class_name: 'Device', foreign_key: 'op_tariff_id'
  has_many :termination_points, class_name: 'Device', foreign_key: 'tp_tariff_id'
  belongs_to :owner, class_name: 'User'

  validates_uniqueness_of :name, :message => _('Name_must_be_unique'), :scope => [:owner_id]
  validates_presence_of :name, :message => _('Name_cannot_be_blank')
  after_create :update_time

  def real_currency
    Currency.where(['name = ?', self.currency]).first
  end

  # select rates by their countries (directions) first letter for easier management
  def rates_by_st(st, per_page, prefix_cond)
    select = 'rates.id, rates.tariff_id, rates.destination_id, destinations.direction_code, destinations.prefix, ' +
             'destinations.name as destination_name'

    Rate.select(select)
        .from('destinations, rates, directions')
        .where(['rates.tariff_id = ? AND destinations.id = rates.destination_id', self.id])
        .where(['directions.code = destinations.direction_code AND directions.name like ?', st.to_s + '%'])
        .where(prefix_cond)
        .group('rates.id')
        .order('directions.name ASC, destinations.prefix ASC')
        .limit(per_page.to_s)
  end

  def sms_rates_by_st(st, sql_start, per_page, options={})
    ex_r = options[:exchange_rate] ? options[:exchange_rate] : 1
    daytype = Day.daytype(options[:user].time_now_in_tz)
    sql = "
      SELECT
        A.id,
        destinations.direction_code,
        destinations.prefix,
        destinations.name AS destination_name,
        directions.code AS direction_code,
        directions.name AS direction_name,
        A.price AS curr_price
      FROM (
        SELECT
          rates.id,
          ratedetails.rate * #{ex_r} AS price,
          rates.destination_id,
          rates.prefix,
          ratedetails.rate_id
        FROM rates
          LEFT JOIN ratedetails ON ratedetails.rate_id = rates.id
          WHERE rates.tariff_id = #{id} AND (effective_from <= NOW() OR effective_from IS NULL)
            AND daytype != '#{daytype}'
          ORDER BY rates.destination_id, rates.effective_from DESC
        ) A
       LEFT JOIN destinations ON A.destination_id = destinations.id
       LEFT JOIN directions ON direction_code = directions.code
       WHERE destinations.name LIKE #{ActiveRecord::Base::sanitize(st.to_s << '%')}
       GROUP BY prefix
       ORDER BY directions.name ASC, destinations.prefix ASC
       LIMIT #{sql_start}, #{per_page.to_s}
    "
    ActiveRecord::Base.connection.select(sql)
  end

  # destinations which have rate assigned for this tariff
  def destinations
    Destination.select('destinations.*')
    .from('destinations, tariffs, rates, directions')
    .where(['rates.tariff_id = ? AND destinations.id = rates.destination_id', self.id])
    .group('destinations.id')
    .order('destinations.prefix ASC')
  end

  # destinations which haven't rate assigned for this tariff by first letter
  def free_destinations_by_st(st, limit = nil, offset = 0)
    st = st.to_s

    destination_ids = Destination.select('destinations.id').
        joins("JOIN directions ON (directions.code = destinations.direction_code AND directions.name like '#{st}%')").
        joins("JOIN rates ON (rates.destination_id = destinations.id AND rates.tariff_id = #{self.id})").
        group('destinations.id').order('destinations.prefix').pluck(:id)

    query = Destination.select('destinations.*')
    .joins('JOIN directions ON (directions.code = destinations.direction_code)')
    .where("directions.name like '#{st}%'")

    query = query.where("destinations.id NOT IN (#{destination_ids.join(',')})") unless destination_ids.blank?

    adests = query.order('directions.name ASC, destinations.prefix ASC')
    .limit(limit || 1000000)
    .offset(offset).all

    actual_adest_count = query.to_a.size
    limit ? [adests, actual_adest_count] : adests
  end

=begin rdoc
  Returns destinations that have no assigned rates.

 *Params*:

 +direction+ - Direction, or Direction.id

 *Flash*:

 +notice+ - messages that are passed through flash[:notice]

 *Redirect*

 +action+ - where action redirects
=end

  def free_destinations_by_direction(direction, options ={})
    destinations = []
    extra = {}
    extra[:limit] = options[:limit].to_i if options[:limit] and options[:limit].to_i
    extra[:offset] = options[:offset].to_i if options[:offset] and options[:offset].to_i
    if direction.class == String
      destinations = Destination.select("destinations.*, directions.code AS 'dir_code', directions.name AS 'dir_name' ").
          joins("LEFT JOIN directions ON (directions.code = destinations.direction_code) LEFT JOIN (SELECT * FROM rates where tariff_id = #{self.id}) as rates  ON (rates.destination_id = destinations.id)").
          where(["destinations.direction_code = ? AND rates.id IS NULL", code])
      if extra.size == 2
        destinations = destinations.limit(extra[:limit]).offset(extra[:offset]).all
      elsif extra[:limit].present?
        destinations = destinations.limit(extra[:limit]).all
      elsif extra[:offset].present?
        destinations = destinations.offset(extra[:offset]).all
      else
        destinations = destinations.all
      end
    end
    if direction.class == Direction
      destinations = Destination.select("destinations.*, directions.code AS 'dir_code', directions.name AS 'dir_name' ").
          joins("LEFT JOIN directions ON (directions.code = destinations.direction_code) LEFT JOIN (SELECT * FROM rates where tariff_id = #{self.id}) as rates  ON (rates.destination_id = destinations.id)").
          where(["destinations.direction_code = ? AND rates.id IS NULL", direction.code])
      if extra.size == 2
        destinations = destinations.limit(extra[:limit]).offset(extra[:offset]).all
      elsif extra[:limit].present?
        destinations = destinations.limit(extra[:limit]).all
      elsif extra[:offset].present?
        destinations = destinations.offset(extra[:offset]).all
      else
        destinations = destinations.all
      end
    end
    options[:with_count] == true
    destinations
  end

  def add_new_rate(dest, rate_value, increment, min_time, connection_fee, ghost_percent = nil, prefix = nil, effective_from = nil)
    success = false
    rate = Rate.new

    if self.purpose.to_s == 'provider' || self.purpose.to_s == 'user_wholesale'
      rate.prefix = prefix || dest.prefix
    end

    rate.tariff_id = self.id
    rate.destination_id = dest.id
    rate.destinationgroup_id = dest.destinationgroup_id
    rate.ghost_min_perc = ghost_percent
    rate.effective_from = effective_from

    rate_det = Ratedetail.new
    rate_det.rate = rate_value.to_d
    rate_det.increment_s = increment.to_i < 1 ? 1 : increment.to_i
    rate_det.min_time = min_time.to_i < 0 ? 0 : min_time.to_i
    rate_det.connection_fee = connection_fee.to_d

    rate.ratedetails << rate_det
    if retry_lock_error(3) { rate.save }
      self.last_update_date = Time.now
      self.save
      success = true
    end
    success
  end


  def delete_all_rates
    if purpose != 'user'
      sql = "DELETE ratedetails, rates FROM ratedetails, rates WHERE ratedetails.rate_id = rates.id AND rates.tariff_id = '#{self.id.to_s}'"
      res = retry_lock_error(3) { ActiveRecord::Base.connection.execute(sql) }

      # Just in case - sometimes helps after crashed rate import from CSV file
      sql = "DELETE FROM rates WHERE rates.tariff_id = '#{self.id.to_s}'"
      res = retry_lock_error(3) { ActiveRecord::Base.connection.execute(sql) }
    else
      sql = "DELETE aratedetails, rates FROM aratedetails, rates WHERE aratedetails.rate_id = rates.id AND rates.tariff_id = '#{self.id.to_s}'"
      res = retry_lock_error(3) { ActiveRecord::Base.connection.execute(sql) }

      # Just in case - sometimes helps after crashed rate import from CSV file
      sql = "DELETE FROM rates WHERE rates.tariff_id = '#{self.id.to_s}'"
      res = retry_lock_error(3) { ActiveRecord::Base.connection.execute(sql) }
    end

    # for rate in self.rates
    #   rate.destroy_everything
    # end
  end


  def exchange_rate(cur = nil)
    if cur
      Currency.count_exchange_rate(cur, currency)
    else
      sql = "SELECT exchange_rate FROM currencies, tariffs WHERE currencies.name = tariffs.currency AND tariffs.id = '#{self.id}'"
      res = ActiveRecord::Base.connection.select_one(sql)
      res["exchange_rate"].to_d
    end
  end

  def make_wholesale_tariff(amount = 0, percent = 0, fee_amount = 0, fee_percent = 0, type = "provider")
    tname = "#{self.name}"
    tname += " + #{amount}" if amount
    tname += " + #{percent}%" if percent

    amount = amount.to_d
    percent = percent.to_d
    fee_amount = fee_amount.to_d
    fee_percent = fee_percent.to_d

    utariff = Tariff.new
    utariff.name = tname
    utariff.purpose = type
    utariff.currency = self.currency
    utariff.owner_id = self.owner_id

    Tariff.transaction do
      if utariff.save
        new_tariff_id = utariff.id

        count_details = 0
        ratedetails_sql = []
        rates_sql = "SELECT ratedetails.id, ratedetails.end_time, ratedetails.start_time, ratedetails.rate, ratedetails.connection_fee, ratedetails.rate_id, ratedetails.increment_s, ratedetails.min_time, ratedetails.daytype, rates.id, rates.tariff_id, rates.destination_id, rates.effective_from, destinations.name ,rates.prefix FROM ratedetails LEFT join rates ON (rates.id = ratedetails.rate_id) LEFT JOIN destinations on rates.destination_id = destinations.id WHERE rates.tariff_id = #{self.id};"
        rates_array = ActiveRecord::Base.connection.execute(rates_sql)
        rates = {}
        rates_array.each { |line|

          # THIS WILL HELP TO FIND CORRECT LINES
          # rd = {:id => line[0], :start_time => line[2], :end_time => line[1] , :rate  => line[3] , :connection_fee => line[4] , :rate_id  => line[5] ,
          # :increment_s => line[6] , :min_time => line[7] , :daytype => line[8], :effective_from => line[12] , name: line[13], prefix: line[14] }
          rates[line[9]] = ActiveRecord::Base.connection.insert("INSERT INTO rates (`tariff_id`, `destination_id`, `destinationgroup_id`, `effective_from`, `prefix`) VALUES(#{new_tariff_id}, #{line[11]}, NULL, '#{line[12]}', '#{line[14]}')").to_i if !rates[line[9]]

          connection_fee= line[4].to_d
          connection_fee += fee_amount
          connection_fee += connection_fee*fee_percent/100

          price = line[3].to_d
          price += amount
          price += price*percent/100
          count_details += 1
          ratedetails_sql << "'#{line[2].strftime("%Y%m%d%H%M%S")}','#{line[1].strftime("%Y%m%d%H%M%S")}', #{line[6]}, '#{line[8]}', #{price}, #{rates[line[9]]}, #{line[7]}, #{connection_fee}"
          if count_details > 2000
            ActiveRecord::Base.connection.insert("INSERT INTO ratedetails (`start_time`, `end_time`, `increment_s`, `daytype`, `rate`, `rate_id`, `min_time`, `connection_fee`) VALUES(#{ratedetails_sql.join("),(")})")
            count_details = 0
            ratedetails_sql = []
          end
        }
        ActiveRecord::Base.connection.insert("INSERT INTO ratedetails (`start_time`, `end_time`, `increment_s`, `daytype`, `rate`, `rate_id`, `min_time`, `connection_fee`) VALUES(#{ratedetails_sql.join("),(")})") if count_details > 0
      else
        return false
      end
    end
    return utariff
  end

=begin rdoc
  Makes new retail tariff from existing one.

  *Params*

  +amount+ - amount to add to rate price.
  +percent+ - amount to add to rate in percents.
  +fee_amount+ - amount to add to conncetion fee price.
  +fee_percent+ - amount to add to connection fee in percents.
  +owner+ - owner of new tariff.
=end

  def make_retail_tariff(amount = 0, percent = 0, fee_amount = 0, fee_percent = 0, owner = 0, round_by = 1)
    trates = 0 # total_rates
    round_by = 1 if round_by == ''
    insert_header = "INSERT INTO aratedetails (`duration`, `price`, `end_time`, `from`, `artype`, `rate_id`, `round`, `start_time`)"
    tariff = Tariff.new
    Tariff.transaction do
      tname = "#{self.name}"
      tname += " + #{amount}" if amount != 0
      tname += " + #{percent}%" if percent != 0

      tariff.name = tname
      tariff.purpose = 'user'
      tariff.currency = self.currency
      tariff.owner_id = owner
      if tariff.save
        count_details = 0
        ratedetails_sql = []
        ActiveRecord::Base.connection.execute("DROP TEMPORARY TABLE IF EXISTS tmp_dest_groups;")

        sql = "CREATE TEMPORARY TABLE tmp_dest_groups SELECT destinations.destinationgroup_id AS id,
                                                             MAX(rate) AS rate
                                                      FROM destinations
                                                      JOIN rates ON (destinations.id = rates.destination_id)
                                                      JOIN ratedetails ON (ratedetails.rate_id = rates.id)
                                                      WHERE rates.tariff_id = #{self.id}
                                                            AND ratedetails.rate = (SELECT r.rate
                                                                                    FROM ratedetails AS r
                                                                                    WHERE rates.id = r.rate_id
                                                                                          AND (rates.effective_from <= NOW() OR rates.effective_from IS NULL)
                                                                                    ORDER BY rates.effective_from DESC, r.rate DESC LIMIT 1
                                                                                    )
                                                      GROUP BY destinations.destinationgroup_id;"
        res = ActiveRecord::Base.connection.execute(sql)

        sql = "create index tmp_id_index on tmp_dest_groups(id)"
        res = ActiveRecord::Base.connection.execute(sql)

        sql = "SELECT destinationgroups.id,
                      rates.destination_id,
                      rates.tariff_id,
                      ratedetails.rate,
                      ratedetails.increment_s,
                      ratedetails.connection_fee,
                      destinations.destinationgroup_id,
                      ratedetails.min_time,
                      rates.effective_from
               FROM destinationgroups
               JOIN destinations ON (destinations.destinationgroup_id = destinationgroups.id)
               JOIN rates ON (destinations.id = rates.destination_id)
               JOIN ratedetails ON (ratedetails.rate_id = rates.id)
               JOIN tmp_dest_groups ON (tmp_dest_groups.id = destinationgroups.id)
               WHERE rates.tariff_id = #{self.id}
                     AND tmp_dest_groups.rate = ratedetails.rate
               GROUP BY destinationgroups.id;"
        res = ActiveRecord::Base.connection.execute(sql)

        ActiveRecord::Base.connection.execute("DROP TEMPORARY TABLE IF EXISTS tmp_dest_groups;")

        res.each { |line|
          trates += 1
          new_rate = line[3].to_d
          new_increment = line[4].to_d
          new_connfee = line[5].to_d
          min_time = line[7].to_d

          new_rate += amount.to_d
          new_rate += new_rate/100 * percent.to_d
          new_rate = new_rate.round(15)

          new_connfee += fee_amount.to_d
          new_connfee += new_connfee/100 * fee_percent.to_d
          new_connfee = new_connfee.round(15)


          # `duration`, `price`, `end_time`, `from`, `artype`, `rate_id`, `round`, `start_time`
          rate_id = ActiveRecord::Base.connection.insert("INSERT INTO rates (`tariff_id`, `destination_id`, `destinationgroup_id`, `effective_from`) VALUES(#{tariff.id}, #{line[2]}, #{line[0]}, '#{line[8]}')").to_i
          if new_connfee != 0
            count_details += 1
            ratedetails_sql << "0, #{new_connfee}, '23:59:59', 1, 'event', #{rate_id}, #{round_by}, '00:00:00'"
          end

          if min_time != 0
            count_details += 1
            ratedetails_sql << "#{min_time}, #{new_rate}, '23:59:59', 1, 'minute', #{rate_id}, #{min_time}, '00:00:00'"
          end

          count_details += 1
          ratedetails_sql << "-1, #{new_rate}, '23:59:59', #{min_time + 1}, 'minute', #{rate_id}, #{round_by}, '00:00:00'"
          if count_details > 2000
            #           "INSERT INTO aratedetails (`duration`, `price`, `end_time`, `from`, `artype`, `rate_id`, `round`, `start_time`)"
            ActiveRecord::Base.connection.insert("#{insert_header} VALUES (#{ratedetails_sql.join("),(")})")
            count_details = 0
            ratedetails_sql = []
          end
        }
        ActiveRecord::Base.connection.insert("#{insert_header} VALUES (#{ratedetails_sql.join("),(")})") if count_details > 0
      else
        return false
      end
    end
    return trates
  end

  def generate_user_rates_csv(session)
    tariff_currency = self.currency.to_s
    sql = "SELECT rates.* FROM rates
           LEFT JOIN destinationgroups on (destinationgroups.id = rates.destinationgroup_id)
           WHERE rates.tariff_id ='#{id}'
           ORDER BY destinationgroups.name ASC"

    rates = Rate.find_by_sql(sql)
    sep, dec = Confline.get_value('CSV_Separator').to_s, Confline.get_value('CSV_Decimal').to_s
    csv_string = _('Destination_Group_Name') + sep + _('Rate') + '(' + tariff_currency + ')' + sep + _('Round') + "\n"

    for rate in rates
      arate_details, arate_cur = get_user_rate_details(rate, 1)

      # Destination Group Name
      csv_string += rate.destinationgroup.present? ? "#{"\"" + rate.destinationgroup.name.to_s.gsub(sep, ' ') + "\""}#{sep}" : "#{"\"" + '0' + "\""}#{sep}"

      # Rate; Round
      csv_string += arate_details.size == 0 ? "0#{sep}0\n" : "#{nice_number(arate_cur, session).to_s.gsub('.', dec)}#{sep}#{arate_details[0]['round'].to_s.gsub('.', dec)}\n"
    end

    csv_string
  end

  def tariffs_api_wholesale
    sql = "SELECT directions.name as 'direction', destinations.name as 'destination', destinations.prefix, directions.code,
      ratedetails.start_time, ratedetails.end_time, ratedetails.rate, ratedetails.connection_fee, ratedetails.increment_s, ratedetails.min_time, ratedetails.daytype
      FROM rates
      LEFT JOIN ratedetails ON (rates.id = ratedetails.rate_id)
      LEFT JOIN destinations ON (rates.destination_id = destinations.id)
      LEFT JOIN directions ON (directions.code = destinations.direction_code)
      WHERE rates.tariff_id = #{self.id}
      ORDER BY directions.name ASC;"
    result = ActiveRecord::Base.connection.select_all(sql)
    return result
  end

  def tariffs_api_retail
    sql = "SELECT rates.id, destinationgroups.name,
           aratedetails.price, aratedetails.round, aratedetails.duration, aratedetails.artype, aratedetails.start_time, aratedetails.end_time, aratedetails.daytype, aratedetails.from
           FROM rates
           LEFT JOIN destinationgroups on (destinationgroups.id = rates.destinationgroup_id)
           LEFT JOIN aratedetails on (aratedetails.rate_id = rates.id)
           WHERE rates.tariff_id ='#{id}'
           ORDER BY  destinationgroups.name, aratedetails.from, aratedetails.daytype ,aratedetails.start_time, rates.id ASC"
    result = ActiveRecord::Base.connection.select_all(sql)
    return result
  end

  def generate_providers_rates_csv(session, current_user = nil)
    tariff_currency = self.currency.to_s
    res = Array(ActiveRecord::Base.connection.select_all(self.sql_for_providers_rates_csv(session)))
    sep = Confline.get_value("CSV_Separator").to_s
    dec = Confline.get_value("CSV_Decimal").to_s
    tax = current_user.get_tax
    show_rates_with_tax = Confline.get_value('Show_Rates_Without_Tax', current_user.owner_id) != '1' if current_user.usertype != 'accountant'

    csv_string = CSV.generate(col_sep: sep, quote_char: "\'") do |csv|
      csv << [
          _('Destination'),
          _('Prefix'),
          _('Rate') + '(' + tariff_currency + ')',
          _('Connection_Fee') + '(' + tariff_currency + ')',
          _('Increment',),
          _('Minimal_Time'),
          _('Start_Time'),
          _('End_Time'),
          _('Week_Day'),
          @effective_from_active ? _('Effective_from') : "\"\""
        ]

      res.each do |result|
        rate, con_fee = [result['rate'].to_d, result['connection_fee'].to_d]
        rate, con_fee = [tax.count_tax_amount(rate) + rate, tax.count_tax_amount(con_fee) + con_fee] if show_rates_with_tax

        csv << [
            "\"#{result['destination'].to_s.gsub(sep, ' ')}\"",
            result['prefix'],
            nice_number(rate, session).gsub('.', dec),
            nice_number(con_fee, session).gsub('.', dec),
            result['increment_s'],
            result['min_time'],
            result['start_time'].blank? ? "\"\"" : result['start_time'].strftime('%H:%M:%S'),
            result['end_time'].blank? ? "\"\"" : result['end_time'].strftime('%H:%M:%S'),
            result['daytype'].blank? ? "\"\"" : result['daytype'],
            @effective_from_active ? (nice_date_time(result['effective_from'],session,current_user).blank? ?  "\"\"" : nice_date_time(result['effective_from'],session,current_user)) : "\"\""
          ]
      end
    end
  end

  def sql_for_providers_rates_csv(session)
    s_prefix = session[:user_rates_prefix] ||= ''
    prefix_cond = s_prefix.present? ? " AND rates.prefix LIKE '#{s_prefix.to_s}'" : ''
    @effective_from_active = (%w[admin reseller accountant partner].include?(session[:usertype]) && (['provider', 'user_wholesale'].include?(self.purpose)))
    effective_cond = @effective_from_active ? ' AND (effective_from <= NOW() OR effective_from IS NULL)' : ''

    sql = "SELECT destinations.name AS destination,A.*
           FROM (
                  SELECT rates.prefix, rates.effective_from, ratedetails.start_time,
                         ratedetails.end_time, ratedetails.rate, ratedetails.connection_fee,
                         ratedetails.increment_s, ratedetails.min_time, ratedetails.daytype,
                         destination_id
                  FROM rates
                  LEFT JOIN ratedetails ON ratedetails.rate_id = rates.id
                  WHERE rates.tariff_id = #{self.id}#{effective_cond}#{prefix_cond}
           ORDER BY prefix, rates.effective_from DESC) A
           LEFT JOIN destinations on A.destination_id = destinations.id GROUP BY A.prefix
           ORDER BY destination, prefix;"
    sql
  end

  def generate_personal_wholesale_rates_csv(session)
    tariff_currency = self.currency.to_s
    sql = "SELECT rates.* FROM rates LEFT JOIN destinations on rates.destination_id = destinations.id WHERE rates.tariff_id = #{id} ORDER by destinations.name ASC;"
    rates = Rate.find_by_sql(sql)
    sep = Confline.get_value("CSV_Separator").to_s
    dec = Confline.get_value("CSV_Decimal").to_s

    csv_string = _('Prefix') + sep + _('Rate') + "(" + tariff_currency + ")" + sep +
      _('Connection_Fee') + "(" + tariff_currency + ")" + sep + _('Increment') + sep +
      _('Minimal_Time') + "\n"

    rates.each do |rate|
      rate_details, rate_cur = get_provider_rate_details(rate, 1)
      csv_string += "#{rate.prefix}#{sep}#{rate_cur.to_s.gsub(".", dec)}#{sep}"

      if rate_details.size > 0
        csv_string += "#{rate_details[0]['connection_fee'].to_s.gsub(".", dec)}#{sep}" +
        "#{rate_details[0]['increment_s'].to_s.gsub(".", dec)}#{sep}#{rate_details[0]['min_time'].to_s.gsub(".", dec)}\n"
      else
        csv_string += "0#{sep}0#{sep}0#{sep}0\n"
      end
    end

    csv_string
  end

  def check_types_periods(options={})
    if options[:time_from]
      a1, a2 = options[:time_from][:hour].to_s + ":" + options[:time_from][:minute].to_s + ":" + options[:time_from][:second].to_s, options[:time_till][:hour].to_s + ":" + options[:time_till][:minute].to_s + ":" + options[:time_till][:second].to_s
    else
      a1, a2 = options[:time_from_hour].to_s + ":" + options[:time_from_minute].to_s + ":" + options[:time_from_second].to_s, options[:time_till_hour].to_s + ":" + options[:time_till_minute].to_s + ":" + options[:time_till_second].to_s
    end
    day_type = ["wd", "fd",].include?(options[:rate_day_type].to_s) ? options[:rate_day_type].to_s : ''
    #In case new rate detail's time and daytype is identical to allready existing rate details it will
    #be updated so we don't think it is a collision
    #In case new rate details time is WD and there already is FD there cannot be time collisions. and vice versa
    #In all other cases we need to check for time colissions. Note bug that was originaly here - function does not
    #work if time wraps around e.g. period is between 23:00 and 01:00
    #UPDATE mor has peculiar way to check for time collisions - if at least a minute is set for all days, no other
    #tariff detail can be set to fd/wd and vice versa
    ratesd = Ratedetail.joins("LEFT JOIN rates ON (ratedetails.rate_id = rates.id)").where(["rates.tariff_id = '#{id}' AND
      CASE
        WHEN daytype = '#{day_type}' AND start_time = '#{a1}' AND end_time = '#{a2}' THEN 0
        WHEN '#{day_type}' IN ('WD', 'FD') AND daytype IN ('WD', 'FD') AND daytype != '#{day_type}' THEN 0
        WHEN (daytype = '' AND '#{day_type}' != '') OR (daytype IN ('WD', 'FD') AND '#{day_type}' NOT IN ('WD', 'FD')) THEN 1
        ELSE ('#{a1}' BETWEEN start_time AND end_time) OR ('#{a2}' BETWEEN start_time AND end_time) OR (start_time BETWEEN '#{a1}' AND '#{a2}') OR (end_time BETWEEN '#{a1}' AND '#{a2}')
      END != 0"]).all

    notice_2 = ''
    #checking time periods for collisions
    #ticket #5808 -> not checking any more
    #if ratesd and ratesd.size.to_i > 0
    #  notice_2 = _('Tariff_import_incorrect_time').html_safe
    #  notice_2 += '<br /> * '.html_safe + _('Please_select_period_without_collisions').html_safe
    #  # redirect_to :action => "import_csv", :id => @tariff.id, :step => "2" and return false
    #end

    ratesd = Ratedetail.select("SUM(IF(daytype = '',1,0)) all_sum, SUM(IF(daytype != '',1,0)) wd_fd_sum ").joins("LEFT JOIN rates ON (ratedetails.rate_id = rates.id)").where(["rates.tariff_id = '#{id}'"]).first
    if ratesd.wd_fd_sum.to_i == 0
      rate_types = [[_("All"), "all"], [_("Work_Days"), "wd"], [_("Free_Days"), "fd"]]
    else
      rate_types = [_("Work_Days"), "wd"], [_("Free_Days"), "fd"]
    end

    return rate_types, notice_2
  end

  def head_of_file(path, number = 1)
    CsvImportDb.head_of_file(path, number)
  end

  def save_file(file, path = '/tmp/')
    CsvImportDb.save_file(id, file, path)
  end

  def load_csv_into_db(tname, sep, dec, fl, path = '/tmp/')
    colums ={}
    colums[:colums] = [{name: 'short_prefix', type: 'VARCHAR(50)', default: ''},
                       {name: 'f_country_code', type: 'INT(4)', default: 0},
                       {name: 'f_error', type: 'INT(4)', default: 0},
                       {name: 'nice_error', type: 'INT(4)', default: 0},
                       {name: 'ned_update', type: 'INT(4)', default: 0},
                       {name: 'not_found_in_db', type: 'INT(4)', default: 0},
                       {name: 'new_effective_from', type: 'INT(4)', default: 0}, # Whether create new or update Rate
                       {name: 'id', type: 'INT(11)', inscrement: ' NOT NULL auto_increment '},
                       {name: 'original_destination_name', type: 'VARCHAR(255)', default: ''},
                       {name: 'destination_id', type: 'INT(11)', default: 0},
                       {name: 'destination_group_id', type: 'INT(11)', default: 0},
                       {name: 'destination_name', type: 'VARCHAR(255)', default: ''}
                     ]
    CsvImportDb.load_csv_into_db(tname, sep, dec, fl, path, colums)
  end

  def analyze_file(name, options)
    CsvImportDb.log_swap('analize')
    MorLog.my_debug("CSV analyze_file #{name}", 1)

    arr = {
        tariff_rates: Rate.where(tariff_id: id).size
    }
    if ActiveRecord::Base.connection.tables.include?(name)
      arr[:destinations_in_csv_file] =
          (ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name}").to_i - 1).to_s
    end

    if options[:imp_effective_from].present?
      str2 = ", col_#{options[:imp_effective_from]}"

      # Formats similar to '06-01' cannot be interpreted by SQL Date parser, so the mentioned fields have to be
      #   pre-parsed by Ruby.
      rows = ActiveRecord::Base.connection.select_all("
        SELECT id,
               col_#{options[:imp_effective_from]} AS effective_from
        FROM #{name}
        WHERE (length(col_#{options[:imp_effective_from]}) = 5
               AND LEFT(col_#{options[:imp_effective_from]}, 3) = '#{options[:date_format][2]}'
              )
      ")
      current_time = Date.current.to_time
      row_updates = []
      rows.each do |row|
        begin
          effective_from_date = row['effective_from']
          effective_from_date = Time.parse(effective_from_date.gsub('-', '/'), current_time).
              strftime("#{options[:date_format]}")

          row_updates << "UPDATE #{name} SET col_#{options[:imp_effective_from]} = '#{effective_from_date}' WHERE id = #{row['id']}"
        rescue
          # Do nothing. (Skip one failed row).
        end
      end

      # Additionally time format containing dots (.) will be converted into colons (:)
      rows = ActiveRecord::Base.connection.select_all("
        SELECT id,
               col_#{options[:imp_effective_from]} AS effective_from
        FROM #{name}
        WHERE (
               LOCATE('.', SUBSTRING_INDEX(col_#{options[:imp_effective_from]}, ' ', -1)) > 0
               AND SUBSTRING_INDEX(col_#{options[:imp_effective_from]}, ' ', -1) != col_#{options[:imp_effective_from]}
              )
      ")
      rows.each do |row|
        begin
          effective_from = row['effective_from']
          effective_from_splitted = effective_from.split(' ')
          if effective_from_splitted.size == 2
            effective_from = effective_from_splitted[0] + ' ' + effective_from_splitted[1].gsub('.', ':')
          end

          row_updates << "UPDATE #{name} SET col_#{options[:imp_effective_from]} = '#{effective_from}' WHERE id = #{row['id']}"
        rescue
          # Do nothing. (Skip one failed row).
        end
      end

      ActiveRecord::Base.transaction{ row_updates.each { |update| ActiveRecord::Base.connection.execute(update) } }
    else
      str2 = ''
    end

    # Condition to check whether effective_from is identical
    if options[:imp_effective_from].present? # effective_from imported straight from file
      effective_from_column = ', effective_from'
      effective_from_value = "CONVERT_TZ(STR_TO_DATE(col_#{options[:imp_effective_from]}, '#{options[:date_format]}'), '#{options[:current_user_tz]}', '#{local_tz_for_import}')"
      effective_from_field = ", #{effective_from_value}"
    elsif options[:manual_effective_from].present? # effective_from datetime dropdown select or default
      effective_from_column = ', effective_from'
      effective_from_value = "'#{options[:manual_effective_from]}'"
      effective_from_field = ", #{effective_from_value}"
    end
    effective_from_value = "''" if effective_from_value.blank?
    effective_from_condition = effective_from_value.present? ? "AND (rates.effective_from != #{effective_from_value} OR rates.effective_from IS NULL)" : ''
    effective_from_condition_identical = effective_from_value.present? ? "AND rates.effective_from = #{effective_from_value}" : ''

    # Wondering why so many 'if ActiveRecord::Base.connection.tables.include?(name)' before each execution?
    # Well frankly neither know I, but there is one some sort of a reason:
    #   here we work with temporary DB table and it's only a matter of time when server can run out of space, memory or
    #   something else (yes we have this issue and ok if that would only occur once, but you know, karma..), so in order
    #   to just make one if, we make sure, that before every sql execution temp DB table is still there breathing. Else
    #   one nasty crash for client.

    # Set error flag on not rates if Effective_from is not datetime | code : 16
    if ActiveRecord::Base.connection.tables.include?(name) && options[:imp_effective_from].present?
      retry_lock_error(3) {
        ActiveRecord::Base.connection.execute("
        UPDATE #{name}
        SET f_error = 1, nice_error = 16
        WHERE STR_TO_DATE(col_#{options[:imp_effective_from]}, '#{options[:date_format]}') IS NULL
          OR STR_TO_DATE(col_#{options[:imp_effective_from]}, '#{options[:date_format]}') = '0000-00-00 00:00:00'
        ")
      }
    end

    # Set error flag on duplicates | code : 12
    if ActiveRecord::Base.connection.tables.include?(name)
      str3 = str2.present? ? "WHERE col_#{options[:imp_effective_from]} != ''" : ''
      retry_lock_error(3) {
        ActiveRecord::Base.connection.execute("
          UPDATE #{name}
          SET f_error = 1, nice_error = 12
          WHERE f_error = 0
                AND col_#{options[:imp_prefix]} IN (SELECT prf
                                                    FROM (SELECT col_#{options[:imp_prefix]} AS prf,
                                                                 COUNT(*) AS u
                                                          FROM #{name}
                                                          #{str3}
                                                          GROUP BY col_#{options[:imp_prefix]}#{str2} HAVING u > 1
                                                         ) AS imf
                                                   )
        ")
      }
    end

    # Set error flag on not int prefixes | code : 13
    if ActiveRecord::Base.connection.tables.include?(name)
      retry_lock_error(3) {
        ActiveRecord::Base.connection.execute("
          UPDATE #{name}
          SET f_error = 1, nice_error = 13
          WHERE col_#{options[:imp_prefix]} REGEXP '^[0-9]+$' = 0
          AND f_error = 0
        ")
      }
    end

    # Set error flag on bad formatted rates | code : 17
    if ActiveRecord::Base.connection.tables.include?(name)
      retry_lock_error(3) {
        ActiveRecord::Base.connection.execute("
          UPDATE #{name}
          SET col_#{options[:imp_rate]} = -1
          WHERE col_#{options[:imp_rate]} REGEXP '^blocked$' = 1
        ")
      }
    end

    if ActiveRecord::Base.connection.tables.include?(name)
      retry_lock_error(3) {
        ActiveRecord::Base.connection.execute("
          UPDATE #{name}
          SET f_error = 1, nice_error = 17
          WHERE col_#{options[:imp_rate]} REGEXP '^-?[0-9]+$|^-?[0-9]+[;,.][0-9]+$' = 0
                AND f_error = 0
        ")
      }
    end

    # Set error flag on

    if ActiveRecord::Base.connection.tables.include?(name)
      # Ticket #5808 -> since now we don't check for time collisions, just import anything if possible. Else User will
      #   be notified in the last step about rates that was not possible to import due to time collision.

      day_type = ['wd', 'fd'].include?(options[:imp_date_day_type].to_s) ? options[:imp_date_day_type].to_s : ''
      start_time, end_time = options[:imp_time_from_type], options[:imp_time_till_type]

      retry_lock_error(3) {
        ActiveRecord::Base.connection.execute("UPDATE #{name}
                                              JOIN rates ON (col_#{options[:imp_prefix]} = rates.prefix #{effective_from_condition_identical})
                                              JOIN ratedetails ON (ratedetails.rate_id = rates.id)
                                              SET f_error = 1, nice_error = 15
                                              WHERE rates.tariff_id = '#{id}'
                                                    AND CASE
                                                          WHEN daytype = '#{day_type}'
                                                               AND start_time = '#{start_time}'
                                                               AND end_time = '#{end_time}'
                                                          THEN 0

                                                          WHEN '#{day_type}' IN ('WD', 'FD')
                                                               AND daytype IN ('WD', 'FD')
                                                               AND daytype != '#{day_type}'
                                                          THEN 0

                                                          WHEN (daytype = '' AND '#{day_type}' != '')
                                                               OR (daytype IN ('WD', 'FD') AND '#{day_type}' NOT IN ('WD', 'FD'))
                                                          THEN 1

                                                          ELSE ('#{start_time}' BETWEEN start_time AND end_time)
                                                               OR ('#{end_time}' BETWEEN start_time AND end_time)
                                                               OR (start_time BETWEEN '#{start_time}' AND '#{end_time}')
                                                               OR (end_time BETWEEN '#{start_time}' AND '#{end_time}')
                                                        END != 0
        ")
      }
    end

    # Set new_effective_from if Rate was found, but with not identical Effective From
    if ActiveRecord::Base.connection.tables.include?(name)
      retry_lock_error(3) {
        ActiveRecord::Base.connection.execute("
          UPDATE #{name}
          JOIN rates ON (col_#{options[:imp_prefix]} = rates.prefix #{effective_from_condition})
          SET new_effective_from = 1
        ")
      }
    end
    # Set flag on destination name update
    if ActiveRecord::Base.connection.tables.include?(name) && options[:imp_update_dest_names].to_i == 1 && options[:imp_dst] >= 0
      retry_lock_error(3) {
        ActiveRecord::Base.connection.execute("
          UPDATE #{name}
          JOIN destinations ON (col_#{options[:imp_prefix]} = destinations.prefix)
          SET ned_update = 1
          WHERE TRIM(col_#{options[:imp_dst]}) != '' AND (BINARY replace(TRIM(col_#{options[:imp_dst]}), '  ', ' ') != IFNULL(original_destination_name, destinations.name) OR destinations.name IS NULL)
        ")
      }
    end

    # Set flag not_found_in_db
    if ActiveRecord::Base.connection.tables.include?(name)
      retry_lock_error(3) {
        ActiveRecord::Base.connection.execute("
          UPDATE #{name}
          LEFT JOIN destinations ON (col_#{options[:imp_prefix]} = destinations.prefix)
          SET not_found_in_db = 1
          WHERE destinations.id IS NULL
                AND f_error = 0
        ")
      }
    end

    # Set destination_id if found in DB
    if ActiveRecord::Base.connection.tables.include?(name)
      retry_lock_error(3) {
        ActiveRecord::Base.connection.execute("
          UPDATE #{name}
          LEFT JOIN destinations ON (col_#{options[:imp_prefix]} = destinations.prefix)
          SET #{name}.destination_id = destinations.id,
              #{name}.destination_group_id = destinations.destinationgroup_id,
              #{name}.destination_name = destinations.name
          WHERE not_found_in_db = 0
                AND f_error = 0
        ")
      }
    end

    # Set flags
    if ActiveRecord::Base.connection.tables.include?(name)
      self.csv_import_prefix_analyze(name, options)
    end

    if ActiveRecord::Base.connection.tables.include?(name)
      begin
        CsvImportDb.create_index_for_prefix(name, options[:imp_prefix])
      rescue
        MorLog.my_debug("Tariff import analysis window refreshed on #{name}", 1)
      end
      # we put this here in case user refreshes browser after analysis and create index fails, thats why we ignore the crash
    end

    if ActiveRecord::Base.connection.tables.include?(name) && options[:imp_update_directions].to_i == 1
      retry_lock_error(3) {
        ActiveRecord::Base.connection.execute("
          UPDATE #{name}
          JOIN directions ON (col_#{options[:imp_cc]} = directions.code)
          JOIN destinations ON (col_#{options[:imp_prefix]} = destinations.prefix)
          SET ned_update = ned_update + 4
          WHERE destinations.direction_code != directions.code
        ")
      }
    end

    if ActiveRecord::Base.connection.tables.include?(name)
      arr[:bad_destinations] =
          ActiveRecord::Base.connection.select_value("
            SELECT COUNT(*)
            FROM #{name}
            WHERE f_error = 1
          ").to_i

      if options[:imp_update_dest_names].to_i == 1 && options[:imp_dst] >= 0
        arr[:destinations_to_update] =
            ActiveRecord::Base.connection.select_value("
              SELECT COUNT(*) AS d_all
              FROM #{name}
              WHERE ned_update IN (1, 3, 5, 7)
            ").to_i
      end

      arr[:destinations_to_create] =
          ActiveRecord::Base.connection.select_value("
            SELECT COUNT(*)
            FROM #{name}
            WHERE f_error = 0
                  AND not_found_in_db = 1
          ").to_i

      arr[:new_rates_to_create] =
          ActiveRecord::Base.connection.select_value("
            SELECT COUNT(*) AS r_all
            FROM #{name}
            LEFT JOIN rates ON (col_#{options[:imp_prefix]} = rates.prefix
                                AND rates.tariff_id = #{id})
            WHERE f_error = 0
                  AND rates.id IS NULL
          ").to_i

      arr[:new_destinations_in_csv_file] =
          ActiveRecord::Base.connection.select_value("
            SELECT COUNT(*)
            FROM #{name}
            WHERE not_found_in_db = 1
          ").to_i

      arr[:rates_to_update] =
          ActiveRecord::Base.connection.select_value("
            SELECT COUNT(*)
            FROM (SELECT COUNT(prefix)
                  FROM rates
                  JOIN #{name} ON col_#{options[:imp_prefix]} = rates.prefix
                  WHERE rates.tariff_id = #{id}
                        AND f_error = 0
                  GROUP BY prefix
                 ) sub
          ").to_i

      arr[:zero_rates] =
          ActiveRecord::Base.connection.select_value("
            SELECT COUNT(*)
            FROM #{name}
            WHERE col_#{options[:imp_rate]} #{SqlExport.is_zero_condition}
          ").to_i
    end

    if options[:imp_delete_unimported_prefix_rates].to_i == 1
      all_tariff_rates = Rate.where(tariff_id: id).count
      imported_rates = Rate.where(tariff_id: id).
                            joins("INNER JOIN #{name} ON rates.prefix = #{name}.col_#{options[:imp_prefix]} AND
                                                         f_error = 0")
                            .count
      arr[:rates_to_delete] = all_tariff_rates - imported_rates
    end

    return arr
  end

  def create_deatinations(name, options, options2)
    CsvImportDb.log_swap('create_destinations_start')
    MorLog.my_debug("CSV create_deatinations #{name}", 1)
    count = 0
    # ss is name of columns data is going to be inserted
    # s is select sentence
    # cc is country code
    s, ss, cc = [], [], ''
    ['prefix', 'direction_code', 'name'].each { |col|
      if (options["imp_#{col}".to_sym].present? && options["imp_#{col}".to_sym].to_i > -1) || %w(direction_code).include?(col)
        case col
          when "prefix"
            s << 'DISTINCT(col_' + (options["imp_#{col}".to_sym]).to_s + ')'
          when "direction_code"
            sbg = 'short_prefix'
            cc << (options[:imp_cc].to_i >= 0 ? "IF(col_#{options[:imp_cc]} IN (SELECT code FROM directions),col_#{options[:imp_cc]},#{sbg})" : "#{sbg}")
            s << "#{cc}"
          else
            s << 'col_' + (options["imp_#{col}".to_sym]).to_s
        end
        ss << col
      elsif col == 'name'
        ss << 'name'
        if options[:imp_dst].present? && options[:imp_dst].to_i > -1
        # s[1] here is location of Country Code in temp table, which we find above
          s << "IF(col_#{options[:imp_dst].to_s} = '',
                CONCAT((SELECT name FROM directions WHERE code = #{s[1]} LIMIT 1)) ,
                col_#{options[:imp_dst].to_s})"
        else
          s << " #{name}.destination_name "
        end
      end
    }

    s2 = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE f_country_code = 1 AND f_error = 0 AND not_found_in_db = 1").to_i
    num = s2/1000 +1
    num.times { |i|
      in_rd = "INSERT INTO destinations (#{ss.join(',')})
                SELECT #{s.join(',')} FROM #{name}
                WHERE f_country_code = 1 AND f_error = 0 AND not_found_in_db = 1 LIMIT #{i * 1000}, 1000"
      begin
        Confline.set_value('Destination_create', 1, User.current.id)
        ActiveRecord::Base.connection.execute(in_rd)
        count += ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE f_country_code = 1 AND f_error = 0 AND not_found_in_db = 1 LIMIT #{i * 1000}, 100000").to_i
      ensure
        Confline.set_value('Destination_create', 0, User.current.id)
      end
    }

    if options[:imp_cc] >= 0
      s3 = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE f_country_code = 0 AND f_error = 0 AND not_found_in_db = 1").to_i
      num = s3/1000 +1
      num.times { |i|
        n_rd = "INSERT INTO destinations (#{ss.join(',')})
                  SELECT #{s.join(',')} FROM #{name}
                  WHERE f_country_code = 0 AND f_error = 0 AND not_found_in_db = 1 LIMIT #{i * 1000}, 1000"
        begin
          Confline.set_value('Destination_create', 1, User.current.id)
          ActiveRecord::Base.connection.execute(n_rd)
          count += ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE f_country_code = 0 AND f_error = 0 AND not_found_in_db = 1 LIMIT #{i * 1000}, 1000").to_i
        ensure
          Confline.set_value('Destination_create', 0, User.current.id)
        end
      }
    end
    CsvImportDb.log_swap('create_destinations_end')
    count
  end

  def update_destination_groups(name, options, options2)
    CsvImportDb.log_swap('update_destination_groups_start')
    MorLog.my_debug("CSV update_destination_groups #{name}", 1)
    count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name}").to_i
    sql ="UPDATE destinations
         JOIN #{name} ON (col_#{options[:imp_prefix]} = destinations.prefix)
         JOIN destinationgroups ON flag = LOWER(direction_code)
         SET destinations.destinationgroup_id = destinationgroups.id"

    ActiveRecord::Base.connection.update(sql)
    CsvImportDb.log_swap('update_destination_groups_end')
    count
  end

  def update_directions(name, options, options2)
    CsvImportDb.log_swap('update_directions_start')
    MorLog.my_debug("CSV update_directions #{name}", 1)
    count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE ned_update IN (4, 5, 6, 7)").to_i

    sql ="UPDATE destinations
         JOIN #{name} ON (col_#{options[:imp_prefix]} = destinations.prefix)
         JOIN directions on directions.code = col_#{options[:imp_cc]}
         SET destinations.direction_code = col_#{options[:imp_cc]}
         WHERE ned_update IN (4, 5, 6, 7)"
    ActiveRecord::Base.connection.update(sql)
    CsvImportDb.log_swap('update_directions_end')
    count
  end

  def update_destinations(name, options, options2)
    CsvImportDb.log_swap('update_destinations_start')
    MorLog.my_debug("CSV update_destinations #{name}", 1)
    count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE ned_update IN (1, 3, 5, 7)").to_i
    sql = "UPDATE destinations" +
          " JOIN #{name} ON (col_#{options[:imp_prefix]} = destinations.prefix) " +
          "SET name = replace(TRIM(col_#{options[:imp_dst]}), '  ', ' ') " +
          "WHERE ned_update IN (1, 3, 5, 7) AND replace(TRIM(col_#{options[:imp_dst]}), '  ', ' ') != ''"
    ActiveRecord::Base.connection.update(sql)
    CsvImportDb.log_swap('update_destinations_end')
    count
  end

  def update_rates_from_csv(name, options, options2)
    CsvImportDb.log_swap('update_rates_from_csv_start')
    MorLog.my_debug("CSV update_rates_from_csv #{name}", 1)

    day_type = %w[wd fd].include?(options[:imp_date_day_type].to_s) ? options[:imp_date_day_type].upcase : ''
    type_sql = day_type.blank? ? '' : " AND ratedetails.daytype = '#{day_type.to_s}' "

    # Ratedetails connection_fee
    if options[:manual_connection_fee] && options[:manual_connection_fee].present?
      connection_fee = options[:manual_connection_fee]
    elsif options[:imp_connection_fee].present? && options[:imp_connection_fee].to_i > -1
      connection_fee = "replace(col_#{options[:imp_connection_fee]}, '#{options[:dec]}', '.')"
    else
      connection_fee = 'connection_fee'
    end

    # Ratedetails increment
    if options[:manual_increment] && options[:manual_increment].present?
      increment_s = options[:manual_increment]
    elsif options[:imp_increment_s].present? && options[:imp_increment_s].to_i > -1
      increment_s = "if(col_#{options[:imp_increment_s]} < 1,1,col_#{options[:imp_increment_s]})"
    else
      increment_s = 'increment_s'
    end

    # Ratedetails min_time
    if options[:manual_min_time] && options[:manual_min_time].present?
      min_time = options[:manual_min_time]
    elsif options[:imp_min_time].present? && options[:imp_min_time].to_i > -1
      min_time = "col_#{options[:imp_min_time]}"
    else
      min_time = 'min_time'
    end

    # Ratedetails ghost_percent
    if options[:manual_ghost_percent] && options[:manual_ghost_percent].present?
      ghost_percent = options[:manual_ghost_percent]
    elsif options[:imp_ghost_percent].present? && options[:imp_ghost_percent].to_i > -1
      ghost_percent = "replace(col_#{options[:imp_ghost_percent]}, '\\r', 0)"
      ghost_percent = "IF(#{ghost_percent} REGEXP '^[[:digit:].]+$', #{ghost_percent}, 0)"
    else
      ghost_percent = 'NULL'
    end

    # Rate effective_from
    # Here the magic begins, keep in mind:
    #   * Rate exists with identical imported Rate effective from? - Update existing Rate/Ratedetails;
    #   * Rate exists, but effective from is not identical? - Leave existing Rate/Ratedetails behind and create
    #       (in GUI we call this 'Rate update') new Rate with selected effective from.
    # In addition, there is no way new rates can be created without effective from, it MUST be present
    #   (except for very old rates which never had it, and will never have OR a nasty bug).
    # If effective_rate is not selected to be imported from file or by hand, current import time will be used instead.
    if options[:imp_effective_from].present? # effective_from imported straight from file
      effective_from_column = ', effective_from'
      effective_from_value = "CONVERT_TZ(STR_TO_DATE(col_#{options[:imp_effective_from]}, '#{options[:date_format]}'), '#{options[:current_user_tz]}', '#{local_tz_for_import}')"
      effective_from_field = ", #{effective_from_value}"
    elsif options[:manual_effective_from].present? # effective_from datetime dropdown select or default
      effective_from_column = ', effective_from'
      effective_from_value = "'#{options[:manual_effective_from]}'"
      effective_from_field = ", #{effective_from_value}"
    end

    effective_from_value = "''" if effective_from_value.blank?
    effective_from_condition = effective_from_value.present? ? "AND rates.effective_from = #{effective_from_value}" : ''

    # Rate prefix
    if options[:imp_prefix].present? && options[:imp_prefix].to_i > -1
      prefix = "col_#{options[:imp_prefix]}"
    end

    # Used to update Rates with existing prefixes AND EXISTING (identical) effective from
    sql = "
      UPDATE ratedetails,
             (SELECT rates.id AS nrate_id,
                     #{name}.*
              FROM rates
              JOIN #{name} ON (col_#{options[:imp_prefix]} = rates.prefix #{effective_from_condition})
              WHERE rates.tariff_id = #{id}
                    AND f_error = 0
                    AND not_found_in_db = 0
             ) AS temp
      SET ratedetails.rate = replace(replace(replace(col_#{options[:imp_rate]}, '#{options[:dec]}', '.'), '$', ''), ',', '.'),
          ratedetails.connection_fee = #{connection_fee},
          increment_s = #{increment_s},
          min_time = #{min_time}
      WHERE ratedetails.rate_id = nrate_id #{type_sql}
            AND start_time = '#{options[:imp_time_from_type]}'
            AND end_time = '#{options[:imp_time_till_type]}'
    "
    rates_updated_count = retry_lock_error(3) { ActiveRecord::Base.connection.update(sql) }
    rates_updated_count = rates_updated_count.is_a?(Integer) ? rates_updated_count : 0

    # Used to prevent from adding Rates with same prefix and effective from,
    #   since managing it in Insert Query would require some serious computation and would take more time.
    # Sets In Update Used Prefixes to NULL, So they wouldn't get created again.
    sql = "
      UPDATE rates
      JOIN #{name} ON (col_#{options[:imp_prefix]} = rates.prefix #{effective_from_condition})
      SET col_#{options[:imp_prefix]} = NULL
      WHERE rates.tariff_id = #{id}
            AND f_error = 0
            AND not_found_in_db = 0
    "
    retry_lock_error(3) { ActiveRecord::Base.connection.update(sql) } if rates_updated_count > 0

    # Used to 'update' (actually create) existing Rates with different (not identical) effective from
    sql = "
      INSERT INTO rates (tariff_id, destination_id, ghost_min_perc, prefix #{effective_from_column}, destinationgroup_id)
        SELECT #{id},
               #{name}.destination_id,
               #{ghost_percent},
               #{prefix}
               #{effective_from_field},
               #{name}.destination_group_id
        FROM #{name}
        JOIN (SELECT prefix
              FROM rates
              WHERE tariff_id = #{id}
              GROUP BY prefix
             ) AS rates_new ON (col_#{options[:imp_prefix]} = rates_new.prefix)
        WHERE f_error = 0
              AND new_effective_from = 1
    "
    rates_inserted_count = retry_lock_error(3) { ActiveRecord::Base.connection.update(sql) }
    rates_inserted_count = rates_inserted_count.is_a?(Integer) ? rates_inserted_count : 0

    CsvImportDb.log_swap('update_rates_from_csv_end')
    (rates_inserted_count.to_i + rates_updated_count.to_i)
  end

  def create_rates_from_csv(name, options, options2)
    CsvImportDb.log_swap('create_rates_from_csv_start')
    MorLog.my_debug("CSV create_rates_from_csv #{name}", 1)

    # Rate effective_from
    if options[:imp_effective_from].present? # effective_from imported straight from file
      effective_from_column = ', effective_from'
      effective_from_value = ", CONVERT_TZ(STR_TO_DATE(col_#{options[:imp_effective_from]}, '#{options[:date_format]}'), '#{options[:current_user_tz]}', '#{local_tz_for_import}')"
    elsif options[:manual_effective_from].present? # effective_from datetime dropdown select or default
      effective_from_column = ', effective_from'
      effective_from_value = ",'#{options[:manual_effective_from]}'"
    end

    # Rate ghost_percent
    if options[:manual_ghost_percent] && !options[:manual_ghost_percent].blank?
      ghost_percent = options[:manual_ghost_percent]
    elsif !options[:imp_ghost_percent].blank? && options[:imp_ghost_percent].to_i > -1
      ghost_percent = "col_#{options[:imp_ghost_percent]}"
      ghost_percent = "IF(#{ghost_percent} REGEXP '^[[:digit:].]+$', #{ghost_percent}, 0)"
    else
      ghost_percent = 'NULL'
    end

    # Rate prefix
    if options[:imp_prefix].present? && options[:imp_prefix].to_i > -1
      prefix = "col_#{options[:imp_prefix]}"
    end

    destination_group_id_column = options[:imp_dst].to_i < 0 ? "#{name}.destination_group_id" : 'destinations.destinationgroup_id'

    sql = "
      INSERT INTO rates (tariff_id, destination_id, ghost_min_perc, prefix #{effective_from_column}, destinationgroup_id)
        SELECT #{id},
              destinations.id ,
              #{ghost_percent},
              #{prefix}
              #{effective_from_value},
              #{destination_group_id_column}
        FROM #{name}
        JOIN destinations ON (col_#{options[:imp_prefix]} = destinations.prefix)
        LEFT JOIN rates ON (col_#{options[:imp_prefix]} = rates.prefix
                            AND rates.tariff_id = #{id})
        WHERE rates.id IS NULL
              AND f_error = 0
    "
    rates_created_count = ActiveRecord::Base.connection.update(sql)

    CsvImportDb.log_swap('create_rates_from_csv')
    rates_created_count.to_i
  end

  def insert_ratedetails(name, options, options2)
    CsvImportDb.log_swap('insert_ratedetails_start')
    MorLog.my_debug("CSV insert_ratedetails #{name}", 1)

    option_array, ss = [], []
    %w[rate increment_s min_time connection_fee daytype].each do |col|
      case col
        when 'daytype'
          %w[wd fd].include?(options[:imp_date_day_type].to_s) ? day_type = options[:imp_date_day_type].upcase : day_type = ''
          s1 = day_type.blank? ? "''" : " '#{day_type.to_s}' "
        when 'connection_fee'
          if options[:manual_connection_fee] && options[:manual_connection_fee].present?
            s1 = options[:manual_connection_fee]
          elsif options[:imp_connection_fee].present? && options[:imp_connection_fee].to_i > -1
            s1 = "replace(col_#{options[:imp_connection_fee]}, '#{options[:dec]}', '.')"
          else
            s1 = 0
          end
        when 'increment_s'
          if options[:manual_increment] && options[:manual_increment].present?
            s1 = options[:manual_increment]
          elsif options[:imp_increment_s].present? && options[:imp_increment_s].to_i > -1
            s1 = "if(col_#{options[:imp_increment_s]} < 1,1,col_#{options[:imp_increment_s]})"
          else
            s1 = 1
          end
        when 'min_time'
          if options[:manual_min_time] && options[:manual_min_time].present?
            s1 = options[:manual_min_time]
          elsif options[:imp_min_time].present? && options[:imp_min_time].to_i > -1
            s1 = "col_#{options[:imp_min_time]}"
          else
            s1 = 0
          end
        when 'rate'
          s1 = "replace(replace(col_#{options[:imp_rate]}, '#{options[:dec]}', '.'), '$', '')"
        else
          s1= 'replace(col_' + (options["imp_#{col}".to_sym]).to_s + ", '\\r', '')"
      end

      option_array << s1
      ss << col
    end

    # Ticket #4845 -> I'm not joining Ratedetails based only on rate_id table because it might return more than
    #   1 row for each Rate and in that case multiple new rates might be imported.
    # Instead I'm joining on rate_id, daytype, start/end time to exclude Ratedetails that has to be updated,
    #   not inserted as new.
    # Note that I'm relying 100% that checks were made to ensure that after inserting new Ratedetails there cannot
    #   be any duplications, we should pray for that.

    if options[:imp_effective_from].present? # effective_from imported straight from file
      effective_from_column = ', effective_from'
      effective_from_value = "CONVERT_TZ(STR_TO_DATE(col_#{options[:imp_effective_from]}, '#{options[:date_format]}'), '#{options[:current_user_tz]}', '#{local_tz_for_import}')"
      effective_from_field = ", #{effective_from_value}"
    elsif options[:manual_effective_from].present? # effective_from datetime dropdown select or default
      effective_from_column = ', effective_from'
      effective_from_value = "'#{options[:manual_effective_from]}'"
      effective_from_field = ", #{effective_from_value}"
    end
    effective_from_value = "''" if effective_from_value.blank?
    effective_from_condition = effective_from_value.present? ? "AND rates.effective_from = #{effective_from_value}" : ''

    insert_ratedetails = "
      INSERT INTO ratedetails (rate_id, start_time, end_time, #{ss.join(',')})
        SELECT DISTINCT(rates.id),
              '#{options[:imp_time_from_type]}',
              '#{options[:imp_time_till_type]}',
              #{option_array.join(',')}
        FROM #{name}
        JOIN rates ON (col_#{options[:imp_prefix]} = rates.prefix
                       AND rates.tariff_id = #{id} #{effective_from_condition})
        LEFT JOIN ratedetails on (ratedetails.rate_id = rates.id
                                  AND ratedetails.daytype = '#{(['wd', 'fd'].include?(options[:imp_date_day_type].to_s) ? options[:imp_date_day_type].to_s : '')}'
                                  AND ratedetails.start_time = '#{options[:imp_time_from_type]}'
                                  AND ratedetails.end_time = '#{options[:imp_time_till_type]}')
        WHERE ratedetails.id IS NULL
              AND f_error = 0
    "

    count = 0
    retry_lock_error(3) { count = ActiveRecord::Base.connection.update(insert_ratedetails) }

    CsvImportDb.log_swap('insert_ratedetails_end')
    count.to_i
  end

  def delete_unimported_rates(name, options)
    prefix_loc = "col_#{options[:imp_prefix]}"

    # we need rate_id to delete ratedetails and aratedetails, to delete it by one query, because deleting one by one takes too much time
    rates_to_delete = value_not_present_in_importable_file(name, prefix_loc, 'id')
    rates_to_delete_string = "'" + rates_to_delete.join("','") + "'"
    prefixes_to_delete = "'" + value_not_present_in_importable_file(name, prefix_loc, 'prefix').join("','") + "'"

    sql_to_delete_rates = "DELETE FROM rates WHERE prefix IN (#{prefixes_to_delete}) AND tariff_id = #{id}"
    sql_to_delete_ratedetails =  "DELETE FROM ratedetails WHERE rate_id IN (#{rates_to_delete_string})"
    sql_to_delete_aratedetails = "DELETE FROM aratedetails WHERE rate_id IN (#{rates_to_delete_string})"

    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute(sql_to_delete_rates)
      ActiveRecord::Base.connection.execute(sql_to_delete_ratedetails)
      ActiveRecord::Base.connection.execute(sql_to_delete_aratedetails)
    end

    rates_to_delete.size
  end

  def Tariff.clean_after_import(tname, path = "/tmp/")
    CsvImportDb.clean_after_import(tname, path)
  end


  def csv_import_prefix_analyze(name, options)
    MorLog.my_debug("CSV csv_import_prefix_analyze #{name}", 1)

    # Retrieve direction_codes to hash
    direction_codes = {}
    res = ActiveRecord::Base.connection.select_all("SELECT direction_code, prefix FROM destinations;")
    res.each { |r| direction_codes[r["prefix"]] = r["direction_code"] }

    # Collect already existing destinations
    destination_data = ActiveRecord::Base.connection.select_all("SELECT * FROM destinations")
    present_dsts = Hash[destination_data.map { |row| [ row['prefix'].to_s.gsub(/\s/, ''), row ] }]

    should_update_destination = options[:imp_dst].to_i < 0 # If false destination names will be gathered from file

    # 0 - empty line - skip
    # 1 - everything ok
    # 2 - cc(country_code) = usa
    # 3 - cc from csv
    # 4 - prefix from shorter prefix
    # ERRORS
    # 10 - no cc from csv - can't create destination
    # 11 - bad cc from csv - can't create destination
    # 12 - duplicate

    short_prefix = ''
    longest_maching_prefix = ''
    unique = ''
    bad = []

    new_destinations = ActiveRecord::Base.connection.select_all("SELECT *, #{name}.id AS i_id FROM #{name} WHERE not_found_in_db = 1 AND f_error = 0;")
    MorLog.my_debug("Use temp table : #{name}")

    config   = Rails.configuration.database_configuration
    packed_destinations = {}
    update = {}
    imp_cc = options[:imp_cc]

    # Each prefix that was not found in DB is analysed
    new_destinations.each_with_index { |row, index|
      country_code = row["col_#{imp_cc}"].to_s #country_code
      if country_code.blank? || imp_cc == -1
        # If There is no country code in file or it's not selected, It search for longest maching prefix in database
        prefix = row["col_#{options[:imp_prefix]}"].to_s.strip.gsub(/\s/, '')
        pfound = 0
        plength = prefix.length
        j = 1
        while j < plength && pfound == 0
          tprefix = prefix[0, plength - j]
          pfound = 1 if present_dsts[tprefix].present?
          j += 1
        end

        if pfound == 1
          longest_maching_prefix = tprefix.to_s
          short_prefix = direction_codes[longest_maching_prefix]

          dest = present_dsts[longest_maching_prefix]

          if update[longest_maching_prefix].blank?
            update[longest_maching_prefix] = {}
            update[longest_maching_prefix][unique] = [row['i_id']]
          else
            if update[longest_maching_prefix][unique].blank?
              update[longest_maching_prefix][unique] = [row['i_id']]
            else
              update[longest_maching_prefix][unique] << row['i_id']
            end
          end

          update[longest_maching_prefix][:direction_code] = short_prefix
          update[longest_maching_prefix][:destination_group_id] = dest['destinationgroup_id'].to_i

          if should_update_destination # new destination will be created from file
            update[longest_maching_prefix][:destination_id] = dest['id'].to_i
            update[longest_maching_prefix][:name] = dest['name'].to_s
          end
        else
            bad << row['i_id']
        end
      end
      MorLog.my_debug(index.to_s + ' status/update_rate counted', 1) if index % 1000 == 0
    }

    update.each { |longest_prefix, values_object|
      values_object.except(:destination_id, :name, :destination_group_id, :direction_code).keys.each { |unique|
        table_count = ActiveRecord::Base.connection.select_all("SELECT COUNT(*) AS a FROM information_schema.tables WHERE table_schema = '#{config[Rails.env]["database"]}' AND table_name = '#{name}' LIMIT 1")

        if table_count.first['a'] > 0
          # If destination name is not selected in file
          retry_lock_error(3) { ActiveRecord::Base.connection.execute(Tariff.generate_sql_for_update(update, longest_prefix, unique, name, should_update_destination)) }
        else
          flash[:notice] = _('Tariff_import_failed_please_try_again')
          (redirect_to controller: :tariffs, action: :list) && (return false)
        end
      }
    }

    if bad && bad.size.to_i > 0
      table_count = ActiveRecord::Base.connection.select_all("SELECT COUNT(*) AS a FROM information_schema.tables  WHERE table_schema = '#{config[Rails.env]["database"]}' AND table_name = '#{name}' LIMIT 1")
      if table_count.first['a'] > 0
        # set error flag on not int prefixes | code : 13
        ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 10 WHERE id IN (#{bad.join(',')})")
      else
        flash[:notice] = _('Tariff_import_failed_please_try_again')
        (redirect_to controller: :tariffs, action: :list) && (return false)
      end
    end
  end

  def able_to_delete?
    #check for providers
    if providers.count > 0 || sms_providers.count > 0
      providers_for_messages = []
      message = _("It_is_used_by_some_Providers")
      providers.try(:each) do |prov|
        providers_for_messages << " <a href='#{Web_Dir}/providers/edit/#{prov.id}'>#{prov.name}</a>"
      end
      sms_providers.try(:each) do |prov|
        providers_for_messages << " <a href='#{Web_Dir}/sms/provider_edit/#{prov.id}'>#{prov.name}</a>"
      end
      message << providers_for_messages.join(',')
      errors.add(:provider_error, message)
    end
    # check for cardgroups
    cardgroup = cardgroups.count
    if cardgroup > 0
      cardgroups_for_messages = []
      message = _("It_is_used_by_some_Card_Groups")
      cardgroups.each do |card_group|
        cardgroups_for_messages << " <a href='#{Web_Dir}/cardgroups/edit/#{card_group.id}'>#{card_group.name}</a>"
      end
      message << cardgroups_for_messages.join(',')
      errors.add(:cardgroups_error, message)
    end
    #check for users
    sms_users = User.where(sms_tariff_id: id)
    if users.count > 0 || sms_users.count > 0
      users_for_messages = []
      message = _("It_is_used_by_some_Users")
      users.try(:each) do |user|
        users_for_messages << " <a href='#{Web_Dir}/users/edit/#{user.id}'>#{user.nice_name}</a>"
      end
      sms_users.try(:each) do |user|
        users_for_messages << " <a href='#{Web_Dir}/sms/edit_user/#{user.id}'>#{user.nice_name}</a>"
      end
      message << users_for_messages.join(',')
      errors.add(:users_error, message)
    end
    #check for locationrules
    lrules = locationrules.count
    if lrules > 0
      locations_messages = []
      message = _("It_is_used_by_some_Location_Rules")
      locationrules.each do |locationrule|
        locations_messages << " <a href='#{Web_Dir}/locations/location_rule_edit/#{locationrule.id}'>#{locationrule.name}</a>"
      end
      message << locations_messages.join(',')
      errors.add(:location_rules_error, message)
    end
    #check for OP
    opts = origination_points.count
    if opts > 0
      message = _('device_op_are_using_this_tariff_cant_delete')
      errors.add(:op_error, message)
    end
    #check for TP
    tpts = termination_points.count
    if tpts > 0
      message = _('device_tp_are_using_this_tariff_cant_delete')
      errors.add(:tp_error, message)
    end
    comm_use_prov_table = common_use_providers.count
    if comm_use_prov_table > 0
      message = _('common_use_providers_are_using_this_tariff_cant_delete')
      errors.add(:comm_use_prov_error, message)
    end

    errors.messages.empty?
  end

  def self.find_by_user(user_id)
    Tariff.where("owner_id = #{user_id} ").order("name ASC")
  end

  def updated
    self.last_update_date = Time.now
    self.save
  end

  # generates sql for update destination_id, destination_group_id and destination_name fields in temp rates import table
  def self.generate_sql_for_update(update, s_prefix, unique, name, update_destination = true)
    all_id = update[s_prefix][unique].map { |id| id }.join ','
    base_update = "UPDATE #{name} SET f_country_code = 1, short_prefix = '#{update[s_prefix][:direction_code]}', destination_group_id = #{update[s_prefix][:destination_group_id]} "

    if update_destination # If update destination is false, information will be gathered from file
      destination_name = ActiveRecord::Base.connection.quote(update[s_prefix][:name])
      base_update += ", destination_id = #{update[s_prefix][:destination_id]}, destination_name = #{destination_name}"
    end

    base_update += " WHERE id IN (#{all_id})"
    base_update
  end

  def update_time
    self.last_update_date = Time.now
    self.save
  end

  def self.system_stats
    {
        total: self.count,
        provider: self.where(purpose: 'provider').count,
        user: self.where(purpose: 'user').count,
        user_wholesale: self.where(purpose: 'user_wholesale').count
    }
  end

  private

  def get_user_rate_details(rate, exrate)
    arate_details = Aratedetail.where("rate_id = #{rate.id.to_s} AND artype = 'minute'").order("price DESC").all
    arate_cur = Currency.count_exchange_prices({:exrate => exrate, :prices => [arate_details[0]['price'].to_d]}) if arate_details.size > 0
    [arate_details, arate_cur]
  end

  def nice_date_time(time, session, current_user=nil, ofset=1)
    if time
      format = (session and !session[:date_time_format].to_s.blank?) ? session[:date_time_format].to_s : "%Y-%m-%d %H:%M:%S"
      real_time = time.respond_to?(:strftime) ? time : time.to_time

      if ofset.to_i == 1
        (session and current_user) ? current_user.user_time(real_time).strftime(format.to_s) : real_time.strftime(format.to_s)
      else
        real_time.strftime(format.to_s)
      end
    else
      ''
    end
  end

  def nice_number(number, session)
    if !session[:nice_number_digits]
      confline = Confline.get_value("Nice_Number_Digits")
      session[:nice_number_digits] ||= confline.to_i if confline and confline.to_s.length > 0
      session[:nice_number_digits] ||= 2 if !session[:nice_number_digits]
    end
    session[:nice_number_digits] = 2 if session[:nice_number_digits] == ""
    num = ""
    num = sprintf("%0.#{session[:nice_number_digits]}f", number.to_d) if number
    if session[:change_decimal]
      num = num.gsub('.', session[:global_decimal])
    end
    num
  end

  def get_provider_rate_details(rate, exrate)
    rate_details = Ratedetail.where(["rate_id = ?", rate.id]).order("rate DESC").all

    if rate_details.size > 0
      rate_increment_s = rate_details[0]['increment_s']
      rate_cur, rate_free = Currency.count_exchange_prices({:exrate => exrate, :prices => [rate_details[0]['rate'].to_d, rate_details[0]['connection_fee']]})
    end

    return rate_details, rate_cur
  end

  def local_tz_for_import
    Time.now.formatted_offset
  end

  def self.tariffs_for_device(current_user_id)
    Tariff.where("purpose = 'provider' OR purpose = 'user_wholesale' AND owner_id = #{current_user_id}")
          .order('name ASC').all
  end

  def value_not_present_in_importable_file(name, prefix_loc, return_value)
    sql = "SELECT rates.#{return_value}
           FROM rates
           LEFT JOIN #{name} ON rates.prefix = #{name}.#{prefix_loc}
           WHERE #{name}.#{prefix_loc} IS NULL AND rates.tariff_id = #{id}"
    ActiveRecord::Base.connection.select_values(sql)
  end
end
#module ActiveRecord
#  module ConnectionAdapters
#    class MysqlAdapter
#      private
#      def connect_with_local_infile
#        @connection.options(Mysql::OPT_LOCAL_INFILE, 1)
#        connect_without_local_infile
#      end
#      alias_method_chain :connect, :local_infile
#    end
#  end
#end
