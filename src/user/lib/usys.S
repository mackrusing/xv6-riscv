#define SYSCALL(num, name, stub, ...) .global stub; stub: li a7, num; ecall; ret;
#include <abi/syscalls.def>
