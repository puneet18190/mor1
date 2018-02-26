#3 - tarifo id, 531 tik id
INSERT INTO `aratedetails` (`from`, `duration`, `artype`, `round`, `price`, `rate_id`, `start_time`, `end_time`, `daytype`) VALUES
(1, -1, 'minute', 1, 0.350000000000000, 3531, '00:00:00', '23:59:59', '');

INSERT INTO `rates` (`id`, `tariff_id`, `destination_id`, `destinationgroup_id`, `ghost_min_perc`, `effective_from`, `prefix`) VALUES
(3531, 3, 0, 3, 0.000000000000000, NULL, '355');

UPDATE `tariffs` set `last_update_date`=NOW() where id=3;
