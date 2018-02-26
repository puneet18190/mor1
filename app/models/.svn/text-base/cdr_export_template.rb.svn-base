# -*- encoding : utf-8 -*-
class CdrExportTemplate < ActiveRecord::Base
  attr_protected
  belongs_to :user

  validates :name,
            uniqueness: {message: _('Name_must_be_unique'), scope: :user_id},
            presence: {message: _('Name_cannot_be_blank')}

  before_save :set_nice_columns

  def columns_array
    columns.to_s.split(';')
  end

  def set_nice_columns
    headers = CdrExportTemplate.column_headers(user.try(:usertype).to_s.to_sym)
    self.nice_columns = columns_array.map { |name| headers[name] }.join(';')
  end

  def self.column_headers(usertype = :admin)
    headers = {}

    case usertype
      when :accountant
      when :reseller
      when :partner
      when :user
      else
        headers = {
            'calldate2' => _('Date'),
            'clid' => _('Called_from'),
            'dst' => _('Called_to'),
            'prefix' => _('Prefix'),
            'destination' => _('Destination_name'),
            'nice_billsec' => _('User_Billsec'),
            'dispod' => _('hangup_cause'),
            'server_id' => _('Server'),
            'provider_name' => _('Provider'),
            'provider_rate' => _('Provider_Rate'),
            'provider_price' => _('Provider_Price'),
            'nice_reseller' => _('Reseller'),
            'reseller_rate' => _('Reseller_rate'),
            'reseller_price' => _('Reseller_price'),
            'user' => _('User'),
            'user_rate' => _('User_Rate'),
            'user_price' => _('User_Price'),
            'did' => _('DID_Number'),
            'did_prov_price' => _('DID_provider_price'),
            'did_inc_price' => _('DID_incoming_price'),
            'did_price' => _('DID_Price'),
            'profit' => _('Profit'),
            'id' => _('Call_ID'),
            'src' => _('Source_Number'),
            'dst_original' => _('Destination_Number'),
            'duration' => _('Duration'),
            'billsec' => _('Billsec'),
            'disposition' => _('Disposition'),
            'accountcode' => _('Accountcode'),
            'uniqueid' => _('UniqueID'),
            'dst_device_id' => _('Dst_Device_ID'),
            'provider_id' => _('Provider_ID'),
            'provider_billsec' => _('Provider_Billsec'),
            'user_id' => _('User_ID'),
            'reseller_id' => _('Reseller_ID'),
            'reseller_billsec' => _('Reseller_Billsec'),
            'card_id' => _('Card_id'),
            'hangupcause' => _('Hang_up_cause_code'),
            'server_id' => _('Server_ID'),
            'did_provider_id' => _('DID_Provider_ID'),
            'originator_ip' => _('Originator_IP'),
            'terminator_ip' => _('Terminator_IP'),
            'real_duration' => _('Real_Duration'),
            'real_billsec' => _('Real_Billsec'),
            'did_billsec' => _('DID_Billsec'),
            'dst_user_id' => _('Dst_User_ID'),
            'partner_id' => _('Partner_ID'),
            'partner_price' => _('Partner_Price'),
            'partner_rate' => _('Partner_Rate'),
            'partner_billsec' => _('Partner_Billsec')
        }

        headers['nice_src_device'] = _('Device') if Confline.get_value('Show_device_and_cid_in_last_calls').to_i == 1
    end

    headers
  end

  def self.update_setting_changes(user_id = 0)
    if Confline.get_value('Show_device_and_cid_in_last_calls', user_id).to_i == 0
      CdrExportTemplate.where("user_id = ? AND columns LIKE '%nice_src_device%'", user_id).all.each do |template|
        template.columns = template.columns.sub('nice_src_device', '')
        template.set_nice_columns
        template.save
      end
    end
  end
end
