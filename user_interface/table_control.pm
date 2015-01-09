package table_control;


use strict;
use warnings;
use Time::HiRes;
use POSIX qw/strftime/;
use POSIX;
use Device::SerialPort;

use Storable qw(lock_store lock_retrieve);



## methods

sub new {
  my $class = shift;
  my %options = @_;
  
  my $self = {}; # put tons of default values here (if you wish);
  
  $self->{setpos} = { x => 0, y => 0};
  $self->{realpos} = { x => 0, y => 0};
  
  $self->{constants} = {
  };
  
  $self->{misc} = {
    settings_file => "./table_control.settings"
  };
  
  $self->{default_settings} = { # hard default settings
    tty => "/dev/ttyACM0",
    baudrate => 115200,
    approx_speed => 10, #mm per second,
    size_x => 300,
    size_y => 150,
    table_precision => 0.015*2 #mm ... 3mm per round, 200 steps per round
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

sub require_run {
  my $self    = shift;
  my $subname = shift;
  
  unless($self->{has_run}->{$subname}){
    $self->$subname();
    $self->{has_run}->{$subname} = 1;
  }
}







sub load_settings {
  my $self=shift;
  my $settings_file = $self->{misc}->{settings_file};
  
  if ( -e $settings_file ) {
    $self->{settings} = {%{$self->{settings}}, %{lock_retrieve($settings_file)}};
  }
  return $self->{settings};
}

sub save_settings {
  my $self=shift;
  my %options = @_;
  
  $self->require_run("load_settings");
  
  my $settings_file = $self->{misc}->{settings_file};
  
  $self->{settings} = { %{$self->{settings}}, %options};
  lock_store($self->{settings},$settings_file);
  return $self->{settings}
}

sub reset_settings {
  my $self=shift;
  my $settings_file = $self->{misc}->{settings_file};
  lock_store({},$settings_file);
  $self->{settings} = {%{$self->{default_settings}}};
  return $self->{settings}
}


sub help {
  my $self = shift;
  my $verbose = shift;
  print "This is the help message!\n";
#   pod2usage(verbose => $verbose);
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





sub init_port {
  my $self = shift;
  
  $self->require_run("load_settings");
  
  my $baudrate = $self->{settings}->{baudrate};
  my $tty = $self->{settings}->{tty};
    
  # talk to the serial interface

  $self->{port} = new Device::SerialPort($tty);
  my $port = $self->{port};
  
  unless ($port)
  {
    print "can't open serial interface $tty\n";
    exit;
  }

  $port->user_msg('ON'); 
  $port->baudrate($baudrate); 
  $port->parity("none"); 
  $port->databits(8); 
  $port->stopbits(1); 
  $port->handshake("none"); 
  $port->write_settings;

}

sub send {
  my $self = shift;
  my %options = @_;
  my $command = $options{command} || "";
  
  $self->require_run("init_port");

  my $port = $self->{port};

  $port->lookclear; 
  $port->write("$command\n");

}

sub receive {
  my $self = shift;
  my %options = @_;
  
  my $wait = $options{wait} || 1;
  my $output  = $options{output} || "hash"; 
  
  $self->require_run("init_port");

  my $port = $self->{port};

  $port->are_match("\n");

  # read what has accumulated in the serial buffer
  # do 1 seconds of polling
  for (my $i = 0; ($i<100*$wait) ;$i++) {
    while(my $a = $port->lookfor) {
      $a =~ s/[\r\n]//g;
      if( $a =~ m/x_pos.+y_pos/) { ## discard the standard error string
        
        if ($output eq "plain"){
          return $a;
        } else {
          $a =~ m/x_pos: ([\+\-][ 0-9]{3}\.[0-9]{3})  y_pos: ([\+\-][ 0-9]{3}\.[0-9]{3})  end_sw: (\d)(\d)(\d)(\d)/;
          my $data = {
            x_pos => $1,
            y_pos => $2,
            xend2_sw => $3,
            xend1_sw => $4,
            yend2_sw => $5,
            yend1_sw => $6
          };
          $data->{x_pos} =~ s/[\+\s]//g;
          $data->{y_pos} =~ s/[\+\s]//g;
          return $data;
        }
      }

    } 
      Time::HiRes::sleep(.01);
  }

  die "no answer";
}

sub communicate {

  my $self = shift;
  my %options = @_;
  my $command = $options{command};
  my $wait    = $options{wait};
  #  with parameter output=plain, print plain resonse from board
  #  else split information in a hash
  my $output  = $options{output} || "hash"; 
  
  $self->send(command => $command);
  return $self->receive(wait => $wait, output => $output);
}


sub status {
  my $self = shift;
  $self->communicate();
  
}

sub go_xy {
  my $self = shift;
  my %options = @_;
  
  my $new_x = (defined $options{x}) ? $options{x} : $self->{setpos}->{x};
  my $old_x = $self->{setpos}->{x};
  my $new_y = (defined $options{y}) ? $options{y} : $self->{setpos}->{y};
  my $old_y = $self->{setpos}->{y};
  
  my $dx = $new_x - $old_x;
  my $dy = $new_y - $old_y;
  
  my $longest_movement = max(abs($dx),abs($dy));
  my $travel_time = $longest_movement / $self->{settings}->{approx_speed};
  my $travel_timeout = $travel_time * 1.1 + 1;
  
  echo("go to x=$new_x, y=$new_y");
  $self->send(command => "gx$new_x");
  $self->send(command => "gy$new_y");
  # hier musst du noch weiterarbeiten!
 
  my $answer = $self->receive(wait => $travel_timeout);
  
  
  if(abs($answer->{x_pos} - $new_x) <= $self->{settings}->{table_precision} ){
    $self->{setpos}->{x}  = $new_x;
    $self->{realpos}->{x} = $answer->{x_pos};
  } else {
    print "did not move to correct x position!\n";
  }
  
  if(abs($answer->{y_pos} - $new_y) <= $self->{settings}->{table_precision} ){
    $self->{setpos}->{y}  = $new_y;
    $self->{realpos}->{y} = $answer->{y_pos};
  } else {
    print "did not move to correct y position!\n";
  }
  
  return $answer;
  
}

sub set_zero {
  my $self = shift;
  $self->communicate(command => "z");
}

sub home {
  my $self = shift;
  
  # check if already at the stops, if yes, move away and return again
  my $answer = $self->status();
  if (($answer->{xend2_sw} == 1) && ($answer->{xend2_sw} == 1)) { ## did you hit the stop switch?
    $self->set_zero();
    $answer = $self->go_xy(
      x => 10,
      y => 10
    );
  }
 
  # not homed ... go home
  $answer = $self->go_xy(
    x => -1.2*$self->{settings}->{size_x},
    y => -1.2*$self->{settings}->{size_y}
  );
  
  if (($answer->{xend2_sw} == 1) && ($answer->{xend2_sw} == 1)) { ## did you hit the stop switch?
    return $self->set_zero();
  } else {
    die "homing the axes failed!\n";
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


1;
