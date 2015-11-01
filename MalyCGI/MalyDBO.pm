package MalyDBO; # Database Object, provides an OOP interface to database operations.
my $X = 0;

# To get set up with the hostname, database name, username and password for the database connection,
# One must pass suitable parameters to init(), equivalent to what would be passed to DBI->connect(), ie.:
# 
# MalyDBO->init('dbi:mysql:hostname=localhost;database=circuitm','username','password');
# 
# Typically, this is automatically handled in a generic level CGI class, which a normal CGI would subclass.
#
#
# From there, one can either use MalyDBO directly to create a new object for operations upon a single table,
# And pass the table name and primary key to new(),
# Or sublcass this and define subclass_init(), which takes the tablename and primary key as parameters.
#
# my $db = MalyDBO->new('affiliates', 'affiliate_id', 'optional_concat_char')
#  OR
# within 'Affiliates.pm', define subclass_init() to return ('affiliates', 'affiliate_id')
#
# the optional concat_char is for when you set a value to an array ref, it joins the values by the char into a string and sets the column to that.
#
# The primary key (second arg) can be an array ref, which then means that the key to be auto-generated is the first element, and all successive arguments are keys that MUST be set via the application. I.e., only one column will ever get auto-generated.
#
# To disable auto generation of keys (which will make updates useless), specify undef as arg #2
#
# One can specify multiple tables (separated by a comma, as in SQL) to perform joins. Remember to either also include ON x.a = y.a in the string if left join, or as ["t1.c1 = t2.c2"] in the search() params....
#
# If multiple tables are specified, any changes to the db is done only on the first table. i.e., make the first table the primary one, with any other secondard ones with linked data.
# 
# If the table for does NOT have a primary key column, one can pass columns that would create a unique entry as an array ref as the second arg to subclass_init's return or new().
# From there, one can perform searches using search(), like:
#
# my $results = $db->search(MEMBER=>'tomas',FOO=>'bar') (if using the direct MalyDBO instance)
#   OR
# my $results = Affiliate->search(MEMBER=>'tomas',...) (If using a subclass of MalyDBO)
#
# search() simply returns a copy of the object with the results saved inside of it.
# If calling search() on an existing object (i.e., a search), it will erase any existing records.
#
# $db->search_cols([cols...], ...) work like search(), but only retrieve cols spec'd
# Takes either a string or an array reference of strings as columns. undef = *, default.
#
# search() can take two kinds of parameters:
#  Elements of a list, which gets translated to KEY=VALUE into the WHERE clause of the SQL statement, OR
#  Array references, i.e., ['X BETWEEN A AND B'], which gets put as literal text.
#
#  Both of these can be mixed and matched any way. All the components get AND'ed together.
# 
# To perform a complex query such as outer joins that cannot be expressed as simple COL=VALUE pairs in the WHERE
#   clause, call search_sql().
# It takes a literal SQL statement as a parameter, and any placeholders afterwards.
# I.e.,
# my $result = MalyDBO->search_sql("SELECT * FROM AFFILIATES LEFT OUTER JOIN APPLICATIONS ON ....");
#
# It is recommended to implement a subclass that wraps such complex queries around simple function names.
# Or perhaps implement hashes, where simple key names map to complex queries. again, subclassed.
#
# One can generate sorting and row count limits by passing LIMIT=># and ORDER=>col and DESC=>1 parameters to search().
#
# If no ORDER is specified per query, the default ordering scheme as returned from 'default_order()' will be used. Default is none.
#
# To access the data from a search,
#
# my $value = $results->get('column')
#
# To split a single column at the default concatenation character (i.e., getting an array from a single column), ask for one column and assign to an array.
# 
# To get the keys in a row (columns of a table), call columns(), i.e, $results->columns
# This ASSUMES you actually have results. If no results exist from a query, this will return nothing.
#
# As we can get multiple results from a search, we can iterate over each row like:
#
# while ($results->more)
# {
#   foreach my $key ($results->columns)
#   {
#     my $value = $results->get($key);
#     print "$key: $value\n";
#   }
#   $results->next;
# }
#
# $results->next() just moves to the next row in the list.
#
# $results->count() will return the number of rows we got back from a search.
#
# $results->first() will first the counter and return the current pointer to the first row. This then enables
# looping over each result again to run ->update().
#
# $results->last() goes to the last record found, and $results->append() goes to the next record for adding
#  
# To change a value of some columns (for the current row), call $results->set('column', 'value', 'col2', 'val2',...)
# This works for any number of columns. Just pass a hash to set().
#
# Any array refs as values of a column will be concatenated (joined) into a single string.
#
# To then commit any changes you've made to an EXISTING row, call $results->update().
# It is also possibel to pass all the arguments to set(), to update(), like:
#
# $results->update(FOO=>'bar',COL1=>'VALUE1',...)
#
#
# To create a new entry into the database, do the following:
#
# my $record = MalyDBO->new('table', 'prikey')
# $record-.set(ONE=>'two'); # Can use a combination of setting values via set() and/or insert()
# $record->insert(FOO=>'bar', BIN=>'baz'); # values are sent to set() or insert()
#   OR
# Affiliate->insert(FOO=>'bar',BIN=>'zab');
#
# update() or insert() returns a copy of the record itself.
#
# The value of the primary key column (as specified by new() or subclass_init() is handled internally
# There is no need to set it explicitly, even for insert().
#
# To perform a complex INSERT or UPDATE, etc... that cannot be expressed via COL1=COL2, etc...., use do():
# MalyDBO->do("INSERT INTO table SET COL1=VAL2,....");
# 
# This is simply a wrapper to the DBI do(), It accepts placeholder arguments after the SQL string.
#
#
# To then return the internal hash representing a single row, call $result->hash, or $result->hashref (for a ref)
# 
# To return an array of hash references, call $result->results or $result->results_ref.
#
# Both of these would then return values appropriate for loop iteration and input into a web page.
#
# To remove a record from a database once it has been found via search(), call $result->delete()
#
# To clear any data in the object, call $obj->clear();
#
# $obj->refresh() tell to reload the record from the db, as some columns can get generated by the sql server (i.e. TIMESTAMP)
#
#
# To enable debugging, set either $dbo->{DEBUG} = 1 or $MalyDBO::DEBUG = 1;

