#!/bin/sh
# usage: kc.sh <srctree> <conf args...>   (cwd must be writable: cc-option probes mkdir there)
T="$1"; shift
exec env srctree="$T" ARCH=arm64 SRCARCH=arm64 CC=gcc LD=ld HOSTCC=gcc HOSTCXX=g++ \
  CC_VERSION_TEXT="$(gcc --version | head -1)" RUSTC=rustc BINDGEN=bindgen PAHOLE=pahole \
  HOSTRUSTC=rustc OBJCOPY=objcopy AR=ar NM=nm "$T/scripts/kconfig/conf" "$@" Kconfig
