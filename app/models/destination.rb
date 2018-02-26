# -*- encoding : utf-8 -*-
class Destination < ActiveRecord::Base
  include UniversalHelpers

  attr_accessible :id, :prefix, :direction_code, :name
  attr_accessible :destinationgroup_id

  attr_protected

  has_many :rates
  has_many :flatrate_destinations, :dependent => :destroy
  has_many :calls, ->(prefix) { where(prefix: prefix) }
  belongs_to :destinationgroup
  belongs_to :direction, :foreign_key => 'direction_code', :primary_key => 'code'

  validates_uniqueness_of :prefix
  validates_presence_of :prefix, :direction_code, :name

  after_save :update_destinationgroup_id
  before_destroy :dest_before_destroy

  def update_destinationgroup_id
    if self.destinationgroup_id_changed?
      Rate.where("destination_id = #{self.id}").update_all(destinationgroup_id: self.destinationgroup_id)
    end
  end

  def dest_before_destroy
    th = Thread.new { @call = Call.select('id').where("prefix = '#{prefix}'").first; ActiveRecord::Base.connection.close }
    used_prefix = rates.pluck(:prefix)

    if rates.size > 0
      errors.add(:rates, _("rates_exist") + ": " + used_prefix.join(' '))
      return false
    end

    th.join
    if @call
      errors.add(:calls, _("calls_to_this_destination_exist") + ": " + prefix)
      return false
    end

  end

  def update_by(params)
    updated = false
    if params[('dg' + self.id.to_s).intern] and params[('dg' + self.id.to_s).intern].length > 0
        self.destinationgroup_id = params[("dg#{id}").intern]
        rates = Rate.where("destination_id = #{self.id}").update_all(destinationgroup_id: destinationgroup_id)
        updated = true
    end
    updated
  end

  def direction
    Direction.where(code: self.direction_code).order("name ASC").first
  end

  def calls
    Call.where(prefix: prefix).all
  end

  def sms_rates(tariff)
    SmsRate.where(prefix: prefix,sms_tariff_id: tariff.id).first
  end

  def Destination.auto_assignet_to_dg
    begining_of_sql = 'UPDATE destinations ' +
      'LEFT JOIN destinationgroups ON (destinationgroups.flag = destinations.direction_code ) ' +
      'LEFT JOIN rates ON (destinations.id = rates.destination_id) ' +
      'SET destinations.destinationgroup_id = destinationgroups.id, rates.destinationgroup_id = destinationgroups.id WHERE destinations.destinationgroup_id = 0 AND '
    sql = "#{begining_of_sql}destinations.direction_code != ''"
    retry_lock_error(3) { ActiveRecord::Base.connection.execute(sql) }
    sql2 = "#{begining_of_sql}destinations.name LIKE '%MOB%' AND destinations.direction_code != ''"
    retry_lock_error(3) { ActiveRecord::Base.connection.execute(sql2) }
    sql3 = "#{begining_of_sql}destinations.name LIKE '%NGN%' AND destinations.direction_code != ''"
    retry_lock_error(3) { ActiveRecord::Base.connection.execute(sql3) }
    sql4 = "#{begining_of_sql}destinations.name LIKE '%FIX%' AND destinations.direction_code != ''"
    retry_lock_error(3) { ActiveRecord::Base.connection.execute(sql4) }
    sql5 = "#{begining_of_sql}destinations.direction_code != ''"
    retry_lock_error(3) { ActiveRecord::Base.connection.execute(sql5) }
  end

  def Destination.select_destination_assign_dg(page, order)
    limit = Confline.get_value('Items_Per_Page').to_i
    offset = limit*(page-1)

    sql = "SELECT * FROM (
            SELECT * FROM (
              SELECT * FROM (
                SELECT destinations.id, prefix, destinations.name, destinationgroups.id AS dgid, destinationgroups.name AS dgn, direction_code, 1 AS p FROM destinations
                  JOIN destinationgroups ON (flag = direction_code )
                  WHERE destinationgroup_id = 0 AND destinations.name = destinationgroups.name
                  GROUP BY id ORDER BY direction_code) AS v1
              UNION
              SELECT * FROM (
                SELECT destinations.id, prefix, destinations.name, destinationgroups.id AS dgid, destinationgroups.name AS dgn, direction_code, 2 AS p FROM destinations
                  JOIN destinationgroups ON (flag = direction_code  )
                  WHERE destinationgroup_id = 0 AND destinations.name REGEXP 'MOB|special|premium|proper'
                  GROUP BY id ORDER BY direction_code) AS v2
              UNION
              SELECT * FROM (
                SELECT destinations.id, prefix, destinations.name, destinationgroups.id AS dgid, destinationgroups.name AS dgn, direction_code, 3 AS p FROM destinations
                  JOIN directions ON (directions.code = destinations.direction_code)
                  JOIN destinationgroups ON (flag = direction_code  )
                  WHERE destinationgroup_id = 0 AND  destinationgroups.name = directions.name
                  GROUP BY id ORDER BY direction_code) AS v3
            ) AS v4 ORDER BY p ASC
          ) AS v5 GROUP BY id ORDER BY #{order}, id LIMIT #{limit} OFFSET #{offset}"

    Destination.find_by_sql(sql)
  end

