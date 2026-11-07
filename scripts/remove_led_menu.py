#!/usr/bin/env python3
"""编译期移除「系统 → LED 配置」菜单条目。

为什么必须在编译期改源文件（血泪教训）：
  LuCI 25.12 的菜单树由 modules/luci-base/ucode/dispatcher.uc 的 build_pagetree()
  直接读取 /usr/share/luci/menu.d/*.json 构建，并按文件列表哈希缓存到
  /tmp/luci-indexcache.*.json。菜单项根本不存在于 /etc/config/luci，
  因此在 uci-defaults 里用 uci 删除菜单节点是无效的 —— 脚本会正常退出，
  自检还会因为「脚本已打包且有执行位」而误判通过，但菜单一个字都没变。

  正确做法是在 feeds 拉取完成、开始编译之前，把 feed 源文件里的这个键删掉，
  让它根本不进 rootfs。

判定方式：菜单项的 key 是 "admin/system/leds"，其 action.path 是 "system/leds"。
两个条件都认，这样上游即使改了 key 也仍能命中。

幂等：脚本重复运行时条目已不存在，只要 luci-mod-system 的菜单文件还在就正常退出；
      连文件都找不到（上游改了目录结构）才报错，避免静默失效。
"""

import json
import pathlib
import sys

KEY = "admin/system/leds"
PATH = "system/leds"
TARGET_FILE = "luci-mod-system.json"

# feeds install -a 会在 package/feeds/luci 下建软链接指回 feeds/luci，
# 两个根都扫一遍，用 realpath 去重，避免符号链接导致重复处理或漏改。
ROOTS = [
    pathlib.Path("openwrt/feeds/luci"),
    pathlib.Path("openwrt/package/feeds/luci"),
]


def is_led_entry(key, spec):
    if key == KEY:
        return True
    if isinstance(spec, dict):
        action = spec.get("action")
        if isinstance(action, dict) and action.get("path") == PATH:
            return True
    return False


def main():
    files = []
    seen = set()
    for root in ROOTS:
        if not root.exists():
            continue
        for p in root.rglob("*.json"):
            if p.parent.name != "menu.d":
                continue
            real = p.resolve()
            if real in seen:
                continue
            seen.add(real)
            files.append(real)

    if not files:
        sys.exit("[led-menu] 找不到任何 menu.d/*.json，feeds 可能没安装成功")

    found_target = any(p.name == TARGET_FILE for p in files)
    removed = 0
    changed = []

    for p in files:
        try:
            data = json.loads(p.read_text(encoding="utf-8"))
        except (OSError, ValueError) as e:
            sys.exit(f"[led-menu] 无法解析 {p}: {e}")
        if not isinstance(data, dict):
            continue

        hits = [k for k, v in data.items() if is_led_entry(k, v)]
        if not hits:
            continue
        for k in hits:
            del data[k]
        p.write_text(json.dumps(data, ensure_ascii=False, indent="\t") + "\n",
                     encoding="utf-8")
        removed += len(hits)
        changed.append((p, hits))

    for p, hits in changed:
        print(f"[led-menu] {p}: 移除 {', '.join(hits)}")

    if removed == 0:
        if not found_target:
            sys.exit(f"[led-menu] 找不到 {TARGET_FILE}，上游目录结构可能已变更，请检查")
        print(f"[led-menu] 菜单条目本就不存在（上游已移除或已处理过），无需改动")
    else:
        print(f"[led-menu] 共移除 {removed} 个条目，涉及 {len(changed)} 个文件")

    # 结果自检：改完再读一遍，确认真的没了
    left = []
    for p in files:
        try:
            data = json.loads(p.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        if isinstance(data, dict):
            left += [k for k, v in data.items() if is_led_entry(k, v)]
    if left:
        sys.exit(f"[led-menu] 校验失败，仍有条目：{left}")
    print("[led-menu] 结果校验通过：所有 menu.d 里都不再有 LED 配置菜单")
    return 0


if __name__ == "__main__":
    sys.exit(main())
