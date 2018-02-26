INSERT INTO `actions` (`user_id`, `date`, `action`, `data`, `data2`, `processed`, `target_type`, `target_id`, `data3`, `data4`) VALUES
(4, '2014-11-06 11:52:34', 'Starting_invoices_generation', '2014-11-06 11:52:34 +0200', NULL, 0, '', NULL, NULL, NULL),
(4, '2014-11-06 11:52:36', 'Finish_invoices_generation', '2014-11-06 11:52:36 +0200', NULL, 0, '', NULL, NULL, NULL),
(3, '2014-11-06 13:39:24', 'Starting_invoices_generation', '2014-11-06 13:39:24 +0200', NULL, 0, '', NULL, NULL, NULL),
(3, '2014-11-06 13:39:24', 'Finish_invoices_generation', '2014-11-06 13:39:24 +0200', NULL, 0, '', NULL, NULL, NULL),
(0, '2014-11-06 16:39:24', 'Starting_invoices_generation', '2014-11-06 16:39:24 +0200', NULL, 0, '', NULL, NULL, NULL),
(0, '2014-11-06 16:39:24', 'Finish_invoices_generation', '2014-11-06 16:39:24 +0200', NULL, 0, '', NULL, NULL, NULL);

INSERT INTO `invoices` (`id`, `user_id`, `period_start`, `period_end`, `issue_date`, `paid`, `paid_date`, `price`, `price_with_vat`, `payment_id`, `number`, `sent_email`, `sent_manually`, `invoice_type`, `number_type`, `tax_id`, `comment`, `tax_1_value`, `tax_2_value`, `tax_3_value`, `tax_4_value`, `invoice_precision`, `invoice_exchange_rate`, `invoice_currency`, `timezone`) VALUES
(4, 0, '2008-01-01', '2009-12-31', '2014-11-06', 0, NULL, 13.000000000000000, 13.000000000000000, NULL, 'INV0801011', 0, 0, 'postpaid', 2, 1010, NULL, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 4, 1.000000000000000, 'USD', 'Mountain Time (US & Canada)'),
(5, 2, '2008-01-01', '2009-12-31', '2014-11-06', 0, NULL, 126.225800000000000, 126.225800000000000, NULL, 'INV0801012', 0, 0, 'postpaid', 2, 1011, NULL, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 4, 1.000000000000000, 'USD', 'UTC'),
(6, 3, '2008-01-01', '2009-12-31', '2014-11-06', 0, NULL, 33.00000000000000, 33.000000000000000, NULL, 'INV0801013', 0, 0, 'postpaid', 2, 1012, NULL, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 4, 1.000000000000000, 'USD', 'Vilnius'),
(7, 2, '2012-11-01', '2012-11-30', '2014-11-06', 0, NULL, 40.252600000000000, 40.252600000000000, NULL, 'INV1211011', 0, 0, 'postpaid', 2, 1012, NULL, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 4, 1.000000000000000, 'USD', 'UTC'),
(8, 5, '2009-01-15', '2013-01-15', '2014-11-06', 0, NULL, 6.000000000000000, 6.000000000000000, NULL, '0701151', 0, 0, 'postpaid', 2, 1012, NULL, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 4, 1.000000000000000, 'USD', 'UTC'),
#kitoks invoice currency
(9, 2, '2013-02-01', '2013-02-28', '2013-02-28', 0, NULL, 10.000000000000000, 10.000000000000000, NULL, 'INV1302011', 0, 0, 'postpaid', 2, 1011, NULL, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 4, 0.73853104, 'EUR', 'Arizona'),
(10, 5, '2013-02-01', '2013-02-28', '2013-02-28', 0, NULL, 0.879100000000000, 0.879100000000000, NULL, '1302011', 0, 0, 'postpaid', 2, 1011, NULL, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 4, 0.73853104, 'EUR', 'UTC'),
#prepaid invoisas
(11, 2, '2012-11-20', '2014-11-06', '2014-11-06', 1, NULL, 235.666700000000000, 235.666700000000000, NULL, '1211201', 0, 0, 'prepaid', 2, 1012, NULL, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 4, 0.73853104, 'EUR', 'UTC'),
(12, 5, '2012-11-20', '2014-11-06', '2014-11-06', 1, NULL, 235.666700000000000, 235.666700000000000, NULL, '1211201', 0, 0, 'prepaid', 2, 1012, NULL, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 4, 0.73853104, 'EUR', 'Atlantic Time (Canada)');

