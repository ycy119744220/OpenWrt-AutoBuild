#!/usr/bin/env bash
# defconfig 之后校验关键符号，任何一条不符就让构建失败
#
# 判定规则（很关键）：
#   必须启用（must_y）：.config 里必须出现 "<SYM>=y"
#   必须禁用（must_n）：.config 里只要不是 "=y" 就算通过。
#   因为 kconfig 对「从未被引用」的符号压根不会写任何行（既没有 =n 也没有
#   "# ... is not set"），旧版脚本要求必须出现 "is not set" 会把
#   kmod-r8169 这类被 trim 掉、且无人引用的符号误判成失败。
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

# 挂载点相关：25.12 已把 block-mount 并入 fstools，LuCI 侧也没有 luci-app-fstab，
# 这两个符号现在不存在。保留在禁用清单里，是为了将来上游若恢复它们时能被拦住。
must_n="
CONFIG_PACKAGE_luci-app-fstab
CONFIG_PACKAGE_block-mount
CONFIG_PACKAGE_luci-app-diskman
CONFIG_PACKAGE_kmod-r8169
CONFIG_PACKAGE_kmod-e1000e
CONFIG_PACKAGE_kmod-e100
CONFIG_PACKAGE_kmod-igb
CONFIG_PACKAGE_kmod-ixgbe
CONFIG_PACKAGE_kmod-drm-i915
CONFIG_RUBY_ENABLE_YJIT
"
# CONFIG_RUBY_ENABLE_YJIT 必须禁用：它一开就会拉 rust/host（rustc 内部再编整套 LLVM），
# 单次构建多耗 2 小时以上。OpenClash 只用 ruby + ruby-yaml，不需要 YJIT。

bad=0
for s in $must_y; do
  if ! grep -qx "$s=y" .config; then
    echo "FAIL 缺少 $s=y"
    bad=1
  fi
done

for s in $must_n; do
  if grep -qx "$s=y" .config; then
    echo "FAIL 不该启用却启用了 $s=y"
    bad=1
  fi
done

if [ "$bad" -ne 0 ]; then
  echo "== 配置校验失败，相关行如下 =="
  for s in $must_y $must_n; do
    line=$(grep -nE "^(# )?${s}(=| is not set)" .config || true)
    echo "${line:-（.config 中无此符号）}  <- $s"
  done
  echo "== 生成的 .config 已上传为 artifact，便于排查 =="
  exit 1
fi

echo "== 配置校验通过：$(grep -c '^CONFIG_' .config) 行配置，关键符号全部匹配"
