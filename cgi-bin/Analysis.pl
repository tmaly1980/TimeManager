#!/usr/bin/perl

my $cgi = AnalysisCGI->new(PATH_INFO_KEYS=>[qw(mode component)],DBO=>1);

package AnalysisCGI;
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
use GD::Graph::hbars;
use GD::Graph::bars;
use GD::Text::Wrap;
use GD::Text::Align;

sub process
{
  my ($self, $action) = @_;
  my $pid = $self->get("PID");
  my $project = Project->new();
  my $mode = $self->get_path_info_or_default("mode", "Search"); # View, Edit, Search, Browse, etc...
  my $com = $self->get_path_info("component"); # top, image, etc...
  # View is printable version (no form, no look/feel, etc...
  my %form = $self->get_hash;
  my %raw_hash = $self->get_raw_hash;

  my $session_uid = $self->session_get("UID");

  # TID+, PID+ (dont show mid/tid if > 1), MID+, PTID+

  if ($mode eq 'Gantt')
  {
    my @tid = $self->get("TID");
    my @ptid = $self->get("PTID");
    my @mid = $self->get("MID");
    my @pid = $self->get("PID");

    $self->user_error("No criteria (project, milestone or task) specified.", "Javascript:window.close();")
     if not (@tid or @mid or @pid or @ptid);

    if ($com eq 'top')
    {
      $self->template_display("Analysis/Gantt/top");
    } elsif ($com eq 'image') {
      my $title = undef; # Figure out here...
      my @data = ();
      if (@tid)
      {
        @data = $self->task_data(@tid);
      } elsif (@ptid) {
        @data = $self->ptask_data(@ptid);
      } elsif (@mid) { 
        @data = $self->mile_data(@mid);
      } elsif (@pid) {
        @data = $self->project_data(@pid);
      }

      if (not @data)
      {
        $self->user_error("No data to plot.", "Javascript:window.close();");
      } else {
        $self->render_gantt(@data);
      }
    } else { # frameset.
      $self->template_display("Analysis/Gantt/frameset");
    }
  }
}

sub bound_days
{
  my (@dates) = @_;
  my $mindays = undef;
  my $maxdays = undef;
  for (my $i = 0; $i < @dates; $i++)
  {
    next if $dates[$i] eq '0' or $dates[$i] eq '';
    my $days = Calendar->to_days(Calendar->time_in_secs($dates[$i]));
    $mindays = $days if $days and (not defined $mindays or $mindays > $days);
    $maxdays = $days+1 if $days+1 and (not defined $maxdays or $maxdays < $days+1);
  }
  return ($mindays, $maxdays);
}

sub ptask_data
{
  my ($self, @ptid) = @_;
  my @data = ();
  foreach my $ptid (@ptid)
  {
    my ($ptask_data) = $self->task_data($ptid);
    $ptask_data->{PTASK} = 1;
    push @data, $ptask_data;
    my @tid = ref $ptask_data->{SUBTID} eq 'ARRAY' ? @{ $ptask_data->{SUBTID} } : ();
    push @data, $self->task_data(@tid);
  }

  return @data;
}

sub task_data
{
  my ($self, @tid) = @_;
  my @data = ();
  foreach my $tid (@tid)
  {
    my $task = Task->search(TID=>$tid);
    my ($id, $title, $startdate, $enddate, $percent, $status) = $task->get(
      qw(TID TITLE STARTDATE DUEDATE PERCENT STATUS)
    );

    my @subtid = $task->get("SUBTASK_IDS")->get_all("TID");
    push @data,
    {
        ID=>$id,
	TITLE=>$title,
	STARTDATE=>$startdate,
	ENDDATE=>$enddate,
	PERCENT=>$percent,
	SUBTID=>\@subtid,
	STATUS=>$status,
	TASK=>1,
    };
  }
  return @data;
}

sub project_data
{
  my ($self, @pid) = @_;
  if (@pid > 1) # Just show pid, maybe milestones too.
  {

  } else { # Just one.
    my $project = Project->search(PID=>$pid[0]);
    my @data = ();
    my ($id, $title, $startdate, $enddate, $percent, $status) = $project->get(
      qw(PID TITLE STARTDATE ENDDATE PERCENT STATUS)
    );
    push @data,
    {
        ID=>$id,
	TITLE=>$title,
	STARTDATE=>$startdate,
	ENDDATE=>$enddate,
	PERCENT=>$percent,
	STATUS=>$status,
	PROJECT=>1,
    };
    my @mid = $project->get_all("MILESTONES{MID}");
    push @data, $self->mile_data(@mid);

    return @data;
  }

}

