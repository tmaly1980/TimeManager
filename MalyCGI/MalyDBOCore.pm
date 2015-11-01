package MalyDBOCore; # Database Object, provides an OOP interface to database operations.

# Documentation is in MalyDBO, some applies here, some does not.

use Data::Dumper;

our $DBH = undef;
our @DBPARAMS = ();
our $COLUMNS = {};
our $DEBUG = 0;

###########################
use MalyLog;
use MalyVar;
use UNIVERSAL qw(isa);

our $VARS = {GLOBAL=>{LOGGER=>MalyLog->new()}}; # Dummy reference, will get overwritten later.
our $LOGGER = $VARS->{GLOBAL}->{LOGGER};
our $FD = 1;
our $CACHE = {};

sub logger { return $VARS->{GLOBAL}->{LOGGER} || $LOGGER }; # In case GLOBAL gets overwritten, WITHOUT A LOGGER !
sub internal_error { my ($this, @args) = @_; logger->internal_error(@args); }
sub system_error { my ($this, @args) = @_; logger->{SYSTEM_ERROR}->(@args); }
sub user_error { my ($this, @args) = @_; logger->{USER_ERROR}->(@args); }
sub debug { my ($this, @args) = @_; logger->debug(@args); }
sub log_debug_stack { my ($this, @args) = @_; logger->log_debug_stack(@args); }
sub log { my ($this, @args) = @_; logger->log(@args); }

###########################

sub new
{
  my ($this, @schema) = @_;
  my $class = ref($this) || $this;
  @schema = $this->get_schema() unless @schema;
  my $self = bless {}, $class;
  $self->{SCHEMA} = [ @schema ];
  $self->{ITER} = 0;
  $self->{GLOBAL} = $VARS->{GLOBAL};
  $self->{AUTOLINK} = $this->{AUTOLINK}; # Pass-through
  $VARS->{GLOBAL}->{LOGGER} = $self->{GLOBAL}->{LOGGER};
  return $self;
}

sub records # Basic usage. WITH one dimension of pseudo-record retrieval.
{
  my ($self) = @_;

  my @out = ();
  for ($self->first; $self->more; $self->next)
  {
    next if $self->{DELETES}->[$self->{ITER}];
    push @out, $self->hashref;
  }
  $self->first;
  return @out if wantarray; # Returns records unaffected.
  return \@out if defined wantarray;
}

sub set_globals # CALLED BEFORE new()
{
  my ($this, $globals) = @_;
  $VARS->{GLOBAL} = $globals;
  $this->{GLOBAL} = $VARS->{GLOBAL} if (ref $this);
}

sub records_ref { [ shift->records(@_) ]; }

# All scalars passed are sent to key = value in WHERE.
# All array refs are appended, but literally, i.e., for non '=' stuff.
# Saves search in self, it already instantiated.
sub search
{
  my ($this, @args) = @_;
  my $self = $this->search_cols(undef, @args);
}

sub search_nolink
{
  my ($self, @args) = @_;
  $self->search_cols_nolink(undef, @args);
}

sub get_schema
{
  my ($this) = @_;
  # If instance of MalyDBO, return copy. else, call subclass_init to get.
  if (ref $this->{SCHEMA})
  {
    #MalyDBO->log("REF SCHEMA!");
    return @{$this->{SCHEMA}} if wantarray;
    return $this->{SCHEMA};
  } else {
    #MalyDBO->log("SUBCLASS_INIT");
    return $this->subclass_init if wantarray;
    return [$this->subclass_init];
  }
}

sub search_cols
{
  my ($this, @args) = @_;
  my $self = ref ($this) ? $this : $this->new($this->get_schema);
  $self->search_cols_nolink(@args);
  return $self if defined wantarray;
}


sub default_order { return ""; }

sub should_insert # Whether should add/insert (true) or replace/update (false)
{
  my ($self) = @_;
  my @keys = $self->key_name;
  if (@keys > 1) # No primary key, necessarily! Should go by whether searched from.
  { 
    return $self->is_new;
  } else {
    my $keyname = $keys[0];
    my $v = $self->get($keyname);
    return undef if $v ne '';
    return 1;
  }
}

sub is_new # Is this NOT based upon a database record?
{
  my ($self) = @_;
  ##MalyDBO->log("REF RECORDS?=".ref ($self->{RECORDS}));

  if (
    not ref $self->{RECORDS} or
    not ref $self->{RECORDS}->[$self->{ITER}] or
    not ref $self->{RECORDS}->[$self->{ITER}]->{ORIGINAL} or
    not scalar keys %{$self->{RECORDS}->[$self->{ITER}]->{ORIGINAL}}
    )
  {
    return 1;
  }
  return undef;
}

sub iter { return shift->{ITER}; }
sub index { return shift->iter; }

sub result
{
  my ($self) = @_;
  return undef unless $self->count;
  return $self;
}

