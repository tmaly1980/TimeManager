####################
package Components;

use lib "../../MalyCGI";
use base "MalyDBO";
use ComponentFeatures;
use DBOFactory;

sub subclass_init
{
  return ("components", "component_id");
}

sub db2cgi
{
  my ($self) = @_;
  return
  (
    FEATURES=>[ ComponentFeatures->new(), "COMPONENT_ID", "COMPONENT_ID" ],
    GOALS=>[ Goals->new(), "COMPONENT_ID", "COMPONENT_ID" ],
    #ACCESS_IMAGES=>[DBOFactory->new("REFERENCE_IMAGES"), "COMPONENT_ID", "ACCESS_COMPONENT_ID" ],
    #OVERVIEW_IMAGES=>[DBOFactory->new("REFERENCE_IMAGES"), "COMPONENT_ID", "OVERVIEW_COMPONENT_ID" ],
    OVERVIEW_IMAGES=>[DBOFactory->new("COMPONENT_OVERVIEW"), "COMPONENT_ID", "COMPONENT_ID" ],
    ACCESS=>[ DBOFactory->new("COMPONENT_ACCESS"), "COMPONENT_ID", "COMPONENT_ID"],
  );
}

1;
