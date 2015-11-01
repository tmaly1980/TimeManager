####################
package Goals;

use lib "../../MalyCGI";
use base "MalyDBO";

sub subclass_init
{
  return ("goals", "goal_id");
}

sub db2cgi
{
  my ($self) = @_;
  return
  (
  );
}

1;
