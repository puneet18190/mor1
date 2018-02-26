
$j = jQuery.noConflict();
var tariffId;
var lastMatch;

$j(document).ready(function() {
	initUpdateRates();

	if($j('#autocomplete').val().length > 0) {
	  onDestinationGroupSelect();
	}
});

function initUpdateRates() {
	detailsForm = $j('.details-form');
	destinationsUrl = detailsForm.attr('destinations-url');
	tariffId = detailsForm.attr('tariff-id');

	//Disables submit on enter
	detailsForm.keypress(function(event) {
	  return event.keyCode != 13;
	});

	//Initializes the autocomplete field
    $j("#autocomplete").autocomplete({
        source: function (request, response) {
            if (request.term.length > 2) {
				updateDestinations();
            } else {
                renderDestinationRatesTable('');
                response('');
            }
        },
        select: function( event, ui ) {
            $j("#autocomplete").val( ui.item.label );
		  onDestinationGroupSelect();
		  return false;
		},
        close: function (event, ui) {
            onDestinationGroupSelect();
        },
		focus: function (event, ui) {
            event.preventDefault();
            $j("#autocomplete").val(ui.item.label);
            onDestinationGroupSelect();
        },
		minLength: 2
	});

    $j("#autocomplete").keyup(function() {
        if ( $j('#autocomplete').val().length < 3) {
            renderDestinationRatesTable([]);
        }
    }
    );
}

function onDestinationGroupSelect() {
	updateDestinations();
}

function updateDestinations() {
    $j.ajax({
		url: destinationsUrl,
		data: {tariff_id: tariffId, mask: $j('#autocomplete').val()},
		async: true,
		dataType: 'json',
		success: function(response) {
			renderDestinationRatesTable(response);
		}
	});
}

function renderDestinationRatesTable(destinations) {
    if (destinations.length == 0) {
        $j('#destination-group-field').val('');
        destinations = [{name: 'No Destinations', rate: ''}];
        $j('#destination-count').text('');
    } else if (destinations.length > 1000) {
    	destinations = [{name: 'Too many Destinations to show', rate: ''}];
        $j('#destination-count').text('');
    } else {
    	$j('#destination-count').text('(' + destinations.length + ')');
    }
	table = $j('#destinations-table');
	table.html('');
    var each_index = 0;

   	$j.each(destinations, function() {
        each_index += 1;
		row = $j('<tr/>').attr('row', each_index);
		row.append($j('<td/>').attr('align', 'left').attr('name', each_index).text(this.name));
		row.append($j('<td/>').attr('align', 'right').attr('rate', each_index).text(this.rate));
		table.append(row);
	});

}