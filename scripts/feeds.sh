#!/usr/bin/env bash
# 克隆 OpenWrt 指定 tag -> 安装官方 feeds -> 把第三方包放进 package/
set -euo pipefail

TAG=${1:?用法: feeds.sh <openwrt-tag>}

echo "==> 克隆 OpenWrt ${TAG}"
git clone --depth 1 -b "$TAG" https://github.com/openwrt/openwrt.git openwrt
cd openwrt

echo "==> 安装官方 feeds（packages / luci / routing / telephony / video）"
./scripts/feeds update -a
./scripts/feeds install -a

# 说明（这是一次真实踩坑）：
# luci-theme-argon 与 luci-app-argon-config 都是「仓库根目录就是包本身」的结构。
# 若写成 src-git feed，25.12 的 feeds 索引生成会把包自己的 Makefile 当成 feed 索引
# 去解析，得到：
#     feeds/argon.tmp/info/.files-packageinfo.mk:1: *** target pattern contains no '%'
#     Ignoring feed 'argon' - index missing
# 结果是整条 feed 被丢弃、luci-theme-argon 根本不进包树，defconfig 后 .config 里
# 连这个符号都不存在。所以改为直接 clone 到 package/，完全绕开索引生成。
fetch_pkg() {
	local repo=$1 dest=$2 tag=""
	tag=$(curl -fsSL "https://api.github.com/repos/jerrykuku/${repo}/releases/latest" 2>/dev/null \
		| sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1) || true

	rm -rf "package/${dest}"
	if [ -n "${tag}" ] && git clone --depth 1 -b "${tag}" \
		"https://github.com/jerrykuku/${repo}.git" "package/${dest}" 2>/dev/null; then
		echo "==> ${dest} @ ${tag}"
	else
		rm -rf "package/${dest}"
		git clone --depth 1 "https://github.com/jerrykuku/${repo}.git" "package/${dest}"
		echo "==> ${dest} @ 默认分支（未取到 release tag）"
	fi
}

fetch_pkg luci-theme-argon      luci-theme-argon
fetch_pkg luci-app-argon-config luci-app-argon-config

echo "==> 拉取 OpenClash 最新 release"
oc_tag=$(curl -fsSL https://api.github.com/repos/vernesong/OpenClash/releases/latest \
  | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1) || true
rm -rf /tmp/openclash
if [ -n "${oc_tag}" ] && git clone --depth 1 -b "${oc_tag}" \
     https://github.com/vernesong/OpenClash.git /tmp/openclash 2>/dev/null; then
  echo "==> OpenClash @ ${oc_tag}"
else
  rm -rf /tmp/openclash
  git clone --depth 1 https://github.com/vernesong/OpenClash.git /tmp/openclash
  echo "==> OpenClash @ master（未匹配到 release tag，回落主分支）"
fi
rm -rf package/luci-app-openclash
cp -r /tmp/openclash/luci-app-openclash package/luci-app-openclash

echo "==> 复制本仓库的本地包（OpenClash 内核与 4 个数据库）"
rm -rf package/openclash-core-meta package/openclash-geo-db
cp -r ../package/openclash-core-meta ../package/openclash-geo-db package/

echo "==> 组件版本"
show_pkg() {
	local d=$1
	[ -f "${d}/Makefile" ] || { echo "!!! 缺失 ${d}"; return 0; }
	printf '%-32s' "${d}:"
	grep -m1 -E '^(PKG_NAME|LUCI_TITLE):=' "${d}/Makefile" | sed 's/^[^:]*:=//' | tr -d '\n'
	printf ' %s-%s\n' \
		"$(grep -m1 -E '^PKG_VERSION:=' "${d}/Makefile" | sed 's/^[^:]*:=//')" \
		"$(grep -m1 -E '^PKG_RELEASE:=' "${d}/Makefile" | sed 's/^[^:]*:=//')"
}
show_pkg package/luci-theme-argon
show_pkg package/luci-app-argon-config
show_pkg package/luci-app-openclash
show_pkg package/openclash-core-meta
show_pkg package/openclash-geo-db

# 关键校验：三个第三方包的源码必须真的在位，否则后面 defconfig 会静默丢包
for d in package/luci-theme-argon package/luci-app-argon-config package/luci-app-openclash; do
	[ -f "${d}/Makefile" ] || { echo "!! ${d} 没有 Makefile，第三方源拉取失败"; exit 1; }
done
echo "==> 第三方包就位"
