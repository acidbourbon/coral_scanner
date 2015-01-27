function unfold(button,container){
  var button_text = button.html();
  var new_button_text;
  
  if(container.is(':visible')){
    new_button_text = button_text.replace("[-]","[+]");
  } else {
    new_button_text = button_text.replace("[+]","[-]");
    container.trigger('isVisible');
  }
  container.fadeToggle();
  $('html, body').animate({
      scrollTop: container.offset().top
  }, 1000);
  button.html(new_button_text);
}

function unfolds(button,container){
  button.click(function(){
    unfold(button,container);
  });
  
  var button_text = button.html();
  
  if(container.is(':visible')){
    button.html("[-] "+button_text);
  } else {
    button.html("[+] "+button_text);
  }
  
}

// use unfold with an event trigger:

//   unfolds($("#show_scan_pattern"),$("#scan_pattern_container"));
//   $("#scan_pattern_container").bind('isVisible',function(){
//     alert("div becomes visible");
//     get_pattern_svg();
//   });


function flot_w_selectZoom(id,data,options) {
  $.plot(id, data, options);
  
  $(id).bind("plotselected", function (event, ranges) {
    // clamp the zooming to prevent eternal zoom
    if (ranges.xaxis.to - ranges.xaxis.from < 0.00001) {
      ranges.xaxis.to = ranges.xaxis.from + 0.00001;
    }
    if (ranges.yaxis.to - ranges.yaxis.from < 0.00001) {
      ranges.yaxis.to = ranges.yaxis.from + 0.00001;
    }
    // do the zooming
    plot = $.plot(id, data,
      $.extend(true, {}, options, {
        xaxis: { min: ranges.xaxis.from, max: ranges.xaxis.to },
        yaxis: { min: ranges.yaxis.from, max: ranges.yaxis.to }
      })
    );
  });
}