sub mile_data
{
  my ($self, @mid) = @_;

    my $tasks = Task->new();

    # XXX Allow option to hide tasks for project, just show miles.
    # XXX IMPLEMENT ZOOMING IN, WILL HAVE TO TAKE NEGATIVE #'s as 0, with display date still there.
    # Implement coloring task names according to owner!!!! TODO LATER !!!
    my $mile = Milestone->new();

    if (@mid) 
    {
      $mile->search(Milestone->col_in(MID=>@mid));
      my $task_link = TaskLink->search(TaskLink->col_in(MID=>@mid));
      @tid = $task_link->get_all("TID");
    }

    $self->user_error("No tasks given.", "Javascript:window.close();") unless @tid;

    $tasks->search(Task->col_in(TID=>@tid));

    my @data = ();

    # Next, create dataset, with x label as well as data value to display.
    # NEEDS TO BE DONE SORTED PROPERLY!!!


    my $chart_title = "Gantt Chart blah blah blah";


    my @mile = $mile->records;
    # XXX SOON DO SORTING PROPERLY!!! XXX

    foreach my $milerec (@mile)
    {
      my $id = $milerec->{MID};
      my $title = $milerec->{"SUMMARY"};
      my $startdate = $milerec->{"STARTDATE"};
      my $enddate = $milerec->{"ENDDATE"};
      my $percent = $milerec->{"PERCENT"};
      my $status = $milerec->{"STATUS"};


      push @data, 
      {
        ID=>$id,
	TITLE=>$title,
	STARTDATE=>$startdate,
	ENDDATE=>$enddate,
	PERCENT=>$percent,
	STATUS=>$status,
	MILE=>1,
      };

      next if $self->get("NO_TASKS");

      my @tasks = $milerec->{"TASKS"}->records;

      # DO SORTING HERE
      foreach my $taskrec (@tasks)
      {
        my $id = $taskrec->{"TID"};
        my $title = $taskrec->{"TITLE"};
        my $startdate = $taskrec->{"STARTDATE"};
        my $enddate = $taskrec->{"DUEDATE"};
        my $percent = $taskrec->{"PERCENT"};
        my $status = $taskrec->{"STATUS"};
	
        push @data,
	{
          ID=>$id,
	  TITLE=>$title,
	  STARTDATE=>$startdate,
	  ENDDATE=>$enddate,
	  PERCENT=>$percent,
	  STATUS=>$status,
	  TASK=>1,
	};
      }
    }

    return (@data);
}

