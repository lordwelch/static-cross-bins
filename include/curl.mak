NAME := curl
CURL_VERSION := 8.20.0
CURL_URL := https://github.com/curl/curl/releases/download/curl-$(subst .,_,$(CURL_VERSION))/curl-$(CURL_VERSION).tar.gz
CURL_PROGRAMS := curl
CURL_LIBRARIES := libcurl.a

CURL_CONFIG = --with-ca-bundle=/etc/ssl/ca-bundle.pem --with-ca-embed=/etc/ssl/ca-bundle.pem

# WolfSSL results in a much smaller binary (around 1MB).
# The only reason you'd use OpenSSL here is if you already
# need the library for other things and don't care about size.
LIB_SSL := wolfssl
# LIB_SSL := openssl

$(eval $(call create_recipes, \
	$(NAME), \
	$(CURL_VERSION), \
	$(CURL_URL), \
	$(CURL_PROGRAMS), \
	$(CURL_LIBRARIES), \
))

# This package uses libtool and needs LDFLAGS to include -all-static
# in order to produce a statically linked binary.  However, the
# configure script doesn't use libtool, so the flag must be injected
# at built-time only, otherwise the configure will fail.
#   See https://stackoverflow.com/a/54168321/477563
$(BUILD_FLAG): $$(libz) $$(libpsl) $$(libzstd)
	$(eval $(call activate_toolchain,$@))
	cd "$(SRC)" && ./configure \
	  $(CONFIGURE_DEFAULTS) \
	  --with-zlib="$(SYSROOT)" \
	  --disable-shared --enable-static --with-$(LIB_SSL) --without-libpsl \
	  $(CURL_CONFIG) \
	  CFLAGS="$(filter-out -I%,$(CFLAGS))" CPPFLAGS="$(CXXFLAGS)" LDFLAGS="$(filter -L%,$(LDFLAGS))" CC="$(CC)"
	$(MAKE) -C "$(SRC)" clean
	$(MAKE) -C "$(SRC)" LDFLAGS="$(LDFLAGS) -all-static"
	$(MAKE) -C "$(SRC)" install

# Update dependencies based on chosen SSL library.
ifeq ($(LIB_SSL),wolfssl)
$(BUILD_FLAG): $$(libwolfssl)
else ifeq ($(LIB_SSL),openssl)
$(BUILD_FLAG): $$(libssl)
else
$(error Invalid LIB_SSL selection: $(LIB_SSL))
endif

ALL_PROGRAMS += $(CURL_PROGRAMS)
DEFAULT_PROGRAMS += $(CURL_PROGRAMS)
