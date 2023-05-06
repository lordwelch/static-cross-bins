NAME := git
GIT_VERSION := 2.40.1

# The download URL should point to a tar archive of some sort.
# On most systems, tar will handle most compression formats, so
# tar/gzip, tar/bzip2, etc, are fine.  If the archive is in a different
# format, a recipe to create $(SRC) will need to be provided.
GIT_URL := https://github.com/git/git/archive/refs/tags/v$(GIT_VERSION).tar.gz

# The list of all programs that the package builds.
# These targets can be called and built from the command line.
# If the package provides no programs, leave this list empty.
GIT_PROGRAMS := git git.tar.gz


# The list of library names that the package builds.
# If the package provides no libraries, leave this list empty.
# Libraries will be represented as variables so that other packages may use them.
# For example, libsomething.a will be available as $$(libsomething).
# GIT_LIBRARIES := libexample.a

# Allow the user to add any make, autoconf, or configure options that they want.
# Feel free to put any reasonable default values here.
GIT_CONFIG = INSTALL_SYMLINKS=1

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
GIT_WOLFSSL_PATCH := $(src)/.wolfssl

# This is the main build recipe!
# Using $(BUILD_FLAG) as a target, it must compile the sources in $(SRC) and
# install the resulting programs and libraries into $(SYSROOT).  If the package
# depends on any libraries, add their variable representations to this target's
# dependency list.  For example, if the package depends on libsomething.a,
# add $$(libsomething) to $(BUILD_FLAG)'s dependencies.
$(GIT_WOLFSSL_PATCH):
	cd "$(SRC)" && patch -p1 < $(MAKEFILE_DIR)/include/git-wolfssl.patch
	touch $(GIT_WOLFSSL_PATCH)

TOOLS = AR=$(SYSROOT)/bin/$(TARGET)-ar AS=$(SYSROOT)/bin/$(TARGET)-as CC=$(SYSROOT)/bin/$(TARGET)-cc CXX=$(SYSROOT)/bin/$(TARGET)-g++ LD=$(SYSROOT)/bin/$(TARGET)-ld NM=$(SYSROOT)/bin/$(TARGET)-nm OBJCOPY=$(SYSROOT)/bin/$(TARGET)-objcopy OBJDUMP=$(SYSROOT)/bin/$(TARGET)-objdump RANLIB=$(SYSROOT)/bin/$(TARGET)-ranlib READELF=$(SYSROOT)/bin/$(TARGET)-readelf STRIP=$(SYSROOT)/bin/$(TARGET)-strip prefix="$(SYSROOT)"

$(BUILD_FLAG): $$(libz) $$(libcurl) $$(libssl) $$(openssl) $$(curl) $(libexpat) $(GIT_WOLFSSL_PATCH)
# This activates the cross-compiler toolchain by setting/exporting a lot of variables.
# Without this, builds would default to the system's compilers and libraries.
	$(eval $(call activate_toolchain,$@))
# The configure step defines what features should be enabled for the program.
# If available, the --host and --prefix values should always be the values below.
# Try to only hard-code the flags that are critical to a successful static build.
# Optional flags should be put in GIT_CONFIG so the user can override them.

	$(MAKE) -C "$(SRC)" clean
	$(MAKE) -C "$(SRC)" V=1 $(TOOLS) \
		NO_REGEX=YesPlease NO_ICONV=YesPlease NO_GETTEXT=YesPlease NO_TCLTK=YesPlease NO_PERL=1 $(SSL_FLAGS) \
		CURL_LDFLAGS="-L/build/sysroot/aarch64-linux-musl/lib -lcurl $(SSL_CURL_FLAGS) -lm -lz" \
		CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" $(GIT_CONFIG)
	$(MAKE) -C "$(SRC)" $(TOOLS) prefix="$(SYSROOT)" \
		NO_REGEX=YesPlease NO_ICONV=YesPlease NO_GETTEXT=YesPlease NO_TCLTK=YesPlease NO_PERL=1 $(SSL_FLAGS) \
		CURL_LDFLAGS="-L/build/sysroot/aarch64-linux-musl/lib -lcurl $(SSL_CURL_FLAGS) -lm -lz" \
		CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" $(GIT_CONFIG) install
	$(MAKE) -C "$(SRC)" $(TOOLS) prefix="/" \
		NO_REGEX=YesPlease NO_ICONV=YesPlease NO_GETTEXT=YesPlease NO_TCLTK=YesPlease NO_PERL=1 $(SSL_FLAGS) \
		CURL_LDFLAGS="-L/build/sysroot/aarch64-linux-musl/lib -lcurl $(SSL_CURL_FLAGS) -lm -lz" \
		CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)" $(GIT_CONFIG) DESTDIR=/tmp/git install
	tar czf $(SYSROOT)/bin/git.tar.gz -C /tmp/git .

SSL_FLAGS :=
SSL_CURL_FLAGS := -lssl -lcrypto
ifeq (wolfssl,$(OPENSSL))
SSL_FLAGS := USE_WOLFSSL=1 OPENSSL_SHA1=1 OPENSSL_SHA256=1 WOLFSSSLDIR="$(SYSROOT)"
SSL_CURL_FLAGS := -lwolfssl

else ifeq (wolfssl,$(CURL_SSL))
SSL_CURL_FLAGS := $(SSL_CURL_FLAGS) -lwolfssl
endif

# All programs should add themselves to the ALL_PROGRAMS list.
ALL_PROGRAMS += $(GIT_PROGRAMS)

# Only programs that most users would want should be added to DEFAULT_PROGRAMS.
DEFAULT_PROGRAMS += $(GIT_PROGRAMS)
