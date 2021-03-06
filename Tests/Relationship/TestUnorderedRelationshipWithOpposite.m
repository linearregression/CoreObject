/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

@interface TestUnorderedRelationshipWithOpposite : NSObject <UKTest>
@end

@implementation TestUnorderedRelationshipWithOpposite

- (void) testUnorderedGroupWithOpposite
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnorderedGroupWithOpposite *group1 = [ctx insertObjectWithEntityName: @"UnorderedGroupWithOpposite"];
	UnorderedGroupWithOpposite *group2 = [ctx insertObjectWithEntityName: @"UnorderedGroupWithOpposite"];
	UnorderedGroupContent *item1 = [ctx insertObjectWithEntityName: @"UnorderedGroupContent"];
	UnorderedGroupContent *item2 = [ctx insertObjectWithEntityName: @"UnorderedGroupContent"];
	
	group1.contents = S(item1, item2);
	group2.contents = S(item1);
	
	UKObjectsEqual(S(group1, group2), [item1 parentGroups]);
	UKObjectsEqual(S(group1), [item2 parentGroups]);
	
	// Make some changes
	
	group2.contents = S(item1, item2);
	
	UKObjectsEqual(S(group1, group2), [item2 parentGroups]);
	
	group1.contents = S(item2);
	
	UKObjectsEqual(S(group2), [item1 parentGroups]);
	
	// Reload in another graph
	
	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	[ctx2 setItemGraph: ctx];
	
	UnorderedGroupWithOpposite *group1ctx2 = [ctx2 loadedObjectForUUID: [group1 UUID]];
	UnorderedGroupWithOpposite *group2ctx2 = [ctx2 loadedObjectForUUID: [group2 UUID]];
	UnorderedGroupContent *item1ctx2 = [ctx2 loadedObjectForUUID: [item1 UUID]];
	UnorderedGroupContent *item2ctx2 = [ctx2 loadedObjectForUUID: [item2 UUID]];
	
	UKObjectsEqual(S(item2ctx2), [group1ctx2 contents]);
	UKObjectsEqual(S(item1ctx2, item2ctx2), [group2ctx2 contents]);
	UKObjectsEqual(S(group1ctx2, group2ctx2), [item2ctx2 parentGroups]);
	UKObjectsEqual(S(group2ctx2), [item1ctx2 parentGroups]);
}

- (void) testIllegalDirectModificationOfCollection
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnorderedGroupWithOpposite *group1 = [ctx insertObjectWithEntityName: @"UnorderedGroupWithOpposite"];
	UnorderedGroupContent *item1 = [ctx insertObjectWithEntityName: @"UnorderedGroupContent"];
	UnorderedGroupContent *item2 = [ctx insertObjectWithEntityName: @"UnorderedGroupContent"];
	
	group1.contents = S(item1, item2);
	
	UKRaisesException([(NSMutableSet *)group1.contents removeObject: item1]);
}

- (void)testNullDisallowedInCollection
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnorderedGroupWithOpposite *group1 = [ctx insertObjectWithEntityName: @"UnorderedGroupWithOpposite"];
	
	UKRaisesException([group1 setContents: S([NSNull null])]);
}

- (void) testWrongEntityTypeInCollection
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnorderedGroupWithOpposite *group1 = [ctx insertObjectWithEntityName: @"UnorderedGroupWithOpposite"];
	OutlineItem *item1 = [ctx insertObjectWithEntityName: @"OutlineItem"];
	
	UKRaisesException([group1 setContents: S(item1)]);
}

@end


/**
 * For some general code comments that apply to all tests, see
 * -testTargetPersistentRootUndeletion, -testSourcePersistentRootUndeletion and
 * -testSourcePersistentRootUndeletionForReferenceToSpecificBranch.
 */
@interface TestCrossPersistentRootUnorderedRelationshipWithOpposite : EditingContextTestCase <UKTest>
{
	UnorderedGroupWithOpposite *group1;
	UnorderedGroupContent *item1;
	UnorderedGroupContent *item2;
	UnorderedGroupContent *otherItem1;
	UnorderedGroupWithOpposite *otherGroup1;
}

@end

