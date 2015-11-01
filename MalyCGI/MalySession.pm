# DONE
package MalySession;

use Digest::MD5;
use CGI::Pretty;
use URI::Escape;
use Data::Dumper;
use UNIVERSAL qw(isa can);

# Variables that CAN be set:
#
#
# LOGGER = Instance of MalyLog, most likely passed from CGI for use to log to same file. Else, if not passed, it's made.
#
# MODULE = Optional name of application, i.e., file to log to within the logs/ directory below where the CGI is. Defaults to 'error'.
#
# SESS_AUTH = Function reference called when authenticating. No default. Returns true on success, undef on failure.
#
# SESS_POST = Run after session (cookie or user/pass) is verified, i.e., load password from session in case it's needed.
#
# SCOPE = What to authorize against. Anything found at this or an above level is considered equivalent. Defaults to nothing (top-level)
#
# BASE_PATH = Dir (relative to the web server root) that the cookies can span. Not really useful.
#
# SESS_CREATE = Function reference for writing session information to disk, db, etc.... Defaults to disk.
# SESS_DEL = Function reference for removing session info.
# SESS_GET = Function reference for getting an existing session info. Defaults to disk.
# SESS_ACCT_CHANGE = Function reference for changing the stored data for a user account.
# SESS_ACCT_CREATE = Function reference for CREATING an account for a user.
# NO_COOKIE_SET_ON_ACCOUNT_CREATE = Flag to not auto-login once an account is created. defaults to false.
# SESS_LENGTH = Length session lasts (empty string means at end of session)
# SESS_LENGTH_IN_SECS = Length session lasts (in seconds), for use with deletion of old sessions.
#
# RESTRICTED = Whether page is restricted or not. Can be set in application-wide CGI layer, or in specific page CGI for refinement.
#
# POST_LOGIN_PAGE = Page to go to after successful login. If not defined, just returns true. If fails, returns false. Can be overwritten by param to verify_session()
#
# NEXT_SELF = Whether to Redirect to self. Can be overwritten by verify_session()
#
# SESS_USER = hash key returned in hash from SESS_GET, containing username
#
# SESS_PASS = hash key returned in hash from SESS_GET, containing password

# Where cookie is saved determines level.

sub new
{
  my ($this, $globals) = @_; # %vars is most likely $self->{GLOBAL} of cgi calling..
  my $class = ref($this) || $this;
  my $self = {GLOBAL=>$globals};
  bless $self, $class;
  $self->{GLOBAL}->{SESSION_ID_NAME} ||= "MalySession";
  $self->{GLOBAL}->{SESS_CREATE} ||= sub { $self->default_create_session(@_) };
  $self->{GLOBAL}->{SESS_DEL} ||= sub { $self->default_delete_session(@_) };
  $self->{GLOBAL}->{SESS_GET} ||= sub { $self->default_get_existing_session(@_) };
  $self->{GLOBAL}->{SESS_USER} ||= "username";
  $self->{GLOBAL}->{SESS_PASS} ||= "passwd";
  $self->{GLOBAL}->{SESS_LOGIN_PAGE} ||= sub { $self->default_login_page(@_) };
  $self->{GLOBAL}->{SESS_LOGOUT_PAGE} ||= sub { $self->default_logout_page(@_) };
  $self->{GLOBAL}->{LOGIN_URL} ||= $self->{GLOBAL}->{PATHINFO_URL};
  $self->{COOKIE} = {};
  if (not defined $self->{GLOBAL}->{SESS_LENGTH})
  {
    $self->{GLOBAL}->{SESS_LENGTH} = "+1d";
  }
  $self->{GLOBAL}->{LOGGER}->internal_error("Authentication backend not configured. Unable to continue.") unless ($self->{GLOBAL}->{SESS_AUTH});

  return $self;
}

