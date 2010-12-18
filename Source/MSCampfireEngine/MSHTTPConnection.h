//
//  MSTAsyncHTTP.h
//  AdiumCampfire
//
//  Created by Marek Stępniowski on 10-03-11.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


@class DDAsyncSocket;
@class MSHTTPConnection;


@protocol MSHTTPConnectionDelegate

- (void)connection:(MSHTTPConnection *)connection didReceiveBody:(NSString *)body;
- (void)connection:(MSHTTPConnection *)connection didReceiveLine:(NSString *)line;

@end


@interface MSHTTPConnection : NSObject {
  NSURL *url;
  NSString *method;
  NSObject <MSHTTPConnectionDelegate> *delegate;
  NSString *user;
  NSString *password;
  
  NSInteger port;
  BOOL secure;
  DDAsyncSocket *socket;
  CFHTTPMessageRef response;
  int numHeaderLines;
  id identifier;
  
  NSData *payload; // request data
}

@property (retain,nonatomic) id identifier;
@property (retain,nonatomic) NSData *payload;

- (MSHTTPConnection *)initWithURL:(NSURL *)aURL 
                           method:(NSString *)aMethod 
                         delegate:(NSObject *)aDelegate;

- (MSHTTPConnection *)initWithURL:(NSURL *)aURL 
                           method:(NSString *)aMethod 
                         delegate:(NSObject *)aDelegate
                       identifier:(id)anIdentifier;

- (void)connect;
- (void)disconnect;
- (void)sendHeaders;
- (void)handleInvalidResponse:(NSData *)what;
- (void)setUser:(NSString *)aUser password:(NSString *)aPassword;
- (NSString *)base64EncodedCredentials;
@end

