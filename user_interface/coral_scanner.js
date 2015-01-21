
var timer;

// var clientId = Math.random();















$(document).ready(function(){

  
  timer = $.timer(function() {
    get_scan_status()
  });
  
  unfolds($("#show_main_controls"),$("#main_controls_container"));
  unfolds($("#show_pmt_ro_settings"),$("#pmt_ro_settings_container"));
  unfolds($("#show_table_control_settings"),$("#table_control_settings_container"));
  
  $("#button_start_scan").click(function(){
    start_scan();
  });
  $("#button_stop_scan").click(function(){
    stop_scan();
  });
  
  
  set_clear_timer();
  
});






function set_clear_timer(){
     timer.set({time:2000,autostart: true});
}

function stop_timer(){
     timer.stop();
}


function get_scan_status(){
  $.ajax({
        url:       "coral_scanner.pl",
        cache:     false,
        async:     true,
        dataType:  "text",
        data:      {
          sub        : "scan_status",
          report     : "true"
        },
        success:   function(answer) {
          $("#scan_status_container").html("<pre>"+answer+"</pre>");
        }
     });
}


function start_scan(){
  $.ajax({
        url:       "coral_scanner.pl",
        cache:     false,
        async:     true,
        dataType:  "text",
        data:      {
          sub        : "start_scan"
        },
        success:   function(answer) {
        }
     });
}

function stop_scan(){
  $.ajax({
        url:       "coral_scanner.pl",
        cache:     false,
        async:     true,
        dataType:  "text",
        data:      {
          sub        : "stop_scan"
        },
        success:   function(answer) {
        }
     });
}