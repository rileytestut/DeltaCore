//
//  AudioManager.swift
//  DeltaCore
//
//  Created by Riley Testut on 1/12/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import AVFoundation

internal extension AVAudioFormat
{
    var frameSize: Int {
        return Int(self.streamDescription.pointee.mBytesPerFrame)
    }
}

public class AudioManager: NSObject, AudioRendering
{
    /// Currently only supports 16-bit interleaved Linear PCM.
    public internal(set) var audioFormat: AVAudioFormat {
        didSet {
            self.resetAudioEngine()
        }
    }
    
    public var isEnabled = true {
        didSet
        {
            self.audioBuffer.isEnabled = self.isEnabled
            
            self.updateOutputVolume()
            
            do
            {
                if self.isEnabled
                {
                    try self.audioEngine.start()
                }
                else
                {
                    self.audioEngine.pause()
                }
            }
            catch
            {
                print(error)
            }
            
            self.audioBuffer.reset()
        }
    }
    
    public private(set) var audioBuffer: RingBuffer
    
    public internal(set) var rate = 1.0 {
        didSet {
            self.timePitchEffect.rate = Float(self.rate)
        }
    }
    
    var frameDuration: Double = (1.0 / 60.0) {
        didSet {
            guard self.audioEngine.isRunning else { return }
            self.resetAudioEngine()
        }
    }
    
    private let audioEngine: AVAudioEngine
    private let audioPlayerNode: AVAudioPlayerNode
    private let timePitchEffect: AVAudioUnitTimePitch
    
    private var audioConverter: AVAudioConverter?
    private var audioConverterRequiredFrameCount: AVAudioFrameCount?
    
    private let audioBufferCount = 3
    
    // Used to synchronize access to self.audioPlayerNode without causing deadlocks.
    private let renderingQueue = DispatchQueue(label: "com.rileytestut.Delta.AudioManager.renderingQueue")
        
    public init(audioFormat: AVAudioFormat)
    {
        self.audioFormat = audioFormat
        
        // Temporary. Will be replaced with more accurate RingBuffer in resetAudioEngine().
        self.audioBuffer = RingBuffer(preferredBufferSize: 4096)!
        
        do
        {
            // Set category before configuring AVAudioEngine to prevent pausing any currently playing audio from another app.
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        }
        catch
        {
            print(error)
        }
        
        self.audioEngine = AVAudioEngine()
        
        self.audioPlayerNode = AVAudioPlayerNode()
        self.audioEngine.attach(self.audioPlayerNode)
        
        self.timePitchEffect = AVAudioUnitTimePitch()
        self.audioEngine.attach(self.timePitchEffect)
        
        super.init()
        
        self.updateOutputVolume()
        
        NotificationCenter.default.addObserver(self, selector: #selector(AudioManager.resetAudioEngine), name: .AVAudioEngineConfigurationChange, object: nil)
    }
}

public extension AudioManager
{
    func start()
    {
        do
        {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(0.005)
            try AVAudioSession.sharedInstance().setActive(true)
        }
        catch
        {
            print(error)
        }
        
        self.resetAudioEngine()
    }
    