sub session_process # Called by MalyCGI before (and in replacement to) it's process()...
# Only relating to logging IN and logging out...
{
  my ($self, $a, $u, $p, $restricted) = @_;
  print STDERR "IN SESSION_PROCESS (A=$a, U=$u, P=$p, R=$restricted\n" if $self->{GLOBAL}->{SESSION_DEBUG};

  #$self->{GLOBAL}->{LOGGER}->log("A=$a,U=$u,P=$p,R=$self->{GLOBAL}->{RESTRICTED}");

  # Get cookie so we can check that.
  my $cookie = $self->get_verified_cookie();

  print STDERR "COOKIE=$cookie\n" if $self->{GLOBAL}->{SESSION_DEBUG};

  #$self->{GLOBAL}->{LOGGER}->log("COOKIE=$cookie,SESSINFO=".Dumper($self->{SESSION_INFO}));

  if ( ($a eq 'Login' or $self->{GLOBAL}->{RESTRICTED} or $restricted) and not ($u or $p) and not $cookie)
  
  # action=Login in url, or restricted and no user/pass or cookie.
  # need to verify cookie first, and set for check.
  {
    print STDERR "DOING LOGIN PAGE, RESTRICTED=$self->{GLOBAL}->{RESTRICTED}\n" if $self->{GLOBAL}->{SESSION_DEBUG};
    $self->{GLOBAL}->{SESS_LOGIN_PAGE}->();
  }
  elsif ($a eq 'Logout') # Remove session
  {
    #$self->{GLOBAL}->{LOGGER}->log("DELETING SESSION");
    my $cookie = $self->delete_session();
    $self->{GLOBAL}->{SESS_LOGOUT_PAGE}->($cookie);
  }
  elsif ($a eq "Login" and $u and $p) # Actually authenticate session now.
  {
    print STDERR "CALLING VERIFY LOGIN (based upon (LOGIN action)\n" if $self->{GLOBAL}->{SESSION_DEBUG};
    return $self->verify_login($self->{GLOBAL}->{SESS_USER}=>$u,PASSWD=>$p,RESTRICTED=>1,ACTION=>$a);
  }
  elsif (not $cookie)
  {
    print STDERR "CALLING VERIFY LOGIN\n" if $self->{GLOBAL}->{SESSION_DEBUG};
    return $self->verify_login($self->{GLOBAL}->{SESS_USER}=>$u,PASSWD=>$p,RESTRICTED=>$self->{GLOBAL}->{RESTRICTED}||$restricted, ACTION=>$a);
  }
  return 0;
}

sub verify_login # Recognized params: USERNAME, PASSWD, POST_LOGIN_PAGE, NEXT_SELF. Overrides global settings.
{ # If successful authentication, will redirect to specified location (or self or default post-login page) with cookie set.
# If PURPOSELY want to go to self, should pass URL to self. Else, would prefer to go to POST_LOGIN_PAGE
  my ($self, %params) = @_;
  my $username = $params{$self->{GLOBAL}->{SESS_USER}};
  my $passwd = $params{PASSWD};
  my $action = $params{ACTION};

  print STDERR "IN VERIFY LOGIN, CALLING PROCESS_LOGIN\n" if $self->{GLOBAL}->{SESSION_DEBUG};

  $self->process_login($username, $passwd);

  if (not $self->{SESSION_INFO}) # Failed (or no login info at all).
  {
    print STDERR "NOT SESSION_INFO (FAILED)\n" if $self->{GLOBAL}->{SESSION_DEBUG};
    if ($params{RESTRICTED} or ($username and $action eq 'Login')) # If no login_page, return undef. Bothered to give username, so also give up.
    {
      $self->{GLOBAL}->{LOGGER}->{USER_ERROR}->("Unable to login.");
    } # else, Okay to fail, not REQUIRED (anonymous ok with authenticated users!).
  } else { # Logged in successfully, do SESS_GET_POST
    if (ref $self->{GLOBAL}->{SESS_GET_POST} eq 'CODE')
    {
      $self->{GLOBAL}->{SESS_GET_POST}->($username, $passwd);
    }
  }
  print STDERR "CONTINUING AFTER VERIFY_LOGIN (OK)\n" if $self->{GLOBAL}->{SESSION_DEBUG};

  return 0;
  #elsif ($self->{COOKIE}) { # SUCCESS! 

    # Different situations to use sessoins:
    # Want to go to specific page, but restricted.
    # Want to go to login page, and then go to some other page afterwards.
    # Login page cgi SHOULD handle where to go next!!!!

    # Ok to go to process()

    #my $next_page = undef;
    #if ($self->{GLOBAL}->{POST_LOGIN_PAGE})
    #{
    #  $next_page = "$self->{GLOBAL}->{BASE_PATH}/$self->{GLOBAL}->{POST_LOGIN_PAGE}";
    #}
    #elsif ($params{POST_LOGIN_PAGE})
    #{
    #  $next_page = "$self->{GLOBAL}->{BASE_PATH}/$params->{POST_LOGIN_PAGE}";
    #} else { # Remove action=Logout, though
    #  $next_page = $self->{GLOBAL}->{REFERER}; # With query, action=Login
    #  #$next_page = $self->{GLOBAL}->{PATHINFO_URL}; # Redirect to self by default.
    #}
#
#    $self->redirect($next_page, -Cookie=>$self->{COOKIE}); # Should bypass undef below
  #}
}

