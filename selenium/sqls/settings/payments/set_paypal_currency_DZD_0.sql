# Set paypal currency to DZD (Admin)
UPDATE `conflines` SET value='DZD' WHERE name = 'Paypal_Default_Currency' AND owner_id = 0;