sub count
{
  my ($self) = @_;
  my $count = scalar @{$self->{RECORDS}} if (ref $self->{RECORDS});
  return $count || '0';
}

sub first # We should prolly tinker with removing actual deletes....
{
  my ($self) = @_;
  $self->{ITER} = 0;

  $self->remove_empty_records();
  
  return $self;
}

sub clear
{
  my ($self) = @_;
  $self->{RECORDS} = undef;

}


sub append # Puts in spot for new record at end.
{
  my ($self) = @_;
  $self->last;
  $self->next if $self->count; # Only move past record if there already is one.
  $self->{RECORDS}->[$self->{ITER}] = {};
  return $self if defined wantarray;
}

sub last # Set to end. (last one.)
{
  my ($self) = @_;
  my $count = $self->count || 1;
  $self->{ITER} = $count - 1;
  return $self if defined wantarray;
}

sub next # Moves to next record. Even if new. Does not return object if no more there.
{
  my ($self) = @_;
  return undef if (++$self->{ITER} < $self->count);
  return $self if defined wantarray;
}

sub more
{
  my ($self) = @_;
  my $rc = ($self->{ITER} < $self->count);
  #$self->first unless $rc; # auto reset, ok since used in loops
  return $rc;
}

# Works only if already got a result.
sub keys { shift->columns; }
sub columns
{
  my ($self) = @_;
  return keys %{$self->internal_rec->{CURRENT}} if ref ($self->internal_rec->{CURRENT});
}

sub list_get
{
  my ($self, $col) = @_;
  my @values = $self->get($col);
  my $concat_char = $self->concat_char;
  if (@values > 1)
  {
    return @values;
  } elsif (@values == 1 and $concat_char and $self->should_concat($col)) {
    return split /$concat_char/, $values[0];
  } else {
    return ();
  }
}

sub should_concat # Whether really should involve concat char or not.
# DONT UNLESS WE EXPLICITLY SAY SO
{
  my ($self, $field) = @_;
  my $concat_fields = $self->{CONCAT_FIELDS} || eval '$' . ref($self) . '::CONCAT_FIELDS';
  my @concat_fields = ref $concat_fields eq 'ARRAY' ? @$concat_fields : ();

  return grep { $field eq $_ } @concat_fields;
  return undef;
}

sub get_hash
{
  my ($self, @args) = @_;
  $self->hash(@args);
}

sub hash
{
  my ($self, @args) = @_;
  $self->hash_generic("CURRENT", @args);
}

sub hashnew
{
  my ($self, @args) = @_;
  $self->hash_generic("CHANGES", @args);
}

sub hashold
{
  my ($self, @args) = @_;
  $self->hash_generic("ORIGINAL", @args);
}

sub depth # Specify the depth (# of subrecords deep) to automatically get when doing a records()/hash()
{
  my ($self, $depth) = @_;
  $depth = 1 if @_ == 1; # Default to 1, unless specified other (even 0!)
  $self->{_PSEUDO_DEPTH} = $depth;
  return $self if defined wantarray; # Can put in " $dbo = OBJ->new()->depth(5)->search(...); "
}

sub hsplit # THE NEW, PREFERRED WAY OF SPLITTING THE HASH. Takes concat char'ed string and turns into array ref.
{
  my ($self, %hash) = @_;
  my $concat_char = $self->concat_char;
  my @keys = keys %hash;
  foreach my $key (@keys)
  {
    my $value = $hash{$value};
    $value = [ split(quotemeta($concat_char), $value) ] if (($split and $self->should_concat($key) ) and not ref $value and $value =~ quotemeta($concat_char));
    $h{"CONCAT_$key"} = $orig_value if ($split and $orig_value ne $value); # Keep unconcatenated value, too, but rename.
    $h{$key} = $value;
  }
  return %h;
}

# All subrecords are translated to hashrefs or arrayrefs of hashrefs.
sub hash_generic # If $split set to true, will split at concat char. MAKE SURE UNIQUE AND NEVER USED ELSEWHERE...
{
  # NEED TO FIX TO ENCORPORATE NEW DB2CGI
  my ($self, $reckey, $split, @keys) = @_;
  my $concat_char = $self->concat_char;

  if (not exists $self->{RECORDS} or not ref $self->{RECORDS} eq 'ARRAY' or
    scalar @{ $self->{RECORDS} } < $self->{ITER} + 1)
  {
    return () if wantarray;
    return undef if defined wantarray;
  }

  # KLUDGE
  if ($split ne '' and $split ne '1') # It's not to split, it's a key!
  {
    unshift @keys, $split;
  }

  my $rec = $self->internal_rec($reckey);
  my %rec = ref $rec eq 'HASH' ? %$rec : ();

  my %pseudo = $self->get_pseudo_meta();

  @keys = (keys %rec, keys %pseudo) unless @keys;
  

  # Take depth, include %pseudo if set. subtract one, somehow pass to var_evaluate.

  my %h = ();

  foreach my $key (@keys)
  {
    #my $value = MalyVar->var_evaluate($rec, uc $key, \%pseudo); # We should explicitly use uppercase macros if we care.
    # as %pseudo is not necessarily doing the same.
    my $value = MalyVar->var_evaluate($rec, $key, \%pseudo);
    # This should KEEP a DBO as a DBO.
    my $orig_value = $value;
    $value = [ split(quotemeta($concat_char), $value) ] if ($split and $self->should_concat($key) and not ref $value and $value =~ quotemeta($concat_char));
    $h{"CONCAT_$key"} = $orig_value if ($split and $orig_value ne $value); # Keep unconcatenated value, too, but rename.
    $h{$key} = $value;
  }

  return %h if wantarray;
  return \%h if defined wantarray;
}

