# -*- encoding : utf-8 -*-
# I'm not sure why it has ActiveRecord relation, we don't have stats table...
class Stat < ActiveRecord::Base
  attr_protected

  def self.find_rates_and_tariffs_by_number(user_id, phrase, tariff_list)
    tariff_clause = tariff_list.present? ? "tariffs.id IN (#{tariff_list})" : "tariffs.owner_id = #{user_id}"
    collided_prefix = "'#{phrase.join("', '")}'"
    sql =
    "
      -- User wholesale and provider rates
      SELECT
        rates.id AS rate_id,
        rates.prefix AS prefix,
        tariffs.purpose AS purpose,
        tariffs.id AS tariffs_id,
        tariffs.name AS tariffs_name,
        tariffs.currency AS currency,
        destinations.direction_code AS direction_code,
        destinations.name AS name,
        ratedetails.id AS ratedetails_id,
        ratedetails.rate AS rate,
        ratedetails.start_time AS start_time,
        ratedetails.end_time AS end_time,
        ratedetails.connection_fee AS connection_fee,
        rates.effective_from AS effective_from,
        NULL AS price,
        NULL AS arate_daytype,
        NULL AS arate_start_time,
        NULL AS arate_end_time
      FROM rates
      INNER JOIN tariffs ON (
        rates.tariff_id = tariffs.id
        AND (tariffs.purpose = 'provider' OR tariffs.purpose = 'user_wholesale')
        AND #{tariff_clause}
      )
      INNER JOIN (
        SELECT DISTINCT
          ALL_MATCHING_RATES.tariff_id,
          ALL_MATCHING_RATES.destination_id
        FROM
          ( SELECT
            tariffs.id AS tariff_id,
            rates.id AS rate_id,
            rates.destination_id,
            rates.effective_from,
            rates.prefix
          FROM tariffs
          INNER JOIN rates ON (
            rates.prefix IN (#{collided_prefix})
            AND rates.tariff_id = tariffs.id
          )
          WHERE #{tariff_clause}
          ORDER BY
            LENGTH(rates.prefix) DESC, rates.effective_from DESC ) AS ALL_MATCHING_RATES
        GROUP BY tariff_id
        ) AS LONGEST_PREFIX_DSTS ON (
          rates.tariff_id = LONGEST_PREFIX_DSTS.tariff_id
          AND rates.destination_id = LONGEST_PREFIX_DSTS.destination_id
        )
        JOIN ratedetails ON ratedetails.rate_id = rates.id
        LEFT JOIN destinations ON destinations.id = LONGEST_PREFIX_DSTS.destination_id

      UNION

      -- Retail rates
      SELECT *
      FROM (SELECT * FROM (
        SELECT rates.id AS rate_id,
          destinations.prefix AS prefix,
          tariffs.purpose AS purpose,
          tariffs.id AS tariffs_id,
          tariffs.name AS tariffs_name,
          tariffs.currency AS currency,
          destinations.direction_code AS direction_code,
          destinations.name AS name,
          aratedetails.id AS ratedetails_id,
          NULL AS rate,
          NULL AS start_time,
          NULL AS end_time,
          NULL AS effective_from,
          NULL AS connection_fee,
          aratedetails.price AS price,
          aratedetails.daytype AS arate_daytype,
          aratedetails.start_time AS arate_start_time,
          aratedetails.end_time AS arate_end_time
        FROM rates
          LEFT JOIN aratedetails ON (aratedetails.rate_id = rates.id)
          JOIN destinationgroups ON (destinationgroups.id = rates.destinationgroup_id)
          JOIN (
            SELECT destinations.*
            FROM destinations
            WHERE destinations.destinationgroup_id != 0 AND destinations.prefix IN (#{collided_prefix})
          ORDER BY LENGTH(destinations.prefix) DESC
        ) AS ALL_MATCHING_RATES ON (
          ALL_MATCHING_RATES.destinationgroup_id = destinationgroups.id
        )
        JOIN tariffs ON (rates.tariff_id = tariffs.id AND tariffs.purpose = 'user' AND #{tariff_clause})
        LEFT JOIN destinations ON (
          destinations.destinationgroup_id = rates.destinationgroup_id
          AND destinations.prefix IN (#{collided_prefix})
        )
      ORDER BY LENGTH(destinations.prefix) DESC) A GROUP BY ratedetails_id) AS LONGEST_PREFIX_DSTS
      GROUP BY LONGEST_PREFIX_DSTS.ratedetails_id
      ORDER BY purpose, tariffs_name;
    "
    ActiveRecord::Base.connection.select_all(sql)
  end

  def self.find_services_for_profit(reseller, a1, a2, responsible_accountant_id, user_id)
    user_sql2 = ''
    user_sql2 = " AND subscriptions.user_id IN (SELECT users.id FROM `users` JOIN users tmp " +
                    "ON(tmp.id = users.responsible_accountant_id) WHERE tmp.id = '#{responsible_accountant_id}')" if responsible_accountant_id != -1
    user_sql2 = " AND subscriptions.user_id = '#{user_id}' " if user_id != -1

    if !reseller
      price = 0
      sql = "SELECT users.id, subscriptions.*, " +
            " services.servicetype, services.periodtype, services.quantity, " +
            "#{SqlExport.replace_price('(services.price - services.selfcost_price)', {:reference => 'price'})} " +
            "FROM subscriptions " +
            "JOIN services ON (services.id = subscriptions.service_id) " +
            "JOIN users ON (users.id = subscriptions.user_id) " +
            "WHERE ((activation_start < '#{a1}' AND (activation_end > '#{a1}' OR activation_end IS NULL)) OR " +
            "(activation_start BETWEEN '#{a1}' AND '#{a2}' AND (activation_end >'#{a1}' OR activation_end IS NULL)))" +
            " #{user_sql2} group by subscriptions.id"
      res = ActiveRecord::Base.connection.select_all(sql)
    else
      res = []
    end

    res
  end

  def self.find_subs_params(res, a1, a2, sub_price)
    if res and res.size > 0
      res.each do |r|
        activation_start = r['activation_start']
        activation_start_to_date = r['activation_start'].to_date
        activation_end = r['activation_end']
        activation_end_to_date = r['activation_end'].try(:to_date)
        periodtype = r['periodtype'].to_s
        periodtype_is_day = (periodtype == 'day')
        periodtype_is_month = (periodtype == 'month')
        servicetype = r['servicetype'].to_s
        r_price = r['price'].to_d
        quantity_to_dec = r['quantity'].to_d
        price = 0

        if !activation_end_to_date.blank? && (activation_start_to_date > a1.to_date) && (activation_end_to_date < a2.to_date)
          sub_days = Stat.find_sub_days(activation_start, activation_end)
          price = Stat.find_price_if_day(price, sub_days, servicetype, r_price, quantity_to_dec) if periodtype_is_day
          price = Stat.find_price_if_month(price, servicetype, r_price, activation_start, activation_end, quantity_to_dec) if periodtype_is_month
        else
          use_start = (activation_start_to_date <= a1.to_date) ? a1.to_date : activation_start_to_date
          use_end = (activation_end_to_date.blank? || activation_end_to_date >= a2.to_date) ? a2.to_date : activation_end_to_date

          sub_days = Stat.find_sub_days(use_start, use_end)
          price = Stat.find_price_if_day(price, sub_days, servicetype, r_price, quantity_to_dec) if periodtype_is_day
          price = Stat.find_price_if_month(price, servicetype, r_price, use_start, use_end, quantity_to_dec) if periodtype_is_month
        end
        sub_price += price.to_d
      end
    end

    return sub_price
  end

  def self.find_price_if_day(price, sub_days, servicetype, r_price, quantity_to_dec)
    quantity = sub_days / quantity_to_dec
    days = sub_days % quantity_to_dec

    price = (r_price * quantity.to_i) if servicetype == 'activation_from_registration'
    price = r_price if servicetype == 'one_time_fee'
    price = ((r_price / quantity_to_dec) * days.to_i).to_d + ((r_price * quantity.to_d)).to_d if ((servicetype == 'periodic_fee') || (servicetype == 'flat_rate'))

    return price
  end

  def self.find_price_if_month(price, servicetype, r_price, activation_start, activation_end, quantity_to_dec)
    y = activation_end.to_time.year - activation_start.to_time.year
    m = activation_end.to_time.month - activation_start.to_time.month
    months = y.to_i * 12 + m.to_i
    quantity = months / quantity_to_dec
    days = (activation_end.to_time.day - activation_start.to_time.day) + 1

    price = r_price * quantity.to_i if servicetype == 'activation_from_registration'
    price = r_price if servicetype == 'one_time_fee'

    if (servicetype == 'periodic_fee') || (servicetype == 'flat_rate')
      if days < 0
        quantity = quantity - 1
        days = activation_start.to_time.day + days
      end

      price = ((r_price / activation_end.to_time.end_of_month().day.to_i.to_d) * days.to_i).to_d + ((r_price * quantity.to_d)).to_d
    end

    return price
  end

  def self.find_sub_days(sub_start, sub_end)
    sub_days = sub_end.to_time - sub_start.to_time
    sub_days = (((sub_days / 60) / 60) / 24)

    return sub_days
  end
end
