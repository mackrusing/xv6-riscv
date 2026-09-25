// Create a zombie process that
// must be reparented at exit.

#include <abi/types.h>
#include <abi/stat.h>
#include <user/user.h>

int
main(void)
{
  if (fork() > 0)
    pause(5); // Let child exit before parent.
  exit(0);
}