#
# If db2cgi() is defined, it is interpretted as to return a hashref of key=>subst pairs that are then set into the results of a search.
# cgi2db() does the reverse- the form is converted using the criteria into the record.
#
# One is able to link multiple records together and access them through MalyVar-based variable macros in an HTML template, 
# AND one can also use db2cgi() to link CHANGES to multiple/related records.
#
# The advantage of such is that one needs to call commit() ONCE, and it affects both the parent and subrecords. 
# Thus, one uses the same html form field names as macro names to change a record and any subrecords. To do so,
# one simply needs to set a variable such as FOO{BAR} or BIN[0]{BAZ}, and it is checked if FOO/BIN is a pseudo column subrecord.
# The subrecord, if not already existing, will have the linking key set as specified by db2cgi.
#
# To then commit the subrecords, one simply uses commit() as normal. In db2cgi, there should be a fourth argument to specify whether 
# commit should traverse into such subrecord. THIS IS THE ONLY THING NEEDED TO ENABLE RECURSIVE COMMITTING/CHANGING.
#
# To get sub records as records, call $self->subrec("PSEUDOKEY") . If it's not set, it returns undef.
# 
# TODO:
# use malyvar to SET vars based upon the foo{name}[2]....
# change commit to check enabled subrecords.
# XXX
# CHECK SELF AND MALYVAR FOR ACCURACY!

use base "MalyDBOCore";
use Data::Dumper;
use DBI;
use UNIVERSAL qw(isa can);
use Crypt::TripleDES;

our $DBH = undef;
our @DBPARAMS = ();
our $COLUMNS = {};
our $DEBUG = 0;
our $ENCRYPT_KEY = "8skqj294382034Kj232KAF3kdjf";
our $CRYPT = Crypt::TripleDES->new();

sub init 
{
  my ($class, @dbparams) = @_;
  if (@dbparams == 1 and ref $dbparams[0] eq 'ARRAY')
  {
    @DBPARAMS = @{$dbparams[0]};
  } else {
    @DBPARAMS = @dbparams;
  }
  $COLUMNS = {};
}

###########################

