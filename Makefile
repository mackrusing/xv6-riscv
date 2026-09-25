# directories for kernel and user source directories (and tools dir)
K := kernel
U := user
T := tools

# build directory
B := build

# kernel linker script
K_LD := $K/kernel.ld

# all kernel objects (kernel)
K_OBJS := \
	bio \
	console \
	entry \
	exec \
	file \
	fs \
	kalloc \
	kernelvec \
	log \
	main \
	pipe \
	plic \
	printk \
	proc \
	sleeplock \
	spinlock \
	start \
	string \
	swtch \
	syscall \
	sysfile \
	sysproc \
	trampoline \
	trap \
	uart \
	virtio_disk \
	vm
K_OBJS := $(addsuffix .o,$(K_OBJS))
K_OBJS := $(addprefix $B/$K/,$(K_OBJS))

# the kernel executable
K_BIN := $B/$K/kernel

# user linker script
U_LD = $U/user.ld

# user library objects (user/lib)
U_LIB_OBJS := printf ulib umalloc usys
U_LIB_OBJS := $(addsuffix .o,$(U_LIB_OBJS))
U_LIB_OBJS := $(addprefix $B/$U/lib/,$(U_LIB_OBJS))

# all user program executables (user)
U_PROG_BINS := \
	cat \
	echo \
	grep \
	init \
	kill \
	ln \
	ls \
	mkdir \
	rm \
	sh \
	sync \
	wc
U_PROG_BINS := $(addprefix $B/$U/_,$(U_PROG_BINS))

