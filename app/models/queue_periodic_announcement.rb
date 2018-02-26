# -*- encoding : utf-8 -*-
class QueuePeriodicAnnouncement < ActiveRecord::Base

  belongs_to :queue

  def self.table_name()
    "queue_periodic_announcements"
  end

  attr_accessible :id, :queue_id, :ivr_sound_files_id, :priority

  attr_protected

  def move_announcement(direction)

    order = direction == 'down'
      queue_announcement = QueuePeriodicAnnouncement.
        where("queue_id = #{self.queue_id} AND priority #{order ? '>' : '<'} #{self.priority}").
        order("priority #{order ? 'ASC' : 'DESC'}").first

    if queue_announcement
      old_priority = self.priority
      self.update_attribute(:priority, queue_announcement.priority)
      queue_announcement.update_attribute(:priority, old_priority)
    end
  end

end

