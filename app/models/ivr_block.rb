# -*- encoding : utf-8 -*-
class IvrBlock < ActiveRecord::Base
  attr_accessible :id, :name, :ivr_id, :timeout_response, :timeout_digits

  belongs_to :ivr
  has_many :ivr_actions, :dependent => :destroy
  has_many :ivr_extensions, :dependent => :destroy
  before_destroy { |block|
    Extline.delete_all("context = 'ivr_block#{block.id}'")
  }

  def regenerate_extlines
    Extline.delete_all("context = 'ivr_block#{self.id}'")
    priority = 1
    context = "ivr_block#{self.id}"
    exten = 's'
    app = 'NoOp'
    appdata = "IVR_BLOCK_#{self.id}_REACHED"
    Extline.mcreate(context, priority.to_s, app, appdata, exten, '0')
    priority += 1
    app = 'Set'
    Extline.mcreate(context, priority.to_s, app, "TIMEOUT(digit)=#{self.timeout_digits}", exten, '0')
    priority += 1
    Extline.mcreate(context, priority.to_s, app, "TIMEOUT(response)=#{self.timeout_response}", exten, '0')
    self.ivr_actions.each do |action|
      priority += 1
      case action.name
      when 'Delay'
        Extline.mcreate(context, priority.to_s, 'Waitexten', action.data1.to_s, exten, '0')
      when 'Debug'
        Extline.mcreate(context, priority.to_s, 'NoOp', action.data1.to_s, exten, '0')
      when 'Playback'
        Extline.mcreate(context, priority.to_s, 'Answer', '', exten, '0')
        priority += 1
        Extline.mcreate(context, priority.to_s, 'Background', "mor/ivr_voices/#{action.data1.to_s}/"+action.data2.to_s.split('.').first.to_s, exten, '0')
      when 'Change Voice'
        Extline.mcreate(context, priority.to_s, 'Set', "CHANNEL(language)=#{action.data1.to_s}", exten, '0')
      when 'Hangup'
        if action.data1 == 'Busy'
          Extline.mcreate(context, priority.to_s, 'Busy', '10', exten, '0')
        else
          Extline.mcreate(context, priority.to_s, 'Congestion', '4', exten, '0')
        end
      when 'Transfer To'
        case action.data1.to_s
        when 'IVR'
          Extline.mcreate(context, priority.to_s, 'Goto', "ivr_block#{action.data2.to_s}|s|1", exten, '0')
        when 'DID'
          Extline.mcreate(context, priority.to_s, 'Goto', "mor|#{action.data2.to_s}|1", exten, '0')
        when 'Device'
          ivr_action_device = Device.where(id: action.data2).first
          dev_context = action.data2.to_i == 0 ? 'mor_local' : ivr_action_device.context.to_s
          Extline.mcreate(context, priority.to_s, 'Goto', "#{dev_context}|#{ivr_action_device.extension.to_s}|1", exten, '0')
        when 'Block'
          Extline.mcreate(context, priority.to_s, 'Goto', "ivr_block#{action.data2.to_s}|s|1", exten, '0')
        when 'Extension'
          pbx_context = action.data3.to_i > 1 ? "pool_#{action.data3}_" : ''
          Extline.mcreate(context, priority.to_s, 'Goto', "#{pbx_context}mor_local|#{action.data2.to_s}|1", exten, '0')
        else
          Extline.mcreate(context, priority.to_s, 'NoOp', "Unknown_Command: #{action.name}_params:_#{action.data1.to_s}|#{action.data2.to_s}", exten, '0')
        end
      when 'Set Accountcode'
        # put accountcode value to both channels, in various situations different channels are used
        Extline.mcreate(context, priority.to_s, 'Set', "MASTER_CHANNEL(MOR_ACC)=#{action.data1.to_s}", exten, '0')
        priority += 1
        Extline.mcreate(context, priority.to_s, 'Set', "MOR_ACC=#{action.data1.to_s}", exten, '0')
      when 'mor'
        Extline.mcreate(context, priority.to_s, 'mor', '', exten, '0')
      when 'Action log'
        Extline.mcreate(context, priority.to_s, 'Set', "IVR_TXT=\"#{action.data1.to_s.gsub('"', '`').gsub('\'', '`')}\"" , exten, '0')
        priority += 1
        Extline.mcreate(context, priority.to_s, 'AGI', 'mor_action_log', exten, '0')
      when 'Change CallerID (Number)'
        Extline.mcreate(context, priority.to_s, 'Set', "CALLERID(num)=#{action.data1.to_s}", exten, '0')
      when 'Random Play'
        Extline.mcreate(context, priority.to_s, 'AGI', "mor_play_random,#{action.data1.to_s}", exten, '0')
      else
        Extline.mcreate(context, priority.to_s, 'NoOp', "Unknown_Command: #{action.name}", exten, '0')
      end
    end

    for exten in self.ivr_extensions do
      Extline.mcreate(context, '1', 'NoOp', "IVR Block #{self.id}, Extension #{exten.exten} reached", exten.exten, '0')
      Extline.mcreate(context, '2', 'Goto', "ivr_block#{exten.goto_ivr_block_id}|s|1", exten.exten.to_s, '0')
    end
  end

  def update_by(ivr)
    self.ivr_id = ivr.id
    self.timeout_response = 10
    self.timeout_digits = 3
  end

end
