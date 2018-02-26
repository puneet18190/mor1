#sito sql reikia test db sutvarkyti, kad invoisų scriptai teisingai veiktų. Negali būti tokių atvejų, kad skirtingi useriai turi vienodus taxus ar neturi jų visai. Bet keičiant testinės db faile, lūžta daug testų keistai ir reikėjo sugrąžinti pakeitimus, kad būtų laiku baigtas sprintas. Gal ateityje bandyti dar kartą. 

INSERT INTO `taxes` (`id`, `tax1_enabled`, `tax2_enabled`, `tax3_enabled`, `tax4_enabled`, `tax1_name`, `tax2_name`, `tax3_name`, `tax4_name`, `total_tax_name`, `tax1_value`, `tax2_value`, `tax3_value`, `tax4_value`, `compound_tax`) VALUES
(2, 0, 0, 0, 0, '', '', '', '', '', 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 1),
(3, 0, 0, 0, 0, '', '', '', '', '', 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 1),
(4, 0, 0, 0, 0, '', '', '', '', '', 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 1),
(5, 0, 0, 0, 0, '', '', '', '', '', 0.000000000000000, 0.000000000000000, 0.000000000000000, 0.000000000000000, 1);

UPDATE `mor`.`users` SET `tax_id` = '2' WHERE `users`.`id` =2 LIMIT 1 ;
UPDATE `mor`.`users` SET `tax_id` = '3' WHERE `users`.`id` =3 LIMIT 1 ;
UPDATE `mor`.`users` SET `tax_id` = '4' WHERE `users`.`id` =4 LIMIT 1 ;
UPDATE `mor`.`users` SET `tax_id` = '5' WHERE `users`.`id` =5 LIMIT 1 ;
