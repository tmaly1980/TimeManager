package MalyConf;
# Handles I/O of configuration files (perl data structs)

use MalyVar;
use Data::Dumper ();

our $ERROR = undef;

sub new # We MAY be writing to a file for the first time!
{
  my ($this, $prefix, $key, $required) = @_;
  my $class = ref($this) || $this;
  my $self = bless {}, $class;

  # We can span multiple files and merge it in memory, then dump back to the original files

  $self->{PREFIX} = $prefix;
  $self->{KEY} = $key; # The main key, for all display purposes

  $prefix =~ s/[.]conf$//i;
  my $file = "$prefix.conf";

  my $data = do $file;
  die("$file: $!") if (not $data and $required);

  # Now load all auxiliary files. ONLY makes sense when main file is a hashref

  my @aux_files = <$prefix/*.conf>;
  my @aux_keys = map { m{$prefix/(.+)[.]conf$}; $1; } @aux_files;
  for (my $i = 0; $i < @aux_files; $i++)
  {
    my $aux_file = $aux_files[$i];
    my $aux_data = do $aux_file;
    my $aux_key = $aux_keys[$i];
    $data->{uc $aux_key} = $aux_data;
  }
  $self->external(@aux_keys);

  $self->{DATA} = { $key => $data };

  return $self;
}

sub external # Gets/Sets keys that map to a separate file name.
{
  my ($self, @keys) = @_;
  $self->{EXT_KEYS} = \@keys if @keys;
  my $ext_keys = $self->{EXT_KEYS};
  my @ext_keys = ref $ext_keys eq 'ARRAY' ? @$ext_keys : ();
  return @ext_keys if wantarray;
  return $ext_keys if defined wantarray;
}

sub get # If does not start with $self->{KEY}, put it there!
{
  my ($self, @args) = @_;
  if (not @args)
  {
    return $self->list if wantarray;
    return $self->ref if defined wantarray;
  }

  @args = map { /^$self->{KEY}/ ?  $_ : "$self->{KEY}$_" } @args;
  my @values = ();
  if (@args == 1)
  {
    my $value = MalyVar->var_evaluate($self->{DATA}, $args[0]);
    if (wantarray and ref $value)
    {
      return %$value if ref $value eq 'HASH';
      return @$value if ref $value eq 'ARRAY';
    }
    return $value;
  } else {
    foreach my $arg (@args)
    {
      my $value = MalyVar->var_evaluate($self->{DATA}, $arg);
      push @values, $value;
    }
    return @values if wantarray;
    return \@values if defined wantarray;
  }
}

sub set # If keys in hash does not start with $self->{KEY}, put it there!
{
  my ($self, %hash) = @_;
  #%hash = map { (/^$self->{KEY}/ ? $_ : "$self->{KEY}$_", $hash{$_}) } keys %hash;
  # Require that everything start with name!
  MalyVar->struct_update($self->{DATA}, undef, %hash);
}

sub ref # Removes key, returns structure reference
{
  my ($self) = @_;
  return $self->{DATA}->{$self->{KEY}};
}

sub list # Removes key, returns as list (whether array or hash)
{ 
  my ($self) = @_;
  my $r = $self->ref;
  return %$r if ref $r eq 'HASH';
  return @$r if ref $r eq 'ARRAY';
  return $r; # Otherwise, i.e. scalar
}

sub save # Write struct to file(s), according to external keys
{
  my ($self) = @_;
  my $data = $self->{DATA}->{$self->{KEY}};
  my $ldata = $data;

  my @keys = $self->external;
  foreach my $key (@keys)
  {
    my $lckey = lc($key);
    $self->write("$self->{PREFIX}/$lckey.conf", $ldata->{uc $key});
  }

  if (@keys and ref $data eq 'HASH')
  {
    $ldata = { %$data };
    map { delete $ldata->{$_} } @keys;
  }
  $self->write("$self->{PREFIX}.conf", $ldata);
}

sub write # Write a single struct to a single file
{
  my ($self, $file, $struct) = @_;
  $file ||= "$self->{PREFIX}.conf";
  $struct ||= $self->{DATA}->{$self->{KEY}};

  print STDERR "WRITING TO $file\n";

  # Make sure all parent directories exist
  my @parts = split("/", $file);
  my @dirs = map { join("/", @parts[0..$_]) } (0..$#parts-1);
  print STDERR "D=".join(", ", @dirs)."\n";
  map { mkdir($_) unless -e $_ } @dirs;

  if (open(F, ">$file"))
  {
    $Data::Dumper::Terse = 1;
    $Data::Dumper::Purity = 1;
    $Data::Dumper::Deepcopy = 1;
    print F Data::Dumper->Dump([$struct]);
    close(F);
    return 0;
  } else {
    $ERROR = "Unable to save file '$file': $!";
    return $ERROR;
  }
}

1;
