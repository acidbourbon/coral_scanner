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



1;