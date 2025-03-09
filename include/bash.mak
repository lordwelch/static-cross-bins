NAME := bash
BASH_VERSION := 5.2.37
BASH_URL := https://ftp.gnu.org/gnu/bash/bash-$(BASH_VERSION).tar.gz
BASH_PROGRAMS := bash
BASH_LIBRARIES :=

BASH_CONFIG =

$(eval $(call create_recipes, \
	$(NAME), \
	$(BASH_VERSION), \
	$(BASH_URL), \
	$(BASH_PROGRAMS), \
	$(BASH_LIBRARIES), \
))

BASH_MUSL_PATCH := $(src)/.musl

$(BASH_MUSL_PATCH): $(src)
	cd "$(SRC)" && patch -p1 < $(MAKEFILE_DIR)/include/bash-musl.patch
	touch $(BASH_MUSL_PATCH)

$(BUILD_FLAG): $$(libncurses) $$(libreadline)
	$(eval $(call activate_toolchain,$@))
	cd "$(SRC)" && ./configure \
	  $(CONFIGURE_DEFAULTS) --without-bash-malloc \
	  --enable-static-link --with-curses --with-readline \
	  $(BASH_CONFIG) \
	  CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)"
	$(MAKE) -C "$(SRC)" clean
	$(MAKE) -C "$(SRC)"
	$(MAKE) -C "$(SRC)" install

ALL_PROGRAMS += $(BASH_PROGRAMS)
DEFAULT_PROGRAMS += $(BASH_PROGRAMS)