sub cookie # Store in a hash.
{
  my ($self, %args) = @_;
  my $cookie = $self->{GLOBAL}->{CGI}->cookie(%args);
  if (@_ > 3) # Set as well
  {
    print STDERR "SETTING COOKIE $cookie, CALLER=".join(",", caller())."\n" if $self->{GLOBAL}->{SESSION_DEBUG};
    $self->{COOKIE}->{$args{-name}} = $cookie;
  }
  return $cookie;
}

sub redirect
{
  my ($self, $page, @headers) = @_;
  print $self->{GLOBAL}->{CGI}->redirect({-Location=>$page, @headers});
  exit;
}

sub get_session_id
{
  my ($self) = @_;
  my $cgi_session_id = $self->{GLOBAL}->{CGI}->param($self->{GLOBAL}->{SESSION_ID_NAME}); # CGI or CLI
  my $session_id = $self->cookie(-name=>$self->{GLOBAL}->{SESSION_ID_NAME});
  if (not $session_id and $cgi_session_id)
  {
    $session_id = $cgi_session_id;
    my $cookie_name = $self->{GLOBAL}->{SESSION_ID_NAME};
    $cookie_name .= "/" . $authscope if ($authscope);
    $self->cookie(-name=>$cookie_name,
      -value=>$session_id,
      -path=>$self->{GLOBAL}->{BASE_PATH} || "/",
      -expires=>$self->{GLOBAL}->{SESS_LENGTH}||undef
      );
  }
  return $session_id;
}

sub process_login # Generalized for generic authentication. Uses $self->{GLOBAL}->{SESS_AUTH}->($username, $passwd) to verify.
# Gets session info from configured source.
{
  my ($self, $username, $passwd) = @_;
  # If existing session, return.
  # if no session, check with password
    
  print STDERR "IN PROCESS_LOGIN (USERNAME=$username, PASS=$passwd)\n" if $self->{GLOBAL}->{SESSION_DEBUG};

  my $session_id = $self->get_session_id;

  if ($username and $passwd) # Not logged in, or trying to log in again, check.
  {
    print STDERR "CALLING SESS_AUTH\n" if $self->{GLOBAL}->{SESSION_DEBUG};
    my $new_username = $self->{GLOBAL}->{SESS_AUTH}->($username, $passwd);
    # Should return old username if ok, or new one if ok, or undef if failed to auth.

    $self->{GLOBAL}->{LOGGER}->{USER_ERROR}->("Incorrect username/password.")
      unless ($new_username);
    $self->{GLOBAL}->{SESS_POST}->($username, $passwd) if ($self->{GLOBAL}->{SESS_POST});
    $username = $new_username if ($new_username and $new_username ne $username);
    
    # If match, add to session table (drop all existing session records!)
    # session should consist of username, client IP, session id
    $session_id = $self->create_session_id($username);

    $self->session_create($username, $passwd, $session_id);
  }
  print STDERR "DONE WITH PROCESS_LOGIN\n" if $self->{GLOBAL}->{SESSION_DEBUG};
}

