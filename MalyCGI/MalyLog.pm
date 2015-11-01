# DONE
# CHECKED
package MalyLog;

use base "DB";
use Digest::MD5;
use Data::Dumper;
##use POSIX;

my %fh = ();
our $COMMAND_LINE_MODE = !$ENV{HTTP_HOST}; # IMPLEMENT !!!!
$Data::Dumper::Maxdepth = 3;

# Can be passed:
#
# MODULE = file prefix of filename to write to. Defaults to "error".
# LOGDIR = Dir where log files should be put. defaults to $0/../logs (i.e., for bin/foo or cgi-bin/foo)
# PREFIX = Text (non-interprative) to print on each line.
# STDERR = Set all logging to STDERR instead of a file. Useful for debugging runtime/compile errors.
# TITLE = Title of application, whats printed out in the error pages.
# STYLE = Path (relative to / of the URL) where the given style sheet is.
#	REALLY DOESNT MATTER...

sub new
{
  my ($this, @vars) = @_;
  my $class = ref($this) || $this;
  my $self = {};
  $self->{GLOBAL} = (@vars == 1 ? $vars[0] : {@vars});
  $self->{MODULE} = $self->{GLOBAL}->{MODULE} || "error";
  $self->{DEBUGSTACK} = {};
  bless $self, $class;


  ##my $me = $0; # CGI.
  ##my $cwd = POSIX::getcwd();
  ##$me = "$cwd/$me" if ($me !~ m{^/});
  ##my @dirparts = grep {!/^[.]$/} split("/", $me);
  ##pop @dirparts; pop @dirparts; # Get rid of file and parent (cgi-bin) dir.
  #@dirparts = (".") unless scalar @dirparts;
  ##my $BASEDIR = join("/", @dirparts ) || "../";

  ##$self->{GLOBAL}->{LOGDIR} ||= "$BASEDIR/logs";
  $self->{LOGDIR} = $self->{GLOBAL}->{LOGDIR} || "../logs";

  $self->{NAME} = $self->{GLOBAL}->{NAME} || $self->{MODULE};
  $self->{REQUEST} = {};

  if ($self->{GLOBAL}->{STDERR})
  {
    $fh{$self->{MODULE}} = \*STDERR;
  } else { # Try file.
    unless (open($fh{$self->{MODULE}}, ">>$self->{LOGDIR}/$self->{MODULE}.log"))
    {
      $fh{$self->{MODULE}} = \*STDERR;
    }

    # Enable autoflush.
    select ($fh{$self->{MODULE}});
    $| = 1;
    select STDOUT;
  }

  $self->{URL} = $ENV{SCRIPT_NAME};
  $self->{REFERER} = $ENV{HTTP_REFERER};
  ($self->{BASE_PATH}) = $self->{URL} =~ m{^(.*)/(.+?)$};
  $self->{INTERNAL_ERROR} ||= sub { $self->internal_error(@_) };
  $self->{SYSTEM_ERROR} ||= sub { $self->system_error(@_) };
  $self->{USER_ERROR} ||= sub { $self->user_error(@_) };
  $self->{MSG_PAGE} ||= sub { $self->msg_page(@_) };

  # Set SIGUP.
  # DOESNT WORK!!!
  #$SIG{USR1} = sub { $self->internal_error("Application terminated.") };
  open(STDERR, ">>/tmp/error_log"); # Redirect error log, apache has problems with buffering. BASTARD.

  return $self;
}

sub log # May want to customize which file to print to....
{
  my ($self, $msg) = @_;
  my $prefix = $self->{GLOBAL}->{PREFIX} . ": " if $self->{GLOBAL}->{PREFIX};
  print {$fh{$self->{MODULE}}} "$prefix$msg\n";
}

sub internal_error
{
  my ($self, $msg, $page) = @_;

  $self->internal_error_command_line($msg, $page) if $COMMAND_LINE_MODE;
  $self->internal_error_cgi($msg, $page);
}

