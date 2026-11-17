#!/usr/bin/env bash
# 取 OpenWrt 上游最新正式版 tag，供三个工作流共用。
#
# 背景（2026-11-17 真实故障）：此前用匿名 curl 调 GitHub API，匿名限额是
# 「每 IP 每小时 60 次」，而 GitHub 托管 runner 的出口 IP 被全球任务共享，
# 一旦被别人的用量撞满就返回 403，check-upstream 当天整条检测失败。
# 认证后限额变为「每仓库每小时 1000 次」，且对 API 加 3 次重试兜底。
#
# 用法: resolve_tag.sh [指定tag]
#   - 指定 tag 非空时直接使用（用于重编历史版本）
#   - 留空时取上游最新 vX.Y.Z 正式版
# 输出:
#   - 日志「上游版本: X」
#   - GITHUB_OUTPUT: version=X（供 job outputs / steps 引用）
#   - GITHUB_ENV:    VERSION=X、VERFILE=X去v（供后续步骤用）
#   本地调试（无 GITHUB_OUTPUT/ENV）时只打印日志。
set -euo pipefail

IN_TAG=${1:-}
API_URL="https://api.github.com/repos/openwrt/openwrt/releases?per_page=100"

fetch_latest() {
	# 优先 gh api（runner 自带 gh 且 GH_TOKEN 已由工作流注入，自动带认证）；
	# gh 不可用或失败时退回 curl + Bearer。
	if command -v gh >/dev/null 2>&1 && [ -n "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ]; then
		gh api "$API_URL" 2>/dev/null && return 0
	fi
	curl -fsSL ${GH_TOKEN:+-H "Authorization: Bearer ${GH_TOKEN}"} \
		${GITHUB_TOKEN:+-H "Authorization: Bearer ${GITHUB_TOKEN}"} "$API_URL"
}

latest=""
if [ -z "$IN_TAG" ]; then
	for i in 1 2 3; do
		if latest=$(fetch_latest \
			| jq -r '.[] | select(.draft==false and .prerelease==false) | .tag_name' \
			| grep -Ev 'rc|beta|alpha' \
			| grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
			| sort -V | tail -1) && [ -n "$latest" ]; then
			break
		fi
		echo "!! 第 $i 次取上游版本失败（限流或网络），$( [ "$i" -lt 3 ] && echo "10 秒后重试" || echo "放弃" )" >&2
		[ "$i" -lt 3 ] && sleep 10
	done
	[ -n "$latest" ] || { echo "未取到上游稳定版本号"; exit 1; }
else
	latest="$IN_TAG"
fi

echo "上游版本: $latest"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
	echo "version=$latest" >> "$GITHUB_OUTPUT"
fi
if [ -n "${GITHUB_ENV:-}" ]; then
	echo "VERSION=$latest" >> "$GITHUB_ENV"
	echo "VERFILE=${latest#v}" >> "$GITHUB_ENV"
fi
