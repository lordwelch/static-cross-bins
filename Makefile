########################## Usage ###########################

define USAGE
========================================
USAGE: make TARGET=musl-toolchain [ARCH=cpu-arch] [program ...]
The TARGET value must be a musl-cross-make toolchain target.
The optional ARCH value must be a valid GCC -march CPU type.

Examples targets:
  TARGET=arm-linux-musleabi
  TARGET=arm-linux-musleabihf ARCH=armv7-a+fp
  TARGET=mips-linux-musl
  TARGET=mipsel-linux-muslsf
  TARGET=x86_64-linux-musl
  ...
  For additional targets, consult the musl manual:
    https://musl.libc.org/doc/1.1.24/manual.html

Goals:
  all
    Builds all available programs:
    $(sort $(ALL_PROGRAMS))
  default
    Builds default subset of programs:
    $(sort $(DEFAULT_PROGRAMS))
  musl
    Builds the cross-compiler toolchain for TARGET.
  archlist
    Shows available CPU architectures for TARGET.
  env
    Shows shell commands to activate TARGET toolchain.
  usage
    Shows this message.
  mostlyclean
    Removes source code and temporary objects.
  clean
    Removes cross-compiler toolchain, sources, and objects.
========================================
endef

required_features := else-if order-only second-expansion target-specific
missing_features := $(filter-out $(.FEATURES),$(required_features))
ifneq (,$(missing_features))
$(error This version of make is missing required features: $(required_features))
endif



########################## Flags ###########################

# We need access to `command -v` to check if programs exist.
SHELL := /bin/sh

CFLAGS = -g0 -Os
CXXFLAGS = -g0 -Os

# Just in case the user forgets that we're doing static builds.
override LDFLAGS  += -static
override CFLAGS   += -static $(if $(ARCH),-march=$(ARCH))
override CXXFLAGS += -static $(if $(ARCH),-march=$(ARCH))

# Some builds need to be explicitly given these paths.
override LDFLAGS  += -L$(SYSROOT)/lib
override CFLAGS   += -I$(SYSROOT)/include
override CXXFLAGS += -I$(SYSROOT)/include

# Attempt to make builds reproducible.
# For most builds, this will get you a byte-for-byte identical output
# regardless of which machine you cross-compiled from.  Failing that,
# two builds from the same build machine are identical.
ifneq (0,$(REPRODUCIBLE))
export SOURCE_DATE_EPOCH := 0
override CFLAGS   += -ffile-prefix-map=$(MAKEFILE_DIR)=.
override CXXFLAGS += -ffile-prefix-map=$(MAKEFILE_DIR)=.
endif

# Intermediate files will be larger and build times will be slightly longer
# but the final binary can sometimes be much smaller.
ifneq (0,$(EXTRA_SMALL))
override LDFLAGS  += -Wl,--gc-sections
override CFLAGS   += -ffunction-sections -fdata-sections
override CXXFLAGS += -ffunction-sections -fdata-sections
endif

# The download command should take two extra arguments: OUTPUT_FILE URL
ifneq (,$(shell command -v curl))
DOWNLOAD := curl --silent --show-error -L -o
else ifneq (,$(shell command -v wget))
DOWNLOAD := wget --no-verbose -c -O
else
$(error No curl or wget detected, please manually specify the DOWNLOAD command.)
endif

# Try to find gsed
ifeq ($(shell command -v gsed),)
    SED := sed
else
    SED := gsed
endif

# LibreSSL is a drop-in replacement for OpenSSL that's smaller and easier to build.
OPENSSL := libressl
# OPENSSL := openssl
TARGET := x86_64-linux-musl
BUILD_TRIPLE := $(shell $(filter-out --target%,$(CC)) -dumpmachine 2>/dev/null)
CONFIGURE_DEFAULTS = --build="$(BUILD_TRIPLE)" --host="$(TARGET)" --prefix="$(SYSROOT)"


########################## Paths ###########################

# NOTE: these paths need to be absolute.
# All other paths are built from these, including the toolchain binaries.
# A relative path would be useless once we `cd` into a source code directory.
MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
MAKEFILE_DIR := $(patsubst %/,%,$(dir $(MAKEFILE_PATH)))

SOURCE_ROOT := $(MAKEFILE_DIR)/sources
WORK_ROOT := $(MAKEFILE_DIR)/work
OUTPUT_ROOT := $(MAKEFILE_DIR)/output
TOOLCHAIN_ROOT := $(MAKEFILE_DIR)/sysroot

SYSROOT := $(TOOLCHAIN_ROOT)/$(TARGET)
OUTPUT := $(OUTPUT_ROOT)/$(TARGET)
PKG_CONFIG_PATH := $(SYSROOT)/lib/pkgconfig

