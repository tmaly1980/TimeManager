####################
package Project;

use lib "../MalyCGI";
use base "MalyDBO";
use Data::Dumper;
use Task;
use TaskLink;
use Milestone;
use Participants;
use Product;
use User;
use Resources;
use Time::Local qw(timelocal_nocheck);

our $CONF = do "../etc/TMCGI.conf";

sub subclass_init
{
  return ("projects", "pid");
}

sub db2cgi
{
  my ($self) = @_;

  return
  (
    OVERDUE=>[ sub { overdue_prefix(@_) }, "#ENDDATE#", "#STATUS#" ],
    OVERDUE_OPEN=>[ sub { overdue_open_prefix(@_) }, "#ENDDATE#", "#STATUS#" ],
    MANAGER=>[ User->new(), "PMUID", "UID" ],
    PRODUCT_NAME=>[ sub { Product->get_name(@_) }, "#PROD_ID#" ],
    PARTICIPANT_UIDS=>[ Participants->new(), "PID", "PID" ],
    PARTICIPANTS=>[ User->new(), "PARTICIPANT_UIDS{UID}", "UID" ],
    MILESTONES=>[ Milestone->new(), "PID", "PID" ],
    RESOURCES=>[ Resources->new(), "PID", "PID" ],


    #PARTICIPANTS=>[ sub { $self->get_participants(@_) }, "#LIST:PARTICIPANT_UIDS{UID}#" ],
    #FLOATING_TASKS_IDS=>[ TaskLink->new(), "PID", "PID", ["(MID IS NULL)"] ],
    #FLOATING_TASKS=>[ Task->new(), "FLOATING_TASKS_IDS{TID}", "TID" ],
    #FLOATING_TASKS=>[ Task->new(), "PID", "PID", ["MID IS NULL"] ],
    #STATUS=>[ sub { $self->get_status(@_) }, ],
    #PERCENT=>[ sub { $self->get_percent(@_) } ],
    #COST=>[ sub { $self->get_cost(@_) } ],
    #TASKS=>[ Task->new(), "PID", "PID" ],
  );
}

sub overdue_prefix
{
  my ($enddate, $status) = @_;
  return "" if $enddate eq '' or $status >= 10; # No due date specified, or already finished.
  my ($year, $mon, $day) = split(/[-\/]/, $enddate);
  $mon--;
  $year-=1900;
  my $enddate_in_secs = timelocal_nocheck(0,0,0,$day,$mon,$year); # Midnight that day
  my $now = time;
  ($enddate_in_secs <= $now) ? "overdue_" : "";
}

sub overdue_open_prefix
{
  my ($enddate, $status) = @_;
  my $overdue = overdue_prefix($enddate, $status);
  $overdue = 'completed_' if ($overdue eq '' and $status >= 10);
  return $overdue;
}

# 
sub update_percent
{
  my ($self) = @_;
  my $pid = $self->get("PID");
  #my $tasks = Task->search(PID=>$pid);
  #my @percent = $tasks->get_all("PERCENT");
  #my $count = $tasks->count;
  #my $percent = 0;
  #if ($count > 0)
  #{
  #  my $percent_sum = 0;
  #  map { $percent_sum += $_ } @percent;
  #  $percent = int ($percent_sum / $count);
  #}
  #$self->set("PERCENT", $percent);
}

sub get_participants
{
  my ($self, $uids) = @_;
  my @uids = split(",", $uids);

  my $participants = User->search(User->col_in("UID", @uids));
  return $participants;
}

sub update_status # Will use the highest number in list. 
{
  my ($self) = @_;

  #my $milestones = $self->get("MILESTONES");
  my @component_status = ref $milestones ? $milestones->get_all("STATUS") : ();
  #my $floating_tasks = $self->get("FLOATING_TASKS");
  #push @component_status, ref $floating_tasks ? $floating_tasks->get_all("STATUS") : ();

  my $status = 0; # Not started is default.
  return 0 unless @component_status;

  my @map = ref $CONF->{MAP_PROJECT_STATUS} ? @{ $CONF->{MAP_PROJECT_STATUS} } : ();
  my %map = @map;
  my $i = 0; my @map_keys = grep { $i++ % 2 == 0 } @map;

  my %status = map { ($_, 1) } @component_status;

  if (keys %status == 1) # Only one kind
  {
    ($status) = keys %status;
  } else { # Go through config.
    foreach my $i (@map_keys)
    #(my $i = 0; $i < @map_keys; $i++)
    {
      if (grep { "$_" eq "$i" } @component_status) # Found, set to the value.
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
  $self->set("STATUS", $status);
}

sub get_cost
{
  my ($self) = @_;
  my $pid = $self->get("PID");
  return 0 if $pid eq '';
  my $total_cost = 0;
  #my $link = TaskProjectLink->search(PID=>$pid);
  #my $tasks = Task->search(Task->col_in("TID", $link->get_all("TID")));
  ##for ($tasks->first; $tasks->more; $tasks->next)
  #{
  #  my $cost = $tasks->get("COST");
  #  my $hourly = $tasks->get("COST_HOURLY");
  #  my $hours = $tasks->get("HOURS");
  #  $total_cost += ($hourly ? $cost * $hours : $cost);
  #}
  return $total_cost;
}

sub sync_stats # esthours, hours, status, percent, cost!
# ONLY should get called from subtasks! so then this milestone already exists!
{
  my ($self) = @_;
  $self->refresh(); # Forces a subrecord cache erase. As well as iterators, etc...
  for ($self->first; $self->more; $self->next) 
  # WE need to do the loop since the iterator gets reset from refresh()
  {
    my $miles = $self->get("MILESTONES");
    my @task_link = $miles->get_all("TASK_IDS");

    my @task_ids = map { $_->{TID} } @task_link;

    my $tasks = Task->search_cols('PERCENT, STATUS, ESTHOURS, HOURS, COST, COST_HOURLY', Task->col_in(TID=>@task_ids));

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
    
    if (keys %status == 1) # Only one kind.
    {
      ($status) = keys %status;
    } elsif (keys %status == 2 and $status{10} and $status{20}) {
    # If all completed and some canceled, we're completed.
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
    my $cost = 0;
    my $estcost = 0;
  
    for ($tasks->first; $tasks->more; $tasks->next)
    {
      my $st = $tasks->get("STATUS");
      my $tcost = $tasks->get("COST");
      my $thours = $tasks->get("HOURS");
      my $testhours = $tasks->get("ESTHOURS");
      my $hourly = $tasks->get("COST_HOURLY");
      if ($st < 10 or $st >= 20) # Don't count if canceled
      {
        $percent += $tasks->get("PERCENT");
        $hours += $tasks->get("HOURS");
        $esthours += $tasks->get("ESTHOURS");
	$count++;
      }
      $cost += $hourly ? ($thours||$testhours) * $tcost : $tcost;
      $estcost += $hourly ? $testhours * $tcost : $tcost;
    }
  
    $percent /= $count if $count > 0;
    $self->commit(PERCENT=>$percent, STATUS=>$status, ESTHOURS=>$esthours, HOURS=>$hours, ESTCOST=>$estcost, COST=>$cost);
  }
}

1;
