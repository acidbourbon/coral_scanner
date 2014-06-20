#!/usr/bin/perl
use strict;
use warnings;
use Device::SerialPort;
use Time::HiRes;
use Getopt::Long;
use POSIX qw/strftime/;

# plot destination
# check for tools




# defaults
my $baudrate=115200;
my $port;


my $ser_dev = "/dev/ttyUSB0";



init_port();

for (my $i=0;$i<128;$i++){
  my $rstring = communicate("R".chr($i));
#   printf ("length of response: %d \n",length($rstring));


  my $byte3 = ord(substr($rstring,0,1));
  my $byte2 = ord(substr($rstring,1,1));
  my $byte1 = ord(substr($rstring,2,1));
  my $byte0 = ord(substr($rstring,3,1));
  my $val = (($byte3<<24)|($byte2<<16)|($byte1<<8)|$byte0);
  printf("%d\t%d\n",$i,$val);
#   printf("addr %d:\t%d.%d.%d.%d\n",$i,$byte3,$byte2,$byte1,$byte0);
#       Time::HiRes::sleep(.01);
}




sub communicate {

  my $ack_timeout=0.5;

  my $command = $_[0];
#   print "sending command $command\n";
  my $cmd_echo;


  $port->are_match(chr(10));
  $port->lookclear; 
  $port->write("$command\n");
  
  my $ack = 0;




ACK_POLLING:  for (my $i = 0; ($i<$ack_timeout*100) ;$i++) {
#     print $i."\n";
    while(my $a = $port->lookfor) {
        if($a=~ m/R(....)/) {
          $cmd_echo = $1;
#           print "padiwa sent: $cmd_echo\n\n";
          $ack=1;
          last ACK_POLLING;
        }

    } 
      Time::HiRes::sleep(.01);

  }
  
  unless($ack) {
    print "no answer\n";
    return "0";
  }
  
  return $cmd_echo;
  
  

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
  $port->handshake("xoff"); 
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
