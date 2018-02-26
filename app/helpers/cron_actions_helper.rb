# -*- encoding : utf-8 -*-
module CronActionsHelper
  def show_user_selection(target)
    case(target)
      when -3
        _('Prepaid')
      when -2
        _('Postpaid')
      when -1
        _('All_Users')
      end
  end
  def correct_target_name(cs)
     target = cs.target
     case cs.target_class
      when 'Provider'
        target ? _('Provider') + ': ' + link_nice_provider(target) : _('All_providers')
      when 'User'
        if cs.change_tariff_details == 'For_User'
          target ? _('User') + ': ' + link_nice_user(target) : show_user_selection(cs.target_id)
        else
          _('All_users_and_location') + ' ' + (target ? link_to_tariff_name(target) : _('Any')) + ' ' + _('assigned')
        end
      end
  end
end