sub session_create
{
  my ($self, $username, $passwd, $session_id) = @_;
  print STDERR "IN SESSION_CREATE (SETTING SESSION_INFO)\n" if $self->{GLOBAL}->{SESSION_DEBUG};
    my $cookie_name = $self->{GLOBAL}->{SESSION_ID_NAME};
    $cookie_name .= "/" . $authscope if ($authscope);
    $self->cookie(-name=>$cookie_name,
      -value=>$session_id,
      -path=>$self->{GLOBAL}->{BASE_PATH} || "/",
      -expires=>$self->{GLOBAL}->{SESS_LENGTH}||undef
      );

    $self->{GLOBAL}->{SESS_CREATE}->($username, $passwd, $session_id);
    $self->{SESSION_INFO} = $self->{GLOBAL}->{SESS_GET}->($session_id);
  print STDERR "SESSION_INFO=".Dumper($self->{SESSION_INFO})."\n" if $self->{GLOBAL}->{SESSION_DEBUG};
}

sub refresh_session
{
  my ($self) = @_;
  my $session_id = $self->get_session_id;
  $self->{SESSION_INFO} = $session_id ? $self->{GLOBAL}->{SESS_GET}->($session_id) : undef;
  $self->delete_session if ($session_id and not $self->{SESSION_INFO}); # Invalid cookie, get rid of.
  return $session_id;
}

sub get_verified_cookie
{
  my ($self) = @_;
  if (my $session_id = $self->refresh_session)
  {
    my $user_field = $self->{GLOBAL}->{SESS_USER};
    my $pass_field = $self->{GLOBAL}->{SESS_PASS};
    my $username = $self->get($user_field);
    my $passwd = $self->get($pass_field);
    $self->{GLOBAL}->{SESS_POST}->($username, $passwd) if ($self->{GLOBAL}->{SESS_POST});
    return $session_id;
  } else {
    return undef;
  }
}

sub default_delete_session
{
  my ($self, $session_id) = @_;
  my $session_path = "/tmp/$self->{GLOBAL}->{SESSION_ID_NAME}/$session_id";
  unlink($session_path) or 
    $self->{GLOBAL}->{LOGGER}->internal_error("Unable to remove session (at $session_path): $!");

}

sub delete_session # Removes session at current scope, NOT ABOVE!
# Call this to get the cookie needed to delete the session (and to delete it internally).
{
  my ($self) = @_;
  my $session_id = $self->cookie(-name=>$self->{GLOBAL}->{SESSION_ID_NAME});
  #$self->{GLOBAL}->{LOGGER}->log("REMOVING COOKIE: SID =$session_id");
  return undef unless $session_id;

  $self->{GLOBAL}->{SESS_DEL}->($session_id);

  # Would need to change accordingly to whatever scope session really is at.
  my $cookie = $self->cookie(-name=>
    $self->{GLOBAL}->{SESSION_ID_NAME},
    -value=>$session_id,-path=>$self->{GLOBAL}->{BASE_PATH},-expires=>"-1y");
  #$self->{GLOBAL}->{LOGGER}->log("COOKIE IS $cookie UPON DELETE");
  $self->{SESSION_INFO} = {};
  return $cookie;
}

# Make MalyCGI to generalize as much of PMCGI as possible? even sessions.
# and database and vars and tied variables (session,database,vars,request,?)
# declare variables and db and so on in malycgi. set info regarding
# db access, tied varialbes (hashes of names to queries/updates), vars
# etc... in pmcgi's vars, $self->{GLOBAL} used by malycgi with predefined keys

