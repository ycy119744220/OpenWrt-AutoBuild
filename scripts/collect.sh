#!/usr/bin/env bash
# 从 bin/targets 收集需要发布的产物（用 glob 匹配，不硬编码设备名）
set -euo pipefail

V=${1:?用法: collect.sh <版本号，不含 v>}
SRC=openwrt/bin/targets/x86/64
mkdir -p release

pick() {
	local pattern=$1 desc=$2 f
	f=$(ls -1 ${SRC}/${pattern} 2>/dev/null | grep -v 'preconfigured' | head -1 || true)
	if [ -z "$f" ]; then
		echo "缺少产物（${desc}）：${SRC}/${pattern}"
		echo "== 实际产物列表 =="
		ls -lh "$SRC" 2>/dev/null || true
		exit 1
	fi
	printf '%s' "$f"
}

IMG=$(pick '*-ext4-combined-efi.img.gz' 'EFI 引导 ext4 合并镜像')
ROOTFS=$(pick '*-rootfs.tar.gz' 'rootfs 归档')
KERNEL=$(pick '*-kernel.bin' '内核')

echo "==> 镜像:   $IMG"
echo "==> rootfs: $ROOTFS"
echo "==> 内核:   $KERNEL"

cp -f "$IMG" "$ROOTFS" "$KERNEL" release/

# 注意：不要在 release/ 里放隐藏文件当"元数据"。softprops/action-gh-release
# 会把点开头的文件改名成 default.<name> 再上传，于是 Release 里会多出一个
# 无用的 default.imagename 附件。真需要记录就写到 /tmp。
basename "$IMG" > /tmp/imagename.txt
ls -lh release