sub matches # if either column is value or has if array ref. Can give multiple for an AND
{
  my ($self, %hash) = @_;
  foreach my $key (keys %hash)
  {
    my $guess = $hash{$key};
    my @values = $self->get($key);
    return 0 unless grep { $_ eq $guess } @values;
  }
  return 1;
}

sub grep # Returns the indices that evaluated true.
{
  my ($self, @args) = @_;

  my @indices = ();
  my $i = 0; my @keys = grep { $i++ % 2 == 0 } @args;
  my %args = @args % 2 == 0 ? @args : ();

  for ($self->first; $self->more; $self->next)
  {
    my $rc = undef;
    if (@args == 1 and ref $args[0] eq 'CODE')
    {
      $rc = $args[0]->($self);
    } else { # hash match. (NOT SQL!)
      $rc = 1 if (@keys);
      foreach my $key (@keys)
      {
        if ( $self->matches($key, $args{$key}) )
	{
	  $rc = 0;
	}
      }
    }

    if ($rc)
    {
      return $self->{ITER} if (defined wantarray and not wantarray);
      push @indices, $self->{ITER};
    }
  }
  return @indices if wantarray;
  return $indices[0] if defined wantarray; # Scalar
}

sub hashref
{
  my ($self, @args) = @_;
  return { $self->hash(@args) };
}

sub getnew 
{ 
  my ($self, @keys) = @_; 
  $self->get_generic("CHANGES", @keys);
}

sub get
{
  my ($self, @args) = @_;
  $self->get_generic("CURRENT", @args);
}

sub at_index
{
  my ($self, $index) = @_;
  $self->{ITER} = $index;
  return $self if defined wantarray;
}

sub subrec # Smartly returns undef if not a subrec.
{
  my ($self, $name) = @_;
  my $value = $self->get($name);
  return undef unless isa($value, "UNIVERSAL");
  return $value;
}

sub load_pseudo # Loop through ALL records!
#XXX REMOVE?
{
  my ($self, @keys) = @_;
  my %pseudo = $self->get_pseudo_meta;

  return unless %pseudo;
  @keys = keys %pseudo unless @keys; # Default to all.

  for ($self->first; $self->more; $self->next)
  {
    my $rec = $self->internal_rec($reckey);
    foreach my $key (@keys)
    {
      map { $rec->{"_PSEUDO_$_"} = $pseudo{$_} } keys %pseudo; # Give proper names, so we can have backup.
      MalyVar->var_evaluate($rec, uc $key);
      # Fix so we dont bother returning if not defined wantarray

      # perhaps overhead is in get_generic (MalyVar)?
      # Way of not bothering with check?
      # HOPEFULLY NOT.
    }
  }
  $self->first;
}

# Subrecords are kept raw.
sub get_generic
{
  my ($self, $reckey, @keys) = @_;
  if (not exists $self->{RECORDS} or not ref $self->{RECORDS} eq 'ARRAY' or
    scalar @{ $self->{RECORDS} } < $self->{ITER} + 1)
  {
    return () if wantarray;
    return undef if defined wantarray;
  }
  my $rec = $self->internal_rec($reckey);
  my @out = ();
  my $concat_char = $self->concat_char;
  my $pseudo = $self->get_pseudo_meta;
  foreach my $key (@keys)
  {
    #my $value = MalyVar->var_evaluate($rec, uc $key); # Allows recursion

    my $value = MalyVar->var_evaluate($rec, uc $key, $pseudo); # Allows recursion

    if (not ref $value and $self->should_concat($key) and $concat_char and $value =~ quotemeta($concat_char) and wantarray and @keys == 1) 
    # Asking for one thing and wanting multiple, so split at concat_char.
    {
      my @values = split(quotemeta($concat_char), $value);
      return @values;
    }
    elsif (wantarray and @keys == 1 and ref $value and isa($value, "MalyDBOCore")) # Want records() implicitly called!
    {
      return $value->records();
    }
    elsif (wantarray and @keys == 1 and ref $value eq 'ARRAY')
    {
      return @$value;
    }
    push @out, $value;
  }


  # Map @out so array refs with single values get turned into scalars.
  @out = map { ( (ref($_) eq 'ARRAY' and @$_ == 1) ? @$_ : $_ ) } @out;
  #@out = map { ref($_) eq 'ARRAY' and @$_ == 1 ? @$_ : $_ } @out;

  return () if (wantarray and not CORE::grep { /./ } @out); # wanting array, and nothing found.
  return @out if wantarray;
  return $out[0];
}

