INSERT INTO `providers` (`id`, `name`, `tech`, `channel`, `login`, `password`, `server_ip`, `port`, `priority`, `quality`, `tariff_id`, `cut_a`, `cut_b`, `add_a`, `add_b`, `device_id`, `ani`, `timeout`, `call_limit`, `interpret_noanswer_as_failed`, `interpret_busy_as_failed`, `register`, `reg_extension`, `terminator_id`, `reg_line`, `hidden`, `use_p_asserted_identity`, `user_id`, `common_use`, `balance`) VALUES
(3002, 'admin_prov_sip', 'SIP', '', 'admin_prov_sip', 'admin_prov_password', '33.44.55.66', '5060', 1, 1, 1, 0, 0, '', '', 2001, 0, 60, 0, 0, 0, 0, '', 0, '', 0, 0, 0, 0, 0.000000000000000);

INSERT INTO `devices` (`id`, `name`, `host`, `secret`, `context`, `ipaddr`, `port`, `regseconds`, `accountcode`, `callerid`, `extension`, `voicemail_active`, `username`, `device_type`, `user_id`, `primary_did_id`, `works_not_logged`, `forward_to`, `record`, `transfer`, `disallow`, `allow`, `deny`, `permit`, `nat`, `qualify`, `fullcontact`, `canreinvite`, `devicegroup_id`, `dtmfmode`, `callgroup`, `pickupgroup`, `fromuser`, `fromdomain`, `trustrpid`, `sendrpid`, `insecure`, `progressinband`, `videosupport`, `location_id`, `description`, `istrunk`, `cid_from_dids`, `pin`, `tell_balance`, `tell_time`, `tell_rtime_when_left`, `repeat_rtime_every`, `t38pt_udptl`, `regserver`, `ani`, `promiscredir`, `timeout`, `process_sipchaninfo`, `temporary_id`, `allow_duplicate_calls`, `call_limit`, `lastms`, `faststart`, `h245tunneling`, `latency`, `grace_time`, `recording_to_email`, `recording_keep`, `recording_email`, `record_forced`, `fake_ring`, `save_call_log`, `mailbox`, `server_id`, `enable_mwi`, `authuser`, `requirecalltoken`, `language`, `use_ani_for_cli`, `calleridpres`, `change_failed_code_to`, `reg_status`, `max_timeout`, `forward_did_id`, `anti_resale_auto_answer`, `qf_tell_balance`, `qf_tell_time`, `time_limit_per_day`, `control_callerid_by_cids`, `callerid_advanced_control`, `transport`, `subscribemwi`, `encryption`, `block_callerid`, `tell_rate`, `trunk`, `proxy_port`, `cps_call_limit`, `cps_period`) VALUES
(2001, 'prov_2011', '33.44.55.66', 'admin_prov_password', 'mor', '33.44.55.66', 5060, 0, 2001, NULL, 'c3ed8huy1b', 0, 'admin_prov_sip', 'SIP', -1, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'no', 'yes', NULL, 'no', NULL, 'rfc2833', NULL, NULL, NULL, NULL, 'yes', 'no', 'port,invite', 'never', 'no', 1, NULL, 1, 0, NULL, 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0.000000000000000, 0, 0, 0, NULL, 0, 0, 0, '', 1, 0, '', 'no', 'en', 0, NULL, 0, NULL, 0, 0, 0, 0, 0, 0, NULL, 0, 'udp', 'no', 'no', 0, 0, 'no', 5060, 0, 0);
