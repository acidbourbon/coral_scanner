package pmt_ro;


use strict;
use warnings;
use Time::HiRes;
use POSIX qw/strftime/;
use POSIX;
use FileHandle;
use regio;

use misc_subs;
use has_settings;
our @ISA = qw/has_settings/; # assimilate the methods of the has_settings class

## methods

sub new {
  my $class = shift;
  my %options = @_;
  
  my $self = {}; # put tons of default values here (if you wish);
  
  # a lookup table for registers in the FPGA
  $self->{regaddr_lookup} = {
    signal_thresh  => 0,
    veto_thresh    => 1,
    acquisition    => 20,
    signal_counter => 21,
    veto_counter   => 22,
    net_counter    => 23,
    reset_counter  => 24,
    dead_time      => 25
  };
  
  $self->{constants} = {
    DACrange => 65535,
    padiwa_clockrate => 133000000
  };
  
  $self->{settings_file} = "./".__PACKAGE__.".settings";
  
  $self->{default_settings} = { # hard default settings
    tty => "/dev/ttyUSB0",
    baudrate => 115200,
    signal_zero => 0,
    veto_zero => 0,
    is_calibrated => 0,
    dead_time => 265, # corresponds to 2 us dead time
    signal_thresh => 0,
    veto_thresh => 0
  };

  $self->{has_run} = {}; # remember which subs already have run
  
  $self->{settings} = {%{$self->{default_settings}}};
  
  $self  = {
    %$self,
    %options
  };
  bless($self, $class);
  
  return $self;
}




sub setup_regio {
  my $self = shift;
  
  $self->require_run("load_settings");
  
  my $regio_options = {
    tty => $self->{settings}->{tty},
    baudrate => $self->{settings}->{baudrate}
  };
  $self->{regio} = regio->new(%$regio_options);
}


sub apply_device_settings {
  my $self = shift;
  my %options = @_;
  
  $self->require_run("load_settings");
  $self->require_run("setup_regio");
  
  $self->signal_thresh(value => $self->{settings}->{signal_thresh});
  $self->veto_thresh(value => $self->{settings}->{veto_thresh});
  $self->dead_time(value => $self->{settings}->{dead_time});
  return;
}

sub spectral_scan {
  my $self = shift;
  my %options = @_;
  
  $self->require_run("load_settings");
  $self->require_run("setup_regio");
  
  die "device zero offset calibration has to be performed first!\n
  run subroutine zero_calib!\n" unless $self->{settings}->{is_calibrated};
  
  my $start=$options{start};
  my $stop=$options{stop};
  my $bins=$options{bins}||64;
  my $delay=$options{delay}||1;
  my $verbose=$options{verbose};
  
  my $spec_width = $stop-$start;
  my $bin_width = $spec_width/$bins;
  
  my $file = FileHandle->new("./test.dat", 'w');
  
  my $counts;
  my $bin_pos;
  my $spectrum;
  
  print "#bin\t#bin_pos\t#counts\n" if $verbose;
  for (my $i=0; $i<$bins; $i++){
    $self->veto_thresh(value => floor($start+$bin_width*$i) );
    $self->signal_thresh(value => floor($start+$bin_width*($i+1)) );
    $bin_pos = floor($start+$bin_width*($i+0.5));
    $counts = $self->count(channel => "net", delay => $delay);
    $spectrum->{$i} = { 
      counts => $counts,
      bin_pos => $bin_pos
    };
    print "$i\t$bin_pos\t$counts\n" if $verbose;
    print $file "$i\t$bin_pos\t$counts\n";
  }
  return $spectrum;
  
}

sub spectral_scan_onesided {
  my $self = shift;
  my %options = @_;
  
  $self->require_run("load_settings");
  $self->require_run("setup_regio");
  
  die "device zero offset calibration has to be performed first!\n
  run subroutine zero_calib!\n" unless $self->{settings}->{is_calibrated};
  
  my $start=$options{start};
  my $stop=$options{stop};
  my $bins=$options{bins}||64;
  my $delay=$options{delay}||1;
  my $verbose=$options{verbose};
  my $tofile=$options{tofile};
  
  my $file = FileHandle->new("./cumul_spec.dat", 'w');
  
  my $spec_width = $stop-$start;
  my $bin_width = $spec_width/$bins;
  
  my $counts;
  my $bin_pos;
  my $spectrum;
  
  my $cumulation;
  
  print "#bin\t#bin_pos\t#counts\n" if $verbose;
  for (my $i=0; $i<$bins; $i++){
#     $self->veto_thresh(value => floor($start+$bin_width*$i) );
    $self->signal_thresh(value => floor($start+$bin_width*$i) );
    $bin_pos = floor($start+$bin_width*($i+0.5));
    $counts = $self->count(channel => "signal", delay => $delay);
    $spectrum->{$i} = { 
      counts => $counts,
      bin_pos => $bin_pos
    };
    print "$i\t$bin_pos\t$counts\n" if $verbose;
    print $file "$i\t$bin_pos\t$counts\n";
    
  }
  
  $file->close();
  return $spectrum;
  
}

