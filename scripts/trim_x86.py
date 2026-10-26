#!/usr/bin/env python3
"""剔除 x86_64 设备默认包里不需要的网卡/显卡驱动。

25.12 起，x86 的驱动不再列在 target/linux/x86/Makefile，而是在
target/linux/x86/image/64.mk 的 Device/generic -> DEVICE_PACKAGES 中。
仅靠 .config 的 =n 不一定能压住这些设备默认项，所以直接改 Makefile。

注意：整块读完再重新排版，避免删空行后遗留续行反斜杠把下一行吃掉。
"""

import pathlib
import re
import sys

KEEP = {"kmod-igc", "kmod-fs-vfat"}
PATH = pathlib.Path("target/linux/x86/image/64.mk")
PER_LINE = 4

if not PATH.exists():
    sys.exit(f"[trim] 找不到 {PATH}，上游目录结构可能已变更")

lines = PATH.read_text().splitlines()
out: list[str] = []
removed: list[str] = []
i = 0

while i < len(lines):
    line = lines[i]
    if not re.match(r"\s*DEVICE_PACKAGES\s*\+=", line):
        out.append(line)
        i += 1
        continue

    header = line
    i += 1
    tokens: list[str] = []
    while i < len(lines):
        cur = lines[i]
        cont = cur.rstrip().endswith("\\")
        body = cur.rstrip()[:-1].rstrip() if cont else cur.rstrip()
        tokens += body.split()
        i += 1
        if not cont:
            break

    kept: list[str] = []
    for tok in tokens:
        if tok.startswith("kmod-") and tok not in KEEP:
            removed.append(tok)
        else:
            kept.append(tok)

    out.append(header)
    for n in range(0, len(kept), PER_LINE):
        chunk = kept[n:n + PER_LINE]
        sep = " \\" if n + PER_LINE < len(kept) else ""
        out.append("\t" + " ".join(chunk) + sep)

PATH.write_text("\n".join(out) + "\n")
print("[trim] 移除:", " ".join(removed) if removed else "(无)")
print("[trim] 保留:", " ".join(t for t in kept if t.startswith("kmod-")))
