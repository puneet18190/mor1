# -*- encoding : utf-8 -*-
class CronSetting < ActiveRecord::Base

  attr_protected

  belongs_to :user
  has_many :cron_actions

  before_save :cron_s_before_save
  after_create :cron_after_create
  after_update :cron_after_update

  def cron_s_before_save

    case(self.action)
    when 'change_tariff'
      self.target_class = 'User'
      self.to_target_class = 'Tariff'
      self.user_id = User.current.id
    when 'change_provider_tariff'
      self.target_class = 'Provider'
      self.to_target_class = 'Provider_Tariff'
      self.user_id = User.current.id
    when 'change_LCR'
      self.target_class = 'User'
      self.to_target_class = 'User_LCR'
    when 'Generate_Invoice'
      self.target_class = 'User'
      self.to_target_class = 'Invoice'
    end

    if periodic_type.to_i == 0 and valid_from.to_time < Time.now
      errors.add(:period, _("Please_enter_correct_period"))
      return false
    end

    if (valid_till.to_time < Time.now or valid_from > valid_till and next_run_time > valid_till) and repeat_forever.to_i == 0
      errors.add(:period, _("Please_enter_correct_period"))
      return false
    end

  end

  def CronSetting.cron_settings_actions(user = 'admin')
    actions = []
    actions.concat([[_('change_tariff'), 'change_tariff'], [_('change_provider_tariff'), 'change_provider_tariff'], [_('change_LCR'), 'change_LCR']]) if user == 'admin'
    actions << [_('Generate_Invoice'), 'Generate_Invoice']
    actions.sort!
    return actions
  end

  def CronSetting.cron_settings_periodic_types
    [[_('One_time'), 0], [_('Yearly'), 1], [_('Monthly'), 2], [_('Weekly'), 3], [_('Work_days'), 4], [_('Free_days'), 5], [_('Daily'), 6]]
  end

  def CronSetting.cron_settings_inv_periodic_types
    [[_('One_time'), 0], [_('Monthly'), 2]]
  end

  def CronSetting.cron_settings_priority
    [[_('high'), 10], [_('medium'), 20], [_('low'), 30]]
  end

  def CronSetting.cron_settings_target_class
    [[_('User'), 'User'], [_('Provider'), 'Provider']]
  end

  def target
    case target_class
      when 'User'
        change_tariff_details == 'For_User' ? User.where({id: target_id}).first : Tariff.where(id: target_id).first
      when 'Provider'
        Provider.where({id: provider_target_id}).first
    end
  end

  def cron_after_create
    CronAction.create({ cron_setting_id: id, run_at: self.next_run_time })
  end

  def cron_after_update
    CronAction.delete_all(:cron_setting_id => id)
    CronAction.create({ cron_setting_id: id, run_at: self.next_run_time })
  end

  def next_run_time(tim=nil)
    if tim
      time = tim
    elsif action == 'Generate_Invoice'
      valid_from_invoice_date = valid_from.dup

      fixed_date = Application.fix_last_day(valid_from_invoice_date, inv_till)
      # at least 24h have to pass after Generate_Invoice cron action inv_till to create background_task, therefore 2 days are added to valid_from_invoice_date
      date_diff = fixed_date.end_of_month.day - fixed_date.day
      # If it's last or second to last day of month, month will be increased
      time = if date_diff < 2 # adding 2 days to valid_from_invoice_date, if valid_from_invoice_date is either last or one before last day of month
              same_month = valid_from_invoice_date.strftime('%Y%m') == Time.now.strftime('%Y%m')
              valid_from_invoice_date += 1.month if same_month
              valid_from_invoice_date = valid_from_invoice_date.change(day: (2 - date_diff))
              valid_from_invoice_date += 1.month if !same_month && valid_from_invoice_date.day < valid_from.day
              valid_from_invoice_date
             else
               same_month = valid_from_invoice_date.strftime('%Y%m') == Time.now.strftime('%Y%m')
               valid_from_invoice_date = valid_from_invoice_date.change(day: fixed_date.day + 2)
               valid_from_invoice_date += 1.month if same_month && valid_from_invoice_date.day < valid_from.day
               valid_from_invoice_date
            end

    else
      time = valid_from
    end

    time = time.to_s.to_time

    while time < Time.now do
      next_day = time + 1.day

      time =  case periodic_type
              when 0
                time
              when 1
                time + 1.year
              when 2
                time + 1.month
              when 3
                time + 1.week
              when 4
                ((weekend? next_day) ? next_monday(time) : next_day)
              when 5
                ((weekend? next_day) ? next_day : next_saturday(time))
              when 6
                next_day
              end
    end

    time
  end

=begin
    Check whether given date is weekend or not

    *Params*
        date - datetime or time instance

    *Returns*
        true if given date is weekday else returns false
=end
  def weekend?(date)
    [6,0].include? date.wday
  end

  #We need to get date of next monday
  def next_monday(date)
    date += ((1-date.wday) % 7).days
  end

  #We need to get date of next saturday, that is closest day of upcoming weekend
  def next_saturday(date)
    date += ((6-date.wday) % 7).days
  end

  def invoice_type
    case target_id.to_i
    when -3
      'prepaid'
    when -2
      'postpaid'
    else
      'user'
    end
  end
end