@implementation TestCrossPersistentRootUnorderedRelationshipWithOpposite

- (id)init
{
	SUPERINIT;
	
	ctx.unloadingBehavior = COEditingContextUnloadingBehaviorNever;

	group1 = [ctx insertNewPersistentRootWithEntityName: @"UnorderedGroupWithOpposite"].rootObject;
	item1 = [ctx insertNewPersistentRootWithEntityName: @"UnorderedGroupContent"].rootObject;
	item1.label = @"current";
	item2 = [ctx insertNewPersistentRootWithEntityName: @"UnorderedGroupContent"].rootObject;
	group1.label = @"current";
	group1.contents = S(item1, item2);
	[ctx commit];

	otherItem1 = [item1.persistentRoot.currentBranch makeBranchWithLabel: @"other"].rootObject;
	otherItem1.label = @"other";
	otherGroup1 = [group1.persistentRoot.currentBranch makeBranchWithLabel: @"other"].rootObject;
	otherGroup1.label = @"other";
	[ctx commit];

	return self;
}

#define CHECK_BLOCK_ARGS COEditingContext *testCtx, UnorderedGroupWithOpposite *testGroup1, UnorderedGroupContent *testItem1, UnorderedGroupContent *testItem2, UnorderedGroupContent *testOtherItem1, UnorderedGroupWithOpposite *testOtherGroup1, UnorderedGroupWithOpposite *testCurrentGroup1, UnorderedGroupContent *testCurrentItem1, UnorderedGroupContent *testCurrentItem2, BOOL isNewContext

- (void)checkPersistentRootsWithExistingAndNewContextInBlock: (void (^)(CHECK_BLOCK_ARGS))block
{
	[self checkPersistentRootWithExistingAndNewContext: group1.persistentRoot
											   inBlock:
	 ^(COEditingContext *testCtx, COPersistentRoot *testPersistentRoot, COBranch *testBranch, BOOL isNewContext)
	{
		UnorderedGroupWithOpposite *testGroup1 = testPersistentRoot.rootObject;
		UnorderedGroupContent *testItem1 =
			[testCtx persistentRootForUUID: item1.persistentRoot.UUID].rootObject;
		UnorderedGroupContent *testItem2 =
			[testCtx persistentRootForUUID: item2.persistentRoot.UUID].rootObject;
		UnorderedGroupContent *testOtherItem1 =
			[testItem1.persistentRoot branchForUUID: otherItem1.branch.UUID].rootObject;
		UnorderedGroupWithOpposite *testOtherGroup1 =
			[testGroup1.persistentRoot branchForUUID: otherGroup1.branch.UUID].rootObject;
		
		UnorderedGroupWithOpposite *testCurrentGroup1 = testPersistentRoot.currentBranch.rootObject;
		UnorderedGroupContent *testCurrentItem1 =
			[testCtx persistentRootForUUID: item1.persistentRoot.UUID].currentBranch.rootObject;
		UnorderedGroupContent *testCurrentItem2 =
			[testCtx persistentRootForUUID: item2.persistentRoot.UUID].currentBranch.rootObject;
		UnorderedGroupContent *testCurrentOtherItem1 =
			[testCtx persistentRootForUUID: otherItem1.persistentRoot.UUID].currentBranch.rootObject;
		UnorderedGroupWithOpposite *testCurrentOtherGroup1 =
			[testCtx persistentRootForUUID: otherGroup1.persistentRoot.UUID].currentBranch.rootObject;
	
		UKObjectsSame(testCurrentGroup1, testCurrentOtherGroup1);
		UKObjectsSame(testCurrentItem1, testCurrentOtherItem1);
		
		block(testCtx, testGroup1, testItem1, testItem2, testOtherItem1, testOtherGroup1, testCurrentGroup1, testCurrentItem1, testCurrentItem2, isNewContext);
	}];
}

#pragma mark - Relationship Target Deletion Tests

- (void)testTargetPersistentRootDeletion
{
	item1.persistentRoot.deleted = YES;
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKObjectsEqual(S(testItem2), testGroup1.contents);
		UKTrue(testItem1.parentGroups.isEmpty);

		UKObjectsEqual(S(testItem2), testCurrentGroup1.contents);
		UKTrue(testCurrentItem1.parentGroups.isEmpty);
	}];
}

