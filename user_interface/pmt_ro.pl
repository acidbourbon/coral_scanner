#!/usr/bin/perl

####################################################################################
##  This is a simple script to dispatch a perl module's subs from a CGI request   ##
####################################################################################

use strict;
use warnings;
use CGI_dispatch;

use pmt_ro;
my $self = pmt_ro->new();

# go only to methods that are in the following dispatch table:
# if associated value is one, sub can be called via CGI
my $dispatch_table = {
  help => 1,
  test => 1,
  read_register => 1,
  write_register => 1,
  find_baseline => 1,
  signal_range => 1,
  count => 1,
  load_settings => 1,
  save_settings => 1,
  reset_settings => 1,
  settings_form => 1,
  zero_calib => 1,
  signal_thresh => 1,
  veto_thresh => 1,
  spectral_scan => 1,
  spectral_scan_onesided => 1,
  dead_time => 1,
  apply_device_settings => 1
};

CGI_dispatch::dispatch_sub($self,$dispatch_table);