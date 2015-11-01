####################
package Dependency;

use lib "../../MalyCGI";
use base "MalyDBO";
use Data::Dumper;

sub subclass_init
{
  return ("dependencies", ["tid", "dependent_tid"]);
}

1;
