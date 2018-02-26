# -*- encoding : utf-8 -*-
# Server <-> Provider relation
class Serverprovider < ActiveRecord::Base
  attr_accessible :id, :server_id, :provider_id

  belongs_to :provider
  belongs_to :server

  def self.assign_sip_to_all_asterisk
    asterisk_servers, sip_providers =
        Server.where(server_type: :asterisk).pluck(:id),
        Provider.where(tech: :sip, login: '', password: '').where.not(server_ip: 'dynamic').pluck(:id)

    sip_providers.each do |provider_id|
      # Clean up possible incorrect data rows
      where(provider_id: provider_id).delete_all

      # Create new correct data rows
      self.assign_provider_to_asterisk(provider_id, asterisk_servers)
    end
  end

  def self.assign_sip_to_one_asterisk
    reseller_asterisk_server = Server.where(id: Confline.get_value('Resellers_server_id').to_i).first.try(:id) ||
        Server.where(server_type: :asterisk).order(id: :asc).first.try(:id).to_i

    sip_providers = Provider.where(tech: :sip)

    sip_providers.each do |provider|
      provider_id = provider.id
      next if provider.try(:user).try(:usertype).to_s != 'reseller'

      # Clean up possible incorrect data rows
      where(provider_id: provider_id).delete_all

      create(server_id: reseller_asterisk_server, provider_id: provider_id)
    end
  end

  private

  def self.assign_provider_to_asterisk(provider_id, asterisk_servers)
    asterisk_servers.each { |server_id| create(server_id: server_id, provider_id: provider_id) }
  end
end
