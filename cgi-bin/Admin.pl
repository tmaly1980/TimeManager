#!/usr/bin/perl

my $cgi = AdminCGI->new(PATH_INFO_KEYS=>[qw/target id/],DBO=>1);

package AdminCGI;
use lib "../lib";
use base "TMCGI";
use MalyTemplate;
use Data::Dumper;
use User;
use UserManagers;
use Group;
use TaskCategoriesRemoved;
use Calendar;
use Task;
use GroupMembership;
use TaskCategories;
use Product;

sub process
{
  my ($self, $action) = @_;
  #return unless $action; # Pass through if nothing happened.
  my ($target) = $self->get_path_info("target");

  my $session_uid = $self->session_get("UID");
  my $siteadmin = $self->session_get("SITEADMIN");

  if ($target eq '')
  {
    if ($siteadmin)
    {
      #my $skills = Skill->search(['GID IS NULL'])->records_ref; # FIX FOR JUST GLOBAL!
      $self->template_display("Admin/browse", USERS=>User->search(), GROUPS=>Group->search(), PRODUCTS=>Product->search());
    } else {
      my $managed = UserManagers->search(MANAGER_UID=>$session_uid);
      my @managed_uids = $managed->get_all("UID");

      my $groups = Group->search(MANAGER_UID=>$session_uid);

      my @gidlist = $groups->get_all("GID");
      my $gidlist = "NULL";
      $gidlist = join(",", @gidlist) if @gidlist;
      my $managed_via_groups = GroupMembership->search(["GID IN ($gidlist)"]);
      my @managed_via_groups_uids = $managed_via_groups->get_all("UID");

      my @all_managed_uids = (@managed_uids, @managed_via_groups_uids);
      push @all_managed_uids, $session_uid if $session_uid;

      my $managed_users = User->new();

      if (@all_managed_uids)
      {
        my %u = ();
        my @uamu = grep { not $u{$_}++ } @all_managed_uids;
        my $amuidlist = @uamu ? join(",", @uamu) : "NULL";
	$managed_users->search(["UID IN ($amuidlist)"]);
      }

      my $products = Product->search(MANAGER_UID=>$session_uid);

      if ($managed_users->count or $groups->count or $products->count)
      {
        # TODO, ADD USERS LINKS, but make CONTENT OF EACH readonly!
        $self->template_display("Admin/browse", USERS=>$managed_users, GROUPS=>$groups, PRODUCTS=>$products);
      } else {
        $self->redirect("$self->{GLOBAL}->{URL}/user?uid=$session_uid");
      }
    }

  } elsif ($target eq 'user') {
    my $user = User->new();
    my $uid = $self->get("uid");
    my $add = ($uid eq '');
    my $edit = !$add;
    my $membership = undef;
    if ($uid ne '')
    {
      $user->search(UID=>$uid);
      $self->user_error("No such user.", "Javascript:window.close();") 
        unless ($user->count);

    } else { 
      $self->user_error("Sorry, only site admins can do that.", "Javascript:window.close();")
        unless ($siteadmin);

      $self->system_error("Cannot add user, maximum number in database reached ($self->{LICENSE}->{COUNT}). Please upgrade licenses at http://www.malysoft.com/")
        if ($self->{LICENSE}->{COUNT} != -1 and User->search_cols("COUNT(*)+1 AS TOTAL")->get("TOTAL") > $self->{LICENSE}->{COUNT});
    }
    my $me = ($user && $session_uid == $user->get("UID"));
    my $readonly = not ($me || $siteadmin);

    $self->user_edit($user) if $action;  # Deal with form buttons.

    my @gids = $user->get("GROUP_IDS{GID}");
    my $atc = TaskCategories->search(Group->col_in("GID", @gids));

    $self->template_display("Admin/user", EDIT=>$edit, USER=>$user->hashref, SKILLS=>$skills,
      SITEADMIN=>$siteadmin, SELF=>$me,READONLY=>$readonly, 
      ALL_USERS=>User->search, AVAILABLE_TASK_CATEGORIES=>$atc, REMOVED_TASK_CATEGORIES=>$rtc);

  } elsif ($target eq 'group') {
    my $group = Group->new();
    my $gid = $self->get("gid");
    my $add = $self->get("add");
    my $membership = undef;
    if ($gid ne '')
    {
      $group->search(GID=>$gid);
      $self->user_error("No such group.", "Javascript:window.close();") 
        unless ($group->count);

      $self->user_error("Sorry, you can't do that.", "Javascript:window.close();")
        unless ($siteadmin or $session_uid == $group->get("MANAGER_UID"));
    } else { 
      $self->user_error("Sorry, only site admins can do that.", "Javascript:window.close();")
        unless ($siteadmin);
    }

    $self->group_edit($group) if $action;  # Deal with form buttons.
    # Handle changing categories, members, name, manager.

    my $my = ($group && $session_uid == $group->get("MANAGER_UID"));
    my $readonly = not ($my || $siteadmin);

    my $tc = $group->get("TASK_CATEGORIES");

    #print STDERR "STAGES=".Dumper($tc->get_all("STAGES"))."\n";

    $self->template_display("Admin/group", GROUP=>$group->hashref, 
      READONLY=>$readonly, ALL_USERS=>User->search);
  } elsif ($target eq 'workload') {

    my @uids = grep { $_ ne '' } $self->get("UID");

    # Allow simplified arg of 'managed=1' to say all users that i manage. (explicit or implicit)

    @uids = ($self->session_get("UID")) if @uids == 0; # Default to self.
    my $startdate = $self->get("STARTDATE");
    my $enddate = $self->get("ENDDATE");
    my $start = $startdate || Calendar->date( Calendar->start_of_week( ($enddate ? Calendar->time_in_secs($enddate) : time) - Calendar->week(3)) );
    my $end = $enddate || Calendar->date( Calendar->end_of_week(time+Calendar->week(1)) );

    my @data = ();

    my %users = ();
    my $user = User->search(User->col_in(UID=>@uids));
    my @users = ();
    for ($user->first; $user->more; $user->next)
    {
      my $u = $user->hashref;
      $u->{HOURSPERWEEK} ||= 40; # Default.
      # GENERATE COLORS... (USE LIGHT ONES ONLY!)

      my $r = int rand(128)+128;
      my $g = int rand(128)+128;
      my $b = int rand(128)+128;
      $u->{COLOR} = sprintf "#%02x%02x%02x", $r, $g, $b;
      push @users, $u;
    }

    # 400 pixels is allocated for the middle...
    # RESERVE 50 pixes for # hours
    
    my @weeks = ();
    my $max_hours = 50;

    for (my $x = Calendar->start_of_week($start); $x <= Calendar->end_of_week($end); $x+=Calendar->week)
    {
      # For each user, get the number of hours they are working in that week. divide by h/w or default 40.
      # to get the number of hours in the week they're working, we have to get all tasks where $x is between start/due
      # then figure out how much percent of this week is contained in the task's lifespan.
      # Then take the hours and multiple that by this percentage.
      # TRY COMPLETE SQL!!!

      my $start_of_week = Calendar->start_of_week($x);
      my $end_of_week = Calendar->end_of_week($x);
      my %allocated = ();

      my $xdate = Calendar->date($x);
      my $xstart = Calendar->date($start_of_week);
      my $xend = Calendar->date($end_of_week);

      foreach my $uid (@uids)
      {
        my $hours_allocated = 0;

	my $crit = "(ESTHOURS+HOURS > 0 AND ( (STARTDATE BETWEEN '$xstart' AND '$xend') OR (DUEDATE BETWEEN '$xstart' AND '$xend') ) )";
        my $tasks = Task->search(UID=>$uid, [$crit]);
	for ($tasks->first; $tasks->more; $tasks->next)
	{
	  # Assumes both start/end is defined. Others are ignored.
	  my $task_esthours = $tasks->get("ESTHOURS");
	  my $task_hours = $tasks->get("HOURS");
	  my $hours = $task_hours > $task_esthours ? $task_hours : $task_esthours;
	  my $task_start = $tasks->get("STARTDATE");
	  my $task_start_in_secs = Calendar->time_in_secs($task_start);
	  my $task_end = $tasks->get("DUEDATE");
	  my $task_end_in_secs = Calendar->time_in_secs($task_end, 1); # ROUND UP TO LAST SECOND OF DAY...
	  my $total_day_count = Calendar->to_days(Calendar->between($task_end_in_secs, $task_start_in_secs), 1);
	  

	  my $hours_per_day = ($hours / $total_day_count);
	  #$hours_per_day += 1 if int($hours_per_day) < $hours_per_day;
	  #$hours_per_day = int($hours_per_day);

	  # Get # of days this task falls in this week

	  my $days = Calendar->to_days( Calendar->intersect($task_start_in_secs, $task_end_in_secs, $start_of_week, $end_of_week), 1);

	  my $task_hours_relevent = $days * $hours_per_day;

	  $hours_allocated += $task_hours_relevent;
	}
	$hours_allocated = 1 + int($hours_allocated) if int($hours_allocated) < $hours_allocated;
	$allocated{$uid} = sprintf("%.1f", $hours_allocated);
	$max_hours = $allocated{$uid} if $max_hours < $allocated{$uid};
      }
      push @weeks, 
      {
        START=>$self->{GLOBAL}->{DATE}->get("dd.MON.yy", $start_of_week),
        END=>$self->{GLOBAL}->{DATE}->get("dd.MON.yy", $end_of_week),
	SQLSTART=>Calendar->date($start_of_week),
	SQLEND=>Calendar->date($end_of_week),
	ALLOCATED=>\%allocated,
      };
    }

    my $pixels_per_hour = 350 / $max_hours;
    $max_hours += 5; # Allow for % display.

    my %users = map { ($_->{UID}, $_) } @users;

    foreach my $user (@users)
    {
      $user->{TOTAL_HOUR_PIXELS} = int( $user->{HOURSPERWEEK} * $pixels_per_hour);
    }

    # NOW, update ALLOCATED so it contains values in pixels.
    foreach my $week (@weeks)
    {
      my %allocated = ref $week->{ALLOCATED} eq 'HASH' ? 
        %{ $week->{ALLOCATED} } : ();

      foreach my $uid (keys %allocated)
      {
        $week->{ALLOCATED_PIXELS}->{$uid} = 
	  int($allocated{$uid}*$pixels_per_hour);
        $week->{ALLOCATED_PERCENT}->{$uid} = 
	  int($allocated{$uid}/$users{$uid}->{HOURSPERWEEK}*100);

      }
    }

    
    my $dividers = 8;

    my $unit_hours = int($max_hours/$dividers) + ($max_hours % $dividers != 0 ? 1 : 0);

    my $hourwidth = $pixels_per_hour * $unit_hours;

    my @hours = ();
    for (my $h = 0; $h < $max_hours+$unit_hours; $h+=$unit_hours)
    {
      push @hours, $h;
    }

    $self->template_display("Admin/workload", WEEKS=>\@weeks, 
      USERS=>\@users, MAX_HOURS=>$max_hours,
      SQLSTART=>$start, SQLEND=>$end, 
      HOURS=>\@hours,
      HOURWIDTH=>$hourwidth,
      PIXELS_PER_HOUR=>$pixels_per_hour);
  } elsif ($target eq 'product') {
    my $product = Product->new();
    my $prod_id = $self->get("PROD_ID");
    my %form = $self->get_hash;
    if ($prod_id ne '')
    {
      $product->search(PROD_ID=>$prod_id);
    }

    if ($action eq 'Update' or $action eq 'Add')
    {
      $product->commit(%form);
      $prod_id = $product->get("PROD_ID");

      my $versions = $product->get("VERSIONS");

      my @versions = $self->get("VERSIONS");
      my @ver_id = ();
      my @ver_name = ();
      my @ver_alias = ();
      foreach my $version (@versions)
      {
        my ($ver_id, $ver_name, $ver_alias) = split(":", $version);
	push @ver_id, $ver_id;
	push @ver_name, $ver_name;
	push @ver_alias, $ver_alias;
      }

      $versions->commit_list([PROD_ID=>$prod_id], undef, undef, VER_ID=>\@ver_id, VER_NAME=>\@ver_name, VER_ALIAS=>\@ver_alias);

    }

    $self->template_display("Admin/products", PRODUCT=>$product);
  }
}