# all user test executables (user/tests)
U_TEST_BINS := $(sort $(wildcard $U/tests/*.c))
U_TEST_BINS := $(patsubst $U/tests/%.c,$B/$U/tests/_%,$(U_TEST_BINS))

# the executable used to create the filesystem
TOOL_MKFS_DIR := $T/mkfs
TOOL_MKFS_BIN := $B/$(TOOL_MKFS_DIR)/mkfs

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

# compiler toolchain flags
CFLAGS = -Wall -Werror -Wno-unknown-attributes -Wno-main
CFLAGS += -O -fno-omit-frame-pointer -ggdb -gdwarf-2
CFLAGS += $(DETFLAGS)
CFLAGS += -MD
CFLAGS += -std=gnu99
CFLAGS += -march=rv64gc
CFLAGS += -mcmodel=medany
CFLAGS += -ffreestanding
CFLAGS += -fno-common -nostdlib
CFLAGS += -fno-builtin-strncpy -fno-builtin-strncmp -fno-builtin-strlen \
	-fno-builtin-memset -fno-builtin-memmove -fno-builtin-memcmp \
	-fno-builtin-log -fno-builtin-bzero -fno-builtin-strchr \
	-fno-builtin-exit -fno-builtin-malloc -fno-builtin-putc \
	-fno-builtin-free -fno-builtin-memcpy -fno-builtin-printf \
	-fno-builtin-fprintf -fno-builtin-vprintf
CFLAGS += $(shell $(CC) -fno-stack-protector -E -x c /dev/null >/dev/null 2>&1 && echo -fno-stack-protector)

# disable position independent executables when possible
ifneq ($(shell $(CC) -dumpspecs 2>/dev/null | grep -e '[^f]no-pie'),)
CFLAGS += -fno-pie -no-pie
endif
ifneq ($(shell $(CC) -dumpspecs 2>/dev/null | grep -e '[^f]nopie'),)
CFLAGS += -fno-pie -nopie
endif

# separate the flags for kernel and userspace code
K_CFLAGS = -Iinclude -Ikernel/include $(CFLAGS)
U_CFLAGS = -Iinclude -Iuser/include $(CFLAGS)

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
QEMUOPTS = -machine virt -bios none -kernel $(K_BIN) -m 128M -smp $(CPUS) -nographic
QEMUOPTS += -global virtio-mmio.force-legacy=false
QEMUOPTS += -drive file=$(FS_IMG),if=none,format=raw,id=x0
QEMUOPTS += -device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0

# grab qemu's version
QEMU_VERSION := $(shell $(QEMU) --version | head -n 1 | sed -E 's/^QEMU emulator version ([0-9]+\.[0-9]+)\..*/\1/')

# non-file related rules
.PHONY: all kernel user mkfs clean fmt qemu qemu-gdb check-qemu-version print-gdbport

# prevent deletion of intermediate files
.PRECIOUS: $B/$K/%.o $B/$U/%.o $B/$U/lib/%.o $B/$U/tests/%.o

# default rule
all: kernel

# helper rules
kernel: $(K_BIN)
user: $(U_PROG_BINS) $(U_TEST_BINS)
mkfs: $(TOOL_MKFS_BIN)

# remove build artifacts
clean:
	rm -rf $B .gdbinit

fmt:
	clang-format -i $(wildcard include/abi/*.h $K/include/kernel/*.h $K/*.c tools/mkfs/*.c $U/include/user/*.h $U/lib/*.c $U/tests/*.c $U/*.c)

# run the emulator
qemu: check-qemu-version $(K_BIN) $(FS_IMG)
	$(QEMU) $(QEMUOPTS)

# run the emulator but stop before first instruction and allow gdb to attach
qemu-gdb: check-qemu-version $(K_BIN) $(FS_IMG) .gdbinit
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

# build kernel executable using linker script (and provide disassembly and
# symbols files alongside it)
$(K_BIN): $(K_OBJS) $(K_LD)
	@mkdir -p $(@D)
	$(LD) $(LDFLAGS) -T $(K_LD) -o $@ $(K_OBJS)
	$(OBJDUMP) -S $@ > $(basename $@).asm
	$(OBJDUMP) -t $@ | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(basename $@).sym

# build kernel object files from c
$B/$K/%.o: $K/%.c
	@mkdir -p $(@D)
	$(CC) $(K_CFLAGS) -c -o $@ $<

# build kernel object files from assembly
$B/$K/%.o: $K/%.S
	@mkdir -p $(@D)
	$(CC) $(K_CFLAGS) -c -o $@ $<

# build user library object files from c
$B/$U/lib/%.o: $U/lib/%.c
	@mkdir -p $(@D)
	$(CC) $(U_CFLAGS) -c -o $@ $<

# build the usys object from perl -> assembly -> object
$B/$U/lib/usys.o: $U/lib/usys.pl
	@mkdir -p $(@D)
	perl $< > $(basename $@).S
	$(CC) $(U_CFLAGS) -c -o $@ $(basename $@).S

# build user test object files from c
$B/$U/tests/%.o: $U/tests/%.c
	@mkdir -p $(@D)
	$(CC) $(U_CFLAGS) -Ikernel/include -c -o $@ $<

# build user program object files from c
$B/$U/%.o: $U/%.c
	@mkdir -p $(@D)
	$(CC) $(U_CFLAGS) -c -o $@ $<

# build user executables using linker script (and provide disassembly and
# symbols files alongside them)
$B/$U/_%: $B/$U/%.o $(U_LIB_OBJS) $(U_LD)
	@mkdir -p $(@D)
	$(LD) $(LDFLAGS) -T $(U_LD) -o $@ $< $(U_LIB_OBJS)
	$(OBJDUMP) -S $@ > $(basename $@).asm
	$(OBJDUMP) -t $@ | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(basename $@).sym

# build user test executables using linker script (and provide disassembly and
# symbols files alongside them)
$B/$U/tests/_%: $B/$U/tests/%.o $(U_LIB_OBJS) $(U_LD)
	@mkdir -p $(@D)
	$(LD) $(LDFLAGS) -T $(U_LD) -o $@ $< $(U_LIB_OBJS)
	$(OBJDUMP) -S $@ > $(basename $@).asm
	$(OBJDUMP) -t $@ | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(basename $@).sym

# build forktest executable with less of library code to save on space in order
# to max out proc table. disassembly and symbols files are also created.
$B/$U/tests/_forktest: $B/$U/tests/forktest.o $B/$U/lib/ulib.o $B/$U/lib/usys.o
	@mkdir -p $(@D)
	$(LD) $(LDFLAGS) -N -e main -Ttext 0 -o $@ $< $B/$U/lib/ulib.o $B/$U/lib/usys.o
	$(OBJDUMP) -S $@ > $(basename $@).asm
	$(OBJDUMP) -t $@ | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(basename $@).sym

# create the mkfs executable with host toolchain
$(TOOL_MKFS_BIN): $(TOOL_MKFS_DIR)/mkfs.c include/abi/param.h include/abi/stat.h include/abi/types.h $K/include/kernel/fs.h
	@mkdir -p $(@D)
	gcc -Wno-unknown-attributes -Iinclude -Ikernel/include -o $@ $<

# create the disk image
$(FS_IMG): $(TOOL_MKFS_BIN) README $(U_PROG_BINS) $(U_TEST_BINS)
	@mkdir -p $(@D)
	$(TOOL_MKFS_BIN) $@ README $(U_PROG_BINS) $(U_TEST_BINS)

# create gdb init file from template
.gdbinit: .gdbinit.tmpl-riscv
	sed "s/:1234/:$(GDBPORT)/; s|build/kernel/kernel|$(K_BIN)|" < $^ > $@

# load dependency files
-include $B/$K/*.d $B/$U/*.d $B/$U/lib/*.d $B/$U/tests/*.d