- (void)testTargetPersistentRootUndeletion
{
	item1.persistentRoot.deleted = YES;
	[ctx commit];
	
	item1.persistentRoot.deleted = NO;
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKObjectsEqual(S(testItem1, testItem2), testGroup1.contents);
		UKObjectsEqual(S(testGroup1), testItem1.parentGroups);

		// Bidirectional cross persistent root relationships are limited to the
		// tracking branch, this means item1 in the non-tracking current branch
		// doesn't appear in testCurrentGroup1.contents and doesn't refer to it
		// with an inverse relationship (-referringObjectsForPropertyInTarget:
		// simulates it though).
		// Bidirectional cross persistent root relationships are supported
		// accross current branches, but materialized accross tracking branches
		// in memory (they are not visible accross the current branches in memory).
		UKObjectsEqual(S(testItem1, testItem2), testCurrentGroup1.contents);
		UKObjectsEqual(S(testGroup1), testCurrentItem1.parentGroups);
	}];
}

- (void)testTargetPersistentRootDeletionForReferenceToSpecificBranch
{
	group1.contents = S(otherItem1, item2);
	[ctx commit];

	item1.persistentRoot.deleted = YES;
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKObjectsEqual(S(testItem2), testGroup1.contents);
		UKTrue(testItem1.parentGroups.isEmpty);
		
		UKObjectsEqual(S(testItem2), testCurrentGroup1.contents);
		UKTrue(testCurrentItem1.parentGroups.isEmpty);
	}];
}

- (void)testTargetPersistentRootUndeletionForReferenceToSpecificBranch
{
	group1.contents = S(otherItem1, item2);
	[ctx commit];

	item1.persistentRoot.deleted = YES;
	[ctx commit];
	
	item1.persistentRoot.deleted = NO;
	[ctx commit];
	
	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKStringsEqual(@"other", testOtherItem1.label);
		UKStringsEqual(@"current", testItem1.label);
		UKObjectsEqual(S(testOtherItem1, testItem2), testGroup1.contents);
		UKObjectsEqual(S(testGroup1), testOtherItem1.parentGroups);
		
		UKObjectsEqual(S(testOtherItem1, testItem2), testCurrentGroup1.contents);
		UKObjectsEqual(S(testGroup1), testOtherItem1.parentGroups);
	}];
}

/**
 * The current branch cannot be deleted, so we cannot write a test method
 * -testTargetBranchDeletion analog to -testTargetPersistentRootDeletion
 */
- (void)testTargetBranchDeletionForReferenceToSpecificBranch
{
	group1.contents = S(otherItem1, item2);
	[ctx commit];
	
	otherItem1.branch.deleted = YES;
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKObjectsEqual(S(testItem2), testGroup1.contents);
		UKTrue(testOtherItem1.parentGroups.isEmpty);

		UKObjectsEqual(S(testItem2), testCurrentGroup1.contents);
		UKTrue(testCurrentItem1.parentGroups.isEmpty);

	}];
}

- (void)testTargetBranchUndeletionForReferenceToSpecificBranch
{
	group1.contents = S(otherItem1, item2);
	[ctx commit];
	
	otherItem1.branch.deleted = YES;
	[ctx commit];

	otherItem1.branch.deleted = NO;
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKStringsEqual(@"other", testOtherItem1.label);
		UKStringsEqual(@"current", testItem1.label);
		UKObjectsEqual(S(testOtherItem1, testItem2), testGroup1.contents);
		UKObjectsEqual(S(testGroup1), testOtherItem1.parentGroups);

		UKObjectsEqual(S(testOtherItem1, testItem2), testCurrentGroup1.contents);
		UKObjectsEqual(S(testGroup1), testOtherItem1.parentGroups);
	}];
}


#pragma mark - Relationship Source Deletion Tests

- (void)testSourcePersistentRootDeletion
{
	group1.persistentRoot.deleted = YES;
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKObjectsEqual(S(testItem1, testItem2), testGroup1.contents);
		UKTrue(testItem1.parentGroups.isEmpty);

		UKObjectsEqual(S(testItem1, testItem2), testCurrentGroup1.contents);
		UKTrue(testCurrentItem1.parentGroups.isEmpty);
	}];
}

