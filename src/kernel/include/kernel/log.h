#ifndef KERNEL_LOG_H
#define KERNEL_LOG_H

struct buf;
struct superblock;

void initlog(int, struct superblock *);
void log_write(struct buf *);
void begin_op(void);
void end_op(void);

#endif // KERNEL_LOG_H
