####################
package CompetitorFeatures;

use lib "../../MalyCGI";
use base "MalyDBO";

sub subclass_init
{
  return ("competitor_features", "compfeat_id");
}

sub db2cgi
{
  my ($self) = @_;
  return
  (
  );
}

1;
