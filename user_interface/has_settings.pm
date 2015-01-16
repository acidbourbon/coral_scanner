package has_settings;
use Storable qw(lock_store lock_retrieve);
use misc_subs;





sub load_settings {
  my $self=shift;
  my $settings_file = $self->{settings_file};
  
  if ( -e $settings_file ) {
    $self->{settings} = {%{$self->{settings}}, %{lock_retrieve($settings_file)}};
  }
  return $self->{settings};
}

sub save_settings {
  my $self=shift;
  my %options = @_;
  
  $self->require_run("load_settings");
  
  my $settings_file = $self->{settings_file};
  
  $self->{settings} = { %{$self->{settings}}, %options};
  lock_store($self->{settings},$settings_file);
  print "settings were saved!\n";
  return $self->{settings};
}

sub reset_settings {
  my $self=shift;
  my $settings_file = $self->{settings_file};
  lock_store({},$settings_file);
  $self->{settings} = {%{$self->{default_settings}}};
  return $self->{settings}
}


sub settings_form {
  my $self=shift;
  my %options=@_;
  my $settings = $self->load_settings();
  my $settings_desc = $self->{settings_desc};
  
  my $header=$options{header};

  printHeader('text/html') if $header;
  
  print '
<style>
.hidden {
  display:none;
}

span.dropt {border-bottom: thin dotted; background: #ffeedd;}
span.dropt:hover {text-decoration: none; background: #ffffff; z-index: 6; }
span.dropt span {position: absolute; left: -9999px;
  margin: 20px 0 0 0px; padding: 3px 3px 3px 3px;
  border-style:solid; border-color:black; border-width:1px; z-index: 6;}
span.dropt:hover span {left: 2%; background: #ffffff;} 
span.dropt span {position: absolute; left: -9999px;
  margin: 4px 0 0 0px; padding: 3px 3px 3px 3px; 
  border-style:solid; border-color:black; border-width:1px;}
span.dropt:hover span {margin: 20px 0 0 170px; background: #ffffff; z-index:6;} 

</style>

  
<form action="'.ref($self).'.pl" method="get" target="_blank">
  <input type="text" name="sub" value="save_settings" class="hidden"><br>
  <table>
  ';
  
  for my $key ( sort(keys %$settings) ) {
    my $value = $settings->{$key};
    print "<tr><td align=right><span class=dropt>$key :";
    
    print "<span style=\"width:300px;\" >".$settings_desc->{$key}."</span></span></td>";
    print "<td><input type='text' name='$key' value='$value'></td></tr>";
  }

print '
  <tr><td></td><td>
  <input type="submit" value="save settings"></td>
  </table>
</form>


';
  return " ";

}


1;