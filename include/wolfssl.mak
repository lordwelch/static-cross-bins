NAME := wolfssl
WOLFSSL_VERSION := 5.7.2
WOLFSSL_URL := https://github.com/wolfSSL/wolfssl/archive/refs/tags/v$(WOLFSSL_VERSION)-stable.tar.gz
WOLFSSL_PROGRAMS :=
WOLFSSL_LIBRARIES := libwolfssl.a

$(eval $(call create_recipes, \
	$(NAME), \
	$(WOLFSSL_VERSION), \
	$(WOLFSSL_URL), \
	$(WOLFSSL_PROGRAMS), \
	$(WOLFSSL_LIBRARIES), \
))

$(BUILD_FLAG):
	$(eval $(call activate_toolchain,$@))
	cd "$(SRC)" && sed -i 's@cut >/dev/null 2>&1 </dev/null@which cut >/dev/null 2>\&1 </dev/null@g' configure*
	cd "$(SRC)" && autoreconf -i
	cd "$(SRC)" && ./configure \
	  $(CONFIGURE_DEFAULTS) \
	  --disable-shared --enable-static \
	  --enable-opensslall --enable-opensslextra --enable-curl \
	  CFLAGS="$(CFLAGS)" LDFLAGS="$(LDFLAGS)"
	$(MAKE) -C "$(SRC)" clean
	$(MAKE) -C "$(SRC)"
	$(MAKE) -C "$(SRC)" install
