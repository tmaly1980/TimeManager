####################
package ComponentFeatures;

use lib "../../MalyCGI";
use base "MalyDBO";
use ComponentFeatureItems;
use DBOFactory;

sub subclass_init
{
  return ("component_features", "cfeature_id");
}

sub db2cgi
{
  my ($self) = @_;
  return
  (
    ITEMS=>[ ComponentFeatureItems->new(), "CFEATURE_ID", "CFEATURE_ID" ],
    OVERVIEW=>[ DBOFactory->new("PRODUCT_FEATURE_OVERVIEW"), "CFEATURE_ID", "CFEATURE_ID" ],
    HOWTO=>[ DBOFactory->new("PRODUCT_FEATURE_HOWTO"), "CFEATURE_ID", "CFEATURE_ID" ],
  );
}

1;
