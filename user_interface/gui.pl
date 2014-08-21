#!/usr/bin/perl -w

use strict;
use Gtk2 '-init';

use constant TRUE  => 1;
use constant FALSE => 0;

my $window = Gtk2::Window->new;
$window->set_title ('FPGA based pulse width analyzer');
$window->signal_connect (destroy => sub { Gtk2->main_quit; });
$window->set_border_width(3);

my $vbox = Gtk2::VBox->new(FALSE, 6);
$window->add($vbox);

my $actions_frame = Gtk2::Frame->new('Actions');
$vbox->pack_start($actions_frame, TRUE, TRUE, 0);
$actions_frame->set_border_width(3);

my $plot_frame = Gtk2::Frame->new('Plot');
$vbox->pack_start($plot_frame, TRUE, TRUE, 0);
$plot_frame->set_border_width(3);


my $hbox = Gtk2::HBox->new(FALSE, 6);
$actions_frame->add($hbox);
$hbox->set_border_width(3);



##################################################
##                   buttons                    ##
##################################################

my $inc_button = Gtk2::Button->new('_Click Me');
# $hbox->pack_start($inc_button, FALSE, FALSE, 0);
my $count = 1;

my $plot_button = Gtk2::Button->new('_Plot');
$hbox->pack_start($plot_button, FALSE, FALSE, 0);

my $clear_button = Gtk2::Button->new('_Clear');
$hbox->pack_start($clear_button, FALSE, FALSE, 0);

my $windowLength_entry = Gtk2::Entry->new('100us');
$hbox->pack_start($windowLength_entry, FALSE, FALSE, 0);

my $setWindowLength_button = Gtk2::Button->new('_Set window length');
$hbox->pack_start($setWindowLength_button, FALSE, FALSE, 0);



my $quit_button = Gtk2::Button->new('_Quit');
# $hbox->pack_start($quit_button, FALSE, FALSE, 0);
$quit_button->signal_connect( clicked => sub {
            Gtk2->main_quit;
    });





my $image = Gtk2::Image->new_from_file ("plot.png");
# $vbox->pack_start($image, TRUE, TRUE, 0);
$plot_frame->add($image);




my $label = Gtk2::Label->new('... debug out');
$vbox->pack_start($label, TRUE, TRUE, 0);



##################################################
##               button functions               ##
##################################################
# has to be done after we've created the label so we can get to it
$inc_button->signal_connect( clicked => \&update_clicks);
sub update_clicks {
  
#                 $label->set_text("Clicked $count times.");
                $count++;
  
}


$plot_button->signal_connect( clicked => sub {

#   $label->set_text(qx%echo blah%);
  execute("./plot.sh");
  $plot_frame->remove($image);
  $image->clear;
  $image = Gtk2::Image->new_from_file ("plot.png");
  $plot_frame->add($image);
  $window->show_all;
  
});

$clear_button->signal_connect( clicked => sub {

  execute("./analyzer.pl --clear");
  $image->clear;
  
});

$setWindowLength_button->signal_connect( clicked => sub {
  my $windowLength = $windowLength_entry->get_text();
  execute("./analyzer.pl --window $windowLength");
#   $label->set_text($windowLength_entry->get_text());
  execute("./analyzer.pl --clear");
  
});


sub execute {
  my $command = shift;
  print "execute:\n$command\n";
  system($command);  
  print "\n\n";
  
}





$window->show_all;
Gtk2->main;