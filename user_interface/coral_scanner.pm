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
use JSON;

# use settings_subs;
use has_settings;
our @ISA = qw/has_settings/; # assimilate the methods of the has_settings class


use pmt_ro;
use table_control;

use misc_subs;

use shm_manager;

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
  
  $self->{status_shm} = shm_manager->new( shmName => __PACKAGE__.".status" );
  $self->{status_shm}->initShm(); 
  $self->{scan_shm} = shm_manager->new( shmName => __PACKAGE__.".scan" );
  $self->{scan_shm}->initShm(); 
  
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
  
  print '<div id="scan_container" style="width: 600px; height: 270px; overflow-x: scroll;">';
  $self->scan_to_svg();
  print '</div>';
  
  print br;
  print "estimated scan duration: ".hms_string($self->scan_ETA());
  print br;
  
  print "<div id='scan_status_container' class='padded'>";
  print "<pre>";
  $self->scan_status( report => 1 );
  print "</pre>";
  print "</div>";
  
  print "<input type='button' id='button_start_scan' value='start scan'>";
  print "<input type='button' id='button_stop_scan' value='stop scan'>";
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
  
  my $ro = $self->{pmt_ro};
  
  
  
  

#   $tc->home();
#   $tc->scan( eval => 'print("test\n");' );
  my $scan_pattern = $tc->scan_pattern();
  
  my $ETA = $self->scan_ETA();
  
  $self->{status_shm}->updateShm({
    action => 'scanning',
    abort  => 0,
    cols => $scan_pattern->{cols},
    rows => $scan_pattern->{rows},
    current_col => 0,
    current_row => 0,
    ETA  => $ETA,
    seconds_left => $ETA
  });
  
  $self->{current_scan} = {};
  $self->{current_scan}->{meta} = {
    number_points => $scan_pattern->{number_points},
    cols => $scan_pattern->{cols},
    rows => $scan_pattern->{rows},
    time_per_pixel => $self->{settings}->{time_per_pixel},
    signal_thresh  => $self->{pmt_ro}->{settings}->{signal_thresh},
    step_size => $self->{table_control}->{settings}->{sample_step_size}
    
  };
  $self->{current_scan}->{data} = [];
  
  for my $point (@{$scan_pattern->{points}}) {
    $tc->go_xy( x => $point->{x}, y => $point->{y});
    
    printf("Acquire PMT counts at point x,y = %3.3f,%3.3f i,j = %d,%d\n" ,$point->{x_rel},$point->{y_rel}, $point->{row},$point->{col});
    
    my $delay = $self->{settings}->{time_per_pixel};
    my $counts = $ro->count(delay => $delay, channel => "signal");
    my $col = $point->{col};
    my $row = $point->{row};
    
    $self->{current_scan}->{data}->[$row]->[$col] = $counts;
    print "counts: $counts\n";
    print "\n\n";
    
    my $status = $self->{status_shm}->lockAndReadShm();
    
    if ($status->{abort}) {
      $status = {
        %$status,
        action => "aborted",
        abort => 0,
        current_col => $col,
        current_row => $row,
        seconds_left => 0
      };
      $self->{status_shm}->writeShm($status);
      $self->{scan_shm}->writeShm($self->{current_scan});
      print "scan was aborted!\n";
#       last; # stop the acquisition loop!
      exit;
    } else {
      my $seconds_left = floor($status->{ETA} * (1 - $row/$status->{rows}));
      $status = {
        %$status,
        current_col => $col,
        current_row => $row,
        seconds_left => $seconds_left
      };
      $self->{status_shm}->writeShm($status);
    }
  }
  
  $self->{scan_shm}->writeShm($self->{current_scan});
  $self->{status_shm}->updateShm({
    action => 'idle',
    seconds_left => 0
  });
  
  $self->save_scan_ascii(filename => "./scan.dat");
  
  

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
  for my $point (@{$pattern->{points}}){
    unless(defined($last_point)){
      $pattern_length += max($point->{x},$point->{y});
    } else {
      my $dx = abs($point->{x} - $last_point->{x});
      my $dy = abs($point->{y} - $last_point->{y});
      $pattern_length += max($dx,$dy);
    }
    $last_point = $point;
  }
  
  my $number_points = $pattern->{number_points};
  return $pattern_length/$speed + $number_points*$time_per_pixel;
  
}

