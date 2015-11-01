####################
package ProductTutorial;

use lib "../../MalyCGI";
use base "MalyDBO";
use ProductTutorialStep;

sub subclass_init
{
  return ("product_tutorials", "tutorial_id");
}

sub db2cgi
{
  my ($self) = @_;
  return
  (
    STEPS=>[ ProductTutorialStep->new(), "TUTORIAL_ID", "TUTORIAL_ID" ],
  );
}

1;