sub records 
  # Returns the raw data as an array of hashrefs, OR:
  #
  # Given a column to group by, it will create a list of records, grouped by the $group_by_col.
  # If that column is a reference (a subrecord), the results will be a list of records, containing a key pointing
  # to all of the first dimensional records that have the same value for the group_by_col
  #
  # group_by_col is the column to group by.
  #
  # sub_key is the key in the original inner records that make them unique. It is typically the key in the inner record that was used to link with the main one in the first place.
  # 
  # dest_key is the key that the inner record will use to store the array ref containing the similar outer records. You make it up to be whatever you want.
  #
  # In other words, this takes a two-dimensional record (a record with a link to some other)
  # and reverses the dimension order, grouping by the former inner dimension.
  #
  # or, this creates an array of arrayrefs, each ref being a list of records with the same value for $group_by_col
{
  my ($self, $group_by_col, $sub_key, $dest_key) = @_;
  my @in = $self->SUPER::records();

  my @out = ();
  my %out = ();
  my @values = ();
  foreach my $value (@in)
  {
    my $gbc_value = $value->{$group_by_col} if $group_by_col;
    $gbc_value = $gbc_value->hashref if (UNIVERSAL::isa($gbc_value, "MalyDBOCore"));
    if ($group_by_col and ref $gbc_value) # eq 'HASH') # it's a sub record, should put this record inside of it at the $dest_key
    {
      # Take sub record, get unique key. 
      # add to list.
      # in separate array, keep track of sub record.
      # create array of sub records in order, with parent records merged into sub key.

      my $sub_value = $gbc_value->{$sub_key}; # Array ref of all records with same group_by_col value.

      # add inner record to final list if not already there....
      push @values, $gbc_value if not CORE::grep { $_->{$sub_key} eq $sub_value } @values;

      # ADD outer record TO LIST of inner record
      my $out_values = $out{$sub_value};
      my @out_values = ref $out_values ? @{$out_values} : ();
      #$gbc_value->{$dest_key} = $value;
      push @out_values, $value; # Add old 1st dimensional record to list
      
      # Returns array of hashrefs, with the given key pointing to array ref of original records....
      $out{$sub_value} = \@out_values;
      # END ADD TO LIST
    } 
    elsif ($group_by_col)
    {
      # Will return an array of array refs of hashrefs. Each hashref is a record, each array ref is a group of records.
      push @values, $out_values if not CORE::grep { $_ eq $out_values } @values;
      my $out_values = $out{$group_by_col};
      my @out_values = ref $out_values ? @{$out_values} : ();
      push @out_values, $value;
      $out{$group_by_col} = \@out_values;
    } else {
      push @out, $value;
    }
  }

  if ($group_by_col and $sub_key and $dest_key)
  {
    # Values contains a list of unique inner records. Return, in same order, the list of unique inner records containing
    # an array ref in the col spec'd by $dest_key of the similar outer records.

    @retout = map { $_->{$dest_key} = $out{$_->{$sub_key}}; $_ } @values;
    return @retout;
  } 
  elsif ($group_by_col)
  {
    return map { $out{$_} } @values;
    # returns an array, whose each element is an array ref containing all the records with identical values for $group_by_col
  } else {
    return @out; # Returns records unaffected.
  }
}

