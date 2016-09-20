//
//  RingBuffer.swift
//  DeltaCore
//
//  Created by Riley Testut on 6/29/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation
import TPCircularBuffer

@objc(DLTARingBuffer)
public class RingBuffer: NSObject
{
    public var isEnabled: Bool = true
    
    public var availableBytesForWriting: Int {
        return Int(self.circularBuffer.length - self.circularBuffer.fillCount)
    }
    
    public var availableBytesForReading: Int {
        return Int(self.circularBuffer.fillCount)
    }
    
    fileprivate var circularBuffer = TPCircularBuffer()
    
    /// Initialize with `preferredBufferSize` bytes.
    public init?(preferredBufferSize: Int)
    {
        // 32 = size of C TPCircularBuffer struct
        if !_TPCircularBufferInit(&self.circularBuffer, Int32(preferredBufferSize), 32)
        {
            return nil
        }
    }
    
    deinit
    {
        TPCircularBufferCleanup(&self.circularBuffer)
    }
}

public extension RingBuffer
{
    /// Writes `size` bytes from `buffer` to ring buffer if possible. Otherwise, writes as many as possible.
    @objc(writeBuffer:size:)
    func write(_ buffer: UnsafePointer<UInt8>, size: Int)
    {
        guard self.isEnabled else { return }
        
        let size = min(size, self.availableBytesForWriting)
        TPCircularBufferProduceBytes(&self.circularBuffer, buffer, Int32(size))
    }
    
    /// Copies `size` bytes from ring buffer to `buffer` if possible. Otherwise, copies as many as possible.
    @objc(readIntoBuffer:preferredSize:)
    func read(into buffer: UnsafeMutablePointer<UInt8>, preferredSize: Int)
    {
        var availableBytes: Int32 = 0
        guard let ringBuffer = TPCircularBufferTail(&self.circularBuffer, &availableBytes) else { return }
        
        let size = min(preferredSize, Int(availableBytes))
        
        if self.isEnabled
        {
            memcpy(buffer, ringBuffer, size)
        }
        
        TPCircularBufferConsume(&self.circularBuffer, Int32(size))
    }
    
    /// Resets buffer to clean state.
    func reset()
    {
        TPCircularBufferClear(&self.circularBuffer)
    }
}
