#
# OpenClash 所需的四个数据库：GeoIP / GeoSite / Country.mmdb / ASN.mmdb
# 来源 MetaCubeX/meta-rules-dat 的 latest 滚动 release
#
include $(TOPDIR)/rules.mk

PKG_NAME:=openclash-geo-db
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_SOURCE:=geoip.dat geosite.dat country.mmdb GeoLite2-ASN.mmdb
PKG_SOURCE_URL:=https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest
PKG_HASH:=skip

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=net
  CATEGORY:=Network
  TITLE:=GeoIP/GeoSite/MMDB/ASN databases for OpenClash
  PKGARCH:=all
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/openclash
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/geoip.dat         $(1)/etc/openclash/GeoIP.dat
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/geosite.dat       $(1)/etc/openclash/GeoSite.dat
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/country.mmdb      $(1)/etc/openclash/Country.mmdb
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/GeoLite2-ASN.mmdb $(1)/etc/openclash/ASN.mmdb
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
