# Does variable substitutions using #MACRO# format, given the hashref containing values....can be nested/multidimensional.

# Syntax is like:
#
#
#
#
# FOO{BAR} : FOO is hash, BAR is key, get value where BAR is key
# FOO[1]
# FOO{BAR}[1]{STUFF}
#
# FOO{KEY=VALUE} : FOO is really an array, but we want the hash underneath it where KEY is VALUE
# FOO[INDEX=VALUE] : FOO is really an array, but we want the INNER array, where index INDEX has value VALUE
#
# I.e., in case where we use a '=', the brackets/braces determine what we are LOOKING for, rather than
# what we have (determined by the var name/obj to the left)

package MalyVar;

use Data::Dumper;
use UNIVERSAL qw(isa can);
use URI::Escape ();
use HTML::Entities ();
our $DEBOOG = 0;

sub struct_update # Updates arbitrary structure with a flat hash, which is converted and merged.
{
  # Stuff may be invalid like BLAH{FLUKE}_POOP....
  # so traverse to point where parent should be, and just abort, not erase!
  my ($self, $struct, $pseudo, %hash) = @_;
  foreach my $key (keys %hash)
  {
    #print STDERR "SETTING $key to $hash{$key}, FROM=".join(",", caller(1))."\n" if $key eq 'GROUP';
    my ($varname, $remain) = $key =~ /^([^\{\[]+)(.*)/; # var name is everything up until first { or [
    next unless $varname;

    my $temp_struct = \($struct->{$varname});
    
    while ($remain =~ /^\{(.*?)\}/ or $remain =~ /^\[(.*?)\]/)
    {
      my $end = $';
      my $name = $1;

      if ($remain =~ /^\{/)
      {
        $temp_struct = \($$temp_struct->{$name});
      } 
      elsif ($remain =~ /^\[/) 
      {
        $temp_struct = \($$temp_struct->[$name]);
      }
      $remain = $end;
    }

    next if $remain; # OOPS, we had extra crap! and not valid, either.

    $$temp_struct = $hash{$key}; # Update
  }
  return $struct if defined wantarray;
}

sub var_evaluate # Array, hash or scalar.
{
  my ($self, $vars, $var, $pseudo, $all) = @_;

  # By default, get $pseudo from $vars->get_pseudo_meta if $pseudo is undef and $vars is dbo.
  $pseudo ||= $vars->get_pseudo_meta if isa($vars, "MalyDBOCore");

  # NEW: If ask for a hash, but really an array, interpolate as an array of hashrefs,
  # and get first hashref that matches criteria...
  # I.e., #FOOBAR{hashkey=VALUE}#

  # To get all values instead of just the first:
  # BLAHBLAH{+VARNAME} instead of BLAHBLAH{VARNAME}
  #

  # NEW: recursive data structures.... like FOOBAR{BIN}{BAZ}
  #my ($varname, $remain) = $var =~ /^([^{[]+)(.*)/; # var name is everything up until first { or [
  my ($varname, $remain) = $var =~ /^([\w:]+)(.*)/; # var name is everything up until first { or [
  my $func = undef;

  if ($varname =~ /(.+):(.+)/)
  {
    ($func, $varname) = ($1,$2);
  }

  if ($remain)
  {
    my $tempvar = $self->get_hash_value($vars, $varname, undef, $pseudo);

    #while ($remain =~ /^\{(.*?)\}/ or $remain =~ /^\[(.*?)\]/)
    # We dont use the above anymore, to support nested {} or [].
    while ($remain =~ /^(\{)(.*)/ or $remain =~ /^(\[)(.*)/)
    {
      # The KEY is the stuff in between the braces.
      # The END is the stuff after the closing brace.
      my $type = $1;
      my $closing = { '{'=>'}', '['=>']' }->{$type};
      my @chars = split(//, $2);
      my $dial = 0;
      my $end = undef;
      my $key = "";
      my @key_parts = ();

      for (my $k = 0; $k < @chars; $k++)
      {
        $dial-- if ($chars[$k] eq $type); # Found another opening.
        $dial++ if ($chars[$k] eq $closing); # Found closing.

	if ($dial == 1) # Found closing marker!
	{
	  $end = join("", @chars[$k+1..$#chars]);
	  $key = join("", @key_parts);
	  last;
	}
	# Else, add character to key.
	push @key_parts, $chars[$k];
      }

      my $temp_vars = {%$vars, $tempvar};

      # NOW, we need to fix below, so key of #P{BLAH}# CAN be handled!
      #$key =~ s/#(\w+)#/$self->var_evaluate($temp_vars, $1, $pseudo)/ge;
      $key = $self->evaluate_content($key, $temp_vars, $pseudo);

 # WE should arbitrarily supporting getting all. Th
 # Use a different syntax for getting all in an array from a key.

      if ($type eq '{') # Hash.
      {
        my $id = undef;
        if ($key =~ /=/) # FOO{key=BAR} or FOO{key+=BAR} (latter meaning return ALL)
	{
	  if ($key =~ /[+]=/)
	  {
	    ($id,$key) = $key =~ /^(.+)[+]=(.*)$/;
	    $tempvar = $self->get_hash_value($tempvar, $key, $id, $pseudo, 1);
	  } else {
	    ($id,$key) = $key =~ /^(.+)=(.*)$/;
	    $tempvar = $self->get_hash_value($tempvar, $key, $id, $pseudo);
	  }
	} elsif (ref $tempvar or isa($tempvar, "UNIVERSAL")) {
	  $tempvar = $self->get_hash_value($tempvar, $key, undef, $pseudo, ( ($key =~ /^[+]/) || $all) );
	  # NEED TO FIX, ie. for maly-loop!
	} else {
	  return undef; # So we can check with maly-if defined=1 var="FOO"
	  #return "";
	}
      } 
      elsif ($type eq '[') # Array
      {
        if ($key =~ /=/)
	{
	  ($id,$key) = $key =~ /^(.+)=(.+)$/;
	  $tempvar = $self->get_array_value($tempvar, $key, $id);
	}
        elsif ((not ref $tempvar or ref $tempvar eq 'HASH' or ref $tempvar eq 'SCALAR') and $key eq '0') 
	  # Just one record, show that instead.
	{
	  $remain = $end;
	  next;
	} elsif (ref $tempvar eq 'ARRAY' or isa($tempvar, "UNIVERSAL")) {
	  $tempvar = $self->get_array_value($tempvar, $key);
	} else {
	  return "";
	}
      }
      $remain = $end;
    }

    return if not defined wantarray;
    return $func ? $self->func_evaluate(lc $func, $tempvar) : $tempvar;
  } else { # Just a scalar... (OR OBJECT)
    # Allow for '0' value, only try other values if not empty string (undef/null)
    my $v = $self->get_hash_value($vars, $varname, undef, $pseudo); 
    return if not defined wantarray;
    return $func ? $self->func_evaluate(lc $func, $v) : $v;
  }
}

sub html_format
{
  my ($text) = @_;
  $text =~ s/&/&amp;/g;
  $text =~ s/</&lt;/g;
  $text =~ s/>/&gt;/g;
  $text =~ s/\n/<br>\n/g;
  $text =~ s/\t/&nbsp;&nbsp;/g;
  $text =~ s/  /&nbsp;&nbsp;/g;
  $text =~ s{((https|http|ftp)://\S+)}{<a href="\1">\1</a>}g;
  return $text;
}

sub func_evaluate
{
  my ($this, $func, $v) = @_;
  $func =~ /^list(.*)/ && return make_list($v, $1);
  $func =~ /^orlist(.*)/ && return make_or_list($v, $1);
  if ($func eq 'noquot') { $v =~ s/["']//g; return $v; }; # Remove quotes.
  if ($func eq 'date')
  {
    my ($y, $m, $d) = split("-", $v); 
    return sprintf("%02u/%02u/%04u", $m, $d, $y);
  }
  $func eq 'num' && return ($v eq '' ? '0' : "$v"); # Show 0 if not set.
  $func eq 'signed' && return ($v > 0 ? "+$v" : $v); 
  $func eq 'int' && return ($v eq '' ? '0' : int($v)); 
  $func eq 'ref' && return ref $v;
  $func eq 'html' && return html_format($v); # Format suitable for html display of text
  $func eq 'defined' && return (defined $v);
  $func eq 'scalar' && (return get_scalar_value($v));
  $func eq 'keys' && (ref $v eq 'HASH' ? return keys %$v : return () );
  $func eq 'values' && (ref $v eq 'HASH' ? return values %$v : return () );
  $func eq 'encoded' && (return URI::Escape::uri_escape($v));
  $func eq 'htmlescape' && (return HTML::Entities::encode_entities($v));
  $func eq 'dumper' && return Dumper($v);
  if ($func eq 'classmap') # Take text, make something appropriate for CSS class name
  {
    $v = lc($v);
    $v =~ s/\W+//g;
    return $v;
  }
}

sub make_or_list
{
  my ($value, $kind) = @_;
  my @values = ();

  for (my $i = 1; $i < $value; $i *= 2)
  {
    unshift @values, $i if ($value & $i)
  }

  return make_list(\@values, $kind);
}

sub make_list
{
  my ($v, $kind) = @_;
  $kind = '_comma' unless $kind;
  $kind = lc($kind);
  my @values = ref $v eq 'ARRAY' ? @$v : ();

  my $char = ",";
  if ($kind eq '_comma')
  {
    $char = ',';
  } elsif ($kind eq '_tab') {
    $char = '\t',
  } elsif ($kind eq '_space') {
    $char = ' ';
  } elsif ($kind eq '_newline') {
    $char = '\n';
  } elsif ($kind eq '_colon') {
    $char = ':';
  } elsif ($kind eq '_semicolon') {
    $char = ';';
  }
  return join($char, @values);
}

sub get_scalar_value
{
  my ($v) = @_;
  if (ref $v eq 'ARRAY')
  {
    return scalar @$v;
  } 
  elsif (isa($v, "UNIVERSAL") and $v->can("count"))
  {
    return $v->count;
  } else {
    return 0;
  }
}
 # Since just one, gets first inner hash automatically. NEED TO HANDLE FUNC CALL BEFORE THIS STEP

# Do we ever want to return a hash? or array? this above func should be purely for string interpretation. thus, should only return scalar.
# 


sub get_ref_or_value # Return # keys if hash, first value if array, or value if scalar.
{
  my ($self, $value) = @_;
  my $rv = undef;

  if (ref $value eq 'HASH')
  {
    $rv = scalar keys %$value;
  } elsif (ref $value eq 'ARRAY' and @$value == 1) { # JUST GET FIRST ONE!
    $rv = $value->[0];
  } elsif (ref $value eq 'ARRAY') {
    # Really want to return first value, man.
    #
    #return scalar @$value;
    $rv = $value->[0];
    # When we reference something like #FOO# then we just want the literal scalar() of it. 
    # However, when we do #FOO{BAR}# when FOO is really an ARRAY ref, THEN we want to get first one. (this is done in var_evaluate). get_ref_or_value is the last-stop before MalyTemplate.
  } elsif (ref $value and isa($value, "MalyDBOCore")) {
    $rv = $value->count();
  } elsif (ref $value) {
    $rv = $value;
    #return undef;
  } else {
    # Do escaping here (may need to be conditional!)
    $rv = $value;
  }

  return $rv;
}

sub flat_var_evaluate # Used with evaluate_content, will return sensible data if asked for scalar.
{
  my ($self, $vars, $var, $pseudo, $all) = @_;
  my $value = $self->var_evaluate($vars, $var, $pseudo, $all);
  my $retval = $self->get_ref_or_value($value);
  #print STDERR "ASKING FOR $var, WAS ".Dumper($value).", GOT '$retval'\n";
  return $retval;
}

# XXX TODO REMEMBER, THIS NEEDS TO ___SET___ THE VALUE BACK, SO WE'RE NOT CALLING THIS FOREVER...
# WE ALSO NEED TO RE-EVALUATE WHEN STUFF CHANGES !!!
# I.e., it needs to keep a record of how to link/calculate (basically, this ref.)
# Perhaps this should be moved to _PSEUDO_key, instead.

# i.e., if _PSEUDO_key exists, check binding criteria (will need to improve CODE to pass stuff instead of 
#		USING as internal args)
# and if not up to date (or unsure, OR not defined as 'key'), then get from _PSEUDO_key.

sub struct_eq # Takes two arbitrary structures (ARRAY,HASH,SCALAR or scalar non-refs), returns true if identical, false if not
{
  my ($s1, $s2) = @_;

  my $rs1 = ref $s1;
  my $rs2 = ref $s2;
  return undef unless $rs1 eq $rs2;

  if ($rs1 eq 'ARRAY')
  {
    my @s1 = @$s1;
    my @s2 = @$s2;
    return undef unless scalar(@s1) == scalar(@s2);

    for (my $i = 0; $i < @s1; $i++)
    {
      return undef unless struct_eq($s1[$i], $s2[$i]);
    }
    return 1;
  } elsif ($rs1 eq 'HASH') {
    my %s1 = %$s1;
    my %s2 = %$s2;
    return undef unless scalar(%s1) == scalar(%s2);
    return undef unless struct_eq( [keys(%s1)], [keys(%s2)] );

    foreach my $key (keys %s1)
    {
      return undef unless struct_eq($s1{$key}, $s2{$key});
    }
    return 1;
  } elsif ($rs1 eq 'SCALAR') {
    return $$s1 eq $$s2;
  } elsif ($rs1) { # Something else!
    return $rs1 eq $rs2; # Assume has memory location in string comparison.
    return undef;
  } else { # Plain scalars
    return $s1 eq $s2;
  }
}


sub get_pseudo_value # Should return undef when binding criteria matches (up-to-date), or no _PSEUDO_key
{
  my ($self, $vars, $key, $pseudo) = @_;

  my $pseudo_var = $pseudo->{$key};
  my $var = $vars->{$key};
  my $value = undef;


  return undef unless $pseudo_var;

  # Now check whether pseudo (CODE or DBO)
  if (ref $pseudo_var eq 'ARRAY') # Otherwise, it's a simple MalyVar mapping?
  {
    my ($first, @args) = @$pseudo_var;
    if (ref $first eq 'CODE')
    {
      my $sub = $first;
      my @subst_args = ();
      foreach my $arg (@args)
      {
        if (not ref $arg)
	{
          push @subst_args, MalyVar->evaluate_content($arg, $vars, $pseudo);
	} else { # Literal, i.e., object, array ref, etc...
	  push @subst_args, $arg;
	}
	# FIX BOTH WAYS, CHANGING @records to USE OF RECS->more()!!!
      }

      # Check binding criteria (if matches or not)
      # WHEN CHECKING BINDING CRITERIA FOR CODE, WE NEED TO SAVE THE LAST RUN'S VALUES
      # WE WOULD NEED TO STORE THIS ELSEWHERE, 

      my @last_args = ref $pseudo->{"_PSEUDO_${key}_LAST_ARGS"} ? @{ $pseudo->{"_PSEUDO_${key}_LAST_ARGS"} } : ();
      if (not @last_args or not struct_eq(\@last_args, \@subst_args) or not defined $vars->{$key})
      # Then we need to re-run.
      {
        $pseudo->{"_PSEUDO_${key}_LAST_ARGS"} = \@subst_args;
        $vars->{$key} = $sub->(@subst_args); # Update.
      }
    } elsif (ref $first and isa($first, "MalyDBOCore")) {
      my ($srckey, $dstkey, @where) = @args;
      # srckey = Outer records key that corresponds to some inner record key's value
      # dstkey = Inner records key that matches outer records key

      my $old_dstkey_value = $self->get_hash_value($vars, $dstkey, undef, $pseudo);
      my $old_value = $vars->{$key};
      my @old_params = ref $pseudo->{"_PSEUDO_${key}_LAST_PARAMS"} eq 'ARRAY' ? 
        @{ $pseudo->{"_PSEUDO_${key}_LAST_PARAMS"} } :();

      #my $dstvalue = $self->get_hash_value($vars, $srckey, undef, $pseudo);
      my $dstvalue = $self->var_evaluate($vars, $srckey, $pseudo, 1);
      # Since this MAY involve fancy key names (i.e, implicit get_all)
      # i.e., if we say DBO_OBJECT{COLUMN} for srckey, it will implicitly return an array of all values for COL

      # Evaluate, so can handle #XXX# macros in @where.
      @where = map { ref $_ ? $_ : MalyVar->evaluate_content($_, $vars, $pseudo) } @where;

      my @params = ();
      if (ref $dstvalue eq 'ARRAY') # COL IN (...)
      {
        #my $dvstr = join(",", @$dstvalue);
	#$dvstr = 'NULL' if $dvstr eq '';
        #@params = (["$dstkey IN ($dvstr)"], @where);

	# NEED TO CALL ONE FOR DMLDAP, BUT WE MAY NOT HAVE THE OBJECT!
	my $pseudo_dbo = $pseudo->{_DBO} || $vars;
	if (isa($pseudo_dbo, "MalyDBOCore")) # Don't know how the hell else to do it.... ignore.
	{
          my $colin = $pseudo_dbo->col_in($dstkey, @$dstvalue);
          @params = ($colin, @where);
	} else {
	  die("Attempting to do a COL IN without having a DBO");
	}
      } else { # COL = '...'
        @params = ($dstkey, $dstvalue, @where);
      }

      if (not defined $vars->{$key} or 
           (defined $vars->{$key} and 
	     #isa($old_value, "UNIVERSAL") and $old_value->can("get") and  # DBO.
	     (
	       #$old_value->get($dstkey) ne $old_dstkey_value  or # key doesn't match.
	       not @old_params # never run before, no old where.
	       or not struct_eq(\@old_params, \@params)
	     ) 
	   ) 
         ) # Re-run
      {
        my @args = isa($first, "DBOFactory") ? $first->{TABLE_NAME} : ();
        my $dbo = $first->new(@args);
	$dbo->depth($pseudo->{_PSEUDO_DEPTH}-1);
	$pseudo->{"_PSEUDO_${key}_LAST_PARAMS"} = \@params;

        #my $dstvalue = MalyVar->evaluate_content("#$srckey#", $self->hashref);
        # Changed 01/13/2004, doesnt look like need for first.
  $dbo->{DEBUG} = ($key eq 'SUBTASK_IDS');

        if ($dstvalue ne '')
        {
          $vars->{$key} = $dbo->search(@params);
	  # Check depth, to see whether we should call or not.
	  if ($dbo->{_PSEUDO_DEPTH} > 0)
	  {
	    $dbo->load_pseudo();
	  }
        } else {
          $vars->{$key} = undef;
        }
      }
    }
  } elsif ($pseudo_var) { # NOT ARRAY. MALYVAR INTERPOLATE VALUE
    $vars->{$key} = $self->evaluate_content($pseudo_var, $vars, $pseudo);
  }

}

sub get_hash_value
{
  my ($self, $vars, $value, $key, $pseudo, $all) = @_;
  # Handle if $vars is an object.
  my $tempvar = undef;
  my @tempvars = ();

  # $vars might not be an object, but THE INNER THING SURE CAN BE.
  if (ref $vars and isa($vars, "MalyDBOCore")) # Object.
  {
    my $previter = $vars->{ITER}; # Want to reset back after work is done!
    if ($key) # Want to get sub record with given value for ($value) for key ($key)
    {
      if ($value ne '')
      {
        for($vars->first; $vars->more; $vars->next)
	{
	  if ($vars->get($key) eq $value)
	  {
	    $tempvar = $vars->hashref;
	    push @tempvars, $tempvar;
	    last unless $all;
	    #last;
	  }
	}
      }
      #return $tempvars[1];
      return $all ? \@tempvars : $tempvars[0]; #NEW
    } else { # Has DBobject, called via 'DBO{KEY}'. Wants all values of KEY.
      # Basically, return an array ref of all values.

      # CHECK HERE
      my @values = ();
      if ($all)
      {
        #my $n = 0;
        #while (my @c = caller($n))
	#{
	#  print STDERR (" " x $n) . join(",", @c)."\n" if $DEBOOG;
	#  $n++;
	#}
        @values = $vars->get_all($value);
      } else {
        @values = $vars->get($value);
      }

      if (not @values and $vars->{$value} ne '')
      {
        @values = (ref $vars->{$value} eq 'ARRAY') ? @{$vars->{$value}} : ($vars->{$value});
      }

      @tempvars = @values;
      return \@tempvars; #NEW
      ###$tempvar = \@tempvars;
      #$tempvar = $vars->get($value); # THIS IS STILL RAW.
    }
  } else { # Normal hashref (or array we are poking through via a key). 

    if ($key) { # Want to get sub record whose key has certain value.
      my @array = ref $vars eq 'ARRAY' ? @$vars : ();
      my @values = grep { my $v=$self->get_hash_value($_, $key, undef, $pseudo); $v eq $value } @array;
      @tempvars = @values;
      return $all ? \@tempvars : $tempvars[0]; #NEW
      ###$tempvar = $tempvars[0];
    } elsif (ref $vars eq 'HASH') {
      # Handle where vars->{$value} is an array ref. i.e., get first value.
      #print STDERR "HASHASKING FOR $value\n" if $value eq 'TASKS';
      $self->get_pseudo_value($vars, $value, $pseudo); # Will change $vars, if needed.
      @tempvars = $self->get_value_from_hashref($vars, $value);
      return $tempvars[0]; #NEW
      ###$tempvar = $tempvars[0];
    # RE_ENABLED NEXT TWO LINES, TO ALLOW GETTING THE HASHREF OF A DB RECORD WHERE THERE IS ONLY ONE. 01/23/2004
    } elsif (ref $vars eq 'ARRAY' and @$vars == 1 and ref $vars->[0] eq 'HASH') {  # Really want first one, implicit.
      $self->get_pseudo_value($vars->[0], $value, $pseudo); # Will change $vars, if needed.
      @tempvars = $self->get_value_from_hashref($vars->[0], $value);
      return $all ? \@tempvars : $tempvars[0]; #NEW
      ###$tempvar = $tempvars[0];
    } elsif (ref $vars eq 'ARRAY') {
      # When we have an array, DO NOT use pseudo values. it's NOT a DBO!
      @tempvars = $self->get_value_from_hashref({@$vars}, $value);
      return $tempvars[0];

    # REMOVED 03/09/2004, need to use array ref in new above block as hashref....
    # NOT SURE WHAT THIS WAS FOR ANYWAY....
    #} elsif (ref $vars eq 'ARRAY') { # get values for key of each one.
    #  @tempvars =  
    #    map { 
#	  $self->get_pseudo_value($_, $value, $pseudo); 
#	  $self->get_value_from_hashref($_, $value); 
#	} @$vars;
#      return \@tempvars; #NEW
      ###$tempvar = \@tempvars;
    }
  }

  ###return $tempvar;
}

sub eval_concatenate_struct
{
  my ($self, $struct, $as, @content) = @_;

  foreach my $from_content (@content)
  {
    my @values = ();
    if (ref $from_content eq 'ARRAY')
    {
      # need to evaluate each one with this again!
      $struct = $self->eval_concatenate_struct($struct, $as, @$from_content);
    } 
    elsif (ref $from_content eq 'HASH')
    {
      if ($as eq 'ARRAY')
      {
        @values = $from_content;
      } else {
        @values = %$from_content;
      }
      $struct = $self->concatenate_struct($struct, $as, @values);
    }
    elsif (ref $from_content and isa($from_content, "MalyDBOCore"))
    {
      if ($as eq 'ARRAY')
      {
        @values = $from_content->records;
      } elsif ($as eq 'HASH') { # Get just first one!
        @values = $from_content->hash; 
      } # Else, ignore it, as we do above.

      $struct = $self->concatenate_struct($struct, $as, @values);
    }
    elsif (defined $from_content)
    {
      $struct = $self->concatenate_struct($struct, $as, $from_content);
    }
    # Ignore if not defined (i.e., dont add undef to struct!)
  }
  return $struct if defined wantarray;
}

sub concatenate_struct
{
  my ($self, $struct, $as, @content) = @_;
  $as ||= "ARRAY"; # Default.
  if (!ref $struct)
  {
    if ($as eq 'ARRAY')
    {
      $struct = [];
    } elsif ($as eq 'HASH') {
      $struct = {};
    } else { #Scalar ref.
      my $empty = undef;
      $struct = \$empty;
    }
  }
  if ($as eq 'ARRAY')
  {
    $struct = [ (ref $struct eq 'ARRAY' ? @$struct:()), @content ];
  } elsif ($as eq 'HASH') {
    $struct = { (ref $struct eq 'HASH' ? %$struct:()), @content };
  } else { # Scalar ref!
    $struct = $content[0]; # Just first one.
  }
  return $struct if defined wantarray;
}

# REALLY SHOULD BE RETURNING LIST. 

sub get_value_from_hashref # May have mixed case! Force case so get no matter what.
{
  my ($self, $vars, $value) = @_;
  my $v = undef;
  if (not $v = $vars->{$value})
  {
    my %vars = ref $vars eq 'HASH' ? %$vars : ();
    %vars = map { (uc($_), $vars{$_}) } keys %vars;
    $v = $vars{uc $value};
  }
  return $v;
}

sub get_array_value
{
  my ($self, $vars, $value, $key) = @_;
  my $tempvar = undef;
  if ($key ne '')
  {
    # Go through each element (array) and match where $key is $value
    # Doesn't really make sense if object, to have two adjacent dimensions of arrays.
    if (ref $vars and isa($vars, "UNIVERSAL") and $vars->can("first") and $vars->can("next") and $vars->can("more") and $vars->can("at_index"))
    {
      for ($vars->first; $vars->more; $vars->next)
      {
        if ($vars->at_index($key) eq $value)
	{
	  $tempvar = $vars->at_index($key);
	}
      }
    } elsif (ref $vars eq 'ARRAY') {
      my $count = scalar @$vars;
      for (my $i = 0; $i < $count; $i++)
      {
        if ($vars->[$i]->[$key] eq $value)
	{
	  $tempvar = $vars->[$i];
	  last;
	}
      }
    } else { # Nothing.

    }
  } else {
    if (ref $vars and isa($vars, "UNIVERSAL") and $vars->can("at_index"))
    {
      $tempvar = $vars->at_index($value);
    } elsif (ref $vars eq 'ARRAY') {
      $tempvar = $vars->[$value];
    }
  }
  return $tempvar;
}

sub evaluate_content # Separate to make easy to remember
{
  my ($self, $content, $vars, $pseudo, $escape_quotes, $all) = @_;
  # Variable is scalar or array or hash.
  my $found = 0;
  #do
  #{
  #  #$found = $content =~ s/#([\w:-]+?(\[[\w#=-]*?\]|\{[\w#=-]*?\})*)#/$self->flat_var_evaluate($vars, $1, $pseudo)/ge;
  #  $found = $content =~ s/#([\w:-]+?(\[[\w#=-]*?\]|\{[\w#=-]*?\})*)#/$self->flat_var_evaluate($vars, $1, $pseudo)/ge;
  #  print STDERR "FOUND=$found, CON=$content\n";
  #} while($found);

  #while ( $content =~ s/#([\w:-]+?(\[[\w#=-]*?\]|\{[\w#=-]*?\})*)#/$self->flat_var_evaluate($vars, $1, $pseudo)/ge ) {;}
  #$content =~ s/#([\w:-]+?(\[[\w#=-]*?\]|\{[\w#=-]*?\})*)#/$self->flat_var_evaluate($vars, $1, $pseudo)/ge;
  while( $content =~ s/(?<!\\)#([\w:-]+?(\[[\w#=+-]*?\]|\{[\w#=+-]*?\})*)#/$self->flat_var_evaluate($vars, $1, $pseudo, $all)/ge ) {;}
  $content =~ s/\\#/#/g unless ($vars->{_KEEP_ESCAPES});

  if ($escape_quotes)
  {
    #$content =~ s/'/&apos;/g;
    # We autmatically use double quotes, no need to escape
    $content =~ s/"/&quot;/g;
  }

  return $content;
}

sub sprintf
{
  my ($self, @args) = @_;
  $self->evaluate_content(@args);
}

1;

