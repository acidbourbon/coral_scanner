
var timer;

// var clientId = Math.random();


var scan_meta;
var coral_scanner_settings;
var pmt_ro_settings;











$(document).ready(function(){

  
  timer = $.timer(function() {
    get_scan_status()
  });
  
  unfolds($("#show_main_controls"),$("#main_controls_container"));
  unfolds($("#show_pmt_ro_settings"),$("#pmt_ro_settings_container"));
  unfolds($("#show_table_control_settings"),$("#table_control_settings_container"));
  
  $("#button_home").click(function(){
    home();
  });
  $("#button_start_scan").click(function(){
    start_scan();
  });
  $("#button_stop_scan").click(function(){
    stop_scan();
  });
  $("#button_test").click(function(){
  });
  $("#button_replot").click(function(){
    store_slider_settings();
    get_scan_svg();
  });
  
  $("#button_count").click(function(){
     $('#text_count_out').val("");
     $.ajax({
        url:       "pmt_ro.pl",
        cache:     false,
        async:     false,
        dataType:  "text",
        data:      {
            sub      : "count",
            channel  : "signal",
            delay    : $('#text_count').val()
        },
        success:   function(answer) {
          $('#text_count_out').val(answer);
        }
     });
  });
  
  $("#button_thresh").click(function(){
//     save_settings("pmt_ro.pl",{
//       signal_thresh : $('#text_thresh').val()
//     });
    signal_thresh();
  });
  
  
  $( "#progressbar" ).progressbar({
    value: 100
  });
  
  get_coral_scanner_settings();
  get_pmt_ro_settings();
  

  
  get_scan_meta();
//   get_scan_svg();
  
  set_clear_timer();
  
});






function set_clear_timer(){
     timer.set({time:2000,autostart: true});
}

function stop_timer(){
     timer.stop();
}

function store_slider_settings(){
  save_settings("coral_scanner.pl",{
    plot_lower_limit : $( "#slider-range" ).slider( "values", 0 ),
    plot_upper_limit : $( "#slider-range" ).slider( "values", 1 )
  });
}

function get_coral_scanner_settings(){
  coral_scanner_settings = load_settings("coral_scanner.pl");
  init_slider();
}
function get_pmt_ro_settings(){
  pmt_ro_settings = load_settings("pmt_ro.pl");
  $('#text_thresh').val(pmt_ro_settings.signal_thresh);
}

function init_slider(){
  $( "#slider-range" ).slider({
    range: true,
    min: 0,
    max: coral_scanner_settings.approx_upper_rate,
    values: [ coral_scanner_settings.plot_lower_limit, coral_scanner_settings.plot_upper_limit  ],
    slide: function( event, ui ) {
    $( "#amount" ).html( ui.values[ 0 ] + " - " + ui.values[ 1 ] );
    }
  });
  $( "#amount" ).html( $( "#slider-range" ).slider( "values", 0 ) +
    " - " + $( "#slider-range" ).slider( "values", 1 ) );
}

function get_scan_svg(){
  $.ajax({
        url:       "coral_scanner.pl",
        cache:     false,
        async:     true,
        dataType:  "text",
        data:      {
          sub        : "scan_to_svg"
        },
        success:   function(answer) {
          $("#scan_container").html(answer);
        }
     });
}

function get_scan_meta(){
  $.ajax({
        url:       "coral_scanner.pl",
        cache:     false,
        async:     true,
        dataType:  "json",
        data:      {
          sub        : "scan_meta"
        },
        success:   function(answer) {
          scan_meta = answer;
        }
     });
}


function get_scan_status_report(){
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

function get_scan_status(){
  $.ajax({
        url:       "coral_scanner.pl",
        cache:     false,
        async:     true,
        dataType:  "json",
        data:      {
          sub      : "scan_status",
          json     : "true"
        },
        success:   function(answer) {
          for (id in answer){
            $('#'+id).html(answer[id]);
          }
          $( "#progressbar" ).progressbar({
            max: answer.rows,
            value: answer.current_row
          });
        }
     });
}

function home(){
  $.ajax({
        url:       "coral_scanner.pl",
        cache:     false,
        async:     true,
        dataType:  "text",
        data:      {
          sub        : "home"
        },
        success:   function(answer) {
        }
     });
}

function signal_thresh(){
  $.ajax({
        url:       "pmt_ro.pl",
        cache:     false,
        async:     false,
        dataType:  "text",
        data:      {
          sub        : "signal_thresh",
          value      : $('#text_thresh').val()
        },
        success:   function(answer) {
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

function save_settings(url,settings){
  $.ajax({
        url:       url,
        cache:     false,
        async:     false,
        dataType:  "text",
        data:      $.extend({
            sub      : "save_settings"
        }, settings),
        success:   function(answer) {
        }
     });
}

function load_settings(url){
  var return_obj;
  $.ajax({
        url:       url,
        cache:     false,
        async:     false,
        dataType:  "json",
        data:      {
            sub      : "load_settings",
            json     : "true"
        },
        success:   function(answer) {
          return_obj = answer;
        }
     });
  return return_obj;
}