sub default_create_session
{
  my ($self, $username, $passwd, $session_id) = @_;
  # Create
  my $session_dir = "/tmp/$self->{GLOBAL}->{SESSION_ID_NAME}";
  #$self->{GLOBAL}->{LOGGER}->log("U=$username, P=$passwd, RH=$remote_host, SID=$session_id, AS=$authscope, DIR=$session_dir\n");
  if (!-d $session_dir)
  {
    my @dir_parts = split "/", $session_dir;
    my @dir = ();
    while (@dir_parts)
    {
      push @dir, shift @dir_parts;
      my $dir_name = join("/", @dir);
      $dir_name = "/" unless $dir_name;
      if (!-d $dir_name)
      {
        mkdir($dir_name, 0700) or 
	  $self->{GLOBAL}->{LOGGER}->internal_error("Cannot authenticate, unable to create session directory ($dir_name) for $session_dir");
      }
    }
  } elsif (! -w $session_dir) {
    $self->{GLOBAL}->{LOGGER}->internal_error("Unable to write to $session_dir for session tracking.");
  }
  my $rc = open (SFH, ">" . $session_dir . "/$session_id");
  return undef unless $rc;
  print SFH "$self->{GLOBAL}->{SESS_USER}	$username\n";
  print SFH "$self->{GLOBAL}->{SESS_PASS}	$passwd\n";
  print SFH "session_id	$session_id\n";
  close SFH;

}

sub session_info # Returns a hash ref, whether internally so or an object. Object must implement hashref()
{
  my ($self) = @_;
  if ($self->{SESSION_INFO} and ref $self->{SESSION_INFO} ne 'HASH')
  {
    return $self->{SESSION_INFO}->hash if wantarray;
    return $self->{SESSION_INFO}->hashref;
  } else {
    if (wantarray)
    {
      return %{$self->{SESSION_INFO}} if ref $self->{SESSION_INFO} eq 'HASH';
      return ();
    } else {
    return $self->{SESSION_INFO};
    } 
  }
}

sub create_session_id
{
  my ($self, $username) = @_;
  my $timestamp = time();
  my $plain_session_id = 
    "USERNAME:$username;TIMESTAMP:$timestamp;ID=$$";
  my $ctx = Digest::MD5->new();
  $ctx->add($plain_session_id);
  $session_id = $ctx->hexdigest;
}

sub account_create
{
  my ($self, %session_info) = @_;
  %session_info = map { (uc($_), $session_info{$_}) } keys %session_info;
  my $username = $session_info{ uc $self->{GLOBAL}->{SESS_USER} };
  my $session_id = $self->create_session_id($username);

  $self->{GLOBAL}->{LOGGER}->internal_error("No account create implemented.") if not $self->{GLOBAL}->{SESS_ACCT_CREATE};
  $self->{GLOBAL}->{SESS_ACCT_CREATE}->($session_id, %session_info);
  my $account = $self->{GLOBAL}->{SESS_GET}->($session_id);
  my $passwd = $account->{ uc $self->{GLOBAL}->{SESS_PASS} };
  # Now, set cookie and what not.
  # We want to optionally set cookie and update session_id in db.
  unless ($self->{GLOBAL}->{NO_COOKIE_SET_ON_ACCOUNT_CREATE})
  {
    # Set cookie and set session_id in db.
    $self->session_create($username, $password, $session_id);
  #} else { # No matter what, link browser with account (i.e., session), but don't tell client yet.
  #$self->{GLOBAL}->{SESS_CREATE}->($username, $passwd, $session_id);
  #  $self->{SESSION_INFO} = $self->{GLOBAL}->{SESS_GET}->($session_id);
  }

  # Return session information
  return $self->session_info(); # Should be blank if no cookie set!

  # We ALWAYS want to return session hash.
}

sub account_change
{
  my ($self, %session_info) = @_;
  %session_info = map { (uc($_), $session_info{$_}) } keys %session_info;
  my $username = $session_info{ uc $self->{GLOBAL}->{SESS_USER} };
  my $session_id = $self->get_session_id;

  if ($session_id eq '') # Prompt with login page.
  {
    $self->{GLOBAL}->{SESS_LOGIN_PAGE}->();
  }
  
  $self->{GLOBAL}->{LOGGER}->internal_error("No account change implemented.") if not $self->{GLOBAL}->{SESS_ACCT_CHANGE};
  $self->{GLOBAL}->{SESS_ACCT_CHANGE}->($session_id, %session_info);
  #my $username = $self->{GLOBAL}->{SESS_GET}->($session_id);
  #my $passwd = $account->{ uc $self->{GLOBAL}->{SESS_PASS} };
  # Now, set cookie and what not.
  #$self->{GLOBAL}->{SESS_CREATE}->($username, $passwd, $session_id);

  # Now make SESSION_INFO up to date.
  $self->{GLOBAL}->{SESS_CREATE}->($username, $passwd, $session_id);
  $self->{SESSION_INFO} = $self->{GLOBAL}->{SESS_GET}->($session_id);
  # ADDED 03/03/2004, to let session up date itself immediately, and not next web page.

  $self->session_info();

  # Return session hash
}

