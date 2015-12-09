package report;


use strict;
use warnings;
use POSIX qw/strftime/;
use POSIX;


use Net::SMTP::SSL;
use MIME::Base64 qw( encode_base64 );

use File::Basename;

use misc_subs;
use has_settings;
our @ISA = qw/has_settings/; # assimilate the methods of the has_settings class

## methods

sub new {
  my $class = shift;
  my %options = @_;
  
  my $self = {}; # put tons of default values here (if you wish);
  
  $self->{constants} = {
  };
  
  $self->{settings_file} = "./".__PACKAGE__.".settings";
  
  $self->{default_settings} = { # hard default settings
    recipients => "",
    from => "",
    sender_address => "",
    sender_password => "",
    subject => "Coral Scan finished",
    smtp_server => "smtp.sth.sth",
    smtp_port => "465",
  };
  
  $self->{settings_desc} = {
    recipients => "A comma separated list of email addresses of people who are to receive a confirmation
    and the data when a scan has finished.",
    from => "The displayed address of the sender",
    sender_address => "Email address of account which is used to send the confirmation email.",
    sender_password => "Password of the account which is used to send the confirmation email.",
    subject => "Confirmation email subject",
    smtp_server => "Outgoing mail server (SMTP)",
    smtp_port => "The port of the outgoing SMTP connection",
  };

  $self->{has_run} = {}; # remember which subs already have run
  
  $self->{settings} = {%{$self->{default_settings}}};
  
  $self  = {
    %$self,
    %options
  };
  bless($self, $class);
  $self->load_settings();
  
  return $self;
}


sub email {
  
  my $self = shift;
  my %options = @_;
  
  my $to = $self->{settings}->{recipients};
  $to =~ s/\s//g;
  my @recipients = split(',',$to);
  
  my $attch_list = $options{attachments} || "";
  $attch_list =~ s/\s//g;
  my @attachments = split(',',$attch_list);
  
  my $text = $options{text} || "";
  
  my $account = $self->{settings}->{sender_address};
  my $password = $self->{settings}->{sender_password};
  
  my $boundary = 'frontier';
  
  for my $recipient (@recipients) {
  
    my $smtp = Net::SMTP::SSL->new(
    Host => $self->{settings}->{smtp_server},
    Port => $self->{settings}->{smtp_port},
    Timeout => 120
    ); # connect to an SMTP server
    die "Couldn't open connection: $!" if (!defined $smtp );
    
    
    $smtp->auth($account,$password);
    $smtp->mail( $account ); # use the sender's address here
    $smtp->to( $recipient ); # recipient's address
    $smtp->data(); # Start the mail
    # Send the header.
    $smtp->datasend("To: $recipient\n");
    $smtp->datasend("From: ".$self->{settings}->{from}."\n");
    $smtp->datasend("Subject: ".$self->{settings}->{subject}."\n");

    $smtp->datasend("MIME-Version: 1.0\n");
    $smtp->datasend("Content-type: multipart/mixed;\n\tboundary=\"$boundary\"\n");
    $smtp->datasend("\n");
    $smtp->datasend("--$boundary\n");
    $smtp->datasend("Content-type: text/plain\n");
    $smtp->datasend("Content-Disposition: quoted-printable\n");
#     $smtp->datasend("\nToday\'s files are attached:\n");
#     $smtp->datasend("\nHave a nice day! :)\n");
    $smtp->datasend("\n".$text."\n");
    $smtp->datasend("--$boundary\n");

    for my $attachBinaryFile (@attachments) {
      my $attachBinaryFileName = (fileparse($attachBinaryFile))[0] ;
      $smtp->datasend("Content-Type: binary; name=\"$attachBinaryFileName\"\n");
      $smtp->datasend("Content-Transfer-Encoding: base64\n");
      $smtp->datasend("Content-Disposition: attachment; filename=\"$attachBinaryFileName\"\n");
      $smtp->datasend("\n");
      my $buf;
      open(DAT, "$attachBinaryFile") || die("Could not open binary file!");
        binmode(DAT);
      #    local $/=undef;
        while (read(DAT, my $picture, 4096)) {
            $buf = &encode_base64( $picture );
            $smtp->datasend($buf);
        }
      close(DAT);
      $smtp->datasend("\n");
      $smtp->datasend("--$boundary\n");
    }

    $smtp->dataend(); # Finish sending the mail
    $smtp->quit; # Close the SMTP connection
  }



}











sub help {
  my $self = shift;
  my $verbose = shift;
  print "This is the help message!\n";
#   pod2usage(verbose => $verbose);
  exit;
  
}



1;
