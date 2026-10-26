#!/usr/bin/env bash
# 检查 rootfs 里"简体中文 + Argon 默认主题 + OpenClash 内核与数据库"是否真的存在
set -euo pipefail

V=${1:?用法: verify_firmware.sh <版本号> <plain|preconfigured>}
MODE=${2:-plain}

TAR=$(ls -1 openwrt/bin/targets/x86/64/*-rootfs.tar.gz 2>/dev/null | head -1 || true)
[ -n "$TAR" ] && [ -f "$TAR" ] || {
	echo "找不到 rootfs.tar.gz（openwrt/bin/targets/x86/64/）"
	ls -lh openwrt/bin/targets/x86/64 2>/dev/null || true
	exit 1
}
echo "== 检查 $TAR"

LIST=$(tar -tzf "$TAR")
fail=0

chk() {
  if printf '%s\n' "$LIST" | grep -q "$1"; then
    echo "OK   $2"
  else
    echo "FAIL $2"
    fail=1
  fi
}

chk 'etc/uci-defaults/99-luci-zh-argon' 'Argon/中文 首启脚本已打包'

# 首启脚本必须带执行位，否则永远不会被执行
mode=$(tar -tvzf "$TAR" | grep -F 'etc/uci-defaults/99-luci-zh-argon' | head -1 | awk '{print $1}')
case "$mode" in
  -rwx*) echo "OK   首启脚本可执行 ($mode)" ;;
  *)     echo "FAIL 首启脚本缺少执行位 ($mode)，Argon/中文 不会生效"; fail=1 ;;
esac
chk 'luci-static/argon/'                'Argon 主题文件已打包'
chk 'etc/openclash/core/clash_meta'     'mihomo(Meta) 内核已预置'
chk 'etc/openclash/GeoIP.dat'           'GeoIP 数据库已预置'
chk 'etc/openclash/GeoSite.dat'         'GeoSite 数据库已预置'
chk 'etc/openclash/Country.mmdb'        'Country.mmdb 已预置'
chk 'etc/openclash/ASN.mmdb'            'ASN.mmdb 已预置'

total=$(printf '%s\n' "$LIST" | grep -cE 'i18n/.*\.(lmo|json)' || true)
zh=$(printf '%s\n' "$LIST" | grep -cE 'i18n/.*\.zh[-_][A-Za-z0-9]+\.(lmo|json)' || true)
if [ "$total" -eq 0 ]; then
  echo "WARN 未发现 i18n 资源文件，跳过语言包数量检查（请你人工确认界面语言）"
elif [ "$zh" -lt 1 ]; then
  echo "FAIL 有 $total 个语言包，但没有任何中文语言包"
  fail=1
else
  echo "OK   中文语言包 $zh / 共 $total"
fi

if [ "$MODE" = "plain" ]; then
  if printf '%s\n' "$LIST" | grep -q 'etc/uci-defaults/90-preconfigured'; then
    echo "FAIL 普通版不应包含预配置脚本"
    fail=1
  else
    echo "OK   普通版不含预配置脚本"
  fi
fi

if [ "$fail" -ne 0 ]; then
  echo "== 固件自检失败"
  exit 1
fi
echo "== 固件自检通过"
