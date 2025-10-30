NAME := git
GIT_VERSION := 2.51.2

# The download URL should point to a tar archive of some sort.
# On most systems, tar will handle most compression formats, so
# tar/gzip, tar/bzip2, etc, are fine.  If the archive is in a different
# format, a recipe to create $(SRC) will need to be provided.
GIT_URL := https://github.com/git/git/archive/refs/tags/v$(GIT_VERSION).tar.gz

# The list of all programs that the package builds.
# These targets can be called and built from the command line.
# If the package provides no programs, leave this list empty.
GIT_PROGRAMS := git git.tar.zst


# The list of library names that the package builds.
# If the package provides no libraries, leave this list empty.
# Libraries will be represented as variables so that other packages may use them.
# For example, libsomething.a will be available as $$(libsomething).
# GIT_LIBRARIES := libexample.a

# Allow the user to add any make, autoconf, or configure options that they want.
# Feel free to put any reasonable default values here.
GIT_CONFIG = INSTALL_SYMLINKS=1
LIB_SSL := wolfssl

# This creates the recipe chain that downloads, extracts, builds, and strips
# the binaries created by this package.  This makes it so that only the main
# build recipe's contents need to be provided by the package author.
$(eval $(call create_recipes, \
	$(NAME), \
	$(GIT_VERSION), \
	$(GIT_URL), \
	$(GIT_PROGRAMS), \
	$(GIT_LIBRARIES), \
))
GIT_WOLFSSL_PATCH := $(src)/.github/wolfssl

# This is the main build recipe!
# Using $(BUILD_FLAG) as a target, it must compile the sources in $(SRC) and
# install the resulting programs and libraries into $(SYSROOT).  If the package
# depends on any libraries, add their variable representations to this target's
# dependency list.  For example, if the package depends on libsomething.a,
# add $$(libsomething) to $(BUILD_FLAG)'s dependencies.

TOOLS = "AR=$(AR)" "AS=$(AS)" "CC=$(CC)" "CXX=$(CXX)" "NM=$(NM)" "OBJCOPY=$(OBJCOPY)" "OBJDUMP=$(OBJDUMP)" "RANLIB=$(RANLIB)" "READELF=$(READELF)" "STRIP=$(STRIP)" prefix="$(SYSROOT)"

$(BUILD_FLAG): $$(libz) $$(libcurl) $$(wolfssl) $$(curl) $(libexpat)
# This activates the cross-compiler toolchain by setting/exporting a lot of variables.
# Without this, builds would default to the system's compilers and libraries.
	$(eval $(call activate_toolchain,$@))
# The configure step defines what features should be enabled for the program.
# If available, the --host and --prefix values should always be the values below.
# Try to only hard-code the flags that are critical to a successful static build.
# Optional flags should be put in GIT_CONFIG so the user can override them.

	bash -c "cd \"$(SRC)\" && test -f $(GIT_WOLFSSL_PATCH) || patch -N -p1 < $(MAKEFILE_DIR)/include/git-wolfssl.patch; true"
	touch $(GIT_WOLFSSL_PATCH)
	"$(SED)" -i '/LINK_FUZZ_PROGRAMS/d' "$(SRC)/config.mak.uname"
	$(MAKE) -C "$(SRC)" clean
	- $(RM) -rf $(SYSROOT)/tmp/git
	$(MAKE) -C "$(SRC)" V=1 $(TOOLS) \
		NO_REGEX=YesPlease NO_ICONV=YesPlease NO_GETTEXT=YesPlease NO_TCLTK=YesPlease NO_PERL=1 $(SSL_FLAGS) CURL_CONFIG="$(SYSROOT)/bin/curl-config" \
		CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" $(GIT_CONFIG) uname_S=Linux
	$(MAKE) -C "$(SRC)" $(TOOLS) prefix="$(SYSROOT)" \
		NO_REGEX=YesPlease NO_ICONV=YesPlease NO_GETTEXT=YesPlease NO_TCLTK=YesPlease NO_PERL=1 $(SSL_FLAGS) CURL_CONFIG="$(SYSROOT)/bin/curl-config" \
		CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" $(GIT_CONFIG) uname_S=Linux install
	$(MAKE) -C "$(SRC)" $(TOOLS) prefix="/" \
		NO_REGEX=YesPlease NO_ICONV=YesPlease NO_GETTEXT=YesPlease NO_TCLTK=YesPlease NO_PERL=1 $(SSL_FLAGS) CURL_CONFIG="$(SYSROOT)/bin/curl-config" \
		CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" $(GIT_CONFIG) uname_S=Linux DESTDIR=$(SYSROOT)/tmp/git bindir="/usr/bin" install
	cd $(SYSROOT)/tmp/git && tar cf - * | zstd -f -o $(SYSROOT)/bin/git.tar.zst

SSL_FLAGS :=
ifeq (wolfssl,$(LIB_SSL))
SSL_FLAGS := USE_WOLFSSL=1 OPENSSL_SHA1=1 OPENSSL_SHA256=1 WOLFSSSLDIR="$(SYSROOT)"
endif

# All programs should add themselves to the ALL_PROGRAMS list.
ALL_PROGRAMS += $(GIT_PROGRAMS)

# Only programs that most users would want should be added to DEFAULT_PROGRAMS.
DEFAULT_PROGRAMS += $(GIT_PROGRAMS)
