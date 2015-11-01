####################
package ProductSysReqModules;

use lib "../../MalyCGI";
use base "MalyDBO";

sub subclass_init
{
  return ("product_sysreq_modules", "module_id");
}

sub db2cgi
{
  my ($self) = @_;
  return
  (
  );
}

1;
