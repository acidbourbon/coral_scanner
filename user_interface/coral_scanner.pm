package coral_scanner;


use strict;
use warnings;
use Time::HiRes;
use POSIX qw/strftime/;
use POSIX;
use Device::SerialPort;

use SVG;

use CGI ':standard';

require settings_subs;
# our @ISA = qw/has_settings/; # assimilate the methods of the has_settings class


#use pmt_ro;
#use table_control;

require misc_subs;

## methods

sub new {
  my $class = shift;
  my %options = @_;
  
  my $self = {}; # put tons of default values here (if you wish);

  $self->{constants} = {
  };
  
  $self->{settings_file} = "./".__PACKAGE__.".settings";
  
  $self->{default_settings} = { # hard default settings
    a => 1,
    b => 2
  };
  
  $self->{settings_desc} = {

  };

  $self->{has_run} = {}; # remember which subs already have run
  
  $self->{settings} = {%{$self->{default_settings}}};
  
  $self  = {
    %$self,
    %options
  };
  bless($self, $class);
  
  #$self->{pmt_ro} = pmt_ro->new();
  #$self->{pmt_control} = table_control->new();
  
  return $self;
}

sub main_html {

  my $self = shift;
  my %options = @_;
  
  printHeader('text/html');
  
  print start_html(
    -title => 'Coral Scanner',
    
    -style => [
      {'src' => './styles.css'},
      {'src' => './coral_scanner.css'}
    ],
    
    -script => [
      {-src => './jquery.min.js'},
      {-src => './jquery.timer.js'},
      {-src => './jquery.mwiebusch.js'},
      {-src => './coral_scanner.js'},
    ]
  );
  
  
  print h2 "Coral Scanner";
  
  print "<div id='main_body'>";
  
  print "<p id='show_pmt_ro_settings' class='quasibutton' >pmt_ro settings</p>";
  print "<div id='pmt_ro_settings_container' class='stylishBox hidden_by_default'>";
  $self->settings_form();
  print "</div>";
  
  
  print "</div>";
  
  print end_html();
  return " ";
}







1;
