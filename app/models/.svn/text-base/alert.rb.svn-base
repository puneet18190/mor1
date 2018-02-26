# -*- encoding : utf-8 -*-
# This is alert module
class Alert < ActiveRecord::Base
  attr_protected

  has_many :alert_dependency, dependent: :destroy, foreign_key: :owner_alert_id
  belongs_to :alert_group
  validates_numericality_of :clear_after, message: _('clear_after_not_numerical')
  validates_numericality_of :hgc, only_integer: true, greater_than_or_equal_to: 0,
                            less_than_or_equal_to: 400, message: _('hgc_must_be_integer_between')
  after_destroy {|alert| AlertDependency.where(alert_id: id).destroy_all}
  after_commit :set_name

  def validation(current_user_id, clear_on_date_blank, alert_dependencies = [])
    clear_after_int = clear_after.to_i
    alert_if_less_equals_zero = alert_if_less == 0
    alert_if_more_equals_zero = alert_if_more == 0
    clear_after_greater_than_zero = clear_after_int > 0
    clear_if_less_equals_zero = clear_if_less == 0
    clear_if_more_equals_zero = clear_if_more == 0
    disable_clear_on = disable_clear == 1
    check_data_not_all = check_data != 'all'
    check_data_present = check_data.present?

    if check_type == 'device'
      if check_data_present
        device = Device.where(id: check_data).first
        device_user = device.try(:user)
      end

      errors.add(:check_type, _('device_must_be_selected')) if check_data_not_all && (!device || !(device_user && device_user.owner_id == current_user_id))
    end

    if check_type == 'provider'
      provider = Provider.where(id: check_data, user_id: current_user_id).first if check_data_present
      errors.add(:check_type, _('provider_must_be_selected')) if !provider && check_data_not_all
    end

    if (check_type == 'user') && !['all', 'postpaid', 'prepaid'].member?(check_data)
      user = User.where(id: check_data, owner_id: current_user_id).first if check_data_present
      errors.add(:check_type, _('user_must_be_selected')) if !user
    end

    if (check_type == 'destination') && !check_data.to_s.strip.match(/\A[0-9%]+\Z/)
      errors.add(:check_type, _('Prefix_was_not_found'))
    end

    alert_type_is_group = alert_type == 'group'

    if !(['group', 'registration'].member?(alert_type))
      if (alert_if_more > clear_if_less && alert_if_less_equals_zero && clear_if_more_equals_zero) ||
        (alert_if_less < clear_if_more && alert_if_more_equals_zero && clear_if_less_equals_zero) ||
        (alert_if_less > alert_if_more && alert_if_more_equals_zero && (disable_clear_on || clear_after_greater_than_zero)) ||
        (alert_if_more > alert_if_less && alert_if_less_equals_zero && (disable_clear_on || clear_after_greater_than_zero))
      else
        if alert_type.to_s == 'price_sum'
          # Skip validation for price sum
        elsif alert_if_more <= clear_if_less && clear_if_less != 0
          errors.add(:alert_if, _('Alert') + " >= " + _('must_be_higher_than') + _('Clear') + " <= ")
        elsif alert_if_less >= clear_if_more && alert_if_less != 0
          errors.add(:alert_if, _('Alert') + " <= " + _('must_be_lower_than') + _('Clear') + " >= ")
        elsif alert_if_more_equals_zero && alert_if_less_equals_zero && clear_if_more_equals_zero && clear_if_less_equals_zero
          errors.add(:alert_if, _('Alert_cannot_be_equal_to_Clear'))
        else
          errors.add(:alert_if, _('logic_error_in_alerts'))
        end
      end
    end

    if alert_dependencies.try(:count).to_i < 2 && alert_type_is_group
      errors.add(:alert_group, _('Alert_group_must_have_more_than_one_alert'))
    end

    if (action_alert_email == 1 || action_clear_email == 1 ) && alert_groups_id.to_i == 0
      errors.add(:notify, _('group_must_be_selected'))
    end

    if clear_after_int < 0 || clear_after_int > 200000
      errors.add(:notify, _('clear_after_notice'))
    end

    if disable_clear != 1
      if !clear_on_date.nil? && clear_on_date < Time.now
        errors.add(:notify, _('Clear_on_date_in_past'))
      elsif (1..4).include?(clear_on_date_blank)
        errors.add(:notify, _('Clear_on_date_values'))
      end
    end

    if alert_type_is_group && alert_dependencies
      alert_dependencies.each do |alert|
        alert.owner_alert_id = id
        if Alert.find(alert.alert_id).check_type != check_type
          errors.add(:notify, _('dependencies_must_have_the_same_object_type'))
          break
        end
        if AlertDependency.cycle_exists?(alert)
          errors.add(:notify, _('cycle_exists_in_your_alert_groups'))
          break
        end
      end
    end

    return errors.size > 0 ? false : true
  end

  def Alert.alerts_order_by(options)
    option_order_by = options[:order_by].to_s

    case option_order_by.strip
    when'id'
      order_by = 'id'
    else
      order_by = option_order_by
    end

    if order_by != ''
      order_by << (option_order_by.to_i == 0 ? ' ASC' : ' DESC')
    end

    return order_by
  end

  def apply_limitations
    min = 0.0
    min = -9999999 if alert_type.to_s == 'price_sum'
    max = 100 if ['asr'].member?(alert_type)
    max = 600 if ['acd'].member?(alert_type)
    max = 30.0 if ['pdd','ttc'].member?(alert_type)
    max = 9999999 if ['billsec_sum'].member?(alert_type)
    max = 99999 if ['calls_total','calls_answered','calls_not_answered', 'sim_calls', 'price_sum'].member?(alert_type)
    max = 400 if ['hgc_absolute','hgc_percent'].member?(alert_type)
    max_second= 100000

    alert_if_less_dec, alert_if_more_dec = [alert_if_less.to_d, alert_if_more.to_d]
    clear_if_less_dec, clear_if_more_dec = [clear_if_less.to_d, clear_if_more.to_d]
    ignore_if_calls_less_dec, ignore_if_calls_more_dec = [ignore_if_calls_less.to_d, ignore_if_calls_more.to_d]

    if !(['group', 'registration'].member?(alert_type))
      self.alert_if_less = min if alert_if_less_dec < min || alert_if_less.to_s == ''
      self.alert_if_less = max if alert_if_less_dec > max
      self.alert_if_more = min if alert_if_more_dec < min || alert_if_more.to_s == ''
      self.alert_if_more = max if alert_if_more_dec > max
      self.clear_if_less = min if clear_if_less_dec < min || clear_if_less.to_s == ''
      self.clear_if_less = max if clear_if_less_dec > max
      self.clear_if_more = min if clear_if_more_dec < min || clear_if_more.to_s == ''
      self.clear_if_more = max if clear_if_more_dec > max
      self.clear_after = 0 if clear_after.blank?
      self.ignore_if_calls_less = min if ignore_if_calls_less_dec < min || ignore_if_calls_less.to_s == ''
      self.ignore_if_calls_less = max_second if ignore_if_calls_less_dec > max_second
      self.ignore_if_calls_more = min if ignore_if_calls_more_dec < min || ignore_if_calls_more.to_s == ''
      self.ignore_if_calls_more = max_second if ignore_if_calls_more_dec > max_second
    end
    self.clear_after = 0 if alert_type == 'registration'
  end

  def self.schedule_update(schedule, periods)
    err = []
    schedule.alert_schedule_periods.each do |period|
      period_id = period.id.to_s
      period_fields = periods[period_id]
      if period_fields.is_a? Hash
        periods.try(:delete, period_id)
        if period_fields['start']
          period_start = period_fields[:start]
          period.start = period.start.change(hour: period_start[:hour], min: period_start[:minute])
        end
        if period_fields['end']
          period_end = period_fields[:end]
          period.end  = period.end.change(hour: period_end[:hour], min: period_end[:minute])
        end
        unless period.save
          err << _('invalid_period')
        end
      end
    end

    periods.try(:each) do |key, values|
      tmp = schedule.alert_schedule_periods.new
      values_start = values[:start]
      values_end = values[:end]
      tmp.start = tmp.start.change(hour: values_start[:hour], min: values_start[:minute])
      tmp.end	= tmp.end.change(hour: values_end[:hour], min: values_end[:minute])
      tmp.day_type = values[:day_type]
      unless tmp.save
        err << _('invalid_period')
      end
    end

    return err
  end

  def self.group_update(group)
    group.sms_schedule_id = 0 if group.sms_schedule_id.to_i <= 0
    group.email_schedule_id = 0 if group.email_schedule_id.to_i <= 0

    return group
  end

  def self.group_add(new_group)
    new_group.sms_schedule_id = 0 if new_group.sms_schedule_id.to_i <= 0
    new_group.email_schedule_id = 0 if new_group.email_schedule_id.to_i <= 0

    return new_group
  end

  def self.new_schedule(params)
    last_fake	= "#{AlertSchedulePeriod.last.try(:id).to_i+1}#{Time.now.to_i}"
    js_new	= AlertSchedulePeriod.new

    start_hour = params[:start_hour].to_i
    start_min	 = params[:start_min].to_i
    end_hour	 = params[:end_hour].to_i
    end_min	 = params[:end_min].to_i

    js_new.start = js_new.start.change(hour: start_hour, min: start_min)
    js_new.end   = js_new.end.change(hour: end_hour, min: end_min)

    js_new[:id] = last_fake
    js_new[:day_type] = params[:day_type]

    return js_new
  end

  def set_name
    if name.blank?
      self.name = "Alert_#{self.id}"
      save
    end
  end

  def alert_if_less_frmt
    if alert_if_more == 0 && clear_if_less == 0 && alert_type != 'registration'
      %w(asr pdd ttc price_sum).member?(alert_type) ? alert_if_less : alert_if_less.to_i
    end
  end

  def alert_if_more_frmt
    if alert_if_less == 0 && clear_if_more == 0 || alert_type == 'registration'
      %w(asr pdd ttc price_sum registration).member?(alert_type) ? alert_if_more : alert_if_more.to_i
    end
  end

  def clear_if_less_frmt
    if alert_type != 'registration'
      return _('Disabled') if disable_clear.to_i == 1
      if alert_if_less == 0 && clear_if_more == 0
        %w(asr pdd ttc).member?(alert_type) ? clear_if_less : clear_if_less.to_i
      end
    end
  end

  def clear_if_more_frmt
    return clear_if_more if alert_type == 'registration' && disable_clear == 0
    return _('Disabled') if disable_clear == 1
    if alert_if_more == 0 && clear_if_less == 0
      %w(asr pdd ttc).member?(alert_type) ? clear_if_more : clear_if_more.to_i
    end
  end
end
