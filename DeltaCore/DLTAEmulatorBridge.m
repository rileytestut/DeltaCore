//
//  DLTAEmulatorBridge.m
//  DeltaCore
//
//  Created by Riley Testut on 6/9/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

#import "DLTAEmulatorBridge.h"

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

#pragma mark - Inputs -

- (void)activateInput:(NSInteger)gameInput
{
    [NSException raise:@"Invoked Abstract Method" format:@"-[DLTAEmulatorBridge activateInput:] must be implemented by subclasses."];
}

- (void)deactivateInput:(NSInteger)gameInput
{
    [NSException raise:@"Invoked Abstract Method" format:@"-[DLTAEmulatorBridge deactivateInput:] must be implemented by subclasses."];
}

#pragma mark - Save States -

- (void)saveSaveStateToURL:(NSURL *)URL
{
    [NSException raise:@"Invoked Abstract Method" format:@"-[DLTAEmulatorBridge saveSaveStateToURL:] must be implemented by subclasses."];
}

- (void)loadSaveStateFromURL:(NSURL *)URL
{
    [NSException raise:@"Invoked Abstract Method" format:@"-[DLTAEmulatorBridge loadSaveStateFromURL:] must be implemented by subclasses."];
}

#pragma mark - Cheats -

- (BOOL)addCheatCode:(NSString *)cheatCode type:(NSInteger)type
{
    @throw [NSException exceptionWithName:@"Invoked Abstract Method" reason:@"-[DLTAEmulatorBridge addCheatCode:type:] must be implemented by subclasses." userInfo:nil];
}

- (void)resetCheats
{
    [NSException raise:@"Invoked Abstract Method" format:@"-[DLTAEmulatorBridge resetCheats] must be implemented by subclasses."];
}

- (void)updateCheats
{
    // Optionally implemented by subclasses
}

@end