sub signal_thresh {
  # reads or sets signal threshold
  my $self = shift;
  my %options = @_;
  
  $self->require_run("load_settings");
  $self->require_run("setup_regio");
  
  my $value = $options{value};
  
  if(defined($value)){
    #if value is given, write threshold
    $self->write_register(regName => "signal_thresh", value => $value+$self->{settings}->{signal_zero});
    $self->{settings}->{signal_thresh} = $value;
    $self->save_settings();
    return;
  } else {
    #just read threshold
    return $self->read_register(regName => "signal_thresh")-$self->{settings}->{signal_zero};
  }
}

sub veto_thresh {
  # reads or sets signal threshold
  my $self = shift;
  my %options = @_;
  
  $self->require_run("load_settings");
  $self->require_run("setup_regio");
  
  my $value = $options{value};
  
  if($value){
    #if value is given, write threshold
    $self->write_register(regName => "veto_thresh", value => $value+$self->{settings}->{veto_zero});
    $self->{settings}->{veto_thresh} = $value;
    $self->save_settings();
    return;
  } else {
    #just read threshold
    return $self->read_register(regName => "veto_thresh")-$self->{settings}->{veto_zero};
  }
}

sub dead_time {
  # reads or sets signal threshold (the latter is done when value is given)
  # if unit is set (s, ms, us or ns), time is read/set in the given
  # timebase
  my $self = shift;
  my %options = @_;
  
  $self->require_run("load_settings");
  
  my $value = $options{value};
  my $unit = $options{unit}||"cycles";
  
  my $clockrate = $self->{constants}->{padiwa_clockrate};
  
  my $timebase;
  my $clock2time = 1; # if no unit is given, display as cycles
  
  $timebase = 1    if($unit eq "s");
  $timebase = 1e-3 if($unit eq "ms");
  $timebase = 1e-6 if($unit eq "us");
  $timebase = 1e-9 if($unit eq "ns");
  
  if ($timebase) {
    $clock2time = 1/$clockrate/$timebase; # by multiplying with $clock2time
    # you convert a number of clock cycles to a time in the given timebase
  }
  
  if(defined($value)){
    #if value is given, write threshold
    $self->write_register(regName => "dead_time", value => $value/$clock2time);
    $self->{settings}->{dead_time} = $value;
    $self->save_settings();
  } else {
    #just read threshold
    return $self->read_register(regName => "dead_time")*$clock2time;
  }
}

sub zero_calib {
  #calibrates the offset between both comparator inputs
  #please unplug signal input before executing this
  my $self = shift;
  my %options = @_;
  
  $self->require_run("load_settings");
  $self->require_run("setup_regio");
  
  my $iterations = $options{iterations} || 26;
  my $verbose = $options{verbose};
  my $delay = $options{delay} || 0.05;
  my $sub_verbose = 0;
  if($verbose){
    if($verbose > 0){
      $sub_verbose = $verbose - 1;
    }
  }
  
  my $signal_range = $self->signal_range( 
    channel => "signal",
    iterations => $iterations,
    verbose => $sub_verbose,
    delay => $delay,
    use_zero_calib => 0 #ignore previous zero calibration values
  );
  
  my $veto_range = $self->signal_range( 
    channel => "veto",
    iterations => $iterations,
    verbose => $sub_verbose,
    delay => $delay,
    use_zero_calib => 0 #ignore previous zero calibration values
  );
  
  $self->{settings}->{signal_zero} =
    floor(($signal_range->{lower}->{position} + $signal_range->{upper}->{position})/2);
    
  $self->{settings}->{veto_zero} =
    floor(($veto_range->{lower}->{position} + $veto_range->{upper}->{position})/2);
  
  if($verbose){
    print "this procedure should be called when signal input is unplugged!\n";
    print "signal_zero: ".$self->{settings}->{signal_zero}."\n";
    print "veto_zero: ".$self->{settings}->{veto_zero}."\n";
    print "values will be stored in settings file\n";
  }
  #TODO ... check if calibration was successful
    # low signal range, etc ...
  $self->{settings}->{is_calibrated} = 1; # let the world know that calibration was successful
  $self->save_settings();
}

