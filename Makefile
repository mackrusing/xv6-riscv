# base input and output directories
S := src
T := tools
B := build

# subtrees
K := kernel
U := user

# sub-subtrees
U_LIB := lib
U_TESTS := tests
T_MKFS := mkfs

# linker scripts
K_LD := $S/kernel.ld
U_LD := $S/user.ld

# abi header files
ABI_HEADERS := $(sort $(wildcard $S/include/abi/*.h))

# kernel header files, source files, module names, object files
K_HEADERS := $(sort $(wildcard $S/$K/include/$K/*.h))
K_SRC_C := $(sort $(wildcard $S/$K/*.c))
K_SRC_S := $(sort $(wildcard $S/$K/*.S))
K_MODS := $(sort $(basename $(notdir $(K_SRC_C) $(K_SRC_S))))
K_OBJS := $(addprefix $B/$K/,$(addsuffix .o,$(K_MODS)))
K_BIN := $B/kernel.bin

# user header files
U_HEADERS := $(sort $(wildcard $S/$U/include/$U/*.h))

# user library header files, source files, module names, object files
U_LIB_SRC_C := $(sort $(wildcard $S/$U/$(U_LIB)/*.c))
U_LIB_SRC_S := $(sort $(wildcard $S/$U/$(U_LIB)/*.S))
U_LIB_MODS := $(sort $(basename $(notdir $(U_LIB_SRC_C) $(U_LIB_SRC_S))))
U_LIB_OBJS := $(addprefix $B/$U/$(U_LIB)/,$(addsuffix .o,$(U_LIB_MODS)))

# user test source files, module names, object files, binaries
U_TEST_SRC_C := $(sort $(wildcard $S/$U/$(U_TESTS)/*.c))
U_TEST_MODS := $(sort $(basename $(notdir $(U_TEST_SRC_C))))
U_TEST_OBJS := $(addprefix $B/$U/$(U_TESTS)/,$(addsuffix .o,$(U_TEST_MODS)))
U_TEST_BINS := $(addprefix $B/$U/$(U_TESTS)/,$(addsuffix .bin,$(U_TEST_MODS)))

# user program source files, module names, object files, binaries
U_PROG_SRC_C := $(sort $(wildcard $S/$U/*.c))
U_PROG_MODS := $(sort $(basename $(notdir $(U_PROG_SRC_C))))
U_PROG_OBJS := $(addprefix $B/$U/,$(addsuffix .o,$(U_PROG_MODS)))
U_PROG_BINS := $(addprefix $B/$U/,$(addsuffix .bin,$(U_PROG_MODS)))

# tool mkfs source files, module names, object files, binaries
T_MKFS_SRC_C := $T/$(T_MKFS)/mkfs.c
T_MKFS_MODS := $(sort $(basename $(notdir $(T_MKFS_SRC_C))))
T_MKFS_BIN := $B/mkfs.bin

# the completed filesystem image
FS_IMG := $B/fs.img

# toolchain
CC := clang --target=riscv64-unknown-elf
LD := ld.lld
OBJCOPY := llvm-objcopy
OBJDUMP := llvm-objdump
QEMU := qemu-system-riscv64

# compiler flags
CFLAGS :=
# language features
CFLAGS += -std=gnu99 -fno-common -fno-pie
# extra info on target arch and how c generates address instructions
CFLAGS += -march=rv64gc -mcmodel=medany
# freestanding environment
CFLAGS += -ffreestanding -fno-stack-protector
# optimizations
CFLAGS += -O
# debugging, keep frame pointer for backtrace, store relative paths in dbg info
CFLAGS += -g -fno-omit-frame-pointer -ffile-prefix-map=$(CURDIR)=.
# warnings
CFLAGS += -Wall -Werror
# generate make dependency files
CFLAGS += -MD

# extra domain-specific compiler flags
K_CFLAGS := $(CFLAGS) -I$S/include -I$S/$K/include
U_CFLAGS := $(CFLAGS) -I$S/include -I$S/$U/include

# linker flags
LDFLAGS = -z max-page-size=4096 --discard-locals --no-rosegment

# cores to emulate
CPUS := 3

# emulator flags
QEMUOPTS := -machine virt -bios none -kernel $(K_BIN) -m 128M -smp $(CPUS) \
    -nographic -global virtio-mmio.force-legacy=false \
    -drive file=$(FS_IMG),if=none,format=raw,id=x0 \
    -device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0

#
# helper functions
#

# provide disassembly and symbols files next to a compiled binary
define disassembly # compiled-bin
    $(OBJDUMP) -S $(1) > $(basename $(1)).asm
    $(OBJDUMP) -t $(1) | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(basename $(1)).sym
endef

#
# helper rules
#

# keep intermediate object files
.SECONDARY: $(K_OBJS) $(U_LIB_OBJS) $(U_TEST_OBJS) $(U_PROG_OBJS)

# non-file related rules
.PHONY: all kernel user mkfs clean docs fmt qemu

# default rule
all: kernel

# helper rules
kernel: $(K_BIN)
user: $(U_PROG_BINS) $(U_TEST_BINS)
mkfs: $(T_MKFS_BIN)

clean:
	rm -rf $B

docs:
	@mkdir -p build/docs
	doxygen Doxyfile

fmt:
	clang-format -i $S/include/abi/syscalls.def $(ABI_HEADERS) $(K_HEADERS) $(K_SRC_C) $(U_HEADERS) $(U_LIB_SRC_C) $(U_TEST_SRC_C) $(U_PROG_SRC_C) $(T_MKFS_SRC_C)

qemu: $(K_BIN) $(FS_IMG)
	$(QEMU) $(QEMUOPTS)


#
# compilation rules
#

# build kernel executable + disassembly/symbol files
$(K_BIN): $(K_OBJS) $(K_LD)
	@mkdir -p $(@D)
	$(LD) $(LDFLAGS) -T $(K_LD) -o $@ $(K_OBJS)
	$(call disassembly,$@)

# build kernel objects from c
$B/$K/%.o: $S/$K/%.c
	@mkdir -p $(@D)
	$(CC) $(K_CFLAGS) -c -o $@ $<

# build kernel objects from assembly
$B/$K/%.o: $S/$K/%.S
	@mkdir -p $(@D)
	$(CC) $(K_CFLAGS) -c -o $@ $<

# build user lib objects from c
$B/$U/$(U_LIB)/%.o: $S/$U/$(U_LIB)/%.c
	@mkdir -p $(@D)
	$(CC) $(U_CFLAGS) -c -o $@ $<

# build user lib objects from assembly
$B/$U/$(U_LIB)/%.o: $S/$U/$(U_LIB)/%.S
	@mkdir -p $(@D)
	$(CC) $(U_CFLAGS) -c -o $@ $<

# build user test objects from c
$B/$U/$(U_TESTS)/%.o: $S/$U/$(U_TESTS)/%.c
	@mkdir -p $(@D)
	$(CC) $(U_CFLAGS) -I$S/$K/include -c -o $@ $<

# build user test executables + disassembly/symbols files
$B/$U/$(U_TESTS)/%.bin: $B/$U/$(U_TESTS)/%.o $(U_LIB_OBJS) $(U_LD)
	@mkdir -p $(@D)
	$(LD) $(LDFLAGS) -T $(U_LD) -o $@ $< $(U_LIB_OBJS)
	$(call disassembly,$@)

# build forktest executable + disassembly/symbols files with less library code
$B/$U/$(U_TESTS)/forktest.bin: $B/$U/$(U_TESTS)/forktest.o $B/$U/$(U_LIB)/ulib.o $B/$U/$(U_LIB)/usys.o $(U_LD)
	@mkdir -p $(@D)
	$(LD) $(LDFLAGS) -T $(U_LD) -o $@ $< $B/$U/$(U_LIB)/ulib.o $B/$U/$(U_LIB)/usys.o
	$(call disassembly,$@)

# build user program objects from c
$B/$U/%.o: $S/$U/%.c
	@mkdir -p $(@D)
	$(CC) $(U_CFLAGS) -c -o $@ $<

# build user program executables + disassembly/symbols files
$B/$U/%.bin: $B/$U/%.o $(U_LIB_OBJS) $(U_LD)
	@mkdir -p $(@D)
	$(LD) $(LDFLAGS) -T $(U_LD) -o $@ $< $(U_LIB_OBJS)
	$(call disassembly,$@)

#
# filesystem
#

# create the mkfs executable with host toolchain
$(T_MKFS_BIN): $(T_MKFS_SRC_C) $S/include/abi/fs.h $S/include/abi/param.h $S/include/abi/stat.h $S/include/abi/types.h $S/$K/include/$K/fs.h
	@mkdir -p $(@D)
	cc -Wno-unknown-attributes -I$S/include -I$S/$K/include -o $@ $<

# create the disk image
$(FS_IMG): $(T_MKFS_BIN) README $(U_PROG_BINS) $(U_TEST_BINS)
	@mkdir -p $(@D)
	$(T_MKFS_BIN) $@ README $(U_PROG_BINS) $(U_TEST_BINS)

#
# dependency files
#

# load dependency files
-include $B/$K/*.d
-include $B/$U/*.d
-include $B/$U/$(U_LIB)/*.d
-include $B/$U/$(U_TESTS)/*.d
