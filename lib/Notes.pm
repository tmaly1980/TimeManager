####################
package Notes;

use lib "../../MalyCGI";
use base "MalyDBO";

sub subclass_init
{
  return ("notes", "nid");
}

sub db2cgi
{
  my ($self) = @_;

  return
  (
    TIMESTAMP_FORMATTED=>[ sub { timestamp_formatted(@_) }, "#TIMESTAMP#" ],
    USER=>[ User->new(), "UID", "UID" ],
    HTML_TEXT=>[ sub { $self->html_format_text(@_) }, "#TEXT#" ],
  );
}

sub html_format_text
{
  my ($self, $text) = @_;
  $text =~ s/\n/<br>\n/g;
  $text;
}

sub timestamp_formatted
{
  my ($timestamp) = @_;
  my ($year, $month, $day, $hour, $minute, $second) = $timestamp =~ /(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/;
  return sprintf "%02u/%02u/%04u %02u:%02u:%02u", $month, $day, $year, $hour, $minute, $second;
}

1;
