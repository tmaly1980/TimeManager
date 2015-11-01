####################
package ProductSysReq;

use lib "../../MalyCGI";
use base "MalyDBO";
use DBOFactory;

sub subclass_init
{
  return ("product_sysreq", "sysreq_id");
}

sub db2cgi
{
  my ($self) = @_;
  return
  (
    PRODUCT_SYSREQ_OPTIONS=>[DBOFactory->new("PRODUCT_SYSREQ_OPTIONS"), "SYSREQ_ID", "SYSREQ_ID"],
  );
}

1;
