UPDATE rates JOIN destinations ON destinations.id = rates.destination_id SET rates.prefix = destinations.prefix, rates.name = destinations.name WHERE rates.name = '' AND rates.prefix = '';