sub defined { my ($self, @args) = @_; $self->all_defined(@args); } # Defaults to AND

sub all_defined
{
  my ($self, @keys) = @_;
  not grep { $self->get($_) eq '' } @keys;
}

sub any_defined # OR
{
  my ($self, @keys) = @_;
  grep { $self->get($_) ne '' } @keys;
}

sub getold { 
  my ($self, @keys) = @_;
  $self->get_generic("ORIGINAL", @keys);
}

sub set_default
{
  my ($self, %hash) = @_;
  foreach my $key (keys %hash)
  {
    $self->set($key, $hash{$key}) if ($self->get($key) eq '');
  }
}

sub cgi2db { my ($self, %hash) = @_; return %hash; } # This allows removal of columns from setting.

sub set
{
  my ($self, %hash) = @_;
  #my %extra_hash = $self->cgi2db(%hash);
  #my %valid_hash = $self->ignore_invalid_columns_not_pseudo(%hash, %extra_hash);
  %hash = $self->cgi2db(%hash);
  my %valid_hash = $self->ignore_invalid_columns_not_pseudo(%hash);
  $self->set_unchecked(%valid_hash);
}

sub set_unchecked
{
  my ($self, %changes) = @_;
  #print STDERR "SETTING TGID = $changes{TGROUP_IDS}\n" if $changes{TGROUP_IDS};
  $self->mark_deleted(0); # Reset if previously deleted.
  foreach my $key (keys %changes)
  {
    my $value = $changes{$key};
    $self->{RECORDS}->[$self->{ITER}]->{CURRENT}->{$key} = $value;
    $self->{RECORDS}->[$self->{ITER}]->{CHANGES}->{$key} = $value;
  }
  #print STDERR "CURR=($self)=$self->{RECORDS}->[$self->{ITER}]->{CURRENT}->{TGROUP_IDS}\n";
}

sub ignore_invalid_columns { my ($self, %hash) = @_; return $self->ignore_invalid_columns_not_pseudo(%hash); } # Do nothing.
sub ignore_invalid_columns_not_pseudo { my ($self, %hash) = @_; return %hash; } # Do nothing.

# To generate the WHERE clause, we need to know a unique set of values.
# If SCHEMA->[1] is an array ref, we do such.

sub internal_rec
{
  my ($self, $key) = @_;

  # If key does not exist, make it!
  #$self->{RECORDS}->[$self->{ITER}] = {CURRENT=>{}, CHANGES=>{}, ORIGINAL=>{} } unless exists $self->{RECORDS}->[$self->{ITER}];
  # Removing this mess, as we only need to make this when SETTING (which is done there)
  # and this is making an invisible record appear! d'oh
  # 06/13/04

  #
  return $self->{RECORDS}->[$self->{ITER}]->{$key} if $key;
  return $self->{RECORDS}->[$self->{ITER}];
}

sub has_pending_changes
{
  my ($self) = @_;
  my $changes = $self->{RECORDS}->[$self->{ITER}]->{CHANGES};
  my %changes = %{$changes} if ref $changes;
  return scalar keys %changes;
}

sub has_changed # Since search. Any of the keys (OR'ed)
{
  my ($self, @keys) = @_;
  # searched value isnt current OR searched value isnt NEW (redundant!)
  # (CURRENT IS SET UPON X)
  # CURRENT MEANS OLD, IF NOT OVERWRITTEN BY NEW (set())
  # CHANGES MEANS NEW (SET VIA SET())
  #return CORE::grep { $self->getold($_) ne $self->get($_) or $self->getold($_) ne $self->getnew($_) } @keys;
  return CORE::grep { $self->getold($_) ne $self->get($_) } @keys;
  #return CORE::grep { $self->getnew($_) ne '' } @keys;
}

sub commit_all
{
  my ($this, @changes) = @_;
  my $self = ref $this ? $this : $this->new($this->get_schema);
  for ($self->first; $self->more; $self->next)
  {
    $self->commit(@changes); # if $self->has_pending_changes;
    # If we bothered to call commit_all(), we probably would have just meant so for the loop effect
    # Thus, always do a commit!!!
  }
  return $self if defined wantarray;
}

sub commit # Does save to database whether insert or update.
{
  my ($this, @params) = @_;
  my $self = ref $this ? $this : $this->new($this->get_schema);

  $self->set(@params); # So if we get the key this way, we know to not add
  #print STDERR "RECORDS=".Dumper($self->{RECORDS})."\n";
  #print STDERR "PEDING CHANGES=".$self->has_pending_changes."\n" if ref $self eq 'GroupMembership';
  if ($self->should_insert() and $self->has_pending_changes)
  {
    $self->insert(@params);
  } elsif ($self->has_pending_changes) {
    $self->update(@params);
  }
  return $self if defined wantarray;
}

