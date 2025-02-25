//
//  Kdbx4DatabaseTests.m
//  StrongboxTests
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "CommonTesting.h"
#import "Kdbx4Database.h"
#import "KeePassConstants.h"
#import "DatabaseModel.h"

@interface Kdbx4DatabaseTests : XCTestCase

@end

@implementation Kdbx4DatabaseTests

- (void)testInitExistingWithAllKdbxTestFiles {
    for (NSString* file in CommonTesting.testKdbx4FilesAndPasswords) {
        NSLog(@"=============================================================================================================");
        NSLog(@"===================================== %@ ===============================================", file);
        
        NSData *blob = [CommonTesting getDataFromBundleFile:file ofType:@"kdbx"];
        
        NSError* error;
        NSString* password = [CommonTesting.testKdbx4FilesAndPasswords objectForKey:file];
        
        //Kdbx4Database *db = [[Kdbx4Database alloc] initExistingWithDataAndPassword:blob password:password error:&error];
        StrongboxDatabase* db = [[[Kdbx4Database alloc] init] open:blob compositeKeyFactors:[CompositeKeyFactors password:password] error:&error];
        
        XCTAssertNotNil(db);
        
        NSLog(@"%@", db);
        NSLog(@"=============================================================================================================");
    }
}

- (void)testInitExistingWithLargeAGoogleDriveSafeUncompressed {
    NSData *safeData = [[NSFileManager defaultManager] contentsAtPath:@"/Users/mark/Google Drive/strongbox/keepass/Database-Large-Uncompressed.kdbx"];
    
    NSError* error;
    //Kdbx4Database *db = [[Kdbx4Database alloc] initExistingWithDataAndPassword:safeData password:@"a" error:&error];
    StrongboxDatabase* db = [[[Kdbx4Database alloc] init] open:safeData compositeKeyFactors:[CompositeKeyFactors password:@"a"] error:&error];
    NSLog(@"%@", db);
    
    XCTAssertNotNil(db);
}

- (void)testInitExistingWithLargeGoogleDriveSafe {
    NSData *safeData = [[NSFileManager defaultManager] contentsAtPath:@"/Users/mark/Google Drive/strongbox/keepass/Database-Large.kdbx"];
    
    NSError* error;
    //Kdbx4Database *db = [[Kdbx4Database alloc] initExistingWithDataAndPassword:safeData password:@"a" error:&error];
    StrongboxDatabase* db = [[[Kdbx4Database alloc] init] open:safeData compositeKeyFactors:[CompositeKeyFactors password:@"a"] error:&error];
    NSLog(@"%@ - [%@]", db, error);
    
    XCTAssertNotNil(db);
}

- (void)testEmptyDbGetAsDataAndReOpenSafeIsTheSame {
    id<AbstractDatabaseFormatAdaptor> adaptor = [[Kdbx4Database alloc] init];
    StrongboxDatabase* db = [adaptor create:[CompositeKeyFactors password:@"password"]];
    
    NSLog(@"%@", db);
    
    XCTAssert([[db.rootGroup.childGroups objectAtIndex:0].title isEqualToString:kDefaultRootGroupName]);
    
    KeePass4DatabaseMetadata* metadata = db.metadata;
    XCTAssert([metadata.generator isEqualToString:@"Strongbox"]);
    XCTAssert(metadata.compressionFlags == kGzipCompressionFlag);
    
    NSError* error;
    NSData* data = [adaptor save:db error:&error];
    
    if(error) {
        NSLog(@"%@", error);
    }
    
    XCTAssertNil(error);
    XCTAssertNotNil(data);
    
    StrongboxDatabase *b = [adaptor open:data compositeKeyFactors:[CompositeKeyFactors password:@"password"] error:&error];
    
    if(error) {
        NSLog(@"%@", error);
    }
    
    XCTAssertNotNil(b);
    
    NSLog(@"%@", b);
    
    metadata = b.metadata;
    XCTAssert([[b.rootGroup.childGroups objectAtIndex:0].title isEqualToString:kDefaultRootGroupName]);
    XCTAssert([metadata.generator isEqualToString:@"Strongbox"]);
    XCTAssert(metadata.compressionFlags == kGzipCompressionFlag);
}

