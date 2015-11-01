####################
package Task;

use lib "../../MalyCGI";
use base "MalyDBO";
use base "Logging";
use MalyDBO;
use MIME::Base64;
use Time::Local qw(timelocal_nocheck);
use Notes;
use Data::Dumper;
use Milestone;
use Project;
use User;
use TaskLink;
use Resources;
use WebReferences;
use TaskCategoryStage;

our $CONF = do "../etc/TMCGI.conf";

sub subclass_init
{
  return ("tasks", "tid");
}

sub generate_notes # Takes notes from form and creates db col data.
# Needs to be an actual record instance, not a class as first parameter.
{
  my ($self, $new_notes, $formatted_notes) = @_;
  if ($new_notes)
  {
    my $uid = $self->{GLOBAL}->{SESSION}->{UID};
    my $timestamp = time();
    my $b64notes = encode_base64($new_notes,'');

    my $append_notes = "$uid:$timestamp:$b64notes";
    if ($formatted_notes)
    {
      $formatted_notes .= ";$append_notes";
    } else {
      $formatted_notes = $append_notes;
    }
  }
  return $formatted_notes;
}

sub cgi2db
{
  my ($self, %hash) = @_;

  # Just muck with fields we want to.

  $self->SUPER::cgi2db(%hash);
}

sub db2cgi
{
  my ($self) = @_;

  return
  (
    OVERDUE=>[ sub { overdue_prefix(@_) }, "#DUEDATE#", "#STATUS#" ],
    OVERDUE_OPEN=>[ sub { overdue_open_prefix(@_) }, "#DUEDATE#", "#STATUS#" ],
    REQUESTOR=>[ User->new(), "REQUESTOR_UID", "UID" ],
    SUBMITBY=>[ User->new(), "SUBMITBY_UID", "UID" ],
    OWNER=>[ User->new(), "UID", "UID" ],
    UPDATED=>[ sub { $_[0] =~ s/s+/<br>\n/g; $_[0]; }, "#CHANGED#" ],
    EDITABLE=>[ sub { $self->get_editable_fields(@_) } ],
    NOTES=>[ Notes->new(), "TID", "TID" ],
    CATEGORY=> [ TaskCategories->new(), "TCID", "TCID" ],
    #MILESTONE=>[ Milestone->new(), "MID", "MID" ], # Needed for dependency numbering.
    TGROUP_IDS=>[ TaskLink->new(), "TID", "TID", ["(PTID IS NULL AND MID IS NOT NULL)"] ],
    TGROUPS=>[ Milestone->new(), "TGROUP_IDS{MID}", "MID" ],
    PARENT_IDS=>[ TaskLink->new(), "TID", "TID", ["(MID IS NULL AND PTID IS NOT NULL)"] ],
    SUBTASK_IDS=>[ TaskLink->new(), "TID", "PTID", ["(MID IS NULL AND PTID IS NOT NULL)"] ],
    SUBTASKS=>[ Task->new(), "SUBTASK_IDS{TID}", "TID" ], 
    DEP_NOT_MET=>[ sub { $self->dep_not_met(@_) }, "#LIST:SUBTASK_IDS{STRICT}#", "#LIST:SUBTASKS{STATUS}#" ],
    #SUBTASKS=>[ Task->new(), "TID", "PTID" ], #XXX
    TASK_CATEGORY=>[ TaskCategories->new(), "TCID", "TCID" ],
    TASK_CATEGORY_STAGE=>[ TaskCategoryStage->new(), "STAGE", "IX", TCID=>"#TCID#" ],
    PARTICIPANT_UIDS=>[ Participants->new(), "TID", "TID" ],
    PARTICIPANTS=>[ User->new(), "PARTICIPANT_UIDS{UID}", "UID" ],
    RESOURCES=>[ Resources->new(), "TID", "TID" ],
    WEBREFS=> [ WebReferences->new(), "TID", "TID" ],
    STATUSNAME=>[ sub { $self->get_status_name(@_) }, "#STATUS#" ],
    PRIORITYNAME=>[ sub { $self->get_priority_name(@_) }, "#PRIORITY#" ],
  );
}

sub get_status_name
{
  my ($self, $st) = @_;
  return $CONF->{STATUSMAP}->{$st} || "Unknown";
}