sub search_cols_nolink # Takes first argument as an array refs of cols or a string literal.
# For columns to include in output.
{
  my ($this, $columns, @params) = @_;


  my $self = ref($this) ? $this : $this->new($this->get_schema);
  print STDERR "PARAMS=".Dumper(\@params)."\n" if ($self->{DEBUG});

  my @stored_params = ref $self->{SEARCH_PARAMS} ? @{$self->{SEARCH_PARAMS}} : ();
  $self->{SEARCH_PARAMS} = undef;
  push @params, @stored_params;

  my $table = $self->table_name(1);
  #MalyDBO->log("SEARCH_COLS TABLE=$table\n");
  #MalyDBO->log("SEARCH_COLS SCHEMA=".join(";", @schema));

  my @ph = ();
  my @text = ();
  my %hashparams = ();
  my %append = ();
  for (my $i = 0; $i < @params; $i++)
  {
    my $param = $params[$i];
    if (ref $param eq 'ARRAY')
    {
      push @text, @{$param};
    }
    elsif (ref $param eq 'HASH')
    {
      foreach my $key (%$param)
      {
        if (not defined $param->{$key})
	{
	  push @text, "$key IS NULL";
	} else {
          $hashparams{$key} = $param->{$key};
	}
      }
    } else { # Assume hash.
      next unless $param; # undef as key
      my $value = $params[++$i];
      my @value = ref $value eq 'ARRAY' ? @$value : ($value);
      #print STDERR "PARAM=$param, VALUE=".Dumper($value)."\n" if (ref $value ne 'ARRAY' and ref $value);
      if ($param eq 'ORDER')
      {
        $append{ORDER} = join(",", @value);
      }
      elsif ($param eq 'GROUP')
      {
        $append{GROUP} = join(",", @value);
      }
      elsif ($param eq 'LIMIT')
      {
        $append{LIMIT} = $value;
      }
      elsif ($param eq 'DESC')
      {
        $append{DESC} = $value;
      }
      elsif ($param eq 'TABLES')
      {
        $table = $value;
      } else {
        $hashparams{$param} = $value;
      }
    }
  }

  # Translate undef to NULL and '' to empty string.
  my %valid_hashparams = %hashparams;

  # 03/02/2004 DONT BOTHER, DOESNT MAKE SENSE, Ie can log in as admin when table messed up!

  #if ($table eq $self->table_name(1)) # Table was not altered, can filter search columns.
  #{
  #  %valid_hashparams = $self->ignore_invalid_columns(%hashparams);
  #}
  %valid_hashparams = %hashparams;

  my %translated = ();
  foreach my $param (keys %valid_hashparams)
  {
    my $value = $valid_hashparams{$param};

    # ANY OTHER STUFF TO APPEND?
    if (not defined $value) # Handle IS NULL appropriately
    {
      push @text, "$param IS NULL";
    } 
    elsif (defined $value and $value eq '') # Empty string.
    {
      push @text, "$param = ''";
    }
    else
    {
      $translated{$param} = $value;
    }
  }

  # In case we use 'OR', and accidently forget parentheses.
  my @parenthesized_text = ();
  foreach my $text (@text)
  {
    my $new_text = ($text =~ /^\(.*\)$/ ? $text : "($text)");
    if ($text =~ / OR /i and $new_text ne $text)
    {
      $self->log("Possible omission of parentheses in where clause '$text'");
    }
    push @parenthesized_text, $new_text;
  }

  #if (%hashparams and not %valid_hashparams and not @parenthesized_text) # Don't just do a blank search!
  #{
  #  return $self if defined wantarray;
  #  return;
  #}
  # WE SHOULD, in case we want all records...


  ##print STDERR "VALID SEARCH=".join(";", %translated)."\n";
  my ($where1, @ph) = $self->generate_where_by_hash(%translated);
  ##print STDERR "WHERE1=$where1\n";
  my ($where2) = $self->generate_where_by_text(@parenthesized_text);
  ##print STDERR "WHERE2=$where2\n";
  #MalyDBO->log("WHERE1=$where1, WHERE2=$where2");

  my $cols = undef;
  if (ref $columns)
  {
    my @cols = @{$columns};
    $cols = join(",", @cols);
    $self->{SEARCH_COLS} = [ @cols ];
  } elsif ($columns) {
    $cols = $columns; # Literal.
    $self->{SEARCH_COLS} = [ split /[,\s]+/, $columns ];
  } else {
    $cols = '*';
  }

  my $query = "SELECT $cols FROM $table";
  #MalyDBO->log("TABLE=$table\n");
  my $where = undef;
  if ($where1 and $where2)
  {
    $where = "$where1 AND $where2";
  }
  elsif ($where1)
  {
    $where = $where1;
  }
  elsif ($where2)
  {
    $where = $where2;
  }

  $query .= " WHERE $where" if ($where);

  if ($self->{MULTIPAGE})
  {
    my $count_dbo = $self->new();
    $count_dbo->search_sql("SELECT COUNT(*) AS NUM FROM $table" . ($where ? " WHERE $where" : ""), @ph);
    my ($count) = $count_dbo->values();
    $self->{MULTIPAGE_COUNT} = $count || 0;
  }

  if ($append{ORDER} eq '')
  {
    my $default_order = $self->default_order;
    $append{ORDER} = $default_order;
  }

  my $append = "";
  $append .= " GROUP BY $append{GROUP}" if ($append{GROUP} ne '');
  $append .= " ORDER BY $append{ORDER}" if ($append{ORDER} ne '');
  $append .= " DESC" if ($append{DESC} ne '' and $append{ORDER} ne '');
  $append .= " LIMIT $append{LIMIT}" if ($append{LIMIT} ne '');

  $query .= $append;

  $self->{LAST_SQL} = $query;
  $self->{LAST_PH} = \@ph;

  $self->search_sql($query, @ph);
  #$self->insert_cache();
  return $self if defined wantarray;
}

sub default_order { return ""; }

sub ignore_invalid_columns
{
  my ($self, %hash) = @_; $self->ignore_invalid_columns_meta(undef, %hash);
}

sub ignore_invalid_columns_not_pseudo
{
  my ($self, %hash) = @_; $self->ignore_invalid_columns_meta(1, %hash);
}

sub ignore_invalid_columns_meta
{
  my ($self, $pseudo, %hash) = @_;
  my %valid_hash = ();
  my @table_columns = $self->table_columns();
  my %db2cgi = $self->db2cgi;
  push @table_columns, keys %db2cgi if $pseudo;

  print STDERR "TABLE_COLUMNS=".join(";", @table_columns)."\n" if $self->{DEBUG};
  print STDERR "KEYS_IN=".join(";", keys %hash)."\n" if $self->{DEBUG};

  foreach my $key (keys %hash)
  {
    #print STDERR "CHECKING $key\n";
    next unless CORE::grep { /^$key$/i } @table_columns; # Skip invalid columns.
    #print STDERR "KEEPING $key\n";
    $valid_hash{$key} = $hash{$key};
  }
  return %valid_hash;
}

