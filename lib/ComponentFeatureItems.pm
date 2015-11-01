####################
package ComponentFeatureItems;

use lib "../../MalyCGI";
use base "MalyDBO";

sub subclass_init
{
  return ("feature_items", "fitem_id");
}

sub db2cgi
{
  my ($self) = @_;
  return
  (
  );
}

1;
