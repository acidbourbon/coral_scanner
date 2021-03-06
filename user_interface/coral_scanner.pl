#!/usr/bin/perl

####################################################################################
##  This is a simple script to dispatch a perl module's subs from a CGI request   ##
####################################################################################

use strict;
use warnings;

use lib ".";

use CGI_dispatch;

use coral_scanner;
my $self = coral_scanner->new();

# go only to methods that are in the following dispatch table:
# if associated value is one, sub can be called via CGI
my $dispatch_table = {

};

CGI_dispatch::dispatch_sub(package => $self,
  #dispatch_table => $dispatch_table,
  default_sub => "main_html"
  );
