package MalyDBAuth;

# To authenticate using the db package "User", just pass DBAUTH=>1 to new()

use User;
use Data::Dumper;

sub new
{
  my ($this, $globals) = @_;
  my $class = ref($this) || $this;
  my $self = {GLOBAL=>$globals};
  bless $self, $class;
  $self->{GLOBAL}->{SESS_AUTH} = sub { $self->authenticate(@_) };
  $self->{GLOBAL}->{SESS_GET} = sub { $self->get_session(@_) }; 
  $self->{GLOBAL}->{SESS_CREATE} = sub { $self->create_session(@_) };
  $self->{GLOBAL}->{SESS_DEL} = sub { $self->delete_session(@_) };
  $self->{GLOBAL}->{SESS_SET} = sub { $self->set_session(@_) };
  $self->{GLOBAL}->{SESS_ACCT_CHANGE} = sub { return $self->change_session_account(@_) };
  $self->{GLOBAL}->{SESS_ACCT_CREATE} = sub { return $self->create_session_account(@_) };
  return $self;
}

sub authenticate
{
  my ($self, $user, $password) = @_;
  my $record = User->search($self->id=>$user,PASSWORD=>$password);
  my $username = $record->get($self->id);
  return $username || undef;
}

sub get_session # This should never give an object, as we should handle changes!
{
  my ($self, $session_id) = @_;
  my $record = $self->get_user_by_session_id($session_id);
  return $record if $record->count;
  return;
}

sub set_session # Can be used for insertion OR update! Use with care.
{
  my ($self, $session_id, %set) = @_;
  my $user = $self->get_user_by_session_id($session_id);
  $user->commit(%set);
  return $user; # For hell of it.
}

sub create_session
{
  my ($self, $username, $password, $session_id) = @_;
  my $sess = undef;
  if ($self->{GLOBAL}->{MULTIUSER})
  {
    # APPEND!
    $self->remove_expired_sessions();
    UserSession->search(SESSION_ID=>$session_id)->delete();
    my $user = User->search($self->id=>$username, PASSWORD=>$password);
    $sess = UserSession->commit(SESSION_ID=>$session_id, UID=>$user->get("UID"), DATE=>$self->datetime);
  } else {
    $sess = User->search($self->id=>$username, PASSWORD=>$password)->update(SESSION_ID=>$session_id);
  }
  #return $self->get_session($session_id);
}

sub delete_session
{
  my ($self, $session_id) = @_;
  my $user = $self->get_session_object_by_id($session_id);
  if ($self->{GLOBAL}->{MULTIUSER})
  {
    $user->delete();
  } else {
    $user->update(SESSION_ID=>undef);
  }
}

sub change_session_account
{
  my ($self, $session_id, %account_changes) = @_;
  my $user = $self->get_user_by_session_id($session_id);

  # HANDLE PASSWORD
  # SKIP USERNAME IN CASE GIVEN
  my $id = $self->id;
  delete $account_changes{$id};

  my $password1 = $account_changes{"PASSWORD1"};
  my $password2 = $account_changes{"PASSWORD2"};

  if ($password1 or $password2)
  {
    $self->{GLOBAL}->{LOGGER}->{USER_ERROR}->("Passwords do not match.") if ($password1 ne $password2);
    $self->{GLOBAL}->{LOGGER}->{USER_ERROR}->("Password must be 6 or more characters.") if ( length $password1 < 6);
    $account_changes{PASSWORD} = $password1;
  }

  if ($user->count)
  {
    $user->commit(%account_changes);
  } else {
    $self->{GLOBAL}->{LOGGER}->internal_error("Unable to change account. Invalid user/session.");
  }
  return $user->hash if wantarray;
  return $user->hashref if defined wantarray;
}

sub id
{
  my ($self) = @_;
  uc $self->{GLOBAL}->{SESS_USER} || "USERNAME";
}

sub create_session_account
{
  my ($self, $session_id, %account) = @_;

  %account = map { (uc($_), $account{$_}) } keys %account;
  
  # ABORT on no username, password
  # HANDLE PASSWORD (creating PASSWORD from PW1 and PW2, matching, etc...

  if (not $account{PASSWORD}) # If not given one, try input of two.
  {
    my $password1 = $account{"PASSWORD1"};
    my $password2 = $account{"PASSWORD2"};
    $self->{GLOBAL}->{LOGGER}->{USER_ERROR}->("Must specify password.") if (not $password1 or not $password2);
    $self->{GLOBAL}->{LOGGER}->{USER_ERROR}->("Passwords do not match.") if ($password1 and $password1 ne $password2);
    $self->{GLOBAL}->{LOGGER}->{USER_ERROR}->("Password must be 6 or more characters.") if ( length $password1 < 6);
    $account{PASSWORD} = $password1;
  }


  my $id = $self->id;
  my $id_value = $account{$id};
  $self->{GLOBAL}->{LOGGER}->{USER_ERROR}->("No account ID ($id) specified.") if (not $id_value);
  $self->{GLOBAL}->{LOGGER}->{USER_ERROR}->("Account ID ($id) already taken.") if (User->search($id=>$id_value)->count);

  my $user = User->new();
  $user->commit(%account);
  my $sess = $self->get_session_object_by_login($account{$id}, $account{PASSWORD});
  $sess->commit(SESSION_ID=>$session_id, DATE=>$self->datetime);
}

sub get_user_by_session_id
{
  my ($self, $session_id) = @_;
  if ($self->{GLOBAL}->{MULTIUSER})
  {
    require UserSession;
    my $sess = UserSession->search(SESSION_ID=>$session_id);
    my $uid = $sess->get("UID");
    my $user = User->new();
    $user->search(UID=>$uid) if $uid ne '';
    return $user;
  } else {
    return User->search(SESSION_ID=>$session_id);
  }
}

sub get_session_object_by_id
{
  my ($self, $session_id) = @_;
  if ($self->{GLOBAL}->{MULTIUSER})
  {
    $self->remove_expired_sessions();
    require UserSession;
    my $so = UserSession->search(SESSION_ID=>$session_id);
    return $so;
  } else {
    my $so = User->search(SESSION_ID=>$session_id);
    return $so;
  }
}

sub get_session_object_by_login
{
  my ($self, $username, $password) = @_;
  if ($self->{GLOBAL}->{MULTIUSER})
  {
    $self->remove_expired_sessions();
    require UserSession;
    my $so = UserSession->search($username, $password);
    return $so;
  } else {
    my $so = User->search($self->id=>$username, PASSWORD=>$password);
    return $so;
  }
}

sub remove_expired_sessions # Otherwise, dont bother, new logins will overwrite.
{
  my ($self) = @_;
  if ($self->{GLOBAL}->{MULTIUSER})
  {
    require UserSession;
    my $table = UserSession->table_name;
    my $offset = $self->{GLOBAL}->{SESS_LENGTH_IN_SECS} || (60*60*24); # Default to a day.
    my $date = $self->datetime(time - $offset);
    $MalyDBO::DEBUG = 1;
    MalyDBO->do("DELETE FROM $table WHERE date < '$date'");
    $MalyDBO::DEBUG = 0;
  }
}

sub datetime
{
  my ($self, $time) = @_;
  $time ||= time();
  my ($s, $min, $h, $d, $mon, $y) = localtime($time);
  sprintf "%04u-%02u-%02u %02u:%02u:%02u", $y+1900, $mon+1, $d, $h, $min, $s;
}

1;
