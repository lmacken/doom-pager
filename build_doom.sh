#!/bin/bash
set -e
cd /work/doomgeneric/doomgeneric
export SDK_DIR=/work/openwrt-sdk-22.03.5-ramips-mt76x8_gcc-11.2.0_musl.Linux-x86_64
export STAGING_DIR=$SDK_DIR/staging_dir
export TOOLCHAIN_DIR=$STAGING_DIR/toolchain-mipsel_24kc_gcc-11.2.0_musl
export LD_LIBRARY_PATH=$STAGING_DIR/host/lib:$LD_LIBRARY_PATH
make -f Makefile.mips clean
make -f Makefile.mips