sub get_priority_name
{
  my ($self, $pr) = @_;
  return $CONF->{PRIORITYMAP}->{$pr} || "Unknown";
}

sub dep_not_met
{
  my ($self, $strict, $status) = @_;
  my @strict = split(",", $strict);
  my @status = split(",", $status);
  for (my $i = 0; $i < @strict; $i++)
  {
    if ($strict[$i] and $status[$i] < 10)
    {
      return 1;
    }
  }
  return undef;
}

sub get_editable_fields 
{
  my ($self, $add) = @_;
  return undef if ref $self and $self->is_new;
  my @fields = ($self->table_columns , qw(PARTICIPANTS TGROUPS NOTES SUBTASKS WEBREFS RESOURCES)); # Explicitly set pseudo (form) fields.
  # if $add is set, we're adding. Treat like we're the manager.
  if ($add)
  {
    %edit = map { ($_, 1) } @fields;
    return \%edit;
  }
  return undef unless exists $self->{GLOBAL}->{SESSION};
  my $uid = $self->get("UID");
  my $requestor_uid = $self->get("REQUESTOR_UID");
  my $session_uid = $self->{GLOBAL}->{SESSION}->get("UID");
  my @managed_users = $self->{GLOBAL}->{SESSION}->get("MANAGED");
  my @managed_uids = map { $_->{UID} } @managed_users;
  my $siteadmin = $self->{GLOBAL}->{SESSION}->get("SITEADMIN");

  my %edit = ();

  if ($siteadmin or $requestor_uid == $session_uid or $add) # Siteadmin, or requestor.
  {
    %edit = map { ($_, 1) } @fields;
  } elsif ($session_uid == $uid) { # Just add ones mentioned in config file, as owner.
    %edit = map { ($_, 1) } @fields;
    my @readonly_fields = ref $CONF->{REQUESTOR_EDITABLE_FIELDS} eq 'ARRAY' ?
      @{ $CONF->{REQUESTOR_EDITABLE_FIELDS} } : ();

    map { $edit{$_} = undef; } @readonly_fields;
  } # Else, some other schmuck.
  return \%edit;
}

