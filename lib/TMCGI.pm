package TMCGI;

use lib "../etc";
use lib "../MalyCGI";
use base "MalyCGI";
use TaskCommon;
use MalyDBAuth;
use Data::Dumper;
use MIME::Base64;
use MalyDBO;
use Messenger;
#use Shortcut;
use User;
use Calendar;
use Logging;
use DBOFactory;
use MalyLicense;

our $DBOCONF = do "../etc/db.conf";

sub new
{
  my ($this, %vars) = @_;
  my $class = ref($this) || $this;
  my $globals = require "TMCGI.conf";
  $globals->{RESTRICTED} = 1;
  $globals->{LOGIN_URL} = "cgi-bin/index.pl";
  $globals->{SESSION_ID_NAME} = 'TimeManagerSession';
  $globals->{MANUAL_PROCESS} = 1;
  $globals->{STYLE} = "style.css";
  $globals->{MULTIUSER} = 1;
  $globals->{DBOCONF} = $DBOCONF;
  #$globals->{LOGOUT_TO_LOGIN} = 1;
  # MAYBE SOMEDAY FIX, PROBLEM IF NO NEXT_PAGE SET, WILL GO TO action=Logout IMMEDIATELY
  #$globals->{POST_LOGIN_PAGE} = 'Tasks.pl'; # PERHAPS ALLOW CUSTOMIZATION ?
  $globals->{STDERR} = 1;
  # Overwrite any with individual CGI.
  foreach my $key (%vars)
  {
    $globals->{$key} = $vars{$key};
  }

  $globals->{META} = do "../etc/TMCGI.conf";

  #MalyDBO->init(@{ $globals->{DB_PARAMS} });
  my $dbauth = MalyDBAuth->new($globals); # This sets functions, et al.
  my $self = $class->SUPER::new($globals);
  $self->{GLOBAL}->{MESSENGER} = Messenger->new($globals);
  bless $self, $class;

  Logging::init($self->{GLOBAL});
  DBOFactory::init_config($DBOCONF);

  my $license = eval { do "../etc/license.conf" } || 
    "406040132333434040408030300000008058800000000525f4a454344535804e50000000451435b43580585000000034f455e445";

  $self->{LICENSE} = MalyLicense::decode($license);


  # WE NEED TO CALL SET_VARS MANUALLY SINCE WE DONT HAVE MALYCGI DO IT,
  # AS PER MANUAL_PROCESS.
  $self->{VARS} = $self->get_vars(); # Still needed
  $self->pre_process();
  $self->process($self->get("action"));
  return $self;
}

sub pre_process # Handles sending to different users from drop-down list.
{
  my ($self) = @_;
  my $target = $self->get("user_target");
  if ($target)
  {
    $self->redirect("$self->{GLOBAL}->{BASE_PATH}/Dash.pl/$target");
  }
  # Check who moderating. If not self, siteadmin, or in moderator list, abort.
  $target = $self->get_path_info("euser");
  my $username = $self->session_get("USERNAME");
  my $uid = $self->session_get("UID");
  if ($target and not $self->siteadmin and $target ne $username and
    not User->search_bymod($uid, $target)->result
    )
  {
    $self->user_error("Sorry, you are not set as a moderator for '$target'");
  }
}

