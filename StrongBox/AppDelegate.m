//
//  AppDelegate.m
//  StrongBox
//
//  Created by Mark McGuill on 03/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "AppDelegate.h"
#import "RecordView.h"
#import "BrowseSafeView.h"
#import "PasswordHistoryViewController.h"
#import "PreviousPasswordsTableViewController.h"
#import "ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h"
#import "GoogleDriveManager.h"
#import "Settings.h"
#import "SafesViewController.h"
#import "SafesViewController.h"
#import "OfflineDetector.h"
#import "real-secrets.h"
#import "NSArray+Extensions.h"
#import "OfflineCacheNameDetector.h"
#import "ProUpgradeIAPManager.h"
#import "FileManager.h"
#import "LocalDeviceStorageProvider.h"

@interface AppDelegate ()

@property NSDate* appLaunchTime;

@property dispatch_block_t clearClipboardTask;
@property UIBackgroundTaskIdentifier clearClipboardAppBackgroundTask;
@property NSObject* clipboardNotificationIdentifier;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self initializeDropbox];

    [self initializeInstallSettingsAndLaunchCount];   
    
    [self performMigrations];
    
    // Do not backup local safes, caches or key files

    [FileManager.sharedInstance excludeDirectoriesFromBackup];
    
    [self cleanupInbox:launchOptions];
    
    [self observeClipboardChangeNotifications];
    
    [ProUpgradeIAPManager.sharedInstance initialize]; // Be ready for any In-App Purchase messages
    
    [LocalDeviceStorageProvider.sharedInstance startMonitoringDocumentsDirectory]; // Watch for iTunes File Sharing or other local documents
    
    //    NSLog(@"Documents Directory: [%@]", FileManager.sharedInstance.documentsDirectory);
    //    NSLog(@"Shared App Group Directory: [%@]", FileManager.sharedInstance.sharedAppGroupDirectory);

    return YES;
}

- (void)performMigrations {
    // 17-Jun-2019
    if(!Settings.sharedInstance.migratedLocalDatabasesToNewSystem) {
        [LocalDeviceStorageProvider.sharedInstance migrateLocalDatabasesToNewSystem];
    }
    
    // 2-Jul-2019
    if(!Settings.sharedInstance.migratedToNewPasswordGenerator) {
        [self migrateToNewPasswordGenerator];
    }
    
    // 29-Jul-2019
    
    if(!Settings.sharedInstance.migratedToNewQuickLaunchSystem) {
        [self migrateToNewQuickLaunchSystem];
    }
}

- (void)migrateToNewQuickLaunchSystem {
    NSLog(@"Migrating to new migrateToNewQuickLaunchSystem...");
    
    if(Settings.sharedInstance.useQuickLaunchAsRootView && SafesList.sharedInstance.snapshot.count) {
        SafeMetaData* first = SafesList.sharedInstance.snapshot.firstObject;
        NSString* quickLaunchUuid = first.uuid;
        Settings.sharedInstance.quickLaunchUuid = quickLaunchUuid;
        NSLog(@"Setting [%@] to configured quick launch database", first.nickName);
    }
    
    Settings.sharedInstance.migratedToNewQuickLaunchSystem = YES;
}

