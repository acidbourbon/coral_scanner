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
use report;

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
    time_per_pixel => 1,
    approx_upper_rate => 4000,
    plot_lower_limit  => 0,
    plot_upper_limit  => 4000,
    pid_file           => "./".__PACKAGE__.".pid",
    log_file           => "./".__PACKAGE__.".log",
    table_control_number_retries => 3,
    table_control_retry_delay => 5,
    unshadowed_count_time => 100,
  };
  
  $self->{settings_desc} = {
    time_per_pixel => "time in seconds to integrate the counts of the PMT at a given coordinate",
    approx_upper_rate => "upper boundary of the counting rate in counts/sec,
    is used for setting the value range of the plot",
    plot_lower_limit => "lower contrast setting for the plot",
    plot_upper_limit => "upper contrast setting for the plot",
    pid_file         => "/path/to/file of the lockfile for the scanning background process",
    stdout           => "/path/to/file of the stdout logfile",
    stderr           => "/path/to/file of the stderr logfile",
    table_control_number_retries => "number of retries, when communication with the table fails",
    table_control_retry_delay => "number of seconds to wait for new connection with table",
    unshadowed_count_time => "time in seconds to record the unshadowed/undisturbed count rate of the source before scanning",
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
  $self->{report} = report->new();
  
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
      {'src' => './coral_scanner.css'},
      {'src' => './jquery-ui.css'}
    ],
    
    -script => [
      {-src => './cookies.js'},
      {-src => './jquery.min.js'},
      {-src => './jquery.timer.js'},
      {-src => './jquery-ui.js'},
      {-src => './jquery.flot.js'},
      {-src => './jquery.flot.selection.js'},
      {-src => './jquery.mwiebusch.js'},
      {-src => './coral_scanner.js'},
#       {-src => './SVGPan.js'},
    ]
  );
  

  print h2 "Coral Scanner";
  
  print "<div id='main_body'>";
  
  print "<p id='show_main_controls' class='quasibutton' >main controls</p>";
  print "<div id='main_controls_container' class='stylishBox padded'>";
  

  
  print '<div id="scan_container" style="width: 600px; height: 270px; overflow-x: scroll;">';
#   $self->scan_to_svg();
  print '</div>';
  print br; 
  print "plot contrast: ";
  print "<span id='amount'></span>";
  print br;
  print '<div id="slider-range"></div>';
  print br;
  print "<input type='button' value='(re)plot' id='button_replot'>";
  print "<a href='coral_scanner.pl?sub=scan_to_ascii' target='_blank' id='button_ascii'
  ><input type='button' value='scan to ascii'></a>";
  print "<a href='coral_scanner.log' target='_blank' id='button_log'
  ><input type='button' value='view log'></a>";
  print "<input type='button' value='clear log' id='button_clearlog'>";
  print "<a href='coral_scanner.pl?sub=scan_to_svg' target='_blank' id='button_svg'
  ><input type='button' value='svg image'></a>";
  print "<a href='coral_scanner.pl?sub=last_scan' target='_blank' id='button_dump'
  ><input type='button' value='scan dump'></a>";
  print "<a href='analysis.html' target='_blank' id='button_analysis_gui'
  ><input type='button' value='analysis gui'></a>";
  print br;
  print hr;
  print br;
  print "<table><tr>";
  print "<td align=right>Scan name: </td>";
  print "<td><input type='text' id='text_scan_name' value=''></td>";
  print "</tr><tr>";
  print "<td align=right>Scan description: </td>";
  print "<td><input type='text' id='text_scan_desc' value=''></td>";
  print "</tr><tr>";
  print "<td align=right>Sample length to scan (mm): </td>";
  print "<td><input type='text' id='text_scan_length' value=''></td>";
  print "</tr><tr>";
  print "<td align=right>Time per pixel (s): </td>";
  print "<td><input type='text' id='text_time_per_pixel' value=''></td>";
  print "</tr><tr>";
  print "<td align=right>Sample step size (mm): </td>";
  print "<td><input type='text' id='text_sample_step_size' value=''></td>";
  print "</tr></table>";
  
  print br;
  print "estimated scan duration: <span id='ETA_hms'></span>";
  print br;
  print "Machine is : <span id='action'></span>";
  print br;
  print "row : <span id='current_row'></span>/<span id='rows'></span>";
  print br;
  print "col : <span id='current_col'></span>/<span id='cols'></span>";
  print br;
  print "time left : <span id='time_left'></span>";
  print br;
  print "<div id='progressbar'></div>";
  
