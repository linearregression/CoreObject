/*
	Copyright (C) 2013 Eric Wasylishen

	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <UnitKit/UnitKit.h>
#import <Foundation/Foundation.h>
#import "TestCommon.h"

@interface TestUnivaluedRelationshipWithOpposite : NSObject <UKTest>
@end

@implementation TestUnivaluedRelationshipWithOpposite

- (void) testUnivaluedGroupWithOpposite
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnivaluedGroupWithOpposite *group1 = [ctx insertObjectWithEntityName: @"UnivaluedGroupWithOpposite"];
	UnivaluedGroupWithOpposite *group2 = [ctx insertObjectWithEntityName: @"UnivaluedGroupWithOpposite"];
	UnivaluedGroupWithOpposite *group3 = [ctx insertObjectWithEntityName: @"UnivaluedGroupWithOpposite"];
	UnivaluedGroupContent *item1 = [ctx insertObjectWithEntityName: @"UnivaluedGroupContent"];
	
	group1.content = item1;
	group2.content = item1;
	UKNil(group3.content);
	
	UKObjectsEqual(S(group1, group2), [item1 parents]);
	
	// Make some changes
	
	group2.content = nil;
	
	UKObjectsEqual(S(group1), [item1 parents]);
	
	group3.content = item1;
	
	UKObjectsEqual(S(group1, group3), [item1 parents]);
	
	// Reload in another graph
	
	COObjectGraphContext *ctx2 = [COObjectGraphContext new];
	[ctx2 setItemGraph: ctx];
	
	UnivaluedGroupWithOpposite *group1ctx2 = [ctx2 loadedObjectForUUID: [group1 UUID]];
	UnivaluedGroupWithOpposite *group2ctx2 = [ctx2 loadedObjectForUUID: [group2 UUID]];
	UnivaluedGroupWithOpposite *group3ctx2 = [ctx2 loadedObjectForUUID: [group3 UUID]];
	UnivaluedGroupContent *item1ctx2 = [ctx2 loadedObjectForUUID: [item1 UUID]];
	
	UKObjectsEqual(item1ctx2, [group1ctx2 content]);
	UKNil([group2ctx2 content]);
	UKObjectsEqual(item1ctx2, [group3ctx2 content]);
	UKObjectsEqual(S(group1ctx2, group3ctx2), [item1ctx2 parents]);
	
	// Check the relationship cache
	UKObjectsEqual(S(group1, group3), [item1 referringObjects]);
	UKObjectsEqual(S(group1ctx2, group3ctx2), [item1ctx2 referringObjects]);
}

- (void)testNullAllowedForUnivalued
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnivaluedGroupWithOpposite *group1 = [ctx insertObjectWithEntityName: @"UnivaluedGroupWithOpposite"];
	
	UKDoesNotRaiseException([group1 setContent: nil]);
}

- (void)testNullAndNSNullEquivalent
{
	COObjectGraphContext *ctx = [COObjectGraphContext new];
	UnivaluedGroupWithOpposite *group1 = [ctx insertObjectWithEntityName: @"UnivaluedGroupWithOpposite"];
	UnivaluedGroupContent *item1 = [ctx insertObjectWithEntityName: @"UnivaluedGroupContent"];
	group1.content = item1;
	
	UKNotNil(group1.content);
	UKDoesNotRaiseException(group1.content = (UnivaluedGroupContent *)[NSNull null]);
	UKNil(group1.content);
}

@end

/**
 * For some general code comments that apply to all tests, see
 * -testTargetPersistentRootUndeletion, -testSourcePersistentRootUndeletion and
 * -testSourcePersistentRootUndeletionForReferenceToSpecificBranch.
 */
@interface TestCrossPersistentRootUnivaluedRelationshipWithOpposite : EditingContextTestCase <UKTest>
{
	UnivaluedGroupWithOpposite *group1;
	UnivaluedGroupContent *item1;
	UnivaluedGroupContent *otherItem1;
	UnivaluedGroupWithOpposite *otherGroup1;
}

@end

@implementation TestCrossPersistentRootUnivaluedRelationshipWithOpposite

- (id)init
{
	SUPERINIT;
	
	ctx.unloadingBehavior = COEditingContextUnloadingBehaviorNever;

	group1 = [ctx insertNewPersistentRootWithEntityName: @"UnivaluedGroupWithOpposite"].rootObject;
	item1 = [ctx insertNewPersistentRootWithEntityName: @"UnivaluedGroupContent"].rootObject;
	item1.label = @"current";
	group1.label = @"current";
	group1.content = item1;
	[ctx commit];

	otherItem1 = [item1.persistentRoot.currentBranch makeBranchWithLabel: @"other"].rootObject;
	otherItem1.label = @"other";
	otherGroup1 = [group1.persistentRoot.currentBranch makeBranchWithLabel: @"other"].rootObject;
	otherGroup1.label = @"other";
	[ctx commit];

	return self;
}