- (void)testSmallNewDbWithPasswordGetAsDataAndReOpenSafeIsTheSame {
    id<AbstractDatabaseFormatAdaptor> adaptor = [[Kdbx4Database alloc] init];

    StrongboxDatabase* db = [adaptor create:[CompositeKeyFactors password:@"password"]];

    KeePass4DatabaseMetadata* metadata = db.metadata;
    XCTAssert([[db.rootGroup.childGroups objectAtIndex:0].title isEqualToString:kDefaultRootGroupName]);
    XCTAssert([metadata.generator isEqualToString:@"Strongbox"]);
    XCTAssert(metadata.compressionFlags == kGzipCompressionFlag);
    
    Node* keePassRoot = [db.rootGroup.childGroups objectAtIndex:0];
    NSData* data1 = [@"This is attachment 1 UTF data" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *data2 = [@"This is attachment 2 UTF data" dataUsingEncoding:NSUTF8StringEncoding];
    
    //

    NodeFields *fields = [[NodeFields alloc] initWithUsername:@"username" url:@"url" password:@"ladder" notes:@"notes" email:@"email"];
    
    Node* record = [[Node alloc] initAsRecord:@"Title" parent:keePassRoot fields:fields uuid:nil];
    [keePassRoot addChild:record allowDuplicateGroupTitles:YES];
    
    [db addNodeAttachment:record attachment:[[UiAttachment alloc] initWithFilename:@"attachment1.txt" data:data1]];
    [db addNodeAttachment:record attachment:[[UiAttachment alloc] initWithFilename:@"attachment2.txt" data:data2]];
    
    //NSLog(@"BEFORE: %@", db);
    
    NSError* error;
    NSData* data = [adaptor save:db error:&error];
    
    if(error) {
        NSLog(@"%@", error);
    }
    
    XCTAssertNil(error);
    XCTAssertNotNil(data);
    
    // Kdbx4Database *b = [[Kdbx4Database alloc] initExistingWithDataAndPassword:data password:@"password" error:&error];
    StrongboxDatabase* b = [adaptor open:data compositeKeyFactors:[CompositeKeyFactors password:@"password"] error:&error];
    if(error) {
        NSLog(@"%@", error);
    }
    
    XCTAssertNotNil(b);
    
    //NSLog(@"AFTER: %@", b);
    
    metadata = b.metadata;
    XCTAssert([[b.rootGroup.childGroups objectAtIndex:0].title isEqualToString:kDefaultRootGroupName]);
    XCTAssert([metadata.generator isEqualToString:@"Strongbox"]);
    XCTAssert(metadata.compressionFlags == kGzipCompressionFlag);

    Node* bKeePassRoot = b.rootGroup.childGroups[0];
    Node* bRecord = bKeePassRoot.childRecords[0];

    XCTAssert([bRecord.title isEqualToString:@"Title"]);
    XCTAssert(bRecord.fields.email.length == 0); // Email is ditched by KeePass
    
    XCTAssert([bRecord.fields.username isEqualToString:@"username"]);
    XCTAssert([bRecord.fields.url isEqualToString:@"url"]);
    XCTAssert([bRecord.fields.notes isEqualToString:@"notes"]);
    XCTAssert([bRecord.fields.password isEqualToString:@"ladder"]);
    
    XCTAssert(bRecord.fields.attachments.count == 2);

    XCTAssert([bRecord.fields.attachments[0].filename isEqualToString:@"attachment1.txt"]);
    XCTAssert([bRecord.fields.attachments[1].filename isEqualToString:@"attachment2.txt"]);
    XCTAssert(bRecord.fields.attachments[0].index == 0);
    XCTAssert(bRecord.fields.attachments[1].index == 1);

    XCTAssert(b.attachments.count == 2);

    XCTAssert([b.attachments[0].data isEqualToData:data1]);
    XCTAssert([b.attachments[1].data isEqualToData:data2]);
}
//
//- (void)testDesktopFile {
//    NSData *safeData = [[NSFileManager defaultManager] contentsAtPath:@"/Users/mark/Desktop/keepass4.kdbx"];
//
//    NSError* error;
//    Kdbx4Database * db = [[Kdbx4Database alloc] initExistingWithDataAndPassword:safeData password:@"a" error:&error];
//
//    NSLog(@"%@", db);
//}

- (void)testKdbx4AesArgon2NonDefaultKdf {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"Database-Aes-Argon2NonDefault" ofType:@"kdbx"];
    
    NSError* error;
    id<AbstractDatabaseFormatAdaptor> adaptor = [[Kdbx4Database alloc] init];
    StrongboxDatabase *db = [adaptor open:blob compositeKeyFactors:[CompositeKeyFactors password:@"a"] error:&error];
    
    XCTAssertNotNil(db);
    
    NSLog(@"%@", db);
    
    Node* testNode = db.rootGroup.childGroups[0].childRecords[0];
    XCTAssert(testNode);
    XCTAssert([testNode.title isEqualToString:@"Sample Entry"]);
    XCTAssert([testNode.fields.username isEqualToString:@"User Name"]);
    XCTAssert([testNode.fields.password isEqualToString:@"Password"]);
}