sub application_get_vars {
  my ($self, %globals) = @_;
  my $euser = undef;

  #$self->log("SESSIONINFO=".Dumper($globals{SESSION}->{SESSION_INFO}));

  my $uid = $self->session_get("UID");
  my @shortcuts = ();
  my $samegroup_fullnamemap = undef;
  my $euid = undef;
  my $moderatormap = undef;
  my $moderatormap = undef;
  my $managed_grups = undef;
  my $groupnamemap = undef;
  my $mygroupnamemap = undef;
  my $effgroupnamemap = undef;
  my $fullnamemap = undef;
  my $session = undef;
  my %tab = ();

  my $search_url = $globals{PATHINFO_URL};

  if ($uid ne '')
  {
    if (my $eusername = $self->get_path_info("euser"))
    {
    #$self->log("GETTING EUSER VIA EUSERNAME ($eusername)");
      if ($eusername =~ /^\d+$/)
      {
        $euser = User->search(UID=>$eusername)->hashref;
      } else {
        $euser = User->search(USERNAME=>$eusername)->hashref;
      }
      $self->user_error("No such effective user") unless ref $euser;
    } else {
    #$self->log("GETTING EUSER VIA SESSION");
      $euser = $self->session_info();
    }

    #@shortcuts = Shortcut->search_cols(['SHID','NAME'], UID=>$uid)->values;
    #$samegroup_fullnamemap = User->in_samegroup_as($euser->{UID});
  
    my @qk = $self->get_keys;
    my %qs = map { (uc($_), my $x=$self->get($_)) } @qk;

    delete $qs{SORT};
    delete $qs{DESC};
    my $qstring = join("&", map { "$_=$qs{$_}" } keys %qs);
    $qstring .= "&" if $qstring;
    $search_url .= "?";
    $search_url .= "$qstring" if $qstring;
  
    # Which tabs to display, etc...
    foreach my $tab (("Dash", "Tasks", "Task Groups", "Projects", "Admin"))
    {
       my $key = $tab;
       $key =~ s/\s+//g;
       my $sel = $globals{_NAME} eq $key ? "selectedtab" : "unselectedtab";
       $tab{$key} = $sel;
    }
  
    $euid = $euser->{UID};

    $session = $self->session_info;
  }

  my ($s, $m, $h, $d, $m, $y) = localtime();
  $y+=1900;
  my @nextfewyears = map { $y+$_ } (0..10);
  my $all_users = User->new();
  $all_users->search() if $session->{SITEADMIN};

  my %vars = 
  (
    SESSION=>$session,
    DOC_SITE=>($self->{LICENSE}->{DOCS} ? '' : 'http://www.malysoft.com/'),
    ALL_USERS=>$all_users,
    #URL=>$globals{URL},
    SEARCH_URL=>$search_url, # Capable of just appending name=value&... with no concern for ? or & before.
    #COMPLETE_URL=>$globals{COMPLETE_URL},
    ENC_COMPLETE_URL=>encode_base64($globals{COMPLETE_URL},''),
    #REFERER=>$globals{REFERER},
    ENC_REFERER=>encode_base64($globals{REFERER},''),
    #PATHINFO_URL=>$globals{PATHINFO_URL},
    #BASE_PATH=>$globals{BASE_PATH},
    COMPONENT=>$globals{_NAME},
    EUSER=>$euser,
    TAB=>\%tab,
    TOP_SHORTCUTS=>\@shortcuts,
    MODE=>$self->get_path_info("mode"),
    CONF=>$self->{GLOBAL}->{META},
    TIMESTAMP=>Calendar->timestamp(time),
    TODAY_DATE=>Calendar->date(time),
  );
  return %vars;
} # Usually for sending with template.

sub select_map # Takes a key/value hash and creates an array of hashrefs with KEY and VALUE keys
{
  my ($self, $map, $reverse, $selected) = @_;
  my @out = ();
  my @selected = @{$selected} if ref $selected;
  foreach my $key (sort keys %{$map})
  {
    push @out, {KEY=>$key, VALUE=>$map->{$key}, SELECTED=>(grep { /^$key$/ } @selected) };
  }
  return [reverse @out] if $reverse;
  return [@out];
}

sub sort_records
{
  my ($self, @in) = @_;
  my $sort = $self->get("sort");
  $self->log("SORT=$sort");
  return @in unless $sort;
  my $descending = $self->get("descending");
  $self->log("DESCENDING=$descending");
  my @results = sort 
  { 
    ($a =~ /\D/ or $b =~ /\D/) ? 
    ($a->{$sort} cmp $b->{$sort}) : 
    ($a->{$sort} <=> $b->{$sort})
  } @in;

  if ($descending) { return reverse @results; } 
  else { return @results; }
}

sub siteadmin
{
  my ($self) = @_;
  return undef unless $self->{GLOBAL}->{SESSION};
  my $sa = $self->{GLOBAL}->{SESSION}->get("SITEADMIN");
  #$self->log("SA=$sa");
  return $sa;
}

sub formatted_date_from_secs
{
  my ($self, $time) = @_;
  $time ||= time();
  my ($s,$min,$h,$d,$mon,$y) = localtime($time);
  sprintf "%4u-%02u-%02u %02u:%02u:%02u", $y+1900, $mon+1, $d, $h, $min, $s;
}

sub sql_datetime_from_secs # For import into SQL
{
  my ($self, $time) = @_;
  $time ||= time();
  my ($s,$min,$h,$d,$mon,$y) = localtime($time);
  sprintf "%4u-%02u-%02u %02u:%02u:%02u", $y+1900, $mon+1, $d, $h, $min, $s;
}

sub template_display
{
  my ($self, @args) = @_;
  $self->SUPER::template_display(@args, TaskCommon->vars);
}

1;
