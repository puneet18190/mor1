UPDATE dids SET status='active', reseller_id=4 WHERE id=1;

INSERT INTO `dids` (`id`, `did`, `status`, `user_id`, `device_id`, `subscription_id`, `reseller_id`, `closed_till`, `dialplan_id`, `language`, `provider_id`, `comment`, `call_limit`, `sound_file_id`, `grace_time`, `t_digit`, `t_response`, `reseller_comment`, `cid_name_prefix`, `tonezone`, `call_count`, `cc_tariff_id`, `owner_tariff_id`, `external_server`, `allow_call_reject`) VALUES
(3, '37060012345', 'free', 0, 0, 0, 3, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(4, '37060012346', 'free', 0, 0, 0, 3, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(5, '37060012347', 'reserved', 5, 0, 0, 0, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(6, '37060012348', 'reserved', 5, 0, 0, 0, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(7, '37060012349', 'active', 0, 0, 0, 0, '2006-01-01 00:00:00', 2, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(8, '37060012350', 'active', 0, 0, 0, 0, '2006-01-01 00:00:00', 2, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(9, '37261112345', 'free', 0, 0, 0, 3, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(10, '37261112346', 'free', 0, 0, 0, 3, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(11, '37261112347', 'reserved', 5, 0, 0, 0, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(12, '37261112348', 'reserved', 5, 0, 0, 0, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(13, '37261112349', 'active', 0, 0, 0, 0, '2006-01-01 00:00:00', 2, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(14, '37261112350', 'active', 0, 0, 0, 0, '2006-01-01 00:00:00', 2, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(15, '37161112345', 'free', 0, 0, 0, 0, '2006-01-01 00:00:00', 2, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(16, '37161112346', 'free', 0, 0, 0, 0, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(17, '37161112347', 'active', 0, 0, 0, 0, '2006-01-01 00:00:00', 2, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(18, '37161112348', 'free', 0, 0, 0, 0, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(19, '37161112349', 'active', 0, 0, 0, 0, '2006-01-01 00:00:00', 2, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(20, '37161112350', 'free', 0, 0, 0, 0, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(21, '39060012345', 'free', 0, 0, 0, 3, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(22, '39060012346', 'free', 0, 0, 0, 3, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(23, '39060012347', 'free', 0, 0, 0, 3, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(24, '39060012348', 'free', 0, 0, 0, 3, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(25, '39060012349', 'free', 0, 0, 0, 3, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(26, '39060012350', 'free', 0, 0, 0, 3, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(27, '000037130000', 'free', 0, 0, 0, 0, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(28, '000037130001', 'free', 0, 0, 0, 0, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(29, '000037130002', 'free', 0, 0, 0, 0, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(30, '000037130003', 'free', 0, 0, 0, 0, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(31, '000037130004', 'free', 0, 0, 0, 0, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(32, '000037130005', 'free', 0, 0, 0, 0, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(33, '000037130006', 'free', 0, 0, 0, 0, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(34, '000037130007', 'free', 0, 0, 0, 0, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(35, '000037130008', 'free', 0, 0, 0, 0, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(36, '000037130009', 'free', 0, 0, 0, 0, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0),
(37, '000037130010', 'free', 0, 0, 0, 0, '2006-01-01 00:00:00', 0, '', 1, NULL, 0, 0, 0, 10, 20, NULL, NULL, NULL, 0, 0, 0, NULL, 0);


INSERT INTO `dialplans` (`id`, `name`, `dptype`, `data1`, `data2`, `data3`, `data4`, `data5`, `data6`, `data7`, `data8`, `sound_file_id`, `user_id`, `data9`, `data10`, `data11`, `data12`, `data13`) VALUES
(2, 'qf_dp', 'quickforwarddids', NULL, NULL, '0', NULL, NULL, NULL, NULL, NULL, 0, 0, NULL, '1', NULL, NULL, NULL),
(3, 'test_dialplan', 'callingcard', '10', '4', '0', '0', '3', '3', '0', '0', 0, 0, '1', '0', '0.0', '', '0'),
(4, 'auth_by_pin_dp', 'authbypin', '3', '3', '1', '0', NULL, '0', '0', '1', 0, 0, NULL, NULL, NULL, NULL, NULL),
(5, 'callback_dp', 'callback', '1', '5', '2', '0', '', '0', NULL, NULL, 0, 0, NULL, NULL, NULL, NULL, NULL),
(6, 'ivr_dip', 'ivr', '', '', '', '', '', '', '', NULL, 0, 0, NULL, NULL, NULL, NULL, NULL),
(7, 'qf_dp_res', 'quickforwarddids', NULL, NULL, '0', NULL, NULL, NULL, NULL, NULL, 0, 3, NULL, '1', NULL, NULL, NULL),
(8, 'test_dialplan_res', 'authbypin', '3', '3', '1', '0', NULL, '0', '0', '1', 0, 3, NULL, NULL, NULL, NULL, NULL);


