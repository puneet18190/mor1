# -*- encoding : utf-8 -*-
class Subscription < ActiveRecord::Base

  attr_protected

  belongs_to :user
  belongs_to :service
  has_many :flatrate_datas, dependent: :delete_all

  validate :subscription_interval_valid
  validate :subscription_start_valid

  before_save :s_before_save
  after_create :generate_flatrate_datas

  def subscription_interval_valid
    servicetype = service.try(:servicetype).to_s

    if servicetype != 'one_time_fee' && activation_end.present? && activation_start >= activation_end
      if servicetype == 'dynamic_flat_rate' && activation_start.strftime('%Y%m') == activation_end.strftime('%Y%m')
        errors.add(:activation_end, _('Activation_end_date_must_be_higher_by_at_least_one_month'))
      else
        errors.add(:activation_end, _('activation_start_after_activation_end'))
      end
    end
  end

  def subscription_start_valid

    user_registered = 0
    user_registered = user.registered_at.try(:at_beginning_of_month).strftime("%Y-%m-%d %H:%M:%S").to_time.to_i if (user and user.registered_at)
    unless user_registered <= activation_start.strftime("%Y-%m-%d %H:%M:%S").to_time.to_i
      errors.add(:activation_start, _('activation_start_before_user_created'))
    end
  end

  def s_before_save
    if service.servicetype == "one_time_fee"
      self.activation_end = self.activation_start
    end
  end

  def activation_start=(value)
    value = (value.respond_to?(:strftime) ? value.strftime('%F %H:%M:%S') : value)
    write_attribute(:activation_start, value)
  end

  def activation_end=(value)
    value = (value.respond_to?(:strftime) ? value.strftime('%F %H:%M:%S') : value)
    write_attribute(:activation_end, value)
  end

  def time_left
    time = Time.now
    out = 0
    if (time > activation_start if activation_start.present?) and (activation_end.blank? or time < activation_end or no_expire == 1)
      year_month = time.strftime("%Y-%m")
      data = if no_expire == 1
               FlatrateData.where(subscription_id: id).last
             else
               if service.servicetype == 'dynamic_flat_rate'
                 FlatrateData.where("subscription_id = #{id} AND period_start <= '#{time}' AND period_end >= '#{time}'").first
               else
                 FlatrateData.where(year_month: year_month, subscription_id: id).first
               end
             end
      out = data.seconds.to_i if data
      out = service.quantity.to_i * 60 - out
    end
    out
  end

  def time_left= (value)
    time = Time.now
    if service.servicetype == "one_time_fee" and time > activation_start and (activation_end.blank? or time < activation_end)
      datas = flatrate_datas(:conditions => ["year_month = ?", time.strftime("%Y-%m")])
      datas.each { |data|
        data.minutes = service.quantity.to_i - value
        data.save
      }
    end
  end

=begin
  lets try to figure out what this method is ment to do..
  When one passes period of time(start & end date), this method
  calculates intersection of period passed and its activation
  period.
  Seems like it is ment to calculate period when subscription
  was active, but only in period that one passed to this method

  For instance if we have two periods
  activation period: 1-------------------3
  period passed:            2--------------------------------4
  method will return period starting from 2 to 3.

  Note that there is a bug when periods do no intersect
  activation period: 1------2
  period passed:                3----------------------------4
  method will return period starting from 3 to 2(OMG!!)
