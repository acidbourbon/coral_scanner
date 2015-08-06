

var scan;
var contrast_min;
var contrast_max;

var selection_color = [180,180,255];


var my_subset = {};

var pixel_size = 10;

$(document).ready(function(){
  scan = get_scan_json();
  $('#pout').html(scan.meta.scan_name);
  
  
  contrast_min = 0;
  contrast_max = scan.meta.unshadowed_counts/scan.meta.unshadowed_count_time*scan.meta.time_per_pixel;
  
  draw_scan();
//   alert(false_color(30000,255,100,0));
  
  
  $( "#slider-range" ).slider({
    range: true,
    min: contrast_min,
    max: contrast_max,
    values: [ contrast_min, contrast_max ],
    change: function( event, ui ) {
//     $( "#amount" ).html( ui.values[ 0 ] + " - " + ui.values[ 1 ] );
      contrast_min = ui.values[ 0 ];
      contrast_max = ui.values[ 1 ];
      draw_scan();
    }
  });
  
  init_selection();
  
  
//   $( "#amount" ).html( $( "#slider-range" ).slider( "values", 0 ) +
//     " - " + $( "#slider-range" ).slider( "values", 1 ) );

  $("#btn_clear_selection").click(function(){
    my_subset = {};
    draw_scan();
    calculate();
  });
  
  
  $("#btn_append_data").click(function(){
    $("#text_field").val(
      $("#text_field").val()+"\n"+
      $("#text_label").val()+"\t"+
      $("#text_avg").val()+"\t"+
      $("#text_stdev").val()+"\t"
    );
    
  });
  
});


function calculate(){
  var sel_data = [];
  
  for (x in my_subset) {
    var pos = x.split("-");
    var i = pos[0];
    var j = pos[1];
    sel_data.push(scan.data[i][j]);
  }
  $('#text_avg').val(mean(sel_data).toFixed(2));
  $('#text_stdev').val(stdev(sel_data).toFixed(2));
  
  
}


function selection_finished(x1,x2,y1,y2) {
//   alert(x1.toString()+" "+x2.toString()+" "+y1.toString()+" "+y2.toString()+" ");
  px1 = Math.floor(x1/pixel_size);
  px2 = Math.floor(x2/pixel_size);
  py1 = Math.floor(y1/pixel_size);
  py2 = Math.floor(y2/pixel_size);
//   alert(px1.toString()+" "+px2.toString()+" "+py1.toString()+" "+py2.toString()+" ");
  
  var temp;
  if (px1 > px2) {
    temp = px1;
    px1 = px2;
    px2 = temp;
  }
  if (py1 > py2) {
    temp = py1;
    py1 = py2;
    py2 = temp;
  }
  
  
  for (var j = py1; j <= py2; j++){
    for (var i = px1; i <= px2; i++){
      my_subset[i.toString()+"-"+j.toString()] = 1;
    }
  }
  draw_scan();
  calculate();
}



function draw_scan() {
  var c = document.getElementById("myCanvas");
  var ctx = c.getContext("2d");
  
  
  for (var i = 0; i < scan.meta.rows; i++) {
    for (var j = 0; j < scan.meta.cols; j++) {
      var value = scan.data[i][j];
      if (my_subset[i.toString()+"-"+j.toString()] == 1) {
        ctx.fillStyle = false_color(value,selection_color[0],selection_color[1],selection_color[2]);
      } else {
        ctx.fillStyle = false_color(value,255,255,255);
      }
      ctx.fillRect(i*pixel_size, j*pixel_size, pixel_size, pixel_size);
      
    }
      //Do something
  }
  
  
  
}

function false_color(value,r,g,b) {
  var ratio = (value - contrast_min)/(contrast_max-contrast_min);
  ratio = Math.max(ratio,0);
  ratio = Math.min(ratio,1);
  var ro = Math.round(ratio*r).toString();
  var go = Math.round(ratio*g).toString();
  var bo = Math.round(ratio*b).toString();
  return "rgb("+ro+","+go+","+bo+")";
}


function get_scan_json(){
  var return_obj;
  $.ajax({
        url:       "coral_scanner.pl",
        cache:     false,
        async:     false,
        dataType:  "json",
        data:      {
            sub      : "last_scan",
            json     : true
        },
        success:   function(answer) {
          return_obj = answer;
        }
     });
  return return_obj;
}

















