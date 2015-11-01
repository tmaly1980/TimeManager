package DBAuth;

use User;
use Data::Dumper;

sub new
{
  my ($this, $globals) = @_;
  my $class = ref($this) || $this;
  my $self = {GLOBAL=>$globals};
  bless $self, $class;
  $self->{GLOBAL}->{SESS_AUTH} = sub { $self->authenticate(@_) },
  $self->{GLOBAL}->{SESS_GET} = sub { $self->get_session(@_) }, 
  $self->{GLOBAL}->{SESS_CREATE} = sub { $self->create_session(@_) },
  $self->{GLOBAL}->{SESS_DEL} = sub { $self->delete_session(@_) },
  return $self;
}

sub authenticate
{
  my ($self, $user, $password) = @_;
  $self->{GLOBAL}->{LOGGER}->log("USER=$user, PASSWORD=$password\n");
  my $record = User->search(USERNAME=>$user,PASSWORD=>$password);
  $self->{GLOBAL}->{LOGGER}->log("AUTH GOT:".Dumper($record->hashref)."\n");
  $record->get("USERNAME") || undef;
}

sub get_session
{
  my ($self, $session_id) = @_;
  my $record = User->search(session_id=>$session_id);
  #$self->{GLOBAL}->{LOGGER}->log("GET GOT ($session_id)=".Dumper($record->hashref)."\n");
  return $record->hashref;
}

sub create_session
{
  my ($self, $username, $password, $session_id) = @_;
  $self->{GLOBAL}->{LOGGER}->log("CREATE $username, SESSIONID=$session_id\n");
  my $user = User->search(USERNAME=>$username,PASSWORD=>$password);
  $self->{GLOBAL}->{LOGGER}->log("USER IS=". $user->get("UID")."\n");
  $user->update(SESSION_ID=>$session_id);
  return $self->get_session($session_id);
}

sub delete_session
{
  my ($self, $session_id) = @_;
  $self->{GLOBAL}->{LOGGER}->log("DELETE $session_id\n");
  User->search(SESSION_ID=>$session_id)->update(SESSION_ID=>undef);
}

1;
