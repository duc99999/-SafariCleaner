#import <Preferences/Preferences.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>

@interface SAFECleanerRootListController : PSListController
@end

@interface UIAlertController (Private)
+ (UIAlertController *)alertControllerWithTitle:(NSString *)title
                                        message:(NSString *)message
                                 preferredStyle:(UIAlertControllerStyle)style;
@end

@implementation SAFECleanerRootListController

- (id)specifiers {
    if (_specifiers == nil) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Safari Cleaner";
}

#pragma mark - Action: Wipe

- (void)wipeSafari:(id)sender {
    BOOL keepBackup = [[self readPreferenceValue:@"keepBackup"] boolValue];

    UIAlertController *confirm =
    [UIAlertController alertControllerWithTitle:@"Wipe Safari Now?"
                                        message:keepBackup
                                            ? @"A backup will be saved to /var/mobile/Documents/SafariCleaner/ before wiping."
                                            : @"This will PERMANENTLY erase all Safari data. Make sure you are logged out of important accounts."
                                 preferredStyle:UIAlertControllerStyleAlert];

    [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                               style:UIAlertActionStyleCancel
                                             handler:nil]];

    __weak typeof(self) weakSelf = self;
    [confirm addAction:[UIAlertAction actionWithTitle:@"Wipe"
                                               style:UIAlertActionStyleDestructive
                                             handler:^(UIAlertAction * _Nonnull action) {
        [weakSelf performWipeKeepingBackup:keepBackup];
    }]];

    [self presentViewController:confirm animated:YES completion:nil];
}

- (void)performWipeKeepingBackup:(BOOL)keepBackup {
    // Darwin notify không truyền được userInfo, nên mình gọi qua symbol exported
    // của tweak chính để set cờ keepBackup, rồi post notification.
    void (*setKeepBackupFn)(int) = dlsym(RTLD_DEFAULT, "SafariCleaner_SetKeepBackup");
    if (setKeepBackupFn) {
        setKeepBackupFn(keepBackup ? 1 : 0);
    }

    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.duc.safecleaner/doWipe"),
        NULL, NULL, TRUE);

    [self showSpinner:@"Wiping Safari..."];
}

- (void)showSpinner:(NSString *)message {
    UIAlertController *wait =
    [UIAlertController alertControllerWithTitle:message
                                        message:@"Quitting Safari and clearing data. Do not open Safari."
                                 preferredStyle:UIAlertControllerStyleAlert];

    UIActivityIndicatorView *spin =
    [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:
        UIActivityIndicatorViewStyleMedium];
    spin.translatesAutoresizingMaskIntoConstraints = NO;
    [spin startAnimating];

    [wait.view addSubview:spin];
    [NSLayoutConstraint activateConstraints:@[
        [spin.centerXAnchor constraintEqualToAnchor:wait.view.centerXAnchor],
        [spin.bottomAnchor constraintEqualToAnchor:wait.view.bottomAnchor constant:-20],
    ]];

    [self presentViewController:wait animated:YES completion:nil];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
        [wait dismissViewControllerAnimated:YES completion:nil];
    });
}

#pragma mark - Open backups folder

- (void)openBackupsFolder:(id)sender {
    NSURL *url = [NSURL fileURLWithPath:@"/var/mobile/Documents/SafariCleaner"];
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    } else {
        UIAlertController *info =
        [UIAlertController alertControllerWithTitle:@"Backups"
                                            message:@"Backups are stored at /var/mobile/Documents/SafariCleaner/. Use Filza to access."
                                     preferredStyle:UIAlertControllerStyleAlert];
        [info addAction:[UIAlertAction actionWithTitle:@"OK"
                                                 style:UIAlertActionStyleDefault
                                               handler:nil]];
        [self presentViewController:info animated:YES completion:nil];
    }
}

@end