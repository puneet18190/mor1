# -*- encoding : utf-8 -*-
class MorApi
  require 'builder/xmlbase'

  extend UniversalHelpers

  def MorApi.check_params_with_key(params, request)
    # Hack find user from params u and p
    user = User.where(["username = ?", params[:u].to_s]).first
      user_id = params[:user_id]
      hash = params[:hash]
      period_start = params[:period_start]
      period_end = params[:period_end]
      direction = params[:direction]
      calltype = params[:calltype]
      device = params[:device]
      balance = params[:balance]
      users = params[:users]
      block = params[:block]
      email = params[:email]
      mtype = params[:mtype]
      tariff_id = params[:tariff_id]
      only_did = params[:only_did]
      ret = {}
      ret[:user_id] = user_id.to_i if user_id and user_id.to_s !~ /[^0-9]/ and user_id.to_i >= 0
      ret[:hash] = hash.to_s if hash and hash.to_s.length == 40
      ret[:period_start] = period_start.to_i if period_start and period_start.to_s !~ /[^0-9]/
      ret[:period_end] = period_end.to_i if period_end and period_end.to_s !~ /[^0-9]/
      ret[:direction] = direction.to_s if direction and (direction.to_s == 'outgoing' or direction.to_s == 'incoming')
      ret[:calltype] = calltype.to_s if calltype and ['all', 'answered', 'busy', 'no_answer', 'failed', 'missed', 'missed_inc', 'missed_inc_all', 'missed_not_processed_inc'].include?(calltype.to_s)
      ret[:device] = device.to_s if device and (device.to_s !~ /[^0-9]/ or device.to_s == 'all')
      ret[:balance] = balance if balance and balance.to_s !~ /[^0-9.\-\+]/
      ret[:users] = users.to_s if users and (users =~ /^postpaid$|^prepaid$|^all$|^[0-9,]+$/)
      ret[:block] = block.to_s if block and (block =~ /true|false/)
      ret[:email] = email.to_s if email and (email =~ /true|false/)
      ret[:mtype] = mtype.to_s if mtype and (mtype !~ /[^0-9]/)
      ret[:tariff_id] = tariff_id.to_i if tariff_id and (tariff_id.to_s !~ /[^0-9]/)
      ret[:only_did] = only_did.to_i if only_did and (only_did.to_s !~ /[^0-9]/)

      ret[:key] = Confline.get_value("API_Secret_Key", user ? user.get_correct_owner_id : 0).to_s
      string =
          ret[:user_id].to_s +
              ret[:period_start].to_s +
              ret[:period_end].to_s +
              ret[:direction].to_s+
              ret[:calltype].to_s+
              ret[:device].to_s+
              ret[:balance].to_s+
              ret[:users].to_s+
              ret[:block].to_s+
              ret[:email].to_s+
              ret[:mtype].to_s+
              ret[:key].to_s+
              ret[:callerid].to_s+
              ret[:pin].to_s

      ret[:system_hash] = Digest::SHA1.hexdigest(string)
      ret[:device] = nil if ret[:device] == 'all'
      ret[:calltype] = 'no answer' if ret[:calltype] == 'no_answer'
      ret[:balance] = balance.to_d

    if Confline.get_value("API_Disable_hash_checking", user ? user.get_correct_owner_id : 0).to_i == 0
      unless ret[:system_hash].to_s == ret[:hash]
        MorApi.create_error_action(params, request, 'API : Incorrect hash')
      end
      return ret[:system_hash].to_s == ret[:hash], ret
    else
      return true, ret
    end
  end

  def MorApi.create_error_action(params, request, name)
    Action.create({:user_id => -1, :date => Time.now(), :action => 'error', :data => name, :data2 => (request ? request.url.to_s[0..255] : ''), :data3 => (request ? request.remote_addr : ''), :data4 => params.inspect.to_s[0..255]})
  end

  def self.hash_checking(params, request, params_action, current_user = nil)
    if ApiRequiredParams.method_is_defined_in_required_params_module(params_action)
      hash_params, ret = [ApiRequiredParams.get_required_params_for_api_method(params_action), params]
    else
      hash_params, ret, params = self.check_params_with_all_keys(params, request)
    end

    self.compare_system_and_hashes(hash_params, ret, params, request, current_user)
  end


  def self.check_params_with_all_keys(params, request)
    MorLog.my_debug params.to_yaml
    user_id = params[:user_id]
    hash = params[:hash]
    period_start = params[:period_start]
    period_end = params[:period_end]
    direction = params[:direction]
    calltype = params[:calltype]
    device = params[:device]
    balance = params[:balance]
    users = params[:users]
    block = params[:block]
    email = params[:email]
    mtype = params[:mtype]
    tariff_id = params[:tariff_id]
    only_did = params[:only_did]
    ret = {}
    ret[:user_id] = user_id.to_i if user_id && user_id.to_s !~ /[^0-9]/ && user_id.to_i >= 0
    ret[:hash] = hash.to_s if hash and hash.to_s.length == 40
    ret[:period_start] = period_start.to_i if period_start and period_start.to_s !~ /[^0-9]/
    ret[:period_end] = period_end.to_i if period_end and period_end.to_s !~ /[^0-9]/
    ret[:direction] = direction.to_s if direction and (direction.to_s == 'outgoing' or direction.to_s == 'incoming')
    ret[:calltype] = calltype.to_s if calltype and ['all', 'answered', 'busy', 'no_answer', 'failed', 'missed', 'missed_inc', 'missed_inc_all', 'missed_not_processed_inc'].include?(calltype.to_s)
    ret[:device] = device.to_s if device and (device.to_s !~ /[^0-9]/ or device.to_s == 'all')
    ret[:balance] = balance if balance and balance.to_s !~ /[^0-9.\-\+]/
    ret[:users] = users.to_s if users and (users =~ /^postpaid$|^prepaid$|^all$|^[0-9,]+$/)
    ret[:block] = block.to_s if block and (block =~ /true|false/)
    ret[:email] = email.to_s if email #and (email =~ /true|false/)
    ret[:mtype] = mtype.to_s if mtype and (mtype !~ /[^0-9]/)
    ret[:tariff_id] = tariff_id.to_i if tariff_id and (tariff_id.to_s !~ /[^0-9]/)
    ret[:only_did] = only_did.to_i if only_did and (only_did.to_s !~ /[^0-9]/)

    ['u0', 'u1', 'u2', 'u3', 'u4', 'u5', 'u6', 'u7', 'u8', 'u9', 'u10', 'u11', 'u12', 'u13', 'u14', 'u15', 'u16', 'u17', 'u18', 'u19', 'u20', 'u21', 'u22', 'u23', 'u24', 'u25', 'u26', 'u27', 'u28',
     'ay', 'am', 'ad', 'by', 'bm', 'bd', 'pswd', 'user_warning_email_hour' 'pgui', 'pcsv', 'ppdf',
     'recording_forced_enabled', 'i4', 'tax4_enabled', 'tax2_enabled', 'accountant_type_invalid',
     'block_at_conditional', 'tax3_enabled', 'accountant_type', 'tax1_value', 'show_zero_calls',
     'warning_email_active', 'compound_tax', 'tax4_name', 'allow_loss_calls', 'tax3_name', 'tax2_name',
     'credit', 'tax1_name', 'total_tax_name', 'tax2_value', 'tax4_value',
     'i1', 'tax3_value', 'cyberplat_active', 'i2', 'i3', 'recording_enabled', 'email_warning_sent_test',
     'own_providers', 'a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a7', 'a8', 'a9', 'did', 'forward_to',
     'callflow_action', 'state', 'forward_to_device', 'external_number', 'did_id', 'device_callerid', 'src_callerid', 'custom', 'fax_device'].each { |key|
      ret[key.to_sym] = params[key.to_sym] if params[key.to_sym]
    }

    ret[:s_user] = params[:s_user] if params[:s_user] and params[:s_user].to_s !~ /[^0-9]/
    ret[:s_call_type] = params[:s_call_type] if params[:s_call_type]
    ret[:s_device] = params[:s_device] if params[:s_device] and (params[:s_device].to_s !~ /[^0-9]/ or params[:s_device].to_s == 'all')
    ret[:s_provider] = params[:s_provider] if params[:s_provider] and (params[:s_provider].to_s !~ /[^0-9]/ or params[:s_provider].to_s == 'all')
    ret[:s_hgc] = params[:s_hgc] if params[:s_hgc] and (params[:s_hgc].to_s !~ /[^0-9]/ or params[:s_hgc].to_s == 'all')
    ret[:s_did] = params[:s_did] if params[:s_did] and (params[:s_did].to_s !~ /[^0-9]/ or params[:s_did].to_s == 'all')

    ['s_destination', 'order_by', 'order_desc', 'description', 'pin', 'type', 'devicegroup_id', 'phonebook_id', 'name', 'speeddial'].each { |key|
      ret[key.to_sym] = params[key.to_sym] if params[key.to_sym]
    }

    if params[:action] != 'card_from_group_sell'
      ret[:number] = params[:number] if params[:number]
    end

    ret[:s_user_id] = params[:s_user_id] if params[:s_user_id] and params[:s_user_id].to_s !~ /[^0-9]/
    ret[:s_from] = params[:s_from] if params[:s_from] and params[:s_from].to_s !~ /[^0-9]/
    ret[:s_till] = params[:s_till] if params[:s_till] and params[:s_till].to_s !~ /[^0-9]/
    ret[:lcr_id] = params[:lcr_id].to_s if params[:lcr_id] and (params[:lcr_id].to_s !~ /[^0-9]/)
    ret[:dst] = params[:dst].to_s if params[:dst]
    ret[:src] = params[:src].to_s if params[:src]
    ret[:message] = params[:message].to_s if params[:message]
    ret[:caller_id] = params[:caller_id].to_s if params[:caller_id]
    ret[:device_id] = params[:device_id].to_s if params[:device_id]
    ret[:provider_id] = params[:provider_id].to_s if params[:provider_id]

    ['s_transaction', 's_completed', 's_username', 's_first_name', 's_last_name', 's_paymenttype', 's_amount_max', 's_currency', 's_number', 's_pin',
     'p_currency', 'paymenttype', 'tax_in_amount', 'amount', 'transaction', 'payer_email', 'shipped_at', 'fee', 'id', 'quantity', 'callerid', 'cardgroup_id',
     'status', 'date_from', 'date_till', 's_reseller_did', 's_did_pattern', 'lcr_id', 'dst', 'src', 'message', 'caller_id', 'device_id',
     'device_location_id', 'location_id', 'service_id', 'new_service_name', 'new_service_type'].each { |key|
      ret[key.to_sym] = params[key.to_sym] if params[key.to_sym]
    }

    # adding send email params
    ["server_ip", "device_type", "device_username", "device_password", "login_url", "login_username", "username", "first_name",
     "last_name", "full_name", "nice_balance", "warning_email_balance", "nice_warning_email_balance",
     "currency", "user_email", "company_email", "company", "primary_device_pin", "login_password", "user_ip",
     "date", "auth_code", "transaction_id", "customer_name", "company_name", "url", "trans_id",
     "cc_purchase_details", "payment_amount", "payment_payer_first_name",
     "payment_payer_last_name", "payment_payer_email", "payment_seller_email", "payment_receiver_email", "payment_date", "payment_free",
     "payment_currency", "payment_type", "payment_fee", "call_list", 'email_name', 'email_to_user_id', 'caller_id', 'device_id', "calldate",
     "source", "destination", "billsec", 'calls_string', 'cli_number'].each { |key|
      ret[key.to_sym] = params[key.to_sym] if params[key.to_sym]
    }

    #for future: notice - users should generate hash in same order.

    hash_param_order = ['user_id', 'period_start', 'period_end', 'direction', 'calltype', 'device', 'balance', 'users',
      'block', 'email', 'mtype', 'tariff_id', 'u0', 'u1', 'u2', 'u3', 'u4', 'u5', 'u6', 'u7', 'u8', 'u9', 'u10', 'u11',
      'u12', 'u13', 'u14', 'u15', 'u16', 'u17', 'u18', 'u19', 'u20', 'u21', 'u22', 'u23', 'u24', 'u25', 'u26', 'u27',
      'u28', 'ay', 'am', 'ad', 'by', 'bm', 'bd', 'pswd', 'user_warning_email_hour', 'pgui', 'pcsv', 'ppdf',
      'recording_forced_enabled', 'i4', 'tax4_enabled', 'tax2_enabled', 'accountant_type_invalid',
      'block_at_conditional', 'tax3_enabled', 'accountant_type', 'tax1_value', 'show_zero_calls',
      'warning_email_active', 'compound_tax', 'tax4_name', 'allow_loss_calls', 'tax3_name', 'tax2_name', 'credit',
      'tax1_name', 'total_tax_name', 'tax2_value', 'tax4_value', 'i1', 'tax3_value', 'cyberplat_active', 'i2', 'i3',
      'recording_enabled', 'email_warning_sent_test', 'own_providers', 'a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a7',
      'a8', 'a9', 's_user', 's_call_type', 's_device', 's_provider', 's_hgc', 's_did', 's_destination', 'order_by',
      'order_desc', 'only_did', 'description', 'pin', 'type', 'devicegroup_id', 'phonebook_id', 'number', 'name',
      'speeddial', 's_user_id', 's_from', 'provider_id', 's_till', 's_transaction', 's_completed', 's_username',
      's_first_name', 's_last_name', 's_paymenttype', 's_amount_max', 's_currency', 's_number', 's_pin', 'p_currency',
      'paymenttype', 'tax_in_amount', 'amount', 'transaction', 'payer_email', 'fee', 'id', 'quantity', 'callerid',
      'cardgroup_id', 'status', 'date_from', 'date_till', 's_reseller_did', 's_did_pattern', 'lcr_id', 'dst', 'src',
      'message', "server_ip", "device_type", "device_username", "device_password", "login_url", "login_username",
      "username", "first_name", "last_name", "full_name", "nice_balance", "warning_email_balance",
      "nice_warning_email_balance", "currency", "user_email", "company_email", "company", "primary_device_pin",
      "login_password", "user_ip", "date", "auth_code", "transaction_id", "customer_name", "company_name", "url",
      "trans_id", "cc_purchase_details", "payment_amount", "payment_payer_first_name", "payment_payer_last_name",
      "payment_payer_email", "payment_seller_email", "payment_receiver_email", "payment_date", "payment_free",
      "payment_currency", "payment_type", "payment_fee", "call_list", 'email_name', 'email_to_user_id', 'caller_id',
      'device_id', "calldate", "source", "destination", "billsec", 'calls_string', 'did', 'forward_to',
      'callflow_action', 'state', 'forward_to_device', 'external_number', 'did_id', 'device_calerid', 'src_callerid',
      'custom', 'fax_device', 'device_location_id', 'location_id', 'cli_number', 'new_service_name', 'new_service_type', 'service_id']

    [hash_param_order, ret, params]
  end

  def self.compare_system_and_hashes(hash_params, ret, params, request, current_user = nil)
    user = current_user

    if params[:controller].to_s != 'api' && user.blank?
      user = if params[:u].present?
               User.where(username: params[:u].to_s).first
             elsif params[:id].present? && params[:controller].to_s != 'test'
               User.where(uniquehash: params[:id].to_s).first
             else
               User.first
             end
    end

    owner_id = user ? user.get_correct_owner_id_for_api : 0

    ret[:no_user] = true if user.blank?

    string = ''

    # For backwards compatibility we do not include u = admin in to the hash,
    # but all others u are included for security reasons
    hash_params = [] if (ret[:action] == 'quickstats_get' || (ret[:api_path].present? &&
      ret[:api_path].include?('quickstats_get'))) && ret[:u] == 'admin'

    hash_params.each { |key|
      MorLog.my_debug key if ret[key.to_sym]
      string << ret[key.to_sym].to_s
    }

    if user.try(:is_reseller?) &&
      reseller_hash_string = string.dup
      ret[:reseller_key] = Confline.get_value('API_Secret_Key').to_s if Confline.get_value("Allow_API").to_i == 1
      reseller_hash_string << ret[:reseller_key].to_s

      ret[:reseller_system_hash] = Digest::SHA1.hexdigest(reseller_hash_string) if ret[:reseller_key].present?
    end

    if (Confline.get_value('Allow_API', user.try(:get_correct_owner_id_for_api).to_i).to_i == 1)
      ret[:key] = Confline.get_value('API_Secret_Key', owner_id).to_s
      string << ret[:key]
      ret[:system_hash] = Digest::SHA1.hexdigest(string) if ret[:key].present?
    end

    ret[:device] = nil if ret[:device] == 'all'
    ret[:calltype] = 'no answer' if ret[:calltype] == 'no_answer'
    ret[:balance] = params[:balance].to_d

    hashes_match = (ret[:system_hash].present? && ret[:system_hash].to_s == ret[:hash].to_s) ||
    (user.try(:is_reseller?) && ret[:reseller_system_hash].present? && ret[:hash].to_s == ret[:reseller_system_hash].to_s)

    if user && user.is_reseller? && ret[:system_hash].blank? && ret[:reseller_system_hash].present?
      ret[:system_hash] = ret[:reseller_system_hash]
      ret[:key] = ret[:reseller_key]
    end

    if (Confline.get_value('Allow_API', user.try(:get_correct_owner_id_for_api).to_i).to_i == 1 &&
        Confline.get_value('API_Disable_hash_checking', owner_id).to_i == 1) ||
        (user && user.is_reseller? && Confline.get_value("Allow_API").to_i == 1 && Confline.get_value('API_Disable_hash_checking').to_i == 1)
      [true, ret, hash_params]
    else
      if ret[:key].present? || (user && user.is_reseller? && ret[:reseller_key].present?)
        unless hashes_match
          MorApi.create_error_action(params, request, 'API : Incorrect hash')
        end
      else
        MorApi.create_error_action(params, request, 'API : API must have Secret key')
      end

      [hashes_match, ret, hash_params]
    end
  end

  # This is THE method to add error string to xml object.
  def MorApi.return_error(string, doc = nil)
    if doc
      doc.status { doc.error(string) }
      return doc
    else
      doc = Builder::XmlMarkup.new(:target => out_string = "", :indent => 2)
      doc.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
      doc.status { doc.error(string) }
      return out_string
    end
  end

  def MorApi.list_device_content(doc, device)
    Device.content_columns.each do |column_object|
      column = column_object.name
      add_tag(doc, column, device[column].to_s)
    end
  end

  def MorApi.list_codecs(doc, device)
    device_codecs = device.codecs
    # lambda which checks if codecs are available for device
    active = lambda { |codec| codec if device_codecs.include?(codec) }

    # lambda that creates [audio/video] xml tag
    list = lambda do |codec_type|
      codecs =  device.codecs_order(codec_type).select(&active)
      # web browsers do not escape 'video' tag, so that it is necessary to change it to 'video_codecs'
      tag_name = codec_type + '_codecs'
      add_tag(doc, tag_name, codecs.map(&:name).join(', '))
    end

    doc.codecs{ ['audio', 'video'].each(&list) }
  end

  def MorApi.add_tag(doc, name, content)
    doc.tag!(name){
      doc.text!(content)
    }
  end


  def MorApi.loggin_output(doc, user)
    doc.action {
      doc.name("login")
      doc.status("ok")
      doc.user_id("#{user.id.to_s}")
      doc.status_message("Successfully logged in")
    }
    return doc
  end

  def MorApi.failed_loggin_output(doc, remote_address)
    doc.action {
      doc.name("login")
      doc.status("failed")
      if Action.disable_login_check(remote_address).to_i == 0
        doc.status_message("Please wait 10 seconds before trying to login again")
      else
        doc.status_message("Login failed")
      end
    }
    return doc
  end

  def MorApi.logout_output(doc)
    doc.action {
      doc.name("logout")
      doc.status("ok")
    }
    return doc
  end

  def MorApi.failed_logout_output(doc)
    doc.action {
      doc.name("logout")
      doc.status("failed")
    }
    return doc
  end

  def MorApi.error_fro_callback(params)
    username, pin, server_id = params[:u].to_s, params[:card_pin].to_s, params[:server_id].to_s
    user = User.where(username: username).first

    if (username.length <= 0) || !user
      return 'Not authenticated'
    else
      device = Device.where(id: params[:device]).first
      if !params[:device] || !device || (device.user_id != user.id)
        return 'Bad device'
      elsif !params[:src] || (params[:src].length <= 0)
        return 'No source'
      end

      tariff = Tariff.where(id: params[:lega_tariff_id]).first

      if params[:lega_tariff_id].present?
        if (user.is_reseller?) && (Confline.get_value("Allow_Resellers_to_use_Admin_Tariffs") != '1') && (tariff.owner_id == 0 if tariff.present?)
          return 'Reseller not allowed to use Admin tariffs'
        end

        if !tariff
          return 'No tariff'
        elsif tariff.purpose.to_s == 'provider' || (user.is_admin? && tariff.owner_id != user.id)
          return 'Bad tariff'
        end
      end

      if pin.present?
        pin_not_found = 'PIN was not found'

        if !/^\d+$/.match(pin)
          return pin_not_found
        elsif !Card.where(pin: pin).first
          return pin_not_found
        end
      end

      server = Server.where(id: server_id).first
      if params[:server_id].present? && server.blank?
        return 'Server was not found'
      end

      return nil
    end
  end

  def MorApi.find_legs(device, src)
    legA = Confline.get_value("Callback_legA_CID", 0)
    legB = Confline.get_value("Callback_legB_CID", 0)
    custom_legA = Confline.get_value2('Callback_legA_CID', 0)
    custom_legB = Confline.get_value2('Callback_legB_CID', 0)

    legA_cid = (legA == 'device' ? device.callerid_number : (legA == 'custom' ? custom_legA : src))
    legB_cid = (legB == 'device' ? device.callerid_number : (legB == 'custom' ? custom_legB : src))

    legA_cid = src if legA_cid.blank?
    legB_cid = src if legB_cid.blank?

    return legA_cid, legB_cid
  end

  def self.device_clis_get(doc, params)
    clis = []
    users_id = params[:users_id]
    devices_id = params[:devices_id]
    owner = User.where(username: params[:u]).first
    owner_id = owner.try(:id)
    user_ids = User.where(owner_id: owner_id).pluck(:id)
    acc_user_ids = User.where(owner_id: 0, usertype: 'user').pluck(:id)
    if is_number?(users_id)
      if owner_accountant?(owner)
        user = User.where(id: users_id, owner_id: 0, usertype: 'user').first
      elsif is_owner?(owner_id)
        user = User.where(id: users_id, owner_id: owner_id).first
      else
        user = User.where(id: users_id).first
      end
    end
    if is_number?(devices_id)
      device = Device.where(id: devices_id).first
    end
    if users_id && devices_id
      if user.present?
        if device.present?
          devices = user.devices.where(id: devices_id)
          device_each_clis(devices, clis)
        else
          doc.error('Device was not found')
          return doc
        end
      else
        doc.error('User was not found')
        return doc
      end
    elsif users_id
      if user.present?
        devices = user.devices
        device_each_clis(devices, clis)
      else
        doc.error('User was not found')
        return doc
      end
    elsif devices_id
      if device.present?
        if owner_accountant?(owner)
          devices = Device.where(id: devices_id, user_id: acc_user_ids)
          device_each_clis(devices, clis)
        elsif is_owner?(owner_id)
          devices = Device.where(id: devices_id, user_id: user_ids)
          device_each_clis(devices, clis)
        else
          clis = device.callerids
        end
      else
        doc.error('Device was not found')
        return doc
      end
    elsif
      if owner_accountant?(owner)
        devices = Device.where(user_id: acc_user_ids)
      elsif is_owner?(owner_id)
        devices = Device.where(user_id: user_ids)
      else
        devices = Device.all
      end
      device_each_clis(devices, clis)
    end
    if clis.present?
      clis.each do |cli|
        doc.cli_id(cli.id)
        doc.cli_cli(cli.cli)
        device = Device.where(id: cli.device_id).first
        doc.cli_device(device.try(:nice_device))
        doc.cli_description(cli.description)
        doc.cli_added_at(cli.added_at)
        doc.cli_updated_at(cli.updated_at)
        doc.cli_ivr(Ivr.where(id: cli.ivr_id).first.try(:name)) if cli.ivr_id != 0
        doc.cli_comment(cli.comment)
        doc.cli_email_callback(cli.email_callback)
        doc.cli_banned(cli.banned)
      end
    else
        doc.error('CLIs were not found')
    end
    doc
  end

  def self.calling_card_update(doc, params, current_user)

    card_id = params[:card_id]
    number = params[:number]
    name = params[:name]
    pin = params[:pin]
    batch_number = params[:batch_number]
    callerid = params[:callerid]
    min_balance = params[:min_balance]
    daily_charge_paid_till = params[:daily_charge_paid_till]
    language = params[:language]
    user_id = params[:distributor]

    if is_number?(card_id)
      card = Card.find(card_id)
      if card.present?
        cg = Cardgroup.where(id: card.cardgroup_id).first
        cg_owner_id = cg.owner_id

        if (current_user.is_reseller? && cg_owner_id == current_user.id) || (current_user.is_accountant? && cg_owner_id == 0) || current_user.is_admin?

          if number.present?
            if is_number?(number)
              number_unique = Card.where(number: number).first
              if (number_unique && number_unique.id == card.id) || !number_unique
                if number.length == card.cardgroup.number_length.to_i
                  card.number = number
                else
                  doc.error("Bad number length, should be: #{card.cardgroup.number_length.to_i}")
                  return doc
                end
              else
                doc.error('Number is already taken')
                return doc
              end
            else
              doc.error('Calling Card number must be numerical')
              return doc
            end
          end

          if name.present?
            card.name = name
          end

          if !(params[:pin].nil?)
            unless pin.blank?
              if pin.length == card.cardgroup.pin_length
                pin_unique = Card.where(pin: pin).first
                if (pin_unique && pin_unique.id == card.id) || !pin_unique
                  if current_user.is_accountant?
                    group_id = User.where(username: current_user.username).first
                    permission = AccGroupRight.where(acc_group_id: group_id.acc_group_id, acc_right_id: 13).first
                    if permission.value == 2
                      card.pin = pin
                    end
                  end
                  if current_user.is_admin? || current_user.is_reseller?
                    card.pin = pin
                  end
                else
                  doc.error('PIN is already taken')
                  return doc
                end
              else
                doc.error("Bad PIN length, should be: #{card.cardgroup.pin_length}")
                return doc
              end
            else
              doc.error('Card PIN is blank')
              return doc
            end
          end

          if batch_number.present?
            card.batch_number = batch_number
          end

          if callerid.present?
            callerid_unique = Card.where(callerid: callerid).first
            if (callerid_unique && callerid_unique.id == card.id) || !callerid_unique
              card.callerid = callerid
            else
              doc.error('CallerID must be unique')
              return doc
            end
          end

          if min_balance.present?
            if valid_float?(min_balance)
              if min_balance.to_f > 0
                card.min_balance = sprintf('%.10f', min_balance)
              else
                doc.error('Bad minimal balance')
                return doc
              end
            else
              doc.error('Balance is not a numerical value')
              return doc
            end
          end

          if daily_charge_paid_till.present?
            if daily_charge_paid_till.is_i?
              card.daily_charge_paid_till = DateTime.strptime(daily_charge_paid_till.to_s,'%s').strftime("%Y-%m-%d %H:%M:%S")
            else
              doc.error('Wrong date entered')
              return doc
            end
          end

          if language.present?
            card.language = language
          end

          if user_id.present?
            if is_number?(user_id)
              if current_user.is_accountant? || current_user.is_admin?
                distributor_user = User.where(id: user_id, owner_id: 0, usertype: 'user').first
              end
              if current_user.is_reseller?
                distributor_user = User.where(id: user_id, owner_id: current_user.id, usertype: 'user').first
              end
              if distributor_user.present?
                card.user_id = user_id
              else
                card.user_id = -1
              end
            else
              doc.error('Wrong distributor')
              return doc
            end
          end
          card.save
          doc.success('Calling Card successfully updated')
        else
          doc.error('Calling Card was not found')
          return doc
        end
      else
        doc.error('Calling Card was not found')
        return doc
      end
    else
      doc.error('Wrong Calling Card ID')
      return doc
    end
    doc
  end

  def self.cc_group_create(doc, params, current_user, tax)
    tariff_id = params[:tariff_id]
    pin_length = params[:pin_length]
    date_from = params[:date_from]
    date_till = params[:date_till]
    lcr_id = params[:lcr_id]
    currency = params[:tell_balance_in_currency]
    location_id = params[:location_id]
    valid_after_first_use = params[:valid_after_first_use]
    price = params[:price_with_vat]

    if params[:name].present?
      cardgroup = Cardgroup.new do |cg|
        cg.owner_id = current_user.is_accountant? ? 0 : current_user.id
        pin_length.present? ? cg.pin_length = cg.temp_pl = pin_length : cg.pin_length = cg.temp_pl = 6

        # set params data to cardgroup if params are present
        %w[name description setup_fee ghost_min_perc daily_charge number_length ghost_balance_perc].each do |param|
          cg.send(param.to_s + '=', params[param.to_sym]) if params[param.to_sym].presence
        end
        # check check boxes in cardgroup if params are present and are 0 or 1
        %w[use_external_function allow_loss_calls tell_cents solo_pinless disable_voucher callerid_leave].each do |param|
          if params[param.to_sym].present?
            if params[param.to_sym] == '1' || params[param.to_sym] == '0'
              cg.send(param.to_s + '=', params[param.to_sym])
            else
              doc.error("#{param.gsub(/_/,' ').capitalize.gsub('id','ID')} is incorrect format")
              return doc
            end
          end
        end

        if date_from.present?
          # Unix time stamp converting into date and checking if valid
          datefrom = DateTime.strptime(date_from.to_s,'%s').strftime("%Y-%m-%d %H:%M:%S") if date_from.is_i?
          if datefrom.present? && datefrom < Time.now.change(year: 2100)
            cg.valid_from = datefrom
          else
           (return doc.error('Date from is incorrect format'))
          end
        end

        # if date till not present, but date from is greater than today
        if date_till.blank? && date_from.present? && (date_from.to_i > Date.today.to_time.to_i)
          return doc.error('Date from is greater than date till')
        end

        if date_till.present?
          # Check if date from is not greater than date till
          datetill = DateTime.strptime(date_till.to_s,'%s').strftime("%Y-%m-%d %H:%M:%S") if date_till.is_i?
          if datetill.present? && datetill < Time.now.change(year: 2100)
            if (date_till.to_i >= date_from.to_i && date_from.present?) || (date_till.to_i >= Date.today.to_time.to_i)
            # Unix time stamp converting into date and checking if valid
              cg.valid_till = datetill
            else
              return doc.error('Date from is greater than date till')
            end
          else
              return doc.error('Time till is incorrect format')
          end
        else
          # if date till not present, save today date, because db default is 2010-01-01 00:00:00
          cg.valid_till = Time.now.strftime("%Y-%m-%d %H:%M:%S")
        end
        if tariff_id.present?
          # if tariff id is present and correct
          tariff = Tariff.where(id: tariff_id).try(:first)
          if tariff.present? && !(current_user.is_reseller? && tariff.owner_id == 0)
            cg.tariff_id = tariff_id
          else
            return doc.error('Tariff was not found')
          end
        else
          cg.tariff_id = 1
        end

        if lcr_id.present?
          # if lcr id is present and correct
          lcr = Lcr.where(id: lcr_id).try(:first)
          if lcr.present? && !(current_user.is_reseller? && lcr.user_id == 0)
            cg.lcr_id = lcr_id
          else
            return doc.error('LCR was not found')
          end
        else
          cg.lcr_id = Lcr.try(:first).id
        end

        if location_id.present?
          # if location id is present and correct
          location = Location.where(id: location_id).try(:first)
          if location.present? && !(current_user.is_reseller? && location.user_id == 0)
            cg.location_id = location_id
          else
            return doc.error('Location was not found')
          end
        end

        if currency.present?
          Currency.where(name: currency).present? ? cg.tell_balance_in_currency = currency.upcase : (return doc.error('Currency was not found'))
        else
          cg.tell_balance_in_currency = current_user.currency.name.to_s
        end

        valid_after_first_use_present = valid_after_first_use.present?

        return doc.error('Valid after is incorrect format') if valid_after_first_use_present && valid_after_first_use.to_s.size > 4

        cg.valid_after_first_use = valid_after_first_use.to_i if valid_after_first_use_present
        cg.price = price.to_f if price.present?

      end
      cardgroup.tax = Tax.new(tax)

      # try to save, if something happens, returns one error
      cardgroup.save && cardgroup.tax.save ? doc.success('Card Group was successfully created') : doc.error(cardgroup.errors.messages.values[0].first)
    else
      doc.status('Card Group must have name')
      return doc
    end
  end

  def self.cc_group_update(doc, params, current_user, tax_values)
    cc_group_id = params[:cc_group_id]
    tax_id = params[:tax_id]
    tariff_id = params[:tariff_id]
    date_from = params[:date_from]
    date_till = params[:date_till]
    lcr_id = params[:lcr_id]
    currency = params[:tell_balance_in_currency]
    location_id = params[:location_id]
    price = params[:price_with_vat]
    valid_after_first_use = params[:valid_after_first_use]

    if is_number?(cc_group_id)
      cc_group = Cardgroup.where(id: cc_group_id).try(:first)

      if cc_group.present? && (current_user.is_admin? || (cc_group.owner_id == current_user.get_corrected_owner_id))

        # set params data to cardgroup if params are present
        %w[name description setup_fee ghost_min_perc daily_charge ghost_balance_perc].each do |param|
          cc_group.send(param.to_s + '=', params[param.to_sym]) if params[param.to_sym].presence
        end
        # check check boxes in cardgroup if params are present and are 0 or 1
        %w[use_external_function allow_loss_calls tell_cents solo_pinless disable_voucher callerid_leave].each do |param|
          if params[param.to_sym].present?
            if params[param.to_sym] == '1' || params[param.to_sym] == '0'
              cc_group.send(param.to_s + '=', params[param.to_sym])
            else
              doc.error("#{param.gsub(/_/,' ').capitalize.gsub('id','ID')} is incorrect format")
              return doc
            end
          end
        end

        if date_from.present?
          # Unix time stamp converting into date and checking if valid
          datefrom = DateTime.strptime(date_from.to_s,'%s').strftime("%Y-%m-%d %H:%M:%S") if date_from.is_i?
          if datefrom.present? && datefrom < Time.now.change(year: 2100)
            cc_group.valid_from = datefrom
          else
           (return doc.error('Date from is incorrect format'))
          end
        end

        # if date till not present, but date from is greater than today
        if date_till.blank? && date_from.present? && (date_from.to_i > Date.today.to_time.to_i)
          return doc.error('Date from is greater than date till')
        end

        if date_till.present?
          # Check if date from is not greater than date till
          datetill = DateTime.strptime(date_till.to_s,'%s').strftime("%Y-%m-%d %H:%M:%S") if date_till.is_i?
          if datetill.present? && datetill < Time.now.change(year: 2100)
            if (date_till.to_i >= date_from.to_i && date_from.present?) || (date_till.to_i >= Date.today.to_time.to_i)
            # Unix time stamp converting into date and checking if valid
              cc_group.valid_till = datetill
            else
              return doc.error('Date from is greater than date till')
            end
          else
              return doc.error('Time till is incorrect format')
          end
        end

        if tariff_id.present?
          # if tariff id is present and correct
          tariff = Tariff.where(id: tariff_id).try(:first)
          if tariff.present? && !(current_user.is_reseller? && tariff.owner_id == 0)
            cc_group.tariff_id = tariff_id
          else
            return doc.error('Tariff was not found')
          end
        end

        if lcr_id.present?
          # if lcr id is present and correct
          lcr = Lcr.where(id: lcr_id).try(:first)
          if lcr.present? && !(current_user.is_reseller? && lcr.user_id == 0)
            cc_group.lcr_id = lcr_id
          else
            return doc.error('LCR was not found')
          end
        end

        if location_id.present?
          # if location id is present and correct
          location = Location.where(id: location_id).try(:first)
          if location.present? && !(current_user.is_reseller? && location.user_id == 0)
            cc_group.location_id = location_id
          else
            return doc.error('Location was not found')
          end
        end

        if currency.present?
          Currency.where(name: currency).present? ? cc_group.tell_balance_in_currency = currency.upcase : (return doc.error('Currency was not found'))
        end

        valid_after_first_use_present = valid_after_first_use.present?

        return doc.error('Valid after is incorrect format') if valid_after_first_use_present && valid_after_first_use.to_s.size > 4

        cc_group.valid_after_first_use = valid_after_first_use.to_i if valid_after_first_use_present

        cc_group.price = price.to_f if price.present?

        if tax_id.present?
          tax = Tax.where(id: tax_id).first

          unless tax.present?
            return doc.error('TAX was not found')
          end

          cc_group.tax_id = tax_id
        else
          tax = cc_group.tax
        end
        tax.update_attributes(tax_to_update(tax_values, params))

      else
        doc.error('Card Group was not found')
        return doc
      end

      # try to save, if something happens, returns one error
      cc_group.save ? doc.success('Card Group was successfully updated') : doc.error(cc_group.errors.messages.values[0].first)
    else
      doc.error('Card Group was not found')
      return doc
    end
  end

  def self.calling_cards_get(doc, params, current_user)
    if current_user.is_accountant?
      user = User.where(username: current_user.username).first
      permission = AccGroupRight.where(acc_group_id: user.acc_group_id, acc_right_id: 13).first
      show_pin = permission.value != 0
    end

    options = {
      s_number: params[:number],
      s_name: params[:name],
      s_pin: params[:pin],
      s_batch_number: params[:batch_number],
      s_balance_min: params[:min_balance],
      s_balance_max: params[:max_balance],
      s_callerid: params[:callerid],
      s_language: params[:language],
      s_sold: params[:sold],
      s_user_id: params[:distributor],
      s_user: nil
    }

    [:s_number, :s_name, :s_pin, :s_batch_number, :s_balance_min, :s_balance_max, :s_callerid].each { |key| update_option(key, '', options) }
    user_id = options[:s_user_id]
    current_user_id = current_user.get_corrected_owner_id
    options[:s_language] = _('All') if options[:s_language].blank?
    options[:s_sold] = _('All') if options[:s_sold].blank?
    user_id = -1 if user_id.blank?

    if user_id.present?
      distributor_user = User.where(id: user_id, owner_id: 0, usertype: 'user').first
      options[:s_user] = distributor_user.present? ? distributor_user.username : 'not found'
    end

    cg = current_user.is_admin? ? Cardgroup.pluck(:id) : Cardgroup.where(owner_id: current_user_id).pluck(:id)
    card_exist = false

    cg.each do |id|
      cg_id = Cardgroup.where(id: id).first
      cards, cards_all, search, cards_first_used = Card.find_calling_cards_for_list(options, cg_id, true)

      if cards_all.to_i != 0
        card_exist = true

        doc.cards do
          cards.each do |card|
            doc.card do
              doc.card_id(card.id)
              doc.card_number(card.number)
              doc.card_name(card.name)
              doc.card_pin(card.pin) if (current_user.is_accountant? && show_pin) || current_user.is_reseller? || current_user.is_admin?
              doc.card_batch_number(card.batch_number)
              doc.card_callerid(card.callerid)
              doc.card_balance(card.raw_balance)
              doc.card_minimal_balance(card.min_balance)
              doc.card_first_use(card.first_use ? card.first_use.strftime("%Y-%m-%d %H:%M:%S") : '')
              doc.card_daily_charge_paid_till(card.daily_charge_paid_till ? card.daily_charge_paid_till.strftime("%Y-%m-%d %H:%M:%S") : '')
              doc.card_sold(card.sold)
              doc.card_language(card.language)
              card_user_id = card.user_id

              if card_user_id != -1
                distributor = User.where(id: card_user_id).first
                doc.card_distributor(distributor.nice_user(distributor))
              end
            end
          end
        end
      end
    end

    doc.status { doc.error('Cards were not found') } if card_exist == false
  end

  def self.cc_groups_get(doc, params, current_user)
    cc_group_id = params[:cc_group_id]
    current_user_id = current_user.get_corrected_owner_id

    if cc_group_id.present?
      if is_number?(cc_group_id)
        cg = current_user.is_admin? ? Cardgroup.where(id: cc_group_id).pluck(:id) : Cardgroup.where(id: cc_group_id, owner_id: current_user_id).pluck(:id)
      else
        doc.status { doc.error('Wrong Calling Cards Group ID') } && return
      end
    else
      cg = current_user.is_admin? ? Cardgroup.pluck(:id) : Cardgroup.where(owner_id: current_user_id).pluck(:id)
    end

    if cg.present?
      doc.cc_groups do
        cg.each do |id|
          doc.cc_group do
            group = Cardgroup.where(id: id).first
            group_id = group.id
            doc.group_id(group_id)
            doc.group_image(group.image)
            doc.group_name(group.name)
            doc.group_description(group.description)
            doc.group_number_pin_length("#{group.number_length}/#{group.pin_length}")
            tariff = Tariff.where(id: group.tariff_id).first
            doc.group_tarrif(tariff.name)
            if check_if_cg_owner(group, current_user)
              lcr = Lcr.where(id: group.lcr_id).first
              doc.group_lcr(lcr.name)
            end
            group_prices = group.raw_price
            doc.group_price((group_prices + group.get_tax.count_tax_amount(group_prices)).to_d)
            doc.group_price_without_tax(group_prices)
            doc.group_cards_count(Card.where(cardgroup_id: group_id).count)
          end
        end
      end
    else
      doc.status { doc.error('Calling Cards Groups were not found') }
    end
    doc
  end

  def self.calling_cards_create(doc, params, current_user, access_code)
    return doc.error 'You are not authorized to use this functionality' if access_code == 1
    return doc.error 'Access Denied' unless access_code == 0
    # Modatory
    card_group_id = params[:card_group_id]
    cards_from = params[:cards_from]
    cards_till = params[:cards_till]
    # Optional
    min_balance = params[:min_balance].to_s
    language = params.key?(:language) ? params[:language].to_s : 'en'
    distributor_id = params[:distributor_id]

    current_user_id = current_user.id

    cg_query_attr = { id: card_group_id }
    ds_query_attr = { id: distributor_id, usertype: 'user' }

    # Accountant can reach admin's Card Groups and Users
    if current_user.is_accountant?
      cg_query_attr[:owner_id] = ds_query_attr[:owner_id] = 0
    end

    # Reseller can only reach their Card Groups and Users
    if current_user.is_reseller?
      cg_query_attr[:owner_id] = ds_query_attr[:owner_id] = current_user_id
    end

    cardgroup = Cardgroup.where(cg_query_attr).first
    return doc.error 'Card Group was not found' unless cardgroup.present?

    # Validate number length
    return doc.error 'Cards from was not found' unless cards_from.present?
    return doc.error 'Cards till was not found' unless cards_till.present?

    cg_number_length = cardgroup.try(:number_length).to_i
    unless is_number?(cards_from) && cards_from.length == cg_number_length
      return doc.error 'Cards from is in incorrect format'
    end

    unless is_number?(cards_till) && cards_till.length == cg_number_length
      return doc.error 'Cards till is in incorrect format'
    end

    return doc.error 'Cards from must not be greater than Cards till' unless cards_till >= cards_from

    # Admin can reach everyone's Card Groups and Users but assign Users
    # to Cards only if they are ownded by a Card Group owner
    if current_user.is_admin?
      ds_query_attr[:owner_id] = cardgroup.try(:owner_id)
    end

    distributor = User.where(ds_query_attr).first
    distributor_id = -1 unless distributor.present?

    # Create bulk form
    bulk_form = Forms::CallingCards::BulkForm.new(
      start_number: cards_from,
      end_number: cards_till,
      batch_number: params[:batch_number].to_s,
      min_balance: is_float?(min_balance) ? min_balance : '',
      language: language,
      distributor_id: distributor_id,
      card_group: cardgroup
    )

    # Check if cards can be created
    return doc.error 'PIN is too short for this interval' unless cardgroup.pins_available? bulk_form.total

    # Create cards
    factory = CallingCard::BulkFactory.new(bulk_form.attributes)
    factory.fabricate!
    factory.cards_created != 0 ? doc.status("Cards created: #{factory.cards_created}/#{factory.cards_created + factory.invalid_cards.size}") : doc.error('Cards already exist')
  end

  def self.update_option(key, value, options)
    options_key = options[key]
    options_key = value.is_a?(Integer) ? options_key.to_i : options_key.to_s.strip
  end

  def self.conflines_update_validation(params, user_id)
    errors = []

    default_user_quickforwards_rule_id = params[:default_user_quickforwards_rule_id]
    default_device_location_id = params[:default_device_location_id]
    default_user_tariff_id = params[:default_user_tariff_id]

    if default_user_quickforwards_rule_id.present?
      params[:default_user_quickforwards_rule_id] =
          {default_user_quickforwards_rule_id: default_user_quickforwards_rule_id, user_id: user_id}
    end
    if default_device_location_id.present?
      params[:default_device_location_id] = {default_device_location_id: default_device_location_id, user_id: user_id}
    end
    if default_user_tariff_id.present?
      params[:default_user_tariff_id] = {default_user_tariff_id: default_user_tariff_id, user_id: user_id}
    end

    params.each do |key, value|
      method_name = "conflines_update_validation_#{key.to_s}".to_sym
      # if nil is returned, then method passed validation
      errors << send(method_name, value) if respond_to? method_name
    end

    params[:default_user_quickforwards_rule_id] = default_user_quickforwards_rule_id
    params[:default_device_location_id] = default_device_location_id
    params[:default_user_tariff_id] = default_user_tariff_id

    # eliminates nils from errors array
    return errors.compact
  end

  def self.conflines_update_update_values(params, user_id)
    %w[Allow_API API_Secret_Key Default_User_password_length Default_User_postpaid Default_User_allow_loss_calls
      Default_User_call_limit Default_User_recording_enabled Default_User_recording_forced_enabled
      Default_device_call_limit Default_User_time_zone Default_User_tariff_id Default_device_qualify
      Default_device_grace_time Default_User_quickforwards_rule_id].each do |key|
      param_name = key.downcase.to_sym
      Confline.set_value(key, params[param_name].to_s, user_id) if params[param_name].present?
    end

    %w[Default_User_credit Default_User_balance].each do |key|
      param_name = key.downcase.to_sym
      Confline.set_value(key, params[param_name].to_s.strip.sub(/[\,\.\;]/, '.'), user_id) if params[param_name].present?
    end

    if params[:default_user_currency].present?
      params_currency = Currency.where(name: params[:default_user_currency].to_s.strip).first.try(:id)
      Confline.set_value('Default_User_currency_id', params_currency, user_id)
    end

    if params[:default_device_canreinvite].present?
      Confline.set_value('Default_device_canreinvite', params[:default_device_canreinvite].to_s.strip, user_id)
    end

    if params[:default_device_nat].present?
      Confline.set_value('Default_device_nat', params[:default_device_nat].to_s.strip, user_id)
    end

    if params[:default_device_audio_codecs].present?
      params_codecs = params[:default_device_audio_codecs].to_s.strip.split(',')
      possible_codecs = Codec.where(codec_type: :audio).pluck(:name)

      params_codecs.delete_if { |codec_name| !possible_codecs.include?(codec_name) }
      if params_codecs.present?
        active_codecs = params_codecs.size.to_i

        params_codecs << possible_codecs.
            delete_if { |codec_name| params_codecs.include?(codec_name) }

        params_codecs.flatten!.each_with_index do |codec, index|
          Confline.set_value("Default_device_codec_#{codec}", index < active_codecs ? '1' : '0', user_id)
          Confline.set_value2("Default_device_codec_#{codec}", index, user_id)
        end
      end
    end

    if params[:default_device_video_codecs].present?
      params_codecs = params[:default_device_video_codecs].to_s.strip.split(',')
      possible_codecs = Codec.where(codec_type: :video).pluck(:name)

      params_codecs.delete_if { |codec_name| !possible_codecs.include?(codec_name) }
      if params_codecs.present?
        active_codecs = params_codecs.size.to_i

        params_codecs << possible_codecs.
            delete_if { |codec_name| params_codecs.include?(codec_name) }

        params_codecs.flatten!.each_with_index do |codec, index|
          Confline.set_value("Default_device_codec_#{codec}", index < active_codecs ? '1' : '0', user_id)
          Confline.set_value2("Default_device_codec_#{codec}", index, user_id)
        end
      end
    end

    if params[:default_device_location_id].present?
      Confline.set_value('Default_device_location_id', params[:default_device_location_id].to_i, user_id)
    end
  end

  def self.did_details_update(doc, params, current_user, access_code, did_user_id)
    case access_code

      when 0
        if did_user_id.present?
          user = User.where(id: did_user_id).first
        end
        did = Did.where(id: params[:did_id]).first

        if did.blank? || current_user.usertype == 'reseller' && did.reseller_id != current_user.id
          doc.error('DID was not found')
        else
          error = 0
            if did_user_id.present?
                  if did_user_id.to_i != -1
                    if did_details_user_validation(user, current_user, did)
                      error = 1
                        doc.error('User was not found')
                    else
                      if (did.user_id > 0 || (did.reseller_id > 0 && !current_user.usertype == 'reseller') || did.dialplan_id > 0)
                        unless ((user.is_reseller? && did.reseller_id == did_user_id.to_i) || (did.user_id == did_user_id.to_i))
                          error = 1
                          doc.error('DID is already assigned')
                        end
                      end
                    end
                  else
                    if did.user_id >= 0
                      current_user.is_reseller? ? did.make_free_for_reseller : did.make_free
                    else
                      error = 1
                        doc.error('DID was not found')
                    end
                  end
            end

            call_limit = params[:call_limit].present?

            if call_limit
              unless params[:call_limit] =~ /^\d+$/
                error = 1
                doc.error('Call limit is incorrect format')
              end
            end

            if error == 0
              if did_user_id.present? && did_user_id.to_i != -1
                if user.is_reseller?
                  did.reseller_id = did_user_id.to_i
                else
                  did.user_id = did_user_id.to_i
                  did.status = 'reserved'
                end
              end
              did.update_attribute(:call_limit, params[:call_limit]) if call_limit
              did.save
              Action.new(date: Time.now, user_id: current_user.id, action: "did_edited" , data: did.id).save
              doc.success('DID details successfully updated')
            end
        end
      when 1
        doc.error('You are not authorized to use this functionality')
      else
        doc.error('Access Denied')
    end
  end

  def self.phonebook_record_delete(doc, params, user)
    phonebook = Phonebook.where(id: params[:id]).first
    if phonebook
      if user.id == phonebook.user_id || user.is_admin?
        if phonebook.destroy
          doc.success('Phonebook record successfully deleted')
        end
      else
        doc.error('Phonebook record was not found')
      end
    else
      doc.error('Phonebook record was not found')
    end
  end

  def self.credit_notes_get(doc, params, user, values)
    if user && (user.is_admin? || user.is_reseller? || (user.is_accountant? && user.accountant_allow_read('invoices_manage')))
      if user.is_reseller?
        condition = ["users.owner_id = #{user.id}"]
      elsif user.is_admin? || user.is_accountant?
        condition = ['users.owner_id = 0']
      end
      if params[:credit_note_id]
        condition << "credit_notes.id = #{params[:credit_note_id].to_i}"
      elsif values[:user_id]
        condition << "credit_notes.user_id = #{values[:user_id].to_i}"
      end
      notes = CreditNote.includes(:user).where(condition.join(' AND ')).references(:user)
      if notes && notes.size.to_i > 0
        can_see_finances = (user.is_admin? || user.is_reseller? || (user.is_accountant? && user.accountant_allow_read('see_financial_data')))
        doc.credit_notes {
          for note in notes
            doc.credit_note {
              doc.user_id(note.user_id)
              doc.issue_date(note.issue_date)
              doc.number(note.number)
              doc.comment(note.comment)
              if can_see_finances
                doc.price(note.price)
                doc.price_with_vat(note.price_with_vat)
                doc.pay_date(note.pay_date)
              end
            }
          end
        }
      else
        doc.error("Credit note was not found")
      end
    else
      doc.error("Bad login")
    end
    doc
  end

  def self.did_subscription_stop(doc, params, user, access_code)
    doc.page do
      doc.status do
        case access_code
          when 0
            did_id = params[:dids_id]
            did_attributes = user.is_reseller? ? {id: did_id, reseller_id: user.id} : {id: did_id}
            did = Did.where(did_attributes).first
            if did
              did_status = did.status
              if (did_status == 'active' && did.dialplan_id == 0) || (did_status == 'closed')
                if did.close
                  doc.status('DID was successfully closed')
                else
                  doc.status('DID was not saved')
                end
              else
                doc.error('DID is not assigned to Device')
              end
            else
              doc.error('DID was not found')
            end
          when 1
            doc.error('You are not authorized to use this functionality')
          else
            doc.error('Access Denied')
        end
      end
    end
    doc
  end

  def self.subscriptions_get(doc, params, user, access_code)
    doc.page do
      doc.status do
        case access_code
        when 0
          select_clause = "subscriptions.*, services.name as 'services_name', services.price as 'price', " +
            "services.servicetype as 'services_servicetype', #{SqlExport.nice_user_sql}"
          subscriptions = Subscription.select(select_clause)
                                      .joins('LEFT JOIN users ON (users.id = subscriptions.user_id)')
                                      .joins('LEFT JOIN devices ON (devices.id = subscriptions.device_id)')
                                      .joins('LEFT JOIN services ON (services.id = subscriptions.service_id)')
                                      .where(user.where_clause_for_subscriptions_get(params)).to_a

          if subscriptions.present?
            doc.subscriptions do
              subscriptions.each do |subscription|
                doc.subscription do
                  doc.id(subscription.id)
                  doc.user(subscription.nice_user)
                  doc.device(subscription.device_id.present? ? nice_device(subscription.device) : '')
                  doc.service(subscription.services_name)
                  doc.from(subscription.activation_start)
                  doc.till(subscription.activation_end)
                  doc.time_left(['flat_rate', 'dynamic_flat_rate'].include?(subscription.services_servicetype) ? subscription.time_left : '')
                  doc.memo(subscription.memo)
                  doc.type(subscription.services_servicetype)
                  doc.price(subscription.price)
                  doc.user_id(subscription.user_id)
                end
              end
            end
          else
            doc.error('No Subscriptions found')
          end
        when 1
          doc.error('You are not authorized to manage Subscriptions')
        else
          doc.error('Access Denied')
        end
      end
    end
    doc
  end

  def self.services_get(doc, user)
    doc.page do
      if !user || user.is_user?
        doc.status { doc.error('Access Denied') }
      elsif user.is_accountant? && !user.accountant_allow_read('services_manage')
        doc.status { doc.error('You are not authorized to manage Services') }
      else
        services = Service.where(user.is_admin? ? {} : {owner_id: user.get_corrected_owner_id}).to_a
        if services.present?
          doc.services do
            services.each do |service|
              doc.service do
                doc.id(service.id)
                doc.name(service.name)
                doc.type(service.servicetype)
                doc.period(service.periodtype)
                if !user.is_accountant? || user.accountant_allow_read('see_financial_data')
                  doc.price(service.price)
                  doc.self_cost(service.selfcost_price)
                  doc.currency(Currency.first.name)
                end
                doc.quantity(service.quantity)
              end
            end
          end
        else
          doc.status { doc.error('No Services found') }
        end
      end
    end
    doc
  end

  def self.quickstats_get(doc, current_user, last_day, current_day)
    quick_stats = current_user.quick_stats('', last_day, current_day, current_user.id)
    doc.quickstats do
      doc.this_month do
        doc.calls(quick_stats[0])
        doc.duration(quick_stats[1].to_i)
        unless current_user.usertype == 'user'
          doc.revenue(quick_stats[3])
          doc.self_cost(quick_stats[2])
          doc.profit(quick_stats[4])
        end
      end
      doc.today do
        doc.calls(quick_stats[6])
        doc.duration(quick_stats[7].to_i)
        unless current_user.usertype == 'user'
          doc.revenue(quick_stats[9])
          doc.self_cost(quick_stats[8])
          doc.profit(quick_stats[10])
          end
      end
      if current_user.usertype == 'admin'
        doc.active_calls do
          doc.total(Activecall.count_for_user(current_user))
          doc.answered_calls(Activecall.count_for_user(current_user, true))
        end
      end
    end
  end

  def self.recordings_get(doc, params, current_user)
    date_from = params[:date_from].to_i
    date_till = params[:date_till].to_i
    destination = params[:destination]
    source = params[:source]
    user = params[:user].to_i
    device = params[:device].to_i

    date_from = Date.today.strftime("%Y-%m-%d %H:%M:%S").to_time.to_i if date_from == 0
    date_till = Date.today.strftime("%Y-%m-%d 23:59:59").to_time.to_i if date_till == 0
    unless valid_date?(date_from)
      return doc.error('Date from is incorrect format')
    end
    unless valid_date?(date_till)
      return doc.error('Date till is incorrect format')
    end
    if from_is_greater_than_till?(date_from,date_till)
      return doc.error('Date from is greater than date till')
    end

    cond = "datetime BETWEEN #{ActiveRecord::Base::sanitize(Time.at(date_from))} AND #{ActiveRecord::Base::sanitize(Time.at(date_till))}"
    cond << " AND calls.dst = #{ActiveRecord::Base::sanitize(destination)}" if destination.present?
    cond << " AND calls.src = #{ActiveRecord::Base::sanitize(source)}" if source.present?
    cond << " AND (recordings.src_device_id = #{device} OR recordings.dst_device_id = #{device})" if device > 0

    if current_user.usertype == 'user'
      cond << " AND (recordings.user_id = #{current_user.id} OR recordings.dst_user_id = #{current_user.id})"
    else
      cond << " AND (src_user.owner_id = #{current_user.get_corrected_owner_id} OR dst_user.owner_id = #{current_user.get_corrected_owner_id})"
    end

    if user > 0
      cond << " AND (recordings.user_id = #{user} OR recordings.dst_user_id = #{user})"
    end

    sql = "SELECT * FROM (SELECT recordings.*, calls.real_billsec, calls.disposition, calls.dst AS call_dst,
              calls.id AS real_call_id, calls.src AS call_src
           FROM recordings
           LEFT JOIN devices as src ON (src.id = recordings.src_device_id)
           LEFT JOIN devices as dst ON (dst.id = recordings.dst_device_id)
           LEFT JOIN users src_user ON (src_user.id = src.user_id)
           LEFT JOIN users dst_user ON (dst_user.id = dst.user_id)
           LEFT JOIN calls ON (calls.uniqueid = recordings.uniqueid AND calls.calldate = recordings.datetime)
           WHERE #{cond}
           ORDER BY calls.uniqueid, real_call_id DESC) AS A
           GROUP BY A.id"

    recordings = Recording.find_by_sql(sql)

    if recordings.present?
      doc.recordings do
        recordings.each do |recording|
          doc.recording do
            doc.id(recording.id)
            doc.user_id(recording.user_id)
            doc.dst_user_id(recording.dst_user_id)
            doc.src_device_id(recording.src_device_id)
            doc.dst_device_id(recording.dst_device_id)
            doc.date(recording.datetime)
            doc.comment(recording.comment)
            doc.duration(nice_time(recording.real_billsec, true))
            doc.source(recording.call_src)
            doc.destination(recording.call_dst)
            doc.size(recording.size)
          end
        end
      end
    else
      return doc.error('No Recordings found')
    end
  end

  private

  def self.check_if_cg_owner(cg, current_user)
    cg_owner = cg.lcr.user_id == current_user.id
    (cg.lcr and ((current_user.is_reseller? and cg_owner) or (current_user.is_admin? and cg_owner)))
  end

  def self.valid_date?(timestamp)
    date_time = DateTime.strptime(timestamp.to_s,'%s').strftime("%Y-%m-%d %H:%M:%S") if Time.at(timestamp.to_i)
    if date_time.present? && Date.parse(date_time) && date_time < Time.now.change(year: 2100)
      true
    else
      false
    end
  end

  # date from and date till must be timestamps
  def self.from_is_greater_than_till?(from,till)
    true if (till.to_i <= from.to_i) rescue false
  end

  def self.valid_timestamp?(timestamp)
    true if Time.at(timestamp.to_i) rescue false
  end

  def self.valid_float?(str)
    true if Float(str) rescue false
  end

  def self.is_number?(val=nil)
    (!!(val.match /^[0-9]+$/) rescue false)
  end

  def self.is_float?(val = nil)
    Float(val) != nil rescue false
  end

  def self.device_each_clis(devices, clis)
    devices.each do |device|
      clis.concat(device.callerids)
    end
  end

  def self.is_owner?(owner_id)
    owner_id != 0
  end

  def self.owner_accountant?(owner)
    owner.usertype == 'accountant'
  end

  def self.conflines_update_validation_allow_api(allow_api)
    'allow_api must be 0 or 1' unless /^[0-1]$/ === allow_api.to_s
  end

  def self.conflines_update_validation_api_secret_key(api_secret_key)
    'api_secret_key length must be higher than 5' unless api_secret_key.to_s.length >= 6
  end

  def self.conflines_update_validation_default_user_password_length(default_user_password_length)
    unless ((/^[0-9]+$/ === default_user_password_length.to_s) && (default_user_password_length.to_i.between?(6, 30)))
      'default_user_password_length must be between 6 and 30'
    end
  end

  def self.conflines_update_validation_default_user_credit(default_user_credit)
    unless /^([\d]+([\,\.\;][\d]+){0,1})|(-1)$/ === default_user_credit.to_s
      'default_user_credit must be positive number or -1 for infinity'
    end
  end

  def self.conflines_update_validation_default_user_balance(default_user_balance)
    unless /^-?[\d]+([\,\.\;][\d]+){0,1}$/ === default_user_balance.to_s
      'default_user_balance must be number'
    end
  end

  def self.conflines_update_validation_default_user_postpaid(default_user_postpaid)
    'default_user_postpaid must be 0 or 1' unless /^[0-1]$/ === default_user_postpaid.to_s
  end

  def self.conflines_update_validation_default_user_allow_loss_calls(default_user_allow_loss_calls)
    'default_user_allow_loss_calls must be 0 or 1' unless /^[0-1]$/ === default_user_allow_loss_calls.to_s
  end

  def self.conflines_update_validation_default_user_call_limit(default_user_call_limit)
    'default_user_credit must be positive integer' unless /^[0-9]+$/ === default_user_call_limit.to_s
  end

  def self.conflines_update_validation_default_user_recording_enabled(default_user_recording_enabled)
    'default_user_recording_enabled must be 0 or 1' unless /^[0-1]$/ === default_user_recording_enabled.to_s
  end

  def self.conflines_update_validation_default_user_recording_forced_enabled(default_user_recording_forced_enabled)
    unless /^[0-1]$/ === default_user_recording_forced_enabled.to_s
      'default_user_recording_forced_enabled  must be 0 or 1'
    end
  end

  def self.conflines_update_validation_default_device_call_limit(default_device_call_limit)
    'default_device_call_limit must be positive integer' unless /^[0-9]+$/ === default_device_call_limit.to_s
  end

  def self.conflines_update_validation_default_user_time_zone(default_user_time_zone)
    unless ActiveSupport::TimeZone.all.each_with_index.collect { |tz| tz.name.to_s }.
        include?(default_user_time_zone.to_s.strip)

      'default_user_time_zone name was not correct'
    end
  end

  def self.conflines_update_validation_default_user_currency(default_user_currency)
    params_currency = Currency.where(name: default_user_currency.to_s.strip).first.try(:id)

    'default_user_currency name was not correct' unless params_currency
  end

  def self.conflines_update_validation_default_user_quickforwards_rule_id(options)
    allow_resellers_to_use_admin_quick_forward_rules = Confline.get_value('Allow_Resellers_to_use_Admin_Quick_Forward_Rules').to_i == 1
    user_id = options[:user_id]
    is_reseller = User.where(id: user_id).first.try(:usertype) == 'reseller'

    qfr_owner = is_reseller && allow_resellers_to_use_admin_quick_forward_rules ?
        "(user_id = 0 OR user_id = #{user_id})" :
        "user_id = #{user_id}"

    params_quickforward = options[:default_user_quickforwards_rule_id].to_s.strip == '0' ? 0 :
        QuickforwardsRule.where("id = '#{options[:default_user_quickforwards_rule_id]}' AND #{qfr_owner}").first.try(:id)


    return params_quickforward ? nil : 'default_user_quickforwards_rule_id was not found'
  end

  def self.conflines_update_validation_default_user_tariff_id(options)
    allow_reseller_to_use_admin_tariff = Confline.get_value('Allow_Resellers_to_use_Admin_Tariffs').to_i == 1
    user_id = options[:user_id]
    is_reseller = User.where(id: user_id).first.try(:usertype) == 'reseller'

    tariff_owner = is_reseller && allow_reseller_to_use_admin_tariff ? "(owner_id = 0 OR owner_id = #{user_id})" :
        "owner_id = #{user_id}"

    tariff_purpose = " AND (purpose = 'user' OR purpose = 'user_wholesale') "

    tariff = Tariff.where("id = '#{options[:default_user_tariff_id]}' AND #{tariff_owner} #{tariff_purpose} ").first.try(:id)

    return tariff ? nil : 'default_user_tariff_id was not found'
  end

  def self.conflines_update_validation_default_device_canreinvite(default_device_canreinvite)
    unless ['yes', 'no', 'nonat', 'update', 'update,nonat'].include?(default_device_canreinvite.to_s.strip)
      "default_device_canreinvite can only be one of the following: 'yes', 'no', 'nonat', 'update', 'update,nonat'"
    end
  end

  def self.conflines_update_validation_default_device_nat(default_device_nat)
    unless ['yes', 'no', 'force_rport', 'comedia'].include?(default_device_nat.to_s.strip)
      "default_device_nat can only be one of the following: 'yes', 'no', 'force_rport', 'comedia'"
    end
  end

  def self.conflines_update_validation_default_device_qualify(default_device_qualify)
    unless ((default_device_qualify.to_s == 'no') || (default_device_qualify.to_i >= 1000))
      "default_device_qualify can only be 'no' or >= 1000 integer"
    end
  end

  def self.conflines_update_validation_default_device_grace_time(default_device_grace_time)
    'default_device_grace_time must be positive integer' unless /^[0-9]+$/ === default_device_grace_time.to_s
  end

  def self.conflines_update_validation_default_device_location_id(options)
    allow_resellers_to_use_admin_localization_rules = Confline.get_value('Allow_Resellers_to_use_Admin_Localization_Rules').to_i == 1
    user_id = options[:user_id]
    is_reseller = User.where(id: user_id).first.try(:usertype) == 'reseller'

    location_owner = is_reseller && allow_resellers_to_use_admin_localization_rules ?
        "(user_id = 0 OR user_id = #{user_id})" :
        "user_id = #{user_id}"

    location = Location.where("id = '#{options[:default_device_location_id]}' AND #{location_owner}").first.try(:id)

    return location ? nil : 'default_device_location_id was not found'
  end

  # API Authorisation was ment to be Global, however these are exceptions. Should be put here to keep things more global
  def self.methods_using_uniquehash
    %w[user_simple_balance_get check_rs_user_count user_register]
  end

  def self.uses_username
    %w[user_balance_get]
  end


  def self.did_details_user_validation(user, current_user, did)
    if user.blank? ||
      (current_user.try(:is_reseller?) && user.try(:owner_id) != current_user.try(:id)) ||
      ( (current_user.is_admin? || current_user.is_accountant?) &&
      ( (did.dialplan_id > 0 && (user.try(:is_reseller?) || user.try(:is_partner?))) ||
      (did.dialplan_id <= 0 && (user.try(:is_partners_reseller?) || user.try(:is_partner?))) ) )
      true
    end
  end

  def self.tax_to_update(tax, params)
    taxes = {tax1_enabled: 1}

    %i(tax2_enabled tax3_enabled tax4_enabled compound_tax).each do |value|
      taxes[value] = tax[value].to_i if params[value].present?
    end

    %i(tax1_name tax2_name tax3_name tax4_name total_tax_name).each do |value|
      taxes[value] = tax[value].to_s if params[value].present?
    end

    %i(tax1_value tax2_value tax3_value tax4_value).each do |value|
      taxes[value] = tax[value].to_d if params[value].present?
    end
    taxes
  end
end