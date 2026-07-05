THEOS_PACKAGE_NAME = safecleaner
# Cho CI build: không cần kết nối thiết bị, chỉ build + đóng gói.
# Nếu bạn muốn auto-install qua SSH, set IP/PORT phù hợp.
THEOS_DEVICE_IP =
THEOS_DEVICE_PORT =

# Toolchain & SDK cho iOS 15 rootless (Dopamine / palera1n rootless)
TARGET := iphone:clang:15.5:15.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SafariCleaner
SafariCleaner_FILES = Tweak.x SAFECleanerRoot.m
SafariCleaner_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -std=gnu11
SafariCleaner_FRAMEWORKS = UIKit Foundation Security
SafariCleaner_PRIVATE_FRAMEWORKS = MobileSafari SafariFoundation WebKit WebKitLegacy Preferences
SafariCleaner_LDFLAGS = -lsubstrate -ldl

SUBPROJECTS += SAFECleanerPref
include $(THEOS_MAKE_PATH)/aggregate.mk