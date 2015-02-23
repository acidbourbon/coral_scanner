package misc_subs;
use POSIX;
use Proc::Daemon;

use IO::Handle;

BEGIN {
  require Exporter;
  # set the version for version checking
  our $VERSION = 1.01;
  
  # revision history
  # v1.01
  #     removed daemonize
  #     added daemon_start/stop/status based on Proc::Daemon
  
  # Inherit from Exporter to export functions and variables
  our @ISA = qw(Exporter);
  # Functions and variables which are exported by default
  our @EXPORT = qw(
    printHeader
    min
    max
    echo
    require_run
    test hms_string
    false_color
    daemon_start
    daemon_stop
    daemon_status
  );
  # Functions and variables which can be optionally exported
  #our @EXPORT_OK = qw($Var1 %Hashit func3);
}

sub test {
  my $self = shift;
  my %options = @_;
  print "This is the test message!\n";
  print "The test routine has received the following options:\n\n";
  
  for my $item ( keys %options ) {
    print "key: $item\tvalue: ".$options{$item}."\n";
  }
  exit;
  
}

sub require_run {
  my $self    = shift;
  my $subname = shift;
  
  unless($self->{has_run}->{$subname}){
    $self->$subname();
    $self->{has_run}->{$subname} = 1;
  }
}

# simple subs

sub echo {
  print shift."\n";
}

sub max {
  my ($x,$y) = @_;
  return $x >= $y ? $x : $y;
}
sub min {
  my ($x,$y) = @_;
  return $x <= $y ? $x : $y;
}

sub printHeader {
  my $type = shift @_;
  if ($ENV{'SERVER_SOFTWARE'} =~ /HTTPi/i) {
    print "HTTP/1.0 200 OK\n";
    print "Content-type: $type\r\n\r\n";
  }
  else {
    print "Content-type: $type\n\n";
  }
}

sub hms_string {
  my $s = shift;
  
  my $hours = floor($s/3600);
  my $mins  = floor($s/60)-$hours*60;
  my $secs  = floor($s)-$hours*3600-$mins*60;
  
  my $string = "";
  $string .= $hours." h, " if $hours;
  $string .= $mins." m, " if $mins;
  $string .= $secs." s";
  return $string;
}



sub false_color {
  my $val = shift;
  my $bot = shift;
  my $top = shift;
  
  my $c = min(255,max(0,floor( ($val-$bot)/($top-$bot)*255)));
  return ($c,$c,$c);

}



sub daemon_start{

  my $self = shift;
  my $pf = $self->{settings}->{pid_file};
  my $log = $self->{settings}->{log_file};
  my $daemon = Proc::Daemon->new(
      pid_file => $pf,
      work_dir => "./",
  );
  
  my $pid = $daemon->Status($pf);
  
  if ($pid) {
      print "Background service already running with pid $pid.\n";
      return;
  } else {
      print "Not running. Starting background service\n";
      $daemon->Init;
      open(LOG,"+>>$log");
      *STDERR = *LOG;
      *STDOUT = *LOG;
      LOG->autoflush;
      return 1;
  }
}

sub daemon_stop {
  my $self = shift;
  my $pf = $self->{settings}->{pid_file};
  my $daemon = Proc::Daemon->new(
      pid_file => $pf,
      work_dir => "./",
  );
  my $pid = $daemon->Status($pf);

  if ($pid) {
      print "Stopping pid $pid...\n";
      if ($daemon->Kill_Daemon($pf)) {
          print "Successfully stopped.\n";
      } else {
          print "Could not find $pid.  Was it running?\n";
      }
    } else {
          print "Not running, nothing to stop.\n";
    }
}

sub daemon_status {
  my $self = shift;
  my $pf = $self->{settings}->{pid_file};
  my $daemon = Proc::Daemon->new(
      pid_file => $pf,
      work_dir => "./",
  );
  my $pid = $daemon->Status($pf);

    if ($pid) {
        print "Running with pid $pid.\n";
    } else {
        print "Not running.\n";
    }
  return $pid;
}



1;