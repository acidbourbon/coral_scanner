#!/usr/bin/perl

package this;

=head1 NAME

pmt_ro - configure and read out the photomultiplier hardware

=head1 SYNOPSIS

./pmt_ro action=signal_range channel=(signal|veto)

=head1 DESCRIPTION

Very very easy way to read and write registers in an FPGA with uart_sctrl slow control interface
(written by Jan Michel, part of the padiwa repository)

=head2 Methods

=over 12

=item C<read($addr)>

Returns the contents (32 bit integer) of the register $addr (0-255)

=item C<write($addr,$value)>

Writes $value (32 bit integer) to register $addr (0-255)

=back

=head1 AUTHOR

Michael Wiebusch (m.wiebusch@gsi.de)

=cut



use strict;
use warnings;
use Device::SerialPort;
use Time::HiRes;
use POSIX qw/strftime/;
use POSIX;
use CGI ':standard';
use CGI::Carp qw(fatalsToBrowser);
use Data::Dumper;
use Pod::Usage;
use regio;
use manage_settings;
# use Switch;



my $self = this->new();
$self->main();


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
    reset_counter  => 24
  };
  
  $self->{constants} = {
    DACrange => 65535
  };
  
  $self  = {
    %$self,
    %options
  };
  bless($self, $class);  
  return $self;
}


sub main {
  # go to other methods from here
  my $self = shift;
  
  $self->setup();
  
  my $action = $self->{query}->param('action') || "help";

  # go only to methods that are in the following dispatch table:
  # if associated value is one, sub can be called via CGI
  $self->{dispatch} = {
    help => 1,
    test => 1,
    read_register => 1,
    write_register => 1,
    find_baseline => 1,
    signal_range => 1
  };
  
  # if method exists, execute it, if not complain and show help message
  if ($self->{dispatch}->{$action} ) {
    my $args = $self->CGI_parameters();
    
    # here the corresponding method is called
    my $return = $self->$action(%$args);
    # does it return anything?
    if(defined($return)){ # we get a return value
      if(ref($return) eq "SCALAR"){ # just print it if it is a scalar
        print "$return\n";
      } else { # use Data::Dumper to display a hash
        print "method returns a hash:\n";
        print Dumper $return;
      }
    }
  } else {
    print "$action is not a valid action!\n\n";
    $self->help(1);
  }
}

sub signal_range { # determine the range and the position the signal/noise in terms of
  # DAC setting
  my $self = shift;
  my %options = @_;
  
  my $channel = $options{channel}; # can be "signal" or "veto"
  # options for find_baseline
    # delay (default 10 ms)
    # verbose (default off)
    # iterations (default 16)
  my $verbose = $options{verbose}; # can be "signal" or "veto"
  
  my $counter_addr;
  my $threshold_addr;
  
  if( $channel eq "signal" ){
    $counter_addr = $self->{regaddr_lookup}->{signal_counter};
    $threshold_addr = $self->{regaddr_lookup}->{signal_thresh};
  } elsif ( $channel eq "veto" ){
    $counter_addr = $self->{regaddr_lookup}->{veto_counter};
    $threshold_addr = $self->{regaddr_lookup}->{veto_thresh};
  } else {
    die "$channel is not a valid channel!\n possible channels are \"signal\" and \"veto\"\n!";
  }
  
  my $range = {};
  
  my $sub_verbose = 0;
  if($verbose > 0){
    $sub_verbose = $verbose - 1;
  }
  
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
    print "\n--------------------------\n";
  }
  
  return $range;
}

sub find_baseline {
  my $self = shift;
  my %options = @_;
  
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


sub setup {
  my $self = shift;
  # initialization stuff
  
  # receive CGI query
  $self->{query} = CGI->new(); 
  
  # create new register IO object, with CGI parameters "tty" and "baudrate"
  my $regio_options = $self->CGI_parameters(items => ["tty","baudrate"]);
  $self->{regio} = regio->new(%$regio_options);
}


sub help {
  my $self = shift;
  my $verbose = shift;
#   print "This is the help message!\n";
  pod2usage(verbose => $verbose);
  exit;
  
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


sub CGI_parameters {
  # for each item on the list, get the
  # designated parameter from the CGI query and
  # store it in the target hash IF the parameter is
  # defined in the query!
  
  my $self = shift;
  my %options = @_;
  my $query  = $self->{query};
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



