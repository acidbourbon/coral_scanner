#!/usr/bin/perl

####################################################################################
##  This is a simple script to dispatch a perl module's subs from a CGI request   ##
####################################################################################

use strict;
use warnings;
use lib '.';
use CGI_dispatch;

use table_control;
my $self = table_control->new();

# go only to methods that are in the following dispatch table:
# if associated value is one, sub can be called via CGI
my $dispatch_table = {
  help => 1,
  test => 1,
  load_settings => 1,
  save_settings => 1,
  reset_settings => 1,
  init_port => 1,
  status => 1,
  communicate => 1,
  set_zero => 1,
  go_xy    => 1,
  home   => 1,
  go_startpoint => 1,
  scan_pattern => 1,
  scan_pattern_to_svg => 1,
  scan => 1,
  settings_form => 1
};

CGI_dispatch::dispatch_sub(package => $self, dispatch_table => $dispatch_table);
