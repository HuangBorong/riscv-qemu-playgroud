# Environment Variables
CURRENT_DIR := $(shell pwd)
BUILD_DIR := $(CURRENT_DIR)/build
CONFIG_DIR := $(CURRENT_DIR)/config
NPROC := $(shell nproc)
CROSS_COMPILE := riscv64-linux-gnu-
NCORE ?= 1

# Qemu Variables
qemu_srcdir := $(CURRENT_DIR)/qemu
qemu_builddir := $(BUILD_DIR)/qemu
qemu_target := $(qemu_builddir)/qemu-system-riscv64
qemu_config_args := --target-list=riscv64-softmmu --enable-debug
qemu_machine := -machine xiangshan-kunminghu
qemu_args := -cpu xiangshan-kunminghu \
			 -m 4G \
			 -smp $(NCORE)

# Linux Variables
linux_srcdir := $(CURRENT_DIR)/linux
linux_builddir := $(BUILD_DIR)/linux
linux_vmlinux := $(linux_builddir)/vmlinux
linux_image := $(linux_builddir)/arch/riscv/boot/Image

# FDT Variables
dtb_file := $(linux_builddir)/arch/riscv/boot/dts/bosc/kmh-v2-$(NCORE)core.dtb

# OpenSBI Variables
opensbi_srcdir := $(CURRENT_DIR)/opensbi
opensbi_builddir := $(BUILD_DIR)/opensbi
opensbi_bindir := $(opensbi_builddir)/platform/generic/firmware
opensbi_payload_bin := $(opensbi_bindir)/fw_payload.bin
opensbi_payload_elf := $(opensbi_bindir)/fw_payload.elf

###########
# qemu
###########
.PHONY: qemu
qemu: $(qemu_builddir)/config-host.mak
	$(MAKE) -C $(qemu_builddir) -j $(NPROC)

$(qemu_builddir)/config-host.mak:
	mkdir -p $(qemu_builddir)
	cd $(qemu_builddir) && \
		$(qemu_srcdir)/configure $(qemu_config_args)

###########
# linux
###########
.PHONY: linux
linux: $(linux_builddir)/.config
	$(MAKE) -C $(linux_srcdir) O=$(linux_builddir) -j $(NPROC) \
	ARCH=riscv CROSS_COMPILE=$(CROSS_COMPILE) \

$(linux_builddir)/.config:
	mkdir -p $(dir $@)
	$(MAKE) -C $(linux_srcdir) O=$(linux_builddir) -j $(NPROC) \
	ARCH=riscv CROSS_COMPILE=$(CROSS_COMPILE) \
	defconfig xiangshan.config

###########
# opensbi
###########
.PHONY: opensbi
opensbi: $(dtb_file) $(linux_image)
	mkdir -p $(opensbi_builddir)
	$(MAKE) -C $(opensbi_srcdir) O=$(opensbi_builddir) -j $(NPROC) \
	CROSS_COMPILE=$(CROSS_COMPILE) \
	PLATFORM=generic \
	FW_TEXT_START=0x80000000 \
	FW_FDT_PATH=$(dtb_file) \
	FW_PAYLOAD_PATH=$(linux_image) \
	FW_PAYLOAD_OFFSET=0x400000

##########
# clean
##########
.PHONY: qemu-clean qemu-distclean linux-clean linux-distclean opensbi-clean
qemu-clean:
	$(MAKE) -C $(qemu_builddir) clean

qemu-distclean:
	rm -rf $(qemu_builddir)

linux-clean:
	$(MAKE) -C $(linux_builddir) clean

linux-distclean:
	rm -rf $(linux_builddir)

opensbi-clean:
	rm -rf $(opensbi_builddir)