#   print "<div id='scan_status_container' class='padded'>";
#   print "<pre>";
#   $self->scan_status( report => 1 );
#   print "</pre>";
#   print "</div>";
  
  print "<input type='button' id='button_home' value='home'>";
  print "<input type='button' id='button_start_scan' value='start scan'>";
  print "<input type='button' id='button_stop_scan' value='stop scan'>";
  print "<input type='button' id='button_program_padiwa' value='program padiwa settings'>";
  print "<input type='button' id='button_test' value='test'>";
  print br br hr;
  print "PMT test:";
  print br;
  print "<input type='button' id='button_thresh' value='set threshold'>";
  print "<input type='text' id='text_thresh' value=''>";
  print br;
  print "<input type='button' id='button_count' value='count'>";
  print "<input type='text' id='text_count' value='1'>";
  print " [s] ";
  print "<input type='text' id='text_count_out' value='' readonly>";
  
  
  
  print "</div>";
  
  print "<p id='show_pmt_spectrum' class='quasibutton' >spectrum</p>";
  print "<div id='pmt_spectrum_container' class='stylishBox padded'>";
  print "<table><tr><td>";
  print '<div id="spectrum_plot_container" style="width:600px;height:300px;float:left;"></div>';
  print "</td><td>";
  print '<div id="choices"></div>';
  print "</td></tr></table>";
  print "<input type='button' id='button_plot_spectrum' value='plot spectrum'>";
  print "<input type='button' id='button_clear_spectrum' value='clear spectrum'>";
  print "<input type='button' id='button_delete_selected' value='delete selected'>";
  print "<label><input type='checkbox' id='checkbox_log_spectrum' >log y</label>";
  print "<label><input type='checkbox' id='checkbox_diff_spectrum' >diff</label>";
  print br;
  print "record name: ";
  print "<input type='text' id='text_spectrum_name' value='signal'>";
  print "<input type='button' id='button_record_spectrum' value='record spectrum'>";
  print "<a href='./pmt_ro.pl?sub=spectrum_csv' target='_blank' id='button_spectrum_csv'
  ><input type='button' value='spectrum data (csv)'></a>";
  print "</div>";
  
  print "<p id='show_scan_pattern' class='quasibutton' >scan pattern</p>";
  print "<div id='scan_pattern_container' class='stylishBox padded hidden_by_default'>";
  print '<div id="pattern_svg_container" style="width: 600px; height: 270px; overflow-x: scroll;">';
