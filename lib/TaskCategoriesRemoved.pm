####################
package TaskCategoriesRemoved;

use lib "../../MalyCGI";
use base "MalyDBO";

sub subclass_init
{
  return ("task_categories_removed", "tcid");
}

sub db2cgi
{
  my ($self) = @_;

  return
  (
  );
}

1;
