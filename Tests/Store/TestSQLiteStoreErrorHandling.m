#import "TestCommon.h"
#import "COItem.h"
#import "COSQLiteStore+Attachments.h"

#define READONLY_SEARCHABLE_DIRECTORY_ATTRIBUTES D([NSNumber numberWithShort: 0555], NSFilePosixPermissions)
#define REABLE_WRITABLE_SEARCHABLE_DIRECTORY_ATTRIBUTES D([NSNumber numberWithShort: 0777], NSFilePosixPermissions)

@interface TestSQLiteStoreErrorHandling : NSObject <UKTest>
{
}
@end

@implementation TestSQLiteStoreErrorHandling

static ETUUID *rootUUID;
+ (void) initialize
{
    if (self == [TestSQLiteStoreErrorHandling class])
    {
        rootUUID = [[ETUUID alloc] init];
    }
}

- (COItemGraph *) makeInitialItemGraph
{
    return [COItemGraph itemGraphWithItemsRootFirst: A([[COMutableItem alloc] initWithUUID: rootUUID])];
}

- (COItemGraph *) makeChangedItemGraph
{
    COMutableItem *item = [[COMutableItem alloc] initWithUUID: rootUUID];
    [item setValue: @"hello" forAttribute: @"name" type: kCOTypeString];
    return [COItemGraph itemGraphWithItemsRootFirst: A(item)];
}


- (NSString *) tempPathWithName: (NSString *)aName
{
    return [NSTemporaryDirectory() stringByAppendingPathComponent:
                [NSString stringWithFormat: @"%@-%@", aName, [ETUUID UUID]]];
}

- (void) testCreateStoreInReadonlyDirectory
{
    NSString *dir = [self tempPathWithName: @"coreobject-readonly"];
    
    @autoreleasepool {
        assert([[NSFileManager defaultManager] createDirectoryAtPath: dir
                                         withIntermediateDirectories: NO
                                                          attributes: READONLY_SEARCHABLE_DIRECTORY_ATTRIBUTES
                                                               error: NULL]);
        
        UKNil([[COSQLiteStore alloc] initWithURL: [NSURL fileURLWithPath: dir
                                                              isDirectory: YES]]);
        
        UKNil([[COSQLiteStore alloc] initWithURL: [NSURL fileURLWithPath: [dir stringByAppendingPathComponent: @"test.coreobject"]
                                                              isDirectory: YES]]);
    }

    assert([[NSFileManager defaultManager] removeItemAtPath: dir error: NULL]);
}

- (void) testStoreDirectoryBecomingReadonly
{
    NSString *dir = [self tempPathWithName: @"coreobject-become-readonly"];
    
    @autoreleasepool {
        assert([[NSFileManager defaultManager] createDirectoryAtPath: dir
                                         withIntermediateDirectories: NO
                                                          attributes: nil
                                                               error: NULL]);
        
        COSQLiteStore *store = [[COSQLiteStore alloc] initWithURL: [NSURL fileURLWithPath: dir
                                                                               isDirectory: YES]];
        UKNotNil(store);
        
        assert([[NSFileManager defaultManager] setAttributes: READONLY_SEARCHABLE_DIRECTORY_ATTRIBUTES
                                                ofItemAtPath: dir
                                                       error: NULL]);
        
        // At this point the SQLite database file in dir can be freely modified, but creating files in dir will
        // fail since it's readonly, so creating new persistent roots should fail.
        
		COStoreTransaction *txn = [[COStoreTransaction alloc] init];
		
		[txn createPersistentRootWithInitialItemGraph: [self makeInitialItemGraph]
												 UUID: [ETUUID UUID]
										   branchUUID: [ETUUID UUID]
									 revisionMetadata: nil];
       
        UKFalse([store commitStoreTransaction: txn]);
    }
    
    assert([[NSFileManager defaultManager] setAttributes: REABLE_WRITABLE_SEARCHABLE_DIRECTORY_ATTRIBUTES
                                            ofItemAtPath: dir
                                                   error: NULL]);
    assert([[NSFileManager defaultManager] removeItemAtPath: dir error: NULL]);
}

- (void) testDatabasesBecomingReadonly
{
    NSString *dir = [self tempPathWithName: @"coreobject-index-become-readonly"];
    
    COPersistentRootInfo *info = nil;
    int64_t changeCount;
	
    @autoreleasepool {
        assert([[NSFileManager defaultManager] createDirectoryAtPath: dir
                                         withIntermediateDirectories: NO
                                                          attributes: nil
                                                               error: NULL]);
        
        COSQLiteStore *store = [[COSQLiteStore alloc] initWithURL: [NSURL fileURLWithPath: dir
                                                                               isDirectory: YES]];
        UKNotNil(store);
        
        COStoreTransaction *txn = [[COStoreTransaction alloc] init];
        info = [txn createPersistentRootWithInitialItemGraph: [self makeInitialItemGraph]
														UUID: [ETUUID UUID]
												  branchUUID: [ETUUID UUID]
										    revisionMetadata: nil];
		changeCount = [txn setOldTransactionID: -1 forPersistentRoot: [info UUID]];
        UKTrue([store commitStoreTransaction: txn]);
        
        UKNotNil(info);
    }

    // Make the SQLite files readonly
    
    for (NSString *filename in [[NSFileManager defaultManager] contentsOfDirectoryAtPath: dir error: NULL])
    {
        assert([[NSFileManager defaultManager] setAttributes: READONLY_SEARCHABLE_DIRECTORY_ATTRIBUTES
                                                ofItemAtPath: [dir stringByAppendingPathComponent: filename]
                                                       error: NULL]);
    }

    // Now, writing a revision should fail
    
    @autoreleasepool {
        COSQLiteStore *store = [[COSQLiteStore alloc] initWithURL: [NSURL fileURLWithPath: dir
                                                                               isDirectory: YES]];        
        
        {
			COStoreTransaction *txn = [[COStoreTransaction alloc] init];
            [txn writeRevisionWithModifiedItems: [self makeChangedItemGraph]
								   revisionUUID: [ETUUID UUID]
									   metadata: nil
							   parentRevisionID: [info currentRevisionUUID]
						  mergeParentRevisionID: nil
							 persistentRootUUID: [info UUID]
									 branchUUID: [info currentBranchUUID]];
            UKFalse([store commitStoreTransaction: txn]);
        }
        
        // Check we can still read the initial revision
        
        UKObjectsEqual([self makeInitialItemGraph], [store itemGraphForRevisionUUID: [info currentRevisionUUID] persistentRoot: [info UUID]]);
    }
    
    assert([[NSFileManager defaultManager] removeItemAtPath: dir error: NULL]);
}

@end