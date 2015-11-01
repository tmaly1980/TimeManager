####################
package GroupMembership;

use lib "../../MalyCGI";
use base "MalyDBO";
use MalyDBO;

sub subclass_init
{
  return ("group_members", "membership_id");
}

1;