sub render_gantt
{
  my ($self, @input) = @_;
  # XXX TODO FIXME DONT FORGET, @INPUT MUST BE PRESORTED!

  my ($mindays, $maxdays) = bound_days(map { ($_->{STARTDATE}, $_->{ENDDATE}) } @input);

  my $formstart = $self->get("STARTDATE");
  my $formend = $self->get("ENDDATE");

  $mindays = Calendar->to_days(Calendar->date_in_secs($formstart))+1 if $formstart;
  $maxdays = Calendar->to_days(Calendar->date_in_secs($formend))+1 if $formend;

  my $nd = Calendar->date(Calendar->day($mindays));
  my $xd = Calendar->date(Calendar->day($maxdays));
  
  my $width = 400; # or other..... as configurable.

  my $diffdays = ($maxdays - $mindays) || 7;
  # Basically, the nearest unit that makes up at most 10 dividers
  my $dividers = 6;
  my $days_per_div = int($diffdays / $dividers) + ($diffdays % $dividers != 0 ? 1 : 0);
  my $unit = $days_per_div;

  my $totaldiffdays = int($diffdays/$unit)*$unit + ($diffdays % $unit != 0 ? $unit : 0);

  my $pixelsperday = ($width/$totaldiffdays);
  my $div_width = $unit * $pixelsperday;

  my @data = ();

  # Generate data set.
  foreach my $row (@input)
  {
    my %row = ref $row eq 'HASH' ? %$row : ();

    my $startdays = $row->{STARTDATE} ? Calendar->to_days(Calendar->date_in_secs($row->{STARTDATE}))+1 : 0;
    my $duedays = $row->{ENDDATE} ? Calendar->to_days(Calendar->date_in_secs($row->{ENDDATE}))+1 : 0; 
    # ends at beginning of next day.

    my $diffdays = $duedays - $startdays;

    my $sofardays = ($row->{PERCENT}/100*$diffdays);

    #

    # Handle out of bounds stuff (ie. if put in dates explicitly)
    my $spacer = $startdays < $mindays ? 0 : $startdays - $mindays;
    my $end = $duedays <= $maxdays-1 ? $duedays - $startdays + 1 : $maxdays - $startdays + 1;

    my $is_before = $startdays < $mindays;
    my $is_after = $maxdays < $duedays;

    my $md = Calendar->date(Calendar->day($mindays));
    my $sd = Calendar->date(Calendar->day($startdays));
    my $dd = Calendar->date(Calendar->day($duedays));

    if (not $row->{STARTDATE} or not $row->{ENDDATE})
    {
      push @data,
      {
        %row,
        SPACER=>0,
	DURATION=>0,
	TEXT=>" *** UNKNOWN *** ",
	# XXX TODO MAKE SURE TO ACCOMODATE ROOM FOR TEXT ***
      };
    } else {
      # These are all side by side, now.
      push @data,
      {
        %row,
        SPACER => int(($spacer)*$pixelsperday),
        DURATION => int(($end)*$pixelsperday),
        TEXT => "$row->{PERCENT}%",
	IS_BEFORE=>$is_before,
	IS_AFTER=>$is_after,
      };
    }

  }

  # Generate ruler (i.e., div tag)

  my @axis = ();

  for (my $i = $mindays; $i < $maxdays+$unit; $i+=$unit) # DO an extra one for the heck of it.
  {
    # Here we do some more stuff....
    # we should actually place this ruler between every X number of rows
    my $axis_value = $self->{GLOBAL}->{DATE}->get("dd.MON.yy", Calendar->day($i));
    push @axis, $axis_value;
  }

  my $axis_width = $div_width * scalar(@axis);

  $self->template_display("Analysis/Gantt/main", DATA=>\@data,
    AXIS=>\@axis,
    DIV_WIDTH=>int($div_width),
    AXIS_WIDTH=>int($axis_width),
    #GRAPH_WIDTH => int($axis_width+50), # For text display after row
    GRAPH_WIDTH => int($width+150),
    # OTHER INFO GOES HERE...
  );
}

