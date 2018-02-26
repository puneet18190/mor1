UPDATE `users` set tariff_id=4 where id=2;

INSERT INTO `actions` (`user_id`, `date`, `action`, `data`, `data2`, `processed`, `target_type`, `target_id`, `data3`, `data4`) VALUES
(0, NOW(), 'user_edited', '', '', 0, 'user', 2, NULL, NULL),
(0, NOW(), 'user_tariff_changed', 'Test Tariff for Users', 'Test Tariff + 0.1', 0, 'user', 2, NULL, NULL);
