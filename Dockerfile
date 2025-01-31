# Despite convention, Ubuntu's "latest" tag points to the latest LTS release.
FROM ubuntu:latest

LABEL org.opencontainers.image.authors="llamasoft@rm-rf.email"
LABEL org.opencontainers.image.url="https://github.com/llamasoft/static-builder"

# This is all that's required for the build process.
# Some packages are already installed but are included for completeness.
RUN apt-get update && apt-get upgrade -y \
 && apt-get install -y \
    gcc g++ \
    make autoconf automake libtool patch \
    flex bison \
    curl \
    tar gzip bzip2 xz-utils

RUN mkdir -p "/build" && chown 1000:1000 /build
COPY "Makefile" "/build/"
COPY "include" "/build/include"
VOLUME "/build"

WORKDIR "/build"
USER 1000
ENTRYPOINT ["/usr/bin/make", "-w"]