- (void)testSourcePersistentRootUndeletion
{
	group1.persistentRoot.deleted = YES;
	[ctx commit];

	group1.persistentRoot.deleted = NO;
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKObjectsEqual(S(testItem1, testItem2), testGroup1.contents);
		// testCurrentGroup1 and testOtherGroup1 present in -referringObjects are hidden by -referringObjectsForPropertyInTarget:
		UKObjectsEqual(S(testGroup1), testItem1.parentGroups);
		 
		UKObjectsEqual(S(testItem1, testItem2), testCurrentGroup1.contents);
		// testGroup1 missing from -referringObjects is added by -referringObjectsForPropertyInTarget:
		UKObjectsEqual(S(testGroup1), testCurrentItem1.parentGroups);
	}];
}

- (void)testSourcePersistentRootDeletionForReferenceToSpecificBranch
{
	otherGroup1.contents = S(item1, item2);
	[ctx commit];

	otherGroup1.persistentRoot.deleted = YES;
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKObjectsEqual(S(testItem1, testItem2), testOtherGroup1.contents);
		UKTrue(testItem1.parentGroups.isEmpty);
		
		UKObjectsEqual(S(testItem1, testItem2), testCurrentGroup1.contents);
		UKTrue(testCurrentItem1.parentGroups.isEmpty);
	}];
}

- (void)testSourcePersistentRootUndeletionForReferenceToSpecificBranch
{
	otherGroup1.contents = S(item1, item2);
	[ctx commit];

	otherGroup1.persistentRoot.deleted = YES;
	[ctx commit];
	
	otherGroup1.persistentRoot.deleted = NO;
	[ctx commit];
	
	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKStringsEqual(@"other", testOtherGroup1.label);
		UKStringsEqual(@"current", testGroup1.label);
		UKObjectsEqual(S(testItem1, testItem2), testOtherGroup1.contents);
		// Bidirectional inverse multivalued relationship always point to a
		// single source object owned by the tracking branch, even when the
		// relationship source object exist in multiple branches.
		// For a parent-to-child relationship, reporting every branch source
		// object as a distinct parent doesn't make sense, since conceptually
		// they are all the same parent from the child viewpoint.
		UKObjectsEqual(S(testGroup1), testItem1.parentGroups);
		
		UKObjectsEqual(S(testItem1, testItem2), testCurrentGroup1.contents);
		UKObjectsEqual(S(testGroup1), testCurrentItem1.parentGroups);
	}];
}

- (void)testSourceBranchDeletionForReferenceToSpecificBranch
{
	otherGroup1.contents = S(item1, item2);
	[ctx commit];
	
	otherGroup1.branch.deleted = YES;
	[ctx commit];
	
	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKObjectsEqual(S(testItem1, testItem2), testOtherGroup1.contents);
		// The tracking branch is not deleted, so testItem1 parent is untouched,
		// see comment in -testSourcePersistentRootUndeletionForReferenceToSpecificBranch
		UKObjectsEqual(S(testGroup1), testItem1.parentGroups);

		UKObjectsEqual(S(testItem1, testItem2), testCurrentGroup1.contents);
		UKObjectsEqual(S(testGroup1), testCurrentItem1.parentGroups);
	}];
}

- (void)testSourceBranchUndeletionForReferenceToSpecificBranch
{
	otherGroup1.contents = S(item1, item2);
	[ctx commit];
	
	otherGroup1.branch.deleted = YES;
	[ctx commit];
	
	otherGroup1.branch.deleted = NO;
	[ctx commit];
	
	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKStringsEqual(@"other", testOtherItem1.label);
		UKStringsEqual(@"current", testItem1.label);
		UKObjectsEqual(S(testItem1, testItem2), testGroup1.contents);
		UKObjectsEqual(S(testGroup1), testItem1.parentGroups);

		UKObjectsEqual(S(testItem1, testItem2), testCurrentGroup1.contents);
		UKObjectsEqual(S(testGroup1), testCurrentItem1.parentGroups);
	}];
}

@end
