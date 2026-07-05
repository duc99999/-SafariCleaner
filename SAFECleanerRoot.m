/*
 * SAFECleanerRoot.m
 *
 * Triển khai class `SAFECleanerEngine` được khai báo trong Tweak.x.
 *
 * Tất cả các đường dẫn đều viết theo chuẩn **rootless jailbreak**:
 *   ~/Library  ->  /var/jb/var/mobile/Library (đối với daemon)
 *                 hoặc var/mobile/Containers/Data/Application/<UUID>/Library
 *                 (đối với app sandbox khi chạy trong MobileSafari)
 *
 * Để chạy đúng code dưới, tweak phải inject vào một process có quyền truy
 * cập vào cả 2 cây thư mục:
 *   - MobileSafari process: đọc container của chính nó (khi kill sẽ thất bại lock)
 *   - SpringBoard / safecleaner daemon: có quyền ghi /var/jb
 *
 * Vì vậy, **wipe thực sự sẽ chạy trong SpringBoard** (qua lệnh launchctl).
 */

#import "SAFECleanerRoot.h"
#import <UIKit/UIKit.h>
#import <spawn.h>
#import <sys/stat.h>

@interface SAFECleanerEngine : NSObject
+ (BOOL)wipeSafariDataKeepingBackup:(BOOL)keepBackup;
+ (NSString *)safariDataContainerPath;
+ (NSString *)safariBundleContainerPath;
+ (void)restartSafari;
+ (void)killSafariProcesses;
@end

@implementation SAFECleanerEngine

#pragma mark - Path discovery

