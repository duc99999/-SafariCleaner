THEOS_PACKAGE_NAME = safecleaner
THEOS_DEVICE_IP =
THEOS_DEVICE_PORT =

# Toolchain & SDK cho iOS 14.5 (khớp workflow để tránh bị patch)
TARGET := iphone:clang:latest:14.5
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
