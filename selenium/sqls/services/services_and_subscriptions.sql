INSERT INTO `services`
(`id`,`name`,`servicetype`,`destinationgroup_id`,`periodtype`,`price`,`owner_id`,`quantity`,`selfcost_price`)
VALUES
(2,'Periodic Fee','periodic_fee',NULL,'month ',11,0,NULL,0),
(10,'Periodic Fee_2','periodic_fee',NULL,'month ',11,0,NULL,0),
(3,'One Time Fee','one_time_fee',NULL,'',12,0,NULL,0),
(11,'One Time Fee_3','one_time_fee',NULL,'',12,0,NULL,0),
(4,'One Time Fee_4','one_time_fee',NULL,'',13,0,NULL,0),
(5,'Flat Rate','flat_rate',NULL,'',1,0,1,0),
(12,'Flat Rate_5','flat_rate',NULL,'',1,0,1,0),
(6,'Flat Rate_6','flat_rate',NULL,'',4,0,1,0),
(7,'Periodic Fee reseller','periodic_fee',NULL,'month ',10,3,NULL,0),
(13,'Periodic Fee reseller_1','periodic_fee',NULL,'month ',10,3,NULL,0),
(8,'One Time Fee reseller1','one_time_fee',NULL,'',20,3,NULL,0),
(14,'One Time Fee reseller1_2','one_time_fee',NULL,'',20,3,NULL,0),
(9,'Flat Rate reseller2','flat_rate',NULL,'',30,3,4,0),
(15,'Flat Rate reseller2_2','flat_rate',NULL,'',30,3,4,0),
(16,'Periodic Fee_3','periodic_fee',NULL,'month ',11,0,NULL,0),
(17,'One Time Fee_5','one_time_fee',NULL,'',12,0,NULL,0),
(18,'Flat Rate_7','flat_rate',NULL,'',1,0,1,0),
(19,'Periodic Fee_4','periodic_fee',NULL,'month ',11,0,NULL,0),
(20,'One Time Fee_6','one_time_fee',NULL,'',12,0,NULL,0),
(21,'Flat Rate_8','flat_rate',NULL,'',1,0,1,0),
(22,'Periodic Fee reseller_2','periodic_fee',NULL,'month ',10,3,NULL,0),
(23,'One Time Fee reseller1_3','one_time_fee',NULL,'',20,3,NULL,0),
(24,'Flat Rate reseller2_3','flat_rate',NULL,'',30,3,4,0);