sub overdue_open_prefix
{
  my ($enddate, $status) = @_;
  my $overdue = overdue_prefix($enddate, $status);
  $overdue = 'completed_' if ($overdue eq '' and $status >= 10);
  print STDERR "STATUS=$status\n";
  return $overdue;
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

sub exceeds # Complain if $date1 > $date2 (ONLY IF date2 is set!)
{
  my ($self, $date1, $date2) = @_;
  # ASSUME YYYY-MM-DD format.

  my ($y1, $m1, $d1) = $date1 =~ /(\d{4})\D(\d{2})\D(\d{2})/;
  my ($y2, $m2, $d2) = $date2 =~ /(\d{4})\D(\d{2})\D(\d{2})/;

  my $time1 = timelocal_nocheck(0,0,0,$d1,$m1-1,$y1-1900);
  my $time2 = timelocal_nocheck(0,0,0,$d2,$m2-1,$y2-1900);
  return ($time2 ne '' and $time1 > $time2); # Only complain if due date set.
}


sub sql_datetime_from_secs # For import into SQL
{
  my ($self, $time) = @_;
  $time ||= time();
  my ($s,$min,$h,$d,$mon,$y) = localtime($time);
  sprintf "%4u-%02u-%02u %02u:%02u:%02u", $y+1900, $mon+1, $d, $h, $min, $s;
}

sub save # SHOULD ALSO TAKE CARE OF ADDS! TODO XXX
# WARNING!!! DONT USE THIS WITHOUT PASSING PARTICIAPNTS, RESOURCES, TGROUPS, SUBT, as the omission
# WILL ERASE THEM!
# MAY NEED TO ADD FLAG SAYING CAME FROM EDIT PAGE AND NOT SOME OTHER CGI...
{
  my ($self, %hash) = @_;

  # If has subtasks, refuse to set to completed if subtasks arent.
  # Also, if set to cancelled, set all subtasks to cancelled as well....

  my $tid = $self->get("TID");

  my $subtasks = Task->new();

  #if ($tid ne '')
  #{
  #  $subtasks->search(PTID=>$tid);
  #}
  # FIX!!!!! XXX

    
  my $now = $self->sql_datetime_from_secs();
  my $session_uid = $self->{GLOBAL}->{SESSION}->get("UID");
  my $siteadmin = $self->{GLOBAL}->{SESSION}->get("SITEADMIN");
  my $task_uid = $self->get("UID");
  my $requestor_uid = $self->get("REQUESTOR_UID");
  my $project_uid = $self->get("PROJECT{PMUID}");
  if (! $self->is_new)
  {
    return "Permission Denied" if ($session_uid != $requestor_uid and 
      $session_uid != $task_uid and $session_uid != $project_uid and !$siteadmin);
  } 

  #if ($subtasks->count && $hash{STATUS} >= 20 && @sub_status && grep { $_ < 10 } $subtasks->get_all("STATUS"))
  #{
  #  return "Cannot set a task to completed until all of it's subtasks are set to completed.";
  #} 


  $self->set(%hash, CHANGED=>$now);
  $self->set(SUBMITTED=>$now, SUBMITBY_UID=>$session_uid) if $self->is_new;
  return("Must set title") unless $self->get("TITLE");
  return("Must set due date to complete this task") if ($self->get("STATUS") >= 20 and $self->get("DUEDATE") eq '');
  return("Must set estimated work hours to complete this task") if ($self->get("STATUS") >= 20 and $self->get("ESTHOURS") eq '');
  return("Must set actual work hours to complete this task") if ($self->get("STATUS") >= 20 and $self->get("HOURS") eq '');




  if (not $self->is_new) 
  {
    if ($self->get("STATUS") >= 20) # Check to make sure deps are taken care of.
    {
      my $dep_tasks = $self->get("SUBTASKS");
      for ($dep_tasks->first; $dep_tasks->more; $dep_tasks->next)
      {
        if ($dep_tasks->get("STATUS") < 10)
	{
          return("Must complete subtasks/dependencies first, prior to this task's completion.");
	}
      }
    }

    $self->set("STAGE", undef) if ($self->has_changed("TCID"));
  }
  
  $self->commit; # Move to new MID if needed.
  my $tid = $self->get("TID");
  $self->add_note($hash{NOTES}); # Custom notes.

  # Now do web references (urls)
  if ($hash{WEBREF})
  {
    my @webref = ();
    if (ref $hash{WEBREF} eq 'ARRAY')
    {
      @webref = @{ $hash{WEBREF} };
    } elsif ($hash{WEBREF} ne '') {
      @webref = ($hash{WEBREF});
    }

    my @url = ();
    my @desc = ();
    foreach my $webref (@webref)
    {
      my ($url, $desc) = split(/\|/, $webref);
      push @url, $url;
      push @desc, $desc;
    }

    my $webref = $self->get("WEBREFS") || WebReferences->new();
    $webref->commit_list([TID=>$tid], undef, ["URL", "TID"], URL=>\@url, DESCRIPTION=>\@desc);
  } else { # Clear.
    WebReferences->search(TID=>$tid)->delete_all;
  }

  # Now do participants.
  if ($hash{PARTICIPANTS})
  {
    my @participants = ();
    if (ref $hash{PARTICIPANTS} eq 'ARRAY')
    {
      @participants = @{ $hash{PARTICIPANTS} };
    } elsif ($hash{PARTICIPANTS} ne '') {
      @participants = ($hash{PARTICIPANTS});
    }

    my @party_id = ();

    my $participants = $self->get("PARTICIPANT_UIDS") || Participants->new();
    $participants->commit_list([TID=>$tid], undef, ["UID", "TID"], UID=>\@participants);
  } else { # Clear.
    Participants->search(TID=>$tid)->delete_all;
  }

  # Now do resources.
  if ($hash{RESOURCES})
  {
    my @resources = ();
    if (ref $hash{RESOURCES} eq 'ARRAY')
    {
      @resources = @{ $hash{RESOURCES} };
    } elsif ($hash{RESOURCES} ne '') {
      @resources = ($hash{RESOURCES});
    }

    my @res_id = ();
    my @name = ();

    foreach my $resource (@resources)
    {
      my ($name, $res_id) = split(":", $resource);
      push @res_id, $res_id;
      push @name, $name;
    }

    my $resources = $self->get("RESOURCES") || Resources->new();
    $resources->commit_list([TID=>$tid], undef, undef, RES_ID=>\@res_id, NAME=>\@name);
  } else { # Clear.
    Resources->search(TID=>$tid)->delete_all;
  }



  if ($hash{TGROUPS}) # Link task groups/milestones
  {
    print STDERR "TG\n";
    my @tgroups = ();
    if (ref $hash{TGROUPS} eq 'ARRAY')
    {
      @tgroups = @{$hash{TGROUPS}};
    } elsif ($hash{TGROUPS} ne '') {
      @tgroups = ($hash{TGROUPS});
    }

    my @lid = ();
    my @mid = ();

    foreach my $tgroup (@tgroups)
    {
      my ($lid, $mid) = split(":", $tgroup);
      push @lid, $lid;
      push @mid, $mid;
    }

    my $task_link = TaskLink->new();
    $task_link->search(TID=>$tid, ["(MID IS NOT NULL)"]);

    $task_link->commit_list([TID=>$tid], undef, undef, MID=>\@mid, LINK_ID=>\@lid);

    # Synchronize data with milestones.

    my $mile = Milestone->search(Milestone->col_in(MID=>$task_link->get_all("MID")));
    $mile->sync_stats(); # Does it for EVERY one, as we also reset the data

    my $projects = Project->search(Project->col_in(PID=>$mile->get_all("PID")));
    $projects->sync_stats();
    
  } else { # Clear task groups of.
    my $task_link = TaskLink->search(TID=>$tid, ["MID IS NOT NULL"]);
    my @mid_list = $task_link->get_all("MID");
    $task_link->delete_all();

    # Sync milestones.

    my $mile = Milestone->search(Milestone->col_in(MID=>@mid_list));
    for ($mile->first; $mile->more; $mile->next)
    {
      $mile->sync_stats();
    }

    my $projects = Project->search(Project->col_in(PID=>$mile->get_all("PID")));
    $projects->sync_stats();
  }

  if ($hash{SUBTASKS})
  {
    my @subtasks = ();
    if (ref $hash{SUBTASKS} eq 'ARRAY')
    {
      @subtasks = @{$hash{SUBTASKS}};
    } 
    elsif ($hash{SUBTASKS} ne '')
    {
      @subtasks = ($hash{SUBTASKS});
    }

    my @lid = ();
    my @tid = ();
    my @ntid = ();
    my @strict = ();

    for (my $ntid = 0; $ntid < @subtasks; $ntid++)
    {
      my $subtask = $subtasks[$ntid];
      my ($lid, $tid, $strict) = split(":", $subtask);
      push @lid, $lid;
      push @ntid, $ntid;
      push @tid, $tid;
      push @strict, $strict;
    }

    my $subtlink = TaskLink->search(PTID=>$tid, ["(MID IS NULL)"]);
    $subtlink->commit_list([PTID=>$tid], undef, undef, TID=>\@tid, LINK_ID=>\@lid, NTID=>\@ntid, STRICT=>\@strict);
  } else {
    TaskLink->search(PTID=>$tid)->delete_all(); # Remove all.
  }


  if ($self->defined("MID"))
  {
    # If we've changed MID, we need to update that thing first. (we need to commit above set() first)
    my $mid_tasks = Task->search(MID=>$self->get("MID"));
    $mid_tasks->commit_sorted_list("MTID", $self->hash); # So we know which one is what we are changing. as determined by prikeys
  }
  #$self->logging($task);
  $self->log_changes();
  $self->notification($task);

  return 0;
}

sub add_note
{
  my ($self, @notes) = @_;
  my $concat_notes = join("\n", @notes);
  if ($concat_notes ne '')
  {
    my $note = Notes->new();
    my $tid = $self->get("TID");
    my $uid = $self->{GLOBAL}->{SESSION}->get("UID");
    my ($sec,$min,$hour,$day,$mon,$year) = localtime();
    my $timestamp = sprintf "%04u-%02u-%02u %02u:%02u:%02u", 
	$year+1900, $mon+1, $day, $hour, $min, $sec;
    $note->commit(TID=>$tid,UID=>$uid,TEXT=>$concat_notes,TIMESTAMP=>$timestamp);
  }
}

sub notification
{
  my ($self) = @_;

  # Notification.
  my $task_uid = $self->get("UID");
  my $requestor_uid = $self->get("REQUESTOR_UID");

  # If new task, notify owner if not self.
  # If updating,
  # 	if requestor, notify if not also owner
  #	if owner, notify requestor (if not same)

  my ($s, $min, $h, $d, $mon, $y) = localtime();
  my $today = sprintf "%04u-%02u-%02u", $y+1900, $mon+1, $d;

  # Things to note at the top of the email.

  my @messages = ();
  push @messages, "Estimated Finish Date EXCEEDS Due Date" if ($self->defined("DUEDATE") and $self->exceeds($self->get("ESTCOMDATE", "DUEDATE")));
  push @messages, "Task is OVERDUE" if ($self->defined("DUEDATE") and $self->exceeds($today, $self->get("DUEDATE")));
  push @messages, "Priority CHANGED" if ($self->has_changed("PRIORITY"));
  push @messages, "Status CHANGED" if ($self->has_changed("STATUS"));
  push @messages, "Due Date CHANGED" if ($self->has_changed("DUEDATE"));
  push @messages, "Task REASSIGNED" if ($self->has_changed("UID") and $self->getold("UID") ne '');

  if ($self->getold("UID") ne '' and $self->has_changed("UID")) # Notify old person of unassignment.
  {
    $self->{GLOBAL}->{MESSENGER}->notify($self->getold("UID"), "Task Updated", "Tasks/mail/update", $self->hash, MESSAGES=>\@messages);
  }

  if ($self->is_new and $requestor_uid != $task_uid)
  {
    $self->{GLOBAL}->{MESSENGER}->notify($task_uid, "Task Added", "Tasks/mail/update", $self->hash, IS_NEW=>$self->is_new, MESSAGES=>\@messages);
  } elsif ($session_uid == $requestor_uid and $requestor_uid != $task_uid) { # Requestor, and not own task.
    $self->{GLOBAL}->{MESSENGER}->notify($task_uid, "Task Updated", "Tasks/mail/update", $self->hash, MESSAGES=>\@messages);
  } elsif ($task_uid == $session_uid and $session_uid != $requestor_uid) { # Owner, will notify requestor (if not self).
    my $custom_notify = $self->{GLOBAL}->{META}->{NOTIFY_FIELDS};
    my @custom_notify = ref $custom_notify eq 'ARRAY' ? @$custom_notify : ();
    if (not $custom_notify or grep { $self->has_changed($_) } @custom_notify)
    # Notification of task changing is unconditional (ANY FIELD CHANGE) when NOTIFY_FIELDS is empty ('[]')
    {
      $self->{GLOBAL}->{MESSENGER}->notify($requestor_uid, "Task Updated", "Tasks/mail/update", $self->hash, MESSAGES=>\@messages);
    }
  }

  # Now notify project manager if task's dates go past milestone's
  my $pid = $self->get("PID");
  my $mid = $self->get("MID");
  my $task_due_date = $self->get("DUEDATE");
  my $task_estcomdate = $self->get("ESTCOMDATE");

  if ($self->all_defined("MID", "PID"))
  {
    my $mend_date = $self->get("MILESTONE{ENDDATE}");
    my $pend_date = $self->get("PROJECT{ENDDATE}");
    my $pmuid = $self->get("PROJECT{PMUID}");
    if ($mend_date ne '' and $mend_date < $task_due_date and $self->{GLOBAL}->{META}->{NOTIFY_TASK_EXCEED_PROJECT})
    {
      $self->{GLOBAL}->{MESSENGER}->notify($pmuid, "Task Due Date Exceeds Milestone End Date", "Tasks/mail/update", $self->hash);
    } 
    elsif ($mend_date ne '' and $mend_date < $task_estcomdate and $self->{GLOBAL}->{META}->{NOTIFY_TASK_EXCEED_PROJECT}) 
    {
      $self->{GLOBAL}->{MESSENGER}->notify($pmuid, "Task Estimated Completion Date Exceeds Milestone End Date", "Tasks/mail/update", $self->hash);
    }
  } elsif ($self->defined("PID")) { # Floating task
    my $project = Project->search(PID=>$pid);
    my $pmuid = $project->get("PMUID");
    my $pend_date = $project->get("ENDDATE");
    if ($pend_date ne '' and $pend_date < $task_due_date and $pmuid ne '' and $self->{GLOBAL}->{META}->{NOTIFY_TASK_EXCEED_PROJECT})
    {
      $self->{GLOBAL}->{MESSENGER}->notify($pmuid, "Task Due Date Exceeds Milestone End Date", "Tasks/mail/update", $self->hash);
    } 
    elsif ($pend_date ne '' and $pend_date < $task_estcomdate and $pmuid ne '' and $self->{GLOBAL}->{META}->{NOTIFY_TASK_EXCEED_PROJECT}) 
    {
      $self->{GLOBAL}->{MESSENGER}->notify($pmuid, "Task Estimated Completion Date Exceeds Milestone End Date", "Tasks/mail/update", $self->hash);
    }
  }
}

sub bulk_change
{
  my ($self, %form) = @_;
  %form = map { my $k = $_; s/^bulk_//i; ($_, $form{$k}) } keys %form;

    my @keys = qw(PRIORITY TCID PROD_ID STATUS STARTDATE DUEDATE REL_STARTDATE REL_DUEDATE REL_STARTDATE_UNIT REL_DUEDATE_UNIT UID MID);
    my %changes = ();
    foreach my $key (@keys)
    {
      my $value = $form{$key};
      if ($value ne '')
      {
        print STDERR "KEY=$key\n";
        $changes{$key} = $value;
      }
    }

    return ("No changes to perform.") unless %changes;

    for($self->first; $self->more; $self->next)
    {
      my $tid = $self->get("TID");
      if ($changes{MID})
      {
        if ($changes{MID_ACTION} eq 'rm') # Remove.
	{
	  my $link = TaskLink->search(TID=>$tid, MID=>$changes{MID});
	  $link->delete if $link->count;
	} else { # Add, default.
	  my $link = TaskLink->search(TID=>$tid, MID=>$changes{MID});
	  $link->commit(MID=>$changes{MID}, TID=>$tid);
	}
      }
      # Have to guess if completing/canceling and info not already there.
      if ($changes{STATUS} >= 10)
      {
        if (not $self->get("ACTCOMDATE"))
	{
          my ($s, $min, $h, $d, $mon, $y) = localtime();
          $changes{ACTCOMDATE} = sprintf "%04u-%02u-%02u", $y+1900, $mon+1, $d;
	}
	if ($changes{STATUS} >= 20 and $self->get("ACTHOURS") eq '')  # Completed
	{
	  $changes{ACTHOURS} = $self->get("ESTHOURS") || "0";
	}
      }

      # Relative date changes.
      if ($changes{REL_STARTDATE})
      {
        my $startdate = $self->get("STARTDATE");
	if ($startdate)
	{
	  my $count = $changes{REL_STARTDATE} * ($changes{REL_STARTDATE_UNIT}||1);
	  print STDERR "REL_START=$changes{REL_STARTDATE}, UNIT=$changes{REL_STARTDATE_UNIT}, COUNT=$count\n";
	  $changes{STARTDATE} = Calendar->date(
	    Calendar->date_in_secs($startdate) + Calendar->day($count)
	    );
	}
      }

      if ($changes{REL_DUEDATE})
      {
        my $duedate = $self->get("DUEDATE");
	if ($duedate)
	{
	  my $count = $changes{REL_DUEDATE} * ($changes{REL_DUEDATE_UNIT}||1);
	  print STDERR "REL_DUE=$changes{REL_DUEDATE}, UNIT=$changes{REL_DUEDATE_UNIT}, COUNT=$count\n";
	  $changes{DUEDATE} = Calendar->date(
	    Calendar->date_in_secs($duedate) + Calendar->day($count)
	    );
	}

      }

      #
      $self->commit(%changes);
      my $tid = $self->get("TID");
      my $task_link = TaskLink->search(TID=>$tid, ["MID IS NOT NULL AND PTID IS NULL"]);

    # Synchronize data with milestones.

      my $mile = Milestone->search(Milestone->col_in(MID=>$task_link->get_all("MID")));
      $mile->sync_stats(); # Does it for EVERY one, as we also reset the data

      my $projects = Project->search(Project->col_in(PID=>$mile->get_all("PID")));
      $projects->sync_stats();

    }


    return undef; # OK
}



1;
