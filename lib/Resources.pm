####################
package Resources;

use lib "../../MalyCGI";
use base "MalyDBO";

sub subclass_init
{
  return ("resources", "res_id");
}

1;
