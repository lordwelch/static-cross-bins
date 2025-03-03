NAME := iproute2
IPROUTE2_VERSION := 6.10.0

# The download URL should point to a tar archive of some sort.
# On most systems, tar will handle most compression formats, so
# tar/gzip, tar/bzip2, etc, are fine.  If the archive is in a different
# format, a recipe to create $(SRC) will need to be provided.
IPROUTE2_URL := https://mirrors.edge.kernel.org/pub/linux/utils/net/iproute2/iproute2-$(IPROUTE2_VERSION).tar.xz

# The list of all programs that the package builds.
# These targets can be called and built from the command line.
# If the package provides no programs, leave this list empty.
IPROUTE2_PROGRAMS := ip iproute2.tar.gz

# The list of library names that the package builds.
# If the package provides no libraries, leave this list empty.
# Libraries will be represented as variables so that other packages may use them.
# For example, libsomething.a will be available as $$(libsomething).
IPROUTE2_LIBRARIES :=

# Allow the user to add any make, autoconf, or configure options that they want.
# Feel free to put any reasonable default values here.
IPROUTE2_CONFIG =

# This creates the recipe chain that downloads, extracts, builds, and strips
# the binaries created by this package.  This makes it so that only the main
# build recipe's contents need to be provided by the package author.
$(eval $(call create_recipes, \
	$(NAME), \
	$(IPROUTE2_VERSION), \
	$(IPROUTE2_URL), \
	$(IPROUTE2_PROGRAMS), \
	$(IPROUTE2_LIBRARIES), \
))

# This is the main build recipe!
# Using $(BUILD_FLAG) as a target, it must compile the sources in $(SRC) and
# install the resulting programs and libraries into $(SYSROOT).  If the package
# depends on any libraries, add their variable representations to this target's
# dependency list.  For example, if the package depends on libsomething.a,
# add $$(libsomething) to $(BUILD_FLAG)'s dependencies.
$(BUILD_FLAG): $$(libmnl)
# This activates the cross-compiler toolchain by setting/exporting a lot of variables.
# Without this, builds would default to the system's compilers and libraries.
	$(eval $(call activate_toolchain,$@))
# The configure step defines what features should be enabled for the program.
# If available, the --host and --prefix values should always be the values below.
# Try to only hard-code the flags that are critical to a successful static build.
# Optional flags should be put in IPROUTE2_CONFIG so the user can override them.
	cd "$(SRC)" && PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:$(SYSROOT)/lib/pkgconfig" ./configure
	$(MAKE) -C "$(SRC)" clean EXTRA_CFLAGS="$(CFLAGS)" PREFIX="" LDFLAGS="$(LDFLAGS)" DESTDIR=/tmp/iproute2
	$(MAKE) -C "$(SRC)" HOSTCC=gcc EXTRA_CFLAGS="$(CFLAGS)" PREFIX="" LDFLAGS="$(LDFLAGS)" DESTDIR=/tmp/iproute2
	$(MAKE) -C "$(SRC)" install EXTRA_CFLAGS="$(CFLAGS)" PREFIX="" LDFLAGS="$(LDFLAGS)" DESTDIR=/tmp/iproute2 SUBDIRS="ip misc tc netem"
	cd /tmp/iproute2 && rm -rf share/bash-completion/ share/bash include && tar czf $(SYSROOT)/bin/iproute2.tar.gz *
	cp -a /tmp/iproute2/sbin/ip $(SYSROOT)/bin/

# All programs should add themselves to the ALL_PROGRAMS list.
ALL_PROGRAMS += $(IPROUTE2_PROGRAMS)

# Only programs that most users would want should be added to DEFAULT_PROGRAMS.
# DEFAULT_PROGRAMS += $(IPROUTE2_PROGRAMS)
