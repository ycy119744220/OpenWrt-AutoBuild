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
cleanup() {
	sudo umount "$work/mnt" 2>/dev/null || true
	[ -n "$loop" ] && sudo losetup -d "$loop" 2>/dev/null || true
	rm -rf "$work"
}
trap cleanup EXIT

echo "==> 源镜像: $SRC"
echo "==> 目标:   $DST"
echo "==> 解压镜像"
gunzip -c "$SRC" > "$work/disk.img"

echo "==> 挂载 rootfs 分区"
loop=$(sudo losetup -fP --show "$work/disk.img")
root=$(lsblk -ln -o NAME,FSTYPE "$loop" | awk '$2=="ext4"{print "/dev/"$1; exit}')
[ -n "$root" ] || { echo "镜像内未找到 ext4 分区"; exit 1; }
echo "    rootfs: $root"

mkdir -p "$work/mnt"
sudo e2fsck -f -y "$root" || true
sudo mount "$root" "$work/mnt"

echo "==> 写入预置配置"
sudo cp -a "$OVERLAY/." "$work/mnt/"
sudo chmod 0755 "$work/mnt"/etc/uci-defaults/* 2>/dev/null || true

if [ ! -f "$work/mnt/etc/uci-defaults/90-preconfigured" ]; then
	echo "预配置脚本未写入镜像"
	exit 1
fi
mod=$(sudo stat -c '%a' "$work/mnt/etc/uci-defaults/90-preconfigured")
[ "$mod" = "755" ] || { echo "预配置脚本权限异常: $mod"; exit 1; }

sync
sudo umount "$work/mnt"
sudo losetup -d "$loop"
loop=""

echo "==> 重新压缩"
gzip -9 -c "$work/disk.img" > "$DST"
ls -lh "$DST"
gzip -t "$DST" && echo "==> gzip 完整性校验通过"
