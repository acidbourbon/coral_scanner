package shm_manager;


use strict;
use warnings;
use POSIX;

use Storable qw(lock_store lock_retrieve fd_retrieve nstore_fd);
use Fcntl qw(:DEFAULT :flock);

sub new {
  my $class = shift;
  my %options = @_;
  my $self  = {
    %options
  };
  
  die "shm_manager must get an shmName" unless defined($self->{shmName});
  
  $self->{shmFile} = "/dev/shm/".$self->{shmName};
#   $self->{dataDir} = $self->{shmFile}."_data";
#   $self->{dataFile} = $self->{dataDir}."/data";
  
  $self->{shmFhLocked} = 0;
  bless($self, $class);
}


sub initShm {
  my $self = shift;
  unless($self->existShm()){
    $self->createShm();
  }

}

sub existShm {
  my $self = shift;
  return 1 if( -e $self->{shmFile} );
  return 0;
}

sub createShm {
  my $self = shift;
  die "shm ".$self->{shmFile}." already exists!\n" if( -e $self->{shmFile} );
  
  lock_store({},$self->{shmFile});
#   die "data directory ".$self->{dataDir}." already exists!\n" if( -e $self->{dataDir} );
#   mkdir $self->{dataDir};
};


sub deleteShm {
  my $self = shift;
  unlink $self->{shmFile};
  system("rm -rf ".$self->{dataDir});
}

sub readShm {
  my $self = shift;
  
  if ( -e $self->{shmFile} ){
    return lock_retrieve($self->{shmFile});
  } else {
    die "shm does not exist!";
  }
}

sub lockAndReadShm {
  my $self = shift;
  
  if ( -e $self->{shmFile} ){
    die "Shm file handle already open and locked!\n" if $self->{shmFhLocked};
    sysopen(my $fh, $self->{shmFile}, O_RDWR|O_CREAT, 0666) 
        or die "can't open shm file: $!";
    flock($fh, LOCK_EX)           or die "can't lock shm file: $!";
    $self->{shmFhLocked} = 1;
    $self->{shmFh} = $fh; # store file handle in object
    # attention! file handle is now still open!
    return fd_retrieve(*$fh);
  } else {
    die "shm does not exist!";
  }
}

## deprecated

# sub writeShm {
#   my $self = shift;
#   my $shmHash = shift;
#   if ( -e $self->{shmFile} ){
#     lock_store($shmHash,$self->{shmFile});
#   } else {
#     die "shm does not exist!\n";
#   }
# }

sub writeShm { # closes and unlocks shm file if already open
  my $self = shift;
  my $shmHash = shift;
  
  if ( -e $self->{shmFile} ){
    my $fh=$self->{shmFh};
    #check if file handle still open and locked
    unless($self->{shmFhLocked}){
      print "found locked shm from previous lock-and-read\n";
      sysopen($fh, $self->{shmFile}, O_RDWR|O_CREAT, 0666) 
          or die "can't open shm file: $!";
      flock($fh, LOCK_EX)           or die "can't lock shm file: $!";
    }
    #in any case, store your hash in shm file 
    seek($fh,0,0);
    nstore_fd($shmHash, *$fh)
        or die "can't store hash\n";
    truncate($fh, tell($fh));
    close($fh);
    $self->{shmFhLocked} = 0;# mark file handle as unlocked
    return $shmHash; 
  } else {
    die "shm does not exist!";
  }
}



sub updateShm {
  my $self = shift;
  my $shmHash = shift;
  
  my $oldShmHash = $self->lockAndReadShm();
  my $compositeShmHash = {%$oldShmHash,%$shmHash};
  $self->writeShm($compositeShmHash);
  return $compositeShmHash;
}


1;