=end
  def subscription_period(period_start, period_end)
    use_start = (activation_start < period_start ? period_start : activation_start)
    use_end = ((activation_end.blank? or (activation_end > period_end)) ? period_end : activation_end)
    return use_start.to_date, use_end.to_date
  end

  def price_for_period(period_start, period_end)
    period_start = period_start.to_s.to_time if period_start.class == String
    period_end = period_end.to_s.to_time if period_end.class == String

    # not counting price if subscriptins starts later than this month
    if (!activation_end.blank? && ((activation_end < period_start) || (period_end < activation_start))) ||
      (activation_end.blank? && (period_end < activation_start))
      return 0
    end

    total_price = 0

    case service.servicetype
      when 'flat_rate', 'dynamic_flat_rate'
        start_date, end_date = subscription_period(period_start, period_end)
        days_used = end_date - start_date
        if start_date.month == end_date.month && start_date.year == end_date.year
          total_price = service.price
        else
          total_price = 0
          if months_between(start_date, end_date) > 1
            # jei daugiau nei 1 menuo. Tarpe yra sveiku menesiu kuriem nereikia papildomai skaiciuoti intervalu
            total_price += (months_between(start_date, end_date)-1) * service.price
          end
          #suskaiciuojam pirmo menesio pabaigos ir antro menesio pradzios datas
          last_day_of_month = start_date.to_time.end_of_month.to_date
          last_day_of_month_date = end_date.to_time.end_of_month.to_date
          total_price += service.price
          total_price += service.price/last_day_of_month_date.day * (end_date.day)
        end
      when 'one_time_fee'
        if activation_start >= period_start && activation_start <= period_end
          total_price = service.price
        end
      when 'periodic_fee'
        start_date, end_date = subscription_period(period_start, period_end)
        days_used = end_date - start_date
        #if periodic fee if daily month should be the same every time and
        #if condition should evaluate to true every time
        if start_date.month == end_date.month && start_date.year == end_date.year
          if self.service.periodtype == 'month'
            total_days = start_date.to_time.end_of_month.day.to_i
            total_price = service.price / total_days * (days_used.to_i+1)
          elsif self.service.periodtype == 'day'
            total_price = service.price * (days_used.to_i+1)
          end
        else
          total_price = 0

          if months_between(start_date, end_date) > 1
            # jei daugiau nei 1 menuo. Tarpe yra sveiku menesiu kuriem nereikia papildomai skaiciuoti intervalu
            total_price += (months_between(start_date, end_date)-1) * service.price
          end
          #suskaiciuojam pirmo menesio pabaigos ir antro menesio pradzios datas
          last_day_of_month = start_date.to_time.end_of_month.to_date
          last_day_of_month_date = end_date.to_time.end_of_month.to_date
          total_price += service.price/last_day_of_month.day * (last_day_of_month - start_date+1).to_i
          total_price += service.price/last_day_of_month_date.day * (end_date.day)
        end
    end

    total_price
  end

  #Counts amount of money to be returned for the rest of current month
  def return_for_month_end
    amount = 0
    case service.servicetype
      when 'flat_rate', 'dynamic_flat_rate'
        period_start = Time.now
        period_end = Time.now.end_of_month.change(:hour => 23, :min => 59, :sec => 59)
        start_date, end_date = subscription_period(period_start, period_end)
        days_used = end_date - start_date
        total_days = start_date.to_time.end_of_month.day
        service_price = (service.price.nil? ? 0 : service.price)
        amount = (service_price / total_days.to_i) * (days_used.to_i + 1)
      when 'one_time_fee'
        amount = price_for_period(Time.now, Time.now.end_of_month.change(:hour => 23, :min => 59, :sec => 59)).to_d
      when 'periodic_fee'
        if service.periodtype == 'day'
          amount = Action.where(["action = 'subscription_paid' AND user_id = ? AND data >= ? AND target_id = ?", self.user_id, "#{Time.now.year}-#{Time.now.month}-#{'1'}", self.id]).sum(:data2)
        else
          amount = price_for_period(Time.now, Time.now.end_of_month.change(:hour => 23, :min => 59, :sec => 59)).to_d
        end
    end
    logger.debug "Amount: #{amount}"
    return amount.to_d
  end

  def return_money_whole
    user.user_type == "prepaid" ? end_time = Time.now.end_of_month.change(:hour => 23, :min => 59, :sec => 59) : end_time = Time.now.beginning_of_month
    amount = 0
    case service.servicetype
      when "one_time_fee"
        amount = service.price if end_time > activation_end
      when 'flat_rate', 'dynamic_flat_rate'
        amount = price_for_period(activation_start, end_time).to_d
      when "periodic_fee"
        case self.service.periodtype
          when 'day'
            amount = self.subscriptions_paid_this_month
          when 'month'
            amount = price_for_period(activation_start, end_time).to_d
        end
    end
    if amount
      Payment.subscription_payment(user, amount * -1)
      user.balance += amount
      return user.save
    else
      return false
    end
  end

