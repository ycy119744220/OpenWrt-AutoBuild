#!/usr/bin/env bash
# defconfig 之后校验关键符号，任何一条不符就让构建失败
set -euo pipefail

[ -f .config ] || { echo "找不到 .config"; exit 1; }

must_y="
CONFIG_TARGET_x86_64
CONFIG_PACKAGE_kmod-igc
CONFIG_PACKAGE_luci-theme-argon
CONFIG_PACKAGE_luci-app-argon-config
CONFIG_LUCI_LANG_zh_Hans
CONFIG_PACKAGE_luci-app-openclash
CONFIG_PACKAGE_openclash-core-meta
CONFIG_PACKAGE_openclash-geo-db
CONFIG_PACKAGE_dnsmasq-full
CONFIG_PACKAGE_luci-app-upnp
CONFIG_PACKAGE_kmod-tun
CONFIG_PACKAGE_kmod-nft-tproxy
CONFIG_PACKAGE_ip-full
CONFIG_GRUB_EFI_IMAGES
CONFIG_TARGET_ROOTFS_EXT4FS
"

must_n="
CONFIG_PACKAGE_luci-app-fstab
CONFIG_PACKAGE_block-mount
CONFIG_PACKAGE_kmod-r8169
CONFIG_PACKAGE_kmod-e1000e
CONFIG_PACKAGE_kmod-e100
CONFIG_PACKAGE_kmod-drm-i915
"

bad=0
for s in $must_y; do
  grep -qx "$s=y" .config || { echo "FAIL 缺少 $s=y"; bad=1; }
done
for s in $must_n; do
  grep -qE "^# *$s is not set$|^$s=n$" .config || { echo "FAIL 未关闭 $s"; bad=1; }
done

if [ "$bad" -ne 0 ]; then
  echo "== 配置校验失败，相关行如下 =="
  for s in $must_y $must_n; do grep -n "^\S*$s\b" .config || echo "(无) $s"; done
  exit 1
fi

echo "== 配置校验通过：$(grep -c '^CONFIG_' .config) 行配置，关键符号全部匹配"
