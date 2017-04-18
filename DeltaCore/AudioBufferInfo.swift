//
//  AudioBufferInfo.swift
//  DeltaCore
//
//  Created by Riley Testut on 4/18/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import AVFoundation

public struct AudioBufferInfo
{
    public let format: AVAudioFormat
    public let frameCapacity: AVAudioFrameCount
    
    public var size: Int {
        return self.frameSize * Int(self.frameCapacity)
    }
    
    public var frameSize: Int {
        return Int(self.format.streamDescription.pointee.mBytesPerFrame)
    }
    
    public init(format: AVAudioFormat, frameCapacity: AVAudioFrameCount)
    {
        self.format = format
        self.frameCapacity = frameCapacity
    }
}
