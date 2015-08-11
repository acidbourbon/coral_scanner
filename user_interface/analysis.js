

var scan;
var contrast_min;
var contrast_max;

var canvas_offset = 0;

var selection_color = [220,220,255,0,0,196];


var my_subset = {};

var pixel_size = 10;

$(document).ready(function(){
//   $('#pout').html(scan.meta.scan_name);
  
  $('#files').val("");
  
  $('#files').change(function(){
    readBlob();
  });
  
  $('#btn_last_scan').click(function(){
    scan = get_scan_json();
    init_widgets();
  });
  
  $("#btn_clear_selection").click(function(){
    clear_selection();
  });
  
  
  $("#btn_append_data").click(function(){
    $("#textarea_notepad").val(
      $("#textarea_notepad").val()+
      $("#text_label").val()+"\t"+
      $("#text_thickness").val()+"\t"+
      $("#text_avg_dnsty").val()+"\t"+
      $("#text_stdev_dnsty").val()+"\t"+
      "\n"
    );
  });
  $("#btn_clear_data").click(function(){
    clear_notepad();
  });
  $('#text_thickness').change(function(){
    calculate();
  });
  $('#text_k0').change(function(){
    calculate();
  });
  
 
  
});



function init_widgets(){
  
  
  pixel_size = scan.meta.step_size*10;
  
  contrast_min = 0;
  contrast_max = scan.meta.unshadowed_counts/scan.meta.unshadowed_count_time*scan.meta.time_per_pixel;
  
  
  for( x in scan.meta){
    $('#'+x).html(scan.meta[x]);
  }
  
//   draw_scan();
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

  
  
  $( "#canvas_slider" ).slider({
    min: 0,
    max: scan.meta.rows*pixel_size-document.getElementById("myCanvas").width,
//     values: [ contrast_min, contrast_max ],
    change: function( event, ui ) {
      canvas_offset = Math.round(ui.value);
      draw_scan();
    }
  });
  
  
  clear_selection();
  clear_notepad();
  
}


function clear_selection(){
  my_subset = {};
  draw_scan();
  calculate();
}

function clear_notepad(){
  $("#textarea_notepad").val("#label\t#thickness\t#density\t#density_stdev\n");
}

function calculate(){
  var sel_data = [];
  
  for (x in my_subset) {
    var pos = x.split("-");
    var i = pos[0];
    var j = pos[1];
    sel_data.push(scan.data[i][j]);
  }
  
  var avg_counts = mean(sel_data);
  var stdev_counts = stdev(sel_data);
  
  var thickness = $('#text_thickness').val()/10;
  var k0 = $('#text_k0').val();
  
  var I = avg_counts/scan.meta.time_per_pixel;
  var I0 = scan.meta.unshadowed_counts/scan.meta.unshadowed_count_time;
  var dI = stdev_counts/scan.meta.time_per_pixel;
  
  var avg_density = density(k0,thickness,I,I0);
  var stdev_density = density_err(k0,thickness,I,I0,dI);
  
  $('#text_avg').val(avg_counts.toFixed(2));
  $('#text_stdev').val(stdev_counts.toFixed(2));
  $('#text_avg_dnsty').val(avg_density.toFixed(2));
  $('#text_stdev_dnsty').val(stdev_density.toFixed(2));
  
  
  
}

function density(k0,d,I,I0) {
  return -1/(k0*d)*Math.log(I/I0);
}
function density_err(k0,d,I,I0,dI) {
  return Math.abs(-1/(k0*d)*1/I*dI);
}


function selection_finished(x1,x2,y1,y2) {
//   alert(x1.toString()+" "+x2.toString()+" "+y1.toString()+" "+y2.toString()+" ");
  px1 = Math.floor((x1+canvas_offset)/pixel_size);
  px2 = Math.floor((x2+canvas_offset)/pixel_size);
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
    if (j < scan.meta.cols){
      for (var i = px1; i <= px2; i++){
        if (i < scan.meta.rows ) {
          my_subset[i.toString()+"-"+j.toString()] = 1;
        }
      }
    }
  }
  draw_scan();
  calculate();
}



function draw_scan() {
  var c = document.getElementById("myCanvas");
  var ctx = c.getContext("2d");
  
  ctx.clearRect(0, 0, c.width, c.height);
  
  
  
  for (var i = 0; i < scan.meta.rows; i++) {
    for (var j = 0; j < scan.meta.cols; j++) {
      var value = scan.data[i][j];
      if (my_subset[i.toString()+"-"+j.toString()] == 1) {
        ctx.fillStyle = false_color(value,
                                    selection_color[0],selection_color[1],selection_color[2],
                                    selection_color[3],selection_color[4],selection_color[5]
                                   );
      } else {
        ctx.fillStyle = false_color(value,255,255,255,0,0,0);
      }
      ctx.fillRect(i*pixel_size - canvas_offset, j*pixel_size, pixel_size, pixel_size);
      
    }
      //Do something
  }
  var ruler_y_offset = 180;
  ctx.fillStyle = "#000000";
  for (var i = 0; i < 300; i+=1) {
    var x = i*10-canvas_offset;
    
    if (i % 5 == 0) {
    
      ctx.beginPath();
      ctx.moveTo(x,ruler_y_offset);
      ctx.lineTo(x,ruler_y_offset + 20);
      ctx.stroke();
      ctx.font = "16px Arial";
      if (i == 0) {
        ctx.fillText("0 mm",x+5,ruler_y_offset+20);
      } else {
        ctx.fillText(i,x+5,ruler_y_offset+20);
      }
    } else {
      ctx.beginPath();
      ctx.moveTo(x,ruler_y_offset);
      ctx.lineTo(x,ruler_y_offset + 4);
      ctx.stroke();
    }
  }
  
  
  
}

function false_color(value,r,g,b,r2,g2,b2) {
  var ratio = (value - contrast_min)/(contrast_max-contrast_min);
  ratio = Math.max(ratio,0);
  ratio = Math.min(ratio,1);
  
  
  var ro = Math.round(ratio*(r-r2)+r2).toString();
  var go = Math.round(ratio*(g-g2)+g2).toString();
  var bo = Math.round(ratio*(b-b2)+b2).toString();
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



function readBlob(opt_startByte, opt_stopByte) {

  var files = document.getElementById('files').files;
  if (!files.length) {
    alert('Please select a file!');
    return;
  }

  var file = files[0];
  var start = parseInt(opt_startByte) || 0;
  var stop = parseInt(opt_stopByte) || file.size - 1;

  var reader = new FileReader();

  // If we use onloadend, we need to check the readyState.
  reader.onloadend = function(evt) {
    if (evt.target.readyState == FileReader.DONE) { // DONE == 2
//       document.getElementById('byte_content').textContent = evt.target.result;
      scan = JSON.parse(evt.target.result);
      init_widgets();
//       alert("scan loaded");
//       draw_scan();
//       document.getElementById('byte_range').textContent = 
//           ['Read bytes: ', start + 1, ' - ', stop + 1,
//             ' of ', file.size, ' byte file'].join('');
    }
  };

  var blob = file.slice(start, stop + 1);
  reader.readAsBinaryString(blob);
}















