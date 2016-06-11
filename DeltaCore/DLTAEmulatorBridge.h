//
//  DLTAEmulatorBridge.h
//  DeltaCore
//
//  Created by Riley Testut on 6/9/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol DLTAEmulating;
@protocol DLTAAudioRendering;
@protocol DLTAVideoRendering;

NS_ASSUME_NONNULL_BEGIN

@interface DLTAEmulatorBridge : NSObject

// State
@property (copy, nonatomic, nullable, readonly) NSURL *gameURL;

// Core
@property (weak, nonatomic, nullable) id<DLTAEmulating> emulatorCore;

// Audio
@property (weak, nonatomic, nullable) id<DLTAAudioRendering> audioRenderer;

// Video
@property (weak, nonatomic, nullable) id<DLTAVideoRendering> videoRenderer;

+ (instancetype)sharedBridge;

// Emulation State
- (void)startWithGameURL:(NSURL *)gameURL NS_REQUIRES_SUPER;
- (void)stop;
- (void)pause;
- (void)resume;

// Game Loop
- (void)runFrame;

// Inputs
- (void)activateInput:(NSInteger)gameInput;
- (void)deactivateInput:(NSInteger)gameInput;

// Save States
- (void)saveSaveStateToURL:(NSURL *)URL;
- (void)loadSaveStateFromURL:(NSURL *)URL;

// Game Saves
- (void)saveGameSaveToURL:(NSURL *)URL;
- (void)loadGameSaveFromURL:(NSURL *)URL;

// Cheats
- (BOOL)addCheatCode:(NSString *)cheatCode type:(NSInteger)type;
- (void)resetCheats;
- (void)updateCheats;


@end

NS_ASSUME_NONNULL_END