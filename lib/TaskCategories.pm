####################
package TaskCategories;

use lib "../../MalyCGI";
use base "MalyDBO";
use Group;
use TaskCategoryStage;

sub subclass_init
{
  return ("task_categories", "tcid");
}

sub db2cgi
{
  my ($self) = @_;

  return
  (
    GROUP=>[ Group->new(), "GID", "GID" ],
    XNAME=>[ sub { $_[0] =~ s/['"]//g; $_[0] }, "#NAME#" ],
    STAGES=>[ TaskCategoryStage->new(), "TCID", "TCID" ],
  );
}

1;