sub table_name
{
  my ($self, $all) = @_;
  #print STDERR "GET_SCHEMA=".Dumper($self->get_schema)."\n";
  my $prelim_table = $self->get_schema->[0];
  return $prelim_table if $all;
  my @tables = split(/,[ ]*/, $prelim_table);
  my $table = $tables[0];
  return $table;
}

sub concat_char { my ($self) = @_; return undef; }

sub subclass_init { die ("Schema unititialized. Override subclass_init."); } 
# Overwritten versions (subclassed) should return a list like ('tablename', 'primarykey')

sub is_mark_deleted
{
  my ($self) = @_;
  return $self->{DELETES}->[$self->{ITER}];
}

sub mark_deleted # For use with delete()
{
  my ($self, $value) = @_;
  $value = 1 if (@_ == 1); # If not specified, assume deleting.
  $self->{DELETES}->[$self->{ITER}] = $value;
  # Clear specific record (IF MARKING, NOT UNMARKING).
  $self->{RECORDS}->[$self->{ITER}] = {} if ($value);
  return $value;
}

sub remove_empty_records # From delete()'s. Compacts records.
{
  my ($self) = @_;

  my @deletes = ref $self->{DELETES} eq 'ARRAY' ? @{ $self->{DELETES} } : ();
  my @deletes_indices = ();
  for (my $i = 0; $i < @deletes; $i++)
  {
    push @deletes_indices, $i if $deletes[$i];
  }

  #print STDERR "DELS=".join(",", @deletes)."\n";
  #print STDERR "DELIX=".join(",", @deletes_indices)."\n";

  if (@deletes_indices)
  {
    my @records = ref $self->{RECORDS} eq 'ARRAY' ? @{ $self->{RECORDS} } : ();
    $self->{COMPACT_RECORDS} = [];
  
    for (my $i = 0; $i < @records; $i++)
    {
      push @{ $self->{COMPACT_RECORDS} }, $records[$i] if not grep { $i == $_ } @deletes_indices;
    }
  
    $self->{DELETES} = undef;
    $self->{RECORDS} = $self->{COMPACT_RECORDS};
    $self->{COMPACT_RECORDS} = undef;
  }
}

sub db2cgi {;}

sub add_params
{
  my ($self, @args) = @_;
  my @existing_params = ref $self->{SEARCH_PARAMS} ? @{$self->{SEARCH_PARAMS}} : ();
  push @existing_params, @args;
  $self->{SEARCH_PARAMS} = \@existing_params;
}

sub multipage_count # All results, beyond what returned.
{
  my ($self) = @_;
  return $self->{MULTIPAGE_COUNT} || $self->count;
}

sub reset  # Will reset value (hopefully a pseudo key). Will, if @keys is given, will do those instead of all default pseudo keys.
{
  my ($self, @keys) = @_; # Arbitrary malyvar keys.
  $self->{PSEUDO} ||= { $self->db2cgi };

  if (not @keys and ref $self->{PSEUDO} eq 'HASH')
  {
    @keys = keys %{ $self->{PSEUDO} };
  }

  my $rec = $self->internal_rec("CURRENT");
  my %reset = map { ($_, undef) } @keys;
  MalyVar->struct_update($rec, %reset);
  return $self if defined wantarray;
}

# What we are doing:
#
# moving numbers around.

# Desired behavior:
# If move up one, just swap it with one above (if any)
# If replacing an existing one, 
#	move everyone from that value and above, up by one
# In the end, shorten the list so its sequential, no skipping numbers.

# how to do this mess:
#
# get the value we want to set the current thing to.
#
# go through records. if the EXISTING values match that of any other (ie. duplicates)
# Just bump up the one we got to second. now we have a unique list, except perhaps the changes.
# Save value of field to hash (as key, with index as value).
#
# go through records. if what we find is AT what we want, move down if one higher. 
# OTHER WISE, if what we find is AT or ABOVE, move higher by one.
# If we got the record we're changing, change the value to what we want it to be.
# generate a map of display values to indexes.
#
# Now go through display values. if not in integral sequence, alter corresponding db record.
# 

