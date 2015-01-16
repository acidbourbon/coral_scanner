
var timer;

var clientId = Math.random();















$(document).ready(function(){

  
  timer = $.timer(function() {
  });
  
  unfolds($("#show_main_controls"),$("#main_controls_container"));
  unfolds($("#show_pmt_ro_settings"),$("#pmt_ro_settings_container"));
  unfolds($("#show_table_control_settings"),$("#table_control_settings_container"));
  
});


function plot(){
  $.ajax({
        url:       "index.pl",
        cache:     false,
        async:     true,
        dataType:  "text",
        data:      {
          action     : "plot",
          tty        : shared.tty,
          clientId   : clientId
        },
        success:   function(result) {
          $("#plotContainer").html(result);
        }
     });
}



function set_clear_timer(){
     timer.set({time:1000,autostart: true});
}

function stop_timer(){
     timer.stop();
}





