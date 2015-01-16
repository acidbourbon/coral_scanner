package coral_scanner;


use strict;
use warnings;
use Time::HiRes;
use POSIX qw/strftime/;
use POSIX;
use Device::SerialPort;

use SVG;

use CGI ':standard';

# use settings_subs;
use has_settings;
our @ISA = qw/has_settings/; # assimilate the methods of the has_settings class


use pmt_ro;
use table_control;

use misc_subs;

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
  
  $self->{pmt_ro} = pmt_ro->new();
  $self->{table_control} = table_control->new();
  
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
  
  print "<p id='show_main_controls' class='quasibutton' >main controls</p>";
  print "<div id='main_controls_container' class='stylishBox padded'>";
  print "<svg width=480 height=260>";
  $self->{table_control}->scan_pattern_to_svg();
  print "</svg>";
  print br;
  print "some content!";
  print "</div>";
  
  
  print "<p id='show_pmt_ro_settings' class='quasibutton' >pmt_ro settings</p>";
  print "<div align=right id='pmt_ro_settings_container' class='stylishBox settings_form hidden_by_default'>";
  $self->{pmt_ro}->settings_form();
  print "</div>";
  
  print "<p id='show_table_control_settings' class='quasibutton' >table_control settings</p>";
  print "<div align=right id='table_control_settings_container' class='stylishBox settings_form hidden_by_default'>";
  $self->{table_control}->settings_form();
  print "</div>";
  
  print "</div>";
  
  print end_html();
  return " ";
}







1;
