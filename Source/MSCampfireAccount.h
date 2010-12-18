//
//  MSCampfireAccount.h
//  AdiumCampfire
//
//  Created by Marek Stępniowski on 10-03-10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import <Adium/AIAccount.h>
#import "MSCampfireEngine.h"

@interface MSCampfireAccount : AIAccount {
  MSCampfireEngine *engine;
  NSMutableDictionary *_rooms;
  NSData *lastRoomsUpdate;
  NSInteger updatedRoomsCount;
}

@property (readonly, nonatomic) NSString *defaultServer;

- (void)updateCampfireChat:(AIChat *)campfireChat;
/*- (AIChat *)chatWithName:(NSString *)name;*/
- (void)setConnectionProgress:(NSNumber *)progress message:(NSString *)message;

@end
