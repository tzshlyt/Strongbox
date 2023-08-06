//
//  ExportOptionsTableViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 24/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "ExportOptionsTableViewController.h"
#import "Alerts.h"
#import "StrongboxUIDocument.h"
#import <MessageUI/MessageUI.h>
#import "CHCSVParser.h"
#import "Csv.h"
#import "ISMessages.h"
#import "ClipboardManager.h"
#import "Utils.h"
#import "NSDate+Extensions.h"
#import "Serializator.h"
#import "WorkingCopyManager.h"
#import "AppPreferences.h"

@interface Delegate : NSObject <CHCSVParserDelegate, UIActivityItemSource>

@property (readonly) NSArray *lines;

@end

@interface ExportOptionsTableViewController () <UIDocumentPickerDelegate, MFMailComposeViewControllerDelegate, UIAdaptivePresentationControllerDelegate>

@property (weak, nonatomic) IBOutlet UITableViewCell *cellShare;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellFiles;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellEmail;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellEmailCsv;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellCopy;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellHtml;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellXml;

@property NSURL* temporaryExportUrl;
@property (readonly) NSString* exportFileName;

@end

@implementation ExportOptionsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationController.presentationController.delegate = self;

    self.clearsSelectionOnViewWillAppear = NO;
    
    self.tableView.tableFooterView = [UIView new];
    
    [self cell:self.cellFiles setHidden:YES];
    [self cell:self.cellEmail setHidden:YES];
    [self cell:self.cellXml setHidden:YES];
    
    if (self.hidePlaintextOptions) {
        [self cell:self.cellEmailCsv setHidden:YES];
        [self cell:self.cellCopy setHidden:YES];
        [self cell:self.cellHtml setHidden:YES];
        [self cell:self.cellXml setHidden:YES];
    }
    else {
        if (!( self.viewModel.database.originalFormat == kKeePass || self.viewModel.database.originalFormat == kKeePass4 )) {
            [self cell:self.cellXml setHidden:YES];
        }
        
        if (TARGET_OS_SIMULATOR == 0) { 
            [self cell:self.cellXml setHidden:YES];
        }
    }
    
    [self reloadDataAnimated:YES];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.cellShare.imageView.image = [UIImage imageNamed:@"upload"];
    self.cellFiles.imageView.image = [UIImage imageNamed:@"documents"];
    self.cellEmail.imageView.image = [UIImage imageNamed:@"attach"];
    self.cellEmailCsv.imageView.image = [UIImage imageNamed:@"message"];
    self.cellCopy.imageView.image = [UIImage imageNamed:@"copy"];
    self.cellHtml.imageView.image = [UIImage imageNamed:@"document"];
    self.cellXml.imageView.image = [UIImage imageNamed:@"document"];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    if (cell == self.cellShare) {
        [self onShare];
    }






    else if(cell == self.cellEmailCsv) {
        [self exportCsvByEmail];
    }
    else if(cell == self.cellCopy) {
        [self copyCsv];
    }
    else if(cell == self.cellHtml) {
        [self exportHtmlByEmail];
    }



}

- (void)onShare {
    NSURL* localCopyUrl = [WorkingCopyManager.sharedInstance getLocalWorkingCache:self.viewModel.databaseUuid];
    if (!localCopyUrl) {
        [Alerts error:self error:[Utils createNSError:@"Could not get local copy" errorCode:-2145]];
        return;
    }
    
    NSError* err;
    NSData* data = [NSData dataWithContentsOfURL:localCopyUrl options:kNilOptions error:&err];
    if (err) {
        [Alerts error:self error:err];
        return;
    }
    
    [self onShareWithData:data];
}

- (void)onShareWithData:(NSData*)data {
    NSString* filename = AppPreferences.sharedInstance.appendDateToExportFileName ? self.exportFileName : self.viewModel.metadata.fileName;
    
    NSString* f = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
    
    [NSFileManager.defaultManager removeItemAtPath:f error:nil];
    
    NSError* err;
    [data writeToFile:f options:kNilOptions error:&err];
    
    if (err) {
        [Alerts error:self error:err];
        return;
    }
    
    NSURL* url = [NSURL fileURLWithPath:f];
    NSArray *activityItems = @[url]; 
    
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    
    
    
    activityViewController.popoverPresentationController.sourceView = self.view;
    activityViewController.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds),0,0);
    activityViewController.popoverPresentationController.permittedArrowDirections = 0L; 

    __weak ExportOptionsTableViewController* weakSelf = self;

    [activityViewController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        NSError *errorBlock;
        if([[NSFileManager defaultManager] removeItemAtURL:url error:&errorBlock] == NO) {
            NSLog(@"error deleting file %@", errorBlock);
            return;
        }
        
        if ( completed ) {
            [weakSelf informSuccessAndDismiss];
        }
    }];
    
    [self presentViewController:activityViewController animated:YES completion:nil];
}

