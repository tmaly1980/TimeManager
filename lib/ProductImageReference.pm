####################
package ProductImageReference;

use lib "../../MalyCGI";
use base "MalyDBO";

sub subclass_init
{
  return ("image_reference", "iref_id");
}

sub db2cgi
{
  my ($self) = @_;
  return
  (
  );
}

1;
