

// Click coordinates
var x1, x2, y1, y2;

//Variable indicates wether a mousedown event within your selection happend or not
var selection = false;

// Global mouse button variables
var gMOUSEUP = false;
var gMOUSEDOWN = false;


function init_selection(){

// Global Events if left mousebutton is pressed or nor (usability fix)
$(document).mouseup(function() {
    gMOUSEUP = true;
    gMOUSEDOWN = false;
});
$(document).mousedown(function() {
    gMOUSEUP = false;
    gMOUSEDOWN = true;
});

// Selection frame (playground :D)
$("#YDR-Frame").mousedown(function(e) {
    selection = true;
    // store mouseX and mouseY
    x1 = e.pageX - this.offsetLeft;
    y1 = e.pageY - this.offsetTop;
});

// If selection is true (mousedown on selection frame) the mousemove 
// event will draw the selection div
$('#YDR-Frame').mousemove(function(e) {
    if (selection) {
        // Store current mouseposition
        x2 = e.pageX - this.offsetLeft;
        y2 = e.pageY - this.offsetTop;

        // Prevent the selection div to get outside of your frame
        (x2 < 0) ? selection = false : ($(this).width() < x2) ? selection = false : (y2 < 0) ? selection = false : ($(this).height() < y2) ? selection = false : selection = true;;

        // If the mouse is inside your frame resize the selection div
        if (selection) {
            // Calculate the div selection rectancle for positive and negative values
            var TOP = (y1 < y2) ? y1 : y2;
            var LEFT = (x1 < x2) ? x1 : x2;
            var WIDTH = (x1 < x2) ? x2 - x1 : x1 - x2;
            var HEIGHT = (y1 < y2) ? y2 - y1 : y1 - y2;

            // Use CSS to place your selection div
            $("#selection").css({
                position: 'relative',
                zIndex: 5000,
                left: LEFT,
                top: TOP,
                width: WIDTH,
                height: HEIGHT
            });
            $("#selection").show();

            // Info output
            $('#status2').html('( x1 : ' + x1 + ' )  ( x2 : ' + x2 + ' )  ( y1 : ' + y1 + '  )  ( y2 : ' + y2 + ' ) ');
        }
    } else {
          $("#selection").hide();
    }
});
// Selection complete, hide the selection div (or fade it out)
$('#YDR-Frame').mouseup(function() {
    selection = false;
    $("#selection").hide();
    selection_finished(x1,x2,y1,y2);
});
// Usability fix. If mouse leaves the selection and enters the selection frame again with mousedown
$("#YDR-Frame").mouseenter(function() {
    (gMOUSEDOWN) ? selection = true : selection = false;
});
// Usability fix. If mouse leaves the selection and enters the selection div again with mousedown
$("#selection").mouseenter(function() {
    (gMOUSEDOWN) ? selection = true : selection = false;
});
// Set selection to false, to prevent further selection outside of your selection frame
$('#YDR-Frame').mouseleave(function() {
    selection = false;
});



}


