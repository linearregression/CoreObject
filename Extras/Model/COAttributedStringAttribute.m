#import "COAttributedStringAttribute.h"

@implementation COAttributedStringAttribute

+ (ETEntityDescription*)newEntityDescription
{
    ETEntityDescription *entity = [ETEntityDescription descriptionWithName: @"COAttributedStringAttribute"];
    [entity setParent: (id)@"COObject"];
	
	ETPropertyDescription *htmlCodeProperty = [ETPropertyDescription descriptionWithName: @"htmlCode"
																					type: (id)@"NSString"];
	htmlCodeProperty.persistent = YES;
	
	[entity setPropertyDescriptions: @[htmlCodeProperty]];
    return entity;
}
@dynamic htmlCode;

@end
