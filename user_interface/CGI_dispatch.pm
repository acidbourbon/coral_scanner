package CGI_dispatch;

use strict;
use warnings;
use Data::Dumper;
use CGI ':standard';
use CGI::Carp qw(fatalsToBrowser);

my $query;


sub dispatch_sub {


  my $self = shift;
  my $dispatch_table = shift;
  
  $query = CGI->new();

  my $sub = $query->param('sub') || "help";

  # if method exists in dispatch table, execute it, if not complain and show help message
  # if there is no dispatch table, allow execution of every sub
  if ( not(defined ($dispatch_table)) or $dispatch_table->{$sub}) {
    my $args = CGI_parameters();
    
    # do not pass the "sub=..." parameters to the called sub
    delete $args->{"sub"};
    
    # here the corresponding method is called
    my $return = $self->$sub(%$args);
    # does it return anything?
    if(defined($return)){ # we get a return value
      if(ref(\$return) eq "SCALAR"){ # just print it if it is a scalar
        print "$return\n";
      } else { # use Data::Dumper to display a hash
        print "sub returns a hash:\n";
        print Dumper $return;
      }
    }
  } else {
    print "$sub is not a valid sub!\n\n";
    $self->help(1);
  }

}

sub CGI_parameters {
  # for each item on the list, get the
  # designated parameter from the CGI query and
  # store it in the target hash IF the parameter is
  # defined in the query!
  
  my %options = @_;
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

1;
