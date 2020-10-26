HAS_MEMNEQ ?= 0

ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

LIBMNL_DIR := $(ROOT_DIR)/libmnl
WIREGUARD_DIR := $(ROOT_DIR)/wireguard-linux-compat
WIREGUARD_TOOLS_DIR := $(ROOT_DIR)/wireguard-tools

WG_TARGET := $(WIREGUARD_TOOLS_DIR)/src/wg
WG_QUICK_TARGET := $(WIREGUARD_TOOLS_DIR)/wg-quick
WG_MODULE_TARGET := $(WIREGUARD_DIR)/src/wireguard.ko

GCC := $(CROSS_COMPILE)gcc
TARGET_TRIPLE := $(shell echo $(CROSS_COMPILE)|cut -f4 -d/ -)

all: $(WG_TARGET) $(WG_QUICK_TARGET) $(WG_MODULE_TARGET)

# Prepare libmnl for building
$(LIBMNL_DIR)/Makefile:
	(cd $(LIBMNL_DIR) && ./autogen.sh && ./configure --host=$(shell gcc -dumpmachine) --enable-static --target=$(TARGET_TRIPLE) CC=$(GCC))

# Compile libmnl static lib
$(LIBMNL_DIR)/src/.libs/libmnl.a: $(LIBMNL_DIR)/Makefile
	$(MAKE) -C $(LIBMNL_DIR)

# patch the compatibility layer to always
# use memneq implementation as it doesn't appear to be included on the D218j.
ifeq ($(HAS_MEMNEQ), 0)
	patch $(WIREGUARD_DIR)/src/compat/Kbuild.include $(ROOT_DIR)/memneq.patch
endif

# Build the wg command line tool
$(WG_TARGET): $(LIBMNL_DIR)/src/.libs/libmnl.a $(WIREGUARD_TOOLS_DIR)/src/Makefile
	CFLAGS=-I$(ROOT_DIR)/$(LIBMNL_DIR)/include LDFLAGS=-L$(ROOT_DIR)/$(LIBMNL_DIR)/src/.libs $(MAKE) -C $(WIREGUARD_TOOLS_DIR)/src CC=$(GCC)

# Choose the correct wg-quick implementation
$(WG_QUICK_TARGET): $(WIREGUARD_TOOLS_DIR)/src/Makefile
	cp $(WIREGUARD_TOOLS_DIR)/src/wg-quick/linux.bash $(WG_QUICK_TARGET)

# Build wireguard.ko kernel module
$(WG_MODULE_TARGET): $(WIREGUARD_DIR)/src/Makefile
	$(MAKE) -C $(WIREGUARD_DIR)/src module ARCH=$(ARCH) KERNELDIR=$(KSRC)

install: all
	mkdir -p $(DESTDIR)/wireguard/
	install $(WG_TARGET) $(DESTDIR)/wireguard/
	install $(WG_QUICK_TARGET) $(DESTDIR)/wireguard/
	install $(WG_MODULE_TARGET) $(DESTDIR)/wireguard/

clean:
	$(MAKE) -C $(WIREGUARD_DIR)/src clean ARCH=$(ARCH) KERNELDIR=$(KSRC)
	$(MAKE) -C $(WIREGUARD_TOOLS_DIR)/src clean
	[ ! -f $(LIBMNL_DIR)/Makefile ] || make -C $(LIBMNL_DIR) clean