#   $self->{table_control}->scan_pattern_to_svg(html_tag => 1);
  print '</div>';
  print "</div>";
  
  print "<p id='show_coral_scanner_settings' class='quasibutton' >coral scanner settings</p>";
  print "<div align=right id='coral_scanner_settings_container' class='stylishBox settings_form hidden_by_default'>";
  $self->settings_form();
  print "</div>";
  
  print "<p id='show_pmt_ro_settings' class='quasibutton' >pmt_ro settings</p>";
  print "<div align=right id='pmt_ro_settings_container' class='stylishBox settings_form hidden_by_default'>";
  $self->{pmt_ro}->settings_form();
  print "</div>";
  
  print "<p id='show_table_control_settings' class='quasibutton' >table_control settings</p>";
  print "<div align=right id='table_control_settings_container' class='stylishBox settings_form hidden_by_default'>";
  $self->{table_control}->settings_form();
  print "</div>";
  
  print "<p id='show_report_settings' class='quasibutton' >report settings</p>";
  print "<div align=right id='report_settings_container' class='stylishBox settings_form hidden_by_default'>";
  $self->{report}->settings_form();
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
  
  my $scan_pattern = $tc->scan_pattern();
  my $ETA = $self->scan_ETA();
  
  
  
  $self->{status_shm}->updateShm({
    action => 'scanning',
    abort  => 0,
    cols => $scan_pattern->{cols},
    rows => $scan_pattern->{rows},
    number_points => $scan_pattern->{number_points},
    points_scanned => 0,
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
    step_size => $self->{table_control}->{settings}->{sample_step_size},
    start_time      => time(),
    start_timestamp => strftime("%Y-%m-%d_%H:%M:%S", localtime()),
    
  };
  
  $self->{current_scan}->{meta}->{scan_name} = $options{scan_name} if defined($options{scan_name});
  $self->{current_scan}->{meta}->{scan_desc} = $options{scan_desc} if defined($options{scan_desc});
  $self->{current_scan}->{data} = [];
  # $self->clear_log();
  print ">>> initializing new scan\n\n";
  print "  scan name:        ".$options{scan_name}."\n";
  print "  scan description: ".$options{scan_desc}."\n";
  
  
  print ">>> homing table\n\n";
  $tc->home();
  
  print ">>> recording unshadowed beam count rate\n\n";
  my $unshadowed_count_time = $self->{settings}->{unshadowed_count_time};
  my $unshadowed_counts = $ro->count(delay => $unshadowed_count_time, channel => "signal");
  $self->{current_scan}->{meta}->{unshadowed_count_time} = $unshadowed_count_time;
  $self->{current_scan}->{meta}->{unshadowed_counts}     = $unshadowed_counts;
  print "  count time : $unshadowed_count_time\n";
  print "  counts     : $unshadowed_counts\n";
  
  
  print ">>> starting actual scan\n\n";
  my $points_scanned = 0;
  my $last_row;
  
  for my $point (@{$scan_pattern->{points}}) {
    # attempt to drive to position
    printf("Drive to point x,y = %3.3f,%3.3f i,j = %d,%d\n" ,$point->{x_rel},$point->{y_rel}, $point->{row},$point->{col});

    
    eval {
      $tc->go_xy( x => $point->{x}, y => $point->{y});
    };
    if($@) {
      warn "error from table\n$@";
      print "attempting to reconnect with table\n";
      my $tries = $self->{settings}->{table_control_number_retries};
      for my $try (1..$tries) {
        print "try $try of $tries\n:";
        sleep $self->{settings}->{table_control_retry_delay};
        eval {
          $tc->init_port();
          $tc->home();
          $tc->go_xy( x => $point->{x}, y => $point->{y});
        };
        
        if($@) {
          warn "not successful: $@\n";
          if($try == $tries){
            $self->{status_shm}->updateShm({
              action => "error"
            });
            die "cannot talk to the table after $try tries, giving up\n";
          }
        } else {
          print "table can be controlled again!\ncontinuing scan\n";
          last;
        }
      
      }
    
    }
    
    
    my $delay = $self->{settings}->{time_per_pixel};
    printf("Acquiring PMT counts for %3.2f seconds\n",$delay);
    my $counts = $ro->count(delay => $delay, channel => "signal");
    my $col = $point->{col};
    my $row = $point->{row};
    $points_scanned += 1;
    
    $self->{current_scan}->{data}->[$row]->[$col] = $counts;
    print "recorded counts: $counts\n";
    print "\n\n";
    
    my $status = $self->{status_shm}->lockAndReadShm();
    
    if ($status->{abort}) {
      $status = {
        %$status,
        action => "aborted",
        abort => 0,
        current_col => ($col+1),
        current_row => ($row+1),
        points_scanned => $points_scanned,
        seconds_left => 0
      };
      $self->{status_shm}->writeShm($status);
      $self->{scan_shm}->writeShm($self->{current_scan});
      print ">>> scan was aborted!\n\n";
#       last; # stop the acquisition loop!
      exit;
    } else {
#       my $seconds_left = floor($status->{ETA} * (1 - $row/$status->{rows}));
      my $seconds_left = floor($status->{ETA} * (1 - $points_scanned/$scan_pattern->{number_points}));
      $status = {
        %$status,
        current_col => ($col+1),
        current_row => ($row+1),
        points_scanned => $points_scanned,
        seconds_left => $seconds_left
      };
      $self->{status_shm}->writeShm($status);
    }
    
    # if one row has finished, update the shm (so you can make a plot in the gui)
    unless( $last_row == $row ){
      $self->{scan_shm}->writeShm($self->{current_scan});
    }
    $last_row = $row;
    
  }
  
  $self->{current_scan}->{meta}->{stop_time} = time();
  $self->{current_scan}->{meta}->{stop_timestamp} = strftime("%Y-%m-%d_%H:%M:%S", localtime());
  
  $self->{current_scan}->{meta}->{duration} = hms_string(
    $self->{current_scan}->{meta}->{stop_time} - $self->{current_scan}->{meta}->{start_time} );
  
  
  $self->{scan_shm}->writeShm($self->{current_scan});
  $self->{status_shm}->updateShm({
    action => 'idle',
    seconds_left => 0
  });
  
  print ">>> scan completed!\n\n";
  print ">>> sending report ...\n\n";
  $self->compile_report();
  
  print ">>> homing table\n\n";
  $tc->home();
  print ">>> done!\n\n";
  
  return "";

}

