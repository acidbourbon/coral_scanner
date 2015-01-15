package table_control;


use strict;
use warnings;
use Time::HiRes;
use POSIX qw/strftime/;
use POSIX;
use Device::SerialPort;

use SVG;

use CGI;

require settings_subs;
require misc_subs;


## methods

sub new {
  my $class = shift;
  my %options = @_;
  
  my $self = {}; # put tons of default values here (if you wish);
  
  $self->{setpos} = { x => undef , y => undef};
  $self->{realpos} = { x => undef , y => undef};
  
  $self->{constants} = {
  };
  
  $self->{settings_file} = "./".__PACKAGE__.".settings";
  
  $self->{default_settings} = { # hard default settings
    tty => "/dev/ttyACM0",
    baudrate => 115200,
    approx_speed => 10, #mm per second,
    size_x => 290,
    size_y => 140,
    table_precision => 0.015, #mm ... 3mm per round, 200 steps per round,
    
    # defines the sample measures/coordinates
    sample_rect_x1 => 2.5,
    sample_rect_x2 => 289.5,
    sample_rect_y1 => 107.5,
    sample_rect_y2 => 124.5,
    # defines the sample raster step size
    sample_step_size => 1,
    sample_aperture_dia => 1,
    
    scan_pattern_svg_file => "./scan_pattern.svg",
    scan_pattern_style => "meander"
    
    
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














sub help {
  my $self = shift;
  my $verbose = shift;
  print "This is the help message!\n";
#   pod2usage(verbose => $verbose);
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

  die "no answer from table\n";
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
  my $answer = $self->communicate();
  
  $self->{realpos}->{x} = $answer->{x_pos};
  $self->{realpos}->{y} = $answer->{y_pos};
  
  return $answer;
  
}

sub go_xy {
  my $self = shift;
  my %options = @_;
  
  $self->require_run("status");
  
  
  my $new_x = (defined $options{x}) ? $options{x} : $self->{setpos}->{x};
  unless( defined($new_x) ){
    $new_x = $self->{realpos}->{x};
  }
  my $old_x = $self->{realpos}->{x};
  my $new_y = (defined $options{y}) ? $options{y} : $self->{setpos}->{y};
  unless( defined($new_y) ){
    $new_y = $self->{realpos}->{y};
  }
  my $old_y = $self->{realpos}->{y};
  
  
  my $dx = $new_x - $old_x;
  my $dy = $new_y - $old_y;
  
  my $longest_movement = max(abs($dx),abs($dy));
  my $travel_time = $longest_movement / $self->{settings}->{approx_speed};
  my $travel_timeout = $travel_time * 1.1 + 1;
  
  echo("go to x=$new_x, y=$new_y");
  $self->send(command => "gx$new_x");
  $self->send(command => "gy$new_y");
  # hier musst du noch weiterarbeiten!
 
  for ( my $i = 0; $i <2; $i++ ){
    my $got_x = 0;
    my $got_y = 0;
    
    my $answer = $self->receive(wait => $travel_timeout);
  
    if($new_x - $answer->{x_pos} < $self->{settings}->{table_precision} 
    || $answer->{xend2_sw} || $answer->{xend1_sw} ){
      $self->{setpos}->{x}  = $new_x;
      $self->{realpos}->{x} = $answer->{x_pos};
      $got_x = 1;
    }
    
    
    if($new_y - $answer->{y_pos} < $self->{settings}->{table_precision} 
    || $answer->{yend2_sw} || $answer->{yend1_sw} ){
      $self->{setpos}->{y}  = $new_y;
      $self->{realpos}->{y} = $answer->{y_pos};
      $got_y = 1;
    }
    
    if($got_x && $got_y){
      if( $answer->{xend2_sw} ){
        warn "hit lower X axis end switch\n";
      }
      if( $answer->{yend2_sw} ){
        warn "hit lower Y axis end switch\n";
      }
      if( $answer->{xend1_sw} ){
        warn "hit upper X axis end switch\n";
      }
      if( $answer->{yend1_sw} ){
        warn "hit upper Y axis end switch\n";
      }
      return $answer;
    }
  
  }
  
  die "could not drive to the desired coordinates";
  
}

sub go_startpoint {
  my $self = shift;
  
  $self->go_xy(
    x => $self->{settings}->{sample_rect_x1},
    y => $self->{settings}->{sample_rect_y1}
  );
}


sub scan_pattern {
  my $self = shift;
  my %options = @_;
  my $style = $options{style} || $self->{settings}->{scan_pattern_style};
  
  $self->require_run("load_settings");
  
  my $sample_rect_x1 = $self->{settings}->{sample_rect_x1};
  my $sample_rect_x2 = $self->{settings}->{sample_rect_x2};
  my $sample_rect_y1 = $self->{settings}->{sample_rect_y1};
  my $sample_rect_y2 = $self->{settings}->{sample_rect_y2};
  my $sample_step_size = $self->{settings}->{sample_step_size};
  
  my $sample_rect_size_x = $sample_rect_x2 - $sample_rect_x1;
  my $sample_rect_size_y = $sample_rect_y2 - $sample_rect_y1;
  
  
  my $steps_in_x = floor($sample_rect_size_x / $sample_step_size) +1;
  my $steps_in_y = floor($sample_rect_size_y / $sample_step_size) +1;
  
  my $coordinate_array = [];
  
  for( my $i = 0; $i < $steps_in_x; $i++ ) {
  
    for( my $j = 0; $j < $steps_in_y; $j++ ) {
      
      if( $style eq "linebyline" ) {
        push(@$coordinate_array,{
          x => $sample_rect_x1 + $i*$sample_step_size,
          row => $i,
          y => $sample_rect_y1 + $j*$sample_step_size,
          col => $j
        });
      } elsif ( $style eq "meander" ) {
        #reverse the y stepping direction every row
        my $y;
        my $col;
        if ( $i % 2 ) {  # is the row number uneven ?
          $col = ($steps_in_y-$j-1);
          $y = $sample_rect_y1 + ($steps_in_y-$j-1)*$sample_step_size; # other direction
        } else {
          $col = $j;
          $y = $sample_rect_y1 + $j*$sample_step_size; # else default direction
        }
        push(@$coordinate_array,{
          x => $sample_rect_x1 + $i*$sample_step_size,
          row => $i,
          y => $y,
          col => $col
        });
      }
    
    }
  
  }
  
  return $coordinate_array;
}

sub scan_pattern_to_svg {

  my $self = shift;
  my %options = @_;
  my $style = $options{style};
  
  $self->require_run("load_settings");
  
  my $scan_pattern = $self->scan_pattern(style => $style);
  
  
  my $sample_rect_x1 = $self->{settings}->{sample_rect_x1};
  my $sample_rect_x2 = $self->{settings}->{sample_rect_x2};
  my $sample_rect_y1 = $self->{settings}->{sample_rect_y1};
  my $sample_rect_y2 = $self->{settings}->{sample_rect_y2};
  
  my $aperture_dia = $self->{settings}->{sample_aperture_dia};
  
  my $mm2pix = 1; # pixels per mm
  
  # create an SVG object with a size of 40x40 pixels
  my $svg = SVG->new(
        -printerror => 1,
        -raiseerror => 0,
        -indent     => '  ',
        -docroot => 'svg', #default document root element (SVG specification assumes svg). Defaults to 'svg' if undefined
        #-sysid      => 'abc', #optional system identifyer 
        #-pubid      => "-//W3C//DTD SVG 1.0//EN", #public identifyer default value is "-//W3C//DTD SVG 1.0//EN" if undefined
        #-namespace => 'mysvg',
        -inline   => 1,
        id          => 'document_element',
  width => 800,
  height => 600,
  );
  
  my $scale = 24;
  
  my $scaler = $svg->group(
      transform => "scale($scale)"
  );
  
  my $group1 = $scaler->group(
      transform => "translate(".(-$sample_rect_x1+$aperture_dia).",".(-$sample_rect_y1+$aperture_dia).")"
    );
  
  $group1->rectangle(
    x => $sample_rect_x1-$aperture_dia/2 ,
    width => ($sample_rect_x2 -$sample_rect_x1)+$aperture_dia,
    y => $sample_rect_y1-$aperture_dia/2 ,
    height => ($sample_rect_y2 - $sample_rect_y1)+$aperture_dia,
    style=>{
          'stroke'=>'black',
          'fill'=>'none',
          'stroke-width'=>5/$scale,
    }
  );
  
  my $lastpoint;
  my $counter=0;
  for my $point (@$scan_pattern) {
    last if ($counter++ > 600);
    
    
    if(1){ 
      $group1->circle(
        cx => $point->{x} ,
        cy => $point->{y} ,
        r => $aperture_dia/2 ,
        style=>{
              'stroke'=>'none',
              'fill'=>'rgb(180,180,180)',
              'stroke-width'=>'0.5',
  #             'stroke-opacity'=>'0.5',
  #             'fill-opacity'=>'0.0'
          }
      );
    }
    
    if( defined ($lastpoint)) {
      $group1->line(
#           id=>'l1.'.$counter++,
          x1=> $lastpoint->{x}, y1=>$lastpoint->{y},
          x2=> $point->{x}    , y2=>$point->{y},
        style=>{
              'stroke'=>'red',
              'fill'=>'none',
              'stroke-width'=> 2/$scale,
  #             'stroke-opacity'=>'0.5',
  #             'fill-opacity'=>'0.0'
          }
      );
    
    }
    
    $lastpoint = $point;
      
  
  }
  

  my $svgfile = $self->{settings}->{scan_pattern_svg_file};
  
  open(SVGFILE, ">".$svgfile);
  # now render the SVG object, implicitly use svg namespace
  print SVGFILE $svg->xmlify;
  close(SVGFILE);
}


sub scan {
  my $self = shift;
  my %options = @_;
  
  my $eval   = $options{eval};
  my $subref = $options{subref};
  
  $self->require_run("load_settings");
  
  for my $point (@{$self->scan_pattern()}) {
    $self->go_xy( x => $point->{x}, y => $point->{y});
    eval $eval  if defined($eval);
    $subref->($point) if defined($subref);
  }
  
}


sub set_zero {
  my $self = shift;
  $self->communicate(command => "z");
}

sub home {
  my $self = shift;
  
  $self->require_run("status");
  
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
    x => $self->{realpos}->{x} -1.1*$self->{settings}->{size_x},
    y => $self->{realpos}->{y} -1.1*$self->{settings}->{size_y}
  );
  
  if (($answer->{xend2_sw} == 1) && ($answer->{xend2_sw} == 1)) { ## did you hit the stop switch?
    $self->set_zero();
    return $answer; # return the last status before reset -> residuals for error checking
  } else {
    die "homing the axes failed!\n";
  }
}

1;
