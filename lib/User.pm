####################
package User;

use lib "../../MalyCGI";
use base "MalyDBO";
use MalyDBO;
use UserManagers;
use Data::Dumper;
use Group;
use GroupMembership;
use TaskCategories;
use TaskCategoriesRemoved;

sub subclass_init
{
  return ("users", "uid");
}

sub search_bymod
{
  my ($self, $uid, $target) = @_;
  my @target = (USERNAME=>$target) if $target;
  $self->search($self->col_has(MODERATORS=>$uid), @target);
}

sub db2cgi
{
  my ($self) = @_;
  return
  (
    MANAGED_IDS=>[UserManagers->new(), "UID", "MANAGER_UID"],
    MANAGED=>[ User->new(), "MANAGED_IDS{UID}", "UID"],
    MANAGER_IDS=>[UserManagers->new(), "UID", "UID"],
    MANAGER=>[ User->new(), "MANAGER_IDS{MANAGER_UID}", "UID"],
    GROUP_IDS=>[ GroupMembership->new(), "UID", "UID"],
    GROUPS=>[ Group->new(), "GROUP_IDS{GID}", "GID"],
    MANAGED_GROUPS=>[ Group->new(), "UID", "MANAGER_UID"],
    TASK_CATEGORIES=>[ TaskCategories->new(), "GROUP_IDS{GID}", "GID" ], 
    TASK_CATEGORIES_REMOVED=>[ TaskCategoriesRemoved->new(), "UID", "UID"], # FILL IN LATER
    XFULLNAME=>[ sub { $_[0] =~ s/['"]//g; $_[0] }, "#FULLNAME#" ],
  );
}

# team members is PER PROJECT ! cant add here. Need to somehow merge both SESSION{MANAGED} and PROJECT{PARTICIPANTS}, via maly-set.
# <maly-set var="ASSIGNEES" from="SESSION{MANAGED},PROJECT{PARTICIPANTS}"/>

sub link_managers_to_user
{
  my ($self) = @_;
  my $link_dbo = $self->get("MANAGER_IDS");
  my $managers = User->new();
  if (ref $link_dbo)
  {
    my @uids = map { $_->{MANAGER_UID} } $link_dbo->records;
    $managers->search(User->col_in("UID", @uids));
  }
  return $managers;
}

sub link_managed_to_user
{
  my ($self) = @_;
  my $link_dbo = $self->get("MANAGED_IDS");
  my $managed = User->new();
  if (ref $link_dbo)
  {
    my @uids = map { $_->{UID} } $link_dbo->records;
    my $col_in = User->col_in("UID", @uids)."\n";
    $managed->search(User->col_in("UID", @uids));
  }
  return $managed;
}

sub get_manager_uids
{
  my ($self, $coworkers) = @_;
  my $session_uid = $self->{GLOBAL}->{SESSION}->get("UID");
  my $siteadmin = $self->{GLOBAL}->{SESSION}->get("SITEADMIN");

  my @unique_uids = ();
  if ($siteadmin)
  {
    @unique_uids = User->search_cols("UID")->get_all("UID");
  } else {
  
      my @managers = UserManagers->search(UID=>$session_uid)->get_all("MANAGER_UID");
      my @groups_in = GroupMembership->search(UID=>$session_uid)->get_all("GID");
      my @group_managers = Group->search_cols('MANAGER_UID', Group->col_in(GID=>@groups_in))->get_all("MANAGER_UID");
      my @group_coworkers = ();
      if (@group_coworkers)
      {
        @group_coworkers = GroupMembership->search(Group->col_in(GID=>@groups_in))->get_all("UID");
      }

    @unique_uids = grep { not $u{$_}++ } sort (@managers, @group_managers, @group_coworkers, $session_uid);
  }

  if (wantarray)
  {
    return @unique_uids;
  } else {
    my $uidlist = "NULL";
    $uidlist =  join(",", @unique_uids) if @unique_uids;
    return $uidlist;
  }

}

sub get_coworker_uids
{
  my ($self, $notself) = @_;
  my $session_uid = $self->{GLOBAL}->{SESSION}->get("UID");
  my $siteadmin = $self->{GLOBAL}->{SESSION}->get("SITEADMIN");

  my @unique_uids = ();
  if ($siteadmin)
  {
    @unique_uids = User->search_cols("UID")->get_all("UID");
  } else {
    my @groups_in = GroupMembership->search(UID=>$session_uid)->get_all("GID");
    my @group_coworkers = GroupMembership->search(Group->col_in(GID=>@groups_in))->get_all("UID");

    @unique_uids = grep { not $u{$_}++ } sort (@group_coworkers, ($notself ? () : ($session_uid)) );
  }

  if ($notself)
  {
    @unique_uids = grep { $_ != $session_uid } @unique_uids;
  }

  if (wantarray)
  {
    return @unique_uids;
  } else {
    my $uidlist = "NULL";
    $uidlist =  join(",", @unique_uids) if @unique_uids;
    return $uidlist;
  }

}

sub get_managed_uids
{
  my ($self, $notself) = @_;
  print STDERR "CALLER1=".join(",", caller())."\n";
  my $session_uid = $self->{GLOBAL}->{SESSION}->get("UID");
  my $siteadmin = $self->{GLOBAL}->{SESSION}->get("SITEADMIN");


  my %u = ();
  my @unique_uids = ();
  if ($siteadmin)
  {
    @unique_uids = User->search_cols("UID")->get_all("UID");
  } else {
    #my @member_uids = $self->get("MANAGED_GROUPS{MEMBERS}{UID}");
    #my @managed_uids = $self->get("MANAGED{UID}");

    my @groups_managed = Group->search(MANAGER_UID=>$session_uid)->get_all("GID");
    my @group_members = GroupMembership->search(Group->col_in(GID=>@groups_managed))->get_all("UID");
    my @managed = UserManagers->search(MANAGER_UID=>$session_uid)->get_all("UID");
    @unique_uids = grep { not $u{$_}++ } sort (@groups_managed, @group_members, @managed, ($notself ? () : ($session_uid)) );
  }

  if ($notself)
  {
    @unique_uids = grep { $_ != $session_uid } @unique_uids;
  }

  if (wantarray)
  {
    return @unique_uids;
  } else {
    my $uidlist = "NULL";
    $uidlist =  join(",", @unique_uids) if @unique_uids;
    return $uidlist;
  }
}

sub available_owners
{
  my ($this, $session_uid, @pid) = @_;

  my $self = ref $this ? $this : $this->new($this->get_schema);

  my $available_owners = User->new();
  my $siteadmin = User->search_cols('SITEADMIN', UID=>$session_uid)->get("SITEADMIN");

  if (!$siteadmin)
  {
    if (@pid)
    {
      my %participants = ();
      foreach my $pid (@pid)
      {
        my $participants = Participants->search(PID=>$pid);
	my @puids = $participants->get_all("UID");
	map { $participants{$_}++ } @puids;
      }
      my @participants = grep { $participants{$_} == scalar(@pid) } keys %participants; # in ALL projects!
      $available_owners->add_params(Task->col_in(UID=>($session_uid, @participants)));
    } else { # No project to worry about.
      my @managed_uids = $self->get_managed_uids;
      $available_owners->add_params(User->col_in(UID=>@managed_uids));
    }
  }
  return $available_owners->search();
}


sub available_requestors
{
  my ($this, $session_uid, @pid) = @_;

  my $self = ref $this ? $this : $this->new($this->get_schema);

  my $available_requestors = User->new();
  my $siteadmin = User->search_cols('SITEADMIN', UID=>$session_uid)->get("SITEADMIN");

  if (!$siteadmin)
  {
    if (@pid)
    {
      my %participants = ();
      foreach my $pid (@pid)
      {
        my $participants = Participants->search(PID=>$pid);
	my @puids = $participants->get_all("UID");
	map { $participants{$_}++ } @puids;
      }
      my @pmuid = Project->search_cols('PMUID', Project->col_in(PID=>@pid))->get_all("PMUID");
      my @participants = grep { $participants{$_} == scalar(@pid) } keys %participants; # in ALL projects!
      $available_requestors->add_params(Task->col_in(UID=>($session_uid, @participants, @pmuid)));
    } else { # No project to worry about.
      my @manager_uids = $self->get_manager_uids();
      $available_requestors->add_params(User->col_in(UID=>(@manager_uids)));
    }
  }
  return $available_requestors->search();
}

sub available_participants
{
  my ($this, $session_uid, @pid) = @_;

  my $self = ref $this ? $this : $this->new($this->get_schema);

  my $available_participants = User->new();
  my $siteadmin = User->search_cols('SITEADMIN', UID=>$session_uid)->get("SITEADMIN");

  if (!$siteadmin)
  {
    if (@pid)
    {
      my %participants = ();
      foreach my $pid (@pid)
      {
        my $participants = Participants->search(PID=>$pid);
	my @puids = $participants->get_all("UID");
	map { $participants{$_}++ } @puids;
      }
      my @participants = grep { $participants{$_} == scalar(@pid) } keys %participants; # in ALL projects!
      $available_participants->add_params(Task->col_in(UID=>($session_uid, @participants)));
    } else { # No project to worry about.
      my @managed_uids = $self->get_managed_uids();
      $available_participants->add_params(User->col_in(UID=>@managed_uids));


    }
  }
  return $available_participants->search();
}

1;
