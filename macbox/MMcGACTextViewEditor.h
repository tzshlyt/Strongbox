//
//  MMcGACTextViewEditor.h
//  Strongbox
//
//  Created by Mark on 09/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MMcGACTextViewEditor : NSTextView

@property (nonatomic, nullable, copy) void (^onImagePasted)(void);

@end

NS_ASSUME_NONNULL_END
