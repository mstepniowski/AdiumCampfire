//
//  MSTAsyncHTTP.m
//  AdiumCampfire
//
//  Created by Marek Stępniowski on 10-03-11.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import "MSHTTPConnection.h"
#import "DDAsyncSocket.h"
#import "JSON.h"
#import "NSNumber+Conversion.h"
#import "NSData+Base64.h"


// Define the various timeouts (in seconds) for various parts of the HTTP process
#define READ_TIMEOUT          -1
#define WRITE_HEAD_TIMEOUT    30

// Define the various limits
// LIMIT_MAX_HEADER_LINE_LENGTH: Max length (in bytes) of any single line in a header (including \r\n)
// LIMIT_MAX_HEADER_LINES      : Max number of lines in a single header (including first GET line)
#define LIMIT_MAX_HEADER_LINE_LENGTH  8190
#define LIMIT_MAX_HEADER_LINES         100

// Define the various tags we'll use to differentiate what it is we're currently doing
#define HTTP_RESPONSE_HEADER    10
#define HTTP_RESPONSE_BODY      20
#define HTTP_RESPONSE_BODY_LINE 30


@implementation MSHTTPConnection

@synthesize identifier;
@synthesize payload;

- (MSHTTPConnection *)initWithURL:(NSURL *)aURL
                           method:(NSString*)aMethod
                         delegate:(NSObject *)aDelegate
{  
  secure = NO;
  if ([[aURL scheme] isEqualTo:@"https"]) {
    secure = YES;
  } else if (![[aURL scheme] isEqualTo:@"http"]) {
    @throw [NSException exceptionWithName:@"Bad URL scheme. Should be http or https" reason:@"Whatever" userInfo:nil];
  }
  
  if ([url port]) {
    port = [[url port] integerValue];
  } else {
    port = secure ? 443 : 80;
  }
  
  if ((self = [super init])) {
    url = [aURL retain];
    method = [aMethod retain];
    delegate = aDelegate; // deliberate weak reference
    user = nil;
    password = nil;
    
    socket = [[DDAsyncSocket alloc] initWithDelegate:self];
    response = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, NO);
    numHeaderLines = 0;
    
    payload = nil;
  }
  return self;
}

- (MSHTTPConnection *)initWithURL:(NSURL *)aURL 
                           method:(NSString *)aMethod 
                         delegate:(NSObject *)aDelegate 
                       identifier:(id)anIdentifier
{
  if ((self = [self initWithURL:aURL method:aMethod delegate:aDelegate])) {
    [self setIdentifier:anIdentifier];
  }
  return self;
}

- (void)dealloc
{
  [self disconnect];
  
  [url release];
  [method release];
  delegate = nil;
  
  [socket release];
  if(response) {
    CFRelease(response);
  } 
  [self setIdentifier:nil];
  
  [super dealloc];
}

- (void)setUser:(NSString *)aUser password:(NSString *)aPassword {
  [user release];
  [password release];
  user = [aUser retain];
  password = [aPassword retain];
}

- (void)connect
{
  NSError *err = nil;
	if(![socket connectToHost:[url host] onPort:port error:&err])
	{
		NSLog(@"Error: %@", err);
	}
}

- (void)disconnect
{
  if ([socket isConnected]) {
    [socket disconnect];
  }
}

- (NSString *)userAgent
{
  return @"CampfireStream";
}

- (void)sendHeaders
{
  NSString *headers = [NSString stringWithFormat:@""
    "%@ %@ HTTP/1.1\r\n"
    "Host: %@\r\n"
    "User-Agent: %@\r\n", 
    method, [url path], [url host], [self userAgent], nil];
  
  if (user) {
    headers = [headers stringByAppendingFormat:@"Authorization: Basic %@\r\n",
               [self base64EncodedCredentials], nil];
  }
  
  if (payload) {
    headers = [headers stringByAppendingString:[NSString stringWithFormat:@""
      "Content-Type: application/json\r\n"
      "Content-Length: %d\r\n",
      [payload length]]];
  }
  headers = [headers stringByAppendingString:@"\r\n"];
  
  NSLog(@"headers = %@", headers);
  
  NSMutableData *data = [NSMutableData data];
  [data appendData:[headers dataUsingEncoding:NSUTF8StringEncoding]];
  if (payload) {
    [data appendData:payload];
  }
  
  [socket writeData:data withTimeout:-1 tag:20];
  [socket readDataToData:[DDAsyncSocket CRLFData]
             withTimeout:READ_TIMEOUT
               maxLength:LIMIT_MAX_HEADER_LINE_LENGTH
                     tag:HTTP_RESPONSE_HEADER];
}

- (NSString *)base64EncodedCredentials {
  NSString *credentials = [NSString stringWithFormat:@"%@:%@", user, password, nil];
  NSData *credentialsData = [credentials dataUsingEncoding:NSUTF8StringEncoding];
  return [credentialsData base64EncodingWithLineLength:0];
}

