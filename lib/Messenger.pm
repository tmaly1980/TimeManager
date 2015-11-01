package Messenger;

use lib "../../MalyCGI";
use MalyTemplate;
use MIME::Lite;
use User;

# Takes care of periodic notifications (i.e. ,reminders) as well as triggered events (i.e., task assignment)

sub new
{
  my ($class, $globals) = @_;
  my $self = {
    GLOBAL=>{ %$globals, TEMPLATE_DIR=>"../notify"},
    TEMPLATE=>MalyTemplate->new($globals),
  };
  bless $self, $class;
}

sub notify
{
  my ($self, $uid, $subject, $template, %hash) = @_;
  return unless ($uid ne ''); # May not really be applicable if not there.
  my $user = User->search(UID=>$uid);
  my $content = $self->{TEMPLATE}->render($template, %hash, USER=>$user->hashref, GLOBAL=>$self->{GLOBAL});
  my $from = $self->{GLOBAL}->{META}->{MESSAGE_FROM} || 'ProjectManager <tomas_maly@financialcircuit.com>';
  $self->{GLOBAL}->{LOGGER}->log("No email set for user '$user{USERNAME}'.") if not $user->get("EMAIL");
  $subject ||= "TimeManager Update";
  my $to = $user->get("FULLNAME") . " <" . $user->get("EMAIL") . ">";
  $self->send_mail($from, $to, "ProjectManager: " . $subject, $content);
}

sub send_mail # '$to' can be a array ref
{
  my ($self, $from, $to, $subject, $content) = @_;
  my @to = ($to);
  @to = @{$to} if (ref $to);
  if (not @to)
  {
    $self->{GLOBAL}->{LOGGER}->log("No email set. Not sending.");
    return;
  }

  my $msg = MIME::Lite->new(
    From=>$from,
    To=>$to,
    Subject=>$subject,
    Data=>$content
  );

  $msg->send or $self->{GLOBAL}->{LOGGER}->log("Unable to send email");
}

1;
