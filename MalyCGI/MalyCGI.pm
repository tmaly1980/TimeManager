# DONE
package MalyCGI;

#use CGI::Carp 'fatalsToBrowser';
use lib "../etc";
use CGI::Pretty qw/-any/;
use URI::Escape;
use Data::Dumper;
use MalyDate;
use POSIX;
use MalyTemplate;
use MalyLog;

# Variables that are recognized:
# All other options are passed to MalySession, MalyLog, MalyTemplate.
#
# AUTH_SESSION = Function reference for authorization, if undef, authentication disabled (anonymous).
# Also can specify GET/CREATE/DELETE_SESSION.
# PATH_INFO_KEYS: What each component (directory) of the path_info is keyed.
# MANUAL_PROCESS: Do not call process() automatically....

sub new
{
  my ($this, @params) = @_;
  my $class = ref($this) || $this;
  my $self = {};

  if (scalar @params == 1) { $self->{GLOBAL} = $params[0]; }
  else { $self->{GLOBAL} = {@params}; }

  $self->{GLOBAL}->{CGI} = CGI::Pretty->new(); # REQUEST, HTML generation, etc...
  $self->{GLOBAL}->{TEMPLATE} = MalyTemplate->new($self->{GLOBAL});
  $self->{GLOBAL}->{DATE} = MalyDate->new(); # date conversion et al.
  $self = bless $self, $class;

  my $me = $0; # CGI.
  my $cwd = POSIX::getcwd();
  $me = "$cwd/$me" if ($me !~ m{^/});
  my @dirparts = grep {!/^[.]$/} split("/", $me);
  pop @dirparts; pop @dirparts; # Get rid of file and parent (cgi-bin) dir.
  $self->{GLOBAL}->{BASEDIR} = join("/", @dirparts ) || "../";

  $self->{GLOBAL}->{LOGGER} = MalyLog->new($self->{GLOBAL});
  $self->process_uploads();

# THIS JUST WAS MOVED FROM AFTER GET_GLOBAL_VARS....THIS MAY BE WRONG !!!! 01/07/2004
# MAY HAVE A NEED TO MUCK WITH SOMETHING DB RELATED OR SESSION RELATED...

  # I.e., for bootstrapping session function hooks
  $self->init(); # Child class, generic to all CGI's per application.
  $self->subclass_init(); # Grandchild class, per-URL CGI.

  if ($self->{GLOBAL}->{MAIL})
  {
    require MalyMail;
    $self->{MAIL} = MalyMail->new($self->{GLOBAL});
  }

  if ($self->{GLOBAL}->{DBO})
  {
    require MalyDBO;
    MalyDBO->init(@{$self->{GLOBAL}->{DB_PARAMS}});
    MalyDBO->set_globals($self->{GLOBAL});
  }

  if ($self->{GLOBAL}->{DBAUTH})
  {
    require MalyDBAuth;
    my $dbauth = MalyDBAuth->new($self->{GLOBAL});
  }

  # As session can be database-based, we need to load the db stuff first.

  if ($self->{GLOBAL}->{SESS_AUTH})# and $self->{GLOBAL}->{RESTRICTED})
  # Can be optional, make sure not enforced if not RESTRICTED...
  {
    require MalySession;
    $self->{GLOBAL}->{SESSION} = MalySession->new($self->{GLOBAL});
  } elsif ($self->{GLOBAL}->{RESTRICTED} and not $self->{GLOBAL}->{SESS_AUTH}) {
    $self->{GLOBAL}->{LOGGER}->internal_error("Page is restricted, but no access control implemented.");
  }

  $self->get_global_vars();


  $self->process_query_string();
  $self->process_path_info($self->{GLOBAL}->{PATH_INFO_KEYS});


  # If defined to not process automatically, don't call.

  my $a = $self->get("action");
  # Need to not do session processing unless session exists.
  # i.e., field name of username/password isnt set unless 
  # Session object exists.
  if (not $self->{GLOBAL}->{SESSION})
  {
    $self->pre_process();
    $self->multirow_group_handler();
    $self->validate_data();
    $self->process($a);
    return $self;
  }

  ###$self->{GLOBAL}->{SESS_USER} ||= "username";
  ###$self->{GLOBAL}->{SESS_PASS} ||= "passwd";
  my $u = $self->get($self->{GLOBAL}->{SESS_USER});
  my $p = $self->get($self->{GLOBAL}->{SESS_PASS});
  print STDERR "ABOUT TO CALL SESSION_PROCESS $$ (ACTION=$a, USERNAME=$u, PASSWORD=$p)\n" if $self->{GLOBAL}->{SESSION_DEBUG};
  unless ($self->{GLOBAL}->{NO_SESSION} or $self->{GLOBAL}->{SESSION}->session_process($a,$u,$p) 
    or $self->{GLOBAL}->{MANUAL_PROCESS})
  {
    print STDERR "ABOUT TO CALL PROCESS $$ (ACTION=$a)\n" if $self->{GLOBAL}->{SESSION_DEBUG};
    $self->pre_process();
    $self->multirow_group_handler();
    $self->validate_data();
    $self->process($a);
  }

  return $self;
}

