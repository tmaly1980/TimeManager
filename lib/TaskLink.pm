####################
package TaskLink;

use lib "../../MalyCGI";
use base "MalyDBO";

sub subclass_init
{
  return ("task_link", "link_id");
}

sub db2cgi
{
  my ($self) = @_;

  return
  (
  );
}

1;