sub scan_status {
  my $self = shift;
  my %options = @_;
  my $json = $options{json};
  my $report = $options{report};
  my $status = $self->{status_shm}->readShm();
  
  if($json){
    print encode_json $status;
    return " ";
  }
  if($report){
    print "Machine is : ".$status->{action}."\n";
    print "row ".$status->{current_row}."/".($status->{rows}-1)."\n";
    print "col ".$status->{current_col}."/".($status->{cols}-1)."\n";
    print "scan finished in ".hms_string($status->{seconds_left})."\n";
    print "total duration   ".hms_string($status->{ETA})."\n";
    print "\n";
    return " ";
  } else {
    return $status;
  }
  
}

sub last_scan {
  my $self = shift;
  return $self->{scan_shm}->readShm();

}

sub start_scan {
  my $self= shift;
  daemonize();
  $self->scan_sample();
}

sub stop_scan {
  my $self= shift;
  $self->{status_shm}->updateShm({abort => 1});
  print "sent stop signal\n";
  return " ";
}

sub scan_to_svg {
  my $self = shift;
  my %options = @_;
  
  my $html_tag = $options{html_tag};
  my $svg_file = $options{svg_file};
  
  my $tc = $self->{table_control};
  
  my $scan = $self->{scan_shm}->readShm();
  
  my $sample_rect_x1 = $tc->{settings}->{sample_rect_x1};
  my $sample_rect_x2 = $tc->{settings}->{sample_rect_x2};
  my $sample_rect_y1 = $tc->{settings}->{sample_rect_y1};
  my $sample_rect_y2 = $tc->{settings}->{sample_rect_y2};
  
  my $sample_rect_size_x = $sample_rect_x2 - $sample_rect_x1;
  my $sample_rect_size_y = $sample_rect_y2 - $sample_rect_y1;
  
  my $aperture_dia = $tc->{settings}->{sample_aperture_dia};
  
  my $scale = 12; # pixel per mm
  
  # create an SVG object with a size of 40x40 pixels
  
  my $pic_width  = ($sample_rect_size_x+5)*$scale;
  my $pic_height = 250;
  
  my $svg = SVG->new(
        -printerror => 1,
        -raiseerror => 0,
        -indent     => '  ',
        -docroot => 'svg', #default document root element (SVG specification assumes svg). Defaults to 'svg' if undefined
        -inline   => 1,
        id          => 'document_element',
    width => $pic_width,
    height => $pic_height,
  );
  
  my $step_size = $scan->{meta}->{step_size};
  my $cols = $scan->{meta}->{cols};
  my $rows = $scan->{meta}->{rows};
  my $scale = 12;
  
  my $scaler = $svg->group(
      transform => "scale($scale)"
  );
  
  my $tr1 = $scaler->group(
      transform => "translate(0,0)"
    );
    
  for (my $i=0; $i < $rows; $i++) {
    for (my $j=0; $j < $cols; $j++) {
      my $counts = $scan->{data}->[$i]->[$j];
      my ($r,$g,$b) = false_color($counts,800,4000);
      #= ($i*10,$j*10,$i*$j);
      $tr1->rectangle(
        x => $i*$step_size,
        y => $j*$step_size,
        width => $step_size*.9,
        height => $step_size*.9,
        title => $counts,
        style =>{
            'stroke'=>'none',
            'fill'=>"rgb($r,$g,$b)",
        });
    }
  }
  
  
  if (defined($svg_file)){
    open(SVGFILE, ">".$svg_file) or die "could not open $svg_file for writing!\n";
    # now render the SVG object, implicitly use svg namespace
    print SVGFILE $svg->xmlify;
    close(SVGFILE);
  } else {
    print "<svg width=$pic_width height=$pic_height>" if $html_tag;
    print $svg->xmlify;
    print "</svg>" if $html_tag;
  }
  
  return " ";

}






1;