- (void)migrateToNewPasswordGenerator {
    NSLog(@"Migrating to new Password Generation System...");
    
    PasswordGenerationConfig* newConfig = Settings.sharedInstance.passwordGenerationConfig;
    PasswordGenerationParameters* oldConfig = Settings.sharedInstance.passwordGenerationParameters;
    
    newConfig.algorithm = oldConfig.algorithm == kBasic ? kPasswordGenerationAlgorithmBasic : kPasswordGenerationAlgorithmDiceware;

    newConfig.basicLength = oldConfig.maximumLength;
    
    NSMutableArray<NSNumber*>* characterGroups = @[].mutableCopy;
    if(oldConfig.useLower) {
        [characterGroups addObject:@(kPasswordGenerationCharacterPoolLower)];
    }
    if(oldConfig.useUpper) {
        [characterGroups addObject:@(kPasswordGenerationCharacterPoolUpper)];
    }
    if(oldConfig.useDigits) {
        [characterGroups addObject:@(kPasswordGenerationCharacterPoolNumeric)];
    }
    if(oldConfig.useSymbols) {
        [characterGroups addObject:@(kPasswordGenerationCharacterPoolSymbols)];
    }
    
    newConfig.useCharacterGroups = characterGroups.copy;
    newConfig.easyReadCharactersOnly = oldConfig.easyReadOnly;
    newConfig.nonAmbiguousOnly = YES;
    newConfig.pickFromEveryGroup = NO;
    
    newConfig.wordCount = oldConfig.xkcdWordCount;
    newConfig.wordSeparator = oldConfig.wordSeparator;
    newConfig.hackerify = NO;
    
    Settings.sharedInstance.passwordGenerationConfig = newConfig;
    Settings.sharedInstance.migratedToNewPasswordGenerator = YES;
}

- (void)cleanupInbox:(NSDictionary *)launchOptions {
    if(!launchOptions || launchOptions[UIApplicationLaunchOptionsURLKey] == nil) {
        // Inbox should be empty whenever possible so that we can detect the
        // re-importation of a certain file and ask if user wants to create a
        // new copy or just update an old one...
        [FileManager.sharedInstance deleteAllInboxItems];
    }
}

- (void)initializeInstallSettingsAndLaunchCount {
    [[Settings sharedInstance] incrementLaunchCount];
    
    if(Settings.sharedInstance.installDate == nil) {
        Settings.sharedInstance.installDate = [NSDate date];
    }
    
    if([Settings.sharedInstance getEndFreeTrialDate] == nil) {
        NSCalendar *cal = [NSCalendar currentCalendar];
        NSDate *date = [cal dateByAddingUnit:NSCalendarUnitMonth value:3 toDate:[NSDate date] options:0];
        [Settings.sharedInstance setEndFreeTrialDate:date];
    }
    
    self.appLaunchTime = [NSDate date];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    //NSLog(@"openURL: [%@] => [%@]", options, url);
    
    if ([url.absoluteString hasPrefix:@"db"]) {
        DBOAuthResult *authResult = [DBClientsManager handleRedirectURL:url];

        if (authResult != nil) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"isDropboxLinked" object:authResult];
        }

        return YES;
    }
    else if ([url.absoluteString hasPrefix:@"com.googleusercontent.apps"])
    {
        return [[GIDSignIn sharedInstance] handleURL:url
                                   sourceApplication:options[UIApplicationOpenURLOptionsSourceApplicationKey]
                                          annotation:options[UIApplicationOpenURLOptionsAnnotationKey]];
    }
    else {
        SafesViewController *safesViewController = [self getInitialViewController];

        NSNumber* num = [options objectForKey:UIApplicationOpenURLOptionsOpenInPlaceKey];

        [safesViewController enqueueImport:url canOpenInPlace:num ? num.boolValue : NO];

        return YES;
    }

    return NO;
}

- (SafesViewController *)getInitialViewController {
    UINavigationController* nav = (UINavigationController*)self.window.rootViewController;
    SafesViewController *ivc = (SafesViewController*)nav.viewControllers.firstObject;
    return ivc;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    [OfflineDetector.sharedInstance stopMonitoringConnectivitity];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [OfflineDetector.sharedInstance startMonitoringConnectivitity];    
    [self performedScheduledEntitlementsCheck];
}

- (void)performedScheduledEntitlementsCheck {
    NSTimeInterval timeDifference = [NSDate.date timeIntervalSinceDate:self.appLaunchTime];
    double minutes = timeDifference / 60;
    double hoursSinceLaunch = minutes / 60;

    if(hoursSinceLaunch > 2) { // Stuff we'd like to do, but definitely not immediately on first launch...
        // Do not request review immediately on launch but after a while and after user has used app for a bit
        NSInteger launchCount = [[Settings sharedInstance] getLaunchCount];

        if (launchCount > 30) { // Don't bother any new / recent users - no need for entitlements check until user is regular user
            if (@available( iOS 10.3,*)) {
                [SKStoreReviewController requestReview];
            }

            [ProUpgradeIAPManager.sharedInstance performScheduledProEntitlementsCheckIfAppropriate:self.window.rootViewController];
        }
    }
}

