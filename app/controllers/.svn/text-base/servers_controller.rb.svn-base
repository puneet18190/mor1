# -*- encoding : utf-8 -*-
# Servers' controller.
class ServersController < ApplicationController

  layout 'callc'

  before_filter :check_post_method, only: [:destroy, :create, :update, :server_add, :server_update, :delete,
                                           :delete_device, :server_change_status]
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_server, only: [:server_providers, :add_provider_to_server, :show, :destroy,
                                     :server_change_gui, :server_change_db, :server_change_core, :server_change_status,
                                     :server_change_gateway_status, :server_test, :server_update, :server_devices_list]
  before_filter :no_access_for_other, only: [:server_providers, :server_devices_list]

  def index
    if !admin?
      dont_be_so_smart
      (redirect_to :root) && (return false)
    else
      redirect_to(action: :list) && (return false)
    end
  end

  def list
    @page_title, @page_icon, @help_link = _('Servers'), 'server.png',
        'http://wiki.kolmisoft.com/index.php/Multi_Server_support'
    # @servers = Server.order(:id).all
    @servers = Server.select('servers.*, devices.ipaddr').
                      joins("LEFT JOIN devices ON devices.name LIKE CONCAT('mor_server_', servers.id)")
    @has_proxy = Server.where(server_type: :sip_proxy).exists?
  end

  def server_providers
    @page_title, @page_icon, @help_link = _('Server_providers'), 'provider.png',
        'http://wiki.kolmisoft.com/index.php/Multi_Server_support'
    @providers = Provider.where(hidden: 0)
    @new_prv = []
    @providers.each do |prv|
      unless Serverprovider.where(server_id: @server, provider_id: prv.id).first
        @new_prv << prv
      end
      @providers = @new_prv
    end
    session[:back] = params
  end

  def add_provider_to_server
    provider_id = params[:provider_add]
    unless @provider = Provider.where(id: provider_id).first
      flash[:notice] = _('Provider_not_found')
      redirect_to(action: :list) && (return false)
    end
    server_id = @server.id
    serv_prov = Serverprovider.where(server_id: @server, provider_id: @provider).first

    unless serv_prov
      Server.add_provider_to_server_if_not_serv_prov(@server, @provider, provider_id)

      if @provider.register == 1
        @provider.servers.each { |server| server.reload }
      end
      flash[:status] = _('Provider_added')
    else
      flash[:notice] = _('Provider_already_exists')
    end
    redirect_to(action: :server_providers, id: server_id) && (return false)
  end


  def show
  end

  def new
    @page_title, @page_icon, @help_link = _('Server_new'), 'add.png',
        'http://wiki.kolmisoft.com/index.php/Multi_Server_support'
    @server = Server.new
  end

  def edit
    @page_title, @page_icon, @help_link = _('Server_edit'), 'edit.png',
        'http://wiki.kolmisoft.com/index.php/Multi_Server_support'

    @server = Server.select('servers.*, devices.ipaddr').
                     joins("LEFT JOIN devices ON devices.name LIKE CONCAT('mor_server_', servers.id)").
                     where(id: params[:id]).first

    unless @server
      flash[:notice] = _('Server_not_found')
      redirect_to(action: :list) && (return false)
    end

    @server_type = @server.server_type
  end

  def server_add
    server, serv = Server.server_add(params)

    begin
      server_errors = server.errors.to_hash

      if server.valid? && (server.server_type == 'other' || serv.run) && server_errors.blank? && server.save
        unless server.server_device
          server.create_server_device
        end
        Server.where(id: server.id).update_all(server_ip: params[:server_ip_for_ami]) if params[:server_type].to_s == 'asterisk'
        flash[:status] = _('Server_created')
      else
        server_errors.each { |error, value| server.errors.add(error, value.first) }
        server_errors = server.errors
        if server_errors.keys.include?(:device)
          error_messages = server_errors.values.first
          flash[:notice] = _(error_messages.first, "mor_server_#{server.id.to_s}") if error_messages
        else
          flash_errors_for(_('Server_not_created'), server)
        end
      end
    rescue => crash
      error = crash.to_s
      if error.include?('No route to host')
        server.errors.add(:server, _('server_unreachable'))
      else
        server.errors.add(:server, error)
      end
      flash_errors_for(_('Server_not_created'), server)
    rescue SystemExit
      server.errors.add(:server, _('asterisk_unreachable'))
      flash_errors_for(_('Server_not_created'), server)
    end
    redirect_to action: :list
  end

  def server_update
    dev, @server, errors = Server.server_update(params, @server)
    server_errors = @server.errors.to_hash
    if dev && @server.valid?
      # Updates server with ip of ami if server valid
      @server.server_ip = params[:server_ip_for_ami] if params[:server_type].to_s == 'asterisk'
      name = "mor_server_#{@server.id}"
      dev.assign_attributes({
                                name: name,
                                fromuser: name,
                                extension: name,
                                username: name,
                            })
      unless dev.valid?
        errors += 1
        if dev.errors.values.first.try(:first).to_s == _('Device_extension_must_be_unique')
          server.errors.add(:device, _('Server_device_extension_not_unique', name))
        end
      end
    end

    begin
      if errors.zero? && server_errors.blank? && @server.save
        # update device
        if dev
          dev.assign_attributes({
            host: @server.hostname,
            ipaddr: params[:server_ip],
            port: @server.port,
            proxy_port: dev.port
          })
          dev.save
          @server.ami_cmd('core show uptime') if @server.server_type == 'asterisk'
        end
        flash[:status] = _('Server_update')
      else
        server_errors.each { |error, value| @server.errors.add(error, value.first) }
        server_errors = @server.errors
        flash_errors_for(_('Server_not_updated'), @server)
      end
    rescue => crash
      error = crash.to_s
      if error.include?('No route to host')
        flash[:notice] = _('server_unreachable')
      else
        flash[:notice] = error
      end
    rescue SystemExit
      flash[:notice] = _('asterisk_unreachable')
    end
    redirect_to(action: :list)
  end

  def delete
    provider = Provider.where(id: params[:id]).first
    dev = provider.device
    unless provider
      flash[:notice] = _('Provider_not_found')
      redirect_to(action: :list) && (return false)
    end
    server = Server.where(id: params[:sid]).first
    unless server
      flash[:notice] = _('Server_not_found')
      redirect_to(action: :list) && (return false)
    end

    server_id = server.id
    serverprovider = Serverprovider.where(provider_id: provider, server_id: server)
    server_device  = ServerDevice.where(device_id: dev, server_id: server_id) if dev.present?

    serverprovider.destroy_all
    server_device.destroy_all
    flash[:status] = _('Providers_deleted')
    redirect_to(action: :server_providers, id: server_id)
  end

  def delete_device
    device = Device.where(id: params[:id]).first
    unless device
      flash[:notice] = _('Device_not_found')
      redirect_to(action: :server_devices_list) && (return false)
    end
    server = Server.where(id: params[:serv_id]).first
    unless server
      flash[:notice] = _('Server_not_found')
      redirect_to(action: :server_devices_list) && (return false)
    end
    server_device = ServerDevice.where(server_id: params[:serv_id], device_id: params[:id]).first
    server_device.destroy
    flash[:status] = _('device_deleted')
    redirect_to(action: :server_devices_list, id: params[:serv_id])
  end

  def destroy
    if @server.server_type == 'sip_proxy'
      flash[:notice] = _('Server_cant_be_deleted')
    elsif @server.destroy
      Device.where(name: "mor_server_#{@server.id}").first.try(:destroy)
      Serverprovider.where(server_id: @server).destroy_all

      flash[:status] = _('Server_deleted')
    else
      flash_errors_for(_('Server_Not_Deleted'), @server)
    end
    redirect_to(action: :list)
  end

  def server_change_gui
    @server.gui = (@server.gui == 1 ? 0 : 1)

    unless @server.save
      flash_errors_for(_('Server_not_updated'), @server)
    end
    redirect_to(action: :list, id: params[:id])
  end

  def server_change_db
    @server.db = (@server.db == 1 ? 0 : 1)

    unless @server.save
      flash_errors_for(_('Server_not_updated'), @server)
    end
    redirect_to(action: :list, id: params[:id])
  end


  def server_change_core
    if @server.server_type.to_sym == :other
      flash[:notice] = 'Core cannot be changed for Servers which Type is other'
      redirect_to(action: :list) && (return false)
    end

    @server.core = (@server.core == 1 ? 0 : 1)

    unless @server.save
      flash_errors_for(_('Server_not_updated'), @server)
    end
    redirect_to(action: :list, id: params[:id])
  end

  def server_change_status
    if @server.active == 1
      value = 0
      flash[:notice] = _('Server_disabled')
    else
      value = 1
      flash[:status] = _('Server_enabled')
    end
    sql = "UPDATE servers SET active = #{value} WHERE id = #{@server.id}"
    ActiveRecord::Base.connection.update(sql)
    redirect_to(action: :list, id: @server.id)
  end

  def server_change_gateway_status
    server_id = params[:id]
    if @server.gateway_active == 1
      @server.gateway.destroy
      value = 0
      flash[:notice] = _('Server_marked_as_not_gateway')
    else
      gtw = Gateway.new({setid: 1, destination: "sip:#{@server.server_ip}:#{@server.port}", server_id: server_id})
      gtw.save
      value = 1
      flash[:status] = _('Server_marked_as_gateway')
    end
    sql = "UPDATE servers SET gateway_active = #{value} WHERE id = #{server_id}"
    res = ActiveRecord::Base.connection.update(sql)
    redirect_to(action: :list, id: server_id)
  end

  def server_test
    @help_link = 'http://wiki.kolmisoft.com/index.php/Multi_Server_support'
    server_type = @server.server_type.to_sym
    if (@server.core.to_i == 0) || (server_type == :sip_proxy)
      dont_be_so_smart
      redirect_to :root
    else
      session[:flash_not_redirect] = 1
      server_test_ok = 0
      ami_status = true
      begin
        ami_status = @server.ami_cmd('core show version') if server_type == :asterisk
      rescue
        flash_help_link = 'http://wiki.kolmisoft.com/index.php/GUI_Error_-_SystemExit'
        flash[:notice] = _('Cannot_connect_to_asterisk_server') + "<a href='#{flash_help_link}' target='_blank'><img alt='Help' src='#{Web_Dir}/images/icons/help.png' title='#{_('Help')}' />&nbsp;#{_('Click_here_for_more_info')}</a>"
        server_test_ok = 0
      else
        server_test_ok = 1 unless ami_status
      end
      session[:server_test_ok] = server_test_ok
      render(layout: 'layouts/mor_min')
    end
  end

  # when ccl_active = 1 shows all devices of a certain server
  def server_devices_list
    if !ccl_active? || (session[:usertype] != 'admin' && ccl_active?)
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
    @page_title, @page_icon, @help_link  = _('Server_devices'), 'server.png',
        'http://wiki.kolmisoft.com/index.php/Multi_Server_support'
    # ip_auth + server_devices.server_id is null + server_devices.server_id is not that server + not server device(which were created with server creation)
    @devices = Device.select('devices.*, server_devices.server_id AS serv_id').joins("LEFT JOIN server_devices ON (server_devices.device_id = devices.id AND  server_devices.server_id = #{params[:id].to_i}) LEFT JOIN users ON (users.id = devices.user_id)").where("device_type != 'SIP' AND users.owner_id = #{current_user.id} AND server_devices.server_id is null AND user_id != -1 AND name not like 'mor_server_%'").order('extension ASC').all
  end

  def add_device_to_server
    @device = Device.where(id: params[:device_add].to_i).first
    if !@device
      flash[:notice] = _('Device_not_found')
    else
      serv_dev = ServerDevice.where(server_id: params[:id], device_id: @device).first

      if !serv_dev
        server_device = ServerDevice.new_relation(params[:id], @device.id)
        server_device.save

        flash[:status] = _('Device_added')
      else
        flash[:notice] = _('Device_already_exists')
      end
    end
    redirect_to(action: :server_devices_list, id: params[:id]) && (return false)
  end

  private

  def find_server
    @server = Server.where(id: params[:id]).first
    unless @server
      flash[:notice] = _('Server_not_found')
      redirect_to(action: :list) && (return false)
    end
  end

  def no_access_for_other
    if Server.where(id: params[:id]).first.try(:server_type).to_s == 'other'
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
  end
end