    func stop()
    {
        self.audioPlayerNode.stop()
        self.audioEngine.stop()
        
        self.audioBuffer.isEnabled = false
    }
}

private extension AudioManager
{
    func render(_ inputBuffer: AVAudioPCMBuffer, into outputBuffer: AVAudioPCMBuffer)
    {
        guard let buffer = inputBuffer.int16ChannelData, let audioConverter = self.audioConverter else { return }
        
        // Ensure any buffers from previous audio route configurations are no longer processed.
        guard inputBuffer.format == audioConverter.inputFormat && outputBuffer.format == audioConverter.outputFormat else { return }
        
        if self.audioConverterRequiredFrameCount == nil
        {
            // Determine the minimum number of input frames needed to perform a conversion.
            audioConverter.convert(to: outputBuffer, error: nil) { (requiredPacketCount, outStatus) -> AVAudioBuffer? in
                // In Linear PCM, one packet = one frame.
                self.audioConverterRequiredFrameCount = requiredPacketCount
                
                // Setting to ".noDataNow" sometimes results in crash, so we set to ".endOfStream" and reset audioConverter afterwards.
                outStatus.pointee = .endOfStream
                return nil
            }
            
            audioConverter.reset()
        }
        
        guard let audioConverterRequiredFrameCount = self.audioConverterRequiredFrameCount else { return }
        
        let availableFrameCount = AVAudioFrameCount(self.audioBuffer.availableBytesForReading / self.audioFormat.frameSize)
        if self.audioEngine.isRunning && availableFrameCount >= audioConverterRequiredFrameCount
        {            
            var conversionError: NSError?
            let status = audioConverter.convert(to: outputBuffer, error: &conversionError) { (requiredPacketCount, outStatus) -> AVAudioBuffer? in
                
                // Copy requiredPacketCount frames into inputBuffer's first channel (since audio is interleaved, no need to modify other channels).
                let preferredSize = Int(requiredPacketCount) * self.audioFormat.frameSize
                buffer[0].withMemoryRebound(to: UInt8.self, capacity: preferredSize) { (uint8Buffer) in
                    let readBytes = self.audioBuffer.read(into: uint8Buffer, preferredSize: preferredSize)
                    
                    let frameLength = AVAudioFrameCount(readBytes / self.audioFormat.frameSize)
                    inputBuffer.frameLength = frameLength
                }
                
                if inputBuffer.frameLength == 0
                {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                else
                {
                    outStatus.pointee = .haveData
                    return inputBuffer
                }
            }
            
            if status == .error
            {
                if let error = conversionError
                {
                    print(error, error.userInfo)
                }
            }
        }
        else
        {
            // If not running or not enough input frames, set frameLength to 0 to minimize time until we check again.
            inputBuffer.frameLength = 0
        }
        
        self.audioPlayerNode.scheduleBuffer(outputBuffer) { [weak self, weak node = audioPlayerNode] in
            guard let self = self else { return }
            
            self.renderingQueue.async {
                if node?.isPlaying == true
                {
                    self.render(inputBuffer, into: outputBuffer)
                }
            }
        }
    }
    
    @objc func resetAudioEngine()
    {
        self.renderingQueue.sync {
            self.audioPlayerNode.reset()
            
            guard let outputAudioFormat = AVAudioFormat(standardFormatWithSampleRate: AVAudioSession.sharedInstance().sampleRate, channels: self.audioFormat.channelCount) else { return }
            
            let inputAudioBufferFrameCount = Int(self.audioFormat.sampleRate * self.frameDuration)
            let outputAudioBufferFrameCount = Int(outputAudioFormat.sampleRate * self.frameDuration)
            
            // Allocate enough space to prevent us from overwriting data before we've used it.
            let ringBufferAudioBufferCount = Int((self.audioFormat.sampleRate / outputAudioFormat.sampleRate).rounded(.up) + 3.0)
            
            let preferredBufferSize = inputAudioBufferFrameCount * self.audioFormat.frameSize * ringBufferAudioBufferCount
            guard let ringBuffer = RingBuffer(preferredBufferSize: preferredBufferSize) else {
                fatalError("Cannot initialize RingBuffer with preferredBufferSize of \(preferredBufferSize)")
            }
            self.audioBuffer = ringBuffer
            
            let audioConverter = AVAudioConverter(from: self.audioFormat, to: outputAudioFormat)
            self.audioConverter = audioConverter
            
            self.audioConverterRequiredFrameCount = nil
            
            self.audioEngine.disconnectNodeOutput(self.audioPlayerNode)
            self.audioEngine.disconnectNodeOutput(self.timePitchEffect)
            
            self.audioEngine.connect(self.audioPlayerNode, to: self.timePitchEffect, format: outputAudioFormat)
            self.audioEngine.connect(self.timePitchEffect, to: self.audioEngine.mainMixerNode, format: outputAudioFormat)
            
            self.audioBuffer.reset()
            
            for _ in 0 ..< self.audioBufferCount
            {
                let inputAudioBufferFrameCapacity = max(inputAudioBufferFrameCount, outputAudioBufferFrameCount)
                
                if let inputBuffer = AVAudioPCMBuffer(pcmFormat: self.audioFormat, frameCapacity: AVAudioFrameCount(inputAudioBufferFrameCapacity)),
                    let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputAudioFormat, frameCapacity: AVAudioFrameCount(outputAudioBufferFrameCount))
                {
                    self.render(inputBuffer, into: outputBuffer)
                }
            }
        }
        
        do
        {
            try self.audioEngine.start()
        }
        catch
        {
            print(error)
        }
        
        self.audioPlayerNode.play()
    }
    
    @objc func updateOutputVolume()
    {
        if !self.isEnabled
        {
            self.audioEngine.mainMixerNode.outputVolume = 0.0
        }
        else
        {
            self.audioEngine.mainMixerNode.outputVolume = 1.0
        }
    }
}
