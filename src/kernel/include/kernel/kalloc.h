#ifndef KERNEL_KALLOC_H
#define KERNEL_KALLOC_H

void *kalloc(void);
void kfree(void *);
void kinit(void);

#endif // KERNEL_KALLOC_H