sub render_gantt_gd
{
  my ($self, $title, @input) = @_;
  $title ||= "Gantt Chart";

  my ($mindays, $maxdays) = bound_days(map { ($_->{STARTDATE}, $_->{ENDDATE}) } @input);

  # Need to read LOTS Of options, will think of once the frameset renders correctly.

  my @labels = ();
  my @data = ();
  my @vals = ();

  # XXX TODO HERE display is off by a bit, kinda weird.
  # seems sometimes the start date is a day or two early diplayed.

  foreach my $row (@input)
  {
    # XXX TODO HANDLE OMITTED DATES
    # i.e, set value to 0, and display to "UNKNOWN"
    # DO SAME FOR BOUND_DAYS

    my $startdays = $row->{STARTDATE} ? Calendar->to_days(Calendar->date_in_secs($row->{STARTDATE}))+0 : 0;
    my $duedays = $row->{ENDDATE} ? Calendar->to_days(Calendar->date_in_secs($row->{ENDDATE}))+1 : 0; 
    # ends at beginning of next day.

    my $diffdays = $duedays - $startdays;

    my $sofardays = ($row->{PERCENT}/100*$diffdays);

    #

    $data[0]->[$i] = undef;
    my $spacer = $startdays - $mindays;
    my $sofar = $sofardays+$spacer;
    my $end = $duedays - $mindays; 

    $vals[0]->[$i] = undef;
    if (not $row->{STARTDATE} or not $row->{ENDDATE})
    {
      $data[1]->[$i] = '0';
      $vals[1]->[$i] = " *** UNKNOWN *** ";
    } else {
      $data[1]->[$i] = $spacer;
      $data[2]->[$i] = $sofar-$spacer;
      $data[3]->[$i] = $end-$sofar;
      $vals[1]->[$i] = sprintf "%s - %s (%u%%)", 
          Calendar->mdy_date(Calendar->date_in_secs($row->{STARTDATE})),
  	  Calendar->mdy_date(Calendar->date_in_secs($row->{ENDDATE})),
    	  $row->{PERCENT};

    }

    $i++;
  }

  # MATH CALCULATION DEPENDING ON DATA SPECS:
  # fgure y_tick_number (depends on width of chart!)
  # width of chart
  # height of chart (prolly ok as is)
  #
  # zooming, ALWAYS provide one to fit 400x300!!!!
  # then do multiples (1.5, 2, 4)

  # Need to figure out that are giving a certain number of pixels up/down per task.
  my $spacing = 58; # Pixels per task (row).

  my $count = scalar(@input);

  my $extra = 16+20; # Width of top and bottom....

  my $ticker_count = 10;  # XXX ALLOW AS PARAMETER...i.e., days per marker.

  my $graph = GD::Graph::bars->new(1000,$spacing*($count||4)+$extra);
  $graph->set_title_font(GD::Font->Small);
  $graph->set_y_label_font(GD::Font->Small);
  $graph->set_y_axis_font(GD::Font->Small);
  ####$graph->set_x_axis_font(GD::Font->Tiny);
  #$graph->{"gdta_x_axis"} = GD::Text::Wrap->new($graph->{graph}, align=>'left');
  $graph->set_values_font(GD::Font->Small);
  $graph->set_legend_font(GD::Font->Small);

  my $data = GD::Graph::Data->new(\@data);
  #my $values = $data->copy;
  my $values = GD::Graph::Data->new(\@vals);

  $graph->set(
    cumulate=>1,
    rotate_chart=>1,
    dclrs => [undef, qw(green red) ],
    borderclrs => [undef, undef, undef],
    x_label_position=>1,
    y_long_ticks=>1,
    x_long_ticks=>1,
    l_margin=>150,
    show_values=>$values,
    title=>$title,
    bar_spacing=>30,
    y_max_value=>$maxdays-$mindays,
    y_tick_number=>$ticker_count,
    y_number_format=>sub { day_axis_format($mindays, @_); },
  );

  my $gd = $graph->plot($data);

  # Now, insert labels!
  # XXX
  # Perhaps give colors per owner of a task, and provide legend at bottom.
  # XXX TODO
  my $starty = 75;
  my $black = $gd->colorAllocate(0,0,0);
  for (my $i = 0; $i < @input; $i++)
  {
    my $row = $input[$i];
    my $label = undef;

    if ($row->{MILE})
    {
      $label = "Mile $row->{ID}: $row->{TITLE}";
    } elsif ($row->{TASK}) {
      $label = "Task $row->{ID}: $row->{TITLE}";
    } else {
      $label = $row->{TITLE};
    }

    my $textbox = GD::Text::Wrap->new($gd, line_space=>0, color=>$black, text=>$label||"None");
    if ($row->{MILE})
    {
      $textbox->set_font(GD::Font->MediumBold);
    } elsif ($row->{TASK}) {
      $textbox->set_font(GD::Font->Small);
    } elsif ($row->{PROJECT}) {
      $textbox->set_font(GD::Font->Giant);
    }
    $textbox->set(align=>'left', width=>130);
    $textbox->draw(10, $starty);
    $gd->rectangle($textbox->get_bounds(5, $starty), $black);
    $starty+= $spacing-1; 
  }

  # NOW, INSERT tickers at top (and perhaps ever certain number of rows)
  # XXX

  my $format = $graph->export_format();

  my $filename = "$title.$format";

  print "Content-type: image/$format\n";
  print "Content-Disposition: inline; filename=$filename\n";
  print "\n";
  print $gd->$format();
  exit;
}

sub day_axis_format
{
  my ($mindays, $offset) = @_;
  return undef if (not defined $offset or $offset eq '');
  my $days = $mindays+int($offset);
  my $secs = Calendar->day($days);
  return Calendar->mdy_date($secs);
}

