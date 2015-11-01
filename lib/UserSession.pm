####################
package UserSession;

use lib "../../MalyCGI";
use base "MalyDBO";
use Data::Dumper;

sub subclass_init
{
  return ("usersession", "usersession_id");
}

1;