sub set # WILL CREATE SESSION RECORD IF NOT THERE !!!!
{
  my ($self) = @_;
  # MAYBE JUST LINK TO ABOVE!???
  # CREATE SESSION_ID IF NOT SET!

}

# Session needs to keep object and recursive objects,
# OR 
# needs, on hash_ref, to split and make array refs, in which BELOW will map back to arrays if wanted.

sub get # Variable from SESSION_INFO.
{
# SHOULDWORK WITH MIXED CASE !!!
  my ($self, @vars) = @_;
  return () if (wantarray and not $self->{SESSION_INFO});
  return undef if not $self->{SESSION_INFO};
  my @values = ();
  # We are asking for an array, where it's really a DBO object. call records() !

  if (isa($self->{SESSION_INFO}, "MalyDBOCore")) # Object. Must implement get()
  {
    if (@vars == 1 and wantarray)
    {
      @values = $self->{SESSION_INFO}->get(@vars); # We want to pass through so we call records() if needed.
    } elsif (defined wantarray) { # Asking for scalar. (NOT going to call records()!)
      $values[0] = $self->{SESSION_INFO}->get(@vars);
    }
  } else {
    if (@vars == 1 and wantarray) # ALso try here to get implicit records()
    {
      my $value = MalyVar->var_evaluate($self->{SESSION_INFO}, $vars[0]);
      #my $value = $self->{SESSION_INFO}->{uc $vars[0]};
      @values = isa($value, "MalyDBOCore") ? $value->records() : $value;
    } else {
      @values = map { MalyVar->var_evaluate($self->{SESSION_INFO}, $_) } @vars;
      #@values = map { $self->{SESSION_INFO}->{uc $_} } @vars;
    }
  }
  return () if (wantarray and @vars == 1 and not grep { $_ ne '' } @values);
  return @{$values[0]} if (wantarray and ref $values[0] eq 'ARRAY' and @vars == 1);
  return @values if wantarray;
  return $values[0]; # Assigned to scalar... LOOKS SILLY
}

sub default_get_existing_session
{
  my ($self, $session_id) = @_;
  return undef unless $session_id;


  my $temp_dir = "/tmp/$self->{GLOBAL}->{SESSION_ID_NAME}";
  foreach my $file (glob ($temp_dir . "/*") )
  {
    unlink($file) if (-f $file and -C $file > 3); # After 3 days
  }

  if (-e "$temp_dir/$session_id" and open (SFH, $temp_dir . "/$session_id") )
  {
    my $session_ref = {};
    while (<SFH>)
    {
      my ($key, $value) = split /\t+/;
      chomp($value);
      $session_ref->{$key} = $value;
    }
    my ($u, $p) = map { $session_ref->{$_} } qw/$self->{GLOBAL}->{SESS_USER} $self->{GLOBAL}->{SESS_PASS}/;
    close(SFH);
    return $session_ref;
  }
  return undef;
}