CMAKE_DEFAULTS = -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX=$(SYSROOT) -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_FIND_ROOT_PATH=$(TOOLCHAIN_ROOT) -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY
# Having whitespace in our build paths _will_ result in failures.
# In addition to failures, a path containing whitespace may cause an
# improperly quoted $(RM) to delete things outside of the build directory.
ifneq (1,$(words $(MAKEFILE_DIR)))
$(error Whitespace detected in build path. This _will_ result in build failures.)
endif


######################## Functions #########################

# These "activate" functions are meant to be used with $(eval $(call ...))
define activate_paths
$(1): export SYSROOT=$(SYSROOT)
$(1): export PREFIX=$(SYSROOT)
$(1): export PKG_CONFIG_PATH=$(PKG_CONFIG_PATH)
endef

define activate_toolchain
$(call activate_paths,$(1))
$(1): export HOSTCC=zig cc
$(1): export HOSTCXX=zig c++
$(1): export BUILD_CC=zig cc
$(1): export BUILD_CPP=zig c++
$(1): export CC_FOR_BUILD=zig cc
$(1): export CXX_FOR_BUILD=zig c++
$(1): export AR=zig ar
$(1): export AS=as
$(1): export CC=zig cc --target=$(TARGET)
$(1): export CXX=zig c++ --target=$(TARGET)
$(1): export LD=llvm-link
$(1): export NM=llvm-nm
$(1): export MT=llvm-mt
$(1): export OBJCOPY=zig objcopy
$(1): export OBJDUMP=objdump
$(1): export RANLIB=zig ranlib
$(1): export READELF=readelf
$(1): export STRIP=strip
endef

# Downloads and unpacks a tar file.
define tar_to_tar_zstd
mkdir -p "$(dir $(2))"
$(DOWNLOAD) "$(2).download" "$(1)"
mkdir -p "$(2).tmp"
tar --strip-components=1 -C "$(2).tmp" -xf "$(2).download"
tar --zstd -C "$(2).tmp" -cf "$(2)" "." || ($(RM) "$(2)" ; exit 1)
$(RM) -rf "$(2).download" "$(2).tmp"
endef

# Creates variables based on library names.
# This makes it easier for packages to depend on libraries
# that will be created by other packages.
# For example $(eval $(call export_library,/path/to/libsomething.a))
# will set libsomething := /path/to/libsomething.a
define export_library
$(basename $(notdir $(1))) := $(1)
endef

# Creates generic recipe chains for a package's binaries and libraries.
# This is where the magic happens!
# This would have been much cleaner to create with $(file <template.mak)
# but unfortunately the function wasn't added until GNU Make 4.0.
all_recipes :=
define create_recipes
name := $(strip $(1))
version := $(strip $(2))
url := $(strip $(3))
bin_names := $(notdir $(strip $(4)))
lib_names := $(notdir $(strip $(5)))

ifeq (,$$(name))
$$(error Package name cannot be empty)
else ifeq (,$$(version))
$$(error Package version for $$(name) cannot be empty)
else ifeq (,$$(url))
$$(error Package url for $$(name) cannot be empty)
else ifeq (,$$(bin_names)$$(lib_names))
$$(error The $$(name) package must provide at least one binary or library)
else ifneq (,$$(filter $$(name),$$(all_recipes)))
$$(error A recipe for $$(name) has already been created.)
else
all_recipes += $$(name)
endif

orig_src := $$(SOURCE_ROOT)/$$(name)-$$(version).tar.zstd
work_src := $$(WORK_ROOT)/$$(name)-$$(version)
src := $$(work_src)
bin_paths := $$(addprefix $$(OUTPUT)/bin/,$$(bin_names))
lib_paths := $$(addprefix $$(SYSROOT)/lib/,$$(lib_names))

# Export library names as variables for other recipes to depend on.
$$(foreach lib,$$(lib_paths),$$(eval $$(call export_library,$$(lib))))

# Building any one of the programs or libraries builds them all.
.PHONY: $$(bin_names) $$(lib_names)
$$(bin_names) $$(lib_names): | $$(bin_paths) $$(lib_paths)

# Bind variables to all of this package's recipes.
# These variable names will be reused later by other packages,
# so binding them here the only way to guarantee the correct value.
$$(bin_paths) $$(lib_paths): override URL := $$(url)
$$(bin_paths) $$(lib_paths): override SRC := $$(src)
$$(bin_paths) $$(lib_paths): override ORIG_SRC := $$(orig_src)

