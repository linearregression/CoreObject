/**
	Copyright (C) 2013 Eric Wasylishen

	Date:  December 2013
	License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>

@class COObject, COPath;

@interface COWeakRef : NSObject
{
	@public
	__weak COObject *_object;
}

- (instancetype)initWithObject: (COObject *)anObject;

@end


@protocol COPrimitiveCollection <NSObject>
- (void) beginMutation;
- (void) endMutation;
@property (nonatomic, readonly) BOOL isMutable;
@property (nonatomic, readonly) id <NSFastEnumeration> enumerableReferences;
@end

@interface COMutableSet : NSMutableSet <COPrimitiveCollection>
{
	@public
	BOOL _permanentlyMutable;
	int _temporaryMutable;
	NSHashTable *_backing;
	NSHashTable *_deadReferences;
}
- (void)addReference: (id)aReference;
- (void)removeReference: (id)aReference;
- (BOOL)containsReference: (id)aReference;
@end

@interface COMutableSet (TestPrimitiveCollection)

@property (nonatomic, readonly) NSSet *deadReferences;
@property (nonatomic, readonly) NSSet *allReferences;

@end


/**
 * References are either COPath or any other object.
 *
 * COPath are treated as "tombstones" and hidden from the NSArray
 * access methods (-count, -objectAtIndex:, etc.)
 */
@interface COMutableArray : NSMutableArray <COPrimitiveCollection>
{
@public
	BOOL _permanentlyMutable;
	int _temporaryMutable;
	NSPointerArray *_backing;
	/**
	 * Array of integers, the ith entry gives the backing index for
	 * "external" index i.
	 */
	NSPointerArray *_externalIndexToBackingIndex;
}

@property (nonatomic, readonly) NSPointerArray *backing;

- (id)referenceAtIndex: (NSUInteger)index;
- (void)addReference: (id)aReference;
- (void)replaceReferenceAtIndex: (NSUInteger)index withReference: (id)aReference;
@end

@interface COMutableArray (TestPrimitiveCollection)

@property (nonatomic, readonly) NSIndexSet *deadIndexes;
@property (nonatomic, readonly) NSArray *deadReferences;
@property (nonatomic, readonly) NSArray *allReferences;

@end

@interface COUnsafeRetainedMutableSet : COMutableSet
@end

@interface COUnsafeRetainedMutableArray : COMutableArray
{
	// TODO: Replace with custom acquire/relinquish functions to retain/release
	// COPath references as necessary
	NSMutableSet *_deadReferences;
	NSHashTable *_backingHashTable;
}
@end

@interface COMutableDictionary : NSMutableDictionary <COPrimitiveCollection>
{
	@public
	BOOL _permanentlyMutable;
	int _temporaryMutable;
	NSMutableDictionary *_backing;
	NSMutableSet *_deadKeys;
}
- (void)setReference: (id)aReference forKey: (id <NSCopying>)aKey;
@end
