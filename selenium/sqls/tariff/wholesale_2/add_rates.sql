INSERT INTO `rates` (`id`, `tariff_id`, `destination_id`, `destinationgroup_id`, `ghost_min_perc`, `effective_from`, `prefix`) VALUES
(530, 2, 9241, NULL, NULL, NULL, '1'),
(531, 2, 8489, NULL, NULL, NULL, '886'),
(532, 2, 8029, NULL, NULL, NULL, '34'),
(533, 2, 9599, NULL, NULL, NULL, '7'),
(534, 2, 9936, NULL, NULL, NULL, '79'),
(535, 2, 4242, NULL, NULL, NULL, '233'),
(536, 2, 5595, NULL, NULL, NULL, '371'),
(537, 2, 1722, NULL, NULL, NULL, '45');
INSERT INTO `ratedetails` (`id`, `start_time`, `end_time`, `rate`, `connection_fee`, `rate_id`, `increment_s`, `min_time`, `daytype`) VALUES
(511, '00:00:00', '23:59:59', 0.120000000000000, 0.000000000000000, 530, 1, 0, ''),
(512, '00:00:00', '23:59:59', 0.886200000000000, 0.000000000000000, 531, 1, 0, ''),
(513, '00:00:00', '23:59:59', 0.342000000000000, 0.000000000000000, 532, 1, 0, ''),
(514, '00:00:00', '23:59:59', 0.720000000000000, 0.000000000000000, 533, 1, 0, ''),
(515, '00:00:00', '23:59:59', 0.762000000000000, 0.000000000000000, 534, 1, 0, ''),
(516, '00:00:00', '23:59:59', 0.223200000000000, 0.000000000000000, 535, 1, 0, ''),
(517, '00:00:00', '23:59:59', 0.371200000000000, 0.000000000000000, 536, 1, 0, ''),
(518, '00:00:00', '23:59:59', 0.452000000000000, 0.000000000000000, 537, 1, 0, '');