sub init {;}
sub subclass_init {;}
sub pre_process {;} # Called immediately before process(), after session check.

sub get_global_vars
{
  my ($self) = @_;

  my %globals = ();

  $globals{URL} = $ENV{SCRIPT_NAME};
  $globals{PATHINFO_URL} = $ENV{SCRIPT_NAME} . $ENV{PATH_INFO};

  $globals{REFERER} = $ENV{HTTP_REFERER};
  my $url = $self->{GLOBAL}->{CGI}->url(-full=>1,-query=>1,-path_info=>1);

  $globals{QUERY_STRING} = $self->{GLOBAL}->{CGI}->query_string();

  $globals{FULL_URL} = $url;

  $globals{SCRIPT_NAME} = $ENV{SCRIPT_NAME};
  $globals{SERVER_URL} = $self->{GLOBAL}->{CGI}->url(-base=>1);
  my $file_url = "$globals{SERVER_URL}$globals{SCRIPT_NAME}";

  $globals{COMPLETE_URL} = $file_url;
  $globals{ABSOLUTE_URL} = $file_url;
  ($globals{COMPLETE_BASE_PATH}) = $file_url =~ m{^(.*)/(.+?)$};
  $globals{ABSOLUTE_BASE_PATH} = $globals{COMPLETE_BASE_PATH};

  $globals{COMPLETE_HTML_BASE_PATH} = $globals{COMPLETE_BASE_PATH};
  $globals{COMPLETE_HTML_BASE_PATH} =~ s/\/cgi-bin$//g;
  $globals{ABSOLUTE_HTML_BASE_PATH} = $globals{COMPLETE_HTML_BASE_PATH};

  my $host_url = $self->{GLOBAL}->{CGI}->url(-absolute=>1);
  ($globals{BASE_PATH}) = $host_url =~ m{^(.*)/(.+?)$};

  $globals{HTML_BASE_PATH} = $globals{BASE_PATH};
  $globals{HTML_BASE_PATH} =~ s/\/cgi-bin$//g;


  # WE MAY be using DOCUMENT_ROOT to figure this out........
  # When is it NOT DOCUMENT_ROOT ? 
  # if the script's parent dir is 
  # NOT ABLE TO FIGURE OUT !!!!!
  #($globals{HTML_LOCAL_PATH}) = $ENV{SCRIPT_FILENAME} =~ m{^(.+)$globals{SCRIPT_NAME}};

  if (($globals{_NAME}) = $ENV{SCRIPT_NAME} =~ /([a-zA-Z0-9_]+)([.](cgi|pl))?$/)
  {
    my $prefix = $`;
    ($globals{_REFERER_NAME}) = $ENV{REFERER} =~ m{$prefix([a-zA-Z0-9_]+)};
  }

  $globals{ACTION} = $self->get("ACTION"); # Form action

  foreach my $key (keys %globals)
  {
    $self->{GLOBAL}->{$key} = $globals{$key};
  }

  return %globals if wantarray;
  return \%globals if defined wantarray;
}

sub application_get_vars { return (); }

sub get_vars 
{
  my ($self,%vars) = @_;

  my %globals = $self->get_global_vars;
  my %application_vars = $self->application_get_vars(%globals);
  my $session_info = $self->{GLOBAL}->{SESSION} ? 
    $self->{GLOBAL}->{SESSION}->session_info : undef;

  my %form = $self->get_smart_hash;

  return
  {
    %application_vars,
    %globals,
    SESSION=>$session_info,
    TIMESTAMP=>$self->{GLOBAL}->{DATE}->unix_timestamp_to_cgi,
    MALYDATE=>$self->{GLOBAL}->{DATE},
    WORDED_TIMESTAMP=>$self->{GLOBAL}->{DATE}->unix_timestamp_to_cgi(undef, $MalyDate::DEFAULT_WORDED_FORMAT),
    PATH_INFO=>$self->{PATH_INFO},
    FORM=>\%form,
    ENV=>\%ENV,
    $self->multirow_vars,
    $self->multipage_vars,
    %vars,
  };
}
sub process { ($p,$f,$l) = caller(); shift->log("Error, process() not overwritten (AM $0, FROM $p, $f, $l).");} # Default to not processing anything.

sub redirect
{
  my ($self, $page, $msg, @headers) = @_;
  
  if ($self->{GLOBAL}->{SESSION} and $self->{GLOBAL}->{SESSION}->{COOKIE})
  {
    print STDERR "SETTING COOKIE (FOR REDIRECT)=$self->{GLOBAL}->{SESSION}->{COOKIE}\n" if ($self->{GLOBAL}->{SESSION_DEBUG});
    my @cookies = ref $self->{GLOBAL}->{SESSION}->{COOKIE} eq 'HASH' ? values %{ $self->{GLOBAL}->{SESSION}->{COOKIE} } : ();
    push @headers, map { ("Set-Cookie", $_) } @cookies;
  }

  my $esc_msg = $msg;
  $esc_msg =~ s/\s+/+/g;
  my $esc_msg = uri_escape($msg);
  $esc_msg = "?error_message=" . $esc_msg if ($esc_msg);
  #$page .= ".pl" if ($page !~ /[.]pl$/ and $page !~ /[.]pl[?]/ and $page !~ /[.]pl\//);
  $page ||= $self->{GLOBAL}->{URL};
  if ($page =~ /^[.\w]/ and $page !~ m{^http[s]?://}) # If relative.
  {
    $page = "$self->{GLOBAL}->{COMPLETE_HTML_BASE_PATH}/$page";
  }
  print STDERR "REDIRECTING TO $page\n" if $self->{GLOBAL}->{SESSION_DEBUG};
  print $self->{GLOBAL}->{CGI}->redirect({-Location=>$page . $esc_msg, @headers});
  exit;
}

sub get_upload_info
{
  my ($self, $key) = @_;
  return undef unless $key;
  return $self->{GLOBAL}->{FILES}->{$key}->{info};
}

sub get_upload_data
{
  my ($self, $key) = @_;
  return undef unless $key;
  return $self->{GLOBAL}->{FILES}->{$key}->{data};
}

sub process_uploads # Handle uploads, from get_upload_data and get_upload_info
{
  my ($self) = @_;
  my @query_keys = $self->{GLOBAL}->{CGI}->param();
  foreach my $key (@query_keys)
  {
    my $fh = $self->{GLOBAL}->{CGI}->upload($key);
    next unless $fh; # Not an upload field.
    my $filename = $self->{GLOBAL}->{CGI}->param($key);
    my $info = $self->{GLOBAL}->{CGI}->uploadInfo($filename);
    local $/;
    my $content = <$fh>;
    $self->{GLOBAL}->{FILES}->{$key} = 
    {
      info=>$info,
      data=>$content
    };
  }
  $self->{REQUEST}->{_UPLOAD} = $self->{GLOBAL}->{FILES};
}

sub process_query_string
{
  my ($self) = @_;
  my @query_keys = $self->{GLOBAL}->{CGI}->param();
  foreach my $query_key (@query_keys)
  {
    my @values = $self->{GLOBAL}->{CGI}->param($query_key);
    $self->{REQUEST}->{uc $query_key} = \@values;
    # Just changed, so can pass keys case insensitively to get_hash et al.
  }
  #$self->{GLOBAL}->{CGI}->delete_all(); 
  # WE DONT USE CGI.PM ANYMORE, NEVER WILL, FOR HTML GENERATION
  # Removes all content from CGI object, i.e. no auto-fill by CGI.pm's HTML form tags
}

sub process_path_info
{
  my ($self, $keys) = @_;
  return unless ref($keys) eq 'ARRAY';
  my @keys = @{$keys};
  @path_info = split("/", $ENV{PATH_INFO}); 
  shift @path_info if ($ENV{PATH_INFO} =~ m{^/}); # Drop first /
  $self->{PATH_INFO} = { map { ($keys[$_], $path_info[$_]) } (0..$#keys) };
}

sub get_path_info
{
  my ($self, @keys) = @_;
  if (wantarray and @keys)
  {
    return map { $self->{PATH_INFO}->{$_} } @keys;
  } elsif (@keys) { # Only makes sense that if wanting multiple, only assigning to list
    return $self->{PATH_INFO}->{$keys[0]};
  } elsif (wantarray) { # Return a list of stuff in order....
    @keys = @{ $self->{GLOBAL}->{PATH_INFO_KEYS} } if ref $self->{GLOBAL}->{PATH_INFO_KEYS};
    @values = map { $self->{PATH_INFO}->{$_} } @keys;
    return @values;
  } else {
    return $self->{PATH_INFO};
  }
}

sub set_path_info
{
  my ($self, $key, $value) = @_;
  $self->{PATH_INFO}->{$key} = $value;
  return $self->{PATH_INFO}->{$key};
}

sub set_path_info_default
{
  my ($self, $key, $value) = @_;
  $self->set_path_info($key, $value) unless $self->get_path_info($key);
}

sub get_path_info_or_default
{
  my ($self, $key, $value) = @_;
  $self->set_path_info_default($key, $value);
  return $self->get_path_info($key);
}

sub get_smart_hash
{
  my ($self, @keys) = @_;
  @keys = keys %{ $self->{REQUEST} } if not @keys;
  my %out = ();
  foreach my $key (@keys)
  {
    next if $key =~ /^_/; # Skip internal keys (Uploads)
    my $value = $self->{REQUEST}->{uc $key};
    $value = $value->[0] if (ref $value eq 'ARRAY' and @$value == 1);
    $out{uc $key} = $value;
  }
  return %out;
}

sub get_smart_hash_with_uploads
{
  my ($self, @keys) = @_;
  @keys = keys %{ $self->{REQUEST} } if not @keys;
  my %out = ();
  foreach my $key (@keys)
  {
    my $value = $self->{REQUEST}->{uc $key};
    $value = $value->[0] if (ref $value eq 'ARRAY' and @$value == 1);
    $out{uc $key} = $value;
  }
  return %out;
}

sub get_upload_hash
{
  my ($self, @keys) = @_;
  my %uploads = ref $self->{REQUEST}->{_UPLOAD} eq 'HASH' ? %{ $self->{REQUEST}->{_UPLOAD} } : ();
  @keys = keys %uploads unless @keys;
  my %files = map { ($_, $self->{REQUEST}->{_UPLOAD}->{$_}) } @keys;
  return %files;
}

sub get_raw_hash
{
  my ($self, @keys) = @_;
  @keys = keys %{ $self->{REQUEST} } if not @keys;
  return map { (uc($_), $self->{REQUEST}->{uc $_}) } @keys;
}

sub get_hash
{
  my ($self, @keys) = @_;
  @keys = keys %{ $self->{REQUEST} } if not @keys;
  map { (uc($_), $self->{REQUEST}->{uc $_}->[0]) } grep { $_ !~ /^_/ } @keys;
}

sub get_hashref # !!! THIS GETS ALL VALUES, WHICH IS AN ARRAY REF !!!!
{
  my ($self) = @_;
  return $self->{REQUEST};
}

sub get_keys
{
  my ($self) = @_;
  return grep { !/^_/ } keys %{ $self->{REQUEST} };
}

sub get
{
  my ($self, @fields) = @_;
  my @values = ();
  my %request_hash = ref $self->{REQUEST} eq 'HASH' ? 
    map { (uc($_), $self->{REQUEST}->{$_}) } keys %{$self->{REQUEST}} : ();

  # How do we avoid returning a (undef) when we want a () ?

  foreach my $field (@fields)
  {
    my $value = $request_hash{uc $field};
    # when only asking for one thing and assigning to array, return undef.

    my @value = ref $value eq 'ARRAY' ? @$value : ($value);
    if (@fields == 1 and wantarray) 
    # just asked for one thing. we can assume if assigning to array, 
    # we want all the values.
    {
      push @values, (grep { defined($_) } @value);
    } elsif (wantarray and @fields > 1) { # Asking for array, saving to list. Get array refs!
      if (@value > 1)
      {
        push @values, \@value;
      } else { # Just one.
        push @values, $value[0];
      }
    } else { # Only get first of each field, since assigning to list.
      push @values, $value[0];
    }
  }
  #$self->log("ASKIGN FOR $fields[0]. WANTARRAY?".wantarray);

  ###return undef unless @values; # REMOVE?
  return @values if wantarray;
  return $values[0]; # Not wanting array, i.e., scalar.
}

sub set # Probably wont really call much.
{
  my ($self, %set_hash) = @_; # Can have multiple fields/values. If field has more than one value, is array ref.
  foreach my $key (keys %set_hash)
  {
    my $value = $set_hash{$key};
    $value = [$value] if (ref $value ne 'ARRAY');
    $self->{REQUEST}->{uc $key} = $value;
  }

}

sub set_default
{
  my ($self, %set_hash) = @_;
  foreach my $key (keys %set_hash)
  {
    my $value = $set_hash{$key};
    $value = [$value] if (not ref $value);
    if ($self->get($key) eq '')
    {
      $self->set($key, $value);
    }
  }
}

sub make_dir
{
  my ($self, $dir) = @_;

  my @dir_parts = split("/", $dir);
  my @dir = ();

  while (push @dir, shift @dir_parts)
  {
    my $subdir = join("/", @dir);
    if (not -e $subdir)
    {
      mkdir(0700, $subdir) or
        $self->{GLOBAL}->{LOGGER}->internal_error("Cannot create dir '$subdir' required for the use of '$dir'");
    } 
    elsif (-e $subdir and not -d $subdir)
    {
      $self->{GLOBAL}->{LOGGER}->internal_error("'$subdir' exists but is not a directory.");
    } 
    elsif (-e $subdir and not -w $subdir)
    {
      $self->{GLOBAL}->{LOGGER}->internal_error("'$subdir' exists but is not writeable.");
    }
  }

}

sub log { shift->{GLOBAL}->{LOGGER}->log(@_); }
sub error { &{shift->{GLOBAL}->{LOGGER}->{USER_ERROR}}->(@_); }
sub internal_error { &{shift->{GLOBAL}->{LOGGER}->{INTERNAL_ERROR}}->(@_); }
sub system_error { &{shift->{GLOBAL}->{LOGGER}->{SYSTEM_ERROR}}->(@_); }
sub user_error { &{shift->{GLOBAL}->{LOGGER}->{USER_ERROR}}->(@_); }
sub msg_page { &{shift->{GLOBAL}->{LOGGER}->{MSG_PAGE}}->(@_); }

sub get_ph # Will remove a field (set NULL) if doesnt have a value. Don't add key unless desired.
{
  my ($self, @keys) = @_;
  map { my $v = $self->get($_); $v = undef unless $v =~ /./; ($_, $v) } @keys;
}

sub get_ph_ref
{
  my @ph = shift->get_ph(@_);
  return \@ph;
}

sub session_account_change 
{ 
  my ($self, @args) = @_;
  if ($self->{GLOBAL}->{SESSION})
  {
    return $self->{GLOBAL}->{SESSION}->account_change(@args);
  } else {
    $self->internal_error("Account cannot be changed. No session backend defined.");
  }
}

sub session_account_create 
{ 
  my ($self, @args) = @_;
  if ($self->{GLOBAL}->{SESSION})
  {
    return $self->{GLOBAL}->{SESSION}->account_create(@args);
  } else {
    $self->internal_error("Account cannot be created. No session backend defined.");
  }
}

sub refresh_session
{
  my ($self) = @_;
  $self->{GLOBAL}->{SESSION} && $self->{GLOBAL}->{SESSION}->refresh_session();
}

sub session_info
{
  my ($self) = @_;
  if($self->{GLOBAL}->{SESSION})
  {
    return $self->{GLOBAL}->{SESSION}->session_info();
  } else {
    return () if wantarray;
    return undef;
  }
}

sub session_get
{
  my ($self, @args) = @_;
  my $value = undef;
  my @values = ();
  if ($self->{GLOBAL}->{SESSION})
  {
    if (wantarray)
    {
      @values = $self->{GLOBAL}->{SESSION}->get(@args);
    } else {
      $value = $self->{GLOBAL}->{SESSION}->get(@args);
    }
  } 
  return wantarray ? @values : $value;
}

sub template_display # Called when we're really ready.
{
  my ($self, $page, @tmpl_args) = @_;
  $self->{VARS} = $self->get_vars();
  my $content = $self->{GLOBAL}->{TEMPLATE}->render($page, %{$self->{VARS}}, @tmpl_args);

  print STDERR "VARS=$self->{VARS}->{DOC_SITE}\n";
  print $self->{GLOBAL}->{TEMPLATE}->content_type;
  print $self->{GLOBAL}->{TEMPLATE}->content_disposition;
  # If just now created a cookie, should set. (NEED TO KNOW ITS NEW!)
  if ($self->{GLOBAL}->{SESSION} and $self->{GLOBAL}->{SESSION}->{COOKIE})
  {
    my @cookies = ref $self->{GLOBAL}->{SESSION}->{COOKIE} eq 'HASH' ? values %{ $self->{GLOBAL}->{SESSION}->{COOKIE} } : ();

    foreach my $cookie (@cookies)
    {
      print STDERR "SETTING COOKIE=$cookie\n" if ($self->{GLOBAL}->{SESSION_DEBUG});
      print "Set-Cookie: $cookie\n";
    }
  }
  print "\n";
  print $content;
  exit;
}

# Does data validation, checks for sanity.
# Uses:
#  ACTION = From form, what the cgi is doing. i.e., Submit button.
#  validate_struct() = returns struct (hashref) with conditions and error messages if true.
#    Passed to new() as VALIDATE=>$foo
#    if not set, no validation. Looks like:
#       [
#         "eval"=>"error message"
#       ],
#    where "eval" can contain perl cond'l code, and anything in the
#    style of #FOO# is interpolated as a form value--$self->get("FOO")
#    *** THE EVALUATED CODE, IF TRUE, WILL TRIGGER THE ERROR MESSAGE ***
#
sub validate_data
{
  my ($self) = @_;

  my $action = $self->get("action");
  my $meta = $self->validate_struct($action);
  #{GLOBAL}->{VALIDATE};
  return unless (ref $meta eq 'ARRAY');

  my @evals = grep { $i++ % 2 == 0 } @$meta;
  my %evals = @$meta;
  foreach my $eval (@evals)
  {
    my $msg = $evals{$eval};
    $eval =~ s/#(\w+)#/$self->get($1)/eg;
    my $rc = eval $eval;
    if ($rc)
    {
      $self->user_error($msg);
    }
  }
}

sub validate_struct {;}

# Behind-the-scenes handle of a list of records, adding, deleting. 
# Also loads from form, if possible.

# NEED TO CHANGE TO USE FIELD_x syntax
sub set_multirow_dbo
{
  my ($self, $dbo, $delcheck, %set) = @_;

  my $action = $self->get("action");

  my @keys = $dbo->key_name;
  my @field_names = map { uc($_) } $dbo->table_columns;

  my @form_keys = map { uc($_) } $self->get_keys;
  my ($max_ix) = reverse sort map { /_(\d+)$/ } @form_keys;

  my @non_key_field_names = grep { $f=$_;not grep { $f eq $_ } @keys } @field_names;

  # Generate mapping of form IX to DBO IX (as can sort for arbitrarily)
  my %form_dbo_ix_map = ();
  for ($dbo->first; $dbo->more; $dbo->next)
  {
    my %key_values = map { (uc($_), $x=$dbo->get($_)) } @keys;
    for (my $i = 0; $i <= $max_ix; $i++)
    {
      my %form_key_values = map { (uc($_), $y=$self->get($_."_$i")) } @keys;
      if (not grep { $key_values{$_} ne $form_key_values{$_} } keys %key_values)
      {
        $form_dbo_ix_map{$i} = $dbo->index;
	if ($self->get(uc "${delcheck}_$i"))
	{
	  $dbo->delete();
	}
      }
    }
  }

  # Now that we have the index map, lets go through the form.

  # Go through each form index.
  # Get the fields corresponding to that index.
  # If there are no non-key values:
  # 	erase if already in db.
  #	skip if not already in db.
  # Else, if there are valid values,
  #	get at correct ix and commit.
  #	or append and commit if new

  print STDERR "MAX_IX=$max_ix\n";

  for (my $i = 0; $i <= $max_ix; $i++)
  {
    my $dbo_ix = $form_dbo_ix_map{$i};
    my @form_fields = grep { /_$i$/ } @form_keys;
    my %non_key_field_hash = map { ($_, $v=$self->get($_."_$i"))  } @non_key_field_names;
    my %key_field_hash = map { ($_, $v=$self->get($_."_$i"))  } @keys;

    next if ($self->get("${delcheck}_$i"));
    next if not grep { /./ } values %non_key_field_hash; # Skip, it's empty.

    print STDERR "I=$i, IX=$dbo_ix\n";
    print STDERR "COMMITING=".Dumper(\%non_key_field_hash, \%key_field_hash, \%set)."\n";


    #if (not grep { /./ } values %non_key_field_hash) # No visible values
    #{
    #  print STDERR "\tNO VISIBLE VALUES\n";
    #  if ($dbo_ix ne '')
    #  {
    #    print STDERR "\tDELETING DBO_IX $dbo_ix\n";
    #    $dbo->at_index($dbo_ix)->delete;
#	next;
#      } else { # Never there in first place. Ignore.
#        print STDERR "\tIGNORING\n";
#        next;
#      }
#    }

    # Else, change/add
    if ($dbo_ix ne '')
    {
      $dbo->at_index($dbo_ix)->commit(%non_key_field_hash, %set);
    } else {
      $dbo->append;
      print STDERR "ABOUT TO COMMET\n";
      $dbo->{DEBUG} = 1;
      $dbo->commit(%non_key_field_hash, %key_field_hash, %set);
      # primary keys are hidden in form (generated before-hand, by the template!
    }
  }

}

# Behind-the-scenes multirow editing.
# Struct determining info set by:
# MULTIROW parameter set in new()
# Looks like:
#{
#  "ITER_VAR_FOR_FIRST_LOOP"=>
#  {
#    INPUTS=>["col1_var","col2_var","col3_var"],
#    META=>["add button value","del button value","del checkbox name"],
#  },
#  "ITER_VAR_FOR_OTHER_LOOP"=>
#  {...},
#}
#
# The data is then set into the form.

sub multirow_group_handler
{
  my ($self) = @_;
  my $meta = $self->{GLOBAL}->{MULTIROW};
  return unless (ref $meta eq 'HASH');

  my @groups = keys %$meta;

  foreach my $key (@groups)
  {
    $self->multirow_group_edit($key);
  }
}

sub multirow_group_edit
{
  my ($self, $key) = @_;
  # Needs $key as thats used to save the size.

  my $action = $self->get("action");
  my $struct = $self->{GLOBAL}->{MULTIROW}->{$key};
  return unless (ref $struct eq 'HASH');
  
  my @input_names = @{$struct->{INPUTS}} if ref $struct->{INPUTS};
  my ($addbutton, $delbutton, $delcheck) = @{$struct->{META}}
    if ref $struct->{META};

  my @input_values = ();

  foreach (@input_names)
  {
    my @value = $self->get($_);
    push @input_values, (@value > 1 ? \@value : $value[0]);
  }

  my @deletes = $self->get($delcheck) if $delcheck;

  my $size = $self->multirow_size($input_values[0]);

  my $add = 0;

  if ($action eq $delbutton and $delbutton)
  {
    for (my $i = 0; $i < @input_values; $i++)
    {
      my @values = @{$input_values[$i]} if ref $input_values[$i];
      my @keep_values = ();
      foreach (my $x = 0; $x < @values; $x++)
      {
        push @keep_values, $values[$x] unless (grep { $x == $_ } @deletes);
      }
      $input_values[$i] = \@keep_values;
    }
    my %hash = map { ($input_names[$_], $input_values[$_]) } (0..$self->multirow_size($input_values[0]));
    $self->set(%hash);
  }
  elsif ($action eq $addbutton and $addbutton)
  {
    $add = 1;
  }

  # Need to get length again.
  $size = $self->multirow_size($input_values[0], $add);
  $self->{MULTIROW_VARS}->{$key} = $size;
}

sub multirow_size
{
  my ($self, $input_value, $add) = @_;
  $size = ref $input_value ? scalar @$input_value + $add : 3 + $add;
  return $size;
}

sub multirow_vars # ITERATORS HASH SET IN CGI TEMPLATE
{
  my ($self) = @_;
  return %{$self->{MULTIROW_VARS}} if ref $self->{MULTIROW_VARS};
  return ();
}

sub get_multipage_params
{
  my ($self) = @_;
  $self->get("LIMIT","OFFSET");
}

sub configure_multipage_dbo
{
  my ($self, $dbo) = @_;
  return undef unless ref $dbo;
  my $limit = $self->get("LIMIT");
  my $offset = $self->get("OFFSET");
  $limit ||= $self->{GLOBAL}->{LIMIT} || 10;
  $offset ||= 0;

  $dbo->enable_multipage($offset,$limit);
  $self->{MULTIPAGE_DBO} = $dbo;
}

sub multipage_vars
{
  my ($self) = @_;
  return () unless ref $self->{MULTIPAGE_DBO};
  my ($limit, $offset) = $self->get("LIMIT","OFFSET");
  $limit ||= $self->{GLOBAL}->{LIMIT} || 10;
  $offset ||= 0;

  my %nav_hash = ();
  # Generate variables to include in page display.
  # For navigation of results.

  my @field = $self->get("FIELD");
  my @regex = $self->get("REGEX");
  my @value = $self->get("VALUE");

  my %args = ();
  %args = (FIELD=>\@field, REGEX=>\@regex, VALUE=>\@value, ACTION=>'Search') if @value;

  my $base_url = $self->{GLOBAL}->{PATHINFO_URL};

  my $multipage_count = $self->{MULTIPAGE_DBO}->multipage_count;

  # NEXT PAGE
  if ($multipage_count > $offset+$limit)
  {
    $nav_hash{NEXTURL} = $self->generate_query_string($base_url, %args,
      OFFSET=>$offset+$limit);
  }

  # PREV PAGE
  if ($offset-$limit >= 0)
  {
    $nav_hash{PREVURL} = $self->generate_query_string($base_url, %args,
      OFFSET=>$offset-$limit);
  }

  # Array of 
  # Current page # (index) ?

  my @pages = ();
  my $x = 1;
  for (my $i = 0; $i < $multipage_count; $i+=$limit)
  {
    my $start = $i+1;
    my $end = $i+$limit < $multipage_count ? $i+$limit : $multipage_count;
    my %page_hash = 
    (
      START=>$start,
      END=>$end,
      NUM=>$i%$limit,
      PAGEURL=>$self->generate_query_string($base_url, %args, OFFSET=>$i),
    );
    $nav_hash{CURRPAGE} = $i / $limit if ($i <= $offset and $offset <= $multipage_count);
    push @pages, \%page_hash;
  }

  $nav_hash{PAGEURLS} = \@pages;
  $nav_hash{PAGECOUNT} = scalar @pages;
  #$nav_hash{PAGENUMS} = undef;

  return %nav_hash;
}

sub generate_query_string
{
  my ($self, $base_url, %hash) = @_;
  my $append = undef;
  my @args = ();
  foreach my $key (keys %hash) 
  {
    my $value = $hash{$key};
    my @values = ref $value ? @$value : ($value);
    push @args, map { "$key=$_" } @values;
  }
  my $qstring = join("&", @args);

  my $url = $base_url . ($qstring ? "?$qstring" : "");
  return $url;
}

sub sendmail # Args suitable for MIME::Lite
{
  my ($self, %hash) = @_;
  require MIME::Lite;

  my $msg = MIME::Lite->new(%hash);
  $msg->send or $self->internal_error("Cannot send mail: $!");
}

sub login
{
  my ($self) = @_;
  my $a = $self->get("action");
  my $u = $self->get($self->{GLOBAL}->{SESS_USER});
  my $p = $self->get($self->{GLOBAL}->{SESS_PASS});
  if (ref $self->{GLOBAL}->{SESSION})
  {
    $self->{GLOBAL}->{SESSION}->session_process($a, $u, $p, 1);
  } else {
    $self->internal_error("Unable to login, no session processing implemented.");
  }
}

sub clear_form
{
  my ($self) = @_;
  $self->{REQUEST} = {};
}



1;
