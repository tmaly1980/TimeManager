####################
package ProductAudience;

use lib "../../MalyCGI";
use base "MalyDBO";

sub subclass_init
{
  return ("product_audience", "audience_id");
}

sub db2cgi
{
  my ($self) = @_;
  return
  (
  );
}

1;
