####################
package Event;

use lib "../../MalyCGI";
use base "MalyDBO";
use Attendee;

sub subclass_init
{
  return ("events", "event_id");
}

sub db2cgi
{
  my ($self) = @_;
  return
  (
    OWNER=>[User->new(), OWNER_ID=>"UID" ],
    ATTENDEES=>[Attendee->new(), EVENT_ID=>"REF_ID", REF_TYPE=>'E'],
    #ATTENDEE_COUNT=>[ sub { $self->get("ATTENDEES")->count; } ],
    DURATION_WITH_UNITS=>"#DURATION#",
  );
}

sub search_by_attendee_email
{
  my ($this, $session_email) = @_;
  my $self = ref $this ? $this : $this->new("events, attendees");

  $self->{DEBUG} = 1;
  $self->search(["EVENT_ID = REF_ID"], REF_TYPE=>'E', EMAIL=>$session_email) if $session_email;
  $self->{DEBUG} = 0;
  # ADD PENDING ONLY XXX TODO XXX, AS WELL AS AFTER DATE...
  # Set the specified user in the event record as a link.
  return $self if defined wantarray;
}

1;
