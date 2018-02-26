# -*- encoding : utf-8 -*-
module LcrsHelper

  def lcrpartial_destinations_providers(lcr_id)
    lcr = current_user.load_lcrs({first: true, conditions: "id=#{lcr_id}"})
    code = []
    if lcr
      lcr.providers("asc").each { |p| code << p.name.to_s + " (" + p.tech + ")" }
    end
    code.join('<br />')
  end

  def b_copy(options ={})
    options[:id] = "icon_chech_"+options[:id].to_s if options[:id]
    image_tag('icons/page_copy.png', {:title => _('copy')}.merge(options)) + " "
  end

  def lcrpartial_prefixl(direction)
    if direction
      destinations = Destination.where(direction_code: direction.code.to_s).order(:prefix).all
      code = []
      for destination in destinations
        code << "<option value='#{destination.prefix.to_s}'>#{destination.prefix.to_s} - #{destination.name}</option>"
      end
      code.join("\n").html_safe
    else
      ''
    end
  end

  def accountant_lcr_read
    (accountant? && session[:acc_manage_lcr].to_i == 2) || admin? || reseller? ? false : true
  end

  def default_margin_value(lcr, session)
    minimal_rate_margin_percent = session[:lcr_edit_options][:lcr][:minimal_rate_margin_percent]
    margin_value = minimal_rate_margin_percent.blank? ? lcr.minimal_rate_margin_percent : minimal_rate_margin_percent
  end
end
