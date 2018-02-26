INSERT INTO `calls` (`id`, `calldate`, `clid`, `src`, `dst`, `dcontext`, `channel`, `dstchannel`, `lastapp`, `lastdata`, `duration`, `billsec`, `disposition`, `amaflags`, `accountcode`, `uniqueid`, `userfield`, `src_device_id`, `dst_device_id`, `processed`, `did_price`, `card_id`, `provider_id`, `provider_rate`, `provider_billsec`, `provider_price`, `user_id`, `user_rate`, `user_billsec`, `user_price`, `reseller_id`, `reseller_rate`, `reseller_billsec`, `reseller_price`, `partner_id`, `partner_rate`, `partner_billsec`, `partner_price`, `prefix`, `server_id`, `hangupcause`, `callertype`, `did_inc_price`, `did_prov_price`, `localized_dst`, `did_provider_id`, `did_id`, `originator_ip`, `terminator_ip`, `real_duration`, `real_billsec`, `did_billsec`, `dst_user_id`) VALUES
(200, '2014-01-01 00:00:01', '', '101', '123123', '', '', '', '', '', 10, 20, 'ANSWERED', 0, '2', '1232113370.3', '', 5, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 2, 1600101, 0, 0, 4, 6001, 0, 0, 5, '1231', 1, 16, 'Local', 0, 0, '123123', 0, 0, '', '', 0, 1, 0, NULL),
(201, '2014-01-01 00:00:02', '', '101', '123123', '', '', '', '', '', 20, 30, 'ANSWERED', 0, '2', '1232113371.3', '', 6, 0, 0, 0, 0, 1, 0, 0, 1, 2, 0, 1, 3, 1600101, 0, 0, 4, 6001, 0, 0, 5, '1231', 1, 16, 'Local', 0, 0, '123123', 0, 0, '', '', 0, 1, 0, NULL),
(202, '2014-01-01 00:00:03', '', '101', '123123', '', '', '', '', '', 0, 0, 'BUSY', 0, '2', '1232113372.3', '', 7, 0, 0, 0, 0, 1, 0, 0, 1, 3, 0, 1, 4, 1600101, 0, 0, 4, 6001, 0, 0, 5, '1231', 1, 38, 'Local', 0, 0, '123123', 0, 0, '', '', 0, 1, 0, NULL),
(203, '2014-01-01 00:00:04', '', '101', '123123', '', '', '', '', '', 40, 50, 'ANSWERED', 0, '2', '1232113373.3', '', 2, 0, 0, 0, 0, 1, 0, 0, 1, 5, 0, 1, 5, 1600101, 0, 40, 4, 6001, 0, 0, 5, '1231', 1, 16, 'Local', 0, 0, '123123', 0, 0, '', '', 0, 1, 0, NULL),
(204, '2014-01-02 00:00:01', '37046246362', '37046246362', '37063042438', '', '', '', '', '', 10, 20, 'ANSWERED', 0, '2', '1232113374.3', '', 1, 5, 0, 1, 0, 1, 0, 0, 1, -1, 0, 1, 2, 1600101, 0, 0, 4, 6001, 0, 0, 5, '3706', 1, 16, 'Outside', 1, 1, '37063042438', 0, 1, '', '', 0, 1, 20, 0),
(205, '2014-01-02 00:00:02', '37046246362', '37046246362', '37063042438', '', '', '', '', '', 20, 30, 'ANSWERED', 0, '2', '1232113375.3', '', 1, 4, 0, 1, 0, 1, 0, 0, 1, -1, 0, 1, 3, 1600101, 0, 0, 4, 6001, 0, 0, 5, '3706', 1, 16, 'Outside', 2, 2, '37063042438', 0, 1, '', '', 0, 0, 30, 2),
(206, '2014-01-02 00:00:03', '37046246362', '37046246362', '37063042438', '', '', '', '', '', 0, 0, 'FAILED', 0, '2', '1232113376.3', '', 1, 6, 0, 1, 0, 1, 0, 0, 1, -1, 0, 1, 4, 1600101, 0, 0, 4, 6001, 0, 0, 5, '3706', 1, 12, 'Outside', 3, 3, '37063042438', 0, 1, '', '', 0, 1, 0, 3),
(207, '2014-01-02 00:00:04', '37046246362', '37046246362', '37063042438', '', '', '', '', '', 40, 50, 'ANSWERED', 0, '2', '1232113377.3', '', 1, 7, 0, 1, 0, 1, 0, 0, 1, -1, 0, 1, 5, 1600101, 0, 31, 4, 6001, 0, 0, 5, '3706', 1, 16, 'Outside', 4, 4, '37063042438', 0, 1, '', '', 0, 1, 50, 5),
(208, '2008-01-01 00:00:01', '37046246362', '37046246362', '37063042438', '', '', '', '', '', 10, 20, 'ANSWERED', 0, '2', '1232113374.3', '', 5, 0, 0, 0, 0, 1, 0, 0, 1, -1, 0, 1, 2, 1600101, 0, 0, 4, 6001, 0, 0, 5, '3706', 0, 16, 'Outside', 1, 1, '37063042438', 0, 0, '', '', 0, 1, 20, NULL),
(209, '2008-01-01 00:00:02', '37046246362', '37046246362', '37063042438', '', '', '', '', '', 20, 30, 'ANSWERED', 0, '2', '1232113375.3', '', 4, 0, 0, 0, 0, 1, 0, 0, 1, -1, 0, 1, 3, 1600101, 0, 0, 4, 6001, 0, 0, 5, '3706', 0, 16, 'Outside', 2, 2, '37063042438', 0, 0, '', '', 0, 1, 30, NULL),
(210, '2008-01-01 00:00:03', '37046246362', '37046246362', '37063042438', '', '', '', '', '', 30, 40, 'ANSWERED', 0, '2', '1232113376.3', '', 6, 0, 0, 0, 0, 1, 0, 0, 1, -1, 0, 1, 4, 1600101, 0, 40, 4, 6001, 0, 0, 5, '3706', 0, 16, 'Outside', 3, 3, '37063042438', 0, 0, '', '', 0, 1, 40, NULL),
(211, '2008-01-01 00:00:02', '37046246362', '37046246362', '37063042438', '', '', '', '', '', 20, 30, 'ANSWERED', 0, '2', '1232113375.3', '', 4, 0, 0, 0, 0, 1, 0, 0, 1, -1, 0, 1, 3, 1600101, 0, 0, 4, 6002, 0, 0, 5, '3706', 0, 16, 'Outside', 2, 2, '37063042438', 0, 0, '', '', 0, 1, 30, NULL),
(212, '2008-01-01 00:00:03', '37046246362', '37046246362', '37063042438', '', '', '', '', '', 30, 40, 'ANSWERED', 0, '2', '1232113376.3', '', 6, 0, 0, 0, 0, 1, 0, 0, 1, -1, 0, 1, 4, 1600101, 0, 40, 4, 6002, 0, 0, 5, '3706', 0, 16, 'Outside', 3, 3, '37063042438', 0, 0, '', '', 0, 1, 40, NULL);
