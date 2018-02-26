# Enable cyberplat for admin
UPDATE `conflines` SET value=1 WHERE name = 'Cyberplat_Enabled' AND owner_id = 0;
