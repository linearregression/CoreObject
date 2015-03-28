/*
	Copyright (C) 2014 Quentin Mathe

	Date:  December 2014
	License:  MIT  (see COPYING)
 */

#import "COSchemaMigration.h"
#import "COItem.h"
#import "COModelElementMove.h"
#import "COSchemaMigrationDriver.h"

@implementation COSchemaMigration

@synthesize domain = _domain, destinationVersion = _destinationVersion, migrationBlock = _migrationBlock;
@synthesize entityMoves = _entityMoves, propertyMoves = _propertyMoves, migrationDriver = _migrationDriver;

static NSMutableDictionary *migrations;
static NSMutableDictionary *dependencies;
static NSMutableDictionary *versionsByDomainByEntityTuple;

+ (void)initialize
{
	if (self != [COSchemaMigration class])
		return;

	migrations = [NSMutableDictionary new];
	versionsByDomainByEntityTuple = [NSMutableDictionary new];
}

#pragma mark Schema Migration Registration -

+ (void)registerMigration: (COSchemaMigration *)migration
{
	INVALIDARG_EXCEPTION_TEST(migration, migration.domain != nil);
	INVALIDARG_EXCEPTION_TEST(migration, migration.destinationVersion > 0);

	migrations[S(migration.domain, @(migration.destinationVersion))] = migration;
	dependencies = nil;
}

+ (COSchemaMigration *)migrationForDomain: (NSString *)domain destinationVersion: (NSInteger)version
{
	NILARG_EXCEPTION_TEST(domain);
	INVALIDARG_EXCEPTION_TEST(version, version > 0);

	return migrations[S(domain, @(version))];
}

// NOTE: For unit testing purpose
+ (void)clearRegisteredMigrations
{
	[migrations removeAllObjects];
	dependencies = nil;
	[versionsByDomainByEntityTuple removeAllObjects];
}

+ (NSDictionary *)dependencies
{
	if (dependencies != nil)
		return dependencies;
	
	dependencies = [NSMutableDictionary new];

	for (COSchemaMigration *migration in [migrations objectEnumerator])
	{
		NSSet *migrationMoves =
			[migration.entityMoves setByAddingObjectsFromSet: migration.propertyMoves];

		for (COModelElementMove *move in migrationMoves)
		{
			ETKeyValuePair *pair = [ETKeyValuePair pairWithKey: move.domain
			                                             value: @(move.version)];

			if (dependencies[pair] == nil)
			{
				dependencies[pair] = [NSMutableArray new];
			}
			[(NSMutableArray *)dependencies[pair] addObject: migration];
		}
		
	}
	// TODO: Check there is no cycle with a topological sort.
	
	return dependencies;
}

+ (NSDictionary *)versionsByDomainByEntityTuple
{
	return versionsByDomainByEntityTuple;
}

+ (void) recordVersionsByDomain: (NSDictionary *)versions
					  forDomain: (NSString *)domain
						version: (int64_t)version
					 entityName: (NSString *)entity
{
	NSArray *tuple = @[domain, @(version)];
	versionsByDomainByEntityTuple[tuple] = versions;
}

#pragma mark - Triggering a Migration

+ (NSArray *)migrateItems: (NSArray *)storeItems withModelDescriptionRepository: (ETModelDescriptionRepository *)repo
{
	return [[[COSchemaMigrationDriver alloc]
		initWithModelDescriptionRepository: repo] migrateItems: storeItems];
}

#pragma mark Targeted Versions -

- (int64_t)sourceVersion
{
	return (self.destinationVersion == 0 ? 0 : self.destinationVersion - 1);
}

#pragma mark Migration Process -

- (void)validateItems: (NSArray *)storeItems
{
	for (COItem *item in storeItems)
	{
		ETAssert(self.migrationDriver != nil);
		NSDictionary *versionsByDomain = [self.migrationDriver versionsByDomainForItem: item];
		int64_t itemVersion = [versionsByDomain[self.domain] longLongValue];

		if (itemVersion != self.sourceVersion)
		{
			[NSException raise: NSInvalidArgumentException
		                format: @"Item version %lld doesn't match migration source version %lld",
			                    itemVersion, self.sourceVersion];
		}
	}
}

- (NSArray *)migrateItems: (NSArray *)storeItems
{
	[self validateItems: storeItems];

	if (self.migrationBlock != NULL)
	{
		return self.migrationBlock(self, storeItems);
	}
	else
	{
		return storeItems;
	}
}

@end