- (NSString *)activityViewController:(UIActivityViewController *)activityViewController subjectForActivityType:(NSString *)activityType {
    NSString* nickname = self.viewModel.metadata.nickName;
    NSString* subject = [NSString stringWithFormat:NSLocalizedString(@"export_vc_email_subject", @"Strongbox Database: '%@'"), nickname];

    return subject;
}

- (void)copyCsv {
    NSString *newStr = [[NSString alloc] initWithData:[Csv getSafeAsCsv:self.viewModel.database] encoding:NSUTF8StringEncoding];

    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:newStr];
    
    [ISMessages showCardAlertWithTitle:NSLocalizedString(@"export_vc_message_csv_copied", @"Database CSV Copied to Clipboard")
                               message:nil
                              duration:3.f
                           hideOnSwipe:YES
                             hideOnTap:YES
                             alertType:ISAlertTypeSuccess
                         alertPosition:ISAlertPositionTop
                               didHide:nil];

    [self informSuccessAndDismiss];
}




























- (void)exportCsvByEmail {
    NSData *newStr = [Csv getSafeAsCsv:self.viewModel.database];
    NSString* attachmentName = [NSString stringWithFormat:@"%@.csv", self.viewModel.metadata.nickName];
    [self composeEmail:attachmentName mimeType:@"text/csv" data:newStr nickname:self.viewModel.metadata.nickName];
}

- (void)exportHtmlByEmail {
    NSString *html = [self.viewModel.database getHtmlPrintString:self.viewModel.metadata.nickName];
    
    NSString* attachmentName = [NSString stringWithFormat:@"%@.html", self.viewModel.metadata.nickName];
    
    [self composeEmail:attachmentName mimeType:@"text/html" data:[html dataUsingEncoding:NSUTF8StringEncoding] nickname:self.viewModel.metadata.nickName];
}


























- (void)composeEmail:(NSString*)attachmentName mimeType:(NSString*)mimeType data:(NSData*)data nickname:(NSString*)nickname {
    if(![MFMailComposeViewController canSendMail]) {
        [Alerts info:self
               title:NSLocalizedString(@"export_vc_email_unavailable_title", @"Email Not Available")
             message:NSLocalizedString(@"export_vc_email_unavailable_message", @"It looks like email is not setup on this device and so the database cannot be exported by email.")];
        return;
    }
    
    MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
    
    [picker setSubject:[NSString stringWithFormat:NSLocalizedString(@"export_vc_email_subject", @"Strongbox Database: '%@'"), nickname]];
    
    [picker addAttachmentData:data mimeType:mimeType fileName:attachmentName];
    
    [picker setToRecipients:[NSArray array]];
    [picker setMessageBody:[NSString stringWithFormat:NSLocalizedString(@"export_vc_email_message_body_fmt", @"Here's a copy of my '%@' Strongbox Database."), nickname] isHTML:NO];
    picker.mailComposeDelegate = self;
    
    [self presentViewController:picker animated:YES completion:^{ }];
}

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError *)error {
    [self dismissViewControllerAnimated:YES completion:^{
        if(result == MFMailComposeResultFailed || error) {
            [Alerts error:self
                    title:NSLocalizedString(@"export_vc_email_error_sending", @"Error Sending")
                    error:error];
        }
        else if(result == MFMailComposeResultSent) {
            [self informSuccessAndDismiss];
        }
    }];
}

- (void)informSuccessAndDismiss {
    __weak ExportOptionsTableViewController* weakSelf = self;

    [Alerts info:self
           title:NSLocalizedString(@"export_vc_export_successful_title", @"Export Successful")
         message:NSLocalizedString(@"export_vc_export_successful_message", @"Your database was successfully exported.")
      completion:^{
        [weakSelf.presentingViewController dismissViewControllerAnimated:YES completion:^{
            [weakSelf onDismissed:YES];
        }];
    }];
}
















































































- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {
    [self onDismissed:NO];
}

- (IBAction)onDone:(id)sender {
    __weak ExportOptionsTableViewController* weakSelf = self;

    [self.presentingViewController dismissViewControllerAnimated:YES completion:^{
        [weakSelf onDismissed:NO];
    }];
}

- (void)onDismissed:(BOOL)didExport {
    NSLog(@"Dismissing Export: %hhd successful", didExport);
    
    if ( self.onDone ) {
        self.onDone();
    }
}

- (NSString*)exportFileName {
    NSString* extension = self.viewModel.metadata.fileName.pathExtension;
    NSString* withoutExtension = [self.viewModel.metadata.fileName stringByDeletingPathExtension];
    NSString* newFileName = [withoutExtension stringByAppendingFormat:@"-%@", NSDate.date.fileNameCompatibleDateTime];
    
    NSString* ret = [newFileName stringByAppendingPathExtension:extension];
    
    NSLog(@"Export Filename: [%@]", ret);
    
    return  ret;
}

@end
