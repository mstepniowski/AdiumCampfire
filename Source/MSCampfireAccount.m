//
//  MSTCampfireAccount.m
//  AdiumCampfire
//
//  Created by Marek Stępniowski on 10-03-10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import "MSCampfireAccount.h"
#import "MSCampfireRoom.h"
#import "NSString+SBJSON.h"
#import <Adium/ESDebugAILog.h>
#import <Adium/AIListBookmark.h>
#import <Adium/AIChat.h>
#import <AIUtilities/AIApplicationAdditions.h>
#import <Adium/AIChatControllerProtocol.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIStatusControllerProtocol.h>
#import <Adium/AIInterfaceControllerProtocol.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIContactObserverManager.h>
#import <Adium/AISharedAdium.h>
#import <Adium/AIContentMessage.h>


@implementation MSCampfireAccount

- (void)initAccount
{
	[super initAccount];
  
  engine = nil;
  _rooms = [[NSMutableDictionary alloc] init];
  lastRoomsUpdate = nil;
  updatedRoomsCount = 0;
  authenticatedUserId = -1;
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(chatDidOpen:)
                                               name:Chat_DidOpen
                                             object:nil];
  
  if (!self.host && self.defaultServer) {
    [self setPreference:self.defaultServer forKey:KEY_CONNECT_HOST group:GROUP_ACCOUNT_STATUS];
	}
  AILogWithSignature(@"%@", self.UID);
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [engine release];
  
  [super dealloc];
}

- (NSString *)defaultServer
{
  return @"setjam.campfirenow.com";
}

- (void)connect
{
  AILogWithSignature(@"%@ connecting to Campfire with pass %@", self, self.passwordWhileConnected);
	[super connect];
    
  [self setConnectionProgress:[NSNumber numberWithDouble:0.3] message:@"Connecting"];
  [engine release]; engine = nil;
  engine = [[MSCampfireEngine alloc] initWithDomain:self.UID key:self.passwordWhileConnected delegate:self];
  
  [engine getInformationForAuthenticatedUser];
  [engine getRooms];
}

- (void)disconnect
{
  [super disconnect];
  [lastRoomsUpdate release]; lastRoomsUpdate = nil;
  [engine release]; engine = nil;
  
  [self didDisconnect];
}

#pragma mark AIAccount methods
- (BOOL)maySendMessageToInvisibleContact:(AIListContact *)inContact
{
	return NO;
}

- (BOOL)openChat:(AIChat *)chat
{	
  chat.hideUserIconAndStatus = YES;
  // That fucker is setting status to "Active"!
  [chat setValue:[NSNumber numberWithBool:YES] forProperty:@"Account Joined" notify:NotifyNow];
  
	return [chat isGroupChat];
}

- (BOOL)groupChatsSupportTopic {
  return YES;
}

- (void)setTopic:(NSString *)topic forChat:(AIChat *)chat
{
  NSLog(@"setTopic:%@ forChat:%@", topic, chat);
}

/*!
 * @brief A chat opened.
 *
 * If this is a group chat which belongs to us, aka a timeline chat, set it up how we want it.
 */
- (void)chatDidOpen:(NSNotification *)notification
{
	AIChat *chat = [notification object];
  AILogWithSignature(@"chatDidOpen: %@", chat);
	if(chat.isGroupChat && chat.account == self) {
		[self updateCampfireChat:chat];
	}
}

/*!
 * @brief Chat for a room 
 *
 * If the room chat is not already active, it is created.
 */
- (AIChat *)chatWithName:(NSString *)name
{
	AIChat *chat = [adium.chatController existingChatWithName:name onAccount:self];
  if (!chat) {
      chat = [adium.chatController chatWithName:name
                                     identifier:nil
                                      onAccount:self
                               chatCreationInfo:nil];
  }
  return chat;
}

/*!
 * @brief Update the room chat
 * 
 * Remove the userlist
 */