sub default_login_page
{
  my ($self, $cookie) = @_;
  my $header = $self->{GLOBAL}->{CGI}->header(-cookie=>$cookie);
  my $style = "";
  if ($self->{GLOBAL}->{STYLE})
  {
    my $style_path = $self->{GLOBAL}->{STYLE};
    $style_path = "$self->{GLOBAL}->{COMPLETE_HTML_BASE_PATH}/$style_path" unless $style_path =~ m{^/};
    $style = "<link type=text/css rel=stylesheet href='$style_path' />";
  }
  #<input type=hidden name=next_page value="$self->{GLOBAL}->{REFERER}">
  # TOOK OUT, BAD, WITH action=Logout in!

  # Generate other params (in case query string passed)
  my @params = $self->{GLOBAL}->{CGI}->param();
  my @other_params = ();
  foreach my $param (@params)
  {
    next if $param eq 'Action';
    my $value = $self->{GLOBAL}->{CGI}->param($param);
    push @other_params, "<input type=hidden name=$param value='$value'>";
  }
  my $other_params = join("\n", @other_params);

  print <<"EOF";
$header

<html>
<head>
  <title>$self->{GLOBAL}->{TITLE} Login</title>
  <base href="$self->{GLOBAL}->{COMPLETE_HTML_BASE_PATH}/"/>
  $style
</head>
<body>
  <form method="POST" action="$self->{GLOBAL}->{PATHINFO_URL}">
  $other_params
  <table align=center cellpadding=5 cellspacing=0 border=0>
    <tr>
      <th colspan="3" class="header">
        $self->{GLOBAL}->{TITLE} Login
      </th>
    </tr>
    <tr>
      <td align="right" class="input">
        Username:
      </td>
      <td align="left" class="input">
        <input type="text" name="$self->{GLOBAL}->{SESS_USER}"  size="20" />
      </td>
      <td class="input">
        &nbsp;
      </td>
    </tr>
    <tr>
      <td align="right" class="input">
        Password:
      </td>
      <td align="left" class="input">
        <input type="password" name="$self->{GLOBAL}->{SESS_PASS}"  size="20" />
      </td>
      <td class="input">
        &nbsp;
      </td>
    </tr>
    <tr>
      <td align="center" colspan="3" class="input">
        <input type="submit" name="action" value="Login" />
      </td>
    </tr>
  </table>
  </form>

</body>
</html>
EOF
  exit;

}

sub default_logout_page
{
  my ($self, $cookie) = @_;
  my $header = $self->{GLOBAL}->{CGI}->header(-cookie=>$cookie);
  $self->{GLOBAL}->{SESS_LOGIN_PAGE}->($cookie) if ($self->{GLOBAL}->{LOGOUT_TO_LOGIN});
  if ($self->{GLOBAL}->{STYLE})
  {
    my $style_path = $self->{GLOBAL}->{STYLE};
    $style_path = "$self->{GLOBAL}->{COMPLETE_HTML_BASE_PATH}/$style_path" unless $style_path =~ m{^/};
    $style = "<link type=text/css rel=stylesheet href='$style_path' />";
  }

  my $referer_path = $self->{GLOBAL}->{REFERER};
  $referer_path = "$self->{GLOBAL}->{COMPLETE_HTML_BASE_PATH}/$referer_path" unless $referer_path =~ m{^/|http};
  my $referer = "
    <tr>
      <td class='input'><a href='$referer_path'>Click here</a> to go back.</td>
    </tr>
  " if ($self->{GLOBAL}->{SESSION_DISPLAY_REFERER});

  my $home_path = $self->{GLOBAL}->{HOME_PAGE};
  $home_path = "$self->{GLOBAL}->{COMPLETE_HTML_BASE_PATH}/$home_path" unless $home_path =~ m{^/|http};

  my $home_page = $self->{GLOBAL}->{HOME_PAGE} || $self->{GLOBAL}->{PATHINFO_URL};

  my $home = "
    <tr>
      <td class='input'><a href='$home_path'>Click here</a> to go Home.</td>
    </tr>
  " if ($self->{GLOBAL}->{SESSION_DISPLAY_HOME});


  print <<"EOF";
$header

<html>
<head>
  <title>$self->{GLOBAL}->{TITLE} Logout</title>
  <base href="$self->{GLOBAL}->{COMPLETE_HTML_BASE_PATH}/"/>
  $style
</head>
<body>
  <table cellspacing=0 cellpadding=5 border=0 align=center>
    <tr>
      <th class="header">$self->{GLOBAL}->{TITLE} Logout</th>
    </tr>
    <tr>
      <td class="input">You have successfully logged out.</td>
    </tr>
    <tr>
      <td class="input"><a href="$home_page?action=Login">Click here</a> to log in again.</td>
    </tr>
    $referer
    $home
  </table>
  </form>
</body>
</html>

EOF
  exit;

}

1;
