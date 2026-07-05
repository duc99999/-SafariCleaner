THEOS_PACKAGE_NAME = safecleaner
THEOS_DEVICE_IP =
THEOS_DEVICE_PORT =

TARGET := iphone:clang:latest:14.5
ARCHS = arm64

TWEAK_NAME = SafariCleaner
SUBPROJECTS += SAFECleanerPref

# Khai báo files TRƯỚC khi include tweak.mk
SafariCleaner_FILES = Tweak.x SAFECleanerRoot.m
SafariCleaner_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -std=gnu11
SafariCleaner_FRAMEWORKS = UIKit Foundation Security
SafariCleaner_PRIVATE_FRAMEWORKS = MobileSafari SafariFoundation WebKit WebKitLegacy Preferences
SafariCleaner_LDFLAGS = -lsubstrate -ldl
SafariCleaner_INSTALL_PATH = /var/jb/Library/MobileSubstrate/DynamicLibraries

include $(THEOS)/makefiles/common.mk
include $(THEOS)/makefiles/tweak.mk

include $(THEOS_MAKE_PATH)/aggregate.mk
