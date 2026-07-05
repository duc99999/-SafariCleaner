THEOS_PACKAGE_NAME = safecleaner
THEOS_DEVICE_IP =
THEOS_DEVICE_PORT =

TARGET := iphone:clang:latest:14.5
ARCHS = arm64

# === QUAN TRỌNG: Khai báo TWEAK_NAME + SUBPROJECTS TRƯỚC common.mk ===
TWEAK_NAME = SafariCleaner
SUBPROJECTS += SAFECleanerPref

include $(THEOS)/makefiles/common.mk

# === Cài đặt chi tiết cho tweak (sau common.mk) ===
SafariCleaner_FILES = Tweak.x SAFECleanerRoot.m
SafariCleaner_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -std=gnu11
SafariCleaner_FRAMEWORKS = UIKit Foundation Security
SafariCleaner_PRIVATE_FRAMEWORKS = MobileSafari SafariFoundation WebKit WebKitLegacy Preferences
SafariCleaner_LDFLAGS = -lsubstrate -ldl
SafariCleaner_INSTALL_PATH = /var/jb/Library/MobileSubstrate/DynamicLibraries

include $(THEOS_MAKE_PATH)/aggregate.mk
