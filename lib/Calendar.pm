package Calendar;
use Time::Local 'timelocal_nocheck';
use lib "../../MalyCGI";
use MalyLog;
use Data::Dumper;
#use Task;

sub log
{
  my ($self, $msg) = @_;
  if ($self->{LOGGER}) { $self->{LOGGER}->log($msg); }
  else { print STDERR "$msg\n"; }
}

sub new
{
  my ($this, $vars) = @_;
  my $class = ref ($this) || $this;
  my $self = bless {LOGGER=>MalyLog->new(), VARS=>$vars}, $class;
  return $self;
}

sub weekdayname
{
  my ($self, $weekdaynum) = @_;
  my @daynames = qw(Sunday Monday Tuesday Wednesday Thursday Friday Saturday);
  return $daynames[$weekdaynum];
}

sub template_meta
{
  my ($self, $scope, $date) = @_;
  my @today = localtime(time);
  $date ||= sprintf( "%4u-%02u-%02u", $today[5]+1900, $today[4]+1, $today[3]);
  # Small scope is ALWAYS the month.
  $scope ||= 'month'; # Default

  my $tmpl = $scope;

  my %meta = ();
  if ($scope eq 'month') { %meta = $self->month_meta($date); } 
  return ("Calendar/$tmpl", SCOPE=>$scope, DATE=>$date, %meta);
}

sub generate_endtime_hash
{
  my ($self, $endfield, @records) = @_;
  my %hash = ();
  #$self->log("RECORDS COUNT=".scalar(@records));
  my @sorted_records = sort { $a->{$endfield} cmp $b->{$endfield} } @records;
  #$self->log("SORTEDRECORDS=".Dumper(\@sorted_records));
  foreach my $rec (@sorted_records)
  {
    $rec->{$endfield} ||= "17:00";
    my ($hour, $min) = split(':', $rec->{$endfield});

    if ($min >= 30)
    {
      my @array = ref $hash{"$hour.5"} ? @{$hash{"$hour.5"}} : ();
      push @array, $rec;
      $hash{"$hour.5"} = \@array;
    } else { 
      my @array = ref $hash{$hour} ? @{$hash{$hour}} : ();
      push @array, $rec;
      $hash{$hour} = \@array;
    }
  }
  #$self->log("ENDTIMEHAHS=".Dumper(\%hash));
  
  return %hash;
}

sub month_meta
{
  my ($self, $date) = @_;
  my @days = ();
  my @class = ();

  my @today = localtime(time);
  my @date = $date =~ /(\d{4})-(\d{2})-(\d{2})/;
  my $now = timelocal_nocheck(0,0,11,$date[2],$date[1]-1,$date[0]-1900);
  my @now = localtime($now);

  my $first = timelocal_nocheck(0,0,11,1,$now[4],$now[5]);
  my @first = localtime($first);
  my $start = $first - $first[6]*24*60*60;
  # Go back to that sunday.

  my $nextmon = $now[4];
  my $yearofnextmon = $now[5];

  if (++$nextmon == 12)
  {
    $nextmon = 0;
    $yearofnextmon++;
  }
  # Only increment year if last month of year.
  
  my $last = timelocal_nocheck(0,0,11,1,$nextmon,$yearofnextmon);
  my @last = localtime($last);
  my $end = $last;
  if ($last[6] > 0) # If not Sunday, i.e., this month doesn't end a line, print all of the line.
  {
    $end = $last + (7-$last[6])*24*60*60;
  }
  # Go back to sunday and add a week.

  my $x = 0;

  my $weekcount = 0;

  my @ymd = ();


  #my @tasks = ();
  #my @reminders = ();
  #my @events = ();

  for (my $thisday = $start; $thisday < $end; $thisday += 24*60*60)
  {
    my ($s, $min, $h, $day, $mon, $y, $weekday) = localtime($thisday);
    my $class = $mon == $now[4] ? "data1" : "data2";
    $class = "today" if ($today[3] == $day and $today[4] == $mon and $today[5] == $y);
    #$class = "givendate" if ($now[3] == $day and $now[4] == $mon and $now[5] == $y);
    push @ymd, sprintf "%4u-%02u-%02u", $y+1900, $mon+1, $day;
    push @class, $class;
    push @days, sprintf("%02u", $day);
    # week includes previous month (whether month # less, or year # less, i.e., January)
    if ($weekday == 0 and (($mon <= $now[4] and $y == $now[5]) or ($y <= $now[5])))
    {
      $weekcount++;
    }
    my $enddate = sprintf "%4u-%02u-%02u", $y+1900, $mon+1, $day;

    #my $tasks = Task->search(ENDDATE=>$enddate, UID=>$euid, LIMIT=>2, ORDER=>'PRIORITY');
    # ADD REMINDERS
    # ADD EVENTS
    #push @tasks, $tasks;

    #last if ($x++ > 55);
  }

  my $prevmon = $now[4];
  my $yearofprevmon = $now[5];
  if (--$prevmon < 0)
  {
    $prevmon = 11;
    $yearofprevmon--;
  }

  my %navigation = $self->navigation($now);

  return
  (
    YMD=>\@ymd,
    DAYS=>\@days,
    CLASS=>\@class,
    MONTHNAME=>$self->monthname($now[4]),
    MONTH=>sprintf("%02u", $now[4]+1),
    YEAR=>1900+$now[5],
    WEEKCOUNT=>$weekcount-1, # Since start from zero, and do <= check.
    %navigation,
    #TASKS=>\@tasks,
  );
}