INSERT INTO `subscriptions`
(`id`, `service_id`, `user_id`, `device_id`, `activation_start`, `activation_end`, `added`, `memo`) 
VALUES
# user_admin subscriptionai
## 3x periodic
(11,2,2,NULL,'2010-03-23 09:25:00','2013-02-25 09:25:00','2012-02-02 09:25:00','Periodic fee subscription'),
(12,2,2,NULL,'2010-09-22 09:25:00','2013-12-08 09:25:00','2012-12-12 09:25:00','Periodic fee subscription 2'),
(13,2,2,NULL,'2011-04-24 09:25:00','2013-04-24 09:25:00','2012-04-01 09:25:00','Periodic fee subscription 3'),
## 3x flat rate
(14,6,2,NULL,'2011-02-25 09:25:00','2013-09-17 09:25:00','2012-09-21 09:25:00','Flat Rate subscription'),
(15,6,2,NULL,'2011-03-25 09:28:08','2013-02-22 09:25:00','2012-02-26 09:25:00','Flat Rate subscription 2'),
(16,6,2,NULL,'2010-09-23 09:25:00','2013-01-09 09:25:00','2012-01-13 09:25:00','Flat Rate subscription 3'),
## 3x one time fee
(17,3,2,NULL,'2011-02-25 09:25:00','2013-09-17 09:25:00','2012-09-21 09:25:00','One Time Fee subscription'),
(18,3,2,NULL,'2011-03-25 09:28:08','2013-02-22 09:25:00','2012-02-26 09:25:00','One Time Fee subscription 2'),
(19,3,2,NULL,'2010-09-23 09:25:00','2013-01-09 09:25:00','2012-01-13 09:25:00','One Time Fee subscription 3'),
# user_reseller subscriptionai
## 3x periodic
(20,7,5,NULL,'2010-03-23 09:25:00','2013-02-25 09:25:00','2012-02-02 09:25:00','Periodic fee subscription'),
(21,7,5,NULL,'2010-09-22 09:25:00','2013-12-08 09:25:00','2012-12-12 09:25:00','Periodic fee subscription 2'),
(22,7,5,NULL,'2011-04-24 09:25:00','2013-04-24 09:25:00','2012-04-01 09:25:00','Periodic fee subscription 3'),
## 3x flat rate
(23,9,5,NULL,'2011-02-25 09:25:00','2013-09-17 09:25:00','2012-09-21 09:25:00','Flat Rate subscription'),
(24,9,5,NULL,'2011-03-25 09:28:08','2013-02-22 09:25:00','2012-02-26 09:25:00','Flat Rate subscription 2'),
(25,9,5,NULL,'2010-09-23 09:25:00','2013-01-09 09:25:00','2012-01-13 09:25:00','Flat Rate subscription 3'),
## 3x one time fee
(26,8,5,NULL,'2011-02-25 09:25:00','2013-09-17 09:25:00','2012-09-21 09:25:00','One Time Fee subscription'),
(27,8,5,NULL,'2011-03-25 09:28:08','2013-02-22 09:25:00','2012-02-26 09:25:00','One Time Fee subscription 2'),
(28,8,5,NULL,'2010-09-23 09:25:00','2013-01-09 09:25:00','2012-01-13 09:25:00','One Time Fee subscription 3'),
# reseller subscriptionai
## 3x periodic
(29,10,3,NULL,'2010-03-23 09:25:00','2013-02-25 09:25:00','2012-02-02 09:25:00','Periodic fee subscription'),
(30,10,3,NULL,'2010-09-22 09:25:00','2013-12-08 09:25:00','2012-12-12 09:25:00','Periodic fee subscription 2'),
(31,10,3,NULL,'2011-04-24 09:25:00','2013-04-24 09:25:00','2012-04-01 09:25:00','Periodic fee subscription 3'),
## 3x flat rate
(32,5,3,NULL,'2011-02-25 09:25:00','2013-09-17 09:25:00','2012-09-21 09:25:00','Flat Rate subscription'),
(33,5,3,NULL,'2011-03-25 09:28:08','2013-02-22 09:25:00','2012-02-26 09:25:00','Flat Rate subscription 2'),
(34,5,3,NULL,'2010-09-23 09:25:00','2013-01-09 09:25:00','2012-01-13 09:25:00','Flat Rate subscription 3'),
## 3x one time fee
(35,4,5,NULL,'2011-02-25 09:25:00','2013-09-17 09:25:00','2012-09-21 09:25:00','One Time Fee subscription'),
(36,4,5,NULL,'2011-03-25 09:28:08','2013-02-22 09:25:00','2012-02-26 09:25:00','One Time Fee subscription 2'),
(37,4,5,NULL,'2010-09-23 09:25:00','2013-01-09 09:25:00','2012-01-13 09:25:00','One Time Fee subscription 3');

