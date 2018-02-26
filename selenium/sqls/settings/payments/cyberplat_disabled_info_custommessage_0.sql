# Set cyberplat disabled info to "custom message" for admin
UPDATE `conflines` SET value2='custom message' WHERE name = 'Cyberplat_Disabled_Info' AND owner_id = 0;
