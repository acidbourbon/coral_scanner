package coral_scanner;


use strict;
use warnings;
use Time::HiRes qw/sleep/;
use POSIX qw/strftime/;
use POSIX;
use Device::SerialPort;
use Data::Dumper;

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
    time_per_pixel => 1
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
  
  $self->load_settings();
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
#       {-src => './SVGPan.js'},
    ]
  );
  

  print h2 "Coral Scanner";
  
  print "<div id='main_body'>";
  
  print "<p id='show_main_controls' class='quasibutton' >main controls</p>";
  print "<div id='main_controls_container' class='stylishBox padded'>";
  print '<div style="width: 600px; height: 270px; overflow-x: scroll;">';
  $self->{table_control}->scan_pattern_to_svg(html_tag => 1);
  print '</div>';
  
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

sub scan_sample {

  my $self = shift;
  my %options = @_;
  
  my $tc = $self->{table_control};
  
  $self->{current_scan} = {};
  $self->{current_scan}->{meta} = {points => 0};
  $self->{current_scan}->{data} = [];
  

#   $tc->home();
#   $tc->scan( eval => 'print("test\n");' );
  $tc->scan( object => $self, method => 'scan_callback' );
  
  $self->save_scan_ascii(filename => "./scan.dat");
  
  

}

sub scan_callback {
  my $self  = shift;
  my $point = shift;
  
  printf("Acquire PMT counts at point x,y = %3.3f,%3.3f i,j = %d,%d\n" ,$point->{x_rel},$point->{y_rel}, $point->{row},$point->{col});
  my $ro = $self->{pmt_ro};
  
  $self->{current_scan}->{meta}->{points}++;
  my $delay = $self->{settings}->{time_per_pixel};
  my $counts = $ro->count(delay => $delay, channel => "signal");
  my $col = $point->{col};
  my $row = $point->{row};
  
  $self->{current_scan}->{data}->[$row]->[$col] = $counts;
  print "counts: $counts\n";
  
#   push(@{$self->{current_scan}->{data}},{%$point,counts => $counts});
  print "\n\n";


}

sub save_scan_ascii {
  my $self = shift;
  my %options = @_;
  
  my $filename = $options{filename};
  
  my @darray = @{$self->{current_scan}->{data}};
#   @darray = sort {$a->{col} <=> $b->{col}} @darray;
#   @darray = sort {$a->{row} <=> $b->{row}} @darray;
  
  open(FILE,">$filename");
  for my $item (@darray){
  
    my $string = join("\t",@$item)."\n";
#     my $string = sprintf("%d\t%d\t%d\n",$item->{row},$item->{col},$item->{counts});
    print $string;
    print FILE $string;
  }
  close(FILE);

}

sub scan_ETA { #estimated time to complete a scan
  my $self = shift;
  
  my $tc = $self->{table_control};
  
  my $speed = $tc->{settings}->{approx_speed}; #approximate speed in mm/sec
  my $time_per_pixel = $self->{settings}->{time_per_pixel};
  
  my $pattern_length = 0;
  my $last_point;
  my $pattern = $tc->scan_pattern();
  for my $point (@$pattern){
    unless(defined($last_point)){
      $pattern_length += max($point->{x},$point->{y});
    } else {
      my $dx = abs($point->{x} - $last_point->{x});
      my $dy = abs($point->{y} - $last_point->{y});
      $pattern_length += max($dx,$dy);
    }
    $last_point = $point;
  }
  
  my $number_points = scalar(@$pattern);
  return $pattern_length/$speed + $number_points*$time_per_pixel;
  

}





1;
