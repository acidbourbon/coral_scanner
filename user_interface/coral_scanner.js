
var timer;

// var clientId = Math.random();


var scan_meta;
var coral_scanner_settings;
var pmt_ro_settings;
var spectrum;










$(document).ready(function(){

  
  timer = $.timer(function() {
    get_scan_status()
  });
  
  
  
  $(".has_settings_form").submit(function( event ){
      var url = $(this).attr("action");
      event.preventDefault();
      $.ajax({
          url: url,
          type: 'post',
          dataType: 'text',
          data: $(this).serialize(),
          success: function(data) {
            alert(data);
          }
      });
  });
  
  
  $("#scan_pattern_container").bind('isVisible',function(){
    get_pattern_svg();
  });
  
  
  unfolds($("#show_main_controls"),$("#main_controls_container"));
  unfolds($("#show_pmt_ro_settings"),$("#pmt_ro_settings_container"));
  unfolds($("#show_table_control_settings"),$("#table_control_settings_container"));
  unfolds($("#show_pmt_spectrum"),$("#pmt_spectrum_container"));
  unfolds($("#show_coral_scanner_settings"),$("#coral_scanner_settings_container"));
  unfolds($("#show_scan_pattern"),$("#scan_pattern_container"));
  unfolds($("#show_report_settings"),$("#report_settings_container"));
  
  
  

  
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
  $("#button_program_padiwa").click(function(){
    apply_device_settings();
  });
  $("#button_plot_spectrum").click(function(){
    spectrum = get_spectrum_JSON();
    plot_choices();
    plot_spectrum();
  });
  $("#button_clear_spectrum").click(function(){
    clear_spectrum();
  });
  $("#button_delete_selected").click(function(){
    spectrum_delete();
  });
  $("#button_record_spectrum").click(function(){
    record_spectrum();
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
  
  $("#button_clearlog").click(function(){
    clear_log();
  });
  
  $('#checkbox_log_spectrum').change(function(){
//     alert($(this).prop('checked'));
    plot_spectrum();
  });
  $('#checkbox_diff_spectrum').change(function(){
//     alert($(this).prop('checked'));
    plot_spectrum();
  });
  
  $( "#progressbar" ).progressbar({
    value: 1000
  });
  
  get_coral_scanner_settings();
  get_pmt_ro_settings();
  
  spectrum = get_spectrum_JSON();
  plot_choices();
  plot_spectrum();
  
  get_scan_meta();
//   get_scan_svg();
  
  set_clear_timer();
//   make_flot();
  
});



function make_flot(){
  
  var d1 = [];
                for (var i = 0; i < 14; i += 0.5) {
                        d1.push([i, Math.sin(i)]);
                }

                var d2 = [[0, 3], [4, 8], [8, 5], [9, 13]];

                var d3 = [];
                for (var i = 0; i < 14; i += 0.5) {
                        d3.push([i, Math.cos(i)]);
                }

                var d4 = [];
                for (var i = 0; i < 14; i += 0.1) {
                        d4.push([i, Math.sqrt(i * 10)]);
                }

                var d5 = [];
                for (var i = 0; i < 14; i += 0.5) {
                        d5.push([i, Math.sqrt(i)]);
                }

                var d6 = [];
                for (var i = 0; i < 14; i += 0.5 + Math.random()) {
                        d6.push([i, Math.sqrt(2*i + Math.sin(i) + 5)]);
                }

                $.plot("#spectrum_plot_container", [{
                        data: d1,
                        lines: { show: true, fill: true }
                }, {
                        data: d2,
                        bars: { show: true }
                }, {
                        data: d3,
                        points: { show: true }
                }, {
                        data: d4,
                        lines: { show: true }
                }, {
                        data: d5,
                        lines: { show: true },
                        points: { show: true }
                }, {
                        data: d6,
                        lines: { show: true, steps: true }
                }]);
  
  
}

function plot_choices() {
    // insert checkboxes 
    var choiceContainer = $("#choices");
    choiceContainer.html("");
    $.each(spectrum, function(key, val) {
      choiceContainer.append("<br/><input type='checkbox' name='" + key +
        "' checked='checked' id='id" + key + "'></input>" +
        "<label for='id" + key + "'>"
        + key + "</label>");
    });
    choiceContainer.find("input").click(function(){plot_spectrum();});
    
    
    // select all or none with one master checkbox
    choiceContainer.append("<br><hr><input type='checkbox' id='checkbox_allnone' checked='true'></input>"
    + "<label for='checkbox_allnone'>select all/none</label>");
    $('#checkbox_allnone').click(function(){
      var master = $(this);
      choiceContainer.find("input").each(function(){
        $(this).prop( "checked", master.prop("checked") );
      });
      plot_spectrum();
    });
  
  
}


function plot_spectrum() {
  var data = [];
//   for (x in spectrum){
//     data.push(
//       {
//         data: spectrum[x].data,
//         bars: { show: true ,  barWidth: 0.8*parseFloat(spectrum[x].meta.bin_width), align: "center" },
//         label: x
//       }
//     );
//   }
  
  $('#choices').find("input:checked").each(function () {
        var key = $(this).attr("name");
        
        
        if (key && spectrum[key]) {
//           data.push(datasets[key]);
          var dataset = spectrum[key].data;
          
          if($('#checkbox_diff_spectrum').prop('checked') == true){
            var diff = [];
            
            for (var i = 0; i < dataset.length; i++) {
              if(i > 0) {
                diff.push([(dataset[i][0]+dataset[i-1][0])/2, dataset[i][1]-dataset[i-1][1] ]);
              }
            }
            dataset = diff;
          }
          data.push(
            {
              data: dataset,
              bars: { show: true ,  barWidth: 0.8*parseFloat(spectrum[key].meta.bin_width), align: "center" },
              label: key
            }
          );
        }
      });
  
  var options = {
    selection: {
      mode: "xy"
    },
    xaxis : {
      autoscaleMargin: .1
    },
    legend : {
      position : "nw"
    }
  };
  
  
  if($('#checkbox_log_spectrum').prop('checked')){
      $.extend(options,{
        yaxis: {
          min: 0.1,
          ticks: [0.001,0.01,0.1,1,10,100,1000,10000,100000,1e6],
          transform: function(v) { return v == 0 ? Math.log(0.00001) : Math.log(v) },
//           transform: function (v) { return Math.log(v+0.0001); },
          inverseTransform: function (v) { return Math.exp(v); }
        }
      });
  }

  
  flot_w_selectZoom('#spectrum_plot_container', data, options);
  
}





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

function get_pattern_svg(){
  $.ajax({
        url:       "table_control.pl",
        cache:     false,
        async:     true,
        dataType:  "text",
        data:      {
          sub        : "scan_pattern_to_svg"
        },
        success:   function(answer) {
          $("#pattern_svg_container").html(answer);
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


// function get_scan_status_report(){
//   $.ajax({
//         url:       "coral_scanner.pl",
//         cache:     false,
//         async:     true,
//         dataType:  "text",
//         data:      {
//           sub        : "scan_status",
//           report     : "true"
//         },
//         success:   function(answer) {
//           $("#scan_status_container").html("<pre>"+answer+"</pre>");
//         }
//      });
// }

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
            max: answer.number_points,
            value: answer.points_scanned
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

function apply_device_settings(){
  $.ajax({
        url:       "pmt_ro.pl",
        cache:     false,
        async:     false,
        dataType:  "text",
        data:      {
          sub        : "apply_device_settings"
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


function get_spectrum_JSON(){
  var return_obj;
  $.ajax({
        url:       "pmt_ro.pl",
        cache:     false,
        async:     false,
        dataType:  "json",
        data:      {
            sub      : "spectrum_JSON",
        },
        success:   function(answer) {
          return_obj = answer;
        }
     });
  return return_obj;
}

function clear_spectrum(){
  $.ajax({
        url:       "pmt_ro.pl",
        cache:     false,
        async:     false,
        dataType:  "text",
        data:      {
            sub      : "clear_spectrum",
        },
        success:   function(answer) {
          alert(answer);
        }
     });
}

function clear_log(){
  $.ajax({
        url:       "coral_scanner.pl",
        cache:     false,
        async:     false,
        dataType:  "text",
        data:      {
            sub      : "clear_log",
        },
        success:   function(answer) {
          alert(answer);
        }
     });
}

function record_spectrum(){
  $.ajax({
        url:       "coral_scanner.pl",
        cache:     false,
        async:     true,
        dataType:  "text",
        data:      {
            sub      : "record_spectrum",
            name     : $('#text_spectrum_name').val()
        },
        success:   function(answer) {
          spectrum = get_spectrum_JSON();
          plot_spectrum();
        }
     });
}

function spectrum_delete(){
  var runs = $('#choices input[type=checkbox]:checked').map(function() {
    return $(this).attr("name");
  }).get().join(',');
  $.ajax({
        url:       "pmt_ro.pl",
        cache:     false,
        async:     true,
        dataType:  "text",
        data:      {
            sub      : "spectrum_delete",
            runs     : runs
        },
        success:   function(answer) {
          spectrum = get_spectrum_JSON();
          plot_choices();
          plot_spectrum();
        }
     });
}