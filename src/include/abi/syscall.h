/// @file
/// @brief System call numbers.
///
/// All the system call numbers as defined in `abi/syscalls.def`.

#ifndef ABI_SYSCALL_H
#define ABI_SYSCALL_H

/// @brief System call numbers, derived from `abi/syscalls.def`.
enum sysno {
#define SYSCALL(num, name, ...) SYS_##name = num,
#include <abi/syscalls.def>
#undef SYSCALL
};

#endif // ABI_SYSCALL_H
