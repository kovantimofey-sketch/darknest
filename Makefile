TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DarkIcons

DarkIcons_FILES = Tweak.x
DarkIcons_FRAMEWORKS = UIKit QuartzCore
DarkIcons_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