=begin
  Counts amount that was paid during current month.
  Note that amount is in system currency and beggining of month is in system timezone

  *Returns*
  +amount+ amount(float) that was paid diring current month for this subscription, might be 0.
=end
  def subscriptions_paid_this_month
    actions = Action.select('SUM(data2) AS amount').where("action = 'subscription_paid' AND target_id = #{self.id} AND date > '#{Time.now.beginning_of_month.to_s(:db)}'").first
    return actions.amount.to_d
  end

  def return_money_month
    amount = 0
    user = self.user
    amount = self.return_for_month_end if user && user.user_type.to_s == 'prepaid'
    if amount > 0
      Payment.subscription_payment(user, amount * -1)
      user.balance += amount.to_d
      return user.save
    else
      return false
    end
  end

  def disable
    self.activation_end = Time.now.to_s(:db)
    self.time_left = 0 if ['flat_rate', 'dynamic_flat_rate'].include?(service.servicetype)
  end

  def self.get_activation_year
    this_year = Time.now.year
    min_end   = Subscription.minimum(:activation_end).try(:year) || this_year
    min_start = Subscription.minimum(:activation_start).try(:year) || this_year
    max_end   = Subscription.maximum(:activation_end).try(:year) || this_year
    max_start = Subscription.maximum(:activation_start).try(:year) || this_year
    return min_end, min_start, max_end, max_start
  end

  def update_by(user_id, params)
    self.user_id = user_id
    self.no_expire = params['no_expire'].to_i
    self.added = self.added.change(sec: 0) if self.added
    service = Service.where(id: self.service_id.to_i).first
    case service.try(:servicetype)
    when 'flat_rate'
      self.activation_start = self.activation_start.beginning_of_month.change(hour: 0, min: 0, sec: 0)
      self.activation_end = self.activation_end.end_of_month.change(hour: 23, min: 59, sec: 59) unless params['until_canceled'].to_i == 1
    when 'dynamic_flat_rate'
      self.activation_start = self.activation_start.change(hour: 0, min: 0, sec: 0)
      if params['until_canceled'].to_i != 1
        month_difference = months_between(activation_start, activation_end)
        self.activation_end = self.activation_start.months_since(month_difference).change(hour: 23, min: 59, sec: 59) - 1.day
      end
    end
  end

  def self.get_subscription(id)
    notice = ''
    sub = Subscription.includes(:user, :service).where(["subscriptions.id = ?", id]).first
    if !sub
      notice = _('Subscription_not_found')
    elsif !sub.user
      notice = _('User_not_found')
    elsif !sub.service
      notice = _('Service_not_found')
    end
    return sub, notice
  end

  def delete_by_option(option, user_id)
    self_user_id = self.user_id
    status = ''
    case option.to_s
    when "delete"
      Action.add_action_hash(user_id, {action: 'Subscription_deleted', target_id: id, target_type: 'Subscription', data: self_user_id, data2: service_id})
      status = _('Subscription_deleted')
    when "disable"
      Action.add_action_hash(user_id, {action: 'Subscription_disabled', target_id: id, target_type: 'Subscription', data: self_user_id, data2: service_id})
      self.disable
      self.save
      status = _('Subscription_disabled')
    when "return_money_whole"
      Action.add_action_hash(user_id, {action: 'Subscription_deleted_and_return_money_whole', target_id: id, target_type: 'Subscription', data: self_user_id, data2: service_id})
      self.return_money_whole
      status = _('Subscription_deleted_and_money_returned')
    when "return_money_month"
      Action.add_action_hash(user_id, {action: 'Subscription_deleted_and_return_money_month', target_id: id, target_type: 'Subscription', data: self_user_id, data2: service_id})
      self.return_money_month
      status = _('Subscription_deleted_and_money_returned')
    end
  end

  def owned_by_user
    unless User.current.is_admin?
      self.user.owner_id == User.current.id
    else
      true
    end
  end

  def period(period_start, period_end)
    if activation_start < period_start
      use_start = period_start
    else
      use_start = activation_start
    end
    # till which day used?
    if activation_end.blank? || activation_end > period_end
      use_end = period_end
    else
      use_end = activation_end
    end
    return use_start.to_date, use_end.to_date
  end

  def generate_flatrate_datas
    if service.try(:servicetype).to_s == 'dynamic_flat_rate'
      flatrate_data = {
          subscription_id: id,
          year_month: nil,
          minutes: service.quantity,
          seconds: 0
      }
      FlatrateData.delete_all(subscription_id: id)

      if no_expire == 0
        active_period_start = select_active_period_start(activation_start)
        months = get_months_period_size(activation_start, activation_end, active_period_start)

        generate_flatrate_data_time_periods(activation_start, months, flatrate_data)
      else
        period_activation_end = if activation_end.blank?
                                  activation_start.change(hour: 23, min: 59, sec: 59).years_since(50) - 1.day
                                else
                                  activation_end
                                end

        periods = {
            period_start: activation_start,
            period_end: period_activation_end
        }

        FlatrateData.create(flatrate_data.merge(periods))
      end
    end
  end

  # Select Dynamic Flat Rates subscriptions whose flatrate_data period_start/end are between now
  def self.active_dynamic_flatrates
    prepaid = select('subscriptions.*, flatrate_data.period_start AS period_start, flatrate_data.period_end AS period_end').
        joins('JOIN users ON (subscriptions.user_id = users.id AND users.postpaid = 0)').
        joins("JOIN services ON (subscriptions.service_id = services.id AND services.servicetype = 'dynamic_flat_rate')").
        joins('JOIN flatrate_data ON (subscriptions.id = flatrate_data.subscription_id AND NOW() BETWEEN flatrate_data.period_start AND flatrate_data.period_end)').
        group('subscriptions.id')

    postpaid = select('subscriptions.*, flatrate_data.period_start AS period_start, flatrate_data.period_end AS period_end').
        joins('JOIN users ON (subscriptions.user_id = users.id AND users.postpaid = 1)').
        joins("JOIN services ON (subscriptions.service_id = services.id AND services.servicetype = 'dynamic_flat_rate')").
        joins('JOIN flatrate_data ON (subscriptions.id = flatrate_data.subscription_id AND ADDTIME(NOW(), TIMEDIFF(flatrate_data.period_start, flatrate_data.period_end)) BETWEEN flatrate_data.period_start AND flatrate_data.period_end)').
        where('subscriptions.no_expire = 0').
        group('subscriptions.id')

    no_expire_postpaid = select('subscriptions.*, flatrate_data.period_start AS period_start, flatrate_data.period_end AS period_end').
        joins('JOIN users ON (subscriptions.user_id = users.id AND users.postpaid = 1)').
        joins("JOIN services ON (subscriptions.service_id = services.id AND services.servicetype = 'dynamic_flat_rate')").
        joins('JOIN flatrate_data ON (subscriptions.id = flatrate_data.subscription_id AND NOW() BETWEEN flatrate_data.period_start AND flatrate_data.period_end)').
        where('subscriptions.no_expire = 1').
        group('subscriptions.id')

    prepaid + postpaid + no_expire_postpaid
  end

  def self.dynamic_flatrate_extend_period_for_all
    # Selecting Dynamic Flat-Rate subscriptions, to which flatrate_data period should be extented
    #  activation_end should be higher than now or null (to infinity and beyond)
    dynamic_subscriptions = self.select('subscriptions.*').
        joins("JOIN services ON (subscriptions.service_id = services.id AND services.servicetype = 'dynamic_flat_rate')").
        where('(subscriptions.activation_end IS NULL OR subscriptions.activation_end > NOW()) AND subscriptions.activation_start < NOW() AND subscriptions.no_expire = 0').
        group('subscriptions.id')

    # Extend subscription flatrate_data period
    dynamic_subscriptions.each { |subscription| subscription.dynamic_flatrate_extend_period }
  end

  def dynamic_flatrate_extend_period
    # If there are no flatrate_datas, it will be created for subscription
    #  ...even thou this should not be possible.
    generate_flatrate_datas && (return false) if flatrate_datas.blank?

    # No flatrate data should be changed if subscriptions has No Expiration at the end of a Month setting
    return false if no_expire == 1

    # Skipping subscriptions which time period_end has already reached the limit (activation_end or 24 months)
    active_period_start = select_active_period_start(activation_start)
    last_period = flatrate_datas.order(:period_start).last
    months_between_now_last = months_between(active_period_start, last_period.period_start)

    return false if months_between_now_last >= 24 || last_period.period_end == activation_end

    months_between_now_activation_end = if activation_end.present?
                                           months_between(active_period_start, activation_end + 1.day)
                                         else
                                           24
                                         end
    months_between_now_activation_end = 24 if months_between_now_activation_end > 24

    flatrate_data = {
        subscription_id: id,
        year_month: nil,
        minutes: service.quantity,
        seconds: 0
    }

    months_to_add = months_between_now_activation_end - months_between_now_last

    (1..(months_to_add - 1)).each do |month|
      periods = {
          period_start: last_period.period_start.months_since(month),
          period_end: last_period.period_start.change(hour: 23, min: 59, sec: 59).months_since(month + 1) - 1.day
      }

      FlatrateData.create(flatrate_data.merge(periods))
    end
  end

  def update_activation_dates(subscription_until_canceled, params_until_canceled)
    case service.servicetype
    when 'flat_rate'
      self.activation_start = self.activation_start.beginning_of_month.change(hour: 0, min: 0, sec: 0)

      if subscription_until_canceled.blank?
        self.activation_end = self.activation_end.end_of_month.change(hour: 23, min: 59, sec: 59) unless params_until_canceled == 1
      end
    when 'dynamic_flat_rate'
      self.activation_start = self.activation_start.change(hour: 0, min: 0, sec: 0)

      if subscription_until_canceled.to_i != 1
        month_difference = months_between(self.activation_start, self.activation_end)
        self.activation_end = self.activation_start.months_since(month_difference).change(hour: 23, min: 59, sec: 59) - 1.day
      end
    end

    self
  end

  private

  def months_between(date1, date2)
    years = date2.year - date1.year
    months = years * 12
    months += date2.month - date1.month
    months
  end

  def select_active_period_start(activation_start)
    now = Time.now

    if activation_start < now
      period_start_this_month = activation_start.change(year: now.year, month: now.month)
      now_last_day = now.end_of_month.change(hour: 0, minutes: 0, seconds: 0)
      period_start_this_month = period_start_this_month < now_last_day ? period_start_this_month : now_last_day

      if now < period_start_this_month
        period_start_this_month.months_since(-1)
      else
        period_start_this_month
      end
    else
      activation_start
    end
  end

  def get_months_period_size(activation_start, activation_end, active_period_start)
    if activation_start < Time.now
      if activation_end.blank?
        months_start_active = months_between(activation_start, active_period_start)
        months = months_start_active + 24
      else
        months_start_active = months_between(activation_start, active_period_start)
        months_active_end = months_between(active_period_start, activation_end + 1.day)
        months = months_start_active + (months_active_end > 24 ? 24 : months_active_end)
      end
    else
      if activation_end.blank?
        months = 24
      else
        months = months_between(activation_start, activation_end + 1.day)
        months = months > 24 ? 24 : months
      end
    end

    months
  end

  def generate_flatrate_data_time_periods(activation_start, months, data)
    (1..months).each do |month|
      periods = {
          period_start: activation_start.months_since(month - 1),
          period_end: activation_start.change(hour: 23, min: 59, sec: 59).months_since(month) - 1.day
      }

      FlatrateData.create(data.merge(periods))
    end
  end
end
