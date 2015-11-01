#!/usr/bin/perl

my $cgi = MilestonesCGI->new(PATH_INFO_KEYS=>[qw(mode)],DBO=>1);

package MilestonesCGI;
use lib "../lib";
use base "TMCGI";
use Data::Dumper;
use Project;
use Task;
use TaskLink;
use TaskCommon;
use Milestone;
use Participants;
use Calendar;
use Dependency;
use Product;
use ProductVersion;

sub process
{
  my ($self, $action) = @_;
  my $mode = $self->get_path_info_or_default("mode", "Search"); # View, Edit, Search, Browse, etc...
  # View is printable version (no form, no look/feel, etc...
  my %form = $self->get_hash;
  my %raw_hash = $self->get_raw_hash;
  my $mid = $self->get("MID");
  my $add = ($mode eq 'Add');

  my $session_uid = $self->session_get("UID");
  my $mile = Milestone->new();

  if ($mode eq 'Browse')
  {
    my $by_uid = $self->get("by_uid");
    if ($by_uid ne '' and $by_uid >= 0)
    {
      $mile->search(UID=>$by_uid, ["STATUS < 10"]);
    } elsif ($by_uid == -2) { # Unassigned, self is requestor.
      $mile->search(REQUESTOR_UID=>$session_uid, UID=>undef, ["STATUS < 10"]);
    } elsif ($by_uid == -1) { # ALL managed users (plus self, plus unassigned)
      my @managed = $self->session_get("MANAGED");
      my @managed_uids = map { $_->{UID} } @managed;
      push @managed_uids, $session_uid;
      my $mgr_uids = join(",", @managed_uids);
      $mgr_uids = "NULL" if $mgr_uids eq '';
      $mile->search(["(REQUESTOR_UID = $session_uid OR UID IN ($mgr_uids))"], ["STATUS < 10"]);
    } else { # Just self.
      $mile->search(UID=>$session_uid, ["STATUS < 10"]);
    }
    $self->template_display("Milestones/search", MILES=>$mile, COUNT=>$mile->count);
  } elsif ($mode eq 'Search') {
    my $mile = Milestone->new();
    my $submitted = 0;
    my @miles = ();
    if ($action eq 'Change Task Groups') # Bulk task group change.
    {
      my %changes = $self->get_hash;
      my @mid = $self->get("BULK_MID");
      my $search_url = $self->get("SEARCH_URL");
      $self->user_error("No task groups/milestones selected") if not @mid;
      my $mile = Milestone->search(Milestone->col_in(MID=>@mid));
      my $msg = $mile->bulk_change(%changes);
      $self->user_error($msg) if $msg;
  
      $self->redirect($search_url) if $search_url;
    }
    elsif ($action eq 'Search')
    {
      my @params = ();
      # Add in condition to exclude milestones from task groups unless checkbox set.
      # but also need to mark task groups via TG=1, upon add, i.e., if PID is null.

      # Milestone ID
      my $mid = $self->get("MID");
      if ($mid ne '')
      {
        push @params, (MID=>$mid);
      }

      # Owner
      my $uid = $self->get("UID");
      if ($uid ne '')
      {
        push @params, (UID=>$uid);
      }

      # Project
      my $pid = $self->get("PID");
      if ($pid ne '' and $pid ne '-2')
      {
        $pid = undef if $pid == -1;
	push @params, (PID=>$pid);
      }

      # Status
      my $status = $self->get("STATUS");
      if ($status ne '')
      {
        if ($status == -1)
        {
          push @params, ["STATUS < 10"];
        } else {
          push @params, (STATUS=>$status);
        }
      }

      # Priority
      my $priority = $self->get("PRIORITY");
      if ($priority ne '')
      {
        push @params, (PRIORITY=>$priority);
      }

      ## Text (summary, description AND notes ....)

      my $text = $self->get("TEXT");
      if ($text ne '')
      {
        $text =~ s/(["'])/$1$1/g;
        my $note_midlist = "NULL";
        my @note_mids = Notes->search_cols("MID", ["TEXT REGEXP '$text'", "MID IS NOT NULL"])->get_all("MID");
        $note_midlist = join(",", @note_mids) if @note_mids;
        push @params, (["(SUMMARY REGEXP '$text' OR DESCRIPTION REGEXP '$text' OR MID IN ($note_midlist))"]);
      }

      # Dates.
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
  
        if ($date_vector eq 'started')
        {
          push @params, (["STARTDATE BETWEEN '$start_date' AND '$end_date'"]);
        } 
        elsif ($date_vector eq 'due')
        {
          push @params, (["ENDDATE BETWEEN '$start_date' AND '$end_date'"]);
        } else { # Worked on.
  	push @params, (["(STARTDATE <= '$end_date' AND ENDDATE >= '$start_date')"]);
        }
      }

      # Now check against product. i.e., that of project!
      my $prod_id = $self->get("PROD_ID");
      if ($prod_id ne '')
      {
	if ($prod_id eq '-1') # No product!
	{
	  my $proj = Project->search_cols("PID", ["(PROD_ID IS NOT NULL)"]);
	  my @pid = $proj->get_all("PID");
	  my $pidlist = "NULL";
	  $pidlist = join(",", @pid) if @pid;
          push @params, (["(PID IS NULL OR PID NOT IN ($pidlist))"]);
	} else {
          my $proj = Project->search_cols("PID", 
            $prod_id !~ /:/ ? (["(PROD_ID LIKE '$prod_id:%')"]) : (PROD_ID=>$prod_id)
	    );
	  push @params, (Milestone->col_in(PID=>$proj->get_all("PID")));
	}
      }

      # Now implement what have access to....
      my $session_user = User->search(UID=>$session_uid);
      my $uidlist = $session_user->get_managed_uids();

      push @params, (["(UID IN ($uidlist))"]) if not $siteadmin;
      
      $mile->search(@params); # For now, get all.
      $submitted = 1;

      # NOW handle the GROUPING, if enabled.
      my $group_by = $self->get("GROUP_BY");

      if ($group_by)
      {
        my $key = uc $group_by;
        my %groups = ();
        my @groups = ();
        my @named_groups = ();
  
        my $vars = TaskCommon->vars;

	# product ( from project )
	# end week
  
        for($mile->first; $mile->more; $mile->next)
        {
          my $value = $mile->get($key);
	  $value = $mile->get("PROJECT{PROD_ID}") if $key eq 'PROD_ID';

  	if ($key eq 'ENDWEEK') {
  	  my $dueweek1 = Calendar->start_of_week($mile->get("ENDDATE"));
  	  my $dueweek2 = Calendar->end_of_week($mile->get("ENDDATE"));
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
  	    push @{ $groups{$id}->{LIST} }, $mile->hashref;
  	  } else {
  	    $groups{$id} =
  	    {
  	      NAME=>$name,
  	      LIST=>[ $mile->hashref ],
  	    };
  	  }
  	} else {
  	  if (ref $groups{$value}->{LIST} eq 'ARRAY')
  	  {
  	    push @{ $groups{$value}->{LIST} }, $mile->hashref;
  	  } else {
  	    # Construct name!!!!
  	    my $group_name = $value; # Default to literal.
	    my $group_onclick = undef;
  	    if ($key eq 'UID')
  	    {
  	      $group_name = $mile->get("OWNER{FULLNAME}");
  	    } elsif ($key eq 'PID') {
  	      $group_name = $mile->get("PROJECT{TITLE}");
	      $group_onclick = "viewProjectPopup($value);";
  	    } elsif ($key eq 'PROD_ID') {
  	      my ($prod_id, $ver_id) = split(":", $value);
  	      if ($prod_id ne '')
  	      {
  	        my $product = Product->search(PROD_ID=>$prod_id);
  	        $group_name = $product->get("NAME");
  	        if ($ver_id ne '')
  	        {
  	          my $version = ProductVersion->search(PROD_ID=>$prod_id, VER_ID=>$ver_id);
  		  my ($ver_name, $ver_alias) = $version->get("VER_NAME", "VER_ALIAS");
  		  $group_name .= " $ver_name ";
  		  $group_name .= "($ver_alias)" if ($ver_alias);
  	        }
  	      }
  	    } elsif ($key eq 'PRIORITY') {
  	      $group_name = $vars->{PRIORITYMAP}->{$value};
  	    } elsif ($key eq 'STATUS') {
  	      $group_name = $vars->{STATUSMAP}->{$value};
      	    }
    
  	    $groups{$value} = 
  	    {
  	      NAME=>$group_name,
	      ONCLICK=>$group_onclick,
  	      LIST=>[ $mile->hashref ],
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
  
        @miles = (MILE_GROUPS=>\@groups, COUNT=>$mile->count);
      } else {
        @miles = (MILES=>$mile->records_ref, COUNT=>$mile->count);
      }
    }


    my $session_user = User->search(UID=>$session_uid);
    my $uidlist = $session_user->get_managed_uids();

    my $pidlist = "NULL";

    my $p = Participants->new();
    $p->search(["UID IN ($uidlist)"]);
    my @pidlist = $p->get_all("PID");

    $pidlist = join(",", @pidlist) if @pidlist;

    my $all_projects = Project->new();
    $all_projects->search_cols('PID, TITLE', ["(PMUID IN ($uidlist) OR PID IN ($pidlist))"]);

    my %vars = 
    (
      SEARCH=>1,
      ALL_PROJECTS=>$all_projects,
      PRODUCTS=>Product->search(),
    );
    my $tmpl = $self->get("POPUP") ? "Milestones/search_popup" : "Milestones/search";
    $self->template_display($tmpl, @miles, SUBMITTED=>$submitted, %vars);
  } elsif ($mode eq 'Edit' or $mode eq 'Add') {
    $self->user_error("No task group/milestone specified", "Javascript:window.close();") if $mid eq '' and $mode eq 'Edit';

    $mile->search(MID=>$mid) if $mid ne '';

    $self->user_error("No such milestone / task group.", "Javascript:window.close();") if $mid ne '' and not $mile->count;

    if ($action)
    {
      my $tid = $self->get("TID");
      my $pid = $self->get("PID");
      if ($action eq 'Link' and $pid ne '' and $mile->count) # Adding mile to project
      {
        $mile->commit(PID=>$pid);
        $self->redirect("cgi-bin/Projects.pl/View?pid=$pid");
      }
      elsif ($action eq 'Link' and $tid ne '' and $mile->count) # Adding task to task group
      {
        my $task_link = $mile->get("TASK_IDS");
	$task_link->{DEBUG} = 1;
	my $found = 0;
	for ($task_link->first; $task_link->more; $task_link->next)
	{
	  if ($task_link->get("TID") eq $tid)
	  {
	    $found = 1;
	    last;
	  }
	}
	$task_link->append->commit(MID=>$mid, TID=>$tid) if not $found;
	# Might need to refresh 'TASKS'!!!
      } elsif ($action eq 'Save') { # Milestone info, task ordering, etc...
	#$mile->commit_sorted_list("PMID", %form);
	if ($mile->is_new and $form{UID} eq '') # Set owner to self.
	{
	  $form{UID} = $session_uid;
	}
	$form{REQUESTOR_UID} = $session_uid if $mile->is_new;
	$mile->commit(%form); # I.e., changes to it's info.
	$mid = $mile->get("MID");
	my $task_link = TaskLink->new();

	$mile->add_note($form{NOTES}) if ($form{NOTES});

        # FIX!!!
	if (! $mile->is_new)
	{
	  # Now save ntid ordering associated with tasks
	  $task_link->search(MID=>$mid);
	  my @tid = $self->get("TID");
	  my @ntid = $self->get("NTID");
	  my %tid_ntid_map = map { ($tid[$_], $ntid[$_]) } (0..$#tid);
	  for ($task_link->first; $task_link->more; $task_link->next)
	  {
	    my $tid = $task_link->get("TID");
	    my $ntid = $tid_ntid_map{$tid};
	    $task_link->set(NTID=>$ntid);
	  }
	  $task_link->multi_commit_sorted_list("NTID");
	}
        $self->redirect("cgi-bin/TaskGroups.pl/Edit?mid=$mid&link_field=$form{LINK_FIELD}&saved=1&added=".$mile->is_new);
	# So closing popups dont re-submit updates.
      } elsif ($mile->count and $action eq 'Remove from Project') { # Removing PID
        $mile->commit(PID=>undef);
      } elsif ($mile->count and $action eq 'Delete') { # Removing milestone....
	my $task_ids = $mile->get("TASK_IDS");
	$mile->delete();
	if (ref $task_ids) # Move tasks to bottom of page (no-milestone list)
	{
	  for($task_ids->first; $task_ids->more; $task_ids->next)
	  {
	    $task_ids->delete();
	  }
	}
	$self->template_display("Milestones/deleted");
      }
    }

    # Now, get tasks in order they should be in!


    my $tasks = $mile->get("TASKS");
    my @unsorted_tasks = $tasks->records if ref $tasks;

    # CAN HAVE DEP LOOPS!!!
    # May need to write own sort algorithm from scratch.

    # Create a dep chain for each task that has a dependency.
    # within that chain, sort 
    #

    # If we get tasks in groups based upon dependency chains,
    # We have a strict order.

    # We THEN know not to re-arrange THEIR order. I.e., we can set a flag in them.

    # BUT we may come across tasks being compared against themselves.
    # perhaps we can just return 0, and then remove duplicate tasks
    # (i.e., remove all but the first one).



    # Perhaps group tasks into dependency chains.
    # Then within each chain, sort based upon NTID
    #
   

    #############################
    #
    # If a task has no parent or subtasks, it can be sorted purely by task info.
    # OTHERWISE,
    # 
    # if they have the same parent task, base upon NTID
    # if they have a different parent task, 
    # if have no parent tasks, but have subtasks, 
    # If one has parent task and one has subtasks, 
    #
    #  BLAH!!!!!!!!!!!!111
    #
    #
    #################################
    #
    # Perhaps would require multi-level sorting, starting at the level of tasks with no parent tasks.
    # then once those set of tasks are sorted, ??????
    #
    #
    #
    #
    
    # sort based upon task information.
    # 
    # Now, loop over every task. if has a parent task,
    # 	it has to move before the parent task, but how far before depends upon task info and if any of THE OTHER
    #	tasks have dependencies or not.....
    # BLAH!!!!!!!11
    # 
    #
    ###########################

    #my @tasks = task_sort(@unsorted_tasks);
    my @tasks = sort task_info_sort @unsorted_tasks;

    my $editable = $mile->get("EDITABLE") || Milestone->get_editable_fields(1);

    $self->template_display("Milestones/edit", MILESTONE=>$mile->hashref, TASKS=>\@tasks, ADDED=>$mile->is_new, EDITABLE=>$editable);
    # Might need to add project related stuff later on...
  }


}

sub task_sort
{
  my (@tasks) = @_;

  # Get independent tasks.
  my @other_tasks = grep
  {
    not (grep { my $st = $_; grep { $st->{PTID} == $_->{TID} } @tasks } $_->{SUBTASK_IDS}->records)
    ||
    not (grep { my $pt = $_; grep { $pt->{TID} == $_->{TID} } @tasks } $_->{PARENT_IDS}->records)
  } @tasks;

  my @deptasks = grep { my $t = $_; not grep { $t->{TID} == $_->{TID}  } @other_tasks } @tasks;

  my @sorted_tasks = ();


  # Need to get absolute highest parents. Watch out for dep loops (even indirect)!
  # Not quite sure what will happen to dep loops.
  # Seems like tasks will be ignored?
  # Perhaps we should force all other dep-related tasks not covered (i.e., in the end, 'SORTED')
  # To be added to the other_tasks list.
  my @parent_tasks = grep
  {
    not (grep { my $pt = $_; grep { $pt->{TID} == $_->{TID} } @tasks } $_->{PARENT_IDS}->records)
  } @deptasks;


  # Generate TREE.

  my @tree = generate_tree(\@deptasks, \@parent_tasks);

# Start with the highest level of parent tasks. sort based upon task info. watch out for dep loop
# then for each one of those tasks (starting from the earliest), get it's subtasks and sort against
# all tasks prior (including previous parent tasks at the same level as it's parent). MARK the subtasks
# as 'SORTED', so when generate any further lists of subtasks, will skip in list to sort.
#
# After all iterations are done, any tasks not involved in dependencies are added to the list to sort,
# purely by task information.
#
#
#

  my @sorted_tasks = ();

  for (my $i = 0; $i < @tree; $i++)
  {
    my $branch = $tree[$i];
    my @branch = ref $branch eq 'ARRAY' ? @$branch : ();
    
    @sorted_tasks = sort task_info_sort (@branch, @sorted_tasks);

    # Now, go through newly sorted list, and get those from this branch.
    # Within each of those, get the subtasks, and sort against ALL prior tasks in list.

    foreach my $branch_task (@branch)
    {
      my ($ix) = grep { $branch_task->{TID} == $sorted_tasks->[$_]->{TID} } (0..$#sorted_tasks);
      my @prev_tasks = $ix > 1 ? @sorted_tasks[0..$ix-1] : ();
      my @post_tasks = $ix <= $#sorted_tasks ? @sorted_tasks[$ix..$#sorted_tasks] : ();

      my @child_tasks = grep { my $t = $_; not $t->{SORTED} and grep { $t->{TID} == $_->{TID} } $branch_task->{SUBTASK_IDS}->records; } @tasks;
      # Skip child tasks already sorted.
      # Need to make sure that a child task gets put in the earliest spot that it is considered
      # to be in. i.e., does this involve setting the SORTED flag or not?
      # Since we are starting from the top first. probably should not involve a flag,
      # but should somehow prevent task from appearing multiple times in list.
      # 
      # it COULD be as easy as just removing any extra copies, but what if the extra copies
      # involve some sort of dependencies (or NTID having something prior?)
      # hmmm....

      @sorted_tasks = sort task_info_sort(@prev_tasks), @post_tasks;
    }
  }

  # Now, go through @deptasks and find those not sorted. Treat like not in dependency chain at all
  # I.e., those with dep loops!

  # Now, sort other tasks with dep tasks based upon date info (dont sort if both say 'SORTED')
  

  return @sorted_tasks;
}

sub generate_tree
{
  my ($tasks, $parents) = @_;
  my @tasks = ref $tasks eq 'ARRAY' ? @$tasks : ();
  my @parents = ref $tasks eq 'ARRAY' ? @$tasks : ();

  my @node = ();
  push @node, @parents;
  # Now get children, and add to list.

  foreach my $parent (@parents)
  {
    my @subtasks = grep { my $t = $_; grep { $t->{TID} == $_->{TID} } $parent->{SUBTASK_IDS}->records } @tasks;
    push @node, generate_tree($tasks, \@subtasks);
  }
  
  return @node;
}

sub task_info_sort
{
  my $astart = $a->{STARTDATE};
  my $bstart = $b->{STARTDATE};
  my $startcmp = Calendar->date_in_secs($astart) <=> Calendar->date_in_secs($bstart);
  return $startcmp if $startcmp != 0;

  my $aprio = $a->{PRIORITY};
  my $bprio = $a->{PRIORITY};
  my $priocmp = $aprio <=> $bprio;
  return $priocmp if $priocmp != 0;

  my $aend = $a->{DUEDATE};
  my $bend = $b->{DUEDATE};
  my $endcmp = Calendar->date_in_secs($aend) <=> Calendar->date_in_secs($bend);
  return $endcmp if $endcmp != 0;

  my $aper = $a->{PERCENT};
  my $bper = $b->{PERCENT};

  return $bper <=> $aper; # Want the higher percent to come first.
}

