#ifndef ABI_FS_H
#define ABI_FS_H

#include <abi/types.h>

// Directory is a file containing a sequence of dirent structures.
#define DIRSIZ 14

// The name field may have DIRSIZ characters and not end in a NUL
// character.
struct dirent {
  ushort inum;
  char name[DIRSIZ] __attribute__((nonstring));
};

#endif // ABI_FS_H
