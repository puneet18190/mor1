INSERT INTO `rates` (`id`, `tariff_id`, `destination_id`, `destinationgroup_id`, `ghost_min_perc`, `effective_from`) VALUES
(564, 6, 1722, NULL, NULL, NULL),
(565, 6, 5595, NULL, NULL, NULL),
(566, 6, 5931, NULL, NULL, NULL),
(567, 6, 9599, NULL, NULL, NULL),
(568, 6, 8029, NULL, NULL, NULL),
(569, 6, 8489, NULL, NULL, NULL),
(570, 6, 9241, NULL, NULL, NULL);
INSERT INTO `ratedetails` (`id`, `start_time`, `end_time`, `rate`, `connection_fee`, `rate_id`, `increment_s`, `min_time`, `daytype`) VALUES
(526, '00:00:00', '23:59:59', 0.451230100000000, 0.000000000000000, 564, 1, 0, ''),
(527, '00:00:00', '23:59:59', 0.371123010000000, 0.000000000000000, 565, 1, 0, ''),
(528, '00:00:00', '23:59:59', 0.223123010000000, 0.000000000000000, 566, 1, 0, ''),
(529, '00:00:00', '23:59:59', 0.712301000000000, 0.000000000000000, 567, 1, 0, ''),
(530, '00:00:00', '23:59:59', 0.341230100000000, 0.000000000000000, 568, 1, 0, ''),
(531, '00:00:00', '23:59:59', 0.886123010000000, 0.000000000000000, 569, 1, 0, ''),
(532, '00:00:00', '23:59:59', 0.112301000000000, 0.000000000000000, 570, 1, 0, '');