sub bloke
{

  if ($mode eq 'Gantt') {
    my $pstart = $project->get("STARTDATE");
    my $pstart_in_secs = Calendar->date_in_secs($pstart);
    my $pend = $project->get("ENDDATE");
    my $pend_in_secs = Calendar->date_in_secs($pend);


    $self->user_error("BOTH Project Start and End Dates must be set","Javascript:window.close()") unless $pstart ne '' and $pend ne '';

    my $unit = $self->get("UNIT") || 7; # Number of days per divider.
    my $div_width = $self->get("DIV_WIDTH")||'70';
    my $pixels_per_day = $div_width / $unit; # As we show a week!
    my $total_days = Calendar->to_days( Calendar->between($pend, $pstart) + Calendar->day($unit*2), 1);

    my $view_start = $pstart_in_secs - Calendar->day($unit);
    my $view_end = $pend_in_secs + Calendar->day($unit);

    if ($self->get("FIT"))
    {
      # Width is 400 for timeline.
      $pixels_per_day = 550 / $total_days;
      $unit = $total_days / 8; # Will show 8 divisors.
      $div_width = $unit * $pixels_per_day;
    }



    my @axis = ();
    # Later on, adjust to increment by a day if less than a week and by a month if ....
    for (my $x = $view_start; $x < $view_end; $x+= Calendar->day($unit))
    {
      my $axis_value = $self->{GLOBAL}->{DATE}->get("dd.MON", $x);
      push @axis, $axis_value;
    }

    $axis_width = $div_width * scalar(@axis);

    if ($self->get("HEADER"))
    {
      $self->template_display("Analysis/gantt_header", $project->hash,
        TOTAL_AXIS_WIDTH=>$axis_width,
        AXIS_DIVIDER_WIDTH=>$div_width,
        AXIS=>\@axis);
    } elsif ($self->get("MAIN")) {
  
  
      # Need to calculate 
      # how many days correspond to a certain number of pixels.
      #my $pixels_per_day = $width / ($total_days || 1);
  
      # Need to know number of days since project start, as well as how many days per milestone and task.
      my $mile = $project->get("MILESTONES");
      # If there is no start/end date, it WILL NOT BE DISPLAYED....
      for ($mile->first; $mile->more; $mile->next)
      {
        my $mile_start = $mile->get("STARTDATE");
        my $mile_end = $mile->get("ENDDATE");
  
        if ($mile_start ne '' and $mile_end ne '')
        {
          my $previous_days = Calendar->to_days( Calendar->between($mile_start, $pstart), 1);
          my $duration_days = Calendar->to_days( Calendar->between($mile_start, $mile_end), 1);
  	$mile->set_unchecked("PREVIOUS_WIDTH", int($previous_days * $pixels_per_day));
  	$mile->set_unchecked("DURATION_WIDTH", int($duration_days * $pixels_per_day));
        }
  
        # Now do tasks.
        my $tasks = $mile->get("TASKS");
        for ($tasks->first; $tasks->more; $tasks->next)
        {
          my $tstart = $tasks->get("STARTDATE");
  	  # prefer actual, then estimated, then due.
  	  my $tend = $tasks->get("ACTCOMDATE") || $tasks->get("ESTCOMDATE") || $tasks->get("DUEDATE");
	  my $wrapped_title = $tasks->get("TITLE");
	  $wrapped_title =~ s/([\w]{15})/\1 /g;
	  $tasks->set_unchecked("WRAPPED_TITLE", $wrapped_title);
  	  if ($tstart ne '' and $tend ne '')
          {
            my $previous_days = Calendar->to_days( Calendar->between($tstart, $pstart), 1);
            my $duration_days = Calendar->to_days( Calendar->between($tstart, $tend), 1);
  	    $tasks->set_unchecked("PREVIOUS_WIDTH", int($previous_days * $pixels_per_day));
  	    $tasks->set_unchecked("DURATION_WIDTH", int($duration_days * $pixels_per_day));
    	  }
        }
      }
  
      # Now do tasks w/o a milestone.... (ADD TO DISPLAY TOO!!!)
      my $tasks = $project->get("FLOATING_TASKS");
      for ($tasks->first; $tasks->more; $tasks->next)
      {
        my $tstart = $tasks->get("STARTDATE");
        # prefer actual, then estimated, then due.
        my $tend = $tasks->get("ACTCOMDATE") || $tasks->get("ESTCOMDATE") || $tasks->get("DUEDATE");
	my $wrapped_title = $tasks->get("TITLE");
	$wrapped_title =~ s/([\w]{15})/\1 /g;
	$tasks->set_unchecked("WRAPPED_TITLE", $wrapped_title);
        if ($tstart ne '' and $tend ne '')
        {
          my $previous_days = Calendar->to_days( Calendar->between($tstart, $pstart), 1);
          my $duration_days = Calendar->to_days( Calendar->between($tstart, $tend), 1);
          $tasks->set_unchecked("PREVIOUS_WIDTH", int($previous_days * $pixels_per_day));
          $tasks->set_unchecked("DURATION_WIDTH", int($duration_days * $pixels_per_day));
        }
      }

      $self->template_display("Analysis/gantt_main", $project->hash, TOTAL_AXIS_WIDTH=>$axis_width);
    } else {
      $self->template_display("Analysis/gantt_frameset", PID=>$pid);
    }
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


