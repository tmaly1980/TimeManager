package MalyDate; # Date conversion et al.

use base "MalyDBOCore";

our $DEFAULT_DATE_FORMAT = "month/day/year";
our $DEFAULT_TIME_FORMAT = "hour:minute:second ampm";
our $DEFAULT_TIMESTAMP_FORMAT = "month/day/year hour:minute:second ampm";
our $DEFAULT_WORDED_TIMESTAMP_FORMAT = "monthname dayTH, year hour:minute:second ampm";
our @MONTHNAMES = qw(January February March April May June July August September October November December);
our @ABBREV_MONTHNAMES = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
our @DATE_APPEND = qw(th st nd rd th th th th th th);

sub new
{
  my ($this, $globals) = @_;
  my $class = ref($this)||$this;
  $self = bless {}, $class;
  $self->{GLOBAL} = $globals;
  return $self;
}

sub get
{
  my ($self, $format, $time) = @_;
  $time ||= time();
  my $date=$self->format_localtime($format, localtime($time));
  return $date;
}

sub count { return 1; } # fOR MALYdbocore compliance.

sub unix_timestamp_to_cgi
{
  my ($self, $time, $format) = @_;
  $time ||= time();

  $format ||= $self->{GLOBAL}->{DATE_FORMAT};
  $format ||= $DEFAULT_TIMESTAMP_FORMAT;

  my ($s, $min, $h, $d, $mon, $y) = localtime($time);
  my $time = $self->format_localtime($format, $s, $min, $h, $d, $mon, $y);
  return $time;
}

sub format_localtime
{
  my ($self, $format, $s, $min, $h, $d, $mon, $y) = @_;

  $s = sprintf "%02u", $s;
  $min = sprintf "%02u", $min;
  $h = sprintf "%02u", $h;
  $d = sprintf "%02u", $d;
  my $monthname = $MONTHNAMES[$mon];
  my $monab = $ABBREV_MONTHNAMES[$mon];
  $mon = sprintf "%02u", $mon+1;
  $y = sprintf "%04u", $y+1900;
  my $yy = $y;
  $yy =~ s/^\d{2}//g;

  my $outstamp = $format;

  $outstamp =~ s/year/$y/g;
  $outstamp =~ s/yyyy/$y/gi;
  $outstamp =~ s/yy/$yy/gi;
  $outstamp =~ s/monthname/$monthname/gi;
  $outstamp =~ s/month/$mon/g;
  $outstamp =~ s/mm/$mon/gi;
  $outstamp =~ s/mon/lc($monab)/ge;
  $outstamp =~ s/Mon/ucfirst($monab)/ge;
  $outstamp =~ s/MON/uc($monab)/ge;
  $outstamp =~ s/dayTH/$d$DATE_APPEND[$d%10]/g;
  $outstamp =~ s/day/$d/gi;
  $outstamp =~ s/dd/$d/gi;

  if ($outstamp =~ /ampm/)
  {
    my ($ampm, $hour) = $h > 12 ? ("pm", $h-12) : ("am", ($h||12)); # 00 will show up as 12am
    $outstamp =~ s/ampm/$ampm/g;
    $outstamp =~ s/hour/$hour/g;
  } 
  elsif ($outstamp =~ /AMPM/)
  {
    my ($ampm, $hour) = $h > 12 ? ("PM", $h-12) : ("AM", ($h||12));
    $outstamp =~ s/AMPM/$ampm/g;
    $outstamp =~ s/hour/$hour/g;
  } else {
    $outstamp =~ s/hour/$h/g;
  }

  $outstamp =~ s/minute/$min/g;
  $outstamp =~ s/second/$s/g;

  if (wantarray) # Separate date from time.
  {
    my ($date, $time) = $outstamp =~ /(.+?)\s+(.*)/;
    return ($date, $time); # Tries to keep AM/PM with the time, but separate the date from time.
  } else {
    return $outstamp;
  }
}

sub sql_timestamp_to_cgi
{
  my ($self, $time, $format) = @_;
  $format ||= $self->{GLOBAL}->{DATE_FORMAT};
  $format ||= $DEFAULT_TIMESTAMP_FORMAT;
  my ($y, $mon, $d, $h, $min, $s) = $time =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/;
  $self->format_localtime($format, $s, $min, $h, $d, $mon-1, $y-1900);
}

sub sql_datetime_to_cgi
{
  my ($self, $time, $format) = @_;
  $format ||= $self->{GLOBAL}->{DATE_FORMAT};
  $format ||= $DEFAULT_TIMESTAMP_FORMAT;
  my ($y, $mon, $d, $h, $min, $s) = $time =~ /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/;
  $self->format_localtime($format, $s, $min, $h, $d, $mon, $y);
}

sub sql_date_to_cgi
{
  my ($self, $time, $format) = @_;
  $format ||= $self->{GLOBAL}->{DATE_FORMAT};
  $format ||= "month/day/year hour:minute:second ampm";
  my ($y, $mon, $d) = $time =~ /^(\d{4})-(\d{2})-(\d{2})/;
  $self->format_localtime($format, undef, undef, undef, $d, $mon, $y);
}

sub sql_time_to_cgi { shift->hour_24_to_12(@_); }

sub hour_24_to_12
{
  my $format = $self->{GLOBAL}->{DATE_FORMAT} || $DEFAULT_TIMESTAMP_FORMAT;
  my ($h, $min, $s) = $time =~ /(\d{2}):(\d{2}):(\d{2})$/;
  $self->format_localtime($format, $s, $min, $h);
}

# Takes human readable date and converts to SQL format.
# i.e., turns '04/23/2003 05:30:32 PM' to '2003-04-23 17:30:32'
# May or may not have seconds or minutes&hours (may just be day
sub cgi_to_sql_datetime
{
  my ($self, $cgitime, $format) = @_;
  $format = $self->{GLOBAL}->{DATE_FORMAT};
  $format ||= $DEFAULT_TIMESTAMP_FORMAT;

  my @format_parts = split(/[\/:-] /, $format);
  my @cgitime_parts = split(/[\/:-] /, $cgitime);

  my %d = ();

  for (my $i = 0; $i < @format_parts; $i++)
  {
    if ($format_parts[$i] =~ /^(year|month|day|hour|minute|second|ampm)$/)
    {
      $d{$1} = $cgitime_parts[$i];
    }
  }

  $d{hour} += 12 if ($d{ampm} eq 'PM'); # Convert to 24-hour

  my $datetime = sprintf "%04u-%02u-%02u %02u:%02u:%02u", $d{year}, $d{month}, $d{day}, $d{hour}, $d{minute}, $d{second};
  if (wantarray)
  {
    return split(/\s+/, $datetime);
  } else {
    return $datetime;
  }
}

1;
