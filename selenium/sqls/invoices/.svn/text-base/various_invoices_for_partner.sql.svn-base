INSERT INTO `actions` (`user_id`, `date`, `action`, `data`, `data2`, `processed`, `target_type`, `target_id`, `data3`, `data4`) VALUES
(1600101, '2014-11-06 11:52:34', 'Starting_invoices_generation', '2014-11-06 11:52:34 +0200', NULL, 0, '', NULL, NULL, NULL),
(1600101, '2014-11-06 11:52:36', 'Finish_invoices_generation', '2014-11-06 11:52:36 +0200', NULL, 0, '', NULL, NULL, NULL);

INSERT INTO `invoices` (`id`, `user_id`, `period_start`, `period_end`, `issue_date`, `paid`, `paid_date`, `price`, `price_with_vat`, `payment_id`, `number`, `sent_email`, `sent_manually`, `invoice_type`, `number_type`, `tax_id`, `comment`, `tax_1_value`, `tax_2_value`, `tax_3_value`, `tax_4_value`, `invoice_precision`, `invoice_exchange_rate`, `invoice_currency`, `timezone`) VALUES
(50, 1600101, '2008-01-01', '2009-12-31', '2014-11-06', 0, NULL, 13.000000000000000, 13.000000000000000, NULL, 'INV0801011', 0, 0, 'postpaid', 2, 1010, NULL, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 4, 1.000000000000000, 'USD', 'Mountain Time (US & Canada)'),
(51, 1600101, '2008-01-01', '2009-12-31', '2014-11-06', 0, NULL, 126.225800000000000, 126.225800000000000, NULL, 'INV0801012', 0, 0, 'postpaid', 2, 1011, NULL, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 4, 1.000000000000000, 'USD', 'UTC'),
#kitoks invoice currency
(52, 1600101, '2013-02-01', '2013-02-28', '2013-02-28', 0, NULL, 10.000000000000000, 10.000000000000000, NULL, 'INV1302011', 0, 0, 'postpaid', 2, 1011, NULL, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 4, 1.000000000000000, 'EUR', 'Arizona'),
#prepaid invoisas
(53, 1600101, '2012-11-20', '2014-11-06', '2014-11-06', 1, NULL, 235.666700000000000, 235.666700000000000, NULL, '1211201', 0, 0, 'prepaid', 2, 1012, NULL, 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 4, 1.000000000000000, 'EUR', 'UTC');
INSERT INTO `invoicedetails` (`id`, `invoice_id`, `name`, `quantity`, `price`, `invdet_type`) VALUES
(51, 50, 'Italy', 1, 2.000000000000000, 0),
(52, 50, 'DID Owner Cost', 1, 1.000000000000000, 0),
(53, 50, 'SMS', 1, 10.000000000000000, 0),
(54, 51, 'Romania', 2, 12.000000000000000, 0),
(55, 51, 'DID Owner Cost', 1, 1.000000000000000, 0),
(56, 51, 'Test_periodic_service - Test_preriodic_service_memo', 1, 93.225800000000000, 1),
(57, 51, 'SMS', 2, 20.000000000000000, 0),
(58, 52, 'Belarus', 1, 4.000000000000000, 0),
(59, 52, 'Calls from Users', 4, 28.000000000000000, 0),
(60, 52, 'DID Owner Cost', 1, 17.000000000000000, 0),
(61, 53, 'Lithuania', 8, 10.469300000000000, 0),
(62, 53, 'Calls to DIDs', 8, 3.913300000000000, 0),
(63, 53, 'DID Owner Cost', 12, 15.870000000000000, 0),
(64, 53, 'Test_periodic_service - Test_preriodic_service_memo', 1, 10.000000000000000, 1),
(65, 53, 'USA', 12, 15.870000000000000, 0);
update invoicedetails set prefix=9725 where id=50;
update invoicedetails set total_time=50 where id=50;
update invoicedetails set total_time=1250 where id=51;
update invoicedetails set prefix=407 where id=51;
update invoicedetails set total_time=326454 where id=53;
update invoicedetails set prefix=370 where id=53;
update invoicedetails set total_time=325 where id=52;
update invoicedetails set prefix=37525 where id=52;
update invoicedetails set total_time=3214 where id=65;
update invoicedetails set prefix=1 where id=65;

INSERT INTO `conflines` (name, value, owner_id) VALUES
 ('group_regular_calls_by_destination', 1, 0),
 ('group_regular_calls_by_destination', 1, 6001);
