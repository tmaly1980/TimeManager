####################
package Milestone;

use lib "../MalyCGI";
use base "MalyDBO";
use Task;
use TaskLink;
use Notes;
use Data::Dumper;
use User;

our $CONF = do "../etc/TMCGI.conf";

sub subclass_init
{
  return ("milestones","mid");
}

sub db2cgi
{
  my ($self) = @_;

  return
  (
    OWNER=>[ User->new(), "UID", "UID" ],
    TASK_IDS=>[ TaskLink->new(), "MID", "MID", ["(PTID IS NULL)"] ],
    TASKS=>[ Task->new(), "TASK_IDS{TID}", "TID" ],
    PROJECT=>[ Project->new(), "PID", "PID" ],
    EDITABLE=>[ sub { $self->get_editable_fields(@_) } ],
    NOTES=>[ Notes->new(), "MID", "MID" ],
    #TASKS=>[ Task->new(), "MID", "MID" ],
    #STATUS=>[ sub { $self->get_status(@_) }, "#MID#" ],
    #STATUS=>[ sub { $self->get_status(@_) }, "#LIST:TASKS{STATUS}#" ],
    #PERCENT=>[ sub { $self->get_percent(@_) }, "#MID#" ],
    #PERCENT=>[ sub { $self->get_percent(@_) }, "#LIST:TASKS{PERCENT}#" ],
  );
}

sub get_editable_fields 
{
  my ($self, $add) = @_;
  return undef if ref $self and $self->is_new;
  my @fields = ($self->table_columns , qw(NOTES)); # Explicitly set pseudo (form) fields.
  # if $add is set, we're adding. Treat like we're the manager.
  if ($add)
  {
    %edit = map { ($_, 1) } @fields;
    return \%edit;
  }
  return undef unless exists $self->{GLOBAL}->{SESSION};
  my $uid = $self->get("UID");
  my $session_uid = $self->{GLOBAL}->{SESSION}->get("UID");
  my @managed_users = $self->{GLOBAL}->{SESSION}->get("MANAGED");
  my @managed_uids = map { $_->{UID} } @managed_users;
  my $siteadmin = $self->{GLOBAL}->{SESSION}->get("SITEADMIN");

  my %edit = ();

  if ($siteadmin or $add or ($uid ne '' and $uid == $session_uid)) # Siteadmin or own or adding.
  {
    %edit = map { ($_, 1) } @fields;
  #} elsif ($session_uid == $uid) { # Just add ones mentioned in config file, as owner.
  # NEED TO FIX, MENTION LIST FOR TASK GROUP EDITABLE FIELDS!!!!
  #  %edit = map { ($_, 1) }
  #    (ref $CONF->{OWNER_EDITABLE_FIELDS} eq 'ARRAY' ? 
  #      @{ $CONF->{OWNER_EDITABLE_FIELDS} } : () 
  #    );
  } # Else, some other schmuck.
  return \%edit;
}

sub sync_stats # esthours, hours, status, percent
# ONLY should get called from subtasks! so then this milestone already exists!
{
  my ($self) = @_;
  $self->refresh(); # Forces a subrecord cache erase. As well as iterators, etc...
  for ($self->first; $self->more; $self->next) 
  # WE need to do the loop since the iterator gets reset from refresh()
  {
    my $tasks = $self->get("TASKS");
    my $percent = 0;
    my $status = 0;
    my $esthours = 0;
    my $hours = 0;
  
  
    my @map = 
    (
      # any stalled, it's stalled
      2=>2, 
      # any in progress, it's in progress
      1=>1, 
      # if any completed, it's in progress (if all completed, caught elsewhere to show completed)
      20=>1,
    );
    my %map = @map;

    my @status = $tasks->get_all("STATUS");
    my $i = 0; my @map_keys = grep { $i++ % 2 == 0 } @map;
    my %status = map { ($_, 1) } @status;

    my @status_keys = keys %status;
    
    if (keys %status == 1) # Only one kind.
    {
      ($status) = keys %status;
    } elsif ($status{20} and not grep { $_ < 10 } keys %status) {
    # If all completed and some canceled (or similar), we're completed.
      $status = 20;
    } else {
      foreach my $i (@map_keys)
      {
        if (grep { "$_" eq "$i" } @status) # Found, set.
        {
          if ($map{$i} eq '')
  	{
  	  $status = $i;
  	} else {
  	  $status = $map{$i};
  	}
  	last;
        }
      }
    }
  
    my $count = 0;
  
    for ($tasks->first; $tasks->more; $tasks->next)
    {
      if ($tasks->get("STATUS") != 10) # Don't count if canceled
      {
        $percent += $tasks->get("PERCENT");
        $hours += $tasks->get("HOURS");
        $esthours += $tasks->get("ESTHOURS");
	$count++;
      }
    }
  
    $percent /= $count if $count > 0;
    $self->commit(PERCENT=>$percent, STATUS=>$status, ESTHOURS=>$esthours, HOURS=>$hours);
  }
}

