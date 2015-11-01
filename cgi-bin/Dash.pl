#!/usr/bin/perl

my $cgi = HomeCGI->new(PATH_INFO_KEYS=>[qw(mode)],DBO=>1);

package HomeCGI;
use lib "../lib";
use base "TMCGI";
use MalyTemplate;
use Data::Dumper;
use MIME::Base64;
use Time::Local 'timelocal_nocheck';
use Task;
use User;
use Project;

sub process
{
  my ($self, $action) = @_;

  # Dashboard like control center?
  # Maybe add some statistical stuff -- # tasks, proj, tgroups open
  # as well as which ones would be considered important?

  # tasks, task groups, projects due this week
  # with link to search, and more detailed browsing

  # MAYBE if a manager, show list of recently closed tasks of others?

  # PROVIDE QUICK AND CONVENIENT AND COMMON SEARCHES ALREADY DONE....

  # as well as wizard-like list of what you can do. in layman-friendly wording.

  my $uid = $self->session_get("UID");
  my $session_user = User->search(UID=>$uid);
  my $uidlist = $session_user->get_managed_uids(1);
  $uidlist = "NULL" if $uidlist eq '';

  my $startofweek = Calendar->date( Calendar->start_of_week(time) );
  my $endofweek = Calendar->date( Calendar->end_of_week(time) );

  my $startofnextweek = Calendar->date( Calendar->start_of_week(time+Calendar->week(1)) );
  my $endofnextweek = Calendar->date( Calendar->end_of_week(time+Calendar->week(1)) );

  print STDERR "SOW=$startofweek, EOW=$endofweek\n";
  $MalyDBO::DEBUG = 1;

  my $my_tasks_this = Task->search(UID=>$uid, ["(DUEDATE BETWEEN '$startofweek' AND '$endofweek')"]);
  my $my_tasks_next = Task->search(UID=>$uid, ["(DUEDATE BETWEEN '$startofnextweek' AND '$endofnextweek')"]);
  my $all_tasks_this = Task->search(["UID IN ($uidlist)"], ["(DUEDATE BETWEEN '$startofweek' AND '$endofweek')"]);
  my $all_tasks_next = Task->search(["UID IN ($uidlist)"], ["(DUEDATE BETWEEN '$startofnextweek' AND '$endofnextweek')"]);

  my $my_projects_this = Project->search(PMUID=>$uid, ["(ENDDATE BETWEEN '$startofweek' AND '$endofweek')"]);
  my $my_projects_next = Project->search(PMUID=>$uid, ["(ENDDATE BETWEEN '$startofnextweek' AND '$endofnextweek')"]);
  my $all_projects_this = Project->search(["PMUID IN ($uidlist)"], ["(ENDDATE BETWEEN '$startofweek' AND '$endofweek')"]);
  my $all_projects_next = Project->search(["PMUID IN ($uidlist)"], ["(ENDDATE BETWEEN '$startofnextweek' AND '$endofnextweek')"]);

  my %vars =
  (
    MY_TASK_QUEUE_THIS_WEEK=>$my_tasks_this,
    MY_TASK_QUEUE_NEXT_WEEK=>$my_tasks_next,
    ALL_TASK_QUEUE_THIS_WEEK=>$all_tasks_this,
    ALL_TASK_QUEUE_NEXT_WEEK=>$all_tasks_next,

    MY_PROJECT_QUEUE_THIS_WEEK=>$my_projects_this,
    MY_PROJECT_QUEUE_NEXT_WEEK=>$my_projects_next,
    ALL_PROJECT_QUEUE_THIS_WEEK=>$all_projects_this,
    ALL_PROJECT_QUEUE_NEXT_WEEK=>$all_projects_next,

  );

  $self->template_display("Dash/home", %vars);
}

1;
