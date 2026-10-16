#ifndef KERNEL_SYSCALL_H
#define KERNEL_SYSCALL_H

#include <abi/types.h>

#define SYSCALL(num, name, ...) uint64 sys_##name(void);
#include <abi/syscalls.def>
#undef SYSCALL

#endif // KERNEL_SYSCALL_H
