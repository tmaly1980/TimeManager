# Handles (plain-text, no attachment) emailing using MIME::Lite and MalyTemplate.
package MalyMail;

use MalyTemplate;
use MIME::Lite;
use Data::Dumper;

our $LOGGER = undef;

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
  bless $self, $class;

  if (scalar @params == 1) { $self->{GLOBAL} = $params[0]; }
  else { $self->{GLOBAL} = {@params}; }

  $LOGGER = $self->{GLOBAL}->{LOGGER} || MalyLog->new();

  $self->{TEMPLATE} = MalyTemplate->new($self->{GLOBAL});
  return $self;
}

sub sendmail
{
  my ($self, $lite_args, $template, %tmpl_vars) = @_;
  my $content = $self->{TEMPLATE}->render($template, %tmpl_vars);
  print STDERR "MAILCONTENT=".Dumper($content)."\n";
  $self->sendmail_text($lite_args, $content);
}

sub sendmail_text
{
  my ($self, $lite_args, $content) = @_;

  $LOGGER->internal_error("No recipient email specified.") unless $lite_args->{To};
  $LOGGER->internal_error("No sender email specified.") unless $lite_args->{From};
  my %lite_args = ref $lite_args eq 'HASH' ? %$lite_args : ();
  my $msg = undef;
  eval { $msg=MIME::Lite->new(%lite_args, Data=>$content) } or $LOGGER->log("MalyMail Error: $!");
  $msg->send or $LOGGER->log("MalyMail Error: $!");
}

sub sendmail_multipart # Each part must have syntax like: { Type=>"content/type", Disposition=>"inline/attachment", Data=>"data" }
{
  my ($self, $lite_args, @parts) = @_;

  $LOGGER->internal_error("No recipient email specified.") unless $lite_args->{To};
  $LOGGER->internal_error("No sender email specified.") unless $lite_args->{From};
  my %lite_args = ref $lite_args eq 'HASH' ? %$lite_args : ();
  my $msg = undef;
  eval { $msg=MIME::Lite->new(%lite_args, Type=>"multipart/mixed") } or $LOGGER->log("MalyMail Error: $!");
  foreach my $part (@parts)
  {
    next unless ref $part eq 'HASH';
    eval { $msg->attach(%$part) } or $LOGGER->log("MalyMail Error: $!");
  }
  $msg->send or $LOGGER->log("MalyMail Error: $!");

}

1;
