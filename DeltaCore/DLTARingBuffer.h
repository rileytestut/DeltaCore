//
//  DLTARingBuffer.h
//  DeltaCore
//
//  Created by Riley Testut on 1/12/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DLTARingBuffer : NSObject

@property (assign, nonatomic, getter=isEnabled) BOOL enabled;

@property (assign, nonatomic, readonly) int32_t availableBytesForWriting;
@property (assign, nonatomic, readonly) int32_t availableBytesForReading;

// Initialize with preferred buffer size (in bytes)
- (instancetype)initWithPreferredBufferSize:(int32_t)bufferSize;

// Handler returns number of bytes written
- (void)writeWithHandler:(int32_t (^)(void *ringBuffer, int32_t availableBytes))writingHandler;

// Copies `size` bytes from ring buffer to provided buffer if available. Otherwise, copies as many as possible.
- (void)readIntoBuffer:(void *)buffer preferredSize:(int32_t)size NS_SWIFT_NAME(DLTARingBuffer.read(into:preferredSize:));

// Resets buffer to clean state
- (void)reset;

@end

NS_ASSUME_NONNULL_END
