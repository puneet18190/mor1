DELETE from `taxes`;
INSERT INTO `taxes` (`id`, `tax1_enabled`, `tax2_enabled`, `tax3_enabled`, `tax4_enabled`, `tax1_name`, `tax2_name`, `tax3_name`, `tax4_name`, `total_tax_name`, `tax1_value`, `tax2_value`, `tax3_value`, `tax4_value`, `compound_tax`) VALUES
(2, 0, 0, 0, 0, 'First-tax', 'Second-tax', 'Third-tax', 'Fourth-tax', 'Total_tax', 10.000000000000000, 10.000000000000000, 20.000000000000000, 30.000000000000000, 1),
(3, 0, 0, 0, 0, 'First-tax', 'Second-tax', 'Third-tax', 'Fourth-tax', 'Total_tax', 10.000000000000000, 10.000000000000000, 20.000000000000000, 30.000000000000000, 1),
(4, 0, 0, 0, 0, 'First-tax', 'Second-tax', 'Third-tax', 'Fourth-tax', 'Total_tax', 10.000000000000000, 10.000000000000000, 20.000000000000000, 30.000000000000000, 1),
(5, 0, 0, 0, 0, 'First-tax', 'Second-tax', 'Third-tax', 'Fourth-tax', 'Total_tax', 10.000000000000000, 10.000000000000000, 20.000000000000000, 30.000000000000000, 1);

update `users` set tax_id=2 where id=0;
update `users` set tax_id=3 where id=2;
update `users` set tax_id=4 where id=3;
update `users` set tax_id=5 where id=4;
update `users` set tax_id=3 where id=5;
