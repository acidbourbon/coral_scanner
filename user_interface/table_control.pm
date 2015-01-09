package table_control;


use strict;
use warnings;
use Time::HiRes;
use POSIX qw/strftime/;
use POSIX;
# use CGI ':standard';
# use CGI::Carp qw(fatalsToBrowser);
use Data::Dumper;
# use Pod::Usage;
# use FileHandle;
# use regio;
# use manage_settings;
# use Switch;
use Device::SerialPort;

use Storable qw(lock_store lock_retrieve);



# my $self = this->new();
# $self->main();


## methods

sub new {
  my $class = shift;
  my %options = @_;
  
  my $self = {}; # put tons of default values here (if you wish);
  
  $self->{constants} = {
  };
  
  $self->{misc} = {
    settings_file => "./table_control.settings"
  };
  
  $self->{default_settings} = { # hard default settings
    tty => "/dev/ttyACM0",
    baudrate => 115200,
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

sub communicate {
  my $self = shift;
  my %options = @_;
  my $command = $options{command} || "";
  
  
  $self->require_run("init_port");

  my $port = $self->{port};

  $port->are_match("\n");
  $port->lookclear; 
  $port->write("$command\n");

  # read what has accumulated in the serial buffer
  # do 1 seconds of polling
  for (my $i = 0; ($i<100) ;$i++) {
    while(my $a = $port->lookfor) {
      $a =~ s/[\r\n]//g;
      if( $a =~ m/x_pos.+y_pos/) { ## discard the standard error string
        return $a;
      }

    } 
      Time::HiRes::sleep(.01);
  }

  die "no answer";
}

1;
