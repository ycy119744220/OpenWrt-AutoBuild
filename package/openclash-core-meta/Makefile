#
# mihomo (Meta) 内核 —— 编译期从 MetaCubeX/mihomo 官方 release 下载 x86_64 v1 版本
# OpenClash 运行时期望的内核路径：/etc/openclash/core/clash_meta
#
# 说明：OpenClash 自己的仓库里没有预编译内核（它是在运行时装好后再联网下载），
# 所以必须由本包把它编进固件，做到开箱即用、首次启动不等下载。
#
include $(TOPDIR)/rules.mk

PKG_NAME:=openclash-core-meta
PKG_RELEASE:=1

# 解析 mihomo 最新 tag；取不到就回落到一个固定版本，保证构建可复现
MIHOMO_TAG:=$(strip $(shell curl -fsSL --max-time 25 \
	https://api.github.com/repos/MetaCubeX/mihomo/releases/latest 2>/dev/null \
	| sed -n 's/.*"tag_name": *"\(v[^"]*\)".*/\1/p' | head -1))
ifeq ($(MIHOMO_TAG),)
  MIHOMO_TAG:=v1.19.33
endif

PKG_VERSION:=$(patsubst v%,%,$(MIHOMO_TAG))
CORE_FILE:=mihomo-linux-amd64-v1-$(MIHOMO_TAG).gz
CORE_URL:=https://github.com/MetaCubeX/mihomo/releases/download/$(MIHOMO_TAG)/$(CORE_FILE)

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/openclash-core-meta
  SECTION:=net
  CATEGORY:=Network
  TITLE:=mihomo (Meta) core $(MIHOMO_TAG) for OpenClash (x86_64)
  PKGARCH:=x86_64
  DEPENDS:=@TARGET_x86_64
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	@echo "==> 下载 mihomo 内核 $(MIHOMO_TAG)：$(CORE_URL)"
	curl -fsSL --retry 3 -o $(PKG_BUILD_DIR)/core.gz "$(CORE_URL)" || \
		{ echo "!!! 内核下载失败，中止编译（不要产出没有内核的固件）"; exit 1; }
	gzip -dc $(PKG_BUILD_DIR)/core.gz > $(PKG_BUILD_DIR)/clash
	chmod 0755 $(PKG_BUILD_DIR)/clash
	@test -s $(PKG_BUILD_DIR)/clash || { echo "!!! 解压后的内核为空"; exit 1; }
	@$(PKG_BUILD_DIR)/clash -v 2>/dev/null | head -1 || echo "(内核无法在构建机运行，跳过版本自检)"
	@rm -f $(PKG_BUILD_DIR)/core.gz
endef

define Build/Compile
endef

define Package/openclash-core-meta/install
	$(INSTALL_DIR) $(1)/etc/openclash/core
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/clash $(1)/etc/openclash/core/clash_meta
endef

$(eval $(call BuildPackage,openclash-core-meta))
