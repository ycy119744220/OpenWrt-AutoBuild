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

# 只解压/列目录一次：既拿文件名，也拿大小，避免多次遍历 150MB 归档
TV=$(tar -tvzf "$TAR")
LIST=$(printf '%s\n' "$TV" | awk '{print $NF}')
fail=0

chk() {
  if printf '%s\n' "$LIST" | grep -q "$1"; then
    echo "OK   $2"
  else
    echo "FAIL $2"
    fail=1
  fi
}

# 校验某个文件存在且体积不小于阈值（字节）
chk_size() {
  local path=$1 min=$2 desc=$3 size
  size=$(printf '%s\n' "$TV" | awk -v p="$path" '$NF==p {print $3; exit}')
  if [ -z "${size:-}" ]; then
    echo "FAIL $desc（文件不存在: $path）"
    fail=1
  elif [ "$size" -lt "$min" ]; then
    echo "FAIL $desc（体积 ${size}B 小于阈值 ${min}B，很可能是桩文件）"
    fail=1
  else
    echo "OK   $desc（${size}B）"
  fi
}

chk 'etc/uci-defaults/99-luci-zh-argon' 'Argon/中文 首启脚本已打包'

# 首启脚本必须带执行位，否则永远不会被执行
mode=$(printf '%s\n' "$TV" | grep -F 'etc/uci-defaults/99-luci-zh-argon' | head -1 | awk '{print $1}')
case "$mode" in
  -rwx*) echo "OK   首启脚本可执行 ($mode)" ;;
  *)     echo "FAIL 首启脚本缺少执行位 ($mode)，Argon/中文 不会生效"; fail=1 ;;
esac

chk 'luci-static/argon/'            'Argon 主题文件已打包'
chk_size 'etc/openclash/core/clash_meta' 3000000 'mihomo(Meta) 内核已预置'

# 四个数据库必须是我们装的真实文件：
# OpenClash 包自带的 Country.mmdb 只有 205KB 的桩，GeoSite.dat 也偏旧，
# 这些已被 feeds.sh 删除、改由 openclash-geo-db 提供，这里用体积兜底防止回退。
chk_size 'etc/openclash/GeoIP.dat'   500000 'GeoIP.dat 已预置'
chk_size 'etc/openclash/GeoSite.dat' 500000 'GeoSite.dat 已预置'
chk_size 'etc/openclash/Country.mmdb' 500000 'Country.mmdb 已预置'
chk_size 'etc/openclash/ASN.mmdb'     100000 'ASN.mmdb 已预置'

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
