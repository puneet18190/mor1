INSERT INTO `lcrs` (`id`, `name`, `order`, `user_id`, `first_provider_percent_limit`, `failover_provider_id`, `no_failover`) VALUES (11302, 'price_rs', 'price', 3, 0.000000000000000, NULL, 0);

INSERT INTO `lcr_timeperiods` (`id`, `name`, `start_hour`, `end_hour`, `start_minute`, `end_minute`, `start_weekday`, `end_weekday`, `start_day`, `end_day`, `start_month`, `end_month`, `main_lcr_id`, `lcr_id`, `active`) VALUES
(1130211, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 11302, 0, 0),
(1130222, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 11302, 0, 0),
(1130233, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 11302, 0, 0),
(1130244, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 11302, 0, 0),
(1130255, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 11302, 0, 0);