+ (NSString *)safariDataContainerPath {
    /*
     * Tìm data container của MobileSafari. Rootless chuẩn hóa:
     * /var/mobile/Containers/Data/Application/<UUID>/
     *     Library/
     *         Caches/com.apple.mobilesafari/
     *         Cookies/Cookies.binarycookies
     *         Safari/
     *         Preferences/com.apple.mobilesafari.plist
     *         WebKit/WebsiteData/
     */

    NSString *containersRoot = @"/var/mobile/Containers/Data/Application";
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *err = nil;
    NSArray *items = [fm contentsOfDirectoryAtPath:containersRoot error:&err];
    if (!items) return nil;

    for (NSString *uuid in items) {
        NSString *metaPlist = [containersRoot stringByAppendingPathComponent:
                               [uuid stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"]];
        NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:metaPlist];
        if (meta && [meta[@"MCMMetadataIdentifier"] isEqualToString:@"com.apple.mobilesafari"]) {
            return [containersRoot stringByAppendingPathComponent:uuid];
        }
    }
    return nil;
}

+ (NSString *)safariBundleContainerPath {
    NSString *containersRoot = @"/var/mobile/Containers/Bundle/Application";
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *items = [fm contentsOfDirectoryAtPath:containersRoot error:nil];
    if (!items) return nil;
    for (NSString *uuid in items) {
        NSString *metaPlist = [containersRoot stringByAppendingPathComponent:
                               [uuid stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"]];
        NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:metaPlist];
        if (meta && [meta[@"MCMMetadataIdentifier"] isEqualToString:@"com.apple.mobilesafari"]) {
            return [containersRoot stringByAppendingPathComponent:uuid];
        }
    }
    return nil;
}

#pragma mark - Process control

+ (void)killSafariProcesses {
    /*
     * Kill MobileSafari và SafariViewService. Dùng killall2 (Procursus) hoặc killall.
     * Rootless: killall nằm ở /var/jb/usr/bin/killall2
     */
    NSArray *cmds = @[
        @"/var/jb/usr/bin/killall2", @"-9", @"MobileSafari",
        @"/var/jb/usr/bin/killall2", @"-9", @"SafariViewService",
        @"/var/jb/usr/bin/killall2", @"-9", @"com.apple.WebKit.Networking",
        @"/var/jb/usr/bin/killall2", @"-9", @"com.apple.WebKit.WebContent",
        @"/var/jb/usr/bin/killall2", @"-9", @"com.apple.WebKit.GPU",
    ];

    for (NSUInteger i = 0; i < cmds.count; i += 3) {
        NSString *path = cmds[i];
        NSArray *args = @[cmds[i+1], cmds[i+2]];
        if (![[NSFileManager defaultManager] isExecutableFileAtPath:path]) {
            // Fallback sang /usr/bin/killall nếu không có killall2
            path = @"/usr/bin/killall";
        }
        pid_t pid;
        char **argv = (char **)malloc(sizeof(char *) * (args.count + 2));
        argv[0] = (char *)[path.lastPathComponent UTF8String];
        for (NSUInteger k = 0; k < args.count; k++) {
            argv[k+1] = (char *)[args[k] UTF8String];
        }
        argv[args.count+1] = NULL;
        posix_spawn(&pid, [path UTF8String], NULL, NULL, argv, NULL);
        free(argv);
    }
}

+ (void)restartSafari {
    NSString *safari = @"/var/jb/usr/bin/uicache";
    if (![[NSFileManager defaultManager] isExecutableFileAtPath:safari]) {
        safari = @"/usr/bin/uicache";
    }

    pid_t pid;
    char *argv[] = {
        (char *)[safari.lastPathComponent UTF8String],
        (char *)"-p", (char *)"com.apple.mobilesafari",
        NULL
    };
    posix_spawn(&pid, [safari UTF8String], NULL, NULL, argv, NULL);
}

#pragma mark - File operations

+ (BOOL)safeRemovePath:(NSString *)path {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) return YES;
    NSError *err = nil;
    if ([fm isDeletableFileAtPath:path]) {
        return [fm removeItemAtPath:path error:&err];
    }
    // Dùng rm -rf nếu file system không cho qua Foundation
    pid_t pid;
    char *argv[] = {
        (char *)"/var/jb/usr/bin/rm",
        (char *)"-rf",
        (char *)[path UTF8String],
        NULL
    };
    int status = 0;
    posix_spawn(&pid, "/var/jb/usr/bin/rm", NULL, NULL, argv, NULL);
    waitpid(pid, &status, 0);
    return WIFEXITED(status) && WEXITSTATUS(status) == 0;
}

+ (BOOL)backupPath:(NSString *)src intoDir:(NSString *)backupDir {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *err = nil;
    [fm createDirectoryAtPath:backupDir withIntermediateDirectories:YES attributes:nil error:&err];
    if (![fm fileExistsAtPath:src]) return YES;

    NSString *baseName = src.lastPathComponent;
    NSString *dest = [backupDir stringByAppendingPathComponent:baseName];
    return [fm copyItemAtPath:src toPath:dest error:&err];
}

#pragma mark - Wipe logic

+ (BOOL)wipeSafariDataKeepingBackup:(BOOL)keepBackup {
    NSFileManager *fm = [NSFileManager defaultManager];

    // 0. Tạo backup nếu bật
    NSString *timestamp = [NSString stringWithFormat:@"%.0f",
                           [[NSDate date] timeIntervalSince1970]];
    NSString *backupDir = [kBackupsRoot stringByAppendingPathComponent:
                           [@"backup-" stringByAppendingString:timestamp]];

    BOOL isSpringBoard = [[[NSProcessInfo processInfo] processName] isEqualToString:@"SpringBoard"];

    // ---------- A. Xóa data container của Safari ----------
    NSString *dataRoot = [self safariDataContainerPath];
    if (dataRoot) {
        NSString *lib = [dataRoot stringByAppendingPathComponent:@"Library"];

        NSArray *pathsToWipe = @[
            // Cookies / HSTS
            [lib stringByAppendingPathComponent:@"Cookies"],
            [lib stringByAppendingPathComponent:@"Cookies/Cookies.binarycookies"],
            // WebKit WebsiteData (cookies, IndexedDB, localStorage, sessionStorage, service worker)
            [lib stringByAppendingPathComponent:@"WebKit"],
            [lib stringByAppendingPathComponent:@"WebKit/WebsiteData"],
            // Cache (Safari + WebKit)
            [lib stringByAppendingPathComponent:@"Caches/com.apple.mobilesafari"],
            [lib stringByAppendingPathComponent:@"Caches/com.apple.WebKit"],
            [lib stringByAppendingPathComponent:@"Caches/com.apple.WebKit.Networking"],
            [lib stringByAppendingPathComponent:@"Caches/com.apple.WebKit.WebContent"],
            // Safari's own DBs (history, reading list, recently visited, autofill)
            [lib stringByAppendingPathComponent:@"Safari"],
            [lib stringByAppendingPathComponent:@"Safari/Bookmarks.plist"],
            [lib stringByAppendingPathComponent:@"Safari/History.db"],
            [lib stringByAppendingPathComponent:@"Safari/History.db-wal"],
            [lib stringByAppendingPathComponent:@"Safari/History.db-shm"],
            [lib stringByAppendingPathComponent:@"Safari/ReadingList.db"],
            [lib stringByAppendingPathComponent:@"Safari/ReadingList.db-wal"],
            [lib stringByAppendingPathComponent:@"Safari/ReadingList.db-shm"],
            [lib stringByAppendingPathComponent:@"Safari/RecentSearches.db"],
            [lib stringByAppendingPathComponent:@"Safari/Tabs.db"],
            [lib stringByAppendingPathComponent:@"Safari/Tabs.db-wal"],
            [lib stringByAppendingPathComponent:@"Safari/Tabs.db-shm"],
            [lib stringByAppendingPathComponent:@"Safari/Thumbnails.db"],
            [lib stringByAppendingPathComponent:@"Safari/BrowserState.db"],
            [lib stringByAppendingPathComponent:@"Safari/SuspendTabs.plist"],
            [lib stringByAppendingPathComponent:@"Safari/LastSession.plist"],
            // Preferences (com.apple.mobilesafari + WebKit)
            [lib stringByAppendingPathComponent:@"Preferences/com.apple.mobilesafari.plist"],
            [lib stringByAppendingPathComponent:@"Preferences/com.apple.SafariViewService.plist"],
            [lib stringByAppendingPathComponent:@"Preferences/com.apple.WebKit.plist"],
            [lib stringByAppendingPathComponent:@"Preferences/com.apple.WebKit.Networking.plist"],
            [lib stringByAppendingPathComponent:@"Preferences/com.apple.WebKit.WebContent.plist"],
            [lib stringByAppendingPathComponent:@"Preferences/com.apple.WebKit.GPU.plist"],
        ];

        for (NSString *p in pathsToWipe) {
            if (keepBackup) {
                [self backupPath:p intoDir:backupDir];
            }
            [self safeRemovePath:p];
        }
    }

    // ---------- B. Xóa cfprefsd state cho Safari / WebKit ----------
    // Để xóa sạch preferences, ta xóa thẳng file plist trong
    // /var/mobile/Library/Preferences/ rồi restart cfprefsd.
    NSArray *cfKeyPaths = @[
        @"com.apple.mobilesafari.plist",
        @"com.apple.SafariViewService.plist",
        @"com.apple.WebKit.plist",
        @"com.apple.WebKit.Networking.plist",
        @"com.apple.WebKit.WebContent.plist",
        @"com.apple.WebKit.GPU.plist",
        @"com.apple.Safari.plist",
        @"com.apple.SafariSafeBrowsing.plist",
    ];
    for (NSString *plist in cfKeyPaths) {
        NSString *p = [@"/var/mobile/Library/Preferences/" stringByAppendingString:plist];
        if (keepBackup) {
            [self backupPath:p intoDir:backupDir];
        }
        [self safeRemovePath:p];
    }

    // ---------- C. Reset SSL session cache (qua cfprefsd) ----------
    if (isSpringBoard) {
        // Restart cfprefsd để reload cache
        pid_t pid;
        char *argv[] = {
            (char *)"/var/jb/usr/bin/killall2",
            (char *)"-9",
            (char *)"cfprefsd",
            NULL
        };
        posix_spawn(&pid, "/var/jb/usr/bin/killall2", NULL, NULL, argv, NULL);
    }

    // ---------- D. Dọn rác WebKit GPU / Networking còn sót trong rootless ----------
    NSArray *globalGlobs = @[
        @"/var/mobile/Library/Caches/com.apple.mobilesafari",
        @"/var/mobile/Library/Caches/com.apple.SafariViewService",
        @"/var/mobile/Library/Caches/com.apple.WebKit*",
        @"/var/mobile/Library/WebKit/WebsiteData",
    ];
    for (NSString *g in globalGlobs) {
        [self safeRemovePath:g];
    }

    // ---------- E. Xóa backup nếu không giữ ----------
    if (!keepBackup) {
        [self safeRemovePath:backupDir];
    }

    // Tạo thư mục trống trở lại để Safari không crash lần sau
    if (dataRoot) {
        NSString *lib = [dataRoot stringByAppendingPathComponent:@"Library"];
        [[NSFileManager defaultManager] createDirectoryAtPath:
            [lib stringByAppendingPathComponent:@"Caches/com.apple.mobilesafari"]
            withIntermediateDirectories:YES attributes:nil error:nil];
        [[NSFileManager defaultManager] createDirectoryAtPath:
            [lib stringByAppendingPathComponent:@"WebKit/WebsiteData"]
            withIntermediateDirectories:YES attributes:nil error:nil];
    }

    return YES;
}

@end