####################
package Shortcut;

use lib "../../MalyCGI";
use base "MalyDBO";
use MalyDBO;

sub subclass_init
{
  return ("shortcuts", "shid");
}

1;