sub count { # count for a given time on a given channel
  # return number of counts
  my $self = shift;
  my %options = @_;
  
  $self->require_run("load_settings");
  $self->require_run("setup_regio");
  
  my $channel = $options{channel}; # can be "signal" or "veto" or "net"
  my $delay   = $options{delay} || 1;
  
  my $tries   = $options{tries} || 3;
  
  my $counter_addr;
  my $threshold_addr;
  
  if( $channel eq "signal" ){
    $counter_addr = $self->{regaddr_lookup}->{signal_counter};
    $threshold_addr = $self->{regaddr_lookup}->{signal_thresh};
  } elsif ( $channel eq "veto" ){
    $counter_addr = $self->{regaddr_lookup}->{veto_counter};
    $threshold_addr = $self->{regaddr_lookup}->{veto_thresh};
  } elsif ( $channel eq "net" ){
    $counter_addr = $self->{regaddr_lookup}->{net_counter};
    $threshold_addr = $self->{regaddr_lookup}->{net_thresh};
  } else {
    die "$channel is not a valid channel!\n possible channels are \"signal\",\"veto\" and \"net\"\n!";
  }
  
  for ( my $try=0; $try < $tries; $try++) {
    $self->{regio}->write($self->{regaddr_lookup}->{acquisition},0); # stop acquisition
    $self->{regio}->read($self->{regaddr_lookup}->{reset_counter}); # reset counter
    $self->{regio}->write($self->{regaddr_lookup}->{acquisition},1); # start acquisition
    Time::HiRes::sleep($delay); # let the counter count
    $self->{regio}->write($self->{regaddr_lookup}->{acquisition},0); # stop acquisition
    my $counts = $self->{regio}->read($counter_addr); # read counter value
#     $self->{regio}->write($self->{regaddr_lookup}->{acquisition},1); # start acquisition
    return $counts if defined($counts);
  }
  die "Padiwa does not answer after $tries tries!\n";

}

sub signal_range { # determine the range and the position the signal/noise in terms of
  # DAC setting
  my $self = shift;
  my %options = @_;
  
  $self->require_run("load_settings");
  $self->require_run("setup_regio");
  
  my $use_zero_calib = 1;
  $use_zero_calib = $options{use_zero_calib} if defined($options{use_zero_calib});
  
  my $channel = $options{channel}; # can be "signal" or "veto"
  # options for find_baseline
    # delay (default 10 ms)
    # verbose (default off)
    # iterations (default 16)
  my $verbose = $options{verbose};
  my $sub_verbose = 0;
  if($verbose){
    if($verbose > 0){
      $sub_verbose = $verbose - 1;
    }
  }
  
  my $counter_addr;
  my $threshold_addr;
  my $zero_calib_offset;
  
  if( $channel eq "signal" ){
    $counter_addr = $self->{regaddr_lookup}->{signal_counter};
    $threshold_addr = $self->{regaddr_lookup}->{signal_thresh};
    $zero_calib_offset = $self->{settings}->{signal_zero};
  } elsif ( $channel eq "veto" ){
    $counter_addr = $self->{regaddr_lookup}->{veto_counter};
    $threshold_addr = $self->{regaddr_lookup}->{veto_thresh};
    $zero_calib_offset = $self->{settings}->{veto_zero};
  } else {
    die "$channel is not a valid channel!\n possible channels are \"signal\" and \"veto\"\n!";
  }
  
  my $range = {};
  

  
  $range->{upper} = $self->find_baseline(
    %options,
    counter_addr => $counter_addr,
    threshold_addr => $threshold_addr,
    boundary => "upper",
    verbose => $sub_verbose);
  
  $range->{lower} = $self->find_baseline(
    %options,
    counter_addr => $counter_addr,
    threshold_addr => $threshold_addr,
    boundary => "lower",
    verbose => $sub_verbose);
  
  if ($use_zero_calib){
    $range->{lower}->{position} = $range->{lower}->{position} - $zero_calib_offset;
    $range->{upper}->{position} = $range->{upper}->{position} - $zero_calib_offset;
  }
  
  $range->{range}->{width} = $range->{upper}->{position} - $range->{lower}->{position};
  $range->{range}->{uncertainty} = $range->{upper}->{uncertainty} + $range->{lower}->{uncertainty};
  
  if ($verbose) {
    
    my $lower = $range->{lower}->{position};
    my $upper = $range->{upper}->{position};
    my $width = $range->{range}->{width};
    
    my $range = $self->{constants}->{DACrange};
    print "\n--------------------------\nscan of signal range, channel $channel\n";
    printf("upper signal/noise boundary: %d (%3.2f%%)\n",$upper,$upper/$range*100);
    printf("lower signal/noise boundary: %d (%3.2f%%)\n",$lower,$lower/$range*100);
    printf("signal/noise width: %d (%3.2f%%)\n",$width,$width/$range*100);
    print("these values are zero calibration offset corrected!\n")
      if $use_zero_calib;
    print "\n--------------------------\n";
  }
  
  return $range;
}

