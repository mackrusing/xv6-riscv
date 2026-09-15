# directories for kernel and user source directories
K=kernel
U=user

# all kernel object files
OBJS = \
	$K/entry.o \
	$K/start.o \
	$K/console.o \
	$K/printk.o \
	$K/uart.o \
	$K/kalloc.o \
	$K/spinlock.o \
	$K/string.o \
	$K/main.o \
	$K/vm.o \
	$K/proc.o \
	$K/swtch.o \
	$K/trampoline.o \
	$K/trap.o \
	$K/syscall.o \
	$K/sysproc.o \
	$K/bio.o \
	$K/fs.o \
	$K/log.o \
	$K/sleeplock.o \
	$K/file.o \
	$K/pipe.o \
	$K/exec.o \
	$K/sysfile.o \
	$K/kernelvec.o \
	$K/plic.o \
	$K/virtio_disk.o \

# all user object files
ULIB = \
	$U/ulib.o \
	$U/usys.o \
	$U/printf.o \
	$U/umalloc.o \

# all user program executables
UPROGS= \
	$U/_cat \
	$U/_echo \
	$U/_forktest \
	$U/_grep \
	$U/_init \
	$U/_kill \
	$U/_ln \
	$U/_ls \
	$U/_mkdir \
	$U/_rm \
	$U/_sh \
	$U/_stressfs \
	$U/_usertests \
	$U/_grind \
	$U/_wc \
	$U/_zombie \
	$U/_logstress \
	$U/_forphan \
	$U/_dorphan \
	$U/_sync \

# prefix for compiler, linker, etc
# TOOLPREFIX = riscv64-unknown-elf-

# try to guess prefix if not set
ifndef TOOLPREFIX
TOOLPREFIX := $(shell if riscv64-unknown-elf-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
	then echo 'riscv64-unknown-elf-'; \
	elif riscv64-elf-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
	then echo 'riscv64-elf-'; \
	elif riscv64-none-elf-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
	then echo 'riscv64-none-elf-'; \
	elif riscv64-linux-gnu-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
	then echo 'riscv64-linux-gnu-'; \
	elif riscv64-unknown-linux-gnu-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
	then echo 'riscv64-unknown-linux-gnu-'; \
	else echo "***" 1>&2; \
	echo "*** Error: Couldn't find a riscv64 version of GCC/binutils." 1>&2; \
	echo "*** To turn off this error, run 'gmake TOOLPREFIX= ...'." 1>&2; \
	echo "***" 1>&2; exit 1; fi)
endif

# qemu
QEMU = qemu-system-riscv64
MIN_QEMU_VERSION = 7.2

# compiler toolchain
CC = $(TOOLPREFIX)gcc
LD = $(TOOLPREFIX)ld
OBJCOPY = $(TOOLPREFIX)objcopy
OBJDUMP = $(TOOLPREFIX)objdump

# flags for deterministic builds
DETFLAGS = -ffile-prefix-map=$(CURDIR)=.

# regular compiler toolchain flags
CFLAGS = -Wall -Werror -Wno-unknown-attributes -O -fno-omit-frame-pointer -ggdb -gdwarf-2
CFLAGS += $(DETFLAGS)
CFLAGS += -march=rv64gc
CFLAGS += -std=gnu99
CFLAGS += -MD # generate .d files alongside .o that list includes (dependencies)
CFLAGS += -mcmodel=medany
CFLAGS += -ffreestanding
CFLAGS += -fno-common -nostdlib
CFLAGS += -fno-builtin-strncpy -fno-builtin-strncmp -fno-builtin-strlen -fno-builtin-memset
CFLAGS += -fno-builtin-memmove -fno-builtin-memcmp -fno-builtin-log -fno-builtin-bzero
CFLAGS += -fno-builtin-strchr -fno-builtin-exit -fno-builtin-malloc -fno-builtin-putc
CFLAGS += -fno-builtin-free
CFLAGS += -fno-builtin-memcpy -Wno-main
CFLAGS += -fno-builtin-printf -fno-builtin-fprintf -fno-builtin-vprintf
CFLAGS += -I.
CFLAGS += $(shell $(CC) -fno-stack-protector -E -x c /dev/null >/dev/null 2>&1 && echo -fno-stack-protector)

# disable position independent executables when possible
ifneq ($(shell $(CC) -dumpspecs 2>/dev/null | grep -e '[^f]no-pie'),)
CFLAGS += -fno-pie -no-pie
endif
ifneq ($(shell $(CC) -dumpspecs 2>/dev/null | grep -e '[^f]nopie'),)
CFLAGS += -fno-pie -nopie
endif

