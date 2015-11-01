####################
package ProductVersion;

use lib "../../MalyCGI";
use base "MalyDBO";
use Goals;
use Components;
use ProductTutorial;
use ProductAudience;
use ProductSysReqLink;
use ProductSysReqModules;
use ProductSysReq;
use DBOFactory;

sub subclass_init
{
  return ("product_versions", "ver_id");
}

sub db2cgi
{
  my ($self) = @_;
  return
  (
    TUTORIALS=>[ DBOFactory->new("PRODUCT_TUTORIAL"), "VER_ID", "VER_ID" ],
    GOALS=>[ Goals->new(), "VER_ID", "VER_ID" ],
    COMPONENTS=>[ Components->new(), "VER_ID", "VER_ID" ],
    AUDIENCE=>[ ProductAudience->new(), "VER_ID", "VER_ID" ],
    SYSREQ_ID=>[ ProductSysReqLink->new(), "VER_ID", "VER_ID" ],
    SYSREQ=>[ ProductSysReq->new(), "SYSREQ_ID{SYSREQ_ID}", "SYSREQ_ID" ],
    SYSREQ_MODULES=>[ ProductSysReqModules->new(), "VER_ID", "VER_ID" ],
    PRODUCT_APPLICATIONS=>[ DBOFactory->new("PRODUCT_APPLICATIONS"), "VER_ID", "VER_ID" ],
    PRODUCT_INSTALLATION_STEP=>[ DBOFactory->new("PRODUCT_INSTALLATION_STEP"), "VER_ID", "VER_ID" ],
    PRODUCT_TERMINOLOGY=>[ DBOFactory->new("PRODUCT_TERMINOLOGY"), "VER_ID", "VER_ID" ],
    PRODUCT_ARCHITECTURE=>[ DBOFactory->new("PRODUCT_ARCHITECTURE"), "VER_ID", "VER_ID" ],
    IMAGE_META=>[ DBOFactory->new("IMAGE_META"), "VER_ID", "VER_ID" ],
    CUSTOMIZATION_SECTIONS=>[ DBOFactory->new("PRODUCT_CUSTOMIZATION_SECTION"), "VER_ID", "VER_ID" ],
    SCREENSHOTS=>[ DBOFactory->new("PRODUCT_SCREENSHOTS"), "VER_ID", "VER_ID" ],
  );
}

1;
