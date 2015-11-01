####################
package ProductTutorialStep;

use lib "../../MalyCGI";
use base "MalyDBO";
use ProductImageReference;
use ProductImage;

sub subclass_init
{
  return ("product_tutorial_steps", "step_id");
}

sub db2cgi
{
  my ($self) = @_;
  return
  (
    IMAGE_ID=>[ ProductImageReference->new(), "STEP_ID", "KEY_VALUE", "TABLE_NAME", "product_tutorial_steps"],
    IMAGES=>[ PoductImage->new(), "IMAGE_ID{IMAGE_ID}", "IMAGE_ID" ],
  );
}

1;