#define CHECK_BLOCK_ARGS COEditingContext *testCtx, UnivaluedGroupWithOpposite *testGroup1, UnivaluedGroupContent *testItem1, UnivaluedGroupContent *testOtherItem1, UnivaluedGroupWithOpposite *testOtherGroup1, UnivaluedGroupWithOpposite *testCurrentGroup1, UnivaluedGroupContent *testCurrentItem1, BOOL isNewContext

- (void)checkPersistentRootsWithExistingAndNewContextInBlock: (void (^)(CHECK_BLOCK_ARGS))block
{
	[self checkPersistentRootWithExistingAndNewContext: group1.persistentRoot
											   inBlock:
	 ^(COEditingContext *testCtx, COPersistentRoot *testPersistentRoot, COBranch *testBranch, BOOL isNewContext)
	{
		UnivaluedGroupWithOpposite *testGroup1 = testPersistentRoot.rootObject;
		UnivaluedGroupContent *testItem1 =
			[testCtx persistentRootForUUID: item1.persistentRoot.UUID].rootObject;
		UnivaluedGroupContent *testOtherItem1 =
			[testItem1.persistentRoot branchForUUID: otherItem1.branch.UUID].rootObject;
		UnivaluedGroupWithOpposite *testOtherGroup1 =
			[testGroup1.persistentRoot branchForUUID: otherGroup1.branch.UUID].rootObject;

		UnivaluedGroupWithOpposite *testCurrentGroup1 = testPersistentRoot.currentBranch.rootObject;
		UnivaluedGroupContent *testCurrentItem1 =
			[testCtx persistentRootForUUID: item1.persistentRoot.UUID].currentBranch.rootObject;
		UnivaluedGroupContent *testCurrentOtherItem1 =
			[testCtx persistentRootForUUID: otherItem1.persistentRoot.UUID].currentBranch.rootObject;
		UnivaluedGroupWithOpposite *testCurrentOtherGroup1 =
			[testCtx persistentRootForUUID: otherGroup1.persistentRoot.UUID].currentBranch.rootObject;

		UKObjectsSame(testCurrentGroup1, testCurrentOtherGroup1);
		UKObjectsSame(testCurrentItem1, testCurrentOtherItem1);
		
		block(testCtx, testGroup1, testItem1, testOtherItem1, testOtherGroup1, testCurrentGroup1, testCurrentItem1, isNewContext);
	}];
}

#pragma mark - Relationship Target Deletion Tests

- (void)testTargetPersistentRootDeletion
{
	item1.persistentRoot.deleted = YES;
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKNil(testGroup1.content);
		UKTrue(testItem1.parents.isEmpty);

		UKNil(testCurrentGroup1.content);
		UKTrue(testCurrentItem1.parents.isEmpty);
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
		UKObjectsEqual(testItem1, testGroup1.content);
		UKObjectsEqual(S(testGroup1), testItem1.parents);

		// Bidirectional cross persistent root relationships are limited to the
		// tracking branch, this means item1 in the non-tracking current branch
		// doesn't appear in testCurrentGroup1.contents and doesn't refer to it
		// with an inverse relationship (-referringObjectsForPropertyInTarget:
		// simulates it though).
		// Bidirectional cross persistent root relationships are supported
		// accross current branches, but materialized accross tracking branches
		// in memory (they are not visible accross the current branches in memory).
		UKObjectsEqual(testItem1, testCurrentGroup1.content);
		UKObjectsEqual(S(testGroup1), testCurrentItem1.parents);
	}];
}

- (void)testTargetPersistentRootDeletionForReferenceToSpecificBranch
{
	group1.content = otherItem1;
	[ctx commit];

	item1.persistentRoot.deleted = YES;
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKNil(testGroup1.content);
		UKTrue(testItem1.parents.isEmpty);
		
		UKNil(testCurrentGroup1.content);
		UKTrue(testCurrentItem1.parents.isEmpty);
	}];
}

- (void)testTargetPersistentRootUndeletionForReferenceToSpecificBranch
{
	group1.content = otherItem1;
	[ctx commit];

	item1.persistentRoot.deleted = YES;
	[ctx commit];
	
	item1.persistentRoot.deleted = NO;
	[ctx commit];
	
	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKStringsEqual(@"other", testOtherItem1.label);
		UKStringsEqual(@"current", testItem1.label);
		UKObjectsEqual(testOtherItem1, testGroup1.content);
		UKObjectsEqual(S(testGroup1), testOtherItem1.parents);
		
		UKObjectsEqual(testOtherItem1, testCurrentGroup1.content);
		UKTrue(testCurrentItem1.parents.isEmpty);
	}];
}

/**
 * The current branch cannot be deleted, so we cannot write a test method
 * -testTargetBranchDeletion analog to -testTargetPersistentRootDeletion
 */
- (void)testTargetBranchDeletionForReferenceToSpecificBranch
{
	group1.content = otherItem1;
	[ctx commit];
	
	otherItem1.branch.deleted = YES;
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKNil(testGroup1.content);
		UKTrue(testOtherItem1.parents.isEmpty);

		UKNil(testCurrentGroup1.content);
		UKTrue(testCurrentItem1.parents.isEmpty);
	}];
}