# We potentially have multiple output files generated from one recipe.
# If not handled correctly, building one program from the list can result in the
# recipe running once per program instead of just once overall.
# To work around this, we make each binary depend on an intermediate flag.
# See: https://stackoverflow.com/a/10609434/477563
BUILD_FLAG := $$(SYSROOT)/$$(name).built
.INTERMEDIATE: $$(BUILD_FLAG)

ifneq (,$$(bin_paths))
# Binaries need to be copied from SYSROOT/bin/ to OUTPUT/bin/.
$$(bin_paths): $$(BUILD_FLAG)
	$$(eval $$(call activate_toolchain,$$@))
	mkdir -p "$$(@D)"
	install "$$(SYSROOT)/bin/$$(@F)" "$$@"
	- $$(STRIP) --strip-unneeded "$$@"
	ls -al "$$@"
endif

ifneq (,$$(lib_paths))
# Libraries are already in their final location.
$$(lib_paths): $$(BUILD_FLAG) ;
endif

# This is main build recipe that the package's makefile must provide.
# It should take the source code and output the built programs
# and libraries into the SYSROOT directory tree.
# Here we merely provide the recipe definition and base dependencies.
$$(BUILD_FLAG): $$(src)

$$(orig_src):
	echo orig $$(ORIG_SRC)
	$$(call tar_to_tar_zstd,$$(URL),$$@)

$$(work_src): $$(orig_src)
	rm -rf $$(SRC)
	mkdir -p $$(SRC)
	tar -C $$(SRC) -xf $$(ORIG_SRC)
endef

# Never implicitly pass this makefile's command-line variables
# to other instances of make.  This prevents TARGET, ARCH, etc,
# from tainting the other builds.  Unfortunately, simply clearing
# the MAKEOVERRIDES variable isn't enough because make will
# auto-export any explicitly defined command-line variables.
define unexport_var
_var_assignment := $(1)
_var_parts := $$(subst =, ,$$(_var_assignment))
_var_name := $$(firstword $$(_var_parts))
_var_name := $$(subst :, ,$$(_var_name))
unexport $$(_var_name)
endef
$(foreach assignment,$(MAKEOVERRIDES),$(eval $(call unexport_var,$(assignment))))
MAKEOVERRIDES =


######################### Recipes ##########################

# Disable implicit rules.
.SUFFIXES:

# Secondary expansion is required because some programs will
# depend on library path variables that haven't been defined yet.
.SECONDEXPANSION:

# Don't allow different programs to be built simultaneously,
# but do allow those programs to compile in parallel.
# Building programs in parallel makes it much more difficult
# to notice and diagnose build failure reasons.
.NOTPARALLEL:

# Import all of the individual build components.
include $(MAKEFILE_DIR)/include/*.mak

# If no TARGET was specified, default to the usage guide.
.DEFAULT_GOAL := $(if $(TARGET),default,usage)

.PHONY: all
all: $(ALL_PROGRAMS)
	ls -al "$(OUTPUT)/bin"

.PHONY: default
default: $(DEFAULT_PROGRAMS)
	ls -al "$(OUTPUT)/bin"

.PHONY: help usage
help usage:
	$(info $(USAGE))

# Apparently the help output varies between toolchains so we'll try both.
.PHONY: archlist
archlist:
	$(eval $(call activate_toolchain,$@))
	-@ "$(CC)" -march="x" 2>&1 | grep -F "valid arguments" || true
	-@ "$(CC)" --target-help 2>&1 | "$(SED)" -n '/Known.*-march/,/^$$/p' || true

# Cleans all sources except for musl.
.PHONY: mostlyclean
mostlyclean:
	- $(RM) -r \
	  "$(SOURCE_ROOT)/"*.tgz \
	  "$(SOURCE_ROOT)/"*.tmp

# Cleans all compiled results.
.PHONY: clean
clean: mostlyclean
ifneq (,$(TARGET))
	- $(RM) -r "$(OUTPUT)"
	- $(RM) -r "$(SYSROOT)"
	- $(RM) -r "$(MAKEFILE_DIR)/docker_context"
else
	- $(RM) -r "$(OUTPUT_ROOT)"
	- $(RM) -r "$(TOOLCHAIN_ROOT)"
endif

# Cleans musl toolchain artifacts.
.PHONY: distclean
distclean: clean
	- $(RM) -r "$(SOURCE_ROOT)"

# Dumps the toolchain variables for use in shell environments.
# Meant to be used as: eval "$(make --silent TARGET=toolchain env)"
.PHONY: env
env:
ifeq (,$(TARGET))
	$(error TARGET is required to dump environment variables)
endif
	$(info $(subst : ,,$(call activate_toolchain)))
	$(info LDFLAGS='$(LDFLAGS)')
	$(info CFLAGS='$(CFLAGS)')
	$(info CXXFLAGS='$(CXXFLAGS)')
