# Set paypal currency to EUR (Admin)
UPDATE `conflines` SET value='EUR' WHERE name = 'Paypal_Default_Currency' AND owner_id = 0;