sub get_percent
{
  # Problem here is that we do another search, WHEN WE HAVE IT ONE STEP AWAY!
  #my ($self, $mid) = @_;
  #return 0 if $mid eq '';
  my ($self, $percent) = @_;
  my @percent = split(",", $percent);

  #my $tasks = Task->search(MID=>$mid);
  #my @percent = $tasks->get_all("PERCENT");
  #my $count = $tasks->count;
  my $count = scalar @percent;
  if ($count > 0)
  {
    my $percent_sum = 0;
    map { $percent_sum += $_ } @percent;
    return int ($percent_sum / $count);
  } else {
    return 0;
  }
}


sub get_status # Will use the highest number in list. 
{
  #my ($self, $mid) = @_;
  #print STDERR "SELF=$self, ITER=$self->{ITER}\n";
  #my $tasks = $self->get("TASKS");
  #print STDERR "TASKS=$tasks\n";
  #my @task_status = ref $tasks ? $tasks->get_all("STATUS") : ();

  my ($self, $status_list) = @_;
  my @task_status = split(",", $status_list);

  my $status = 0; # Not started is default.
  return 0 unless @task_status;

  my @map = ref $CONF->{MAP_PROJECT_STATUS} ? @{ $CONF->{MAP_PROJECT_STATUS} } : ();
  my %map = @map;
  my $i = 0; my @map_keys = grep { $i++ % 2 == 0 } @map;

  my %status = map { ($_, 1) } @task_status;

  if (keys %status == 1) # Only one kind
  {
    ($status) = keys %status;
  } else { # Go through config.
    foreach my $i (@map_keys)
    {
      if (grep { "$_" eq "$i" } @task_status) # Found, set to the value.
      {
	if ($map{$i} eq '')
	{
	  $status = $i;
	} else {
          $status = $map{$i};
	}
	last; # Don't bother to check any more.
      }
    }
  }

  return $status;
}

sub add_note
{
  my ($self, @notes) = @_;
  my $note_text = join("\n", @notes);
  if ($note_text ne '')
  {
    my $note = Notes->new();
    my $mid = $self->get("MID");
    my $uid = $self->{GLOBAL}->{SESSION}->get("UID");
    my ($sec,$min,$hour,$day,$mon,$year) = localtime();
    my $timestamp = sprintf "%04u-%02u-%02u %02u:%02u:%02u", 
	$year+1900, $mon+1, $day, $hour, $min, $sec;
    $note->commit(MID=>$mid,UID=>$uid,TEXT=>$note_text,TIMESTAMP=>$timestamp);
  }
}

sub bulk_change
{
  my ($self, %form) = @_;
  %form = map { my $k = $_; s/^bulk_//i; ($_, $form{$k}) } keys %form;

    my @keys = qw(PRIORITY PID STARTDATE ENDDATE UID REL_STARTDATE REL_STARTDATE_UNIT REL_ENDDATE REL_ENDDATE_UNIT);
    my %changes = ();
    foreach my $key (@keys)
    {
      my $value = $form{$key};
      if ($value ne '')
      {
        $changes{$key} = $value;
      }
    }

    return ("No changes to perform.") unless %changes;

    for($self->first; $self->more; $self->next)
    {
      my $mid = $self->get("MID");

      # Relative date changes.
      if ($changes{REL_STARTDATE})
      {
        my $startdate = $self->get("STARTDATE");
	if ($startdate)
	{
	  my $count = $changes{REL_STARTDATE} * ($changes{REL_STARTDATE_UNIT}||1);
	  $changes{STARTDATE} = Calendar->date(
	    Calendar->date_in_secs($startdate) + Calendar->day($count)
	    );
	}
      }

      if ($changes{REL_ENDDATE})
      {
        my $enddate = $self->get("ENDDATE");
	if ($enddate)
	{
	  my $count = $changes{REL_ENDDATE} * ($changes{REL_ENDDATE_UNIT}||1);
	  $changes{ENDDATE} = Calendar->date(
	    Calendar->date_in_secs($enddate) + Calendar->day($count)
	    );
	}

      }
      $self->commit(%changes);
    }
    return undef; # OK
}

1;
