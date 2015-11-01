#!/usr/bin/perl

my $cgi = TaskCGI->new(PATH_INFO_KEYS=>[qw(mode)],DBO=>1);

package TaskCGI;
use lib "../lib";
use base "TMCGI";
use MalyTemplate;
use Data::Dumper;
use MIME::Base64;
use Time::Local 'timelocal_nocheck';
use Task;
use TaskLink;
use Notes;
use TaskCommon;
use User;
use Project;
use Milestone;
use Participants;
use Product;
use Participants;
use Group;
use GroupMembership;

sub process
{
  my ($self, $action) = @_;
  my $mode = $self->get_path_info_or_default("mode", "Search");
  my $id = $self->get("tid");
  my $task = Task->new();
  my $now = $self->sql_datetime_from_secs();
  my $session_uid = $self->session_get("UID");
  my $mid = $self->get("MID");
  my $pid = $self->get("PID");
  my $project_uid = undef;
  my $inline = $self->get("inline");
  my %hash = $self->get_smart_hash;
  my %raw_hash = $self->get_raw_hash;

  my %old = ();
  my %new = ();

  if ($id ne '')
  {
    $task->search(TID=>$id);
    $self->user_error("No such task.", "Javascript:window.close();") unless $task->count;
  }

  if ($action eq 'DELETE TASK' and $id ne '')
  {
    $task->search(["(TID = $id OR PTID = $id)"]);
    $self->user_error("Permission Denied. Only the requestor of a task can delete it.") unless ($task->get("REQUESTOR_UID") == $session_uid and $session_uid ne '');

    for($task->first; $task->more; $task->next)
    {
      my $tid = $task->get("TID");

      # Get rid of task notes.
      my $notes = Notes->search(TID=>$tid);
      $notes->delete();

      my $former_mid = $task->get("MID");

      # Get rid of task.
      $task->delete();

      # Clean up other tasks #'s in milestone
      if ($former_mid ne '')
      {
        my $former_milestone_tasks = Task->search(MID=>$former_mid);
        $former_milestone_tasks->commit_sorted_list("MTID");
      }
    }
    $self->template_display("Tasks/task_deleted");
  }
  elsif ($action eq 'Add')
  {

    $self->system_error("Cannot add tasks, maximum number in database reached ($self->{LICENSE}->{TASKS}). Please upgrade licenses at http://www.malysoft.com/")
      if ($self->{LICENSE}->{TASKS} != -1 and Task->search_cols("COUNT(*)+1 AS TOTAL")->get("TOTAL") > $self->{LICENSE}->{TASKS});

    $task->set("REQUESTOR_UID", $session_uid);
    my $msg = $task->save(%hash);
    $self->user_error($msg) if $msg;
  } 
  elsif ($action eq 'Save')
  {
    my $msg = $task->save(%hash); # May or may not handle adding tasks as well. (PROLLY WILL)
    $self->user_error($msg) if $msg;
  }

  if ($mid ne '' and $inline)
  {
    $self->redirect("cgi-bin/Projects.pl/Edit?pid=$pid");
  }

  # Redirect to self after processing! Since milestone edit will repeate form submit
  $self->redirect("$self->{GLOBAL}->{PATHINFO_URL}?tid=$id&saved=1") if $action eq 'Save';

  if ($action eq 'Add') { $self->redirect("cgi-bin/Tasks.pl/Edit?link_field=".$self->get("LINK_FIELD")."&task_added=1&tid=".$task->get("TID")); }
  elsif ($mode =~ /^(Edit|Add)$/) { $self->display_edit($mode, $id); }
  elsif ($mode eq 'Search') { $self->display_search(); }
  else { $self->display_browse(); }
}




sub should_log
{
  my ($self, $field, $task) = @_;
  my $log_fields = $self->{GLOBAL}->{META}->{LOG_FIELDS};
  my @log_fields = ref $log_fields eq 'ARRAY' ? @$log_fields : ();
  return ($task->has_changed($field) and grep { $_ eq $field } @log_fields);
}

