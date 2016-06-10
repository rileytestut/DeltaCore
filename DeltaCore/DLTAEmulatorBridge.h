//
//  DLTAEmulatorBridge.h
//  DeltaCore
//
//  Created by Riley Testut on 6/9/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol DLTAAudioRendering;
@protocol DLTAVideoRendering;

NS_ASSUME_NONNULL_BEGIN

@interface DLTAEmulatorBridge : NSObject

// State
@property (copy, nonatomic, nullable, readonly) NSURL *gameURL;

// Audio
@property (weak, nonatomic, nullable) id<DLTAAudioRendering> audioRenderer;

// Video
@property (weak, nonatomic, nullable) id<DLTAVideoRendering> videoRenderer;

+ (instancetype)sharedBridge;

// Emulation State
- (void)startWithGameURL:(NSURL *)gameURL;
- (void)stop;
- (void)pause;
- (void)resume;

// Game Loop
- (void)runFrame;

// Save States
- (void)saveSaveStateToURL:(NSURL *)URL;
- (void)loadSaveStateFromURL:(NSURL *)URL;

@end

NS_ASSUME_NONNULL_END