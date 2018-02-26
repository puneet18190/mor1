# -*- encoding : utf-8 -*-
class CronAction < ActiveRecord::Base
  belongs_to :cron_setting

  before_destroy :cron_before_destroy

  attr_protected


  def cron_before_destroy
    self.create_new
  end

  def create_new
    time = self.next_run_time

    if time < cron_setting.valid_till and cron_setting.periodic_type != 0 or cron_setting.repeat_forever == 1
      CronAction.create({ cron_setting_id: cron_setting.id, run_at: time })
    end
  end

=begin
  we should chop off someone's hands for coding like that..
  but there's explanation what periodic_type magic numbers mean:
    0 - runs only once(how ilogical it is to ask about NEXT RUN if action can be run only once??!)
    1 - runs once every year
    2 - runs once every month
    3 - runs once every week
    4 - runs every work day
    5 - runs every free day
    6 - runs once every day

   Note that this method will give you an answer no matter whether it should be run next time or not,
   because cron job can have it's time limit.
=end
  def next_run_time
    time = run_at.to_time

    case cron_setting.periodic_type
    when 0
      time = time.to_s.to_time
    when 1
      time = time.to_s.to_time + 1.year
    when 2
      time = time.to_s.to_time + 1.month
    when 3
      time = time.to_s.to_time + 1.week
    when 4
      z = time.to_s.to_time + 1.day
      if weekend? z
        time = next_monday(time.to_s.to_time)
      else
        time = time.to_s.to_time + 1.day
      end
    when 5
      z = time.to_s.to_time + 1.day

      unless weekend? z
        time = next_saturday(time.to_s.to_time)
      else
        time = time.to_s.to_time + 1.day
      end
    when 6
      time = time.to_s.to_time + 1.day
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

=begin
  We need to get date of next monday
