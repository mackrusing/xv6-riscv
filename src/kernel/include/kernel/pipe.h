#ifndef KERNEL_PIPE_H
#define KERNEL_PIPE_H

#include <abi/types.h>

struct file;
struct pipe;

int pipealloc(struct file **, struct file **);
void pipeclose(struct pipe *, int);
int piperead(struct pipe *, uint64, int);
int pipewrite(struct pipe *, uint64, int);

#endif // KERNEL_PIPE_H
