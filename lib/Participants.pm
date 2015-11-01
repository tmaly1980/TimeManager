####################
package Participants;

use lib "../MalyCGI";
use base "MalyDBO";
use Data::Dumper;
use User;

sub subclass_init
{
  return ("participants", "party_id");
}

sub db2cgi
{
  my ($self) = @_;

  return
  (
    USER=>[ User->new(), "UID", "UID" ],
  );
}

1;