sub internal_error_command_line
{
  my ($self, $msg, $page) = @_;
  $self->log_debug_stack();
  $self->log("INTERNAL ERROR: $msg");
  exit;
}

sub internal_error_cgi
{
  my ($self, $msg, $page) = @_;
  my ($package, $file, $line) = caller();
  my @backtrace = $self->backtrace;
  $self->log_debug_stack();
  $self->log("INTERNAL ERROR: $msg");
  $self->log("STACK TRACE:");
  map { $self->log($_) } $self->backtrace;

  #exit unless $self->{URL};
  my @cookies = $self->{GLOBAL}->{SESSION} and ref $self->{GLOBAL}->{SESSION}->{COOKIE} eq 'HASH' ? values %{ $self->{GLOBAL}->{SESSION}->{COOKIE} } : ();
  my $cookies = join("\n", map { "Set-Cookie: $_\n" } @cookies);

  my $ME = $self->{GLOBAL}->{TITLE} || "The application";
  $msg ||= "Unknown error";
  $page ||= "Javascript:history.go(-1)";
  my $style = undef;
  if ($self->{GLOBAL}->{STYLE})
  {
    my $style_path = $self->{GLOBAL}->{STYLE};
    $style_path = "$self->{GLOBAL}->{COMPLETE_HTML_BASE_PATH}/$style_path" unless $style_path =~ m{^/};
    $style = "<link type=text/css rel=stylesheet href='$style_path' />";
  }

  if (not $self->{GLOBAL}->{NO_CONTENT_TYPE})
  {
    print <<"EOF";
Content-type: text/html
$cookies

EOF
  }

  print << "EOF";
<html>
<head>
  <title>Internal Error</title>
  $style
</head>
<body>
  <table cellspacing=0 cellpadding=5 border=0 align=center>
    <tr>
      <th colspan=3 class="border">
        $ME has recieved an internal error and cannot fulfill your request:
      </th>
    </tr>
    <tr>
      <td class="border">&nbsp;</td>
      <td><i>$msg</i></td>
      <td class="border">&nbsp;</td>
    </tr>
    <tr>
      <td class="border">&nbsp;</td>
      <td> Please contact your local Administrator. </td>
      <td class="border">&nbsp;</td>
    </tr>
    <tr>
      <td class="border" colspan=3>
        <a href="$page">Click here to continue</a>
      </td>
    </tr>
  </table>
</body>
</html>
EOF

  exit;

}

sub system_error_cgi
{
  my ($self, $msg, $page) = @_;

  #exit unless $self->{URL};
  my @cookies = $self->{GLOBAL}->{SESSION} and ref $self->{GLOBAL}->{SESSION}->{COOKIE} eq 'HASH' ? values %{ $self->{GLOBAL}->{SESSION}->{COOKIE} } : ();
  my $cookies = join("\n", map { "Set-Cookie: $_\n" } @cookies);

  my $ME = $self->{GLOBAL}->{TITLE} || "The application";
  $msg ||= "Unknown error";
  $page ||= "Javascript:history.go(-1)";
  my $style = undef;
  if ($self->{GLOBAL}->{STYLE})
  {
    my $style_path = $self->{GLOBAL}->{STYLE};
    $style_path = "$self->{GLOBAL}->{COMPLETE_HTML_BASE_PATH}/$style_path" unless $style_path =~ m{^/};
    $style = "<link type=text/css rel=stylesheet href='$style_path' />";
  }

  if (not $self->{GLOBAL}->{NO_CONTENT_TYPE})
  {
    print <<"EOF";
Content-type: text/html
$cookies

EOF
  }

  print << "EOF";
<html>
<head>
  <title>System Error</title>
  $style
</head>
<body>
  <table cellspacing=0 cellpadding=5 border=0 align=center>
    <tr>
      <th colspan=3 class="border">
        $ME has recieved a system error and cannot fulfill your request:
      </th>
    </tr>
    <tr>
      <td class="border">&nbsp;</td>
      <td><i>$msg</i></td>
      <td class="border">&nbsp;</td>
    </tr>
    <tr>
      <td class="border">&nbsp;</td>
      <td> Please contact your local Administrator. </td>
      <td class="border">&nbsp;</td>
    </tr>
    <tr>
      <td class="border" colspan=3>
        <a href="$page">Click here to continue</a>
      </td>
    </tr>
  </table>
</body>
</html>
EOF

  exit;

}

