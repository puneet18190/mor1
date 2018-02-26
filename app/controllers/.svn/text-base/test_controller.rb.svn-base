# -*- encoding : utf-8 -*-
# Helper to Selenium tests
class TestController < ApplicationController
  before_filter :authorize_admin, :except => [:fake_form, :vat_checking_get_status, :time_zones]
#  require 'google4r/checkout'
#  include Google4R::Checkout

  def create_user
    user = User.new_user_for_test
    user.save(validate: false)
    render text: 'OK'
  end

  # Secret Action Used To clear cache when testing
  def clear_rails_cache
    Rails.cache.clear
    render :text => "Cache Cleared"
  end

  def recaptcha_config_values
    Confline.load_recaptcha_settings
    render text: "<table><tr><td>Public Key</td><td id='public'>#{Recaptcha.configuration.public_key}</td></tr><tr><td>Private Key</td><td id='private'>#{Recaptcha.configuration.private_key}</td></tr></table>".html_safe
  end

  def time
    @time = Time.now()
  end

  def time_zones
    render text: "<table><tr><th>NAME</th><th>VALUE</th></tr>#{ActiveSupport::TimeZone.all.each_with_index.collect { |tz, index| "<tr #{"style='background-color:#EEE'" if index % 2 == 1}><td id='#{tz.name.downcase}'>#{tz.to_s}</td><td id='tz_value_#{index}'>#{tz.name}</td></tr>" }.join()}</table>".html_safe
  end

  def vat_checking_get_status
    condition = Timeout::timeout(5) { !!Net::HTTP.new('ec.europa.eu',80).request_get('/taxation_customs/vies/vatRequest.html').code } rescue false
    render :text => (condition ? 1 : 0)
  end

  def check_db_update
    value = Confline.get_value('DB_Update_From_Script', 0)
    render :text => (value.to_i == 1 ? value : '')
  end

  def launch_script
  end

  def script_output
    command = params[:command].to_s
    script_path = command.split(' ').first
    if !command.blank?
      if File.exists?(script_path)
        result = 'Launching script.</br>Output:</br>'
        result << `/usr/src/mor/test/launcher.sh #{command}`
        result.gsub! /\n/, '<br>'
      else
        result = 'No such file'
      end
      render text: result
    else
      redirect_to action: :launch_script
    end
  end

  def raise_exception
    params[:this_is_fake_exception] = nil
    params[:do_not_log_test_exception] = 1
    case params[:id]
      when "Errno::ENETUNREACH"
        raise Errno::ENETUNREACH
      when "Transactions"
        raise ActiveRecord::Transactions::TransactionError, 'Transaction aborted'
      when "RuntimeError"
        raise RuntimeError, 'No route to host'
      when "RuntimeErrorExit"
        raise RuntimeError, 'exit'
      when "Errno::EHOSTUNREACH"
        raise Errno::EHOSTUNREACH
      when "Errno::ETIMEDOUT"
        raise Errno::ETIMEDOUT
      when "SystemExit"
        raise SystemExit
      when "SocketError"
        raise SocketError
      when "NoMemoryError"
        params[:this_is_fake_exception] = "YES"
        raise NoMemoryError
      when "DNS_TEST"
        raise 'getaddrinfo: Temporary failure in name resolution'
      when "ReCaptcha"
        raise NameError, 'uninitialized constant Ambethia::ReCaptcha::Controller::RecaptchaError'
      when "SyntaxError"
        raise SyntaxError
      when "OpenSSL::SSL::SSLError"
        Confline.set_value("Last_Crash_Exception_Class", "")
        raise OpenSSL::SSL::SSLError
      when "Cairo"
        raise LoadError, 'Could not find the ruby cairo bindings in the standard locations or via rubygems. Check to ensure they\'re installed correctly'
      when 'Google_account_not_active'
        params[:this_is_fake_exception] = "YES"
        raise GoogleCheckoutError, {:message => 'Seller Account 666666666666666 is not active.', :response_code => '', :serial_number => '6666666-6666-6666-6666-666666666666'}
      when "Google_500"
        params[:this_is_fake_exception] = ""
        raise RuntimeError, 'Unexpected response code (Net::HTTPInternalServerError): 500 - Internal Server Error'
      when "Gems"
        raise LoadError, 'in the standard locations or via rubygems. Check to en'
      when "MYSQL"
        params[:this_is_fake_exception] = "YES"
        Confline.set_value("Last_Crash_Exception_Class", "")
        sql = "alter table users drop first_name ;"
        test = ActiveRecord::Base.connection.execute(sql)
        us = User.find(0)
        us.first_name
      when "test_exceptions"
        Confline.set_value("Last_Crash_Exception_Class", "")
        params[:this_is_fake_exception] = ""
        raise SyntaxError
      when "pdf_limit"
        PdfGen::Count.check_page_number(4, 1)
      else
        flash[:notice] = _("ActionView::MissingTemplate")
        (redirect_to :root) && (return false)
    end
  end

  def nice_exception_raiser
    params[:do_not_log_test_exception] = 1
    params[:this_is_fake_exception] = nil
    if params[:exc_class]
      raise eval(params[:exc_class].to_s), params[:exc_message].to_s
    end
  end

  def last_exception
    render :text => Confline.get_value("Last_Crash_Exception_Class", 0).to_s
  end

  def remove_duplicates
    i = 0
    sql = "SELECT user_id, data, target_id, count(*) as 'size' FROM actions WHERE action = 'subscription_paid' GROUP BY user_id, data, target_id HAVING size > 1"
    duplicates = ActiveRecord::Base.connection.execute(sql)
    duplicates.each { |dub|
      (dub[3].to_i - 1).times {
        action = Action.includes([:user]).where(["action = 'subscription_paid' AND user_id = ? AND data = ? AND target_id = ?", dub[0].to_i, dub[1], dub[2].to_i]).first
        user = action.user
        user.balance += action.data2.to_d
        MorLog.my_debug("  Action reverted User: #{user.id}, action.data2: #{action.data2}")
        user.save
        action.destroy
        i += 1
      }
    }
    render :text => "DONE! Removed: #{i}"
  end

  def load_delta_sql
    path = (params[:path].to_s.empty? ? params[:id] : params[:path])
    my_debug(path)
    # MorLog.my_debug(params[:path].join("/"))
    my_debug(File.exist?("#{Rails.root}/config/routes.rb"))
    filename = "#{Rails.root}/selenium/#{path.to_s.gsub(/[^A-Za-z0-9_\/]/, "")}.sql"
    my_debug(filename)
    if File.exist?(filename)
      command = "mysql -u mor -pmor --default-character-set=utf8 mor < #{filename}"
      my_debug(command)
      rez = `#{command}`
      my_debug("DELTA SQL FILE WAS LOADED: #{filename}")
    else
      my_debug("Delta SQL file was not found: #{filename}")
      rez = "Not Found"
    end
    sys_admin = User.where({:id=>0}).first
    renew_session(sys_admin)  if sys_admin
    render :text => rez
  end


  # loads bundle file which has patch to sql files which are loaded one-by-one
  # used for tests to prepare data before testing
  # called by Selenium script through MOR GUI
  def load_bundle_sql
    path = (params[:path].to_s.empty? ? params[:id] : params[:path])
    MorLog.my_debug(path)
    # MorLog.my_debug(params[:path].join("/"))
    MorLog.my_debug(File.exist?("#{Rails.root}/config/routes.rb"))
    filename = "#{Rails.root}/selenium/bundles/#{path.to_s.gsub(/[^A-Za-z0-9_\/]/, "")}.bundle"
    MorLog.my_debug(filename)
    if File.exist?(filename)
      command = "/home/mor/selenium/scripts/load_bundle.sh #{filename}"
      MorLog.my_debug(command)
      rez = `#{command}`
      MorLog.my_debug("BUNDLE WAS LOADED: #{filename}")
    else
      MorLog.my_debug("Bundle file was not found: #{filename}")
      rez = "Not Found"
    end
    render :text => rez
  end

  def restart
    `mor -l`
  end

  def fake_form
    @all_fields = params.reject { |key, value| ['controller', 'action', 'path_to_action'].include?(key) }
    @data = params[:path_to_action]
  end

  def test_api
    api_name = params[:api_name] ||= ''
    allow, values = MorApi.hash_checking(params, request, api_name)
    render :text => values[:system_hash]
  end

  def make_select
    @tables = ActiveRecord::Base.connection.tables
    @table = @tables.include?(params[:table]) ? params[:table] : nil

    if params[:id] && @table
      if [:sessions, :queues].include?(@table.to_sym)
        @select = ActiveRecord::Base.connection.select_all("SELECT * FROM #{params[:table]} WHERE id = #{params[:id].to_i}")
        # make hash from result because rails already has a class named 'Queue' and ActiveRecord as 'Queue.where...' will call it it first
        @object = @select = Hash[@select.columns.zip @select.rows[0]] if @table.to_s == 'queues' && @select.present?
      else
        object_name = @table.singularize.titleize.gsub(' ', '').constantize
        @select = object_name.where(id: params[:id]).first
        @object = object_name.column_names
      end
    end
  end

  def delete_invoice_xlsx_files_in_tmp_folder
    FileUtils.rm_rf(Dir.glob('/tmp/mor/invoices/*'))
  end

  def paypal_notification_email
    response = ''
    user = User.where(id: params[:user_id]).first
    response = _('User_Not_Found') if user.blank?
    payment = Payment.where(id: params[:payment_id], user_id: params[:user_id]).first
    response = _('Payment_was_not_found') if payment.blank?

    fake_response = Paypal::Notification.new('')

    if response.blank?
      Payment.paypal_ipn(fake_response, payment, user, true)
      response = 'Payment management completed. Check weather you got email'
    end

    render :text => response
  end
end
