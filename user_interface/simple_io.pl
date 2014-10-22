#!/usr/bin/perl
use strict;
use warnings;
use Device::SerialPort;
use Time::HiRes;
use Getopt::Long;
use POSIX qw/strftime/;
use POSIX;

# plot destination
# check for tools




# defaults
my $baudrate=115200;
my $port;
my $opt_command;
my $read;
my $opt_help;
my $write;


my $ser_dev = "/dev/ttyUSB0";



GetOptions (  'h|help'      => \$opt_help,
              'c|cmd=s'   => \$opt_command,
              'tty=s'     => \$ser_dev,
              'baud=s'    => \$baudrate,
              'r|read=s'  => \$read,
              'w|write=s'  => \$write
            );


init_port();


sub print_help{
print <<EOF;  
simple_io.pl (-r <addr>|-w <addr>_<val>) [OPTIONS]

Simple_io is a tiny utility that allows easy setting and reading
of registers in an FPGA project with Jan Michel's serial interface
register control.

options:

-h, --help                print this help message
-r <addr>                 read from register <addr> (0-255)
-w <addr>_<val>           write value <val> (32 bit integer) to register <addr> (0-255)

--baud <baudrate>         set baudrate for serial interface (default = 115200)
--tty  <device>           set serial interface device (default = /dev/ttyUSB0)

2014 by M. Wiebusch (m.wiebusch\@gsi.de)          
  
EOF
exit;
}



if (defined ($read)) {
  
  my $val = communicate("R".chr($read));
  printf("response: %d\n",$val);

  exit;
}

if (defined ($write)) {
  
  unless( $write =~ m/(\d+)_(\d+)/ ) {
    die "wrong input format\nusage: simple_io.pl -w 127_1234\n";
  } 
  
  my $addr = $1;
  my $value = $2;
  print "addr:$addr value:$value\n";
  
  my $byte3 = chr(int($value)>>24);
  my $byte2 = chr((int($value)>>16)&0xFF);
  my $byte1 = chr((int($value)>>8)&0xFF);
  my $byte0 = chr(int($value)&0xFF);
  
  my $val = communicate("W".chr($addr).$byte3.$byte2.$byte1.$byte0);
  printf("response: %d\n",$val);

  exit;
}


print_help();



sub communicate {

  my $ack_timeout=0.5;

  my $command = $_[0];
#   print "sending command $command\n";
  my $rstring;


  $port->are_match("");
  $port->read_char_time(1);
  $port->read_const_time(0);
  $port->lookclear; 
  #Time::HiRes::sleep(.004);
  $port->write("$command\n");
  
  my $ack = 0;
  
  

  #Time::HiRes::sleep(.004);

  my ($count, $a) = $port->read(12);
  
  if($a=~ m/R(.{4})/s) {
    $rstring= $1;
#           print "padiwa sent: $cmd_echo\n\n";
    $ack=1;
  }
  
  
  
  unless($ack) {
    print "no answer\n";
    return 0; 
  }
  my $byte3 = ord(substr($rstring,0,1));
  my $byte2 = ord(substr($rstring,1,1));
  my $byte1 = ord(substr($rstring,2,1));
  my $byte0 = ord(substr($rstring,3,1));
  my $val = (($byte3<<24)|($byte2<<16)|($byte1<<8)|$byte0);
  
  return $val;
  
  

}






sub init_port {


  # talk to the serial interface

  $port = new Device::SerialPort($ser_dev);
  unless ($port)
  {
    print "can't open serial interface $ser_dev\n";
    exit;
  }

  $port->user_msg('ON'); 
  $port->baudrate($baudrate); 
  $port->parity("none"); 
  $port->databits(8); 
  $port->stopbits(1); 
#   $port->handshake("xoff"); 
  $port->handshake("none"); 
  $port->write_settings;

}



sub getValue {
  my $valName=$_[0];
  my $answer = communicate($valName);
  if($answer =~ m/$valName=([^=]+)/){
    return $1;
  }
  die "could not retrieve desired value $valName!";
}
