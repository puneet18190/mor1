# -*- encoding : utf-8 -*-
# Ast Queues Model
class AstQueue < ActiveRecord::Base
  attr_accessible :name, :extension, :server_id, :strategy, :weight, :autofill, :ringinuse, :failover_action, :failover_data,
                  :cid_name_prefix, :reportholdtime, :announce, :memberdelay, :timeout, :retry, :wrapuptime, :allow_callee_hangup,
                  :maxlen, :join_announcement, :ringing_instead_of_moh, :moh_id, :ring_at_once, :joinempty, :leavewhenempty,
                  :allow_caller_hangup, :context, :max_wait_time, :announce_frequency, :min_announce_frequency, :announce_position,
                  :announce_position_limit, :announce_holdtime, :announce_round_seconds, :periodic_announce_frequency,
                  :random_periodic_announce, :relative_periodic_announce, :servicelevel, :penaltymemberslimit, :autopause,
                  :setinterface, :setqueueentryvar, :setqueuevar, :membermacro, :membergosub, :monitor_format, :monitor_type,
                  :eventwhencalled, :eventmemberstatus, :timeoutrestart, :queue_youarenext, :queue_thereare, :queue_callswaiting,
                  :queue_holdtime, :queue_minutes, :queue_seconds, :queue_thankyou, :queue_lessthan, :queue_reporthold,
                  :timeoutpriority, :pbx_pool_id, :owner_id, :agent_name, :queue_id, :device_id, :penalty, :paused, :priority,
                  :ivr_sound_files_id

  has_many :dids
  has_many :queue_agents, foreign_key: 'queue_id'
  has_many :queue_periodic_announcements, foreign_key: 'queue_id'

  validates_presence_of :extension, message: _('Please_enter_extension')
  validates_presence_of :name, message: _('Name_cannot_be_blank')

  after_create :after_create_queue

  def self.table_name
    'queues'
  end

  def after_create_queue
    extension, ast_queue_id = [self.extension, self.id]
    dialplan = Dialplan.new({name: self.name, dptype: 'queue',
                             data1: ast_queue_id, data2: extension, data6: self.pbx_pool_id})

    if dialplan.save
      context = self.pbx_pool_id == 1 ? 'mor_local' : "pool_#{self.pbx_pool_id}_mor_local"
      app = 'Set'
      appdata = "MOR_DP_ID=#{dialplan.id}"
      Extline.mcreate(context, "1", app, appdata, extension, '0')

      app = 'Goto'
      appdata = "mor_queues,queue#{ast_queue_id}, 1"
      Extline.mcreate(context, '2', app, appdata, extension, '0')
    end
  end

  def destroy_all
    return false if dialplan_has_dids

    ast_queue_id = self.id
    dialplan = Dialplan.where(name: self.name, dptype: 'queue', data1: ast_queue_id, data2: extension).first

    Extline.delete_all(exten: extension, appdata: "MOR_DP_ID=#{dialplan.id}")
    Extline.delete_all(exten: extension, appdata: "mor_queues,queue#{ast_queue_id}, 1")

    dialplan.destroy
    self.queue_agents.destroy_all
    self.queue_periodic_announcements.destroy_all
    self.destroy
  end

  def dialplan_has_dids
    dialplan = Dialplan.find_by(name: self.name, dptype: 'queue', data1: id, data2: extension)
    if dialplan.dids.size > 0
      errors.add(:dids_error, _('it_has_assigned_DIDs'))
      return true
    end
    return false
  end
end
