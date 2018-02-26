# -*- encoding : utf-8 -*-
class BackgroundTask < ActiveRecord::Base
  attr_accessible :id, :owner_id, :user_id, :task_id, :status, :percent_completed, :created_at
  attr_accessible :started_at, :updated_at, :expected_to_finish_at, :finished_at, :failed_at
  attr_accessible :last_error, :to_do_times, :attempts, :data1, :data2, :data3, :data4, :data5, :data6

  belongs_to	:user
  belongs_to	:owner, class_name: 'User', foreign_key: 'owner_id'

  def invoice_task?
    [3,4,5,6].include?(task_id.to_i)
  end

  def self.generate_invoice(action)
    action_settings = action.cron_setting
    date_from, date_till = action.find_period

    BackgroundTask.create(
      task_id: 5,
      owner_id: action_settings.user_id,
      created_at: Time.zone.now,
      status: 'WAITING',
      user_id: action_settings.target_id,
      data1: date_from,
      data2: date_till,
      data3: action_settings.invoice_type,
      data4: DateTime.now,
      data5: action_settings.inv_currency,
      data6: action_settings.inv_send_after.to_i
    )
  end

  def self.cdr_export_template(options = {})
    BackgroundTask.create(
        task_id: 7,
        owner_id: options[:user_id],
        user_id: options[:user_id],
        created_at: Time.zone.now,
        status: 'WAITING',
        data1: options[:template_id],
        data4: options[:from],
        data5: options[:till],
        data6: options[:sql]
    )
  end
end
