#!/usr/bin/perl

my $cgi = TMIndex->new(PATH_INFO_KEYS=>[qw/mode tid/],DBO=>1,RESTRICTED=>1);

package TMIndex;

use lib "../lib";
use base "TMCGI";

# Figure out what user prefs are and go to there?

sub process
{
  my ($self) = @_;
  $self->redirect("cgi-bin/Dash.pl");
}
