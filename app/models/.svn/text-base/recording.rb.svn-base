# -*- encoding : utf-8 -*-
# Recorded users' calls, for Monitoring purposes
class Recording < ActiveRecord::Base
  attr_protected

  belongs_to :call, primary_key: 'uniqueid', foreign_key: 'uniqueid'
  belongs_to :user
  belongs_to :dst_user, class_name: 'User', foreign_key: 'dst_user_id'

  def destroy_all_data
    if local == 1
      # Delete from local server
      system('chmod 777 -R /home/mor/public/recordings > /dev/null 2>&1')
      file_path = "/home/mor/public/recordings/#{uniqueid}.mp3"
      rm_cmd = "rm -f #{file_path} > /dev/null 2>&1"
      check_cmd = "ls #{file_path} > /dev/null 2>&1"
    else
      # Delete from remote server
      server = Confline.recordings_server
      server_login = server[:login]
      server_ip = server[:ip]
      server_port = server[:port]
      file_path = "/usr/local/mor/recordings/#{uniqueid}.mp3"
      rm_cmd = "/usr/bin/ssh #{server_login}@#{server_ip} -p #{server_port} -f rm -fr #{file_path} "
      check_cmd = "/usr/bin/ssh #{server_login}@#{server_ip} -p #{server_port} -f ls #{file_path} "
    end

    MorLog.my_debug("Deleting Recording audio file - #{uniqueid}.mp3\n#{rm_cmd}")
    system(rm_cmd)

    MorLog.my_debug("Checking existence of Recording audio file - #{uniqueid}.mp3\n#{check_cmd}")
    if system(check_cmd)
      return false
    else
      destroy
    end
  end

  # Recording mp3 file without path
  def mp3
    "#{uniqueid}.mp3"
  end

  def destroy_rec(session)
    session_user_id = session[:user_id].to_i
    message = ''

    return false unless [user_id, dst_user_id].include?(session_user_id)

    # Allow to delete when src/dst matches otherwise -> do invisible
    if user_id == dst_user_id || (user_id == session_user_id && visible_to_dst_user == 0) || (dst_user_id == session_user_id && visible_to_user == 0)
      if destroy_all_data
        message = _('Recording_was_destroyed')
      else
        message = _('Recording_was_not_destroyed')
      end
    else
      # Hide recording for src user because dst user still can see it
      if user_id == session_user_id && visible_to_dst_user == 1
        update_attribute(:visible_to_user, 0)
        message = _('Recording_was_destroyed')
      end

      # Hide recording for dst user because src user still can see it
      if dst_user_id == session_user_id && visible_to_user == 1
        update_attribute(:visible_to_dst_user, 0)
        message = _('Recording_was_destroyed')
      end
    end

    message
  end

  def check_if_file_exist
    if local == 1
      File.file?("/home/mor/public/recordings/#{uniqueid}.mp3")
    else
      # Selected downloads will be working with local recordings

      # server, server_port, server_user = Confline.get_value('Recordings_addon_IP').to_s,
      #     Confline.get_value('Recordings_addon_Port').to_s, Confline.get_value('Recordings_addon_Login').to_s
      #
      # file_path = "/usr/local/mor/recordings/#{uniqueid}.mp3"
      #
      # check_file = "/usr/bin/ssh #{server_user.to_s}@#{server.to_s} -p #{server_port.to_s} ls #{file_path} "
      # system(check_file)
      false
    end
  end

  def user
    User.where(id: user_id).first || User.where(id: dst_user_id).first
  end

  def play
    update_attribute(:played, 1)
  end

  def file_present?
    deleted.to_i == 0 && size.to_i > 0
  end
end
