//
//  SetCredentialsTableViewController.h
//  Strongbox-iOS
//
//  Created by Mark on 31/05/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AbstractDatabaseFormatAdaptor.h"
#import "StaticDataTableViewController.h"
#import "CASGParams.h"

typedef NS_ENUM (unsigned int, CASGMode) {
    kCASGModeCreate,
    kCASGModeCreateExpress,
    kCASGModeAddExisting,
    kCASGModeSetCredentials,
    kCASGModeGetCredentials,
    kCASGModeRenameDatabase,
};

NS_ASSUME_NONNULL_BEGIN

@interface CASGTableViewController : StaticDataTableViewController

+ (NSString*)getSuggestedDatabaseName;

@property CASGMode mode;
@property DatabaseFormat initialFormat;
@property NSURL* initialKeyFileUrl;
@property NSDate* offlineCacheDate;
@property BOOL initialOfflineCache;
@property BOOL initialReadOnly;

@property BOOL autoDetectedKeyFileUrl;
@property NSString* initialName;

@property (nonatomic, copy) void (^onDone)(BOOL success, CASGParams * _Nullable creds);

@end

NS_ASSUME_NONNULL_END
