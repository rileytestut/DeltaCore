//
//  DLTARingBuffer.m
//  DeltaCore
//
//  Created by Riley Testut on 1/12/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

#import "DLTARingBuffer.h"
#import "TPCircularBuffer.h"

@import Roxas;

@interface DLTARingBuffer ()

@property (assign, nonatomic, readonly) TPCircularBuffer circularBuffer;

@end

@implementation DLTARingBuffer

- (instancetype)initWithPreferredBufferSize:(int32_t)bufferSize
{
    self = [super init];
    if (self)
    {
        if (!TPCircularBufferInit(&_circularBuffer, bufferSize))
        {
            ALog(@"Error: Failed to initialize DLTARingBuffer with preferred buffer size of %@", @(bufferSize));
        }
    }
    
    return self;
}

- (void)dealloc
{
    TPCircularBufferCleanup(&_circularBuffer);
}

- (void)writeToRingBuffer:(int32_t (^)(void *ringBuffer, int32_t availableBytes))writingHandler
{
    int32_t availableBytes = 0;
    void *buffer = TPCircularBufferHead(&_circularBuffer, &availableBytes);
    
    int32_t writtenBytes = writingHandler(buffer, availableBytes);
    
    TPCircularBufferProduce(&_circularBuffer, writtenBytes);
}

- (void)readIntoBuffer:(void *)buffer preferredSize:(int32_t)size
{
    int32_t availableBytes;
    void *ringBuffer = TPCircularBufferTail(&_circularBuffer, &availableBytes);
    
    size = MIN(size, availableBytes);
    memcpy(buffer, ringBuffer, size);
    
    TPCircularBufferConsume(&_circularBuffer, size);
}

#pragma mark - Getters/Setters -

- (int32_t)availableBytesForWriting
{
    return self.circularBuffer.length - self.circularBuffer.fillCount;
}

- (int32_t)availableBytesForReading
{
    return self.circularBuffer.fillCount;
}

@end
