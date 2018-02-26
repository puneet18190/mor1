INSERT INTO `ratedetails` (`id`, `start_time`, `end_time`, `rate`, `connection_fee`, `rate_id`, `increment_s`, `min_time`, `daytype`) VALUES
(120126, '00:00:00', '23:59:59', 0.658700000000000, 0.000000000000000, 120126, 1, 0, '');

INSERT INTO `rates` (`id`, `tariff_id`, `destination_id`, `destinationgroup_id`, `ghost_min_perc`, `effective_from`, `prefix`) VALUES
(120126, 12303, 9241, NULL, NULL, NULL,1);

#add rates.prefix ir rates.name
#UPDATE rates JOIN destinations ON destinations.id = rates.destination_id SET rates.prefix = destinations.prefix, rates.name = destinations.name WHERE rates.name = '' AND rates.prefix = '';

