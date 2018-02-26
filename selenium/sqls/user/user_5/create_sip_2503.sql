INSERT INTO `devices` (`id`, `name`, `host`, `secret`, `context`, `ipaddr`, `port`, `regseconds`, `accountcode`, `callerid`, `extension`, `voicemail_active`, `username`, `device_type`, `user_id`, `primary_did_id`, `works_not_logged`, `forward_to`, `record`, `transfer`, `disallow`, `allow`, `deny`, `permit`, `nat`, `qualify`, `fullcontact`, `canreinvite`, `devicegroup_id`, `dtmfmode`, `callgroup`, `pickupgroup`, `fromuser`, `fromdomain`, `trustrpid`, `sendrpid`, `insecure`, `progressinband`, `videosupport`, `location_id`, `description`, `istrunk`, `cid_from_dids`, `pin`, `tell_balance`, `tell_time`, `tell_rtime_when_left`, `repeat_rtime_every`, `t38pt_udptl`, `regserver`, `ani`, `promiscredir`, `timeout`, `process_sipchaninfo`, `temporary_id`, `allow_duplicate_calls`, `call_limit`, `lastms`, `faststart`, `h245tunneling`, `latency`, `grace_time`, `recording_to_email`, `recording_keep`, `recording_email`, `record_forced`, `fake_ring`, `save_call_log`, `mailbox`, `server_id`, `enable_mwi`, `authuser`, `requirecalltoken`, `language`, `use_ani_for_cli`, `calleridpres`, `change_failed_code_to`, `reg_status`, `max_timeout`, `forward_did_id`, `anti_resale_auto_answer`, `qf_tell_balance`, `qf_tell_time`, `time_limit_per_day`, `control_callerid_by_cids`, `callerid_advanced_control`, `transport`, `subscribemwi`, `encryption`, `block_callerid`, `tell_rate`, `trunk`, `proxy_port`, `cps_call_limit`, `cps_period`, `timerb`, `callerid_number_pool_id`, `defaultuser`, `useragent`, `type`, `md5secret`, `remotesecret`, `directmedia`, `useclientcode`, `setvar`, `amaflags`, `callcounter`, `busylevel`, `allowoverlap`, `allowsubscribe`, `maxcallbitrate`, `rfc2833compensate`, `session-timers`, `session-expires`, `session-minse`, `session-refresher`, `t38pt_usertpsource`, `regexten`, `defaultip`, `rtptimeout`, `rtpholdtimeout`, `outboundproxy`, `callbackextension`, `timert1`, `qualifyfreq`, `constantssrc`, `contactpermit`, `contactdeny`, `usereqphone`, `textsupport`, `faxdetect`, `buggymwi`, `auth`, `fullname`, `trunkname`, `cid_number`, `callingpres`, `mohinterpret`, `mohsuggest`, `parkinglot`, `hasvoicemail`, `vmexten`, `autoframing`, `rtpkeepalive`, `call-limit`, `g726nonstandard`, `ignoresdpversion`, `allowtransfer`, `dynamic`) VALUES
(2503, '1005', 'dynamic', '6ewg0xg294m3', 'mor_local', '', 5060, 0, 2503, '', '1005', 0, '1005', 'SIP', 5, 0, 1, 0, 0, 'no', 'all', 'alaw;g729', '0.0.0.0/0.0.0.0', '0.0.0.0/0.0.0.0', 'yes', '1000', NULL, 'no', 3, 'rfc2833', NULL, NULL, '', '', 'no', 'no', '', 'no', 'no', 3, 'sip device for user_reseller', 0, 0, '219729', 0, 0, 60, 60, 'no', NULL, 0, 'no', 60, 0, NULL, 0, 0, 0, 'yes', 'yes', 0.000000000000000, NULL, 0, 0, '', 0, 0, 0, '', 1, 0, '', 'no', 'en', NULL, '', 0, NULL, 0, 0, 0, 0, 0, 0, 0, 0, 'udp', 'no', '', 0, 0, 'no', 5060, 0, 0, 6400, 0, '1005', NULL, 'friend', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);

INSERT INTO `devicecodecs` (`id`, `device_id`, `codec_id`, `priority`) VALUES
(2502, 2503, 1, 0),
(2503, 2503, 5, 0);

INSERT INTO `server_devices` (`id`, `device_id`, `server_id`) VALUES
(2501, 2503, 1);

INSERT INTO `voicemail_boxes` (`uniqueid`, `context`, `mailbox`, `password`, `fullname`, `email`, `pager`, `tz`, `attach`, `saycid`, `dialout`, `callback`, `review`, `operator`, `envelope`, `sayduration`, `saydurationm`, `sendvoicemail`, `delete`, `nextaftercmd`, `forcename`, `forcegreetings`, `hidefromdir`, `stamp`, `device_id`) VALUES
(2501, 'default', '1005', '', 'User Resellers', '', '', 'central', 'yes', 'yes', '', '', 'no', 'no', 'no', 'no', 1, 'no', 'no', 'yes', 'no', 'no', 'yes', '2013-09-12 16:34:34', 2503);