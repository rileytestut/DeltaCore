//
//  AudioManager.swift
//  DeltaCore
//
//  Created by Riley Testut on 1/12/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import AVFoundation

private let AudioBufferCount = 3

public class AudioManager
{
    public let preferredBufferSize: Int
    
    public var paused = false {
        didSet {
            
            if self.paused
            {
                self.audioEngine.pause()
            }
            else
            {
                do
                {
                    try self.audioEngine.start()
                }
                catch let error as NSError
                {
                    print(error, error.userInfo)
                }
            }
        }
    }
    
    public var rate: Float = 1.0 {
        didSet {
            self.timePitchEffect.rate = Float(self.rate)
            self.updateAudioBufferFrameLengths()
        }
    }
    
    public var ringBuffer: DLTARingBuffer
    
    public let audioEngine: AVAudioEngine!
    public let audioPlayerNode: AVAudioPlayerNode
    public let audioConverter: AVAudioConverter
    public let timePitchEffect: AVAudioUnitTimePitch
    
    private var audioBuffers = [AVAudioPCMBuffer]()
    
    public init(preferredBufferSize: Int, audioFormat inputFormat: AVAudioFormat)
    {
        self.preferredBufferSize = preferredBufferSize
        
        self.ringBuffer = DLTARingBuffer(preferredBufferSize: Int32(preferredBufferSize * AudioBufferCount))
        
        // Audio Engine
        self.audioEngine = AVAudioEngine()
        
        self.audioPlayerNode = AVAudioPlayerNode()
        self.audioEngine.attachNode(self.audioPlayerNode)
        
        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: inputFormat.sampleRate, channels: 2)
        self.audioConverter = AVAudioConverter(fromFormat: inputFormat, toFormat: outputFormat)
                
        self.timePitchEffect = AVAudioUnitTimePitch()
        self.audioEngine.attachNode(self.timePitchEffect)
        
        self.audioEngine.connect(self.audioPlayerNode, to: self.timePitchEffect, format: outputFormat)
        self.audioEngine.connect(self.timePitchEffect, to: self.audioEngine.mainMixerNode, format: outputFormat)
        
        for _ in 0 ..< AudioBufferCount
        {
            let inputBuffer = AVAudioPCMBuffer(PCMFormat: inputFormat, frameCapacity: AVAudioFrameCount(self.preferredBufferSize))
            self.audioBuffers.append(inputBuffer)
            
            let outputBuffer = AVAudioPCMBuffer(PCMFormat: outputFormat, frameCapacity: AVAudioFrameCount(self.preferredBufferSize))
            self.audioBuffers.append(outputBuffer)
            
            self.renderAudioBuffer(inputBuffer, intoOutputBuffer: outputBuffer)
        }
        
        self.updateAudioBufferFrameLengths()
    }
}

public extension AudioManager
{
    func start()
    {
        do
        {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, withOptions: [])
            try AVAudioSession.sharedInstance().setActive(true)
            try self.audioEngine.start()
        }
        catch let error as NSError
        {
            print(error, error.userInfo)
        }
        
        self.audioPlayerNode.play()
    }
    
    func stop()
    {
        self.audioPlayerNode.stop()
        self.audioEngine.stop()
    }
}

private extension AudioManager
{
    func renderAudioBuffer(inputBuffer: AVAudioPCMBuffer, intoOutputBuffer outputBuffer: AVAudioPCMBuffer)
    {
        if self.audioEngine.running
        {
            self.ringBuffer.readIntoBuffer(inputBuffer.int16ChannelData[0], preferredSize: Int32(Float(self.preferredBufferSize) * self.rate))
            
            do
            {
                try self.audioConverter.convertToBuffer(outputBuffer, fromBuffer: inputBuffer)
            }
            catch let error as NSError
            {
                print(error, error.userInfo)
            }
        }        
        
        self.audioPlayerNode.scheduleBuffer(outputBuffer) {
            self.renderAudioBuffer(inputBuffer, intoOutputBuffer: outputBuffer)
        }
    }
    
    func updateAudioBufferFrameLengths()
    {
        let frameLength = (Float(self.preferredBufferSize) / Float(self.audioConverter.inputFormat.streamDescription.memory.mBytesPerFrame)) * self.rate
        
        for buffer in self.audioBuffers
        {
            buffer.frameLength = AVAudioFrameCount(frameLength)
        }
    }
}



