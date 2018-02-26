# -*- encoding : utf-8 -*-
# Call Log model
class CallLog < ActiveRecord::Base
  attr_protected

  def nice_log_text
    nice_log = []

    return nice_log unless log.present?

    log.split("\n").each do |log|
      date_offset = 21
      log_string = log[date_offset..-1].to_s
      next unless /\[.*\]+/ =~ log_string
      type_index = log_string.index('[') + date_offset
      message_index = log_string.index(']') + date_offset
      next if type_index.blank? && message_index.blank?
      nice_log << resolve_log(log, type_index, message_index)
    end

    nice_log
  end

  def self.find_log(uniqueid)
    uncached do
      where(uniqueid: uniqueid).first
    end
  end

  def nice_call_tracing_log_text
    nice_log = []

    return nice_log unless log.present?

    log.split("\n").each do |log|
      log_string = log.to_s
      next unless /\[.*\]+/ =~ log_string
      type_index = log_string.index('[')
      message_index = log_string.index(']')
      next if type_index.blank? && message_index.blank?
      nice_log << resolve_call_tracing_log(log, type_index, message_index)
    end

    nice_log.last[:ct_type_color] = (nice_log.last[:ct_message] == 'Call Tracing is successful!') ? 3 : 2

    nice_log
  end

  private

  def resolve_log(log, type_index, message_index)
    ct_date = log[1...20]
    ct_type = log[22...type_index]
    ct_message = log[(message_index + 2)..-1]

    ct_type_color = case ct_type.upcase
                      when 'DEBUG'
                        1
                      when 'ERROR', 'WARNING'
                        2
                      else
                        0
                    end

    {ct_date: ct_date, ct_type: ct_type, ct_message: ct_message, ct_type_color: ct_type_color}
  end

  def resolve_call_tracing_log(log, type_index, message_index)
    ct_type = log[0...type_index]
    ct_message = log[(message_index + 2)..-1]

    ct_type_color = case ct_type.upcase
                      when 'DEBUG'
                        1
                      when 'ERROR', 'WARNING'
                        2
                      else
                        0
                    end

    {ct_type: ct_type, ct_message: ct_message, ct_type_color: ct_type_color}
  end
end
