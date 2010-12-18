#import "NSString+UUID.h"


@implementation NSString (UUID)


+ (NSString*)stringWithNewUUID
{
  // Create a new UUID
  CFUUIDRef uuidObj = CFUUIDCreate(nil);
  
  // Get the string representation of the UUID
  NSString *newUUID = (NSString*)CFUUIDCreateString(nil, uuidObj);
  CFRelease(uuidObj);
  return [newUUID autorelease];
}

@end
