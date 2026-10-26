#!/usr/bin/env bash
# 克隆 OpenWrt 指定 tag，注入第三方 feeds，并把 OpenClash 放进 package/
set -euo pipefail

TAG=${1:?用法: feeds.sh <openwrt-tag>}

echo "==> 克隆 OpenWrt ${TAG}"
git clone --depth 1 -b "$TAG" https://github.com/openwrt/openwrt.git openwrt
cd openwrt

echo "==> 追加第三方 feeds"
[ -n "$(tail -c 1 feeds.conf.default)" ] && echo >> feeds.conf.default
cat >> feeds.conf.default <<'EOF'
src-git argon https://github.com/jerrykuku/luci-theme-argon.git
src-git argonconfig https://github.com/jerrykuku/luci-app-argon-config.git
EOF
cat feeds.conf.default

echo "==> feeds update / install"
./scripts/feeds update -a
./scripts/feeds install -a

echo "==> 拉取 OpenClash 最新 release"
oc_tag=$(curl -fsSL https://api.github.com/repos/vernesong/OpenClash/releases/latest \
  | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
rm -rf /tmp/openclash
if [ -n "$oc_tag" ] && git clone --depth 1 -b "$oc_tag" \
     https://github.com/vernesong/OpenClash.git /tmp/openclash 2>/dev/null; then
  echo "OpenClash: ${oc_tag}"
else
  git clone --depth 1 https://github.com/vernesong/OpenClash.git /tmp/openclash
  echo "OpenClash: master（未匹配到 release tag，回落主分支）"
fi
rm -rf package/luci-app-openclash
cp -r /tmp/openclash/luci-app-openclash package/luci-app-openclash

echo "==> 复制本仓库的本地包（OpenClash 内核与数据库）"
rm -rf package/openclash-core-meta package/openclash-geo-db
cp -r ../package/openclash-core-meta ../package/openclash-geo-db package/

echo "==> 组件版本"
grep -hE '^(LUCI_TITLE|PKG_VERSION|PKG_RELEASE)' \
  package/feeds/argon/luci-theme-argon/Makefile 2>/dev/null || true
grep -hE '^PKG_VERSION' package/luci-app-openclash/Makefile 2>/dev/null || true