- (void)updateCampfireChat:(AIChat *)campfireChat
{
  AILogWithSignature(@"%@", campfireChat);
  
	// Enable the user list on the chat.
	if (!campfireChat.chatContainer.chatViewController.userListVisible) {
		[campfireChat.chatContainer.chatViewController toggleUserList]; 
	}	
	
	// Update the participant list.
//  AIListContact *contact = [self contactWithUID:@"alamakota"];
//  if (!contact) {
//    contact = [[AIListContact alloc] initWithUID:@"alamakota" service:[self service]];
//    [self addContact:contact toGroup:nil];
//  }
  
  AILogWithSignature(@"Setting topic for chat %@", campfireChat);
  [campfireChat setTopic:@"Ala ma kota!"];

  MSCampfireRoom *room = [_rooms objectForKey:[campfireChat name]];
  for (NSNumber *uid in [room contactUIDs]) {
    [campfireChat addParticipatingListObject:[self contactWithUID:[uid stringValue]] notify:NotifyNow];
  }
}

- (BOOL)sendMessageObject:(AIContentMessage *)inContentMessage
{
  NSString *roomName = inContentMessage.chat.name;
  [engine sendTextMessage:inContentMessage.encodedMessage toRoom:[roomName integerValue]];
  // inContentMessage.displayContent = NO;

  return YES;
}

- (void)setConnectionProgress:(NSNumber *)progress message:(NSString *)message
{
	[self setValue:message forProperty:@"ConnectionProgressString" notify:NO];
	[self setValue:progress forProperty:@"ConnectionProgressPercent" notify:NO];	
	[self notifyOfChangedPropertiesSilently:NO];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark MSCampfireEngine delegate methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)didReceiveRooms:(NSDictionary *)rooms {
  if (YES) {
    // Dump data as string for debugging.
    AILogWithSignature(@"%@ JSON value: %@", self, rooms);
  }
  
  if (rooms) {
    updatedRoomsCount = 0;
    
    NSArray *roomArray = [rooms objectForKey:@"rooms"];
    
    [_rooms release];
    _rooms = [[NSMutableDictionary alloc] init];
    
    for (NSDictionary *roomDictionary in roomArray) {
      NSNumber *roomId = [roomDictionary objectForKey:@"id"];
      MSCampfireRoom *newRoom = [[MSCampfireRoom alloc] initWithUID:[roomId integerValue]];
      [_rooms setObject:newRoom forKey:[roomId stringValue]];
      [engine getRoomInformationFor:[roomId integerValue]];
      [newRoom release];
    }
  } else {
    [self disconnect];
  }
}

- (void)didReceiveRoomInformation:(NSDictionary *)roomDict
{ 
  NSDictionary *room = [roomDict objectForKey:@"room"];
  AILogWithSignature(@"Received information for room: %@", room);
  NSNumber *roomId = [room objectForKey:@"id"];
  AIListBookmark *roomBookmark = [adium.contactController existingBookmarkForChatName:[roomId stringValue]
                                                                            onAccount:self
                                                                     chatCreationInfo:nil];
  AILogWithSignature(@"Existing bookmark for %@: %@", [roomId stringValue], roomBookmark);
  if (roomBookmark) {
    [adium.contactController removeBookmark:roomBookmark];
    roomBookmark = nil;    
  }

  MSCampfireRoom *roomR = [_rooms objectForKey:[roomId stringValue]];
  NSArray *users = [room objectForKey:@"users"];
  for (NSDictionary *userDict in users) {
    NSNumber *contactId = [userDict objectForKey:@"id"];
    AIListContact *contact = [[AIListContact alloc] initWithUID:[contactId stringValue]
                                                        account:self
                                                        service:[self service]];
    [contact setDisplayName:[userDict objectForKey:@"name"]];
    [self addContact:contact toGroup:nil];
    [roomR addContactWithUID:[contactId integerValue]];
    
    NSLog(@"Added contact: %@", contact);
    [contact release];
  }
  
  if (!roomBookmark) {
    AILog(@"Creating new room bookmark!");
    AIChat *existingChat = [adium.chatController existingChatWithName:[roomId stringValue] onAccount:self];
    if (existingChat) {
      AILogWithSignature(@"There is already a room for %@", [roomId stringValue]);
    }
    
    AIChat *newRoomChat = [adium.chatController chatWithName:[roomId stringValue]
                                                  identifier:nil
                                                   onAccount:self
                                            chatCreationInfo:nil];
    
    [newRoomChat setDisplayName:[room objectForKey:@"name"]];
      
    roomBookmark = [adium.contactController bookmarkForChat:newRoomChat inGroup:[adium.contactController groupWithUID:@"Campfire"]];
    
    if(!roomBookmark) {
			AILog(@"%@ Room bookmark is nil! Tried checking for existing bookmark for chat name %@, and creating a bookmark for chat %@ in group %@", [roomId stringValue], newRoomChat, [adium.contactController groupWithUID:@"Campfire"]);
		}
  }
  [engine joinRoom:[roomId integerValue]];
  
  updatedRoomsCount += 1;
  if (!lastRoomsUpdate) {
    [self setConnectionProgress:[NSNumber numberWithDouble:(0.3 + (updatedRoomsCount / [_rooms count]) * 0.7)]
                        message:[NSString stringWithFormat:@"Getting info for room %d/%d", updatedRoomsCount, [_rooms count]]];
    if (updatedRoomsCount >= [_rooms count]) {
      lastRoomsUpdate = [[NSDate alloc] init];
      [self didConnect];
    }
  }
}