sub navigation
{
  my ($self, $now) = @_;
  my @now = localtime($now);
  #my ($s, $min, $h, $day, $mon, $y, $weekday) = localtime($thisday);
  my $pm = $now[4]-1;
  my $yopm = $now[5];
  if ($pm < 0)
  {
    $pm = 11;
    $yopm--;
  }

  my $nm = $now[4]+1;
  my $yonm = $now[5];
  if ($nm >= 12)
  {
    $nm = 0;
    $yonm++;
  }

  my @prevmonth = (0,0,11,$now[3],$pm,$yopm),
  my @nextmonth = (0,0,11,$now[3],$nm,$yonm),

  my @currmonth = localtime();

  my @prevday = localtime($now-1*24*60*60);
  my @nextday = localtime($now+1*24*60*60);

  my @prevyear = (0,0,11,$now[3],$now[4],$now[5]-1);
  my @nextyear = (0,0,11,$now[3],$now[4],$now[5]+1);

  my %navigation = 
  (
    PREV_DAY=>$self->nav_format(@prevday),
    NEXT_DAY=>$self->nav_format(@nextday),

    PREV_MONTH=>$self->nav_format(@prevmonth),
    NEXT_MONTH=>$self->nav_format(@nextmonth),

    PREV_YEAR=>$self->nav_format(@prevyear),
    NEXT_YEAR=>$self->nav_format(@nextyear),

    CURRENT_MONTH=>$self->nav_format(@currmonth),

  );
  return %navigation;
}

sub nav_format
{
  my ($self, @now) = @_;
  sprintf "%4u-%02u-%02u", $now[5]+1900, $now[4]+1, $now[3];
}

sub monthname
{
  my ($self, $x) = @_;
  my @month = qw(January February March April May June July August September October November December);
  return $month[$x];
}

sub date # in YYYY-MM-DD format
{
  my ($self, $when) = @_;
  $when ||= time();
  my ($s, $min, $h, $d, $mon, $y, $wd) = localtime($when);
  $mon++;
  $y+=1900;
  return sprintf("%04u-%02u-%02u", $y, $mon, $d);
}

sub mdy_date # Human readable
{
  my ($self, $when) = @_;
  $when ||= time();
  my ($s, $min, $h, $d, $mon, $y, $wd) = localtime($when);
  $mon++;
  $y+=1900;
  return sprintf("%02u/%02u/%04u", $mon, $d, $y);
}

sub week # Relative, in seconds.
{
  my ($self, $count) = @_;
  $count = 1 if @_ == 1; # No arg passed!
  return ($self->day($count * 7));
}

sub day
{
  my ($self, $count) = @_;
  $count = 1 if @_ == 1; # No arg passed!
  return $self->hour($count * 24);
}

sub hour
{
  my ($self, $count) = @_;
  $count = 1 if @_ == 1; # No arg passed!
  return $self->minute(60*$count);
}

sub minute
{
  my ($self, $count) = @_;
  $count = 1 if @_ == 1; # No arg passed!
  return ($count * 60);
}

sub start_of_week # The particular sunday of a date's week. IN SECONDS.
{
  my ($self, $when) = @_;
  $when = $self->date_in_secs($when); 
  my @when = localtime($when);
  my $start_of_week = $when - $self->day($when[6]);
}