sub display_edit
{
  my ($self, $mode, $id) = @_;
  my $task = undef;
  my $session_uid = $self->session_get("UID");
  #my $siteadmin = $self->session_get("SITEADMIN");
  
  my $parent_task = Task->new();
  my $ptid = $self->get("PTID");
  my $mid = $self->get("MID");

  if ($mode eq 'Edit')
  {
    $self->user_error("No Task specified.", "Javascript:window.close();") unless $id =~ /./;
    $task = Task->search(TID=>$id)->result
      or $self->internal_error("Could not find task # $id", "Javascript:window.close();");

  } else {

    $self->system_error("Cannot add tasks, maximum number in database reached ($self->{LICENSE}->{TASKS}). Please upgrade licenses at http://www.malysoft.com/")
      if ($self->{LICENSE}->{TASKS} != -1 and Task->search_cols("COUNT(*)+1 AS TOTAL")->get("TOTAL") > $self->{LICENSE}->{TASKS});

    $task = Task->new();
    if ($ptid ne '')
    {
      $parent_task->search(TID=>$ptid);

      # If adding, we should set certain things in self!!! dont let html do it!
      # XXX TODO ALSO MAKE SURE THAT UPDATING TGROUP_IDS WILL SYNC TGROUPS!!! FIXME TODO XXX

      my %sync_hash =
        $parent_task->get_hash(
	  qw(STARTDATE DUEDATE UID TCID PROD_ID PRIORITY)
	);
      $task->set(%sync_hash);
      # Copy miles over too.
      my $mile_link = $task->get("TGROUP_IDS") || TaskLink->new();
      my $pm_ids = $parent_task->get("TGROUP_IDS");
      for ($pm_ids->first; $pm_ids->more; $pm_ids->next)
      {
        $mile_link->set(MID=>$pm_ids->get("MID"));
      }
      $task->set("TGROUP_IDS", $mile_link);
    }

    if ($mid ne '') # Mile inherit.
    {
      my $mile = Milestone->search(MID=>$mid);
      my $prod_id = $mile->get("PROJECT{PROD_ID}");
      my $startdate = $mile->get("STARTDATE");
      my $duedate = $mile->get("ENDDATE");
      my $mile_link = $task->get("TGROUP_IDS") || TaskLink->new();
      $mile_link->set(MID=>$mid);
      $task->set(PROD_ID=>$prod_id, STARTDATE=>$startdate, DUEDATE=>$duedate, TGROUP_IDS=>$mile_link);
      my $tg = $task->get("TGROUP_IDS");
    }
    $task->set($self->get_hash); # Form takes precedence over parent task.
  }

  my $pid = $task->get("PID") || $self->get("PID");
  my $prioritymap = $self->select_map($self->{VARS}->{PRIORITYMAP}, 1);
  my $statusmap = $self->select_map($self->{VARS}->{STATUSMAP}, 1);
  my $percentmap = [ (0,10,20,30,40,50,60,70,80,90,100) ];
  my $projects = Project->new();
  my $milestones = Milestone->new();
  #if ($pid ne '')
  #{
  #  $milestones->search(PID=>$pid);
  #}
  my $project_participants = Participants->new();
  $project_participants->search(UID=>$session_uid);
  my $pid_list = join(",", $project_participants->get_all("PID"));
  $pid_list = "NULL" if $pid_list eq '';
  $projects->search_cols("pid, title", ["(PMUID = '$session_uid' OR PID IN ($pid_list) )"]);

  my $products = Product->search();

  my $all_project_tasks = Task->new;
  my $project_participants = Participants->new();
  my $users_in_this_project = User->new();


  if ($pid ne '')
  {
    my @search_params = (PID=>$pid);
    my $dependencies = $task->get("DEPENDENCIES");
    if (ref $dependencies)
    {
      my @deps = $dependencies->get_all("TID");
      push @search_params, (Task->col_not_in("TID", $deps)) if @deps; 
    }
    $all_project_tasks->search(@search_params);
    $project_participants->search(PID=>$pid);
    $users_in_this_project->search(User->col_in("UID", $project_participants->get_all("UID")));
  }

  my $editable = $task->get("EDITABLE") || Task->get_editable_fields(1);

  # Now get the previous TID and next TID if in a milestone.

  my $mid = $task->get("MID");
  my $mtid = $task->get("MTID");
  my $prev_tid = undef;
  my $next_tid = undef;
  if ($mid ne '' and $mtid ne '')
  {
    # THIS IS BASED UPON MTID !!!
    $prev_tid = Task->search_cols('TID', MID=>$mid, ["MTID  = $mtid - 1"], ORDER=>'MTID',LIMIT=>1)->get("TID");
    $next_tid = Task->search_cols('TID', MID=>$mid, ["MTID = $mtid + 1"], ORDER=>'MTID',LIMIT=>1)->get("TID");
  }


  my $mile = $task->get("TGROUPS");
  my @pid = ();
  if ($mile and $mile->count)
  {
    @pid = $mile->get_all("PID");
  }

  my $available_owners = User->available_owners($session_uid, @pid);
  my $available_requestors = User->available_requestors($session_uid, @pid);
  my $available_participants = User->available_participants($session_uid, @pid);

  $self->template_display("Tasks/edit", TASK=>$task->hashref, 
    AVAILABLE_OWNERS=>$available_owners,
    AVAILABLE_REQUESTORS=>$available_requestors,
    AVAILABLE_PARTICIPANTS=>$available_participants,
    PARENT_TASK=>$parent_task,
    PREV_TID=>$prev_tid,
    NEXT_TID=>$next_tid,
    EDITABLE=>$editable,
    MODE=>$mode,
    PRIORITYSELMAP=>$prioritymap, STATUSSELMAP=>$statusmap,
    SESSIONUSER=>"Administrator", 
    #PROJECTS=>$projects,
    PRODUCTS=>$products,
    THIS_PROJECT_PARTICIPANTS=>$users_in_this_project,
    MILESTONES=>$milestones,
    REQUIRE_FIELDS=>$self->{GLOBAL}->{META}->{REQUIRE_FIELDS},
  );
}

