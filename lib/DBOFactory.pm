
####################
package DBOFactory;

use lib "../../MalyCGI";
use base "MalyDBO";
use Data::Dumper;
use UNIVERSAL;

our $CONF = undef;

sub new
{
  my ($this, $table) = @_;
  my $table = $table;
  #print STDERR "TABLE=$table, @_\n";
  my $class = ref $this || $this;
  my $table_ref = $CONF->{uc $table};
  #print STDERR "CALLER=".join(",", caller())."\n";
  #print STDERR "TR ($table)=".Dumper($table_ref)."\n";
  my $key = $table_ref->{KEY};
  my $self = $class->SUPER::new(lc $table, lc $key);
  $self->{TABLE_NAME} = $table;
  $self->{TABLE_META} = $table_ref;
  return $self;
}

sub init_config
{
  my ($conf) = @_;
  $CONF = $conf;
}

# GENERATE FROM .CONF FILE!!!!!!!!!
sub db2cgi # ALLOW being called via children, in case they need to specify anyything special.
{
  my ($self, @db2cgi) = @_;
  my $linkref = $self->{TABLE_META}->{LINK};

  # FROM THESE POSSIBLE SYNTAXES:

  # "destfield:destkey" => 
  #				"srctable:srckey"
  #				[ "srctable:srckey" , OPTIONAL_WHERE_LIST ]
  #				[ "srcfield", OPTIONAL_WHERE_LIST ] # first arg, w/o : implies it's a field
  #				[ code_ref, OPTIONAL_PARAM_LIST ] # $self will get passed implicitly!
  #
  # [ "destfield:destkey" => "viatable:viadestkey:viasrckey" => "srctable:srckey" ],
  # [ "destfield:destkey" => "viatable:viadestkey:viasrckey" => ["srctable:srckey", where... ] ],
  # [ "destfield:destkey" => "viatable:viadestkey" => "srcfield" ], # no need for viasrckey, as field
  # 
  #{
  #  dest=>"destfield",
  #  destkey=>"destkey",
  #  src=>"srcfield",
  #  dbosrc=>"srctable",
  #  code=>subref
  #  args=>[ ... ] # to code()
  #  srckey=>"srckey", # If srckey is not defined, then 'src' is a field from the parent dbo, and not a table.
  #  where=>[ OPTIONAL_WHERE_LIST ],
  #  via=>"viatable",
  #  viasrckey=>"viasrckey", # What gets grafted with srckey, IF src is a table!!!
  #  viadestkey=>"viadestkey", # What gets grafted with destkey
  #}

  # Typically speaking, there is a 'via' when there are three tables involved:
  # this table, 'me'
  # the linking table, 'via', which links 'me' to 'src', typically involving only keys (numbers)
  # the source table, 'src', which has sensical info to display (i.e. names, descriptions), etc..
  #
  # This type of indirection makes sense when the source table has 'global' information that will
  # be used repeatedly through different data sets of this table ('me')
  # i.e, sysrem requirements for a product -- typically similar, but not identical, but having
  # valuable information that isn't worth retyping.

  # Any text args to the where list will be macro substituted

  # Converts to:

  # destfield => [ object->new, mykey, theirkey, where, ... ]
  # destfield => [ code, params, ... ]

  # OR if using intermediary table:

  # via_field => [ srcobj->new, viasrckey, srckey ],
  # dest_field => [ viaobj->new, destkey, viadestkey ],

  if (ref $linkref eq 'ARRAY')
  {
    my @linklist = @$linkref;
    for (my $i = 0; $i < @linklist; $i++)
    #foreach my $link (@linklist)
    {
      my $link = $linklist[$i];
      # Convert to hash.
      my %link = ();
      if (ref $link eq 'ARRAY' or not ref $link)
      {
        if (ref $link eq 'ARRAY') # MAY or may not have via specified.
	{
	  my @link = @$link;
	  $dest = $link[0];
	  $src = $link[$#link];
	  $via = $link[1] if @link == 3;
	} else { # Not ref link, normal a => b
	  $dest = $link;
	  $src = $linklist[++$i]; # Need to get next item.
	  #print STDERR "DEST=$dest, SRC=$src\n";
	}

	if (ref $src eq 'ARRAY') # Has extra where, or is code ref.
	{
	  my @src = @$src;
	  if ($src[0] eq 'CODE')
	  {
	    ($link{CODE}) = shift @src;
	    ($link{ARGS}) = [$self, @src];
	  } elsif ($src[0] =~ /:/) { # DBO Table
            ($link{DBOSRC}, $link{SRCKEY}) = split(":", shift @src);
	    $link{WHERE} = \@src;
	  } else {
	    $link{SRC} = shift @src;
	  }
	} elsif ($src =~ /:/) {
          ($link{DBOSRC}, $link{SRCKEY}) = split(":", $src);
	} else {
	  $link{SRC} = $src; # Field.
	}

	($link{DEST}, $link{DESTKEY}) = split(":", $dest);
	($link{VIA}, $link{VIADESTKEY}, $link{VIASRCKEY}) = split(":", $via);


      } elsif (ref $link eq 'HASH') { # Already as we want it.
        %link = map { (uc $_, $link->{$_}) } %$link;
      }

      # NOW THAT IN HASH FORM, CONVERT!
      if ($link{CODE})
      {
        $link{SRC} = $link{CODE};
        $link{WHERE} = $link{ARGS} if $link{ARGS};
      } elsif ($link{DBOSRC}) {
        $link{SRCOBJ} = DBOFactory->new($link{DBOSRC});
      }

	#print STDERR "TABLE $self->{TABLE_NAME}, LINK=".Dumper(\%link)."\n";

      if ($link{VIA}) # Need to make TWO separate ones.
      {
        $link{VIAOBJ} = DBOFactory->new($link{VIA});
	# Hmmmm!
	# [ "SYSREQ:VER_ID" => "PRODUCT_SYSREQ_LINK:VER_ID:SYSREQ_ID" => "PRODUCT_SYSREQ:SYSREQ_ID" ],
        # [ "destfield:destkey" => "viatable:viadestkey:viasrckey" => "srctable:srckey" ],
        #
        # viatable => [ viatableobj, destkey, viadestkey ],
        # dest_table => [ srctableobj, viatable{viasrckey}, srckey ],

        # SYSREQ_ID=>[ ProductSysReqLink->new(), "VER_ID", "VER_ID" ],
        # SYSREQ=>[ ProductSysReq->new(), "SYSREQ_ID{SYSREQ_ID}", "SYSREQ_ID" ],


        push @db2cgi,
	(
	  $link{VIA} => [ $link{VIAOBJ}, $link{DESTKEY}, $link{VIADESTKEY} ],
	  $link{DEST} => [ $link{SRCOBJ}, $link{VIA}.'{'.$link{VIASRCKEY}.'}', $link{SRCKEY} ],
	);
      } else {
        push @db2cgi,
	(
	  $link{DEST} => [ $link{SRCOBJ}||$link{SRC}, $link{DESTKEY}, $link{SRCKEY}, (ref $link{WHERE} eq 'ARRAY' ? @$link{WHERE} : () ) ],
	);
      }
    }
  }

  return @db2cgi;
}

sub sort
{
  my ($self, %decoded_form) = @_;
  my $sortby = $self->{TABLE_META}->{SORTBY};

  # We're given one form, yet dont know what level we're at! so perhaps we need to get the form decoded
  # elsewhere.

  $self->multi_commit_sorted_list(%decoded_form);
}

sub recursive_commit
# Does recursive commiting, handles sorting, adds entries and deletes.
# BUT JUST FOR THE CURRENT RECORD.
#
# Takes entries like this: where the numbers are MALYITER values, NOT prikeys!!!
# OVERVIEW => 1, STEPS[0]{STEP_ID} => 1, STEPS[0]{TEXT} => "Blah", STEPS[0]{REFERENCE_IMAGES} => ['1:1.jpg', '3:2.jpg' ]
#
# and turns into:
#
# { overview=>1, steps=>[ { step_id=>1, text=>"Blah", reference_images=> [ '1:1.jpg', ...] } ] }

# *** data may be encoded, as with reference_images, in that case, we need to decode according to db.conf
#
# can take a prefix, which signifies what key to get use to get to proper data
#
# THIS FUNCTION IS USED IN CASE WHERE WE EDIT A SINGLE ENTRY -- I.E. A SINGLE EDIT/ADD PAGE. THIS CAN TAKE CARE OF
# SUBENTRIES, THOUGH.
{
  my ($self, $prefix, @data) = @_;

  my $meta = $self->{TABLE_META};

  my %struct = ();

  my $base_struct = {};

  if (@data == 1 and ref $data[0] eq 'HASH') # Already in format!
  {
    $base_struct = $data[0];
  } else {
    MalyVar->struct_update($base_struct, undef, @data);
  }

  if ($prefix)
  {
    my $start = MalyVar->var_evaluate($base_struct, $prefix);
    %struct = ref $start eq 'HASH' ? %$start : ();
  } else {
    %struct = %$base_struct;
  }

  print STDERR "STRUCT=".Dumper(\%struct)."\n";
  print STDERR "BASE STRUCT=".Dumper($base_struct)."\n";

  print STDERR "TABLE $self->{TABLE_NAME}, prefix=$prefix, GIVEN=".Dumper(\@data)."\n";


  # COULD BE MULTIPLE THINGS.... could be named differently between tables....


  # Simple prikey => prival is incomplete, as there may be a WHERE clause to the binding.
  # SO IN ALL ACTUALITY, JUST GET THE BINDING CRITERIA!!!!
  # buth THAT only helps when it can be converted to a SET clause, which may be impossible,
  # given direct sql insertion...
  # HELL, LETS JUST HAVE A WHERE CLAUSE IN db.conf

  # 
  $self->commit(%struct);
  my $parentkey = $self->key_name;
  my $parentkeyvalue = $self->get($parentkey);

  foreach my $key (keys %struct) # Only concern yourself with what was submitted....
  {
    my $value = $struct{$key};
    print STDERR "SUBREC $key= $meta->{FIELDS}->{$key}->{SUBREC}, STRUCT=".Dumper($struct{$key})."\n";
    if ($meta->{FIELDS}->{$key}->{SUBREC}) # Subrecord!
    {
      my $reorder = $meta->{FIELDS}->{$key}->{REORDER};
      my $subrec = $self->get($key) || DBOFactory->new($key);
      my $addparentwhere = $subrec->{TABLE_META}->{ADDPARENTWHERE};
      my %addparentwhere = ();
      if (ref $addparentwhere eq 'HASH')
      {
        foreach my $apk (keys %$addparentwhere)
	{
          $addparentwhere{$apk} = MalyVar->evaluate_content($addparentwhere->{$apk}, $self);
	}
      } else {
        %addparentwhere = ($parentkey=>$parentkeyvalue);
      }
      my $prikey = $subrec->key_name;
      my $addkey = $subrec->{TABLE_META}->{ADDKEY};
      $self->system_error("Subrecord '$key' must be an instance of DBOFactory.") unless $subrec->can("recursive_commit");
      my @raw_subrec_data = ref $value eq 'ARRAY' ? @$value : ($value);

      my @keepers = (); # Which encoded subrecords to keep

      # Convert encoded data to decoded data....
      my @subrec_data = ();
      for (my $iter = 0; $iter < @raw_subrec_data; $iter++)
      {
        my $raw_subrec = $raw_subrec_data[$iter];
        if (not ref $raw_subrec and $raw_subrec ne '')
	{
	    my $format = $subrec->{TABLE_META}->{ENCODED_FORMAT};
	    my $sortby = $subrec->{TABLE_META}->{SORTBY};
	    my $char = $subrec->{TABLE_META}->{ENCODED_BY} || ":";
	    if ($format)
	    {
	      my @format = split($char, $format);
	      my @data = split($char, $raw_subrec);
	      my %subrec_hash = ();
	      for (my $i = 0; $i < @format; $i++)
	      {
	        $subrec_hash{$format[$i]} = $data[$i];
	      }
	      if ($sortby and not grep { $sortby eq $_ } @format) # Sorting by field not in data, implicitly the iter # !!!
	      {
	        $subrec_hash{$sortby} = $iter;
	      }
	      push @subrec_data, \%subrec_hash;
	    } else {
	      $self->system_error("Unable to save multilist, no encoding scheme defined.");
	    }
	} else {
	  push @subrec_data, $raw_subrec;
	}
      }

      #print STDERR "RAW DATA=".Dumper(\@raw_subrec_data)."\n";
      print STDERR "DECODED DATA=".Dumper(\@subrec_data)."\n";

      for ($subrec->first; $subrec->more; $subrec->next)
      {
        my $pkvalue = $subrec->get($prikey);
	my $found = 0;
        foreach my $subrec_item (@subrec_data)
	{
	  if (ref $subrec_item eq 'HASH')
	  {
	    if ($subrec_item->{$prikey} == $pkvalue and 
	      not $subrec_item->{"_DELETE"}) # FOUND!
	    {
	      #print STDERR "FOUND! SRI=".Dumper($subrec_item)."\n";
	      $found = 1;
              if (not $meta->{FIELDS}->{$key}->{TYPE}) # Just list to maybe reorder, so dont mess up it's subrecords (prolly excluded)
	      {
	        $subrec->commit(%$subrec_item, %addparentwhere);
	      } else { # Otherwise, we can mess with it's subrecords, cuz they are there....
	        $subrec->recursive_commit(undef, %$subrec_item, %addparentwhere);
	      }
	    }
	  }
	}
	#print STDERR "FOIND=$found\n";
	$subrec->delete unless $found;
      }

      # NOW, handle adding data. (subrecord entries)

      # We know to add, if prikey is undefined....
      foreach my $add_subrec (@subrec_data)
      {
        print STDERR "CHECK TO ADD=$prikey/$add_subrec->{$prikey}, $addkey/$add_subrec->{$addkey}\n";
        next if $add_subrec->{$prikey} ne '' or ($addkey and $add_subrec->{$addkey} eq '');
	#print STDERR "KEEPING\n";
        $subrec->append();
	if (ref $add_subrec eq 'HASH')
	{
	  my %add_data = %$add_subrec;
	  next unless %add_data;
	  $subrec->commit(%add_data, %addparentwhere);
	  print STDERR "JUST DID ADD COMMIT\n";
	}
	$pkvalue = $subrec->get($prikey);
      }

      # Handle sorting....maybe.
      my $subrec_sortkey = $subrec->{TABLE_META}->{SORTBY};

      if ($subrec_sortkey)
      {
        $subrec->multi_commit_sorted_list($subrec_sortkey);
      }

      #

      $self->set($key, $subrec);
    }
  }

  # Now go through subrecords as defined in db.conf that are also a multilist. Remove if not mentioned in struct!
  # BUT ONLY WHEN WERE SUPPOSED TO MANAGE IT!
  # We know that if $prefix is undefined, we're doing a multiedit. otherwise we're doing an edit.
  if (not $self->is_new)
  {
    my $fieldkeys = $prefix eq '' ? ($meta->{MULTIEDIT} || $meta->{EDIT}) : $meta->{EDIT};
    my @fields = ref $fieldkeys eq 'ARRAY' ? @$fieldkeys : ();
    foreach my $field (@fields)
    {
      if ($meta->{FIELDS}->{$field}->{SUBREC} and $meta->{FIELDS}->{$field}->{TYPE} eq 'multilist' and
        not $struct{$field}) # Wasnt in form, was removed!
      {
        my $subrec = $self->get($field);
        $subrec->delete_all if UNIVERSAL::isa($subrec, "MalyDBOCore");
      } elsif ($meta->{FIELDS}->{$field}->{TYPE} eq 'checkbox') { # Removed? Explicitly set.
        $self->set($field, $struct{$field});
      }
    }
  }

  $self->commit();
}

sub recursive_commit_all
# Does recursive commits on all entries of $self, does sorting of $self
# Adds new records to self, deletes records of self not in form.
# Appropriate for Multiedit (or Sort) use.
#
{
  my ($self, %form) = @_;

  my $base_struct = {};
  MalyVar->struct_update($base_struct, undef, %form);

  #print STDERR "FORM=".Dumper(\%form)."\n";
  #print STDERR "BASE=".Dumper($base_struct)."\n";

  my $struct = MalyVar->var_evaluate($base_struct, $self->{TABLE_NAME});
  # We prepend, since in a loop, with the name of the table.

  #print STDERR "STRUCT=".Dumper($struct)."\n";

  my @struct = ref $struct eq 'ARRAY' ? @$struct : ($struct);

  # THIS MAY BE TOTALLY OUT OF ORDER, SO WE MUST GO THROUGH EACH ONE!

  my $prikey = $self->key_name;
  my $addkey = $self->{TABLE_META}->{ADDKEY};
  for ($self->first; $self->more; $self->next)
  {
    my $prival = $self->get($prikey);
    next if $prival eq '';
    my $iter = $self->{ITER};
    my $found = 0;
    for (my $i = 0; $i < @struct; $i++)
    {
      if ($struct[$i]->{$prikey} == $prival and not $struct[$i]->{_DELETE} ) # Found!
      {
        #print STDERR "DOING COMM WHERE MATCH=$prival, STR=".Dumper($struct[$i])."\n";
	$found = 1;
	$self->recursive_commit(undef, $struct[$i]);
      }
    }
    $self->delete if not $found;
  }

  # Additions, where prikey is empty! and yet some other value is NOT!
  foreach my $item (@struct)
  {
    if (ref $item eq 'HASH' and %$item and $item->{$prikey} eq '' and (not $addkey or $item->{$addkey} ne '')) # DO add!!!
    {
      $self->append();
      $self->recursive_commit(undef, $item);
    }
  }

  # Do sorting!

  my $sortkey = $self->{TABLE_META}->{SORTBY};

  if ($sortkey)
  {
    $self->multi_commit_sorted_list($sortkey);
  }

}
1;