=end
  def next_monday(date)
    date += ((1-date.wday) % 7).days
  end

  # We need to get date of next saturday, that is closest day of upcoming weekend
  def next_saturday(date)
    date += ((6-date.wday) % 7).days
  end

  def CronAction.do_jobs
    actions = CronAction.includes(:cron_setting).where(['run_at < ? AND failed_at IS NULL', Time.now().to_s(:db)]).all
    MorLog.my_debug("Cron Action Jobs, found : (#{actions.size.to_i})", 1) if actions

    actions.each do |act|
      if act.cron_setting
        MorLog.my_debug("**** Action : #{act.id} ****")

        case act.cron_setting.action
        when 'change_tariff'
        	if act.cron_setting.change_tariff_details == 'For_Tariff'
            MorLog.my_debug("---- Change tariff into : #{act.cron_setting.to_target_id}")

            if act.cron_setting.target_id == -1
              	location_sql = "UPDATE locationrules
								LEFT JOIN tariffs ON tariff_id = tariffs.id
								SET tariff_id = #{act.cron_setting.to_target_id} WHERE owner_id = 0"
              	sql = "UPDATE users SET tariff_id = #{act.cron_setting.to_target_id} WHERE owner_id = 0"
            else
            	location_sql = "UPDATE locationrules
								LEFT JOIN tariffs ON tariff_id = tariffs.id
								SET tariff_id = #{act.cron_setting.to_target_id} WHERE owner_id = 0 AND tariff_id = #{act.cron_setting.target_id}"
              	sql = "UPDATE users SET tariff_id = #{act.cron_setting.to_target_id} WHERE owner_id = 0 AND tariff_id = #{act.cron_setting.target_id}"
          	end
        	else
            MorLog.my_debug("---- Change tariff into : #{act.cron_setting.to_target_id}")

            if act.cron_setting.target_id == -1
              sql = "UPDATE users SET tariff_id = #{act.cron_setting.to_target_id} WHERE owner_id = #{act.cron_setting.user_id}"
            else
              sql = "UPDATE users SET tariff_id = #{act.cron_setting.to_target_id} WHERE id = #{act.cron_setting.target_id} AND owner_id = #{act.cron_setting.user_id}"
            end
          end

          begin
            ActiveRecord::Base.connection.update(sql)
            ActiveRecord::Base.connection.update(location_sql) if location_sql
            Action.add_action_hash(act.cron_setting.user_id, {:action => 'CronAction_run_successful', :data => 'CronAction successful change tariff', :target_id => act.cron_setting.target_id, :target_type => 'User', :data3 => act.cron_setting_id, :data2 => act.cron_setting.to_target_id})
            act.destroy
            MorLog.my_debug("Cron Actions completed", 1)
          rescue => err
            act.failed_at = Time.now
            act.last_error = err.class.to_s + ' \n ' + err.message.to_s + ' \n ' + err.try(:backtrace).to_s
            act.attempts = act.attempts.to_i + 1
            act.save
            act.create_new
            Action.add_action_hash(act.cron_setting.user_id, {:action => 'error', :data => 'CronAction dont run', :data2 => act.cron_setting_id, :data3 => act.cron_setting.to_target_id, :data4 => err.message.to_s + " " + err.class.to_s, :target_id => act.cron_setting.target_id, :target_type => 'User'})
          end
        when 'change_provider_tariff'
          MorLog.my_debug("---- Change provider tariff into : #{act.cron_setting.provider_to_target_id}")

          if act.cron_setting.provider_target_id == -1
            sql = "UPDATE providers SET tariff_id = #{act.cron_setting.provider_to_target_id} WHERE user_id = #{act.cron_setting.user_id}"
          else
            sql = "UPDATE providers SET tariff_id = #{act.cron_setting.provider_to_target_id} WHERE id = #{act.cron_setting.provider_target_id} AND user_id = #{act.cron_setting.user_id}"
          end

          begin
            ActiveRecord::Base.connection.update(sql)
            Action.add_action_hash(act.cron_setting.user_id, {:action => 'CronAction_run_successful', :data => 'CronAction successful change provider tariff', :target_id => act.cron_setting.provider_target_id, :target_type => 'Provider', :data3 => act.cron_setting_id, :data2 => act.cron_setting.provider_to_target_id})
            act.destroy
            MorLog.my_debug("Cron Actions completed", 1)
          rescue => err
            act.failed_at = Time.now
            act.last_error = err.class.to_s + ' \n ' + err.message.to_s + ' \n ' + err.try(:backtrace).to_s
            act.attempts = act.attempts.to_i + 1
            act.save
            act.create_new
            Action.add_action_hash(act.cron_setting.user_id, {:action => 'error', :data => 'CronAction dont run', :data2 => act.cron_setting_id, :data3 => act.cron_setting.provider_to_target_id, :data4 => err.message.to_s + " " + err.class.to_s, :target_id => act.cron_setting.provider_target_id, :target_type => 'Provider'})
          end
        when 'change_LCR'
          MorLog.my_debug("---- Change user LCR into : #{act.cron_setting.lcr_id}")
          if act.cron_setting.target_id == -1
            sql = "UPDATE users SET lcr_id = #{act.cron_setting.lcr_id}"
          else
            sql = "UPDATE users SET lcr_id = #{act.cron_setting.lcr_id} WHERE id = #{act.cron_setting.target_id}"
          end

          begin
            ActiveRecord::Base.connection.update(sql)
            Action.add_action_hash(act.cron_setting.user_id, {:action => 'CronAction_run_successful', :data => 'CronAction successful change provider tariff', :target_id => act.cron_setting.provider_target_id, :target_type => 'Provider', :data3 => act.cron_setting_id, :data2 => act.cron_setting.provider_to_target_id})
            act.destroy
            MorLog.my_debug("Cron Actions completed", 1)
          rescue => err
            act.failed_at = Time.now
            act.last_error = err.class.to_s + ' \n ' + err.message.to_s + ' \n ' + err.try(:backtrace).to_s
            act.attempts = act.attempts.to_i + 1
            act.save
            act.create_new
            Action.add_action_hash(act.cron_setting.user_id, {:action => 'error', :data => 'CronAction dont run', :data2 => act.cron_setting_id, :data3 => act.cron_setting.lcr_id, :data4 => err.message.to_s + " " + err.class.to_s})
          end
        when 'Generate_Invoice'
          MorLog.my_debug("---- Generate Invoice : #{act.cron_setting.invoice_type}")

          begin
            BackgroundTask.generate_invoice(act)
            system("/usr/local/mor/mor_invoices elasticsearch")
            Action.add_action_hash(act.cron_setting.user_id, {:action => 'CronAction_run_successful', :data => 'CronAction successful generate Invoice', :target_id => act.cron_setting.target_id, :target_type => 'User', :data3 => act.cron_setting_id, :data2 => act.cron_setting.to_target_id})
            act.destroy
            MorLog.my_debug("Cron Actions completed", 1)
          rescue => err
            act.failed_at = Time.now
            act.last_error = err.class.to_s + ' \n ' + err.message.to_s + ' \n ' + err.try(:backtrace).to_s
            act.attempts = act.attempts.to_i + 1
            act.save
            act.create_new
            Action.add_action_hash(act.cron_setting.user_id, {:action => 'error', :data => 'CronAction dont run', :data2 => act.cron_setting_id, :data3 => act.cron_setting.to_target_id, :data4 => err.message.to_s + " " + err.class.to_s, :target_id => act.cron_setting.target_id, :target_type => 'User'})
          end
        end
      else
        act.failed_at = Time.now
        act.last_error = "CronAction setting dont found : #{act.cron_setting_id}"
        act.attempts = act.attempts.to_i + 1
        act.save
        Action.add_action_second(-1, 'error', 'CronAction setting dont found', act.id)
      end
    end
  end

  def find_period
    day_from = cron_setting.inv_from
    day_till = cron_setting.inv_till

    datetime_now = DateTime.now
    datetime_month_before = datetime_now - 1.month

                              # if invoice period starts in previous month and ends in current month
    from_month, till_month =  if day_from > day_till
                                [datetime_month_before, datetime_now]
                              # if invoice period starts and ends in current month before run_at time
                              elsif run_at.to_time.day > day_till
                                [datetime_now, datetime_now]
                              else
                              # if invoice period starts and ends in previous month
                                [datetime_month_before, datetime_month_before]
                              end


    [
      Application.fix_last_day(from_month, day_from).beginning_of_day,
      Application.fix_last_day(till_month, day_till).end_of_day
    ]
  end
end

