/*
 * Visual data functions for jqxGrid table
 */

$j = jQuery.noConflict();

function nice_billsec(billsec, time_format) {
    var nice_time;
    var hours, minutes, seconds;

    if (time_format == '%M:%S') {
        minutes = ~~(billsec / 60);
        seconds = billsec % 60;
        minutes = (minutes < 10) ? ('0' + minutes) : minutes;
        nice_time = minutes + ':' + ('0' + seconds).slice(-2);
    } else {
        hours = ~~(billsec / 3600);
        minutes = ~~((billsec % 3600) / 60);
        seconds = billsec % 60;
        hours = (hours < 10) ? ('0' + hours) : hours;
        nice_time = hours + ':' + ('0' + minutes).slice(-2) + ':' + ('0' + seconds).slice(-2);
    }

    return nice_time
}

function render_flag(flag_name, web_dir) {
    var flag_icon;

    if (flag_name != '') {
        flag_icon = '&nbsp;<img alt="' + flag_name + '" src="' + web_dir + '/images/flags/' + flag_name + '.jpg" style="border-style:none" title="' + flag_name.toUpperCase() + '">';
    } else {
        flag_icon = '';
    }

    return flag_icon
}

function render_device_pic(device_pic_name, web_dir) {
    var device_icon;

    if (device_pic_name != '') {
        device_icon = '&nbsp;<img alt="' + device_pic_name + '" src="' + web_dir + '/images/icons/' + device_pic_name + '.png" style="border-style:none" title="' + device_pic_name.toUpperCase() + '">';
    } else {
        flag_icon = '';
    }

    return device_icon
}

function call_debug_info_tooltip(call_id, web_dir, data_cache) {
    var debug_info_icon;

    debug_info_icon = '<img border="0" onmouseout="UnTip()" src="' + web_dir + '/images/icons/cog.png" onmouseover="Tip(get_call_debug_info(' + call_id + ',\'' + web_dir + '\',data_cache));">';

    return debug_info_icon;
}

function get_call_debug_info(call_id, web_dir, data_cache) {
    var tooltip_data, debug_info;

    if (call_id in data_cache['debuginfo']) {
        debug_info = data_cache['debuginfo'][call_id]
    } else {
        jQuery.ajax({
            async: false,
            type: 'GET',
            url: web_dir + '/stats/retrieve_call_debug_info',
            data: { id: call_id },
            success: function (response) { debug_info = response; }
        });
        data_cache['debuginfo'][call_id] = debug_info;
    }

    tooltip_data = 'PeerIP: ' + debug_info['peerip'] +
        '<br/>RecvIP: ' + debug_info['recvip'] +
        '<br/>SipFrom: ' + debug_info['sipfrom'] +
        '<br/>URI: ' + debug_info['uri'] +
        '<br/>UserAgent: ' + debug_info['useragent'] +
        '<br/>PeerName: ' + debug_info['peername'] +
        '<br/>T38Passthrough: ' + debug_info['t38passthrough'] +
        '<br/>';

    return tooltip_data;
}

function fix_column_width(jqxgrid_name) {
    var loss_making_calls_grid = jQuery("#" + jqxgrid_name);

    var grid_columns = jQuery.grep(loss_making_calls_grid.jqxGrid('columns').records, function(column) { return column.hidden == false });
    var used_width = 0, table_width = parseInt(document.getElementById("content" + jqxgrid_name).style.width);

    jQuery.each(
        grid_columns,
        function(index, column) {
            loss_making_calls_grid.jqxGrid('autoresizecolumn', column.datafield, 'all');
            used_width += column.width;
        }
    );

    var spare_width = 0, fixed_width = 0, fixed_width_last_column = 0;
    var column_count = grid_columns.length;
    if (used_width < table_width) {
        spare_width = table_width - used_width;
        fixed_width = parseInt(spare_width / column_count);
        fixed_width_last_column = spare_width % column_count;

        jQuery.each(
            grid_columns,
            function(index, column) {
                var set_width = column.width;

                if (index == (column_count - 1)) {
                    set_width += fixed_width + fixed_width_last_column;
                } else {
                    set_width += fixed_width;
                }

                loss_making_calls_grid.jqxGrid('setcolumnproperty', column.datafield, 'width', set_width);
            }
        );
    }
}

function nice_user_link(nice_user_and_id, web_dir) {
        var user_id_arr = nice_user_and_id.split(" ");
        var id = user_id_arr.pop();
        var nice_name = user_id_arr.join(" ");
        return '<a href="'+ web_dir + '/users/edit/' + id + '">' + nice_name + '</a></div>';
}