sub end_of_week 
{
  my ($self, $when) = @_;
  $when = $self->date_in_secs($when);
  my @when = localtime($when);
  my $end_of_week = $when + ($self->week - $self->day($when[6])) - 1;
}

sub between
{
  my ($self, $a, $b) = @_;
  return abs( $self->time_in_secs($a) - $self->time_in_secs($b) );
}

sub intersect # # secs these two time spans intersect.
{
  my ($self, $astart, $aend, $bstart, $bend) = @_;
  # As this takes in seconds, we need to get 
  # Can be in either order, doesnt matter.
  my $ass = $self->time_in_secs($astart);
  my $aes = $self->time_in_secs($aend);
  my $bss = $self->time_in_secs($bstart);
  my $bes = $self->time_in_secs($bend);

  my $startdiff = abs($bss - $ass);
  my $enddiff = abs($bes - $aes);

  if ($aes < $bss or $bes < $ass) # there is no intersection when one's end is less than the other's start
  {
    return 0;
  }

  # Take the smallest start and the largest end, then subtract the difference between each respective one.
  # ie..:
  #
  #  {    [XXXX}           ]
  #  AS  BS    AE          BE
  #

  my $firststart = ($ass < $bss ? $ass : $bss);
  my $lastend = ($aes > $bes ? $aes : $bes);

  my $totalspan = $lastend - $firststart;
  my $extra = ($startdiff + $enddiff);



  return $totalspan - $extra;
}

sub to_days # From (A RELATIVE AMOUNT OF) seconds.
{
  my ($self, $secs, $round_up) = @_;
  my $count = $secs / $self->day(1);
  return ($count > int($count) && $round_up) ? int($count)+1 : int($count);
}

sub to_hours
{
  my ($self, $secs, $round_up) = @_;
  my $count = $secs / $self->hour(1);
  return ($count > int($count) && $round_up) ? int($count)+1 : int($count);
}

sub to_weeks
{
  my ($self, $secs, $round_up) = @_;
  my $count = $secs / $self->week(1);
  return ($count > int($count) && $round_up) ? int($count)+1 : int($count);
}

sub to_minutes
{
  my ($self, $secs, $round_up) = @_;
  my $count = $secs / $self->minute(1);
  return ($count > int($count) && $round_up) ? int($count)+1 : int($count);
}

sub time_in_secs # Can either take in unix time, or yyyy-mm-dd hh:mm:ss format
{
  my ($self, $when, $end_of_day) = @_;
  # Round up to is a number of seconds, i.e., determining a day, a week, etc... to get the last second within that time frame. (ie.. last second of day if given a day)
  if ($when =~ /^\d{4}-\d{2}-\d{2}/) # In sql time format.
  {
    my @when_parts = split(/\s+/, $when);
    $when_parts[1] = '23:59:59' if ($end_of_day);
    my @when_date = split(/-/, $when_parts[0]);
    my @when_time = split(/:/, $when_parts[1]);

    my @time = ($when_time[2]||0, $when_time[1]||0, $when_time[0]||0,
      $when_date[2], $when_date[1]-1, $when_date[0]-1900);
    $when = timelocal_nocheck(@time)||time();
  }
  return $when;

}

sub date_in_secs # Round down to nearest day.
{
  my ($self, $when) = @_;
  my $time_in_secs = $self->time_in_secs($when);
  my @time = localtime($time_in_secs);
  my $date_in_secs = timelocal_nocheck(0, 0, 0, @time[3..$#time]);
}


sub timestamp
{
  my ($self, $when) = @_;
  $when ||= time();
  my ($s, $min, $h, $d, $mon, $y, $wd) = localtime($when);
  $mon++;
  $y+=1900;
  my $dname = Calendar->weekdayname($wd);
  my $monname = Calendar->monthname($mon-1);

  return sprintf(
  "%02u:%02u" 
  . ", " . 
  "%s, %s %02u, %04u",
  $h, $min,
  $dname, $monname, $d, $y, 
  );
}


# Need to integrate small calendar with time, as well as being able to pass time to it.
sub dateTime_meta # For popup displaying time/date setting.
# To implement date-only, have new template.
{
  my ($self, $date, $name) = @_;
  # Get main data from other meta function.
  my %meta = 
  (
    $self->month_meta($date),
    DATEFIELD=>"${name}date",
    TIMEFIELD=>"${name}time",
  );
  return %meta;
}



1;
