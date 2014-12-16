#!/usr/bin/perl

use strict;
use warnings;
use CGI ':standard';
use CGI::Carp qw(fatalsToBrowser);
use Data::Dumper;
use pmt_ro;


####################################################################################
##  This is a simple script to dispatch a perl module's subs from a CGI request   ##
####################################################################################



my $query = CGI->new();
my $self = pmt_ro->new();


my $sub = $query->param('sub') || "help";

# go only to methods that are in the following dispatch table:
# if associated value is one, sub can be called via CGI
my $dispatch = {
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
  zero_calib => 1,
  signal_thresh => 1,
  veto_thresh => 1,
  spectral_scan => 1,
  spectral_scan_onesided => 1,
  dead_time => 1,
  apply_device_settings => 1
};

# if method exists, execute it, if not complain and show help message
if ($dispatch->{$sub} ) {
  my $args = CGI_parameters();
  
  # here the corresponding method is called
  my $return = $self->$sub(%$args);
  # does it return anything?
  if(defined($return)){ # we get a return value
    if(ref(\$return) eq "SCALAR"){ # just print it if it is a scalar
      print "$return\n";
    } else { # use Data::Dumper to display a hash
      print "sub returns a hash:\n";
      print Dumper $return;
    }
  }
} else {
  print "$sub is not a valid sub!\n\n";
  $self->help(1);
}



sub CGI_parameters {
  # for each item on the list, get the
  # designated parameter from the CGI query and
  # store it in the target hash IF the parameter is
  # defined in the query!
  
  my %options = @_;
  my $items   = $options{items};
  # target can be left undefined, then a new hash is created
  # and returned
  my $target;
  $target = $options{target} if defined($options{target});
  
  
  if(defined($items)){ # if there is a list of parameters
    for my $item (@{$items}){
      if(defined($query->param($item))){
        $target->{$item} = $query->param($item);
      } 
    }
  } else { # if there is no list of parameters
    # extract all parameters
    for my $item($query->param) {
      $target->{$item} = $query->param($item);
    }
  }
  return $target;
}



