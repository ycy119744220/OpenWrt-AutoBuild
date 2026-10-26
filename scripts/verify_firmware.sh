#!/usr/bin/env bash
# 检查 rootfs 里"简体中文 + Argon 默认主题 + OpenClash 内核与数据库"是否真的存在
#
# 注意两个历史坑（都曾导致镜像明明是好的却自检失败）：
#   1) OpenWrt 的 rootfs.tar.gz 条目带 "./" 前缀，直接拿 tar -tv 的 $NF 做精确比对会全部落空；
#   2) 本脚本开了 pipefail，`printf | grep -q` 里 grep 命中后立刻退出会让 printf 收到 SIGPIPE(141)，
#      整条管道被判失败 —— 于是"匹配成功"反而输出 FAIL。
# 因此这里先把 tar -tv 结果落盘成两个文件（名字表 / 名字+大小表），后续全部读文件，不再走管道。
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

WORK=$(mktemp -d)
trap 'rm -rf "$WORK" 2>/dev/null || true' EXIT

TVFILE=$WORK/tv.raw     # tar -tv 原始输出（取权限位）
LISTF=$WORK/names.txt   # 归一化后的条目名，一行一个
TABLE=$WORK/table.tsv   # 条目名 \t 字节数

tar -tvzf "$TAR" >"$TVFILE"
awk '{ n = $NF; sub(/^\.\//, "", n); print n }' "$TVFILE" >"$LISTF"
awk '{ n = $NF; sub(/^\.\//, "", n); print n "\t" $3 }' "$TVFILE" >"$TABLE"

echo "== rootfs 条目数: $(wc -l <"$LISTF")"
fail=0

# 子串匹配（目录类检查用）
chk() {
	if grep -q -- "$1" "$LISTF"; then
		echo "OK   $2"
	else
		echo "FAIL $2"
		fail=1
	fi
}

# 校验某个文件存在且体积不小于阈值（字节）
chk_size() {
	local path=$1 min=$2 desc=$3 size
	size=$(awk -F'\t' -v p="$path" '$1 == p { print $2; exit }' "$TABLE")
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
mode=$(awk '$NF ~ /etc\/uci-defaults\/99-luci-zh-argon$/ { print $1; exit }' "$TVFILE")
case "$mode" in
	-rwx*) echo "OK   首启脚本可执行 ($mode)" ;;
	*)     echo "FAIL 首启脚本缺少执行位 (${mode:-未找到})，Argon/中文 不会生效"; fail=1 ;;
esac

chk 'luci-static/argon/' 'Argon 主题文件已打包'

# OpenClash 本体（启动脚本 + 资源目录）也在镜像里才说明插件真的装上了
chk 'etc/init.d/openclash' 'OpenClash 启动脚本已打包'
chk 'share/openclash/' 'OpenClash 资源目录已打包'

chk_size 'etc/openclash/core/clash_meta' 3000000 'mihomo(Meta) 内核已预置'

# 四个数据库必须是我们装的真实文件：
# OpenClash 包自带的 Country.mmdb 只有 205KB 的桩，GeoSite.dat 也偏旧，
# 这些已被 feeds.sh 删除、改由 openclash-geo-db 提供，这里用体积兜底防止回退。
chk_size 'etc/openclash/GeoIP.dat' 500000 'GeoIP.dat 已预置'
chk_size 'etc/openclash/GeoSite.dat' 500000 'GeoSite.dat 已预置'
chk_size 'etc/openclash/Country.mmdb' 500000 'Country.mmdb 已预置'
chk_size 'etc/openclash/ASN.mmdb' 100000 'ASN.mmdb 已预置'

total=$(grep -cE 'i18n/.*\.(lmo|json)' "$LISTF" || true)
zh=$(grep -cE 'i18n/.*\.zh[-_][A-Za-z0-9]+\.(lmo|json)' "$LISTF" || true)
if [ "$total" -eq 0 ]; then
	echo "WARN 未发现 i18n 资源文件，跳过语言包数量检查（请你人工确认界面语言）"
elif [ "$zh" -lt 1 ]; then
	echo "FAIL 有 $total 个语言包，但没有任何中文语言包"
	fail=1
else
	echo "OK   中文语言包 $zh / 共 $total"
fi

if [ "$MODE" = "plain" ]; then
	if grep -q -- 'etc/uci-defaults/90-preconfigured' "$LISTF"; then
		echo "FAIL 普通版不应包含预配置脚本"
		fail=1
	else
		echo "OK   普通版不含预配置脚本"
	fi
else
	chk 'etc/uci-defaults/90-preconfigured' '预配置首启脚本已打包'
fi

if [ "$fail" -ne 0 ]; then
	echo "== 固件自检失败"
	echo "---- 以下为 OpenClash / 首启脚本相关实际条目，便于排查 ----"
	grep -E 'openclash|uci-defaults|argon' "$LISTF" | head -40 || true
	exit 1
fi
echo "== 固件自检通过"
