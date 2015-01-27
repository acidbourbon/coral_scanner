function unfold(button,container){
  var button_text = button.html();
  var new_button_text;
  
  if(container.is(':visible')){
    new_button_text = button_text.replace("[-]","[+]");
  } else {
    new_button_text = button_text.replace("[+]","[-]");
  }
  container.fadeToggle();
  $('html, body').animate({
      scrollTop: container.offset().top
  }, 2000);
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