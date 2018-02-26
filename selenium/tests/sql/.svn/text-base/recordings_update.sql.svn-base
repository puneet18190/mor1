UPDATE recordings SET uniqueid = CONCAT(uniqueid, '_', call_id);
UPDATE calls JOIN recordings ON recordings.call_id = calls.id SET calls.uniqueid = recordings.uniqueid;