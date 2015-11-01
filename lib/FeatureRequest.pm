####################
package FeatureRequest;

use lib "../../MalyCGI";
use base "MalyDBO";
use Product;
use ProductVersion;

sub subclass_init
{
  return ("feature_request", "req_id");
}

sub db2cgi
{
  my ($self) = @_;
  return
  (
    PRODUCT=>[ Product->new(), "PROD_ID", "PROD_ID" ],
    VERSION=>[ ProductVersion->new(), "VER_ID", "VER_ID" ],
  );
}

1;
