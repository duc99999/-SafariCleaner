THEOS_PACKAGE_NAME = safecleaner
# Build cho rootless jailbreak (Dopamine / palera1n rootless / Cheyote)
# Layout đã được cấu trúc lại dưới layout/var/jb/...
TARGET := iphone:clang:15.5:15.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SafariCleaner
SafariCleaner_FILES = Tweak.x SAFECleanerRoot.m
SafariCleaner_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -std=gnu11
SafariCleaner_FRAMEWORKS = UIKit Foundation Security
SafariCleaner_PRIVATE_FRAMEWORKS = MobileSafari SafariFoundation WebKit WebKitLegacy Preferences
SafariCleaner_LDFLAGS = -lsubstrate -ldl
SafariCleaner_INSTALL_PATH = /var/jb/Library/MobileSubstrate/DynamicLibraries

SUBPROJECTS += SAFECleanerPref
include $(THEOS_MAKE_PATH)/aggregate.mk

# === Local-only: đóng gói deb từ layout đã chuẩn bị ===
#   make package-local   - chỉ đóng gói, không cần Theos/toolchain
#   make full-local      - đóng gói + verify (khuyến nghị)
.PHONY: package-local full-local clean-local verify-deb
package-local:
	@echo "==> Đóng gói deb từ layout/..."
	@mkdir -p packages
	@rm -f packages/$(THEOS_PACKAGE_NAME)_*.deb
	@cd layout && tar --owner=0 --group=0 -czf ../packages/data.tar.gz \
		DEBIAN var
	@cd layout && tar --owner=0 --group=0 -cf ../packages/control.tar.gz DEBIAN
	@cd packages && \
		echo "2.0" > debian-binary && \
		ar rcs $(THEOS_PACKAGE_NAME)_1.0.0_iphoneos-arm64.deb \
			debian-binary control.tar.gz data.tar.gz
	@echo "==> Hoàn tất: packages/$(THEOS_PACKAGE_NAME)_1.0.0_iphoneos-arm64.deb"

verify-deb: package-local
	@echo "==> Cấu trúc deb:"
	@ar t packages/$(THEOS_PACKAGE_NAME)_1.0.0_iphoneos-arm64.deb
	@echo ""
	@echo "==> Nội dung data.tar.gz (nội dung thật sự cài vào iPhone):"
	@cd layout && tar -tzf ../packages/data.tar.gz
	@echo ""
	@echo "==> Verify không còn rootful paths:"
	@cd layout && tar -tzf ../packages/data.tar.gz | \
		( grep -E '^./(Library|usr)/' || \
		  echo "OK - Tất cả path đều dưới /var/jb/ (rootless)" )

full-local: verify-deb
	@echo ""
	@echo "==> packages/$(THEOS_PACKAGE_NAME)_1.0.0_iphoneos-arm64.deb đã sẵn sàng"
	@echo "==> Copy file này sang iPhone và cài bằng Filza:"

clean-local:
	@rm -rf packages