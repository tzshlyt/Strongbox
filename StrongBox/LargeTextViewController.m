//
//  LargeTextViewController.m
//  Strongbox
//
//  Created by Mark on 23/10/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "LargeTextViewController.h"
#import "FontManager.h"
#import "ColoredStringHelper.h"
#import "AppPreferences.h"
#import "Utils.h"
#import "ClipboardManager.h"

#ifndef IS_APP_EXTENSION

#import "ISMessages/ISMessages.h"

#endif

@interface LargeTextViewController ()

@property (weak, nonatomic) IBOutlet UILabel *labelLargeText;
@property (weak, nonatomic) IBOutlet UIImageView *qrCodeImageView;

@property (weak, nonatomic) IBOutlet UILabel *labelSubtext;
@property (weak, nonatomic) IBOutlet UILabel *labelLargeTextCaption;

@end

@implementation LargeTextViewController

+ (instancetype)fromStoryboard {
    UIStoryboard* sb = [UIStoryboard storyboardWithName:@"LargeTextView" bundle:nil];
    return [sb instantiateInitialViewController];
}

- (void)viewDidLoad {
    [super viewDidLoad];


    

       
    self.qrCodeImageView.hidden = YES;
    
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(labelTapped)];
    tapGestureRecognizer.numberOfTapsRequired = 1;
    [self.labelLargeText addGestureRecognizer:tapGestureRecognizer];
    self.labelLargeText.userInteractionEnabled = YES;

    UITapGestureRecognizer *tapGestureRecognizerSubtext = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(subtextTapped)];
    tapGestureRecognizerSubtext.numberOfTapsRequired = 1;
    [self.labelSubtext addGestureRecognizer:tapGestureRecognizerSubtext];
    self.labelSubtext.userInteractionEnabled = YES;

    if (!self.colorize) {
        self.labelLargeText.font = FontManager.sharedInstance.easyReadFontForTotp;
        self.labelLargeText.text = self.string;
    }
    else {
        BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
        BOOL colorBlind = AppPreferences.sharedInstance.colorizeUseColorBlindPalette;
    
        self.labelLargeText.attributedText = [ColoredStringHelper getColorizedAttributedString:self.string
                                                                                      colorize:YES
                                                                                      darkMode:dark
                                                                                    colorBlind:colorBlind font:FontManager.sharedInstance.easyReadFontForTotp];
    }
    
    self.labelSubtext.text = self.subtext;
    self.labelSubtext.hidden = self.subtext.length == 0;
    self.labelLargeTextCaption.hidden = self.subtext.length == 0;
    self.labelLargeTextCaption.text = NSLocalizedString(@"generic_totp_secret", @"TOTP Secret");
    
    __weak LargeTextViewController* weakSelf = self;
    
    CGFloat width = self.qrCodeImageView.frame.size.width;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [weakSelf loadQrCode:width];
    });
}

- (void)loadQrCode:(CGFloat)width {
    UIImage* img = [Utils getQrCode:self.string
                          pointSize:width];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.qrCodeImageView.image = img;
        
        self.qrCodeImageView.hidden = NO;
    });
}

- (IBAction)onDismiss:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)labelTapped {
    [self copyToClipboard:self.labelLargeText.text];
}
    
- (void)subtextTapped {
    [self copyToClipboard:self.labelSubtext.text];
}












- (void)copyToClipboard:(NSString *)value {
    if (value.length == 0) {
        return;
    }
    
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:value];
    
#ifndef IS_APP_EXTENSION
    [ISMessages showCardAlertWithTitle:NSLocalizedString(@"generic_copied", @"Copied")
                               message:nil
                              duration:3.f
                           hideOnSwipe:YES
                             hideOnTap:YES
                             alertType:ISAlertTypeSuccess
                         alertPosition:ISAlertPositionTop
                               didHide:nil];
#endif
}

@end
