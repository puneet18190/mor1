# -*- encoding : utf-8 -*-
module UsersHelper
  # checks if reseller is allowed to add more users
  def allow_add_rs_user?
    user_limit = 2;
    !reseller? || ((User.where(owner_id: current_user.id).count < user_limit) || (reseller_active? && current_user.own_providers != 1) || reseller_pro_active?)
  end

  # checks to see if reseller_users_restriction is required to be shown
  def show_reseller_users_restriction
    reseller? && (!reseller_active? || ((current_user.own_providers == 1) && !reseller_pro_active?))
  end

  # checks to see if current user can set responsible accountant
  def user_permission(user, params)
  	return (
      (admin? || accountant?) &&
      (params[:action] == 'default_user' ||
      	((user.is_user? || user.is_reseller? || user.is_partner?) && (user.owner_id.to_i == 0 || user.owner.is_partner?)))
      )
  end

  # checks if global thresholds should be checked or not
  def global_blacklist_threshold(user)
    if (user.routing_threshold.to_s == '-1') && (user.routing_threshold_2.to_s == '-1') &&
      (user.routing_threshold_3.to_s == '-1')
      radio_button = 'checked'
    else
      radio_button = 'false'
    end

    return radio_button
  end

  def not_global_blacklist_threshold(user)
    if global_blacklist_threshold(user) == 'checked'
      radio_button = 'false'
    else
      radio_button = 'checked'
    end

    return radio_button
  end

  # checks if global blacklists should be checked or not
  def global_blacklist_lcrs(user)
    if (user.blacklist_lcr.to_s == '-1') && (user.blacklist_lcr_2.to_s == '-1') && (user.blacklist_lcr_3.to_s == '-1')
      radio_button = 'checked'
    else
      radio_button = 'false'
    end

    return radio_button
  end

  def not_global_blacklist_lcrs(user)
    if global_blacklist_lcrs(user) == 'checked'
      radio_button = 'false'
    else
      radio_button = 'checked'
    end

    return radio_button
  end

  # returns agreement date
  def nice_agreement_date(user)
    ad = user.agreement_date
    ad = Time.now if !ad
    ad = ad.to_date if ad.class != Date
    earliest_date = (Time.now - 1000.year + 6.year).to_date
    latest_date  = (Time.now + 1000.year + 6.year).to_date
    ad = earliest_date if ad < earliest_date
    ad = latest_date if ad > latest_date
    ad
  end

  # picks out only those pbx pools which do not contain any of the user's devices extensions
  def pick_out_pbx_pools(user)
    pbx_pools = PbxPool.where(owner_id: current_user_id).order('name ASC').all
    if user.id
      devices = user.devices

      user_extensions = Extline.select('DISTINCT(exten), user_id').
          where("devices.user_id = #{user.id}").
          joins('JOIN devices ON devices.id = extlines.device_id').
          to_a.map(&:exten)

      pbx_pools.each do |pbx_pool|
        unless (user.pbx_pool_id == pbx_pool.id || user.pbx_pool == nil)
          if pbx_pool.id <= 1
            pool_extensions = Extline.select("distinct exten").where(context: 'mor_local').all.to_a
          else
            pool_extensions = Extline.select("distinct exten").where(context: "pool_#{pbx_pool.id}_mor_local").all.to_a
          end
          pool_extensions = pool_extensions.map{ |item| item.exten }.flatten

          pbx_pools -= Array(pbx_pool) unless (user_extensions & pool_extensions).empty?
        end
      end
    end
    pbx_pools.map { |pool| [pool.name, pool.id] }
  end

  # returns quickforward rules with user's rule
  def quickforward_rules_with_current_rule(current_user, user)
    rules = current_user.quickforwards_rules.to_a
    current_rule = user.quickforwards_rule
    if user.owner.is_reseller? && current_rule.try(:user).try(:is_admin?)
      rules << user.quickforwards_rule
    end
    rules
  end

  # returns quickforward rule's name
  def quicforward_name(rule, user)
    if user.owner.is_reseller?
      return rule.name + (rule.user.is_admin? ? ' (admin)' : '')
    else
      return rule.name
    end
  end
end