- (void)disabledTestKdbx4AesArgon2NonDefaultKdfReadAndWrite {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"Database-Aes-Argon2NonDefault" ofType:@"kdbx"];
    
    NSError* error;
    id<AbstractDatabaseFormatAdaptor> adaptor = [[Kdbx4Database alloc] init];
    StrongboxDatabase *db = [adaptor open:blob compositeKeyFactors:[CompositeKeyFactors password:@"a"] error:&error]; //:blob password:@"a" error:&error];
    
    XCTAssertNotNil(db);
    
    NSLog(@"BEFORE: %@", db);

    NSData* data = [adaptor save:db error:&error];// [db getAsData:&error];

    XCTAssert(data);
    
    StrongboxDatabase *db2 = [adaptor open:data compositeKeyFactors:[CompositeKeyFactors password:@"a"] error:&error];

    NSLog(@"AFTER: %@", db2);

    Node* testNode = db2.rootGroup.childGroups[0].childRecords[0];
    XCTAssert(testNode);
    XCTAssert([testNode.title isEqualToString:@"Sample Entry"]);
    XCTAssert([testNode.fields.username isEqualToString:@"User Name"]);
    XCTAssert([testNode.fields.password isEqualToString:@"Password"]);
}

- (void)testCustomIcon {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"custom-icon-4" ofType:@"kdbx"];
    
    NSError* error;
    id<AbstractDatabaseFormatAdaptor> adaptor = [[Kdbx4Database alloc] init];
    StrongboxDatabase *db = [adaptor open:blob compositeKeyFactors:[CompositeKeyFactors password:@"a"] error:&error];
    
    XCTAssertNotNil(db);
    
    NSLog(@"%@", db);
    
    Node* testNode = db.rootGroup.childGroups[0].childRecords[0];
    XCTAssert(testNode);
    XCTAssert([testNode.title isEqualToString:@"Sample Entry"]);
    XCTAssert([testNode.fields.username isEqualToString:@"User Name"]);
    XCTAssert([testNode.fields.password isEqualToString:@"Password"]);

    NSLog(@"%@", testNode.iconId);
    XCTAssert(testNode.iconId.intValue == 0);
    XCTAssert([testNode.customIconUuid.UUIDString isEqualToString:@"E394AE90-219E-C547-8174-976DE6037476"]);
}

- (void)testCustomIconRecreation {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"custom-icon-4" ofType:@"kdbx"];
    
    NSError* error;
    id<AbstractDatabaseFormatAdaptor> adaptor = [[Kdbx4Database alloc] init];
    StrongboxDatabase *b = [adaptor open:blob compositeKeyFactors:[CompositeKeyFactors password:@"a"] error:&error];
    
    XCTAssertNotNil(b);
    
    NSLog(@"BEFORE: %@", b);
    
    NSData* recData = [adaptor save:b error:&error]; // [b getAsData:&error];
    StrongboxDatabase *db = [adaptor open:recData compositeKeyFactors:[CompositeKeyFactors password:@"a"] error:&error];
    
    Node* testNode = db.rootGroup.childGroups[0].childRecords[0];
    XCTAssert(testNode);
    XCTAssert([testNode.title isEqualToString:@"Sample Entry"]);
    XCTAssert([testNode.fields.username isEqualToString:@"User Name"]);
    XCTAssert([testNode.fields.password isEqualToString:@"Password"]);
    
    NSLog(@"%@", testNode.iconId);
    XCTAssert(testNode.iconId.intValue == 0);
    XCTAssert([testNode.customIconUuid.UUIDString isEqualToString:@"E394AE90-219E-C547-8174-976DE6037476"]);
}

- (void)testKdbx4NoCompression {
    NSData *blob = [CommonTesting getDataFromBundleFile:@"db-4-nocompression" ofType:@"kdbx"];
    
    NSError* error;
    id<AbstractDatabaseFormatAdaptor> adaptor = [[Kdbx4Database alloc] init];
    StrongboxDatabase *db = [adaptor open:blob compositeKeyFactors:[CompositeKeyFactors password:@"a"] error:&error];
    
    XCTAssertNotNil(db);
    
    NSLog(@"%@", db);
    
    Node* testNode = db.rootGroup.childGroups[0].childRecords[0];
    XCTAssert(testNode);
    XCTAssert([testNode.title isEqualToString:@"Sample Entry"]);
    XCTAssert([testNode.fields.username isEqualToString:@"User Name"]);
    XCTAssert([testNode.fields.password isEqualToString:@"Password"]);
}

@end
