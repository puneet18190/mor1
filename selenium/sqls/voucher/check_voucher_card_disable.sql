DELETE FROM `conflines` where name='Voucher_Card_Disable';
INSERT INTO `conflines` (`name`, `value`, `owner_id`, `value2`) VALUES
('Voucher_Card_Disable', '1', 0, NULL);