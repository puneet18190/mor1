# -*- encoding : utf-8 -*-
module ProvidersHelper

  def check_alive(prov = nil)
    if prov and ['ip','hostname'].member? prov.type and prov.tech == 'SIP'
      case prov.alive
        when 1; b_check
        when 0; b_cross
      end
    end
  end

  def calculate_asr_and_acd(prov)
    asr = prov.pcalls.to_i > 0 ? (prov.answered.to_f / prov.pcalls.to_f) * 100 : 0.0
    acd = prov.answered.to_i > 0 ? prov.billsec.to_f / prov.answered.to_f : 0.0

    [asr, acd]
  end

  def prov_device_reg_status(device_reg_status)
    icon = ''
    case device_reg_status.upcase
    when 'REGISTERED'
      icon = 'icons/bullet_green.png'
      title = _('Provider_Is_Registered')
    when 'UNREGISTERED'
      icon = 'icons/bullet_red.png'
      title = _('Provider_Is_Unregistered')
    else
      icon = 'icons/bullet_white.png'
      title = _('Provider_Should_Not_Register')
    end
    return image_tag(icon, :title => title)
  end

  def prov_reg_status_msg(provider)
    msg = ''
    if provider.device
      case provider.device.reg_status.to_s.upcase
      when 'REGISTERED'
        msg = 'REGISTERED'
      when 'UNREGISTERED'
        msg = 'UNREGISTERED'
      else
        msg = ''
      end
    else
      msg = ''
    end
    return msg
  end
end
