# -*- encoding : utf-8 -*-
module RecordingsHelper

  def recordings_present(recording, call_present, show_recordings_with_zero_billsec)
    ((recording.deleted.to_i == 0) && (recording.size.to_i > 0) &&
      (call_present && ((recording.real_billsec.to_f > 0.0) || show_recordings_with_zero_billsec)))
  end

  def check_recording_file(recording)
    if recording.check_if_file_exist
      ''
    else
      message = recording.local == 0 ? _('This_Recording_is_residing_on_an_external_Server') :
        _('This_Recording_will_not_be_included_in_download')
      tooltip(_('Recording_file_was_not_found_locally'), message)
        .html_safe << 'style=background-color:#FFDDCC'
    end
  end
end