- (void)initializeDropbox {
    [DBClientsManager setupWithAppKey:DROPBOX_APP_KEY];
}

- (void)onClipboardChangedNotification:(NSNotification*)note {
    NSLog(@"onClipboardChangedNotification: [%@]", note);
    
    if(![UIPasteboard.generalPasteboard hasStrings] &&
       ![UIPasteboard.generalPasteboard hasImages] &&
       ![UIPasteboard.generalPasteboard hasURLs]) {
        return;
    }

    UIApplication* app = [UIApplication sharedApplication];
    if(self.clearClipboardTask) {
        NSLog(@"Clearing existing clear clipboard tasks");
        dispatch_block_cancel(self.clearClipboardTask);
        self.clearClipboardTask = nil;
        if(self.clearClipboardAppBackgroundTask != UIBackgroundTaskInvalid) {
            [app endBackgroundTask:self.clearClipboardAppBackgroundTask];
            self.clearClipboardAppBackgroundTask = UIBackgroundTaskInvalid;
        }
    }

    self.clearClipboardAppBackgroundTask = [app beginBackgroundTaskWithExpirationHandler:^{
        [app endBackgroundTask:self.clearClipboardAppBackgroundTask];
        self.clearClipboardAppBackgroundTask = UIBackgroundTaskInvalid;
    }];
    
    NSLog(@"Creating New Clear Clipboard Background Task... with timeout = [%ld]", (long)Settings.sharedInstance.clearClipboardAfterSeconds);

    NSInteger clipboardChangeCount = UIPasteboard.generalPasteboard.changeCount;
    self.clearClipboardTask = dispatch_block_create(0, ^{
        [self clearClipboardDelayedTask:clipboardChangeCount];
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(Settings.sharedInstance.clearClipboardAfterSeconds * NSEC_PER_SEC)),
                    dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), self.clearClipboardTask);
}

- (void)clearClipboardDelayedTask:(NSInteger)clipboardChangeCount {
    if(!Settings.sharedInstance.clearClipboardEnabled) {
        [self unobserveClipboardChangeNotifications];
        return; // In case a setting change has be made
    }
    
    if(clipboardChangeCount == UIPasteboard.generalPasteboard.changeCount) {
        NSLog(@"Clearing Clipboard...");
        
        [self unobserveClipboardChangeNotifications];
        
        [UIPasteboard.generalPasteboard setStrings:@[]];
        [UIPasteboard.generalPasteboard setImages:@[]];
        [UIPasteboard.generalPasteboard setURLs:@[]];
        
        [self observeClipboardChangeNotifications];
    }
    else {
        NSLog(@"Not clearing clipboard as change count does not match.");
    }
    
    UIApplication* app = [UIApplication sharedApplication];
    [app endBackgroundTask:self.clearClipboardAppBackgroundTask];
    self.clearClipboardAppBackgroundTask = UIBackgroundTaskInvalid;
    self.clearClipboardTask = nil;
}

- (void)observeClipboardChangeNotifications {
    if(Settings.sharedInstance.clearClipboardEnabled) {
        if(!self.clipboardNotificationIdentifier) {
            // Delay by a small bit because we're definitely getting an odd crash or two somehow due to infinite loop now
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.clipboardNotificationIdentifier =
                [NSNotificationCenter.defaultCenter addObserverForName:UIPasteboardChangedNotification
                                                                object:nil
                                                                 queue:nil
                                                            usingBlock:^(NSNotification * _Nonnull note) {
                                                                [self onClipboardChangedNotification:note];
                                                            }];
            });
        }
    }
}

- (void)unobserveClipboardChangeNotifications {
    if(self.clipboardNotificationIdentifier) {
        [NSNotificationCenter.defaultCenter removeObserver:self.clipboardNotificationIdentifier];
        self.clipboardNotificationIdentifier = nil;
    }
}

@end