sub commit_sorted_list # Takes all records, adjusts integer values of $key ($self is a physically displayed list with $key being the #) based upon what was submitted via %hash
# This is appropriate when only ONE record changes.
# Display key should PROBABLY not be primary key.
{
  my ($self, $key, %hash) = @_; # $key is expected to be INTEGER
  my $new_value = $hash{$key};
  my %value_ix_map = (); 

  %hash = map { (uc($_), $hash{$_}) } keys %hash;

  my @keys = $self->key_name;

  my @records = ();

  # if $key's value is undef, pretend like we're adding.
  # FIX OTHER PROBLEM TOO

  my $rec = undef;

  for ($self->first; $self->more; $self->next)
  {
    my $ix = $self->index;
    my $matches = not grep { 
      my $sv=$self->get($_);
      my $hv=$hash{uc $_};
      #print STDERR "SV=$sv, HV=$hv\n";
      $sv ne $hv;
      } @keys;
    my $old_value = $self->getold($key);
    my $iter_value = $self->get($key);
    if ($matches and %hash)
    {
      $self->set(%hash);
      $iter_value = $self->get($key);
      #print STDERR "NV=$new_value\n";
    }
    my $temp_rec = 
    {
      INDEX=>$ix,
      MATCHES=>$matches,
      VALUE=>$iter_value,
      OLD_VALUE=>$old_value,
    };
    $rec = $temp_rec if $matches; # Found match
    if (not $matches or $new_value ne '') # Not resetting, and not adding
    {
      push @records, $temp_rec;
    }
  }

  my $new_rec = undef;

  if (not $rec) # Adding or resetting.
  {
    if (not $matches)
    {
      $self->append();
      $self->set(%hash);
    }
    $new_rec = {
      INDEX=>$self->index,
      MATCHES=>1,
      VALUE=>$new_value,
      OLD_VALUE=>undef, # None, since adding.
    };
    push @records, $new_rec if ($hash{$key} ne '') # Let number determine order if given.
  }

  # If moving up, make sure ones with same value get put BEFORE.
  # If moving down, make sure ones with same value get put AFTER.

  my @sorted_records = sort 
  { 
    return 1 if not $a->{VALUE}; # Move to end of list if empty (will be added at end)
    return -1 if not $b->{VALUE}; # Move to end of list if empty (will be added at end)
    my $cmp = $a->{VALUE} <=> $b->{VALUE};
    
    # if same value and one of them is $rec.
    # Keep rec ABOVE other if just moving by one UP (swapping)
    # Otherwise, keep rec BELOW other.
    if ($cmp == 0)
    {
      if ($a->{MATCHES})
      {
	# up = 1, down = -1
	my $diff = ($a->{VALUE} - $a->{OLD_VALUE});
	# If a is new, put where we ask for it to go!
	if ($a->{OLD_VALUE} == undef)
	{
	  return -1;
	}
	return $diff != 0 ? $diff/abs($diff) : -1;
      } 
      elsif ($b->{MATCHES}) 
      {
        # up = -1, down = 1
	my $diff = ($b->{VALUE} - $b->{OLD_VALUE});
	# If b is new, put where we ask for it to go!
	if ($b->{OLD_VALUE} == undef)
	{
	  return 1;
	}
	return $diff != 0 ? - $diff/abs($diff) : 1;
      }
    }
    return $cmp;
  } @records;

  # NOT ALWAYS PASSING %hash !!!!

  $rec = $new_rec if ($new_rec);
  if (%hash and $hash{$key} eq '') # APPEND TO END ONLY IF NO KEY VALUE SET!
  {
    push @sorted_records, $rec; # APPEND TO END
  }

  for(my $i = 0; $i < @sorted_records; $i++)
  {
    my $r = $sorted_records[$i];
    my $iter_value = $r->{VALUE};
    my $index = $r->{INDEX};
    $self->at_index($index);
    $self->set($key, $i+1);
    $self->commit();
  }

  # Change index to that particular one (so other changes affect just that one!)
  $self->at_index($rec->{INDEX});
}

