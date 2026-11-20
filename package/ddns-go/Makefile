#
# DDNS-GO —— 编译期从 jeessy2/ddns-go 官方 release 下载 linux x86_64 二进制
#
# 说明：OpenWrt 官方 packages/luci feed 里没有 ddns-go（只有传统 ddns-scripts），
# 所以像 openclash-core-meta 一样由本包把它编进固件。DDNS-GO 自带 Web 配置页
# （http://路由IP:9876，首次进入设置密码），不需要也不存在 LuCI 插件。
#
include $(TOPDIR)/rules.mk

PKG_NAME:=ddns-go
PKG_RELEASE:=1

# 解析 ddns-go 最新 tag；取不到就回落到一个固定版本，保证构建可复现
DDNSGO_TAG:=$(strip $(shell curl -fsSL --max-time 25 \
	https://api.github.com/repos/jeessy2/ddns-go/releases/latest 2>/dev/null \
	| sed -n 's/.*"tag_name": *"\(v[^"]*\)".*/\1/p' | head -1))
ifeq ($(DDNSGO_TAG),)
  DDNSGO_TAG:=v6.17.9
endif

PKG_VERSION:=$(patsubst v%,%,$(DDNSGO_TAG))
ASSET_FILE:=ddns-go_$(PKG_VERSION)_linux_x86_64.tar.gz
ASSET_URL:=https://github.com/jeessy2/ddns-go/releases/download/$(DDNSGO_TAG)/$(ASSET_FILE)

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/ddns-go
  SECTION:=net
  CATEGORY:=Network
  TITLE:=DDNS-GO $(DDNSGO_TAG) - dynamic DNS client with web UI (x86_64)
  URL:=https://github.com/jeessy2/ddns-go
  PKGARCH:=x86_64
  DEPENDS:=@TARGET_x86_64
endef

define Package/ddns-go/description
	DDNS-GO：支持阿里云、DNSPod、Cloudflare、华为云等多家服务商的动态域名客户端，
	自带 Web 管理页（默认端口 9876）。配置持久化在 /etc/ddns-go/，刷机/升级不丢。
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	@echo "==> 下载 DDNS-GO $(DDNSGO_TAG)：$(ASSET_URL)"
	curl -fsSL --retry 3 -o $(PKG_BUILD_DIR)/ddns-go.tar.gz "$(ASSET_URL)" || \
		{ echo "!!! DDNS-GO 下载失败，中止编译（不要产出没有 DDNS-GO 的固件）"; exit 1; }
	tar -xzf $(PKG_BUILD_DIR)/ddns-go.tar.gz -C $(PKG_BUILD_DIR) ddns-go || \
		{ echo "!!! 解压失败：压缩包里找不到 ddns-go 二进制"; exit 1; }
	chmod 0755 $(PKG_BUILD_DIR)/ddns-go
	@test -s $(PKG_BUILD_DIR)/ddns-go || { echo "!!! 解压后的 DDNS-GO 为空"; exit 1; }
	@rm -f $(PKG_BUILD_DIR)/ddns-go.tar.gz
endef

define Build/Compile
endef

define Package/ddns-go/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ddns-go $(1)/usr/bin/ddns-go
	$(INSTALL_DIR) $(1)/etc/init.d $(1)/etc/ddns-go
	$(INSTALL_BIN) ./files/ddns-go.init $(1)/etc/init.d/ddns-go
endef

$(eval $(call BuildPackage,ddns-go))
