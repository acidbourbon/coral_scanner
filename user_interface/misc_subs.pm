package misc_subs;
use POSIX;

BEGIN {
  require Exporter;
  # set the version for version checking
  our $VERSION = 1.00;
  # Inherit from Exporter to export functions and variables
  our @ISA = qw(Exporter);
  # Functions and variables which are exported by default
  our @EXPORT = qw(printHeader min max echo require_run test hms_string daemonize false_color);
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

sub daemonize {
  # chdir '/' or die "Can't chdir to /: $!";

  defined(my $pid = fork) or die "Can't fork: $!";
  if($pid){
#     printHeader('text/plain') if $isHttpReq;
    print "this instance has terminated, the other one is a demon now\n";
    exit;
  }
  open STDIN, '/dev/null' or die "Can't read /dev/null: $!";
  open STDOUT, '>>/dev/null' or die "Can't write to /dev/null: $!";
  open STDERR, '>>/dev/null' or die "Can't write to /dev/null: $!";
  POSIX::setsid or die "Can't start a new session: $!";
  umask 0;
}

sub false_color {
  my $val = shift;
  my $bot = shift;
  my $top = shift;
  
  my $c = floor( abs($val/($top-$bot))*255);
  return ($c,$c,$c);

}


1;