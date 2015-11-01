####################
package Product;

use lib "../../MalyCGI";
use base "MalyDBO";
use ProductVersion;
use User;
use Resources;
use FeatureRequest;
use Competitor;

sub subclass_init
{
  return ("products", "prod_id");
}

sub db2cgi
{
  my ($self) = @_;
  return
  (
    VERSIONS=>[ ProductVersion->new(), "PROD_ID", "PROD_ID" ],
    MANAGER=>[ User->new(), "MANAGER_UID", "UID" ],
    RESOURCES=>[ Resources->new(), "PID", "PID" ],
    FEATURE_REQUESTS=>[ FeatureRequest->new(), "PROD_ID", "PROD_ID" ],
    COMPETITORS=>[ Competitor->new(), "PROD_ID", "PROD_ID" ],
  );
}

sub get_name
{
  my ($self, $value) = @_;

  my $name = undef;

  my ($prod_id, $ver_id) = split(":", $value);
  if ($prod_id ne '')
  {
    my $product = Product->search(PROD_ID=>$prod_id);
    $name = $product->get("NAME");
    if ($ver_id ne '')
    {
      my $version = ProductVersion->search(PROD_ID=>$prod_id, VER_ID=>$ver_id);
      my ($ver_name, $ver_alias) = $version->get("VER_NAME", "VER_ALIAS");
      $name .= " $ver_name ";
      $name .= "($ver_alias)" if ($ver_alias);
    }
  }
  return $name;
}

1;
