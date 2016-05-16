//
//  AudioManager.swift
//  DeltaCore
//
//  Created by Riley Testut on 1/12/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import AVFoundation

private let AudioBufferCount = 3

public extension AudioManager
{
    public struct BufferInfo
    {
        public let inputFormat: AVAudioFormat
        public let preferredSize: Int
        
        public init(inputFormat: AVAudioFormat, preferredSize: Int)
        {
            self.inputFormat = inputFormat
            self.preferredSize = preferredSize
        }
    }
}

public class AudioManager: NSObject, DLTAAudioRendering
{
    public let bufferInfo: BufferInfo
    
    public var enabled = true {
        didSet
        {
            self.ringBuffer.enabled = self.enabled
            self.audioEngine.mainMixerNode.outputVolume = self.enabled ? 1.0 : 0.0
            
            do
            {
                if self.enabled
                {
                    try self.audioEngine.start()
                }
                else
                {
                    self.audioEngine.pause()
                }
            }
            catch let error as NSError
            {
                print(error)
            }
            
            self.updateAudioBufferFrameLengths()
            
            self.ringBuffer.reset()
        }
    }
    
    public var rate: Float = 1.0 {
        didSet {
            self.timePitchEffect.rate = Float(self.rate)
            self.updateAudioBufferFrameLengths()
        }
    }
    
    public var ringBuffer: DLTARingBuffer
    
    public let audioEngine: AVAudioEngine
    public let audioPlayerNode: AVAudioPlayerNode
    public let audioConverter: AVAudioConverter
    public let timePitchEffect: AVAudioUnitTimePitch
    
    private var audioBuffers = [AVAudioPCMBuffer]()
    
    public init(bufferInfo: BufferInfo)
    {
        self.bufferInfo = bufferInfo
        
        self.ringBuffer = DLTARingBuffer(preferredBufferSize: Int32(self.bufferInfo.preferredSize * AudioBufferCount))
        
        // Audio Engine
        self.audioEngine = AVAudioEngine()
        
        self.audioPlayerNode = AVAudioPlayerNode()
        self.audioEngine.attachNode(self.audioPlayerNode)
        
        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: self.bufferInfo.inputFormat.sampleRate, channels: 2)
        self.audioConverter = AVAudioConverter(fromFormat: self.bufferInfo.inputFormat, toFormat: outputFormat)
                
        self.timePitchEffect = AVAudioUnitTimePitch()
        self.audioEngine.attachNode(self.timePitchEffect)
        
        self.audioEngine.connect(self.audioPlayerNode, to: self.timePitchEffect, format: outputFormat)
        self.audioEngine.connect(self.timePitchEffect, to: self.audioEngine.mainMixerNode, format: outputFormat)
        
        super.init()
        
        for _ in 0 ..< AudioBufferCount
        {
            let inputBuffer = AVAudioPCMBuffer(PCMFormat: self.bufferInfo.inputFormat, frameCapacity: AVAudioFrameCount(self.bufferInfo.preferredSize))
            self.audioBuffers.append(inputBuffer)
            
            let outputBuffer = AVAudioPCMBuffer(PCMFormat: outputFormat, frameCapacity: AVAudioFrameCount(self.bufferInfo.preferredSize))
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
        self.ringBuffer.reset()
        
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
        
        self.ringBuffer.enabled = false
        self.ringBuffer.reset()
    }
}

private extension AudioManager
{
    func renderAudioBuffer(inputBuffer: AVAudioPCMBuffer, intoOutputBuffer outputBuffer: AVAudioPCMBuffer)
    {
        if self.audioEngine.running
        {            
            self.ringBuffer.readIntoBuffer(inputBuffer.int16ChannelData[0], preferredSize: Int32(Float(self.bufferInfo.preferredSize) * self.rate))
            
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
        let frameLength = (Float(self.bufferInfo.preferredSize) / Float(self.audioConverter.inputFormat.streamDescription.memory.mBytesPerFrame)) * self.rate
        
        for buffer in self.audioBuffers
        {
            buffer.frameLength = AVAudioFrameCount(frameLength)
        }
    }
    
    
}



