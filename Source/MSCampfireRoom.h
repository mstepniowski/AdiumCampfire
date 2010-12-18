//
//  MSCampfireRoom.h
//  AdiumCampfire
//
//  Created by Marek Stępniowski on 10-03-30.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MSCampfireRoom : NSObject {
  NSInteger uid;
  NSMutableArray *contactUIDs;
}

- (MSCampfireRoom *)initWithUID:(NSInteger)anUID;

- (void)addContactWithUID:(NSInteger)anUID;
- (NSArray *)contactUIDs;

@end
