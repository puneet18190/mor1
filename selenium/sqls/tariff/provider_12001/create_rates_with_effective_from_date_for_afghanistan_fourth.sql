INSERT INTO `rates` (`id`, `tariff_id`, `destination_id`, `destinationgroup_id`, `ghost_min_perc`, `effective_from`, `prefix`) VALUES
(1201085, 12001, 2, NULL, 5.000000000000000, '2014-05-29 00:00:00', '93'),
(1201086, 12001, 2, NULL, 5.000000000000000, '2014-06-06 00:00:00', '93'),
(1201087, 12001, 2, NULL, 5.000000000000000, '2014-06-15 00:00:00', '93'),
(1201088, 12001, 2, NULL, 5.000000000000000, '2014-06-27 00:00:00', '93');

#UPDATE rates JOIN destinations ON destinations.id = rates.destination_id SET rates.prefix = destinations.prefix, rates.name = destinations.name WHERE rates.name = '' AND rates.prefix = '';

INSERT INTO `ratedetails` (`id`, `start_time`, `end_time`, `rate`, `connection_fee`, `rate_id`, `increment_s`, `min_time`, `daytype`) VALUES
(1201085, '00:00:00', '23:59:59', 0.230000000000000, 0.000000000000000, 1201085, 1, 0, ''),
(1201086, '00:00:00', '23:59:59', 0.240000000000000, 0.000000000000000, 1201086, 1, 0, ''),
(1201087, '00:00:00', '23:59:59', 0.250000000000000, 0.000000000000000, 1201087, 1, 0, ''),
(1201088, '00:00:00', '23:59:59', 0.260000000000000, 0.000000000000000, 1201088, 1, 0, '');
