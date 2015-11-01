####################
package WebReferences;

use lib "../../MalyCGI";
use base "MalyDBO";

sub subclass_init
{
  return ("web_references", "webref_id");
}

1;