sub multi_commit_sorted_list
# We have an entire LIST in this dbo, and we want to sort it and all.
# The only values changing are for the key.
# But now adding support to internally change key itself rather than rely on CGI.
{
  my ($self, $key, %form) = @_;
  #print STDERR "CALLING MULTICOMMITSORTEDLIST ON $self->{TABLE_NAME}, KEY=$key\n";

  $key = uc $key;
  # generate records.
  # Sort based upon $key's value
  # If same,
  # prefer the one changing if the other is not different
  # for where two change, and both at same number, randomly choose.

  # Perform key/ordering changes....
  if (%form)
  {
    my $prikey = uc $self->key_name;
    my @prikeyvalues = ref $form{$prikey} eq 'ARRAY' ? @{$form{$prikey}} : ();
    my @orderkeyvalues = ref $form{$key} eq 'ARRAY' ? @{ $form{$key} } : ();
    @orderkeyvalues = ($form{$key}) if not @orderkeyvalues and $form{$key} ne '';
    @prikeyvalues = ($form{$prikey}) if not @prikeyvalues and $form{$prikey} ne '';

    for ($self->first; $self->more; $self->next)
    {
      next if $self->is_mark_deleted;
      my $pkval = $self->get($prikey);
      for (my $i = 0; $i < @prikeyvalues; $i++)
      {
        if ($pkval == $prikeyvalues[$i])
        {
	#print STDERR "SETTING $pkval TO $orderkeyvalues[$i]\n";
          $self->set($key, $orderkeyvalues[$i]);
        }
      }
    }
  }



  # Now do sorting...

  my @records = ();
  for($self->first; $self->more; $self->next)
  {
    next if $self->is_mark_deleted;
    my $value = $self->get($key);
    my $old_value = $self->getold($key);
    push @records, {
      $self->hash,
      INDEX=>$self->index,
      VALUE=>$value,
      OLD_VALUE=>$old_value,
    };
  }
  my @sorted_records = sort 
  {
    #print STDERR "CMP $a->{NAME} = $a->{VALUE}, $b->{NAME} = $b->{VALUE}\n";
    my $cmp = ($a->{VALUE} <=> $b->{VALUE});
    if ($cmp == 0)
    {
      # If one changed, and the other one didnt, then prefer the one that changed.
      # i.e., if moving up, put the other one BEFORE.
      # if moving down, put the other one AFTER.
      # watch out for when BOTH havent moved and BOTH are the same. (div/0)
      if ($a->{VALUE} == $a->{OLD_VALUE} and $b->{VALUE} != $b->{OLD_VALUE})
      {
        my $diff = $b->{VALUE} - $b->{OLD_VALUE};
	my $dir = $b->{OLD_VALUE} eq '' ? $diff/abs($diff) : -$diff/abs($diff);
	# Now if something ADDED, gets changed to #1, $diff is always 1, and $dir is always -1 (i.e. let other be #1)
	# so in fact, the problem may be an off-by-one thingy.

	#
	# Now, lets change $a's value so we can move multiple at the same time.
	$a->{VALUE} = $a->{OLD_VALUE} = $a->{VALUE} + $dir;
        return $dir;
      } 
      elsif ($b->{VALUE} == $b->{OLD_VALUE} and $a->{VALUE} != $a->{OLD_VALUE})
      {
        my $diff = $a->{VALUE} - $a->{OLD_VALUE};
	my $dir = $a->{OLD_VALUE} eq '' ? -$diff/abs($diff) : $diff/abs($diff);
	$b->{VALUE} = $b->{OLD_VALUE} = $b->{VALUE} - $dir;
        return $dir;
      }
    }
    return $cmp;
  } @records;


  for(my $i = 0; $i < @sorted_records; $i++)
  {
    my $rec = $sorted_records[$i];
    my $index = $rec->{INDEX};
    $self->at_index($index);
    $self->set($key, $i+1);
    #print STDERR "NAME= $rec->{NAME}, I=$i\n";
    #print STDERR "GONNA COMMIT\n";
    $self->commit();
    #print STDERR "AFTER COMMIT\n";
  }
  #print STDERR "AFTER ALL COMMITS\n";
  $self->first;
}

sub get_pseudo_meta # To disable, we must EXPLICITLY set depth(0)
{
  my ($self) = @_;
  $self->{PSEUDO} ||= { $self->db2cgi, _PSEUDO_DEPTH=>$depth };
  $self->{PSEUDO}->{_DBO} = $self;
  return %{ $self->{PSEUDO} } if wantarray;
  return $self->{PSEUDO} if defined wantarray;
}

sub get_all # For all records, get a single field, return in list, or if concat spec'd, concatenate and create an "a,b,c" format 
{
  my ($self, $col, $concat) = @_;
  my @values = ();
  my $iter = $self->{ITER};
  for ($self->first; $self->more; $self->next)
  {
    #my $value = $self->get($col);
    #push @values, $value;
    push @values, $self->get($col);
  }
  $self->{ITER} = $iter;
  if ($concat)
  {
    my $values = join(",", @values) || "NULL";
    $values = "($values)";
    return $values;
  } else {
    return @values;
  }
}

