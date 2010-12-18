//
//  NSNumber+Conversion.h
//  MSTCampfireEngine
//
//  Created by Marek Stępniowski on 10-03-18.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSNumber (Conversion)

+ (BOOL)parseString:(NSString *)str intoUInt64:(UInt64 *)pNum;

@end