sub system_error
{
  my ($self, $msg, $page) = @_;

  $self->system_error_command_line($msg, $page) if $COMMAND_LINE_MODE;
  $self->system_error_cgi($msg, $page);
}

sub system_error_command_line
{
  my ($self, $msg, $page) = @_;
  $self->log("SYSTEM ERROR: $msg");
  exit;
}

sub user_error
{
  my ($self, $msg, $page) = @_;

  $self->user_error_command_line($msg, $page) if $COMMAND_LINE_MODE;
  $self->user_error_cgi($msg, $page);
}

sub user_error_command_line
{
  my ($self, $msg, $page) = @_;
  $self->log("$msg");
  exit;
}

sub user_error_cgi
{
  my ($self, $msg, $page) = @_;
  $self->log($msg);

  #exit unless $self->{URL};

  $page ||= "Javascript:history.go(-1)";
  my $style = undef;
  my @cookies = ($self->{GLOBAL}->{SESSION} and ref $self->{GLOBAL}->{SESSION}->{COOKIE} eq 'HASH') ? values %{ $self->{GLOBAL}->{SESSION}->{COOKIE} } : ();
  my $cookies = join("\n", map { "Set-Cookie: $_\n" } @cookies) ; 
  if ($self->{GLOBAL}->{STYLE})
  {
    my $style_path = $self->{GLOBAL}->{STYLE};
    $style_path = "$self->{GLOBAL}->{COMPLETE_HTML_BASE_PATH}/$style_path" unless $style_path =~ m{^/};
    $style = "<link type=text/css rel=stylesheet href='$style_path' />";
  }
  my $title = $self->{GLOBAL}->{TITLE};

  if (not $self->{GLOBAL}->{NO_CONTENT_TYPE})
  {
    print <<"EOF";
Content-type: text/html
$cookies

EOF
  }

  print <<"EOF";
<html>
<head>
  <title>$title Error</title>
  $style
</head>
<body>
  <table cellspacing=0 cellpadding=5 border=0 align=center>
    <tr>
      <th colspan=3 class="border">
        User Error
      </th>
    </tr>
    <tr>
      <td class="border">&nbsp;</td>
      <td><i>$msg</i></td>
      <td class="border">&nbsp;</td>
    </tr>
    <tr>
      <td class="border" colspan=3>
        <a href="$page">Click here to continue</a>
      </td>
    </tr>
  </table>
</body>
</html>
EOF

  exit;

}

sub msg_page
{
  my ($self, $msg, $page) = @_;

  $self->msg_page_command_line($msg, $page) if $COMMAND_LINE_MODE;
  $self->msg_page_cgi($msg, $page);
}

sub msg_page_command_line
{
  my ($self, $msg, $page) = @_;
  $self->log("$msg");
  exit;
}

