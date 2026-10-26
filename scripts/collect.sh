#!/usr/bin/env bash
# 从 bin/targets 收集需要发布的产物
set -euo pipefail

V=${1:?用法: collect.sh <版本号，不含 v>}
SRC=openwrt/bin/targets/x86/64
mkdir -p release

for f in \
  "openwrt-${V}-x86-64-generic-ext4-combined-efi.img.gz" \
  "openwrt-${V}-x86-64-generic-rootfs.tar.gz" \
  "openwrt-${V}-x86-64-generic-kernel.bin"
do
  if [ ! -f "${SRC}/${f}" ]; then
    echo "缺少产物: ${SRC}/${f}"
    echo "== 实际产物列表 =="
    ls -lh "$SRC" || true
    exit 1
  fi
  cp "${SRC}/${f}" release/
done

ls -lh release
