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
            self.ringBuffer.isEnabled = self.enabled
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
    
    public var rate = 1.0 {
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
        self.audioEngine.attach(self.audioPlayerNode)
        
        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: self.bufferInfo.inputFormat.sampleRate, channels: 2)
        self.audioConverter = AVAudioConverter(from: self.bufferInfo.inputFormat, to: outputFormat)
                
        self.timePitchEffect = AVAudioUnitTimePitch()
        self.audioEngine.attach(self.timePitchEffect)
        
        self.audioEngine.connect(self.audioPlayerNode, to: self.timePitchEffect, format: outputFormat)
        self.audioEngine.connect(self.timePitchEffect, to: self.audioEngine.mainMixerNode, format: outputFormat)
        
        super.init()
        
        for _ in 0 ..< AudioBufferCount
        {
            let inputBuffer = AVAudioPCMBuffer(pcmFormat: self.bufferInfo.inputFormat, frameCapacity: AVAudioFrameCount(self.bufferInfo.preferredSize))
            self.audioBuffers.append(inputBuffer)
            
            let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: AVAudioFrameCount(self.bufferInfo.preferredSize))
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
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryAmbient)
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
        
        self.ringBuffer.isEnabled = false
        self.ringBuffer.reset()
    }
}

private extension AudioManager
{
    func renderAudioBuffer(_ inputBuffer: AVAudioPCMBuffer, intoOutputBuffer outputBuffer: AVAudioPCMBuffer)
    {
        guard let buffer = inputBuffer.int16ChannelData else { return }
        
        if self.audioEngine.isRunning
        {            
            self.ringBuffer.read(intoBuffer: (buffer[0]), preferredSize: Int32(Double(self.bufferInfo.preferredSize) * self.rate))
            
            do
            {
                try self.audioConverter.convert(to: outputBuffer, from: inputBuffer)
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
        let frameLength = (Double(self.bufferInfo.preferredSize) / Double(self.audioConverter.inputFormat.streamDescription.pointee.mBytesPerFrame)) * self.rate
        
        for buffer in self.audioBuffers
        {
            buffer.frameLength = AVAudioFrameCount(frameLength)
        }
    }
    
    
}



