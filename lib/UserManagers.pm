####################
package UserManagers;

use lib "../../MalyCGI";
use base "MalyDBO";

sub subclass_init
{
  return ("user_managers", ["uid","manager_uid"]);
}

1;

