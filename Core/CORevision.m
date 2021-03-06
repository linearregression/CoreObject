/*
	Copyright (C) 2010 Eric Wasylishen, Quentin Mathe

	Date:  November 2010
	License:  MIT  (see COPYING)
 */

#import "CORevision.h"
#import "COCommitDescriptor.h"
#import "CORevisionInfo.h"
#import "COSQLiteStore.h"
#import "CORevisionCache.h"


@implementation CORevision

- (id)initWithCache: (CORevisionCache *)aCache
       revisionInfo: (CORevisionInfo *)aRevInfo
{
	SUPERINIT;
	cache = aCache;
	revisionInfo =  aRevInfo;
    assert([revisionInfo revisionUUID] != nil);
	return self;
}

- (BOOL)isEqual: (id)rhs
{
	if ([rhs isKindOfClass: [CORevision class]] == NO)
		return NO;

	return [revisionInfo.revisionUUID isEqual: ((CORevision *)rhs)->revisionInfo.revisionUUID];
}

- (NSUInteger)hash
{
	return [revisionInfo.revisionUUID hash];
}

- (NSArray *)propertyNames
{
	return [[super propertyNames] arrayByAddingObjectsFromArray: 
		A(@"UUID", @"date", @"type", @"localizedTypeDescription",
		@"localizedShortDescription", @"metadata")];
}

- (ETUUID *)UUID
{
	return [revisionInfo revisionUUID];
}

- (CORevisionCache *) cache
{
	if (cache == nil)
		[NSException raise: NSGenericException
					format: @"Attempted to access a CORevision property from a revision whose parent revision cache/editing context have been deallocated"];
	return cache;
}

- (CORevision *)parentRevision
{
    if ([revisionInfo parentRevisionUUID] == nil)
    {
        return nil;
    }
    
	ETUUID *parentRevID = [revisionInfo parentRevisionUUID];
    return [[self cache] revisionForRevisionUUID: parentRevID
							  persistentRootUUID: [revisionInfo persistentRootUUID]];
}

- (CORevision *)mergeParentRevision
{
    if ([revisionInfo mergeParentRevisionUUID] == nil)
    {
        return nil;
    }
    
	ETUUID *revID = [revisionInfo mergeParentRevisionUUID];
    return [[self cache] revisionForRevisionUUID: revID
							  persistentRootUUID: [revisionInfo persistentRootUUID]];
}

- (ETUUID *)persistentRootUUID
{
	return [revisionInfo persistentRootUUID];
}

- (ETUUID *)branchUUID
{
	return [revisionInfo branchUUID];
}

- (NSDate *)date
{
	return [revisionInfo date];
}

// TODO: Implement it in the metadata for the new store
// Formalize the concept of similar operations belonging to a common kind...
// For example:
// - major edit vs minor edit
// - Item Mutation that includes Add Item, Remove Item, Insert Item etc.

- (NSDictionary *)metadata
{
	return [revisionInfo metadata];
}

- (COCommitDescriptor *)commitDescriptor
{
	NSString *commitDescriptorId =
		[[self metadata] objectForKey: kCOCommitMetadataIdentifier];

	if (commitDescriptorId == nil)
		return nil;

	return [COCommitDescriptor registeredDescriptorForIdentifier: commitDescriptorId];
}

- (NSString *)localizedTypeDescription
{
	COCommitDescriptor *descriptor = [self commitDescriptor];

	if (descriptor == nil)
		return [[self metadata] objectForKey: kCOCommitMetadataTypeDescription];

	return [descriptor localizedTypeDescription];
}

- (NSString *)localizedShortDescription
{
	return [COCommitDescriptor localizedShortDescriptionFromMetadata: self.metadata];
}

- (NSString *)type
{
	return [[self metadata] objectForKey: @"type"];
}

- (NSString *)shortDescription
{
	return [[self metadata] objectForKey: @"shortDescription"];
}

- (NSString *)description
{
	return [NSString stringWithFormat: @"%@ (%@ <= %@)", 
		NSStringFromClass([self class]),
		[self UUID],
		([self parentRevision] != nil ? [[self parentRevision] UUID] : @"none")];
}

- (BOOL) isEqualToOrAncestorOfRevision: (CORevision *)aRevision
{
    CORevision *rev = aRevision;
    while (rev != nil)
    {
        if ([rev isEqual: self])
        {
            return YES;
        }
        rev = [rev parentRevision];
    }
    return NO;
}

#pragma mark - COTrackNode Implementation

- (id<COTrackNode>)parentNode
{
	return [self parentRevision];
}

- (id<COTrackNode>)mergeParentNode
{
	return [self mergeParentRevision];
}

@end
