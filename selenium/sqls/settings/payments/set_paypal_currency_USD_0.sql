# Set paypal currency to USD (Admin)
UPDATE `conflines` SET value='USD' WHERE name = 'Paypal_Default_Currency' AND owner_id = 0;
