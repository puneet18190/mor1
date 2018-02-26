# -*- encoding : utf-8 -*-
# MOR Monitoring Addon.
class MonitoringsController < ApplicationController
  layout 'callc'

  before_filter :access_denied,
                if: -> { !admin? || !monitorings_addon_active? },
                except: [:blocked_ips, :blocked_ip_unblock, :blocked_ips_access_denied, :blocked_ip_block]
  before_filter :blocked_ips_access_denied,
                if: -> { !admin? },
                only: [:blocked_ips, :blocked_ip_unblock, :blocked_ip_block]
  before_filter :check_post_method, only: [:chanspy, :blocked_ip_unblock]
  before_filter :blocked_ip, only: [:blocked_ip_unblock]
  before_filter :new_block_ip, only: [:blocked_ips, :blocked_ip_block]

  # Enable or disable channel spying globaly. Only admin has rights to set this setting and
  #   reseller if he has sufficient privileges
  def chanspy
    # Checkboxes
    %w[blacklist_enabled default_bl_rules disable_chanspy].each do |key|
      params[key] = params[key].to_i
    end

    session[:ma_setting_options] = params

    if params['default_src_score']
      src_score = Src_new_score.where(value: 'default').first
      src_score.score = params['default_src_score'].to_s.strip if src_score
      err = 1 unless src_score and src_score.save
    end

    if params['default_dst_score']
      dst_score = Dst_new_score.where(value: 'default').first
      dst_score.score = params['default_dst_score'].to_s.strip
      err = 1 unless dst_score.save
    end

    if params['default_ip_score']
      ip_score = IpNewScore.where(value: 'default').first
      ip_score.score = params['default_ip_score'].to_s.strip
      err = 1 unless ip_score.save
    end

    if err.to_i.zero?
      Confline.set_chanspy_values(params, current_user.get_correct_owner_id)

      begin
        Server.where(server_type: 'asterisk').each { |server| server.ami_cmd('mor reload') }
        flash[:status] = _('Monitorings_settings_saved')
        session[:ma_setting_options] = {}
      rescue => e
        flash[:notice] = e.to_s
      end
    else
      flash[:notice] = _('Score_should_be_a_natural_number')
    end

    redirect_to(action: :settings) && (return false)
  end

  def settings
    @page_title, @page_icon = [_('Monitorings_settings'), 'magnifier.png']

    @options = session[:ma_setting_options] || Hash.new(nil)
    @lcrs = Lcr.where(user_id: 0)

    @blacklist_enabled, @default_bl_rules, @chanspy_disabled,
    @default_routing_threshold, @default_routing_threshold_2, @default_routing_threshold_3,
    @selected_lcr_1, @selected_lcr_2, @selected_lcr_3 = Confline.set_monitorings_settings(@options)

    @default_src = Src_new_score.default_score
    @default_dst = Dst_new_score.default_score
    @default_ip = IpNewScore.default_score
  end

  def blocked_ips
    @page_title = _('Blocked_IPs')
    @page_icon = 'world_delete.png'

    @blocked_ips = BlockedIP.monitorings_blocked_ips
    @servers = Server.select("id, CONCAT('ID: ', id, ' IP: ', server_ip) AS server_name").all
  end

  def blocked_ip_unblock
    @blocked_ip.unblock
    flash[:status] = _('IP_will_be_unblocked')
    redirect_to(action: :blocked_ips) && (return false)
  end

  def blocked_ips_access_denied
    dont_be_so_smart
    (redirect_to :root) && (return false)
  end

  def blocked_ip_block
    if @block_ip.validate_ip_for_blocking
      @block_ip.save
      flash[:status] = _('IP_will_be_blocked_in_1_minute')
      redirect_to(action: :blocked_ips)
    else
      flash[:notice] = _('IP_was_not_blocked')
      redirect_to(action: :blocked_ips, blocked_ip: params[:blocked_ip])
    end
  end

  private

  def blocked_ip
    @blocked_ip = BlockedIP.where(id: params[:id]).first
    if @blocked_ip.blank?
      flash[:notice] = _('Blocked_IP_was_not_found')
      redirect_to(action: :blocked_ips) && (return false)
    end
  end

  def new_block_ip
    options = {blocked_ip: {}}
    [:blocked_ip, :server_id, :chain].each { |key| options[:blocked_ip][key] = params[:blocked_ip][key].to_s.strip }

    # IP not logged user's
    options[:blocked_ip][:blocked_ip] = '' if options[:blocked_ip][:blocked_ip] == request.remote_ip

    @block_ip = BlockedIP.new(options[:blocked_ip].merge(unblock: 2))
  end
end
