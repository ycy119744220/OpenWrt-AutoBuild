#!/usr/bin/env bash
# 把 overlay 注入 ext4 镜像，产出 -preconfigured 版本（不重新编译）
set -euo pipefail

V=${1:?用法: make_preconfigured.sh <版本号> <overlay目录> <输出目录>}
OVERLAY=${2:?}
OUT=${3:?}

SRCDIR=openwrt/bin/targets/x86/64
SRC=$(ls -1 ${SRCDIR}/*-ext4-combined-efi.img.gz 2>/dev/null | grep -v 'preconfigured' | head -1 || true)
[ -n "$SRC" ] || {
	echo "找不到源镜像（${SRCDIR}/*-ext4-combined-efi.img.gz）"
	ls -lh "$SRCDIR" 2>/dev/null || true
	exit 1
}
[ -d "$OVERLAY" ] || { echo "找不到 overlay: $OVERLAY"; exit 1; }
mkdir -p "$OUT"

base=$(basename "$SRC" .img.gz)
DST="${OUT}/${base}-preconfigured.img.gz"

work=$(mktemp -d)
loop=""
mounted=""
cleanup() {
	[ -n "$mounted" ] && sudo umount "$mounted" 2>/dev/null || true
	[ -n "$loop" ] && sudo losetup -d "$loop" 2>/dev/null || true
	rm -rf "$work" 2>/dev/null || true
}
trap cleanup EXIT

echo "==> 源镜像: $SRC"
echo "==> 目标:   $DST"
echo "==> 解压镜像"
gunzip -c "$SRC" >"$work/disk.img"

echo "==> 挂载 rootfs 分区"
loop=$(sudo losetup -fP --show "$work/disk.img")
mountpt="$work/mnt"
mkdir -p "$mountpt"

# 注意：x86 的 ext4-combined-efi 镜像里 p1(内核) 和 p2(rootfs) 都是 ext4，
# 盲取"第一个 ext4"会挂到内核分区 —— 那样文件也能拷进去、自检也能过，
# 但刷机后预配置完全不生效。所以按体积从大到小逐个试挂，
# 只有能读到 /etc/openwrt_release 的分区才算真正的 rootfs。
mapfile -t cands < <(lsblk -lnb -o NAME,FSTYPE,SIZE "$loop" \
	| awk '$2 == "ext4" { print $3, "/dev/" $1 }' | sort -rn | awk '{ print $2 }')
[ "${#cands[@]}" -gt 0 ] || { echo "镜像内未找到 ext4 分区"; exit 1; }

root=""
for dev in "${cands[@]}"; do
	echo "    尝试 $dev（$(lsblk -lnb -o SIZE "$dev" | head -1) 字节）"
	sudo e2fsck -f -y "$dev" >/dev/null 2>&1 || true
	if ! sudo mount "$dev" "$mountpt"; then
		echo "    挂载失败，跳过"
		continue
	fi
	if [ -f "$mountpt/etc/openwrt_release" ]; then
		root=$dev
		mounted=$mountpt
		break
	fi
	echo "    无 etc/openwrt_release，不是 rootfs，换下一个"
	sudo umount "$mountpt"
done
[ -n "$root" ] || { echo "没有哪个 ext4 分区含 /etc/openwrt_release，无法定位 rootfs"; exit 1; }
echo "    rootfs: $root"
grep -E "^(DISTRIB_DESCRIPTION|DISTRIB_RELEASE)" "$mountpt/etc/openwrt_release" || true

echo "==> 写入预置配置"
sudo cp -a "$OVERLAY/." "$mountpt/"
sudo chmod 0755 "$mountpt"/etc/uci-defaults/* 2>/dev/null || true

if [ ! -f "$mountpt/etc/uci-defaults/90-preconfigured" ]; then
	echo "预配置脚本未写入镜像"
	exit 1
fi
mod=$(sudo stat -c '%a' "$mountpt/etc/uci-defaults/90-preconfigured")
[ "$mod" = "755" ] || { echo "预配置脚本权限异常: $mod"; exit 1; }
echo "    overlay 文件清单:"
(cd "$OVERLAY" && find . -type f | sed 's/^/      /')

sync
sudo umount "$mountpt"
mounted=""
sudo losetup -d "$loop"
loop=""

echo "==> 重新压缩"
if command -v pigz >/dev/null 2>&1; then
	pigz -9 -c "$work/disk.img" >"$DST"
else
	gzip -9 -c "$work/disk.img" >"$DST"
fi
ls -lh "$DST"
gzip -t "$DST" && echo "==> gzip 完整性校验通过"
