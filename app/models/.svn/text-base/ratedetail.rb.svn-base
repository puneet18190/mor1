# -*- encoding : utf-8 -*-
class Ratedetail < ActiveRecord::Base
  attr_protected

  def Ratedetail.find_all_from_id_with_exrate(options={})
    options_rates = options[:rates]
    options_exrate = options[:exrate]
    options_directions = options[:directions]
    options_destinations = options[:destinations]

    if options_rates and options_rates.size.to_i > 0
      sql = "SELECT ratedetails.*, rate * #{options_exrate.to_d} as erate, connection_fee * #{options_exrate.to_d} as conee #{', directions.*' if options_directions}  #{', directions.name as dname' if options_directions} #{', destinations.*' if options_destinations} FROM ratedetails join rates on (rates.id = ratedetails.rate_id) join destinations on (rates.destination_id = destinations.id) join directions on (destinations.direction_code = directions.code) where rate_id in (#{(options_rates.collect { |r| r.id }).join(' , ')}) ORDER BY directions.name ASC, destinations.prefix ASC, ratedetails.daytype DESC, ratedetails.start_time ASC, rates.id  ASC"
      ratesd = Ratedetail.find_by_sql(sql)
      return ratesd
    end
  end

  def self.find_active_rates(options={})
    options_exrate = options[:exrate]
    options_directions = options[:directions]
    options_destinations = options[:destinations]
    items_per_page = options[:items_per_page]
    options_tax = options[:tax]
    offset = options[:offset]
    s_prefix = options[:s_prefix]
    prefix_cond = " AND prefix LIKE #{ActiveRecord::Base::sanitize(s_prefix)}" if s_prefix.present?
    limit_offset = "LIMIT #{items_per_page} OFFSET #{offset}" if items_per_page && offset
      sql = "SELECT destinations.name AS destination, A.*
                    #{', directions.code' if options_directions}
                    #{', directions.name as dname' if options_directions}
                    #{', destinations.prefix, destinations.name' if options_destinations}
            FROM (SELECT rate * #{options_exrate.to_d} * #{options_tax} as erate,
                    connection_fee * #{options_exrate.to_d} * #{options_tax} as conee,
                    destination_id,prefix, ratedetails.rate_id,
                    ratedetails.increment_s, ratedetails.start_time, ratedetails.end_time, ratedetails.daytype
                 FROM rates
                 LEFT JOIN ratedetails ON ratedetails.rate_id = rates.id
                 WHERE rates.tariff_id = #{options[:tariff_id]} AND (effective_from <= NOW() OR effective_from IS NULL)#{prefix_cond}
                 ORDER BY rates.destination_id, rates.effective_from DESC) A
             LEFT JOIN destinations on A.destination_id = destinations.id
             LEFT JOIN directions on direction_code = directions.code
             WHERE destinations.name LIKE #{ActiveRecord::Base::sanitize(options[:st]+'%')}
             GROUP BY A.prefix
             ORDER BY directions.name ASC, destinations.prefix ASC #{limit_offset};"
      ratesd = Ratedetail.find_by_sql(sql)
      return ratesd
  end

  def combine_work_days
  	combine_day_type('WD')
  end

  def combine_free_days
    combine_day_type('FD')
  end

  def split
  	new_rate_detail = Ratedetail.new(attributes)
    new_rate_detail.daytype = 'FD'
    new_rate_detail.save

    self.daytype = 'WD'
    save
  end

  def combine_day_type(day_type)
  	if daytype == day_type
      self.daytype = ''
      save
    else
      destroy
    end
  end

  def action_on_change(user)
    return if previous_changes.empty?
    Action.ratedetail_change(user, self)
  end
end
