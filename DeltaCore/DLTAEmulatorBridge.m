//
//  DLTAEmulatorBridge.m
//  DeltaCore
//
//  Created by Riley Testut on 6/9/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

#import "DLTAEmulatorBridge.h"

#import <DeltaCore/DeltaCore-Swift.h>

@interface DLTAEmulatorBridge ()

@property (copy, nonatomic, nullable, readwrite) NSURL *gameURL;

@end

@implementation DLTAEmulatorBridge

+ (instancetype)sharedBridge
{
    static DLTAEmulatorBridge *_emulatorBridge = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _emulatorBridge = [[self alloc] init];
    });
    
    return _emulatorBridge;
}

#pragma mark - Emulation State -

- (void)startWithGameURL:(NSURL *)gameURL
{
    self.gameURL = gameURL;
}

- (void)stop
{
    
}

- (void)pause
{
    
}

- (void)resume
{
    
}

#pragma mark - Game Loop -

- (void)runFrame
{
    [NSException raise:@"Invoked Abstract Method" format:@"-[DLTAEmulatorBridge runFrame] must be implemented by subclasses."];
}


@end
