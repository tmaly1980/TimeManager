####################
package Group;

use lib "../../MalyCGI";
use base "MalyDBO";
use MalyDBO;
use GroupMembership;
use User;
use TaskCategories;

sub subclass_init
{
  return ("groups", "gid");
}

sub db2cgi
{
  my ($self) = @_;
  return
  (
    MEMBER_UIDS=>[ GroupMembership->new(), "GID", "GID" ],
    MEMBERS=>[ User->new(), "MEMBER_UIDS{UID}", "UID" ], # Query, where User{UID} in MEMBER_UIDS{UID} list.
    MANAGER=>[ User->new(), "MANAGER_UID", "UID" ],
    TASK_CATEGORIES=>[ TaskCategories->new(), "GID", "GID" ],
  );
}

1;