sub template_display
{
  my ($self, @args) = @_;
  $self->SUPER::template_display(@args);
}

sub display_search
{
  my ($self) = @_;
  my $action = $self->get("ACTION");
  my $session_uid = $self->session_get("UID");
  my $siteadmin = $self->session_get("SITEADMIN");

  my $tasks = Task->new();
  my $search_submitted = undef;

  my @tasks = ();

  if ($action eq 'Change Tasks') # Bulk task change.
  {
    my %changes = $self->get_hash;
    my @tid = $self->get("BULK_TID");
    my $search_url = $self->get("SEARCH_URL");
    $self->user_error("No tasks selected") if not @tid;
    my $tasks = Task->search(Task->col_in(TID=>@tid));
    my $msg = $tasks->bulk_change(%changes);
    $self->user_error($msg) if $msg;

    $self->redirect($search_url) if $search_url;
  }
  elsif ($action eq 'Search') # Something was submitted. 
  {
    my @params = ();

    ## Group Category
    my $groupcat = $self->get("GID");
    my ($gid, $tcid) = split(",", $groupcat);

    if ($tcid ne '')
    {
      push @params, (TCID=>$tcid);
    }
    elsif ($gid ne '')
    {
      my $tcidlist = "NULL";
      my @tcids = TaskCategories->search(GID=>$gid)->get_all("TCID");
      $tcidlist = join(",", @tcids) if @tcids;
      push @params, (["TCID IN ($tcidlist)"]);
    }

    ## Product ID

    my $prod_id = $self->get("PROD_ID");
    if ($prod_id eq '-1') # No product.
    {
      push @params, (["(PROD_ID IS NULL OR PROD_ID = '')"]);
    }
    elsif ($prod_id ne '')
    {
      push @params, $prod_id !~ /:/ ? (["(PROD_ID LIKE '$prod_id:%')"]) : (PROD_ID=>$prod_id);
    }

    ## TASK ID
    my $tid = $self->get("TID");
    if ($tid ne '')
    {
      push @params, (TID=>$tid);
    }

    ## Parent task ID
    my $ptid = $self->get("PTID");
    if ($ptid ne '')
    {
      my $task_link = TaskLink->search(PTID=>$ptid);
      push @params, (Task->col_in("TID", $task_link->get_all("TID")));
    }

    ## Priority
    my $prio = $self->get("PRIORITY");
    if ($prio ne '')
    {
      push @params, (PRIORITY=>$prio);
    }

    ## Owner
    my $owner = $self->get("UID");
    if ($owner ne '')
    {
      if ($owner == -1) # Unassigned
      {
        push @params, (["(UID IS NULL OR UID = '')"]);
      } else {
        push @params, (UID=>$owner);
      }
    }

    my ($s, $min, $h, $d, $mon, $y) = localtime();
    my $today = sprintf "%04u-%02u-%02u", $y+1900, $mon+1, $d;

    ## Status
    my $status = $self->get("STATUS");
    if ($status ne '' and $tid eq '') # Ignore status if put in explicit task id.
    {
      if ($status == -1)
      {
        push @params, ["STATUS < 10"];
      } elsif ($status == -2) {
        push @params, ["DUEDATE <= '$today' AND STATUS < 10"];
      } else {
        push @params, (STATUS=>$status);
      }
    }

    ## Milestone/task group
    my $pidmid = $self->get("PIDMID");
    my ($pid, $mid) = split(":", $pidmid);
    if ($mid ne '')
    {
      if ($mid == -1) # No milestone/task group at all!
      {
	push @params, 
	(
	  TABLES=>"tasks LEFT JOIN task_link ON tasks.tid = task_link.tid",
	  ["task_link.tid IS NULL"],
	);
      } else {
        my $task_link = TaskLink->search(MID=>$mid);
        push @params, (Task->col_in(TID=>$task_link->get_all("TID")));
      }
    } elsif ($pid ne '') {
      my $miles = Milestone->search_cols('MID', PID=>$pid);
      my $task_link = TaskLink->search(TaskLink->col_in(MID=>$miles->get_all("MID")));
      push @params, (Task->col_in(TID=>$task_link->get_all("TID")));
    }

    ## Text (Check title, description, AND notes....)
    my $text = $self->get("TEXT");
    if ($text ne '')
    {
      $text =~ s/(["'])/$1$1/g;
      my $note_tidlist = "NULL";
      my @note_tids = Notes->search_cols("TID", ["TEXT REGEXP '$text'", "TID IS NOT NULL"])->get_all("TID");
      $note_tidlist = join(",", @note_tids) if @note_tids;
      push @params, (["(TITLE REGEXP '$text' OR DESCRIPTION REGEXP '$text' OR TID IN ($note_tidlist))"]);
    }

    # Work time....
    my $time_count = $self->get("TIME_COUNT");
    my $time_unit = $self->get("TIME_UNIT");
    my $time_type = $self->get("TIME_TYPE");

    if ($time_count ne '')
    {
      my $time_hours = $time_count / ($time_unit||1);
      if ($time_type eq 'remain')
      {
        push @params, (["( (HOURS <= ESTHOURS) AND (ESTHOURS - HOURS) <= $time_hours )"]);
      } elsif ($time_type eq 'total') {
        push @params, (["(ESTHOURS BETWEEN 0 AND $time_hours)"]);
      }
    }

    ## DATES....

    my $date_vector = $self->get("DATE_VECTOR");
    my $date1 = $self->get("DATE1");
    my $date2 = $self->get("DATE2");
    my $date1span = $self->get("DATE1SPAN");
    my $date2span = $self->get("DATE2SPAN");

    # if only one provided, pretend like that was both.
    if (not $date1)
    {
      $date1 = $date2;
      $date1span = $date2span;
    } elsif (not $date2) {
      $date2 = $date1;
      $date2span = $date1span;
    }

    if ($date1 ne '' or $date2 ne '')
    {
      my $startsecs = $date1span eq 'week' ? 
        Calendar->start_of_week(Calendar->date_in_secs($date1)) :
	Calendar->date_in_secs($date1);

      my $endsecs = $date2span eq 'week' ? 
        Calendar->end_of_week(Calendar->date_in_secs($date2)) :
	Calendar->date_in_secs($date2);

      my $start_date = Calendar->date($startsecs);
      my $end_date = Calendar->date($endsecs);
      
      my $date_span = $self->get("DATE_SPAN");

      # As we may have DATETIME, we have to format it like DATE, for it to work.

      if ($date_vector eq 'during')
      {
	push @params, (["(STARTDATE <= '$end_date' AND DUEDATE >= '$start_date')"]);
      } elsif ($date_span eq 'between') {
        push @params, (["DATE_FORMAT($date_vector, '%Y-%m-%d') BETWEEN '$start_date' and '$end_date'"]);
      } elsif ($date_span eq 'before') {
        push @params, (["DATE_FORMAT($date_vector, '%Y-%m-%d') <= '$start_date'"]);
      } elsif ($date_span eq 'after') {
        push @params, (["DATE_FORMAT($date_vector, '%Y-%m-%d') >= '$start_date'"]);
      } elsif ($date_span eq 'on') {
        push @params, (["DATE_FORMAT($date_vector, '%Y-%m-%d') = '$start_date'"]);
      }
    }


    ## NOW, add implied permission check.
    # task owner, requestor, or manage owner/requestor (implicit or explicit)

    my $session_user = User->search(UID=>$session_uid);

    my $uidlist = $session_user->get_managed_uids();

    push @params, (["(UID IN ($uidlist) OR REQUESTOR_UID IN ($uidlist))"]) if not $siteadmin;

$tasks->{DEBUG} = 1;
    $tasks->search_cols('tasks.*', @params);
    $search_submitted = 1;






    # NOW handle the GROUPING, if enabled.
    my $group_by = $self->get("GROUP_BY");
    if ($group_by)
    {
      my $key = uc $group_by;
      my %groups = ();
      my @groups = ();
      my @named_groups = ();

      my $vars = TaskCommon->vars;

      for($tasks->first; $tasks->more; $tasks->next)
      {
        my $value = $tasks->get($key);
  	if ($key eq 'TGROUPS') # Handle differently, may duplicate tasks.
	{
	  my $tg = $value;
	  if (not ref $tg or $tg->count == 0) # Not in one at all.
	  {
	    if (ref $groups{none}->{LIST} eq 'ARRAY')
	    {
	      push @{ $groups{none}->{LIST} }, $tasks->hashref;
	    } else {
	      $groups{none} =
	      {
	        NAME=>'', # Don't give a name (i.e., show at bottom of list)
		LIST=>[ $tasks->hashref ],
	      };
	    }
	  }
	  next unless ref $tg;
	  for ($tg->first; $tg->more; $tg->next)
	  {
	    my $tgid = $tg->get("MID");
	    if (ref $groups{$tgid}->{LIST} eq 'ARRAY')
	    {
	      push @{ $groups{$tgid}->{LIST} }, $tasks->hashref;
	    } else {
	      my $summary = $tg->get("SUMMARY");
	      my $projtitle = $tg->get("PROJECT{TITLE}");
	      my $name = $projtitle ? "$projtitle: $summary" : $summary;

	      $groups{$tgid} =
	      {
	        NAME=>$name,
		ONCLICK=>"editMilestonePopup($tgid);",
		LIST=>[ $tasks->hashref ],
	      };
	    }
	  }
	} elsif ($key eq 'PID') {
	  my $tg = $tasks->get("TGROUPS");
	  for ($tg->first; $tg->more; $tg->next)
	  {
	    my $pid = $tg->get("PID");
	    my $ptitle = $tg->get("PROJECT{TITLE}");
	    
	    if ($pid eq '')
	    {
	      $pid = 'none';
	      $ptitle = '';
	    }
	    if (ref $groups{$pid}->{LIST} eq 'ARRAY' )
	    {
	      push @{ $groups{$pid}->{LIST} }, $tasks->hashref;
	    } else {
	      $groups{$pid} =
	      {
	        NAME=>$ptitle,
	        LIST=>[ $tasks->hashref ],
		ONCLICK=>"viewProjectPopup($pid);",
	      };
	    }
	  }
	} elsif ($key eq 'DUEWEEK') {
	  my $dueweek1 = Calendar->start_of_week($tasks->get("DUEDATE"));
	  my $dueweek2 = Calendar->end_of_week($tasks->get("DUEDATE"));
	  my $id = $dueweek1;
	  my $dueweek1name = Calendar->mdy_date($dueweek1);
	  my $dueweek2name = Calendar->mdy_date($dueweek2);
	  my $name = "$dueweek1name - $dueweek2name";
	  if ($dueweek1 eq '' or $dueweek2 eq '' or $dueweek1 <= 0 or $dueweek2 <= 0)
	  {
	    $id = 'none';
	    $name = '';
	  }
	  if (ref $groups{$id}->{LIST} eq 'ARRAY' )
	  {
	    push @{ $groups{$id}->{LIST} }, $tasks->hashref;
	  } else {
	    $groups{$id} =
	    {
	      NAME=>$name,
	      LIST=>[ $tasks->hashref ],
	    };
	  }
	} else {
	  if (ref $groups{$value}->{LIST} eq 'ARRAY')
	  {
	    push @{ $groups{$value}->{LIST} }, $tasks->hashref;
	  } else {
	    # Construct name!!!!
	    my $group_name = $value; # Default to literal.
	    if ($key eq 'UID')
	    {
	      $group_name = $tasks->get("OWNER{FULLNAME}");
	    } elsif ($key eq 'TCID') {
	      $group_name = $tasks->get("TASK_CATEGORY{NAME}");
	    } elsif ($key eq 'PID') {
	      $group_name = $tasks->get("PROJECT{TITLE}");
	    } elsif ($key eq 'PROD_ID') {
	      $group_name = Product->get_name($value);
	    } elsif ($key eq 'PRIORITY') {
	      $group_name = $vars->{PRIORITYMAP}->{$value};
	    } elsif ($key eq 'STATUS') {
	      $group_name = $vars->{STATUSMAP}->{$value};
    	    }
  
	    $groups{$value} = 
	    {
	      NAME=>$group_name,
	      LIST=>[ $tasks->hashref ],
	    };
	  }
	}
      }

      @groups = sort 
      { 
        return 1 if ($a->{NAME} eq '');
        return -1 if ($b->{NAME} eq '');
        return $a->{NAME} cmp $b->{NAME};
      } values %groups;

      @tasks = (TASK_GROUPS=>\@groups, COUNT=>$tasks->count);
    } else {
      @tasks = (TASKS=>$tasks->records_ref, COUNT=>$tasks->count);
    }
  }



  my $uidlist = "NULL";
  my $pidlist = "NULL";

  # Get all users can manage, etc....o
  my @uids = (
    $self->session_get("UID"),
  );

  my $m = $self->session_get("MANAGED");
  push @uids, $m->get_all("UID");

  my $mg = $self->session_get("MANAGED_GROUPS");
  for ($mg->first; $mg->more; $mg->next)
  {
    my $members = $mg->get("MEMBERS");
    push @uids, $members->get_all("UID");
  }

  my $g = $self->session_get("GROUPS");
  for ($g->first; $g->more; $g->next)
  {
    my $members = $g->get("MEMBERS");
    push @uids, $members->get_all("UID");
  }

  my %uidfound = ();
  my @uuids = grep { not $uidfound{$_}++ } sort @uids;

  $uidlist = join(",", @uuids) if @uuids;

  my $tgroups = $siteadmin ? Milestone->search_cols('MID, PID, SUMMARY') : Milestone->search_cols('MID, PID, SUMMARY', ["(UID IN ($uidlist))"]);
  my $products = Product->search();

  my $projects = Project->new();

  if ($siteadmin)
  {
    $projects->search_cols('PID, TITLE');
  } else {
    my $p = Participants->new();
    $p->search(["UID IN ($uidlist)"]);
    my @pidlist = $p->get_all("PID");

    $pidlist = join(",", @pidlist) if @pidlist;
    $projects->search_cols('PID, TITLE', ["(PMUID IN ($uidlist) OR PID IN ($pidlist))"]);
  }

  my $available_groups = Group->new();

  if (not $siteadmin)
  {
    my @gidlist = GroupMembership->search_cols("GID", UID=>$session_uid)->get_all("GID");
    my $gidlist = @gidlist ? join(",", @gidlist) : "NULL";
    $available_groups->add_params(["MANAGER_UID = '$session_uid' OR GID IN ($gidlist)"]);
  }

  $available_groups->search();

  my %form_data =
  (
    AVAILABLE_GROUPS=>$available_groups,
    TGROUPS=>$tgroups,
    PRODUCTS=>$products,
    PROJECTS=>$projects,
    AVAILABLE_REQUESTORS=>User->available_requestors($session_uid),
  );

  my $tmpl = $self->get("POPUP") ? "Tasks/search_popup" : "Tasks/search";
  $self->template_display($tmpl, %form_data, search=>1, search_submitted=>$search_submitted, @tasks);
}

sub display_browse
{
  my ($self) = @_;
  my $tasks = Task->new();

  my $tid = $self->get("tid");

  my $session_uid = $self->session_get("UID");
  $self->internal_error("Unable to retrieve account information.", "Javascript:window.close();") unless ($session_uid =~ /./);

  my $by_uid = $self->get("by_uid");
  if ($by_uid ne '' and $by_uid >= 0)
  {
    $tasks->search(UID=>$by_uid, ["STATUS < 10"]);
  } elsif ($by_uid == -2) { # Unassigned, self is requestor.
    $tasks->search(REQUESTOR_UID=>$session_uid, UID=>undef, ["STATUS < 10"]);
  } elsif ($by_uid == -1) { # ALL managed users (plus self, plus unassigned)
    my @managed = $self->session_get("MANAGED");
    my @managed_uids = map { $_->{UID} } @managed;
    push @managed_uids, $session_uid;
    my $mgr_uids = join(",", @managed_uids);
    $mgr_uids = "NULL" if $mgr_uids eq '';
    $tasks->search(["(UID IN ($mgr_uids) OR (UID IS NULL AND REQUESTOR_UID = $session_uid) )"], ["STATUS < 10"]);
  } elsif ($tid ne '') { # By task id
    $tasks->search(TID=>$tid);
  } else { # Just self.
    $tasks->search(UID=>$session_uid, ["STATUS < 10"]);
  }


  $self->template_display("Tasks/search", TASKS=>$tasks->records_ref, COUNT=>$tasks->count);

}

sub prepare_edit
{
  my ($self, $record) = @_;
  my $new = (!$record);
  my @notes_list = ();
  my ($s, $min, $h, $d, $mon, $y) = localtime();
  foreach my $note (reverse split /;/, $record->{NOTES})
  {
    my @note = split /:/, $note;
    my $user = User->search(UID=>$note[0])->hashref;
    my $timestamp = join ("<br>", split /\s/, $self->formatted_date_from_secs($note[1]));
    my $text = decode_base64($note[2]);
    my %note = (USER=>$user->{FULLNAME}, TIMESTAMP=>$timestamp, TEXT=>$text);
    push @notes_list, \%note;
  }
  $record->{NOTES_LIST} = [ @notes_list ];
  #$record->{STARTTIME} ||= "17:00";
  if ($new)
  {
    $record->{ENDTIME} ||= "17:00";
    $record->{ENDDATE} ||= sprintf("%4u-%02u-%02u", $y+1900, $mon+1, $d);
  }
  #$self->log("NOTES=".Dumper($record->{NOTES_LIST}));
  return $record;
}

1;
