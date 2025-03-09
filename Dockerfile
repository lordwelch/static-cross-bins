# Despite convention, Ubuntu's "latest" tag points to the latest LTS release.
FROM docker.io/library/alpine:latest

# This is all that's required for the build process.
# Some packages are already installed but are included for completeness.
RUN apk add install -y \
    zig llvm \
    make autoconf automake libtool patch \
    flex bison \
    curl \
    tar zstd gzip bzip2 xz-utils cmake build-essential pkg-config linux-headers-generic

RUN install -d -o 1000 -g 1000 "/build"
COPY "Makefile" "/build/"
COPY "include" "/build/include"
VOLUME "/build"

WORKDIR "/build"
USER 1000
ENTRYPOINT ["/usr/bin/make", "-w"]
