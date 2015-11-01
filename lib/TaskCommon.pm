package TaskCommon;
# Stuff like mappings, etc...

our $CONF = do "../etc/TMCGI.conf";

sub vars
{
  my $statusmap = $CONF->{STATUSMAP};
  my @statusclass = classname_map($statusmap);
  my $prioritymap = $CONF->{PRIORITYMAP};
  my @priorityclass = classname_map($prioritymap);

  my %vars =
  (
    PERCENTMAP=>[ (0,10,20,30,40,50,60,70,80,90,100) ],
    STATUSMAP=>$statusmap,
    PRIORITYMAP=>$prioritymap,
    STATUSCLASSMAP=>{@statusclass},
    PRIORITYCLASSMAP=>{@priorityclass},
  );
  return %vars if wantarray;
  return \%vars if defined wantarray;
}

sub classname_map # Maps a hashref's value into a non-ws, lowercase name.
# For use with number-name mappings, where each has it's own color, etc...
{
  my ($map) = @_;
  my %map = ();
  %map = @$map if ref $map eq 'ARRAY';
  %map = %$map if ref $map eq 'HASH';

  map 
  { 
    my $class = $map{$_};
    $class =~ s/\s+//g;
    ($_, lc($class));
  } keys %map;
}

1;
