#!/usr/bin/env bash

# Use this script for reproducible builds!
# Any arguments supported by make are supported here.
#   Example: ./docker_build.sh -j TARGET=arm-linux-musleabi all
set -e
if [ -e .docker_context ]; then
	rm -r .docker_context/*
fi
mkdir -p .docker_context output sources work sysroot
cp -a Dockerfile Makefile include .docker_context
docker build -t static-builder .docker_context
docker run -it -v "${PWD}/output":"/build/output:Z" -v "${PWD}/sources":"/build/sources:Z" -v "${PWD}/work":"/build/work:Z" -v "${PWD}/sysroot":"/build/sysroot:Z" --rm static-builder "$@"