# WARNING: When doing a query purely from search_sql and not search(_cols),
# one CANNOT make changes. This is due to the column filtering mechanism.
# We have no way of determining the table to search unless we have that saved.
sub search_sql
{
  my ($this, $sql, @ph) = @_;
  my $self = ref($this) ? $this : bless {}, (ref $this||$this);

  print STDERR "SQL=$sql,PH=".join(",", @ph)."\n" if ($self->{DEBUG} || $DEBUG);
  $self->connect();
  $self->{LAST_SQL} = $sql;
  my $sth = $DBH->prepare($sql)
    or MalyDBO->internal_error("DB Prepare Error: ".$DBI::errstr);
  my $rc = $sth->execute(@ph)
    or MalyDBO->internal_error("DB Execute Error: ".$DBI::errstr);
  $self->{NAME_uc} = [ @{ $sth->{NAME_uc} } ];
  $self->first;

  my $decrypt_fields = eval '$' . ref($self) . '::ENCRYPT';
  my @decrypt_fields = ref $decrypt_fields eq 'ARRAY' ? @$decrypt_fields : ();

  #my @records = @{ $sth->fetchall_arrayref({}) };
  # do decryption if required.
  my @records = ();
  while (my $rec = $sth->fetchrow_hashref())
  {
    next unless ref $rec eq 'HASH';
    foreach my $dec_field (@decrypt_fields)
    {
      my $value = $rec->{$dec_field};
      my $dec_value = $CRYPT->decrypt3($value, $ENCRYPT_KEY);
      $rec->{$dec_field} = $dec_value;
    }
    push @records, $rec;
  }

  @records = () if (ref $records->[0] and not scalar keys %{$records->[0]});
  @records = () if (@records == 1 and $records[0] == undef);

  $sth->finish();
  #$self->{RECORDS} = scalar @records ? [ map { {ORIGINAL=>$_, CHANGES=>{}, CURRENT=>$_} } @records ] : undef;
  $self->{RECORDS} = scalar @records ? [ map { { ORIGINAL=>{%$_},CHANGES=>{},CURRENT=>{%$_} } } @records ] : undef;

  return $self if defined wantarray;
}

sub do
{
  my ($self, $sql, @ph) = @_;
  $self->connect();
  #MalyDBO->log("DO=>$sql, PH=>".join(",",@ph));
  print STDERR ("DO=>$sql, PH=>".join(",",@ph).";\n");# if $self->{DEBUG} || $DEBUG;
  $DBH->do($sql, undef, @ph)
    or MalyDBO->internal_error("DB Do Error: ".$DBI::errstr);
  return $self;
}

sub values
{
  # Order them in the way it was asked for. This only makes sense being called when
  # Explicit columns were asked for by search_cols.
  my ($self) = @_;
  #print STDERR "NAMEUC=".Dumper($self->{NAME_uc})."\n";
  return () unless ref $self->{NAME_uc};
  my @values = map { my $i = $self->get($_); $i } @{$self->{NAME_uc}};
  #print STDERR "VALUES=".Dumper(\@values).", should be". $self->get("COUNT(*)").", outta be:". $self->{RECORDS}->[$self->{ITER}]->{CURRENT}->{"COUNT(*)"}."\n";
  #print STDERR "RECS=".Dumper($self->records_ref)."\n";
  return @values;
}

sub table_columns
{
  my ($self) = @_;
  # We can unfortunately restrict the columns returned, so this isnt always accurate unless we get a
  # query with all columns specified.
  my $table = $self->table_name(1);
  if (not $COLUMNS->{$table})
  {
    my $search = $self->new();
    $search->search_sql("SELECT * FROM $table WHERE 1 = 0");
    $COLUMNS->{$table} = $search->{NAME_uc};
  }
  return @{ $COLUMNS->{$table} } if ref $COLUMNS->{$table};
  return ();
}