sub find_baseline {
  my $self = shift;
  my %options = @_;
  
  $self->require_run("load_settings");
  $self->require_run("setup_regio");
  
  my $counter_addr   = $options{counter_addr};
  my $threshold_addr = $options{threshold_addr};
  my $boundary       = $options{boundary}        || "lower"; # either upper or lower
  my $iterations     = $options{iterations}      || 16;
  my $verbose        = $options{verbose};
  my $delay          = $options{delay}           || 0.01; #default 10 ms
  
  unless(
    defined($counter_addr) and
    defined($threshold_addr)
  ) { die "missing input parameters!\ncounter_addr, threshold_addr"; }
  
  die "boundary argument must either be \"upper\" or \"lower\"" unless (
    $boundary eq "upper" || $boundary eq "lower" );
  
  my $range = $self->{constants}->{DACrange};
  
  my $upper = $range;
  my $last_upper = $upper;
  my $lower = 0;
  my $last_lower = $lower;
  
  my $position;
  my $uncertainty;
  
  # implementation of a binary search algorithm for the lower/upper noise
  # boundary
  
  for( my $i = 0; $i < $iterations; $i++){
    
    $self->{regio}->write($self->{regaddr_lookup}->{acquisition},0); # stop acquisition
    $self->{regio}->write($threshold_addr,$lower); # go to lower threshold
    Time::HiRes::sleep($delay); # let RC filter settle
    $self->{regio}->read($self->{regaddr_lookup}->{reset_counter}); # reset counter
    $self->{regio}->write($self->{regaddr_lookup}->{acquisition},1); # start acquisition
    $self->{regio}->write($threshold_addr,$upper); # go to upper threshold
    Time::HiRes::sleep($delay); # let RC filter settle
    my $counts = $self->{regio}->read($counter_addr); # look if transition(s) happened
    
    die "Padiwa does not answer!\n" unless defined($counts);
    
    if( $i==0 and $counts==0){
      die "Something is very wrong! No transition was observed as the whole DAC range was covered!\n";
    }
    
    if($verbose){
      print "\n--------------------------\n";
      print "iteration ".($i+1)."/$iterations\n";
      printf("lower threshold: %d (%3.2f%%)\n",$lower,$lower/$range*100);
      printf("upper threshold: %d (%3.2f%%)\n",$upper,$upper/$range*100);
      print "counts: $counts\n";
     
    }
    
    if ($boundary eq "lower") { ## searching for the lower noise boundary
      if($counts){ # transition happened
        last if $i == ($iterations-1);
        $last_upper = $upper;
        $upper = floor(($upper+$lower)/2);
      } else { # no transition
        $lower = $upper;
        $upper = $last_upper;
        last if $i == ($iterations-1);
      }
    } else { # searching for the upper noise boundary
      if($counts){ #transition happened
        last if $i == ($iterations-1);
        $last_lower = $lower;
        $lower = floor(($upper+$lower)/2);
      } else { # no transition
        $upper = $lower;
        $lower = $last_lower;
        last if $i == ($iterations-1);
      }
    }
  }
  
  return {
    position => (floor(($upper+$lower)/2)),
    uncertainty => (ceil(($upper-$lower)/2))
  }  
}

sub read_register {
  my $self = shift;
  my %options = @_;
  
  $self->require_run("load_settings");
  $self->require_run("setup_regio");
  
  my $addr       = $options{addr};
  my $regName    = $options{regName};
  
  if (defined($regName)){
      die "read_register can only accept addr or regName argument!\n" if (defined($addr));
      $addr = $self->{regaddr_lookup}->{$regName};
  }
    
  unless( defined($addr)){
      die "read_register either needs addr or regName argument to access a register\n".
      "possible registers are: \n\n".
      join("\n",keys %{$self->{regaddr_lookup}})."\n\n";
  }
  
  return $self->{regio}->read($addr);
}

sub write_register {
  my $self = shift;
  my %options = @_;
  
  $self->require_run("load_settings");
  $self->require_run("setup_regio");
  
  my $addr       = $options{addr};
  my $regName    = $options{regName};
  my $value      = $options{value};
  
  if (defined($regName)){
      die "read_register can only accept addr or regName argument!\n" if (defined($addr));
      $addr = $self->{regaddr_lookup}->{$regName};
  }
    
  unless( defined($addr)){
      die "read_register either needs addr or regName argument to access a register\n".
      "possible registers are: \n\n".
      join("\n",keys %{$self->{regaddr_lookup}})."\n\n";
  }
  
  unless(defined($value)){
    die "write_register needs a value argument!\n";
  }
  
  $self->{regio}->write($addr,$value);
}






sub help {
  my $self = shift;
  my $verbose = shift;
  print "This is the help message!\n";
#   pod2usage(verbose => $verbose);
  exit;
  
}



1;
