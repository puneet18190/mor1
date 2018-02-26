var mor_functions = {
    "showAJAXLoader":function () { // Shows spinner
        $j("#spinner").show();
    },
    "hideAJAXLoader":function () { // Hides spinner
        $j("#spinner").hide();
    },
    "log":function (msg) { // Writes message to firefox/chrome console.
        if (typeof(console) !== 'undefined' && console != null) {
            console.log(msg);
        }
    },
    "populateSelect":function (path, target, defaul) {
        var options = [];
        $j.ajax({
            url:path,
            complete:mor_functions["hideAJAXLoader"],
            beforeSend:function () {
                target.unbind("click");
                mor_functions["showAJAXLoader"]();

            },
            success:function (data, textStatus, XMLHttpRequest) {
                $j.each(data, function (key, value) {
                    var obj = "<option value='" + value[0] + "'"
                    if (defaul == value[0]) {
                        obj += "selected='selected'";
                    }
                    obj += ">" + value[1] + "</option>"
                    options.push(obj);
                });

                target.html(options.join(""));
            },
            error:function (data, textStatus, XMLHttpRequest) {
            },
            dataType:"json"
        });
    }
}

//alias to function
function log(msg) {
    mor_functions["log"](msg);
}

function show_hide_menus() {
    var value = $j.cookie("hide_menus");
    if (value == "hide") {
        $j.cookie("hide_menus", "show", {
            path:'/'
        });
    } else {
        $j.cookie("hide_menus", "hide", {
            path:'/'
        });
    }
    ;
    read_show_hide_menus();
}

function show_hide_menus2(value) {
    if (value == "0") {
        $j.cookie("hide_menus", "show", {
            path:'/'
        });
    } else {
        $j.cookie("hide_menus", "hide", {
            path:'/'
        });
    }
    ;
    read_show_hide_menus();
}

function read_show_hide_menus() {
    var value = $j.cookie("hide_menus");
    $j("#slide_1").attr("style", "width: 8px");
    if (value == "hide") {
        $j("#slide_1").attr("id", "slide");
        $j(".application_side_expand").show();
        $j(".application_side_contract").hide();

        $j("#page_header").hide();
        $j("#left_menu_spacer").hide();
        $j(".header_spacer").hide();
        $j("#slide").hover(
            function () {
                $j(this).animate({ width:"220px", display:"table-cell"}, 0);
            },
            function () {
                $j(this).animate({ width:"8px" }, 0);
            }
        );
    } else {
        $j("#slide").attr("id", "slide_1");
        $j(".application_side_expand").hide();
        $j(".application_side_contract").show();
        $j("#slide_1").attr("style", "width: 170px");

        $j(".left_menu").show();
        $j("#page_header").show();
        $j("#left_menu_spacer").show();
        $j(".header_spacer").show();
        $j("#slide_1").hover(
            function () {
                $j(this).attr("width", "170px");
                $j(this).attr("style", "display: table-cell");
            },
            function () {
                $j(this).removeAttr("style");
                $j(this).attr("style", "width: 170px");
            }
        );
    }
    ;
}

function httpGet(theUrl){
    var xmlHttp = null;

    xmlHttp = new XMLHttpRequest();
    xmlHttp.open( "GET", theUrl, false );
    xmlHttp.send( null );
    return xmlHttp.responseText;
}

/* Method which appends 3 loading dots to the end of the text
  PARAMS:
    containerId - Html id value of container to which dots should be added
  RETURN VALUE:
    dotsInterval - creted Interval Handle
  Usage: call this function, passing containerId,
    When dots should stop refreshing use clearInterval( yourIntervalHandle )
 */
function appendLoadingDots(containerId){
    dotCount = 0;
    dotsCotnainer = $j("#"+containerId);
    containerText = dotsCotnainer.html();
    dotsInterval = setInterval(function(){



        if (dotCount >= 3){
            console.log('reseting...');
            dotsCotnainer.html(containerText);
            dotCount = 0;
        }else{
            dotCount = dotCount +1;
            dotsCotnainer.append('.');
            console.log(dotCount);
        }
    }, 500);
    return dotsInterval;
}