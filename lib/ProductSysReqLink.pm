####################
package ProductSysReqLink;

use lib "../../MalyCGI";
use base "MalyDBO";

sub subclass_init
{
  return ("product_sysreq_link", "sysreq_link_id");
}

sub db2cgi
{
  my ($self) = @_;
  return
  (
  );
}

1;
