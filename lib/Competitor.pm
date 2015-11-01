####################
package Competitor;

use lib "../../MalyCGI";
use base "MalyDBO";
use CompetitorFeatures;

sub subclass_init
{
  return ("competitors", "comp_id");
}

sub db2cgi
{
  my ($self) = @_;
  return
  (
    FEATURES=>[ CompetitorFeatures->new(), "COMP_ID", "COMP_ID" ],
  );
}

1;
