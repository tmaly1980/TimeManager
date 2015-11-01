####################
package Attendee;

use lib "../../MalyCGI";
use base "MalyDBO";
use Data::Dumper;

our @ENCODE_FIELDS = qw(CN ATTENDEE_ID EMAIL REQUIRED RSVP ASTATUS COMMENT);

sub subclass_init
{
  return ("attendees", ["attendee_id", "ref_id", "ref_type"] );
}

sub db2cgi
{
  my ($self) = @_;
  return
  (
    ENCODED_VALUE=>[ sub { $self->encoded_value(); } ],

  );
}

sub encoded_value
{
  my ($self) = @_;
  return join(":", map { $v=$self->get($_) } @ENCODE_FIELDS);
}

sub verify_all_from_form # CALLED AFTER SET_ALL_FROM_FORM. PERHAPS SHOULD INVOLVE SUGGESTING A NEW TIME TO ALLOW ATTENDEES TO BE IN
{
}

sub set_all_from_form
{
  my ($self, %form) = @_;
  my $attendees = $form{"ATTENDEES"};
  my @attendees_raw = ref $attendees eq 'ARRAY' ? @$attendees : ();

  my @keys = qw(CN ATTENDEE_ID EMAIL REQUIRED RSVP ASTATUS);

  my %attendees = ();

  for (my $i = 0; $i < @attendees_raw; $i++)
  {
    my $attendee_raw = $attendees_raw[$i];
    my @values = split(":", $attendee_raw);
    my %attendee = map { ($keys[$_], $values[$_]) } (0..$#values);
    $attendees{$attendee{ATTENDEE_ID}} = \%attendee;
  }

  # WE ASSUME THE JAVASCRIPT GENERATED APPROPRIATE ATTENDEE_ID's.....EVEN FOR NEW ONES.....

  my @covered_ids = ();
  my @all_ids = grep { /\w/ } keys %attendees;
  my @delete_ids = ();

  for ($self->first; $self->more; $self->next)
  {
    my $id = $self->get("ATTENDEE_ID");
    if ($id ne '')
    {
      my %attendee = ref $attendees{$id} ? %{ $attendees{$id} } : ();
      if (%attendee)
      {
        $self->set(%attendee, TYPE=>'I', REF_TYPE=>'E'); # Individual, Event
        push @covered_ids, $id;
      } else { # Deleted
        push @delete_ids, $id;
      }
    }

  }

  # Now go through ones on form not already covered.

  my @remaining_ids = grep { my $all_ix = $_; not grep { $all_ix == $_ } @covered_ids } @all_ids;

  $self->append if @remaining_ids;
  print STDERR "REMAINING=".join(";", @remaining_ids);
  foreach my $id (sort @remaining_ids) # Remaining in the form, just added.
  {
    my %attendee_hash = ref $attendees{$id} ? %{$attendees{$id}} : ();
    print STDERR "ATTENDEE=".Dumper(\%attendee_hash)."\n";
    next unless (%attendee_hash); # This is not in db, just ignore.

    $self->set(%attendee_hash, TYPE=>'I', REF_TYPE=>"E", ATTENDEE_ID=>$id);
    $self->next; 
  }

  $self->cgi_format(); # Re-make pseudo cols.

  return (@delete_ids);
}

sub commit_all_from_form
{
  my ($self, $event_id, @delete_ids) = @_;

  my @replace_ids = (); # For replacing ones after in list.

  for ($self->first; $self->more; $self->next)
  {
    my $id = $self->get("ATTENDEE_ID");
    next if $id eq '';
    # Need to ALSO keep track of next valid id (still to keep in system) for a given to-delete-id
    # SHOULD TAKE CARE OF AFTER DOING DELETE????
    # !!! HAS ATTENDEE ID SET. keep track of @delete_ids in @replace_ids. Shift off of when doing commit.
    if (grep { $id == $_ } @delete_ids)
    {
      #print STDERR "DELETING ID=$id (REALLY)\n";
      $self->delete;
      push @replace_ids, $id;
    } else {
      #print STDERR "COMMITTING $id\n";
      if (my $new_id = shift @replace_ids)
      {
        my $old_id = $self->get("ATTENDEE_ID");
	# Need to keep trtack of old_id, too. perhaps push onto list of replace_ids ?
	push @replace_ids, $old_id;
        $self->set(ATTENDEE_ID=>$new_id);
	# NEED TO BE ABLE TO DO !!!! MUST HAVE OLD COPY OF ATTENDEE_ID.
	# FIGURE OUT HOW DOES UPDATE, must do getold(PRIKEY)....
      }
      $self->commit(REF_ID=>$event_id);
    }
  }
  $self->cgi_format(); # Re-make pseudo cols.
}

################# OLD CRAP ###############################

sub set_all_from_form_old
{
  my ($self, %form) = @_;
  # Set Attendees, in same order in db as form

  my @attendee_fields = qw(CN EMAIL REQUIRED ASTATUS RSVP COMMENT);

  my @cn_fields = grep { /^CN_/i } keys %form;

  # HOW DO WE GET THE KEYS IN THE ORDER IT WAS DEFINED ???
  # PERHAPS HAVE ATTENDEE_ID ADDED TO LIST..... THEN HAVE ABSOLUTE REFERENCE

  # XXX TODO FIXME INEFFICIENCY !!!!!!!!!!!!!!!! SETTING RSVP="", AND FOR EVENT STUFF TOO.....

  my @covered_ids = ();
  my @all_ids = map { /^CN_(.*)/; $1; } @cn_fields;
  my @delete_ids = ();

  for ($self->first; $self->more; $self->next)
  {
    my $id = $self->get("ATTENDEE_ID");
    if ($id ne '')
    {
      my %attendee_hash = map { ($_, ($form{"${_}_$id"}||'') ) } @attendee_fields;

      if ($attendee_hash{CN})
      {
        $self->set(%attendee_hash);
        $self->set("type", 'I'); # Individual
        $self->set("ref_type", "E"); # Event
        push @covered_ids, $id;
      } elsif ($id ne '') {
        push @delete_ids, $id;
      }
    }
  }

  # Now go through ones on form not already covered.

  my @remaining_ids = grep { my $all_ix = $_; not grep { $all_ix == $_ } @covered_ids } @all_ids;

  $self->append if @remaining_ids;
  foreach my $id (sort @remaining_ids) # Remaining in the form, just added.
  {
    my %attendee_hash = map { ($_, $form{"${_}_$id"}) } @attendee_fields;
    next unless ($attendee_hash{CN} or $attendee_hash{EMAIL}); # This is not in db, just ignore.

    $self->set(%attendee_hash);
    $self->set("type", 'I'); # Individual
    $self->set("ref_type", "E"); # Event
    $self->set(ATTENDEE_ID=>$id);
    $self->next; 
  }
  return (@delete_ids);
}


1;