sub set_unchecked
{
  my ($self, %hash) = @_;
  my $concat_char = $self->concat_char;
  my %real_changes = ();

        #print STDERR "OV=$self->{RECORDS}->[$self->{ITER}]->{ORIGINAL}\n";
        #print STDERR "CV=$self->{RECORDS}->[$self->{ITER}]->{CURRENT}\n";

  foreach my $key (keys %hash)
  {
    #print STDERR "CHECKING VALID KEY OF $key...\n";
    #print STDERR "VALID KEY...\n";
    my ($value) = $hash{$key};
    $key = uc($key);
    #$value = undef if ($value eq ''); # Getting rid of, done now inside of conditional. 
    # We want to TRACK whether we were given undef (set to null no matter what), or an empty string (so if the old value is empty, just ignore)
    # This obfuscates such intentions if left uncommented.

    # This is ok, as no concat_char
    $value = join($concat_char, 
      map { $_ =~ s/$concat_char//g; $_; } @$value) 
        if ($self->should_concat($key) and ref $value eq 'ARRAY' and $concat_char and not ref $value->[0]); # If array of scalars, concatenate?
    
    my $old_defined = defined $self->{RECORDS}->[$self->{ITER}]->{CURRENT}->{$key};
    my $new_defined = defined $value;
    my $old_value = $self->{RECORDS}->[$self->{ITER}]->{CURRENT}->{$key} if $old_defined; # Only set when defined!

    # db string, form empty, set to null.
    # form string, (db empty) or (db string and different), set to form.
    # 

    # If we get here, we asked to set a value.
    # However, watch out for 

    if 
    (
    	# NOT THERE BEFORE, NOT THERE NOW (neither defined nor valued)
      ($old_value ne $value) or # Values don't match
      (not $new_defined) # Explicitly setting to NULL (ie.., TIMESTAMP)

      #($old_defined and (not $new_defined or $value eq '')) or # Old value defined, and either new isnt, or is empty string
      #( $value ne '' and (not $old_defined or $old_value eq '' or ($old_value ne '' and $value ne $old_value)) )
      # new value is something, and either old is undefined/empty string or the two values dont match.
      ###or (not $old_defined and not $new_defined) # If neither defined, set, as will set to NULL
      # REMOVING ABOVE 12/12/03, as TIMESTAMPS WILL BE DONE VIA EMPTY STRING (and internal set to NULL)
    )
    {

      if ($self->{DEBUG}||$DEBUG||1)
      {
        #print STDERR "SET_UNCHECKED ($self//$key): OD=$old_defined, ND=$new_defined, OV=$old_value, V=$value\n";
      }

      if ($value eq '') { $value = undef; } # Clearing form (or explicit NULL). Set to NULL (so numbers don't get assigned empty string, i.e., and implicity '0')..

      $real_changes{$key} = $value;
    }
    else
    {
      #print STDERR "KEY=$key, OLD_DEFINED=$old_defined, NEW_DEFINED=$new_defined, OLD_VALUE=$old_value, NEW_VALUE=$new_value\n";

    }
  }
  $self->SUPER::set_unchecked(%real_changes) if (%real_changes);
}

# To generate the WHERE clause, we need to know a unique set of values.
# If SCHEMA->[1] is an array ref, we do such.

sub generate_where_clause
{
  my ($self) = @_;

  my ($key_name, @othercols) = $self->key_name;
  if (not $key_name)
  { MalyDBO->system_error("Unable to generate WHERE clause, no schema keys set up."); }

  my @wherecols = ($key_name, @othercols); #ref $key_name ? @{$key_name} : ($key_name);

  # Generate WHERE clause, and take care of NULL keys
  my @where_parts = ();
  my @where_ph = ();
  foreach my $col (@wherecols)
  {
    my $value = $self->getold($col);
    if (!defined $value) # Use as FOO IS NULL
    {
      push @where_parts, "$col IS NULL";
    } else { # Normal bind value
      push @where_parts, "$col = ?";
      push @where_ph, $value;
    }
  }
  my $where = join(" AND ", @where_parts);
  return ($where, @where_ph);
}

sub update
{
  my ($self, @set) = @_;
  return undef if $self->is_new;
  $self->set(@set);
  my $record = $self->internal_rec;
  my %changes = %{$record->{CHANGES}} if (ref $record->{CHANGES});
  #print STDERR "ALL CHANGES=".join(", ", %changes)."\n";
  #print STDERR "SCHEMA IS REALLY $self->{SCHEMA}->[0]\n";
  my %valid_changes = $self->ignore_invalid_columns(%changes);
  #print STDERR "VALID CHANGES=".join(", ", %valid_changes)."\n";
  return undef unless %valid_changes;

  # Do data encryption if required.

  my $encrypt_fields = eval '$' . ref($self) . '::ENCRYPT';
  my @encrypt_fields = ref $encrypt_fields eq 'ARRAY' ? @$encrypt_fields : ();

  foreach my $enc_field (@encrypt_fields)
  {
    my $value = $rec->{$enc_field};
    my $enc_value = $CRYPT->encrypt3($value, $ENCRYPT_KEY);
    $valid_changes{$enc_field} = $enc_value;
  }

  my ($where, @where_ph) = $self->generate_where_clause();

  my $table = $self->table_name;

  my $i = 0; my @cols = CORE::grep { $i++ % 2 == 0 } %valid_changes;
  $i = 1; my @ph = CORE::grep { $i++ % 2 == 0 } %valid_changes;
  push @ph, @where_ph;

  my $query = "UPDATE $table SET " . join(", ", map { "$_ = ?" } @cols ) . " WHERE $where";

  $self->do($query, @ph);

  # Clear changes.
  $record->{CHANGES} = {};
  return $self if defined wantarray;
}

sub insert
{
  my ($this, %hash) = @_;
  my $self = ref($this) ? $this : $this->new($this->get_schema);
  $self->set(%hash);
  return undef unless ($self->has_pending_changes);

  my $uniqkey = undef;
  my $table = $self->table_name;
  my $pricol = $self->key_name;
  if ($pricol and $self->get($pricol) eq '')
  {
    $self->set($pricol, $self->unique_key);
  }

  my $record = $self->internal_rec;
  my %changes = %{$record->{CHANGES}} if (ref $record->{CHANGES});
  #print STDERR "RECORD+".Dumper($record)."\n";
  my %valid_changes = $self->ignore_invalid_columns(%changes);

  # Do data encryption if required.

  my $encrypt_fields = eval '$' . ref($self) . '::ENCRYPT';
  my @encrypt_fields = ref $encrypt_fields eq 'ARRAY' ? @$encrypt_fields : ();

  foreach my $enc_field (@encrypt_fields)
  {
    my $value = $rec->{$enc_field};
    my $enc_value = $CRYPT->encrypt3($value, $ENCRYPT_KEY);
    $valid_changes{$enc_field} = $enc_value;
  }


  #my ($prelim_table, $pricol) = @{$self->{SCHEMA}};

  my @cols = ();
  my @ph = ();

  my $i = 0; push @cols, CORE::grep { $i++ % 2 == 0 } %valid_changes;
  $i = 1; push @ph, map { $_ eq '' ? undef : $_ } CORE::grep { $i++ % 2 == 0 } %valid_changes;
  my $query = "INSERT INTO $table SET " . join(", ", map { "$_ = ?" } @cols );
  $self->do($query, @ph);
  if ($pricol and ($self->get($pricol) eq '' and $uniqkey ne '')) # Set key into record.
  {
    $self->set($pricol, $uniqkey);
  }

  # Now put changes into RESULT hash for access via get()
  $record->{CURRENT} = $record->{CHANGES};
  #print "RECORD IS=".Dumper($self->{RECORDS})."\n";
  return $self if defined wantarray;
}

sub concat_char
{
  my ($self) = @_;
  return (ref $self->{SCHEMA} ? $self->get_schema->[2] : "") || ';'; # Default is ;
}

sub key_name
{
  my ($self) = @_;
  my $schema_key = $self->get_schema->[1];
  if (ref $schema_key eq 'ARRAY')
  {
    @values = map { uc $_ } @$schema_key;
  } else {
    @values = uc $schema_key;
  }
  return @values if wantarray;
  return $values[0];
}


sub delete
{
  my ($self) = @_;
  return undef if $self->is_new();
  my ($prikey, @otherkeys) = $self->key_name;
  my $table = $self->table_name;

  my ($where, @where_ph) = $self->generate_where_clause();
  my @ph = @where_ph;

  my $do = "DELETE FROM $table WHERE $where";
  $self->do($do, @ph)
    or MalyDBO->internal_error("DB Error: ".$DBI::errstr);
  $self->SUPER::delete();
  return $self;
}


sub connect
{
  my ($this) = @_;
  $this->internal_error("Database connection not configured.") unless @DBPARAMS;
  if (!$DBH)
  {
    $DBH = DBI->connect(@DBPARAMS) or
      MalyDBO->system_error("Cannot connect to database.");
    $DBH->{ShowErrorStatement} = 1;
    $DBH->{FetchHashKeyName} = "NAME_uc";
  }
}

sub generate_where_by_text
{
  my ($self, @text) = @_;
  my $where = join(" AND ", @text);
  return ($where);
}

sub generate_where_by_hash
{
  my ($self, %h) = @_;
  my @keys = keys %h;
  my $where = join(" AND ", map { "$_ = ?" } @keys);
  my @ph = map { $h{$_} } @keys;
  return ($where, @ph);
}

sub END
{
  $DBH->disconnect() if ($DBH);
}

sub unique_key
{
  my ($self) = @_;
  my $table = $self->table_name;
  my ($key, @othercols) = $self->key_name;
  my $where = join(" AND ", map { "$_ = ?" } @othercols);
  my @ph = map { $x=$self->get($_);$x } @othercols;

  return undef unless $key; # Bogus key (none)
  $self->connect();
  $where = "WHERE $where" if $where;
  my $query = "SELECT $key FROM $table $where ORDER BY $key DESC LIMIT 1";
  my $sth = $DBH->prepare($query);
  $sth->execute(@ph);
  my ($id) = $sth->fetchrow_array();
  $sth->finish;
  # May have text in it (in front!)
  if ($id =~ /^(\D+)(\d+)$/)
  {
    my @id_parts = split(/(\d+)/, $id);
    $id_parts[$#id_parts]++;
    $id = join("", @id_parts);
  } else {
    $id++;
  }
  return $id;
}

sub col_in # Takes ("COL", @array) and forms "COL IN ($array[0],$array[1],...)" or "COL IN (NULL)" if none in list.
{
  my ($self, $col, @values) = @_;
  @values = map { $_ eq '' ? 'NULL' : $_ } @values;
  my $values = join(",", @values);
  $values = "NULL" if ($values eq ''); # In case nothing passed!
  return ["$col IN ($values)"];
}

sub col_not_in # Takes ("COL", @array) and forms "COL NOT IN ($array[0],$array[1],...)" or "COL NOT IN (NULL)" if none in list.
{
  my ($self, $col, @values) = @_;
  my $values = join(",", @values);
  $values = "NULL" if ($values eq '');
  return ["$col NOT IN ($values)"];
}

sub col_has # Insert into search...as parameter
{
  my ($self, $column, $value) = @_;
  #return ["1 = 0"] unless $value; # Don't want to match if empty list or ,,
  my $concat_char = $self->concat_char;
  return ["$column REGEXP CONCAT('(^|$concat_char)', '$value', '($concat_char|\$)')"];
}

# regex, field, value (per row), 
# Allows multiple lines, will add all each together, and join with 'boolean' field (or AND)
sub search_regex_form
{
  my ($this, @in_params) = @_;
  my @params = ();
  my %form = ();

  for (my $i = 0; $i < @in_params; $i++)
  {
    my $param = $in_params[$i];
    if ($param =~ /^(FIELD|REGEX|VALUE)$/i)
    {
      my $value = $in_params[++$i];
      $form{$param} = $value;
    } elsif ($param =~ /^(ACTION)$/i) {
      $i++; # Get rid of value.
    } elsif(ref $param) {
      push @params, $param;
    } # Else, ignore.
  }

  my @fields = ref $form{FIELD} ? @{$form{FIELD}} : ($form{FIELD});
  my @regexes = ref $form{REGEX} ? @{$form{REGEX}} : ($form{REGEX});
  my @values = ref $form{VALUE} ? @{$form{VALUE}} : ($form{VALUE});

  for (my $i = 0; $i < @values; $i++)
  {
    my $regex = $regexes[$i];
    my $field = $fields[$i];
    my $value = $values[$i];

    next unless $value; # Skip invalid

    if ($regex eq 'start')
    {
      push @params, (["$field RLIKE '^$value'"]);
    }
    elsif ($regex eq 'end')
    {
      push @params, (["$field RLIKE '$value\$'"]);
    }
    elsif ($regex eq 'is')
    {
      push @params, (["$field = '$value'"]);
    }
    #elsif ($regex eq 'has')
    else # Default for invalid.
    {
      push @params, (["$field RLIKE '$value'"]);
    }

  }

  return $this->search(@params) if @params;
}

sub enable_multipage
{
  my ($self, $offset, $limit) = @_;
  $self->add_params(LIMIT=>"$offset,$limit");
  $self->{MULTIPAGE} = 1;
}

sub col_in_all
{
  my ($self, $col_in, $get_col) = @_;
  my $values = $self->get_all($get_col, 1);
  return ["$col_in IN $values"];
}

sub get_all
{
  my ($self, $col, $concat) = @_;
  my @values = $self->SUPER::get_all($col, $concat);
  if ($concat)
  {
    return "($values[0])"; #suitable for SQL 'COL IN ...'
  }
  else
  {
    return @values;
  }
}

sub get_primary_key
{
  my ($self) = @_;
  my $pricol = $self->key_name;
  my $prival = $self->get($pricol);
  if ($prival eq '')
  {
    $prival = $self->unique_key;
    $self->set($pricol, $prival);
  }
  return $prival;
}

sub refresh # Last query is re-run. ALL records are erased. Hopefully any new ones added will be found.
{
  my ($self) = @_;

  my $query = $self->{LAST_SQL};
  my $ph = $self->{LAST_PH};
  my @ph = ref $ph ? @$ph : ();

  if ($query)
  {
    $self->search_sql($query, @ph);
  } else { # Just one record, just added.
    my $prikey = $self->key_name;
    my $prival = $self->get($prikey);
    $self->search($prikey,$prival);
  }
}

1;
