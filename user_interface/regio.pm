##################################################
##                 register IO                  ##
##################################################

package regio;


=head1 NAME

regio - a module for easy access to FPGA registers via UART interface

=head1 SYNOPSIS

    use regio;
    my $regio = regio->new(tty => "/dev/ttyUSB0", baudrate => "115200");
    
    my $value = $regio->read($addr);
    $regio->write($addr,$value);

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



sub new {
  my $class = shift;
  my %options = @_;
  my $self = {};
  
  # set some defaults
  $self->{baudrate} = 115200;
  $self->{tty}      = "/dev/ttyUSB0";
  
  # partially overwrite defaults with options 
  $self  = {
    %$self,
    %options
  };
  
  bless($self, $class); 
  
  $self->{port} = new Device::SerialPort($self->{tty});
  unless ($self->{port})
  {
    die "can't open serial interface ".$self->{tty}."\n";
  }

  $self->{port}->user_msg('ON'); 
  $self->{port}->baudrate($self->{baudrate}); 
  $self->{port}->parity("none"); 
  $self->{port}->databits(8); 
  $self->{port}->stopbits(1); 
  $self->{port}->handshake("none"); 
  $self->{port}->write_settings;
  
  return $self;
}




sub read {
  my $self = shift;
  my $addr = shift;
  my $val = $self->communicate("R".chr($addr));
  printf("response: %d\n",$val) if $self->{verbose};
  return $val;
}

sub write {
  my $self = shift;
  my $addr = shift;
  my $value = shift;
  
  print "send addr:$addr value:$value\n" if $self->{verbose};
  
  my $byte3 = chr(int($value)>>24);
  my $byte2 = chr((int($value)>>16)&0xFF);
  my $byte1 = chr((int($value)>>8)&0xFF);
  my $byte0 = chr(int($value)&0xFF);
  
  $self->communicate("W".chr($addr).$byte3.$byte2.$byte1.$byte0);
}


sub communicate {
  my $self = shift;
  my $command = shift;
  
  my $ack_timeout=0.5;
  my $rstring;

  $self->{port}->are_match("");
  $self->{port}->read_char_time(1);  # avg time between read char
  $self->{port}->read_const_time(0); # const time for read (milliseconds)
  $self->{port}->lookclear; 
  $self->{port}->write("$command\n");
  
  my $ack = 0;

  my ($count, $a) = $self->{port}->read(12);# blocks until the read is complete or a Timeout occurs. 
  
  if($a=~ m/R(.{4})/s) {
    $rstring= $1;
    $ack=1;
  }
  
  if($ack){
    my $byte3 = ord(substr($rstring,0,1));
    my $byte2 = ord(substr($rstring,1,1));
    my $byte1 = ord(substr($rstring,2,1));
    my $byte0 = ord(substr($rstring,3,1));
    my $val = (($byte3<<24)|($byte2<<16)|($byte1<<8)|$byte0);
    return $val;
  } else {
    print "no answer\n" if $self->{verbose};
  }
}

1;