#
# OpenClash 所需的四个数据库：GeoIP / GeoSite / Country.mmdb / ASN.mmdb
# 来源：MetaCubeX/meta-rules-dat 的 latest 滚动 release（文件名固定，可长期引用）
#
# 采用 Build/Prepare 直接 curl，而不是 PKG_SOURCE/多文件下载：
# 四个文件名大小写不一致、又不带版本号，走 buildroot 的下载器容易出意外，
# 直接下载失败就 exit 1 反而更明确。
#
include $(TOPDIR)/rules.mk

PKG_NAME:=openclash-geo-db
PKG_VERSION:=1.0
PKG_RELEASE:=1

GEO_BASE:=https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/openclash-geo-db
  SECTION:=net
  CATEGORY:=Network
  TITLE:=GeoIP/GeoSite/Country.mmdb/ASN.mmdb for OpenClash
  PKGARCH:=all
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	curl -fsSL --retry 3 -o $(PKG_BUILD_DIR)/geoip.dat    $(GEO_BASE)/geoip.dat
	curl -fsSL --retry 3 -o $(PKG_BUILD_DIR)/geosite.dat  $(GEO_BASE)/geosite.dat
	curl -fsSL --retry 3 -o $(PKG_BUILD_DIR)/country.mmdb $(GEO_BASE)/country.mmdb
	curl -fsSL --retry 3 -o $(PKG_BUILD_DIR)/asn.mmdb     $(GEO_BASE)/GeoLite2-ASN.mmdb
	for f in geoip.dat geosite.dat country.mmdb asn.mmdb; do \
		test -s "$(PKG_BUILD_DIR)/$$f" || { echo "!!! 下载失败或为空: $$f"; exit 1; }; \
	done
	ls -l $(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/openclash-geo-db/install
	$(INSTALL_DIR) $(1)/etc/openclash
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/geoip.dat    $(1)/etc/openclash/GeoIP.dat
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/geosite.dat  $(1)/etc/openclash/GeoSite.dat
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/country.mmdb $(1)/etc/openclash/Country.mmdb
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/asn.mmdb     $(1)/etc/openclash/ASN.mmdb
endef

$(eval $(call BuildPackage,openclash-geo-db))
