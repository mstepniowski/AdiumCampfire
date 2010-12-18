//
//  NSNumber+Conversion.m
//  MSTCampfireEngine
//
//  Created by Marek Stępniowski on 10-03-18.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import "NSNumber+Conversion.h"


@implementation NSNumber (Conversion)

+ (BOOL)parseString:(NSString *)str intoUInt64:(UInt64 *)pNum
{
	if(str == nil)
	{
		*pNum = 0;
		return NO;
	}
	
	errno = 0;
	
	// On both 32-bit and 64-bit machines, unsigned long long = 64 bit
	
	*pNum = strtoull([str UTF8String], NULL, 10);
	
	if(errno != 0)
		return NO;
	else
		return YES;
}

@end