- (void)handleInvalidResponse:(NSData *)what {
  NSString *s = [[[NSString alloc] initWithBytes:[what bytes]
                                          length:[what length]
                                        encoding: NSUTF8StringEncoding] autorelease];
  s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];  
  NSLog(@"Socket:%p received invalid response:%@", socket, s);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark AsyncSocket Delegate Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)onSocket:(DDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
  if (secure) {
    NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithCapacity:1];
    [settings setObject:[url host] forKey:(NSString *)kCFStreamSSLPeerName];    
    [sock startTLS:settings];
  } else {
    [self sendHeaders];
  }
  
}

- (void)onSocketDidSecure:(DDAsyncSocket *)sock
{
  [self sendHeaders];
}

- (void)onSocket:(DDAsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
  NSLog(@"onSocket:%p willDisconnectWithError:%@", sock, err);
  NSString *s = [NSString stringWithUTF8String:[[sock unreadData] bytes]];
  NSLog(@"unreadData: %@", s);
}

- (void)onSocketDidDisconnect:(DDAsyncSocket *)sock
{
  NSLog(@"onSocketDidDisconnect:%p", sock);
}

- (void)onSocket:(DDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
//	NSLog(@"onSocket:%p didWriteDataWithTag:%d", sock, tag);  
//  [socket readDataToLength:40 withTimeout:30 tag:10];
}

- (void)onSocket:(DDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
  if (tag == HTTP_RESPONSE_HEADER) {
		// Append the header line to the http message
		BOOL result = CFHTTPMessageAppendBytes(response, [data bytes], [data length]);
		if(!result)
		{
			// We have a received a malformed request
			[self handleInvalidResponse:data];
		}
		else if(!CFHTTPMessageIsHeaderComplete(response))
		{
			// We don't have a complete header yet
			// That is, we haven't yet received a CRLF on a line by itself, indicating the end of the header
			if(++numHeaderLines > LIMIT_MAX_HEADER_LINES)
			{
				// Reached the maximum amount of header lines in a single HTTP request
				// This could be an attempted DOS attack
				[socket disconnect];
				
				// Explictly return to ensure we don't do anything after the socket disconnect
				return;
			}
			else
			{
				[socket readDataToData:[DDAsyncSocket CRLFData]
                   withTimeout:READ_TIMEOUT
                     maxLength:LIMIT_MAX_HEADER_LINE_LENGTH
                           tag:HTTP_RESPONSE_HEADER];
			}
		} else {
			// We have an entire HTTP request header from the client
			
			// Extract the response status
			NSString *status = [NSMakeCollectable(CFHTTPMessageCopyResponseStatusLine(response)) autorelease];
      if (![[status substringToIndex:1] isEqualTo:@"2"]) {
        NSLog(@"Wrong status: %@ for %@", status, identifier);
      }
      
			// Check for a Content-Length field
			NSString *contentLength = 
        [NSMakeCollectable(CFHTTPMessageCopyHeaderFieldValue(response, CFSTR("Content-Length"))) autorelease];
			
      if (contentLength != nil) {
        UInt64 responseContentLength;
        if(![NSNumber parseString:(NSString *)contentLength intoUInt64:&responseContentLength]) {
          // Unable to parse Content-Length header into a valid number
          [self handleInvalidResponse:nil];
          return;
        }
        if (responseContentLength == 0) {
          [socket disconnect];
          return;
        }
        [socket readDataToLength:responseContentLength withTimeout:READ_TIMEOUT tag:HTTP_RESPONSE_BODY];
      } else {
        // Streaming response
        [socket readDataToData:[DDAsyncSocket CRData] withTimeout:READ_TIMEOUT tag:HTTP_RESPONSE_BODY_LINE];
      }
    }
  } else if (tag == HTTP_RESPONSE_BODY) {
    NSString *s = [[[NSString alloc] initWithBytes:[data bytes]
                                            length:[data length]
                                          encoding: NSUTF8StringEncoding] autorelease];
    s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];  
    NSLog(@"onConnection:%p didReceiveBody:%@", self, s);    
    if ([delegate respondsToSelector:@selector(connection:didReceiveBody:)]) {
      [delegate connection:self didReceiveBody:s];
    }
    [socket disconnect];
    return;
  } else if (tag == HTTP_RESPONSE_BODY_LINE) {
    NSString *s = [[[NSString alloc] initWithBytes:[data bytes]
                                            length:[data length]
                                          encoding: NSUTF8StringEncoding] autorelease];
    s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];  
    
   // NSLog(@"onConnection:%p didReceiveLine:%@", self, s);
    if ([delegate respondsToSelector:@selector(connection:didReceiveLine:)]) {
      //NSLog(@"Tutaj! %@", s);
      [delegate connection:self didReceiveLine:s];
    }
    
    [socket readDataToData:[DDAsyncSocket CRData] withTimeout:-1 tag:HTTP_RESPONSE_BODY_LINE];
  } else {
//    NSLog(@"Unknown tag!");
    [socket disconnect];
  }
}



@end
