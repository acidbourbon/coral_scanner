#!/usr/bin/perl -w

use strict;
use Gtk2 '-init';

use constant TRUE  => 1;
use constant FALSE => 0;

my $window = Gtk2::Window->new;
$window->set_title ('Widget Layout');
$window->signal_connect (destroy => sub { Gtk2->main_quit; });
$window->set_border_width(3);

my $vbox = Gtk2::VBox->new(FALSE, 6);
$window->add($vbox);

my $frame = Gtk2::Frame->new('Buttons');
$vbox->pack_start($frame, TRUE, TRUE, 0);
$frame->set_border_width(3);

my $hbox = Gtk2::HBox->new(FALSE, 6);
$frame->add($hbox);
$hbox->set_border_width(3);

my $inc_button = Gtk2::Button->new('_Click Me');
$hbox->pack_start($inc_button, FALSE, FALSE, 0);
my $count = 1;

my $quit_button = Gtk2::Button->new('_Quit');
$hbox->pack_start($quit_button, FALSE, FALSE, 0);
$quit_button->signal_connect( clicked => sub {
		Gtk2->main_quit;
	});

my $label = Gtk2::Label->new('Clicked 0 times.');
$vbox->pack_start($label, TRUE, TRUE, 0);

# has to be done after we've created the label so we can get to it
$inc_button->signal_connect( clicked => sub {
		$label->set_text("Clicked $count times.");
		$count++;
	});

$window->show_all;
Gtk2->main;