sub set_vars 
{
  my ($self) = @_;

  my @users = User->search->records;

  my $vars =
  {
    %{$self->SUPER::set_vars()},
    #USERMAP=>{ map { ($_->{UID}, $_) } User->search->records },
    USERNAMEMAP=>{ map { ($_->{UID}, $_->{USERNAME}) } @users },
    FULLNAMEMAP=>{ map { ($_->{UID}, $_->{FULLNAME}) } @users },
  };
  return $vars;
}

sub user_edit
{
  my ($self, $user) = @_;
  my $uid = $self->get("UID");
  my $add = ($uid eq '');
  my $action = $self->get("action");
  my $siteadmin = $self->session_get("SITEADMIN");
  return unless ($action =~ /^(Delete|Update|Add)$/);

  $self->user_error("Sorry, you can't do that.", "Javascript:window.close();")
    unless ($siteadmin or $self->session_get("UID") == $user->get("UID"));

  if ($action eq 'Delete')
  {
    $user->delete();
    $self->template_display("Admin/user_deleted");
  }

  my ($password1, $password2, $fullname, $username, $email) = 
    $self->get("password1", "password2", "fullname", "username", "email");
  my @keys = (qw/username email fullname title siteadmin power_user hoursperweek/);
  $self->user_error("Username required") unless ($username);
  $self->user_error("Email required") unless ($email);

  if ($add)
  {
    $self->user_error("Password required.") unless ($password1 and $password2);
    $self->user_error("Password must be >=4 characters.") unless (length($password1) >= 4);
  }

  if ($add or $password1)
  {
    $self->user_error("Passwords do not match.") if ($password1 ne $password2);
  }

  my @password = (password=>$password1) if $password1;

  $self->set_default("fullname", $username);

  my $olduser = User->new();
  $olduser->search(USERNAME=>$username);

  if ($olduser->count and ($add or $olduser->get("UID") != $self->get("UID")) )
  {
    $self->user_error("Duplicate username");
  }

  my $fullname = $self->get("FULLNAME");
  $fullname =~ s/['"\\]//g; 
  $self->set(FULLNAME=>$fullname);

  #
  #my @moderators = ();
  #my $moderator = User->new();
  #foreach my $moduser ($self->get("moderators"))
  #{
  #  $self->user_error("No such user '$moduser'") unless 
  #    $moderator->search(USERNAME=>$moduser)->count;
  #  push @moderators, $moderator->get("UID");
  #}
  #my $moderators = join(",", @moderators);

  if ($add)
  {
    $user->insert($self->get_ph(@keys), @password);
  } else {
    $user->update($self->get_ph(@keys), @password);
  }
  my $uid = $user->get("UID");

  # Now do mangement links.
  my @form_manager = $self->get("manager");
  my $manager = $user->get("manager_ids");

  $manager->commit_list([UID=>$uid], undef, undef, MANAGER_UID=>\@form_manager);

  $user->set("MANAGER_IDS", $manager);

  # Now deal with 'Task Categories Removed'.
  if (!$user->is_new)
  {
    my $tcr = $user->get("TASK_CATEGORIES_REMOVED");
    my @tcids = $self->get("TASK_CATEGORIES_REMOVED");
    $tcr->commit_list([UID=>$uid], undef, undef, TCID=>\@tcids);
  }

  $self->redirect("cgi-bin/Admin.pl/user/Edit?uid=$uid") if $add;

}

sub group_edit
{
  my ($self, $group) = @_;
  my $action = $self->get("action");
  my %form = $self->get_hash;

  if ($action eq 'Update' or $action eq 'Add')
  {
    my $other_group = Group->search(NAME=>$form{NAME});
    $self->user_error("Group name already taken") if $other_group->count and $other_group->get("GID") ne $form{GID};
  
    $group->commit(%form);
    my $gid = $group->get("GID");
    # Update task categories.
    my $tc = $group->get("TASK_CATEGORIES");
    my @tc = $self->get("TASK_CATEGORIES");
    my @names = ();
    my @gtcid = ();

    my %stages_by_name = ();
    for (my $i = 0; $i < @tc; $i++)
    {
      my $tc_text = $tc[$i];
      my @parts = split(":", $tc_text);
      # Need to generate GTCID if not set (i.e., adding)

      $parts[0] =~ s/['"\\]//g;
      push @names, $parts[0];
      my $tcid = $parts[1];
      push @tcid, $tcid;
      $stages_by_name{$parts[0]} = [ @parts[2..$#parts] ];
    }

    my @rm_tcids = $tc->commit_list([GID=>$group->get("GID")],undef,undef,NAME=>\@names,TCID=>\@tcid); # Give what is unique, what is common
    
    # Remove restrictions on task categories.
    if (@rm_tcids)
    {
      my $cat_rm = TaskCategoriesRemoved->new();
      my @tcids = map { $_->[0] } @rm_tcids; # First element.
      $cat_rm->search(TaskCategoriesRemoved->col_in("TCID", @tcids));
      $cat_rm->delete_all;

      my $stage_rm = TaskCategoryStage->search(
        TaskCategoryStage->col_in("TCID", @tcids));
      $stage_rm->delete_all;
      # Remove old stages.
    }

    print STDERR "STAGES=".Dumper(\%stages_by_name)."\n";

    # Update stages.
    for ($tc->first; $tc->more; $tc->next)
    {
      my $name = $tc->get("NAME");
      my $tcid = $tc->get("TCID");
      if (exists $stages_by_name{$name})
      {
        my @stages = ref $stages_by_name{$name} eq 'ARRAY' ?
	  @{ $stages_by_name{$name} } : ();

	print STDERR "STAGE FOR $name IS=".Dumper(\@stages)."\n";
	my @ix = (0..$#stages);
	my $stage = TaskCategoryStage->search(TCID=>$tcid);
	$stage->commit_list([TCID=>$tcid], undef, ["IX, NAME"], IX=>\@ix, NAME=>\@stages); 
      }
    }


    # Update memberships
    my $gm = $group->get("MEMBER_UIDS");
    my @gm = ($self->get("MEMBERS"));
    my $muid = $self->get("MANAGER_UID");
    my @uid = ();
    my @membership_id = ();
    foreach my $member (@gm)
    {
      my ($uid, $membership_id) = split(":", $member);
      push @uid, $uid;
      push @membership_id, $membership_id;
    }
    push @uid, $muid if not grep { $_ == $muid } @uid;
    $gm->commit_list([GID=>$group->get("GID")],undef,undef,UID=>\@uid, MEMBERSHIP_ID=>\@membership_id);
  } 
  elsif ($action eq 'Delete')
  {
    # Get rid of task categories and memberships
    my $tc = $group->get("TASK_CATEGORIES");
    $tc->delete_all();

    my $gm = $group->get("MEMBER_UIDS");
    $gm->delete_all;

    $group->delete();
    $self->template_display("Admin/group_deleted");
  }
  $self->redirect("cgi-bin/Admin.pl/group?gid=".$group->get("GID"));
}

1;
