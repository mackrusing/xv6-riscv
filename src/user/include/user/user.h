#ifndef USER_USER_H
#define USER_USER_H

#include <abi/stat.h>
#include <abi/types.h>

#define SBRK_ERROR ((char *)-1)

// system calls, generated from abi/syscalls.def
#define SYSCALL(num, name, stub, ret, params) ret stub params;
#include <abi/syscalls.def>
#undef SYSCALL

int exit(int) __attribute__((noreturn));

// ulib.c
int stat(const char *, struct stat *);
char *strcpy(char *, const char *);
void *memmove(void *, const void *, int);
char *strchr(const char *, char c);
int strcmp(const char *, const char *);
char *gets(char *, int max);
uint strlen(const char *);
void *memset(void *, int, uint);
int atoi(const char *);
int memcmp(const void *, const void *, uint);
void *memcpy(void *, const void *, uint);
char *sbrk(int);
char *sbrklazy(int);

// printf.c
void fprintf(int, const char *, ...) __attribute__((format(printf, 2, 3)));
void printf(const char *, ...) __attribute__((format(printf, 1, 2)));

// umalloc.c
void *malloc(uint);
void free(void *);

#endif // USER_USER_H