=begin
  Renames all destination names that have certaint prefix pattern.

  *Params*
  name - destination name, may be blank. if logner than 255 symbols, name will be truncated
  prefix - prefix pattern. Hybrid of mysql's REGEXP and LIKE
=end
  def self.rename_by_prefix(name, prefix)
    update = "name = ?", name.to_s
    condition = prefix_pattern_condition(prefix)
    Destination.where(condition).update_all(update)
  end

=begin
  Finds all destinations that match supplied prefix pattern

  *Params*
  prefix - prefix pattern. Hybrid of mysql's REGEXP and LIKE

  *Returns*
  destinations - array containing all found destinations
=end
  def self.dst_by_prefix(prefix)
    condition = prefix_pattern_condition(prefix)
    includes(:destinationgroup).where(condition).order('prefix ASC').all
  end

=begin
  *Params*
  prefix - prefix pattern. Hybrid of mysql's REGEXP and LIKE

  *Returns*
  condition - condition with regular expression
=end
  def self.prefix_pattern_condition(prefix)
    condition = "prefix REGEXP ?", prefix_pattern(prefix)
  end

=begin
  Deletes % if it is supplied in pattern, because this is not a metacharacter
  of regexp and supplied pattern is hybrid of mysql's REGXEP and LIKE.
  if you would pass prefix X, search would look for pattern Y:
  12%3 -> ^123(thats a system wide feature, heck knows why. AJ)
  123% -> ^123
  %123 -> ^123(thats a system wide feature, heck knows why. AJ)
  123  -> ^123$
=end
  def self.prefix_pattern(prefix)
    '^' + (prefix.to_s.include?('%') ? prefix.to_s.delete('%') : prefix.to_s + '$')
  end

  def get_direction(service_id, servicetype = 'flat_rate')
    if FlatrateDestination.where(["destination_id = ? AND service_id = ?", self.id, service_id]).first
      message = servicetype == 'dynamic_flat_rate' ? _('Destination_already_in_dynamic_flatrate') : _('Destination_already_in_flatrate')
    else
      direction = nil
      direction = self.direction
      if direction
        results = direction.name.to_s + " " + self.name.to_s
      end
    end
    return direction, results, message
  end

  # It's possible to pass single prefix, or prefix list in string separated by ','
  # Returns Active Record Relation object, Not Exact destinations
  def self.find_with_direction(prefix)
    if prefix.present?
      Destination.joins(:direction).
        select('destinations.*, destinations.name AS destination_name, directions.name AS direction_name').
        where("prefix IN (#{prefix})").order('prefix DESC')
    else
      nil
    end
  end

  # Executes the given block +retries+ times (or forever, if explicitly given nil),
  # catching and retrying SQL Deadlock errors.
  def self.retry_lock_error(retries = 3, &block)
    begin
      yield
    rescue ActiveRecord::StatementInvalid => e
      if e.message =~ /Deadlock found when trying to get lock/ and (retries.nil? || retries > 0)
        retry_lock_error(retries ? retries - 1 : nil, &block)
      else
        MorLog.my_debug("#{e.message}")
      end
    end
  end

  def self.find_destination_group(prefix)
    return nil if prefix.empty?
    destination = Destination.where(prefix: prefix).first
    if destination
      destination_group = destination.destinationgroup
      return destination_group if destination_group
    end
    find_destination_group(prefix[0...-1])
  end

  def self.count_without_group
    Destination.where(destinationgroup_id: 0).count.to_i
  end
end
