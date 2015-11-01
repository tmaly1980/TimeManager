####################
package TaskCategoryStage;

use lib "../../MalyCGI";
use base "MalyDBO";

sub subclass_init
{
  return ("task_category_stage", "stage_id");
}

1;