sub scan_ETA { #estimated time to complete a scan
  my $self = shift;
  my %options = @_;
  
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
  my $return_val = $pattern_length/$speed + $number_points*$time_per_pixel;
  if ($options{hms}){
    return hms_string($return_val);
  }
  return $return_val;
  
}

sub scan_status {
  my $self = shift;
  my %options = @_;
  my $json = $options{json};
  my $report = $options{report};
  my $status = $self->{status_shm}->readShm();
  
  $status = { %$status,
    time_left => hms_string($status->{seconds_left}),
    duration  => hms_string($status->{ETA})
  };
  
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
  my %options = @_;
  if ($options{json}) {
    return encode_json $self->{scan_shm}->readShm();
  } else {
    return $self->{scan_shm}->readShm();
  }
}

sub clear_log {
  my $self = shift;
  eval {
    unlink $self->{settings}->{log_file} or die "could not delete log file";
  };
  if ($@) {
    print $@;
    return "";
  }
  print "log file deleted\n";
  return "";
}

sub start_scan {
  my $self= shift;
  my %options = @_;
  #start daemon
  $self->daemon_start() or die "service could not be started (already running?)\n";
  $self->scan_sample(%options);
}

sub record_spectrum {
  my $self= shift;
  my %options = @_;
  my $name = $options{name} || "signal";
  
  #start daemon
  $self->daemon_start() or die "service could not be started (already running?)\n";
  $self->{pmt_ro}->spectral_scan_onesided(
    name => $name
  );
  
  return "";
}

sub home {
  my $self= shift;
  #start daemon
  $self->daemon_start() or die "service could not be started (already running?)\n";
  
  print ">>> homing the table\n\n";
  
  $self->{status_shm}->updateShm({
    action => "homing"
  });
  
  eval {
    $self->{table_control}->home();
  };
  if ($@) {
    warn "could not home table\n";
    warn $@;
    $self->{status_shm}->updateShm({
      action => "error"
    });
  } else {
    $self->{status_shm}->updateShm({
      action => "idle"
    });
    print ">>> homing completed\n";
  }
  
  return "";
}

sub stop_scan {
  my $self= shift;
  $self->{status_shm}->updateShm({abort => 1});
  print "sent stop signal\n";
  return " ";
}