sub msg_page_cgi
{
  my ($self, $msg, $page) = @_;
  $self->log($msg);

  #exit unless $self->{URL};

  $page ||= "Javascript:history.go(-1)";
  my $style = undef;
  my @cookies = ($self->{GLOBAL}->{SESSION} and ref $self->{GLOBAL}->{SESSION}->{COOKIE} eq 'HASH') ? values %{ $self->{GLOBAL}->{SESSION}->{COOKIE} } : ();
  my $cookies = join("\n", map { "Set-Cookie: $_\n" } @cookies) ; 
  if ($self->{GLOBAL}->{STYLE})
  {
    my $style_path = $self->{GLOBAL}->{STYLE};
    $style_path = "$self->{GLOBAL}->{COMPLETE_HTML_BASE_PATH}/$style_path" unless $style_path =~ m{^/};
    $style = "<link type=text/css rel=stylesheet href='$style_path' />";
  }
  my $title = $self->{GLOBAL}->{TITLE};

  if (not $self->{GLOBAL}->{NO_CONTENT_TYPE})
  {
    print <<"EOF";
Content-type: text/html
$cookies

EOF
  }

  print <<"EOF";
<html>
<head>
  <title>$title</title>
  $style
</head>
<body>
  <table cellspacing=0 cellpadding=5 border=0 align=center>
    <tr>
      <td class="border">&nbsp;</td>
      <td><i>$msg</i></td>
      <td class="border">&nbsp;</td>
    </tr>
    <tr>
      <td class="border" colspan=3>
        <a href="$page">Click here to continue</a>
      </td>
    </tr>
  </table>
</body>
</html>
EOF

  exit;

}

# we want to keep stuff even if span multiple packages.....
# so we save like:
# main calling debug(...) : $self->{DEBUGSTACK}->{MESSAGES}->[0]
# main then doit calling debug(...) : $self->{DEBUGSTACK}->{STACK}->{main:doit:5}->{MESSAGES}->[which message]

# Need to prepend package name to function name, as well as append line number!!! that will make it unique!

sub debug # Puts text into debug stack.
{
  my ($self, $message) = @_;
  my @fstack = $self->get_function_stack(1);
  # BORKLEN!
  my $function = pop @fstack;
  my $parent = $self->get_debug_struct($self->{DEBUGSTACK}, @fstack);
  if ($function)
  {
    $$parent->{STACK}->{$function}->{MESSAGES} = [ ref $$parent->{STACK}->{$function}->{MESSAGES} eq 'ARRAY' ? 
      @{ $$parent->{STACK}->{$function}->{MESSAGES} } : (), $message ];
  } else { # Main itself.
    $$parent->{MESSAGES} = [ ref $$parent->{MESSAGES} eq 'ARRAY' ? 
      @{ $$parent->{MESSAGES} } : (), $message ];
  }
  return $message if defined wantarray;
}

sub get_debug_struct # We use this purely for output. if any portion of the struct doesnt exist, return undef.
{
  my ($self, $root, @fstack) = @_;
  my $struct = \($root);
  for (my $i = 0; $i < @fstack; $i++)
  {
    my $function = $fstack[$i];
    $struct = \($$struct->{STACK}->{$function});
  }
  return $struct;
}

sub get_function_stack # Up to and includes current function.
{
  my ($self, $offset) = @_;
  my @function_stack = ();
# We want to make sure that we get the initial set, if called from
  for (my $i = 1+$offset; (my ($pack, $file, $line, $function) = caller($i)); $i++)
  {
    unshift @function_stack, "$function/$pack/$line";
  }
  return @function_stack;
}

sub get_debug
{
  my ($self) = @_;
  my @fstack = $self->get_function_stack(1);

  my @messages = ();
  my $i = -1;
  my $struct = $self->{DEBUGSTACK};
  do
  {
    my $fmess = $struct->{MESSAGES};
    my $ftitle = $i >= 0 ? $fstack[$i] : "main";
    my @fmess = ref $fmess eq 'ARRAY' ? @$fmess : ();
    my $fmess_merged = join("\n", map { "   $_" } @fmess);
    push @messages, "$ftitle:" . ($fmess_merged ? "\n$fmess_merged" : "");
  } while (@fstack > $i++ and $struct = $struct->{STACK}->{$fstack[$i]});
  return @messages if wantarray;
  return join("\n", @messages) if defined wantarray;
}

sub log_debug_stack
{
  my ($self) = @_;
  my $debug_stack = $self->get_debug;
  $self->log($debug_stack);
}

1;