sub commit_list 
# Takes what is common between all recs, and what differs, and updates db, removes what not in list too.
# Returns a list of array refs containing the primary keys of those records deleted
# i.e., in case affects other tables, we have a reference to fix them.
{
  my ($self, $common, $strict_order, $keys, @differ) = @_; 
  my %differ = @differ;
  my @common = ref $common eq 'ARRAY' ? @$common : ();
  my %common = @common % 2 == 0 ? @common : ();
  my $length = ref $differ[1] eq 'ARRAY' ? scalar @{$differ[1]} : 0;
  my @deletes = ();
  my @keys = ref $keys eq 'ARRAY' ? @$keys : $self->key_name; # Default to primary keys, but may rely on secondary keys too.

  if ($strict_order) # Order MUST match what was given by form.
  {
    $self->first;
    for (my $i = 0; $i < $length; $i++)
    {
      my %differ_iter_hash = map { ($_, $differ{$_}->[$i]) } keys %differ;
      $self->commit(@common, %differ_iter_hash);
      $self->next;
    }
    while($self->more)
    {
      push @deletes, [ map { my $x=$self->get($_) } $self->key_name ];
      $self->delete();
      $self->next;
    }
  } else { # Order doesn't matter, we can find our records anywhere.

    my @found_indices = ();
    for ($self->first; $self->more; $self->next)
    {
      my $found = 0;
      for (my $i = 0; $i < $length; $i++)
      {
        my %differ_iter_hash = map { ($_, $differ{$_}->[$i]) } keys %differ;
	# We are not necessarily given any keys.... what we WANT to do, is stop at the first match given @differ
	my %joint_hash = (%differ_iter_hash, %common);
	if (not grep { $joint_hash{$_} ne $self->get($_) } @keys)
	# Found it, based upon primary keys.
	{
	  $found = 1;
	  push @found_indices, $i;
          $self->commit(@common, %differ_iter_hash); # Make changes!
	}
      }
      if (not $found)
      {
        push @deletes, [ map { my $x=$self->get($_) } $self->key_name ];
        $self->delete;
      }
    }
    # Now, we may have some in the form not found in the db. APPEND.
    my @skipped_indices = grep { my $i=$_; not grep { $i == $_ } @found_indices } (0..$length-1);

    for (my $j = 0; $j < @skipped_indices; $j++)
    {
      print STDERR "NOT FOUND, ADDING\n";
      my $ix = $skipped_indices[$j];
      my %differ_iter_hash = map { ($_, $differ{$_}->[$ix]) } keys %differ;
      $self->append();
      $self->commit(@common, %differ_iter_hash);
    }
  }
  $self->remove_empty_records();
  return @deletes; # Array ref of prikeys whose entries were deleted!
}

sub foreach
{
  my ($self, $sub) = @_;
  for ($self->first; $self->more; $self->next)
  {
    $sub->($self);
  }
  $self->first;
}

sub multirow_form_set # Given a CGI form, set the object accordingly (to match 100%, no more, no less).
{
  my ($self, $delcheck, %hash) = @_; # If, within %hash, a key does NOT have a _IX, then it is set for ALL!

  my @keys = $self->key_name;
  my @field_names = map { uc($_) } $self->table_columns;

  my @form_keys = map { uc($_) } keys %hash;
  my ($max_ix) = reverse sort map { /_(\d+)$/ } @form_keys;

  my @non_key_field_names = grep { $f=$_;not grep { $f eq $_ } @keys } @field_names;

  my @global_field_names = grep { $f=$_; grep { $f eq $_ } @field_names } keys %hash;
  my %global_hash = map { ($_, $hash{$_}) } @global_field_names;

  # Generate mapping of form IX to DBO IX (as can sort for arbitrarily)
  my %form_dbo_ix_map = ();
  for ($self->first; $self->more; $self->next)
  {
    my %key_values = map { (uc($_), $x=$self->get($_)) } @keys;
    for (my $i = 0; $i <= $max_ix; $i++)
    {
      my %form_key_values = map { (uc($_), $hash{uc($_)."_$i"}) } @keys;
      if (not grep { $key_values{$_} ne $form_key_values{$_} } keys %key_values)
      {
        $form_dbo_ix_map{$i} = $self->index;
	if ($hash{uc "${delcheck}_$i"})
	{
	  $self->delete();
	}
      }
    }
  }

  for (my $i = 0; $i <= $max_ix; $i++)
  {
    my $dbo_ix = $form_dbo_ix_map{$i};
    my @form_fields = grep { /_$i$/ } @form_keys;
    my %non_key_field_hash = map { ($_, $v=$hash{$_."_$i"})  } @non_key_field_names;
    my %key_field_hash = map { ($_, $v=$hash{$_."_$i"})  } @keys;

    next if ($hash{"${delcheck}_$i"});
    next if not grep { /./ } values %non_key_field_hash; # Skip, it's empty.

    if ($dbo_ix ne '')
    {
      $self->at_index($dbo_ix)->commit(%non_key_field_hash, %global_hash);
    } else {
      $self->append;
      $self->commit(%non_key_field_hash, %key_field_hash, %global_hash);
      # primary keys are hidden in form (generated before-hand, by the template!
    }
  }
  $self->remove_empty_records();

}

sub delete_all
{
  my ($self) = @_;
  for ($self->first; $self->more; $self->next)
  {
    $self->delete();
  }
}


# METHODS TO OVERRRIDE:

sub search_cols_nolink {;} # Creates database specific query. Returns results in object.
sub init {;} # Pass along connection info (username, host, password). Called from CGI.
sub update {;} # Updating a record.
sub insert {;} # Adding a record.
sub delete { shift->mark_deleted(1); } # Removes record from db.
sub connect {;} # Connects to db.
sub END {;} # Disconnects from db.
sub enable_multipage {;} # Adds limits to # of results. As well as an offset.
sub refresh {;} # Last query is re-run. ALL records are erased. Hopefully any new ones added will be found.
sub col_in {;} # How to generate (for search_cols_nolink) the way to do a search  of a field based upon a list of values
sub key_name {;} # Returns keys that uniquely identify a record.

# END METHODS TO OVERRIDE

1;
