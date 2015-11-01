#!/usr/bin/perl

my $cgi = ProjectsCGI->new(PATH_INFO_KEYS=>[qw(mode)],DBO=>1);

package ProjectsCGI;
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
use Resources;

sub process
{
  my ($self, $action) = @_;
  my $pid = $self->get("PID");
  my $project = Project->new();
  my $mode = $self->get_path_info_or_default("mode", "Search"); # View, Edit, Search, Browse, etc...
  # View is printable version (no form, no look/feel, etc...
  my %form = $self->get_hash;
  my %raw_hash = $self->get_raw_hash;

  my $session_uid = $self->session_get("UID");

  if ($pid ne '')
  {
    $project->search(PID=>$pid);
    $self->user_error("No such project.", $mode eq 'Edit' ? 'Javascript:window.close();' : undef) unless $project->count;

  }

  if ($mode eq 'Edit' or $mode eq 'View' or $mode eq 'Add')
  {
    if ($mode eq 'Add')
    {
      $self->system_error("Cannot add project, maximum number in database reached ($self->{LICENSE}->{PROJECTS}). Please upgrade licenses at http://www.malysoft.com/")
        if ($self->{LICENSE}->{PROJECTS} != -1 and Project->search_cols("COUNT(*)+1 AS TOTAL")->get("TOTAL") > $self->{LICENSE}->{PROJECTS});
    }

    if ($action) # Do saving, etc... whatnot.
    {
      $self->user_error("Permission Denied", "Javascript:window.close();") unless ($project->is_new or $project->get("PMUID") == $session_uid);

      if ($action eq 'CANCEL THIS PROJECT') 
      {
	my $miles = Milestone->search(PID=>$pid);
	$miles->commit_all(PID=>undef);
        $project->delete;
	$self->redirect("cgi-bin/Projects.pl");
      }
      elsif ($action eq 'Update' or $action eq 'Add') # Do to project meta info at top
      {
	my $participants = $project->get("PARTICIPANT_UIDS") || Participants->new();
        my %form = $self->get_hash;
	my %hash = $self->get_smart_hash;
	$self->user_error("Title is required.") unless $form{TITLE};
	$project->commit(%form);
	$pid = $project->get("PID"); # In case of adding.

	# Take care of resources
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

          my $resources = $project->get("RESOURCES") || Resources->new();
          $resources->commit_list([PID=>$pid], undef, undef, RES_ID=>\@res_id, NAME=>\@name);
        } else { # Clear.
          Resources->search(PID=>$pid)->delete_all;
	}

	# Add participants
	my $pmuid = $self->get("PMUID");
	my @participants = $self->get("PARTICIPANT_IDS"), $pmuid;
	my @existing = ();
	# Get all existing.
	for ($participants->first; $participants->more; $participants->next)
	{
	  my $uid = $participants->get("UID");
	  if ($uid ne '' and grep { $uid == $_ } @participants)
	  {
	    push @existing, $uid;
	  } else { # Not found, it was removed from the form.
	    $participants->delete();
	  }
	}
	my @new = grep { $id=$_; $id ne '' and not grep { $id == $_ } @existing} @participants;
	foreach my $new (@new)
	{
	  $participants->append();
	  $participants->commit(PID=>$pid, UID=>$new);
	}
        $self->redirect("cgi-bin/Projects.pl/$mode?pid=$pid"); 
	# So closing popups dont re-submit updates.
      } 
      elsif ($action eq 'Save') # Milestones. New or existing.
      {
	my $milestones = $project->get("MILESTONES") || Milestone->new();
	$milestones->commit_sorted_list("PMID", %form);
	my $mid = $milestones->get("MID");
	my $task = Task->new();

	if (! $milestones->is_new)
	{
	  # Now save tasks associated with such.
          $task->search(MID=>$mid);
	  my @tid = $self->get("TID");
	  my @mtid = $self->get("MTID");
	  my %tid_mtid_map = map { ($tid[$_], $mtid[$_]) } (0..$#tid);
	  for ($task->first; $task->more; $task->next)
	  {
	    my $tid = $task->get("TID");
	    my $mtid = $tid_mtid_map{$tid};
	    $task->set(MTID=>$mtid);
	  }
	  $task->multi_commit_sorted_list("MTID");
	}
        $self->redirect("cgi-bin/Projects.pl/$mode?pid=$pid&edit_milestone=$mid"); 
	# So closing popups dont re-submit updates.
      }
      elsif ($action eq 'Delete Milestone') # Removing milestone.
      {
        my $mid = $self->get("MID");
	my $milestone = Milestone->search(MID=>$mid);
	my $tasks = $milestone->get("TASKS");
	$milestone->delete();
	if (ref $tasks) # Move tasks to bottom of page (no-milestone list)
	{
	  for($tasks->first; $tasks->more; $tasks->next)
	  {
	    $tasks->commit(MTID=>undef,MID=>undef);
	  }
	}
	$self->template_display("Projects/milestone_deleted");
      }
      #$project->refresh();
    }

    if ($form{EDIT_MILESTONE} ne '' or $form{ADD_MILESTONE} ne '')
    {
      my $milestone = Milestone->new();
      $milestone->search(MID=>$form{EDIT_MILESTONE}) if $form{EDIT_MILESTONE} ne '';
      my $milestone_count = Milestone->search_cols("count(*) AS COUNT", PID=>$pid)->get("COUNT");
      my $mid_pmid_map = Milestone->search_cols("MID,PMID", PID=>$pid)->records_ref;
      $self->template_display("Projects/milestone_edit", MILESTONE=>$milestone->hashref,
        MID_PMID_MAP=>$mid_pmid_map,
        MILESTONE_COUNT=>$milestone_count, PID=>$pid);
      #$project->hash); #MILESTONE=>$milestone->hash);#, ALL_USERS=>User->search);
    } elsif ($mode eq 'View') {
      my $tmpl = $self->get("POPUP") ? "Projects/view_popup" : "Projects/view";
      $self->template_display($tmpl, $project->hash, ALL_USERS=>User->search);
    } elsif ($mode eq 'Add' or $mode eq 'Edit') {

      my $available_owners = User->available_owners($session_uid, $pid);
      my $available_requestors = User->available_requestors($session_uid, $pid);

      $self->template_display("Projects/edit", $project->hash, 
        ALL_USERS=>User->search, PRODUCTS=>Product->search(),
        AVAILABLE_OWNERS=>$available_owners,
        AVAILABLE_REQUESTORS=>$available_requestors,
	);
    }
  } elsif ($mode eq 'Search') {

    my $session_user = User->search(UID=>$session_uid);
    my $uidlist = $session_user->get_managed_uids();

    my $pidlist = "NULL";

    my $p = Participants->new();
    $p->{DEBUG} = 1;
    $p->search(["UID IN ($uidlist)"]);
    my @pidlist = $p->get_all("PID");

    $pidlist = join(",", @pidlist) if @pidlist;

    my $all_projects = Project->new();
	    $all_projects->search(["(PMUID IN ($uidlist) OR PID IN ($pidlist))"]);


	    ### Now lets do search if asked for.
	    my $action  = $self->get("ACTION");
	    my $submitted = 0;
	    if ($action eq 'Search')
	    {
	      # Gather parameters.
	      my @params = ();

	      # Project name
	      my $pid = $self->get("PID");
	      if ($pid ne '')
	      {
		push @params, (PID=>$pid);
	      }

	      # Project Manager
	      my $pmuid = $self->get("PMUID");
	      if ($pmuid ne '')
	      {
		push @params, (PMUID=>$pmuid);
	      }

	      # Project Participant
	      my $participant_uid = $self->get("PARTICIPANT_UID");
	      if ($participant_uid ne '')
	      {
		my $party_pidlist = "NULL";
		my @party_pidlist = Participants->search(UID=>$participant_uid)->get_all("PID");
		$party_pidlist = join(",", @party_pidlist) if @party_pidlist;
		push @params, (["PID IN ($party_pidlist)"]);
	      }

	      # Status
	      my $status = $self->get("STATUS");
	      if ($status ne '')
	      {
		if ($status == -1) # Active. < 10 !
		{
		  push @params, (["STATUS < 10"]);
		} else {
		  push @params, (STATUS => $status);
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

	      # Product.
	      my $prod_id = $self->get("PROD_ID");
              if ($prod_id eq '-1') # No product.
              {
                push @params, (["(PROD_ID IS NULL OR PROD_ID = '')"]);
              }
              elsif ($prod_id ne '')
              {
                push @params, $prod_id !~ /:/ ? (["(PROD_ID LIKE '$prod_id:%')"]) : (PROD_ID=>$prod_id);
              }

	      # Add restrictions based upon who we are....
	      push @params, ["(PMUID IN ($uidlist) OR PID IN ($pidlist))"];


	      # NOW SEARCH

	      $project->search(@params);
	      $submitted = 1;
	    }

	    # Now do group by.
	    my $group_by = $self->get("GROUP_BY");
	    if ($group_by)
	    {
              my $key = uc $group_by;
              my %groups = ();
              my @groups = ();
              my @named_groups = ();
        
              my $vars = TaskCommon->vars;
        
              for($project->first; $project->more; $project->next)
              {
                my $value = $project->get($key);
		my $pid = $project->get("PID");
          	if ($key eq 'PARTY_UID') # Handle differently, may duplicate.
        	{
        	  my $party = $project->get("PARTICIPANTS");
        	  if (not ref $party or $party->count == 0) # Not in one at all.
        	  {
        	    if (ref $groups{none}->{LIST} eq 'ARRAY')
        	    {
        	      push @{ $groups{none}->{LIST} }, $project->hashref;
        	    } else {
        	      $groups{none} =
        	      {
        	        NAME=>'', # Don't give a name (i.e., show at bottom of list)
        		LIST=>[ $project->hashref ],
        	      };
        	    }
        	  }

		  # Now, get the display value.
        	  for ($party->first; $party->more; $party->next)
        	  {
		    my $uid = $party->get("UID");
        	    if (ref $groups{$uid}->{LIST} eq 'ARRAY')
        	    {
        	      push @{ $groups{$uid}->{LIST} }, $project->hashref;
        	    } else {
		      my $name = $party->get("FULLNAME");
        
        	      $groups{$uid} =
        	      {
        	        NAME=>$name,
        		ONCLICK=>"editUserPopup($uid);",
        		LIST=>[ $project->hashref ],
        	      };
        	    }
        	  }
        	} elsif ($key eq 'STARTWEEK') {
        	  my $startweek1 = Calendar->start_of_week($project->get("STARTDATE"));
        	  my $startweek2 = Calendar->end_of_week($project->get("STARTDATE"));
        	  my $id = $startweek1;
        	  my $startweek1name = Calendar->mdy_date($startweek1);
        	  my $startweek2name = Calendar->mdy_date($startweek2);
        	  my $name = "$startweek1name - $startweek2name";
        	  if ($startweek1 eq '' or $startweek2 eq '' or $startweek1 <= 0 or $startweek2 <= 0)
        	  {
        	    $id = 'none';
        	    $name = '';
        	  }
        	  if (ref $groups{$id}->{LIST} eq 'ARRAY' )
        	  {
        	    push @{ $groups{$id}->{LIST} }, $project->hashref;
        	  } else {
        	    $groups{$id} =
        	    {
        	      NAME=>$name,
        	      LIST=>[ $project->hashref ],
        	    };
        	  }
        	} elsif ($key eq 'ENDWEEK') {
        	  my $dueweek1 = Calendar->start_of_week($project->get("ENDDATE"));
        	  my $dueweek2 = Calendar->end_of_week($project->get("ENDDATE"));
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
        	    push @{ $groups{$id}->{LIST} }, $project->hashref;
        	  } else {
        	    $groups{$id} =
        	    {
        	      NAME=>$name,
        	      LIST=>[ $project->hashref ],
        	    };
        	  }
        	} else {
        	  if (ref $groups{$value}->{LIST} eq 'ARRAY')
        	  {
        	    push @{ $groups{$value}->{LIST} }, $project->hashref;
        	  } else {
        	    # Construct name!!!!
		    my $group_onclick = undef;
        	    my $group_name = $value; # Default to literal.
        	    if ($key eq 'PMUID')
        	    {
        	      $group_name = $project->get("MANAGER{FULLNAME}");
		      $group_onclick = "editUserPopup($value);";
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
        	      LIST=>[ $project->hashref ],
		      ONCLICK=>$group_onclick,
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
        
	      @projects = (PROJECT_GROUPS=>\@groups, COUNT=>$project->count);
	    } else {
	      @projects = (PROJECTS=>$project, COUNT=>$project->count);
	    }

	    my $tmpl = $self->get("POPUP") ? "Projects/search_popup" : "Projects/search";

	    $self->template_display($tmpl, ALL_PROJECTS=>$all_projects, @projects,
	      PRODUCTS=>Product->search(),
	      SUBMITTED=>$submitted);
  } else {
    # Exclude completed projects? (FROM DISPLAY)


    my $by_uid = $self->get("by_uid");
    if ($by_uid ne '' and $by_uid >= 0)
    {
      my $pidlist = "NULL";
      my @pidlist = Participants->search(UID=>$by_uid)->get_all("PID");
      $pidlist = join(",", @pidlist) if @pidlist;
      $project->search(["STATUS < 10"], ["PMUID = $by_uid OR PID IN ($pidlist)"]);
    } elsif ($by_uid == -1) { # ALL managed users (plus self)
      ##my $managed = $self->session_get("MANAGED");

      # ALTER GET SO WHEN WE ASK FOR ONE THING AND ITS A DBO AND WE ASSIGN IT TO AN ARRAY, DO RECORDS() !
      # Obviously records() can only return one dimension of pesudo records.

      #my @managed = $self->session_get("MANAGED");
      #my @managed_uids = map { $_->{UID} } @managed;
      #push @managed_uids, $session_uid;

      # self or managed is pmuid or party in project.
      #my $session_user = User->search(UID=>$session_uid);
      #my @managed_uid_list = $session_user->get_managed_uid_list();

      my $session_user = User->search(UID=>$session_uid);
      my $uidlist = $session_user->get_managed_uids();
      my $pidlist = "NULL";

      my $p = Participants->new();
      $p->search(["UID IN ($uidlist)"]);
      my @pidlist = $p->get_all("PID");

      $pidlist = join(",", @pidlist) if @pidlist;

      $project->search(["STATUS < 10"], ["(PMUID IN ($uidlist) OR PID IN ($pidlist))"]);
      
      #PMUID=>@managed_uids);

    } elsif ($pid ne '') { # By task id
      $project->search(PID=>$pid, ["STATUS < 10"]);
    } else { # Just self.
      my $pidlist = "NULL";
      my $projpart = Participants->search(UID=>$session_uid);
      my @pidlist = $projpart->get_all("PID");
      $pidlist = join(",", @pidlist) if @pidlist;
      $project->search(["(PMUID = '$session_uid' OR PID IN ($pidlist))"], ["STATUS < 10"]);
    }

    $self->template_display("Projects/search", PROJECTS=>$project, COUNT=>$project->count);
  }
}

sub sort_execution
{
  # If one is dependent on the other, FLAG BOTH with a unique dep id # (and direction!)
  # the one we need first will go first.
  # otherwise, sort based on START DATE, THEN FINISH DATE (with earlier finish going first)
  # IF CANT, sort based upon mid and then pmid.
  # 
  my ($a, $b, $depid) = @_;

  my @a_dep_tids = $a->{DEPENDENCY_IDS}->get_all("DEPENDENT_TID");
  my @b_dep_tids = $b->{DEPENDENCY_IDS}->get_all("DEPENDENT_TID");
  my $atid = $a->{TID};
  my $btid = $b->{TID};

  if (grep { $_ == $btid } @a_dep_tids)
  {
    $a->{DEPON} = [ (ref $a->{DEPON} eq 'ARRAY' ? @{$a->{DEPON}} : ()), $$depid ];
    $b->{DEPME} = [ (ref $b->{DEPME} eq 'ARRAY' ? @{$b->{DEPME}} : ()), $$depid ];
    $$depid++;
    return 1; # Put b before a
  } 
  elsif (grep { $_ == $atid } @b_dep_tids)
  {
    $b->{DEPON} = [ (ref $b->{DEPON} eq 'ARRAY' ? @{$b->{DEPON}} : ()), $$depid ];
    $a->{DEPME} = [ (ref $a->{DEPME} eq 'ARRAY' ? @{$a->{DEPME}} : ()), $$depid ];
    $$depid++;
    return -1; # Put a before b
  }

  if ($a->{STARTDATE} and $b->{STARTDATE})
  {
    my $scmp = $a->{STARTDATE} cmp $b->{STARTDATE};
    if ($scmp == 0) # Pick earlier due date.
    {
      my $ecmp = $a->{ENDDATE} cmp $b->{ENDDATE};
      return $ecmp if $ecmp != 0;
    }
  }

  # Sort based upon MID's start/end date
  my $mcmp = $a->{MID} <=> $b->{MID};

  if ($mcmp == 0)
  {
    return $a->{PMID} <=> $b->{PMID};
  } else { # Compare milestone's start/end
    my $amile = $a->{MILESTONE};
    my $bmile = $b->{MILESTONE};
    my $mscmp = $amile->get("STARTDATE") cmp $bmile->get("ENDDATE");
    if ($mscmp == 0)
    {
      return $amile->get("DUEDATE") cmp $bmile->get("DUEDATE");
    } else {
      return $mscmp;
    }
  }

  return 0;
}

sub template_display
{
  my ($self, @args) = @_;
  $self->SUPER::template_display(@args, TaskCommon->vars());
}

1;