- (void)testTargetBranchUndeletionForReferenceToSpecificBranch
{
	group1.content = otherItem1;
	[ctx commit];
	
	otherItem1.branch.deleted = YES;
	[ctx commit];

	otherItem1.branch.deleted = NO;
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKStringsEqual(@"other", testOtherItem1.label);
		UKStringsEqual(@"current", testItem1.label);
		UKObjectsEqual(testOtherItem1, testGroup1.content);
		UKObjectsEqual(S(testGroup1), testOtherItem1.parents);

		UKObjectsEqual(testOtherItem1, testCurrentGroup1.content);
		UKTrue(testCurrentItem1.parents.isEmpty);
	}];
}

#pragma mark - Relationship Source Deletion Tests

- (void)testSourcePersistentRootDeletion
{
	group1.persistentRoot.deleted = YES;
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKObjectsEqual(testItem1, testGroup1.content);
		UKTrue(testItem1.parents.isEmpty);

		UKObjectsEqual(testItem1, testCurrentGroup1.content);
		UKTrue(testCurrentItem1.parents.isEmpty);
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
		UKObjectsEqual(testItem1, testGroup1.content);
		// testCurrentGroup1 and testOtherGroup1 present in -referringObjects are hidden by -referringObjectsForPropertyInTarget:
		UKObjectsEqual(S(testGroup1), testItem1.parents);
		 
		UKObjectsEqual(testItem1, testCurrentGroup1.content);
		// testGroup1 missing from -referringObjects is added by -referringObjectsForPropertyInTarget:
		UKObjectsEqual(S(testGroup1), testCurrentItem1.parents);
	}];
}

- (void)testSourcePersistentRootDeletionForReferenceToSpecificBranch
{
	otherGroup1.content = item1;
	[ctx commit];

	otherGroup1.persistentRoot.deleted = YES;
	[ctx commit];

	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKObjectsEqual(testItem1, testOtherGroup1.content);
		UKTrue(testItem1.parents.isEmpty);
		
		UKObjectsEqual(testItem1, testCurrentGroup1.content);
		UKTrue(testCurrentItem1.parents.isEmpty);
	}];
}

- (void)testSourcePersistentRootUndeletionForReferenceToSpecificBranch
{
	otherGroup1.content = item1;
	[ctx commit];

	otherGroup1.persistentRoot.deleted = YES;
	[ctx commit];
	
	otherGroup1.persistentRoot.deleted = NO;
	[ctx commit];
	
	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKStringsEqual(@"other", testOtherGroup1.label);
		UKStringsEqual(@"current", testGroup1.label);
		UKObjectsEqual(testItem1, testOtherGroup1.content);
		// Bidirectional inverse multivalued relationship always point to a
		// single source object owned by the tracking branch, even when the
		// relationship source object exist in multiple branches.
		// For a parent-to-child relationship, reporting every branch source
		// object as a distinct parent doesn't make sense, since conceptually
		// they are all the same parent from the child viewpoint.
		UKObjectsEqual(S(testGroup1), testItem1.parents);
		
		UKObjectsEqual(testItem1, testCurrentGroup1.content);
		UKObjectsEqual(S(testGroup1), testCurrentItem1.parents);
	}];
}

- (void)testSourceBranchDeletionForReferenceToSpecificBranch
{
	otherGroup1.content = item1;
	[ctx commit];
	
	otherGroup1.branch.deleted = YES;
	[ctx commit];
	
	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		 UKObjectsEqual(testItem1, testOtherGroup1.content);
		// The tracking branch is not deleted, so testItem1 parent is untouched,
		// see comment in -testSourcePersistentRootUndeletionForReferenceToSpecificBranch
		 UKObjectsEqual(S(testGroup1), testItem1.parents);
		 
		 UKObjectsEqual(testItem1, testCurrentGroup1.content);
		 UKObjectsEqual(S(testGroup1), testCurrentItem1.parents);
	}];
}

- (void)testSourceBranchUndeletionForReferenceToSpecificBranch
{
	otherGroup1.content = item1;
	[ctx commit];
	
	otherGroup1.branch.deleted = YES;
	[ctx commit];
	
	otherGroup1.branch.deleted = NO;
	[ctx commit];
	
	[self checkPersistentRootsWithExistingAndNewContextInBlock: ^(CHECK_BLOCK_ARGS)
	{
		UKStringsEqual(@"other", testOtherItem1.label);
		UKStringsEqual(@"current", testItem1.label);
		UKObjectsEqual(testItem1, testGroup1.content);
		UKObjectsEqual(S(testGroup1), testItem1.parents);

		UKObjectsEqual(testItem1, testCurrentGroup1.content);
		UKObjectsEqual(S(testGroup1), testCurrentItem1.parents);
	}];
}

@end