# linker flags
LDFLAGS = -z max-page-size=4096

# unique gdb port
GDBPORT = $(shell expr `id -u` % 5000 + 25000)

# set correct gdb-stub option for qemu
QEMUGDB = $(shell if $(QEMU) -help | grep -q '^-gdb'; \
	then echo "-gdb tcp::$(GDBPORT)"; \
	else echo "-s -p $(GDBPORT)"; fi)

# number of cpus to emulate
ifndef CPUS
CPUS := 3
endif

# options for the emulator
QEMUOPTS = -machine virt -bios none -kernel $K/kernel -m 128M -smp $(CPUS) -nographic
QEMUOPTS += -global virtio-mmio.force-legacy=false
QEMUOPTS += -drive file=fs.img,if=none,format=raw,id=x0
QEMUOPTS += -device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0

# grab qemu's version
QEMU_VERSION := $(shell $(QEMU) --version | head -n 1 | sed -E 's/^QEMU emulator version ([0-9]+\.[0-9]+)\..*/\1/')

# non-file related rules
.PHONY: all clean fmt qemu qemu-gdb check-qemu-version print-gdbport

# prevent deletion of intermediate files
.PRECIOUS: %.o

# default rule
all: $K/kernel

# remove build artifacts
clean:
	rm -f *.tex *.dvi *.idx *.aux *.log *.ind *.ilg \
	*/*.o */*.d */*.asm */*.sym \
	$K/kernel fs.img \
	mkfs/mkfs .gdbinit \
        $U/usys.S \
	$(UPROGS)

# format source files
fmt:
	clang-format -i $(wildcard kernel/*.[ch] user/*.[ch] mkfs/*.c)

# run the emulator
qemu: check-qemu-version $K/kernel fs.img
	$(QEMU) $(QEMUOPTS)

# run the emulator but stop before first instruction and allow gdb to attach
qemu-gdb: check-qemu-version $K/kernel fs.img .gdbinit
	@echo "*** Now run 'gdb' in another window." 1>&2
	$(QEMU) $(QEMUOPTS) -S $(QEMUGDB)

# ensure emulator version is correct
check-qemu-version:
	@if [ "$(shell echo "$(QEMU_VERSION) >= $(MIN_QEMU_VERSION)" | bc)" -eq 0 ]; then \
		echo "ERROR: Need qemu version >= $(MIN_QEMU_VERSION)"; \
		exit 1; \
	fi

# print the generated gdb port
print-gdbport:
	@echo $(GDBPORT)

# build kernel from linker script (and provide disassembly and symbols file)
$K/kernel: $(OBJS) $K/kernel.ld
	$(LD) $(LDFLAGS) -T $K/kernel.ld -o $K/kernel $(OBJS)
	$(OBJDUMP) -S $K/kernel > $K/kernel.asm
	$(OBJDUMP) -t $K/kernel | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $K/kernel.sym

# build kernel assembly files into object files
$K/%.o: $K/%.S
	$(CC) -march=rv64gc -g $(DETFLAGS) -c -o $@ $<

# build user executables using linker script (and provide disassembly and
# symbols file)
_%: %.o $(ULIB) $U/user.ld
	$(LD) $(LDFLAGS) -T $U/user.ld -o $@ $< $(ULIB)
	$(OBJDUMP) -S $@ > $*.asm
	$(OBJDUMP) -t $@ | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $*.sym

# generate syscalls assembly from perl file
$U/usys.S : $U/usys.pl
	perl $U/usys.pl > $U/usys.S

# compile the generated syscall assembly into object file
$U/usys.o : $U/usys.S
	$(CC) $(CFLAGS) -c -o $U/usys.o $U/usys.S

# compile forktest bin (and provide disassembly) with less of library code to
# save on space in order to max out proc table
$U/_forktest: $U/forktest.o $(ULIB)
	$(LD) $(LDFLAGS) -N -e main -Ttext 0 -o $U/_forktest $U/forktest.o $U/ulib.o $U/usys.o
	$(OBJDUMP) -S $U/_forktest > $U/forktest.asm

# create the mkfs executable with host toolchain
mkfs/mkfs: mkfs/mkfs.c $K/fs.h $K/param.h
	gcc -Wno-unknown-attributes -I. -o mkfs/mkfs mkfs/mkfs.c

# create the disk image
fs.img: mkfs/mkfs README $(UPROGS)
	mkfs/mkfs fs.img README $(UPROGS)

# create gdb init file from template
.gdbinit: .gdbinit.tmpl-riscv
	sed "s/:1234/:$(GDBPORT)/" < $^ > $@

# load dependency files
-include kernel/*.d user/*.d