# dar daugiau subscriptionu, kad butu galima testuoti prepaid tipa
INSERT INTO `subscriptions`
(`id`, `service_id`, `user_id`, `device_id`, `activation_start`, `activation_end`, `added`, `memo`) 
VALUES
# user_admin subscriptionai
## 3x periodic
(38,2,2,NULL,'2010-03-23 09:25:00','2013-02-25 09:25:00','2012-02-02 09:25:00','Periodic fee subscription'),
(39,2,2,NULL,'2010-09-22 09:25:00','2013-12-08 09:25:00','2012-12-12 09:25:00','Periodic fee subscription 2'),
(40,2,2,NULL,'2011-04-24 09:25:00','2013-04-24 09:25:00','2012-04-01 09:25:00','Periodic fee subscription 3'),
## 3x flat rate
(41,6,2,NULL,'2011-02-25 09:25:00','2013-09-17 09:25:00','2012-09-21 09:25:00','Flat Rate subscription'),
(42,6,2,NULL,'2011-03-25 09:28:08','2013-02-22 09:25:00','2012-02-26 09:25:00','Flat Rate subscription 2'),
(43,6,2,NULL,'2010-09-23 09:25:00','2013-01-09 09:25:00','2012-01-13 09:25:00','Flat Rate subscription 3'),
## 3x one time fee
(44,3,2,NULL,'2011-02-25 09:25:00','2013-09-17 09:25:00','2012-09-21 09:25:00','One Time Fee subscription'),
(45,3,2,NULL,'2011-03-25 09:28:08','2013-02-22 09:25:00','2012-02-26 09:25:00','One Time Fee subscription 2'),
(46,3,2,NULL,'2010-09-23 09:25:00','2013-01-09 09:25:00','2012-01-13 09:25:00','One Time Fee subscription 3'),
# user_reseller subscriptionai
## 3x periodic
(47,7,5,NULL,'2010-03-23 09:25:00','2013-02-25 09:25:00','2012-02-02 09:25:00','Periodic fee subscription'),
(48,7,5,NULL,'2010-09-22 09:25:00','2013-12-08 09:25:00','2012-12-12 09:25:00','Periodic fee subscription 2'),
(49,7,5,NULL,'2011-04-24 09:25:00','2013-04-24 09:25:00','2012-04-01 09:25:00','Periodic fee subscription 3'),
## 3x flat rate
(50,9,5,NULL,'2011-02-25 09:25:00','2013-09-17 09:25:00','2012-09-21 09:25:00','Flat Rate subscription'),
(51,9,5,NULL,'2011-03-25 09:28:08','2013-02-22 09:25:00','2012-02-26 09:25:00','Flat Rate subscription 2'),
(52,9,5,NULL,'2010-09-23 09:25:00','2013-01-09 09:25:00','2012-01-13 09:25:00','Flat Rate subscription 3'),
## 3x one time fee
(53,8,5,NULL,'2011-02-25 09:25:00','2013-09-17 09:25:00','2012-09-21 09:25:00','One Time Fee subscription'),
(54,8,5,NULL,'2011-03-25 09:28:08','2013-02-22 09:25:00','2012-02-26 09:25:00','One Time Fee subscription 2'),
(55,8,5,NULL,'2010-09-23 09:25:00','2013-01-09 09:25:00','2012-01-13 09:25:00','One Time Fee subscription 3'),
# reseller subscriptionai
## 3x periodic
(56,10,3,NULL,'2010-03-23 09:25:00','2013-02-25 09:25:00','2012-02-02 09:25:00','Periodic fee subscription'),
(57,10,3,NULL,'2010-09-22 09:25:00','2013-12-08 09:25:00','2012-12-12 09:25:00','Periodic fee subscription 2'),
(58,10,3,NULL,'2011-04-24 09:25:00','2013-04-24 09:25:00','2012-04-01 09:25:00','Periodic fee subscription 3'),
## 3x flat rate
(59,5,3,NULL,'2011-02-25 09:25:00','2013-09-17 09:25:00','2012-09-21 09:25:00','Flat Rate subscription'),
(60,5,3,NULL,'2011-03-25 09:28:08','2013-02-22 09:25:00','2012-02-26 09:25:00','Flat Rate subscription 2'),
(61,5,3,NULL,'2010-09-23 09:25:00','2013-01-09 09:25:00','2012-01-13 09:25:00','Flat Rate subscription 3'),
## 3x one time fee
(62,4,5,NULL,'2011-02-25 09:25:00','2013-09-17 09:25:00','2012-09-21 09:25:00','One Time Fee subscription'),
(63,4,5,NULL,'2011-03-25 09:28:08','2013-02-22 09:25:00','2012-02-26 09:25:00','One Time Fee subscription 2'),
(64,4,5,NULL,'2010-09-23 09:25:00','2013-01-09 09:25:00','2012-01-13 09:25:00','One Time Fee subscription 3');
