//
//  AdiumCampfirePlugin.m
//  AdiumCampfire
//
//  Created by Marek Stępniowski on 10-03-10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import "MSAdiumCampfirePlugin.h"
#import "MSCampfireService.h"
#import <Adium/ESDebugAILog.h>


@implementation MSAdiumCampfirePlugin

- (void)installPlugin
{
  [MSCampfireService registerService];
}

@end