INSERT INTO `invoicedetails` (`id`, `invoice_id`, `name`, `quantity`, `price`, `invdet_type`) VALUES
(11, 4, 'Italy', 1, 2.000000000000000, 0),
(12, 4, 'DID Owner Cost', 1, 1.000000000000000, 0),
(13, 4, 'SMS', 1, 10.000000000000000, 0),
(14, 5, 'Romania', 2, 12.000000000000000, 0),
(15, 5, 'DID Owner Cost', 1, 1.000000000000000, 0),
(16, 5, 'Test_periodic_service - Test_preriodic_service_memo', 1, 93.225800000000000, 1),
(17, 5, 'SMS', 2, 20.000000000000000, 0),
(18, 6, 'Belarus', 1, 4.000000000000000, 0),
(19, 6, 'Calls from Users', 4, 28.000000000000000, 0),
(20, 6, 'DID Owner Cost', 1, 17.000000000000000, 0),
(21, 7, 'USA', 8, 10.469300000000000, 0),
(22, 7, 'Calls to DIDs', 8, 3.913300000000000, 0),
(23, 7, 'DID Owner Cost', 12, 15.870000000000000, 0),
(24, 7, 'Test_periodic_service - Test_preriodic_service_memo', 1, 10.000000000000000, 1),
(25, 8, 'Lithuania', 1, 5.000000000000000, 0),
(26, 8, 'DID Owner Cost', 1, 1.000000000000000, 0),
(27, 9, 'Test_periodic_service - Test_preriodic_service_memo', 1, 10.000000000000000, 1),
(28, 10, 'test-periodic-fee', 1, 0.879100000000000, 1),
(29, 11, 'Test_periodic_service - Test_preriodic_service_memo', 1, 235.666700000000000, 1),
(30, 12, 'Test_periodic_service - Test_preriodic_service_memo', 1, 235.666700000000000, 1);
update invoicedetails set prefix=1 where id=21;
update invoicedetails set total_time=3214 where id=21;
update invoicedetails set prefix=370 where id=25;
update invoicedetails set total_time=50 where id=11;
update invoicedetails set total_time=1250 where id=14;
update invoicedetails set total_time=325 where id=18;

INSERT INTO `taxes` (`id`, `tax1_enabled`, `tax2_enabled`, `tax3_enabled`, `tax4_enabled`, `tax1_name`, `tax2_name`, `tax3_name`, `tax4_name`, `total_tax_name`, `tax1_value`, `tax2_value`, `tax3_value`, `tax4_value`, `compound_tax`) VALUES
(1010, 0, 0, 0, 0, 'Tax', '', '', '', 'Tax', 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 1),
(1011, 0, 0, 0, 0, 'Tax', '', '', '', 'Tax', 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 1),
(1012, 0, 0, 0, 0, 'Tax', '', '', '', 'Tax', 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 1);

INSERT INTO `services` (`id`, `name`, `servicetype`, `destinationgroup_id`, `periodtype`, `price`, `owner_id`, `quantity`, `selfcost_price`) VALUES
(2, 'test-periodic-fee', 'periodic_fee', NULL, 'month', 0.879120879120879, 3, 1, 0.879120879120879);

INSERT INTO `subscriptions` (`id`, `service_id`, `user_id`, `device_id`, `activation_start`, `activation_end`, `added`, `memo`, `no_expire`) VALUES
(2, 2, 5, NULL, '2013-02-01 00:00:00', '2013-02-28 23:59:00', '2014-11-06 14:04:00', '', 0);

INSERT INTO `conflines` (name, value, owner_id) VALUES
 ('group_regular_calls_by_destination', 1, 0),
 ('group_regular_calls_by_destination', 1, 3);
