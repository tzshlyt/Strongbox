//
//  QuickLaunchOnboardingViewController.h
//  Strongbox
//
//  Created by Strongbox on 17/05/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OnboardingModule.h"

NS_ASSUME_NONNULL_BEGIN

@interface QuickLaunchOnboardingViewController : UIViewController

@property OnboardingModuleDoneBlock onDone;
@property Model* model;

@end

NS_ASSUME_NONNULL_END
