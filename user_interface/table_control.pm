package table_control;


use strict;
use warnings;
use Time::HiRes;
use POSIX qw/strftime/;
use POSIX;
use Device::SerialPort;

use SVG;

use CGI;

# use has_settings;
# our @ISA = qw/has_settings/; # assimilate the methods of the has_settings class
use misc_subs;
use has_settings;
our @ISA = qw/has_settings/; # assimilate the methods of the has_settings class

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
    
    scan_pattern_style => "meander",
    rows_to_scan => 10,
    mm_to_scan   => 10
    
    
  };
  
  $self->{settings_desc} = {
    tty => "The address of the serial device (COMPORT) of the linear table",
    baudrate => "Baudrate (bits/second) setting of the serial device (tty) of the linear table",
    approx_speed => "Approximate speed of the linear table in mm/sec. Value is used to estimate timeouts",
    size_x => "Length/travel of the linear table x axis in mm",
    size_y => "Length/travel of the linear table y axis in mm",
    table_precision => "Precision of the linear table in mm/step",
    
    sample_rect_x1 => "x start coordinate of sample area in mm",
    sample_rect_x2 => "x end coordinate of sample area in mm",
    sample_rect_y1 => "y start coordinate of sample area in mm",
    sample_rect_y2 => "y end coordinate of sample area in mm",
    sample_step_size => "The step size/width for the scan pattern in mm",
    sample_aperture_dia => "Estimate of the radiation aperture in mm",
    
    scan_pattern_style => "Defines the scan modus, available options are 'linebyline' and 'meander'",
    rows_to_scan => "number of rows the device must scan, if set to 0 then scan the whole sample"
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














sub help {
  my $self = shift;
  my $verbose = shift;
  print "This is the help message!\n";
#   pod2usage(verbose => $verbose);
  exit;
  
}



sub init_port {
  my $self = shift;
  
  #$self->require_run("load_settings");
  
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
  
    if(abs($new_x - $answer->{x_pos}) < $self->{settings}->{table_precision} 
    || $answer->{xend2_sw} || $answer->{xend1_sw} ){
      $self->{setpos}->{x}  = $new_x;
      $self->{realpos}->{x} = $answer->{x_pos};
      $got_x = 1;
    }
    
    
    if(abs($new_y - $answer->{y_pos}) < $self->{settings}->{table_precision} 
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
  print "attempting to go to the scan startpoint\n";
  $self->go_xy(
    x => $self->{settings}->{sample_rect_x1},
    y => $self->{settings}->{sample_rect_y1}
  );
}


sub scan_pattern {
  my $self = shift;
  my %options = @_;
  my $style = $options{style} || $self->{settings}->{scan_pattern_style};
  
  #$self->require_run("load_settings");
  
  my $sample_rect_x1 = $self->{settings}->{sample_rect_x1};
  my $sample_rect_x2 = $self->{settings}->{sample_rect_x2};
  my $sample_rect_y1 = $self->{settings}->{sample_rect_y1};
  my $sample_rect_y2 = $self->{settings}->{sample_rect_y2};
  my $sample_step_size = $self->{settings}->{sample_step_size};
  
  my $sample_rect_size_x = $sample_rect_x2 - $sample_rect_x1;
  my $sample_rect_size_y = $sample_rect_y2 - $sample_rect_y1;
  
  
  my $steps_in_x = floor(min($sample_rect_size_x,$self->{settings}->{mm_to_scan}) / $sample_step_size) +1;
  $steps_in_x = min($steps_in_x,  $self->{settings}->{rows_to_scan} );
  my $steps_in_y = floor($sample_rect_size_y / $sample_step_size) +1;
  
  my $coordinate_array = [];
  
  for( my $i = 0; $i < $steps_in_x; $i++ ) {
  
    for( my $j = 0; $j < $steps_in_y; $j++ ) {
      
      if( $style eq "linebyline" ) {
        push(@$coordinate_array,{
          x => $sample_rect_x1 + $i*$sample_step_size,
          row => $i,
          y => $sample_rect_y1 + $j*$sample_step_size,
          col => $j,
          x_rel => $i*$sample_step_size,
          y_rel => $j*$sample_step_size
        });
      } elsif ( $style eq "meander" ) {
        #reverse the y stepping direction every row
        my $y;
        my $y_rel;
        my $col;
        if ( $i % 2 ) {  # is the row number uneven ?
          $col = ($steps_in_y-$j-1);
        } else {
          $col = $j;
        }
        push(@$coordinate_array,{
          x => $sample_rect_x1 + $i*$sample_step_size,
          row => $i,
          y => $sample_rect_y1 + $col*$sample_step_size,
          col => $col,
          x_rel => $i*$sample_step_size,
          y_rel => $col*$sample_step_size
        });
      }
    
    }
  
  }
  
  return { points => $coordinate_array, cols => $steps_in_y, rows => $steps_in_x, number_points => scalar(@$coordinate_array) };
}

sub scan_pattern_to_svg {

  my $self = shift;
  my %options = @_;
  my $html_tag = $options{html_tag};
  my $svg_file = $options{svg_file};
  
  my $scan_pattern = $self->scan_pattern();
  
  
  my $sample_rect_x1 = $self->{settings}->{sample_rect_x1};
  my $sample_rect_x2 = $self->{settings}->{sample_rect_x2};
  my $sample_rect_y1 = $self->{settings}->{sample_rect_y1};
  my $sample_rect_y2 = $self->{settings}->{sample_rect_y2};
  
  my $sample_rect_size_x = $sample_rect_x2 - $sample_rect_x1;
  my $sample_rect_size_y = $sample_rect_y2 - $sample_rect_y1;
  
  my $aperture_dia = $self->{settings}->{sample_aperture_dia};
  
  my $scale = 12; # pixel per mm
  
  # create an SVG object with a size of 40x40 pixels
  
  my $pic_width  = ($sample_rect_size_x+5)*$scale;
  my $pic_height = 250;
  
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
    width => $pic_width,
    height => $pic_height,
  );
  
  
  my $scaler = $svg->group(
      transform => "scale($scale)"
  );
  
  my $translate1 = $scaler->group(
      transform => "translate($aperture_dia,$aperture_dia)"
    );
    
  for(my $x=0; $x<=$sample_rect_size_x; $x+=5) {
  
    $translate1->line(
         x1=> $x, y1=>$sample_rect_size_y + ( ($x % 10) ? 2 : 1 ),
         x2=> $x, y2=>$sample_rect_size_y+3,
       style=>{
             'stroke'=>'black',
             'fill'=>'none',
             'stroke-width'=> 1/$scale,
  #            'stroke-opacity'=>'0.5',
  #            'fill-opacity'=>'0.0'
         }
     );
     
    unless($x % 10){
     $translate1->text(
         x=>$x+0.2, y=>$sample_rect_size_y+2.5,
         style => 'font-size: 1.5px',
     )->cdata($x);
    }
  }
  
  if(1){
    $translate1->rectangle(
      x => -$aperture_dia/2 ,
      width => $sample_rect_size_x+$aperture_dia,
      y => -$aperture_dia/2 ,
      height => $sample_rect_size_y+$aperture_dia,
      style=>{
            'stroke'=>'black',
            'fill'=>'white',
            'stroke-width'=>5/$scale,
      }
    );
  };
  
  my $lastpoint;
  my $counter=0;
  for my $point (@{$scan_pattern->{points}}) {
    
    last if (
      ($point->{x_rel})*$scale > $pic_width
    );
#     last if (
#       $point->{row} >= $self->{settings}->{rows_to_scan}
#     );
    
    
    if(1){ 
      $translate1->circle(
        cx => $point->{x_rel} ,
        cy => $point->{y_rel} ,
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
      $translate1->line(
#           id=>'l1.'.$counter++,
          x1=> $lastpoint->{x_rel}, y1=>$lastpoint->{y_rel},
          x2=> $point->{x_rel}    , y2=>$point->{y_rel},
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
  
  if (defined($svg_file)){
    open(SVGFILE, ">".$svg_file) or die "could not open $svg_file for writing!\n";
    # now render the SVG object, implicitly use svg namespace
    print SVGFILE $svg->xmlify;
    close(SVGFILE);
  } else {
    print "<svg width=$pic_width height=$pic_height>" if $html_tag;
    print $svg->xmlify;
    print "</svg>" if $html_tag;
  }
  
  return " ";
}


# sub scan {
#   my $self = shift;
#   my %options = @_;
#   
#   my $scan_pattern = $options{scan_pattern};
#   unless(defined($scan_pattern)) {
#     $scan_pattern = $self->scan_pattern();
#   }
#   
#   my $eval   = $options{eval};
#   my $subref = $options{subref};
#   
#   my $method = $options{method};
#   my $object = $options{object};
#   
#   
#   for my $point (@{$scan_pattern->{points}}) {
#   
#     
#     $self->go_xy( x => $point->{x}, y => $point->{y});
#     eval $eval  if defined($eval);
#     $subref->($point) if defined($subref);
#     if(defined($object) && defined($method)){
#       $object->$method($point);
#     }
#   }
#   
# }


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
