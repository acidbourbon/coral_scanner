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
