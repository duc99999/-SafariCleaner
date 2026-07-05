/*
 * SafariCleaner - Tweak.x
 *
 * Hook vào SpringBoard để:
 * 1. Đăng ký Darwin notification listener nhận lệnh wipe từ Pref pane
 * 2. Khi có lệnh -> gọi helper SAFECleanerEngine để thực thi
 *
 * Helper SAFECleanerEngine được định nghĩa trong SAFECleanerRoot.m
 * (Theos biên dịch cả 2 file vào cùng dylib).
 *
 * Hỗ trợ rootless jailbreak (Dopamine / palera1n):
 *   ~/Library... -> var/mobile/Containers/Data/Application/<UUID>/Library/...
 *   ~/Library/Preferences -> var/mobile/Library/Preferences (cfprefsd)
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <substrate.h>

// MARK: - Forward declarations
@interface SAFECleanerEngine : NSObject
+ (BOOL)wipeSafariDataKeepingBackup:(BOOL)keepBackup;
+ (NSString *)safariDataContainerPath;
+ (NSString *)safariBundleContainerPath;
+ (void)restartSafari;
+ (void)killSafariProcesses;
@end

// MARK: - Darwin notification observer
// Lưu ý: Darwin notify CHỈ truyền name, không có userInfo
// -> nên lưu keepBackup qua global atomic
static _Atomic BOOL gKeepBackup = 1;

static void WipePrefsObserver(CFNotificationCenterRef center,
                               void *observer,
                               CFStringRef name,
                               const void *object,
                               CFDictionaryRef userInfo) {
    NSLog(@"[SafariCleaner] Received wipe request (keepBackup=%d)", gKeepBackup);

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        // Kill Safari first (bắt buộc, vì iOS giữ file lock trên database)
        [SAFECleanerEngine killSafariProcesses];

        // Chờ Safari tắt hẳn
        [NSThread sleepForTimeInterval:1.5];

        BOOL ok = [SAFECleanerEngine wipeSafariDataKeepingBackup:gKeepBackup];
        NSLog(@"[SafariCleaner] Wipe %@", ok ? @"OK" : @"FAILED");

        if (ok) {
            [SAFECleanerEngine restartSafari];
        }
    });
}

// Public entry point được Pref pane gọi qua CFNotificationCenter
__attribute__((visibility("default")))
void SafariCleaner_SetKeepBackup(int keepBackup) {
    gKeepBackup = keepBackup ? 1 : 0;
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.duc.safecleaner/doWipe"),
        NULL, NULL, TRUE);
}

// MARK: - SpringBoard hook

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)arg1 {
    %orig;

    // Đăng ký Darwin notification listener (chỉ 1 lần khi SpringBoard boot)
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        WipePrefsObserver,
        CFSTR("com.duc.safecleaner/doWipe"),
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately);

    NSLog(@"[SafariCleaner] SpringBoard hook installed");
}

%end

// MARK: - Constructor (chạy ngay khi dylib được inject)

__attribute__((constructor))
static void SafariCleanerInit(void) {
    NSLog(@"[SafariCleaner] Loaded into process: %@",
        [[NSProcessInfo processInfo] processName]);

    // Bảo đảm listener cũng được đăng ký khi tweak inject vào process khác
    // (như MobileSafari khi uicache khởi động lại sau khi wipe).
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        WipePrefsObserver,
        CFSTR("com.duc.safecleaner/doWipe"),
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately);
}
