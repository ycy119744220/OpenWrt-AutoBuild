#
# mihomo (Meta) 核心，编译期从 vernesong/OpenClash 的 meta 目录下载
#
include $(TOPDIR)/rules.mk

PKG_NAME:=openclash-core-meta
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_SOURCE:=clash-linux-amd64-v1.tar.gz
PKG_SOURCE_URL:=https://raw.githubusercontent.com/vernesong/OpenClash/dev/core/dev/meta
PKG_HASH:=skip

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=net
  CATEGORY:=Network
  TITLE:=mihomo (Meta) core for OpenClash (x86_64)
  PKGARCH:=x86_64
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/openclash/core
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/clash $(1)/etc/openclash/core/clash_meta
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