sub scan_to_ascii {
  my $self = shift;
  my %options = @_;
  my $scan = $self->{scan_shm}->readShm();
  my $tc = $self->{table_control};
  
  my $tofile = $options{tofile};
  
  my $sample_rect_x1 = $tc->{settings}->{sample_rect_x1};
  my $sample_rect_x2 = $tc->{settings}->{sample_rect_x2};
  my $sample_rect_y1 = $tc->{settings}->{sample_rect_y1};
  my $sample_rect_y2 = $tc->{settings}->{sample_rect_y2};
  
  my $sample_rect_size_x = $sample_rect_x2 - $sample_rect_x1;
  my $sample_rect_size_y = $sample_rect_y2 - $sample_rect_y1;
  
  my $aperture_dia = $tc->{settings}->{sample_aperture_dia};
  
  my $step_size = $scan->{meta}->{step_size};
  my $cols = $scan->{meta}->{cols};
  my $rows = $scan->{meta}->{rows};
  
  my @rows = ();
  for (my $i=0; $i < $rows; $i++) {
    my @cols = ();
    for (my $j=0; $j < $cols; $j++) {
      my $counts = $scan->{data}->[$i]->[$j];
      push(@cols,$counts);
    }
    push(@rows,join("\t",@cols));
  }
  if(defined($tofile)){
    open(FILE,"> $tofile") or die "cannot open output file $tofile\n";
    print FILE join("\n",@rows);
    close(FILE);
  } else {
    print join("\n",@rows);
  }
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
  
  my $scaler = $svg->group(
      transform => "scale($scale)"
  );
  
  my $tr1 = $scaler->group(
      transform => "translate(0,0)"
    );
    
  for (my $i=0; $i < $rows; $i++) {
    for (my $j=0; $j < $cols; $j++) {
      my $counts = $scan->{data}->[$i]->[$j];
      my ($r,$g,$b) = false_color(
        $counts/$self->{settings}->{time_per_pixel},
        $self->{settings}->{plot_lower_limit},
        $self->{settings}->{plot_upper_limit}
      );
      #= ($i*10,$j*10,$i*$j);
      $tr1->rectangle(
        x => $i*$step_size,
        y => $j*$step_size,
        width => $step_size*1.05,
        height => $step_size*1.05,
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


sub compile_report {

  my $self = shift;
  my %options = @_;
  
  my $timestamp = strftime("%Y-%m-%d_%H:%M:%S", localtime());
  
  my $scan = $self->last_scan();
  my $scan_name        = $scan->{meta}->{scan_name};
  $scan_name =~ s/ /_/g; #remove spaces, they are not nice in filenames;
  
  my $storable = "./report/".$timestamp."_".$scan_name.".storable";
  system("cp /dev/shm/".$self->{scan_shm}->{shmName}." $storable");
  my $dump = "./report/".$timestamp."_".$scan_name.".dump";
  
  my $csv = "./report/".$timestamp."_".$scan_name.".csv";
  my $json = "./report/".$timestamp."_".$scan_name.".json";
  my $svg = "./report/".$timestamp."_".$scan_name.".svg";
  my $xls = $csv.".xls";
  
  
  open(DUMP,"> $dump") or die "cannot open $dump for writing \n";
  print DUMP Dumper($scan);
  close(DUMP);
  
  open(JSON,"> $json") or die "cannot open $json for writing \n";
  print JSON encode_json($scan);
  close(JSON);
  
  $self->scan_to_ascii(tofile => $csv);
  $self->scan_to_svg(svg_file => $svg);
  system("./csv2xls.sh $csv");
  
#   my $start_timestamp = $scan->{meta}->{start_timestamp};
#   my $stop_timestamp  = $scan->{meta}->{stop_timestamp};
#   my $duration        = $scan->{meta}->{duration};
  
  my $mailtext = "Scan has finished\n".Dumper($scan->{meta})."\n";
  
  
  $self->{report}->email(
    text => $mailtext,
    attachments => join(",",($csv,$svg,$xls,$storable,$dump,$json))
  );
  
  return " ";

}





1;
