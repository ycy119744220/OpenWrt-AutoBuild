#!/usr/bin/env bash
# 从 bin/targets 收集需要发布的产物（用 glob 匹配，不硬编码设备名）
#
# Release 只发布两个镜像：
#   <ver>-x86-64-generic-ext4-combined-efi.img.gz              普通版
#   <ver>-x86-64-generic-ext4-combined-efi-preconfigured.img.gz 预配置版（由 make_preconfigured.sh 生成）
# rootfs.tar.gz / kernel.bin / .config / sha256sums.txt 一律不进 Release。
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

# 只做存在性校验，不发布（固件自检要用 rootfs 归档，但那是从 bin/targets 直接读的）
for pat in '*-rootfs.tar.gz' '*-kernel.bin'; do
	ls -1 ${SRC}/${pat} >/dev/null 2>&1 || {
		echo "缺少产物：${SRC}/${pat}"
		ls -lh "$SRC" 2>/dev/null || true
		exit 1
	}
done

echo "==> 镜像:   $IMG"
echo "==> rootfs/kernel 存在性已确认（不发布）"

cp -f "$IMG" release/

# 注意：不要在 release/ 里放隐藏文件当"元数据"。softprops/action-gh-release
# 会把点开头的文件改名成 default.<name> 再上传，于是 Release 里会多出一个
# 无用的 default.imagename 附件。真需要记录就写到 /tmp。
basename "$IMG" > /tmp/imagename.txt
ls -lh release
