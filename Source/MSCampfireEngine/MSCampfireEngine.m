//
//  MSTCampfireEngine.m
//  AdiumCampfire
//
//  Created by Marek Stępniowski on 10-03-11.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import <Adium/ESDebugAILog.h>
#import "MSCampfireEngine.h"
#import "MSHTTPConnection.h"

#define ROOMS @"rooms"
#define ROOM_INFORMATION @"room information"
#define LISTEN @"listen"
#define JOIN @"join"
#define LEAVE @"leave"
#define SPEAK @"speak"
#define USER_INFORMATION @"user information"

@interface MSCampfireEngine (Private)

- (void)startRequestWithMethod:(NSString *)method
                          path:(NSString *)path
                     streaming:(BOOL)streaming
                           key:(NSString *)key
                      userInfo:(id)info;

- (void)startRequestWithMethod:(NSString *)method
                          path:(NSString *)path
                     streaming:(BOOL)streaming
                           key:(NSString *)key
                      userInfo:(id)info
                       payload:(NSData *)payload;

@end


@implementation MSCampfireEngine

- (MSCampfireEngine *)initWithDomain:(NSString *)domain key:(NSString *)key delegate:(NSObject *)newDelegate 
{
  AILog(@"%@: %@ %@", self, domain, key);
  if ((self = [super init])) {
    delegate = newDelegate;
    _secureConnection = YES;
    _APIDomain = [domain retain];
    _key = [key retain];
    connections = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)dealloc
{
  [_key release];
  [_APIDomain release];
  [connections release];
  [super dealloc];
}

- (void)getRooms
{
  [self startRequestWithMethod:@"GET" path:@"/rooms.json" streaming:NO key:@"rooms" userInfo:ROOMS];
}

- (void)getRoomInformationFor:(NSInteger)roomId
{
  NSString *path = [NSString stringWithFormat:@"/room/%d.json", roomId];
  [self startRequestWithMethod:@"GET" path:path streaming:NO key:path userInfo:ROOM_INFORMATION];
}

- (void)getInformationForUser:(NSInteger)userId
{
  NSString *path = [NSString stringWithFormat:@"/users/%d.json", userId];
  [self startRequestWithMethod:@"GET" path:path streaming:NO key:path userInfo:USER_INFORMATION];
}

- (void)joinRoom:(NSInteger)roomId
{
  NSString *path = [NSString stringWithFormat:@"/room/%d/join.xml", roomId];
  NSMutableDictionary *identifier = [[NSMutableDictionary alloc] initWithCapacity:2];
  [identifier setObject:[NSNumber numberWithInteger:roomId] forKey:@"roomId"];
  [identifier setObject:JOIN forKey:@"operation"];
  [self startRequestWithMethod:@"POST" path:path streaming:NO key:path userInfo:identifier];
}

- (void)leaveRoom:(NSInteger)roomId
{
  NSString *path = [NSString stringWithFormat:@"/room/%d/leave.xml", roomId];
  NSMutableDictionary *identifier = [[NSMutableDictionary alloc] initWithCapacity:2];
  [identifier setObject:[NSNumber numberWithInteger:roomId] forKey:@"roomId"];
  [identifier setObject:LEAVE forKey:@"operation"];
  [self startRequestWithMethod:@"POST" path:path streaming:NO key:path userInfo:identifier];
}

- (void)startListeningForMessagesInRoom:(NSInteger)roomId
{
  NSLog(@"startListeningForMessagesInRoom:%d", roomId);
  NSString *path = [NSString stringWithFormat:@"/room/%d/live.json", roomId];
  [self startRequestWithMethod:@"GET" path:path streaming:YES key:path userInfo:LISTEN];
}

- (void)stopListeningForMessagesInRoom:(NSInteger)roomId
{
  NSString *path = [NSString stringWithFormat:@"/room/%d/live.json", roomId];
  MSHTTPConnection *connection = [connections objectForKey:path];
  [connection disconnect];
  [connections removeObjectForKey:path];
}

- (void)sendTextMessage:(NSString *)message toRoom:(NSInteger)roomId {
  NSString *path = [NSString stringWithFormat:@"/room/%d/speak.json", roomId];
  
  NSMutableDictionary *messageDict = [NSMutableDictionary dictionaryWithCapacity:2];
  [messageDict setObject:@"TextMessage" forKey:@"type"];
  [messageDict setObject:message forKey:@"body"];
  NSMutableDictionary *wrapper = [NSMutableDictionary dictionaryWithCapacity:1];
  [wrapper setObject:messageDict forKey:@"message"];
  
  NSData *payload = [[wrapper JSONRepresentation] dataUsingEncoding:NSUTF8StringEncoding];
  [self startRequestWithMethod:@"POST" 
                          path:path 
                     streaming:NO
                           key:path 
                      userInfo:SPEAK
                       payload:payload];
}

- (void)startRequestWithMethod:(NSString *)method
                          path:(NSString *)path
                     streaming:(BOOL)streaming
                           key:(NSString *)key
                      userInfo:(id)info
{
  [self startRequestWithMethod:method path:path streaming:streaming key:key userInfo:info payload:nil];
}

- (void)startRequestWithMethod:(NSString *)method
                          path:(NSString *)path
                     streaming:(BOOL)streaming
                           key:(NSString *)key
                      userInfo:(id)info
                       payload:(NSData *)payload
{
  // Construct appropriate URL string.
  NSString *urlString = [NSString stringWithFormat:@"%@://%@%@",
                         _secureConnection ? @"https" : @"http", 
                         streaming ? @"streaming.campfirenow.com" : _APIDomain,
                         path];
  NSURL *finalURL = [NSURL URLWithString:urlString];
  if (!finalURL) {
    return;
  }
  
  // Contruct the connection
  MSHTTPConnection *connection = [[MSHTTPConnection alloc] initWithURL:finalURL
                                                                method:method
                                                              delegate:self
                                                            identifier:info];
  
  [connection setUser:_key password:@"X"];
  
  [connection setPayload:payload];
  [connections setValue:connection forKey:key];
  [connection connect];
  [connection release];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark MSHTTPConnection Delegate Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)connection:(MSHTTPConnection *)connection didReceiveBody:(NSString *)body
{
  NSLog(@"connection:%@ didReceiveBody:%@", [connection identifier], body);
  if ([[connection identifier] isEqualTo:ROOMS]) {
    if ([delegate respondsToSelector:@selector(didReceiveRooms:)]) {
      NSDictionary *d = [body JSONValue];
      [delegate didReceiveRooms:d];
    }
    NSLog(@"rooms = %@", body);
  } else if ([[connection identifier] isEqualTo:ROOM_INFORMATION]) {
    if ([delegate respondsToSelector:@selector(didReceiveRoomInformation:)]) {
      NSDictionary *d = [body JSONValue];
      [delegate didReceiveRoomInformation:d];
    }
    NSLog(@"room information = %@", body);
  } else if ([[connection identifier] isEqualTo:USER_INFORMATION]) {
    if ([delegate respondsToSelector:@selector(didReceiveInformationForUser:)]) {
      NSDictionary *d = [body JSONValue];
      [delegate didReceiveInformationForUser:d];
    }
  }
  
  else if ([[connection identifier] respondsToSelector:@selector(objectForKey:)]) {
    NSMutableDictionary *d = [connection identifier];
    NSLog(@"Tutaj! %@", d);
    if ([[d objectForKey:@"operation"] isEqualTo:JOIN]) {
      NSNumber *roomId = [d objectForKey:@"roomId"];
      [self startListeningForMessagesInRoom:[roomId integerValue]];
    } else if ([[d objectForKey:@"operation"] isEqualTo:LEAVE]) {
      NSNumber *roomId = [d objectForKey:@"roomId"];
      [self stopListeningForMessagesInRoom:[roomId integerValue]];
    }
  }
}

- (void)connection:(MSHTTPConnection *)connection didReceiveLine:(NSString *)line {
  if ([line hasPrefix:@"{"]) {
    NSDictionary *d = [line JSONValue];
    if ([delegate respondsToSelector:@selector(didReceiveMessage:)]) {
      [delegate didReceiveMessage:d];
    }
  }
}

@end