- (void)didReceiveMessage:(NSDictionary *)message
{
  NSNumber *roomId = [message objectForKey:@"room_id"];
  AIChat *chat = [self chatWithName:[roomId stringValue]];
  
  NSAttributedString *msg = [[NSAttributedString alloc] initWithString:[message objectForKey:@"body"]];
  
  AILogWithSignature(@"message = %@", message);
  
  if (!chat) {
    AILogWithSignature(@"chat with id %@ not found!", [message objectForKey:@"room_id"]);
    return;
  }
  
  NSString *messageType = [message objectForKey:@"type"];
  if ([messageType isEqualTo:@"TextMessage"] || [messageType isEqualTo:@"PasteMessage"]) {
    NSNumber *contactId = [message objectForKey:@"user_id"];
    AILogWithSignature(@"My ID=%d, Sender ID=%@", authenticatedUserId, contactId);
    if( authenticatedUserId != [contactId integerValue] ) {
      AIContentMessage *contentMessage = [AIContentMessage messageInChat:chat
                                                              withSource:[self contactWithUID:[contactId stringValue]]
                                                             destination:self
                                                                    date:[NSDate date]
                                                                 message:msg
                                                               autoreply:NO];
      
      [adium.contentController receiveContentObject:contentMessage];    
    }
  } else if ([messageType isEqualTo:@"EnterMessage"]) {
    NSNumber *contactId = [message objectForKey:@"user_id"];
    [[_rooms objectForKey:roomId] addContactWithUID:[contactId integerValue]];
    [chat addParticipatingListObject:[self contactWithUID:[contactId stringValue]] notify:NotifyNow];
  } else if ([messageType isEqualTo:@"UploadMessage"]) {
    // If this is an upload message, ask the engine to get the upload details
    NSNumber *uploadId = [message objectForKey:@"id"];
    NSNumber *roomId = [message objectForKey:@"room_id"];
    [engine getUploadForId:[uploadId integerValue] inRoom:[roomId integerValue]];
  } else {
    NSLog(@"message = %@", message);
  } 
}

- (void)didReceiveInformationForAuthenticatedUser:(NSDictionary *)user
{
  NSString *authenticatedUserIdAsString = [[user objectForKey:@"user"] objectForKey:@"id"];
  authenticatedUserId = [authenticatedUserIdAsString integerValue];
  AILogWithSignature(@"Authenticated User ID = %d", authenticatedUserId);
}

- (void)didReceiveUpload:(NSDictionary *)upload
{
  NSDictionary *data = [upload objectForKey:@"upload"];
  NSNumber *contactId = [data objectForKey:@"user_id"];
  NSAttributedString *msg = [[NSAttributedString alloc] initWithString:[data objectForKey:@"full_url"]];
  NSNumber *roomId = [data objectForKey:@"room_id"];
  AIChat *chat = [self chatWithName:[roomId stringValue]];
  
  AIContentMessage *contentMessage = [AIContentMessage messageInChat:chat
                                                          withSource:[self contactWithUID:[contactId stringValue]]
                                                         destination:self
                                                                date:[NSDate date]
                                                             message:msg
                                                           autoreply:NO];
  
  [adium.contentController receiveContentObject:contentMessage]; 
}


@end
