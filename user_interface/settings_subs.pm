
use Storable qw(lock_store lock_retrieve);
require misc_subs;

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
  return $self->{settings}
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
  my $settings = $self->load_settings();

  printHeader('text/html');
  
  print '
<style>
.hidden {
  visibility:collapse
}
</style>

  
<form action="table_control.pl" method="get">
  <input type="text" name="sub" value="save_settings" class="hidden"><br>
  <table>
  ';
  
  for my $key ( sort(keys %$settings) ) {
    my $value = $settings->{$key};
    print "<tr><td align=right>$key :</td>";
    print "<td><input type='text' name='$key' value='$value'></td></tr>";
  }

print '

  </table><input type="submit" value="save settings">
</form>


';
  return 1;

}


1;