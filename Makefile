# directories for kernel and user source directories
K := kernel
U := user
M := mkfs

# build directory
B := build

# all kernel objects
K_OBJS := \
	entry \
	start \
	console \
	printk \
	uart \
	kalloc \
	spinlock \
	string \
	main \
	vm \
	proc \
	swtch \
	trampoline \
	trap \
	syscall \
	sysproc \
	bio \
	fs \
	log \
	sleeplock \
	file \
	pipe \
	exec \
	sysfile \
	kernelvec \
	plic \
	virtio_disk
K_OBJS := $(addsuffix .o,$(K_OBJS))
K_OBJS := $(addprefix $B/$K/,$(K_OBJS))

# the kernel executable
KERNEL := $B/$K/kernel

# all user objects
U_OBJS := \
	ulib \
	usys \
	printf \
	umalloc
U_OBJS := $(addsuffix .o,$(U_OBJS))
U_OBJS := $(addprefix $B/$U/,$(U_OBJS))

# all user binary programs
U_BINS := \
	cat \
	echo \
	forktest \
	grep \
	init \
	kill \
	ln \
	ls \
	mkdir \
	rm \
	sh \
	stressfs \
	usertests \
	grind \
	wc \
	zombie \
	logstress \
	forphan \
	dorphan \
	sync
U_BINS := $(addprefix $B/$U/_,$(U_BINS))

# the executable used to create the filesystem
MKFS := $B/$M/mkfs

# the completed filesystem image
FS_IMG := $B/fs.img

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
QEMUOPTS = -machine virt -bios none -kernel $(KERNEL) -m 128M -smp $(CPUS) -nographic
QEMUOPTS += -global virtio-mmio.force-legacy=false
QEMUOPTS += -drive file=$(FS_IMG),if=none,format=raw,id=x0
QEMUOPTS += -device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0

# grab qemu's version
QEMU_VERSION := $(shell $(QEMU) --version | head -n 1 | sed -E 's/^QEMU emulator version ([0-9]+\.[0-9]+)\..*/\1/')

# non-file related rules
.PHONY: all clean fmt qemu qemu-gdb check-qemu-version print-gdbport

# prevent deletion of intermediate files
.PRECIOUS: $B/$K/%.o $B/$U/%.o

# default rule
all: $(KERNEL)

# remove build artifacts
clean:
	rm -rf $B .gdbinit

# format source files
fmt:
	clang-format -i $(wildcard $K/*.[ch] $U/*.[ch] $M/*.c)

# run the emulator
qemu: check-qemu-version $(KERNEL) $(FS_IMG)
	$(QEMU) $(QEMUOPTS)

# run the emulator but stop before first instruction and allow gdb to attach
qemu-gdb: check-qemu-version $(KERNEL) $(FS_IMG) .gdbinit
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
$(KERNEL): $(K_OBJS) $K/kernel.ld
	@mkdir -p $(@D)
	$(LD) $(LDFLAGS) -T $K/kernel.ld -o $@ $(K_OBJS)
	$(OBJDUMP) -S $@ > $B/$K/kernel.asm
	$(OBJDUMP) -t $@ | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $B/$K/kernel.sym

# build kernel c files into object files
$B/$K/%.o: $K/%.c
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) -c $< -o $@

# build kernel assembly files into object files
$B/$K/%.o: $K/%.S
	@mkdir -p $(@D)
	$(CC) -march=rv64gc -g $(DETFLAGS) -c -o $@ $<

# build user c files into object files
$B/$U/%.o: $U/%.c
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) -c $< -o $@

# build user executables using linker script (and provide disassembly and
# symbols file)
$B/$U/_%: $B/$U/%.o $(U_OBJS) $U/user.ld
	@mkdir -p $(@D)
	$(LD) $(LDFLAGS) -T $U/user.ld -o $@ $< $(U_OBJS)
	$(OBJDUMP) -S $@ > $B/$U/$*.asm
	$(OBJDUMP) -t $@ | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $B/$U/$*.sym

# generate syscalls assembly from perl file
$B/$U/usys.S: $U/usys.pl
	@mkdir -p $(@D)
	perl $< > $@

# compile the generated syscall assembly into object file
$B/$U/usys.o: $B/$U/usys.S
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) -c -o $@ $<

# compile forktest bin (and provide disassembly) with less of library code to
# save on space in order to max out proc table
$B/$U/_forktest: $B/$U/forktest.o $(U_OBJS)
	@mkdir -p $(@D)
	$(LD) $(LDFLAGS) -N -e main -Ttext 0 -o $@ $< $B/$U/ulib.o $B/$U/usys.o
	$(OBJDUMP) -S $@ > $B/$U/forktest.asm

# create the mkfs executable with host toolchain
$(MKFS): $M/mkfs.c $K/fs.h $K/param.h
	@mkdir -p $(@D)
	gcc -Wno-unknown-attributes -I. -o $@ $<

# create the disk image
$(FS_IMG): $(MKFS) README $(U_BINS)
	@mkdir -p $(@D)
	$< $@ README $(U_BINS)

# create gdb init file from template
.gdbinit: .gdbinit.tmpl-riscv
	sed "s/:1234/:$(GDBPORT)/; s|build/kernel/kernel|$(KERNEL)|" < $^ > $@

# load dependency files
-include $B/$K/*.d $B/$U/*.d
