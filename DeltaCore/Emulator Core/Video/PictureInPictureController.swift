//
//  PictureInPictureController.swift
//  PictureInPictureController
//
//  Created by Riley Testut on 7/27/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import AVKit
import CoreImage

private extension CIRenderDestination
{
    var size: CGSize {
        CGSize(width: self.width, height: self.height)
    }
}

private extension CMSampleBuffer
{
    func setAttachments(_ attachments: [String: Any])
    {
        let rawAttachments = CMSampleBufferGetSampleAttachmentsArray(self, createIfNecessary: true)!
        let dictionary = unsafeBitCast(CFArrayGetValueAtIndex(rawAttachments, 0), to: CFMutableDictionary.self)
        
        for (key, value) in attachments
        {
            let rawKey = Unmanaged.passUnretained(key as AnyObject).toOpaque()
            let rawValue = Unmanaged.passUnretained(value as AnyObject).toOpaque()
            
            CFDictionarySetValue(dictionary, rawKey, rawValue)
        }
    }
}

@available(iOS 15, *)
private class RenderProxy: NSObject
{
    weak var pipController: PictureInPictureController?
    
    init(pipController: PictureInPictureController)
    {
        self.pipController = pipController
    }
    
    @objc
    func render()
    {
        self.pipController?.render()
    }
}

@available(iOS 15, *)
public final class PictureInPictureController: NSObject
{
    public private(set) weak var emulatorCore: EmulatorCore?
    public private(set) var isActive: Bool = false
    
    public var cancellationHandler: (@MainActor () -> Void)?
    
    private let sampleBufferLayer: AVSampleBufferDisplayLayer
    private var pipController: AVPictureInPictureController?

    private let context = CIContext(options: [.workingColorSpace: NSNull()])
    private var pixelBuffer: CVPixelBuffer?
    private var renderDestination: CIRenderDestination?
    
    // Target RenderProxy, not self, to avoid circular strong references due to CADisplayLink retaining its target.
    private lazy var displayLink = CADisplayLink(target: RenderProxy(pipController: self), selector: #selector(RenderProxy.render))

    private var coreObservation: NSKeyValueObservation?
    private var layerObservation: NSKeyValueObservation?
    
    private var ignoreStopCallback = false
    
    private weak var gameView: GameView?
    
    @MainActor
    public init(emulatorCore: EmulatorCore)
    {
        self.emulatorCore = emulatorCore
        
        self.sampleBufferLayer = AVSampleBufferDisplayLayer()
        self.sampleBufferLayer.frame = CGRect(x: 0, y: 0, width: emulatorCore.videoManager.videoFormat.dimensions.width, height: emulatorCore.videoManager.videoFormat.dimensions.height)
        
        super.init()
        
        self.coreObservation = emulatorCore.observe(\.state, options: [.initial]) { [weak self] (_, _) in
            self?.update()
        }
        
        self.layerObservation = self.sampleBufferLayer.observe(\.status) { [weak self] (_, _) in
            guard let self = self, self.isActive else { return }
            
            // Don't reset sampleBufferLayer unless PiP is active.
            self.reset()
        }
    }
    
    deinit
    {
        // Manually invalidate KVO tokens to avoid crash during deinit.
        self.coreObservation?.invalidate()
        self.layerObservation?.invalidate()
    }
    
    @MainActor
    public func start(from gameView: GameView)
    {
        guard !self.isActive else { return }
        self.isActive = true
        
        let source = AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: self.sampleBufferLayer, playbackDelegate: self)
        
        self.pipController = AVPictureInPictureController(contentSource: source)
        self.pipController?.delegate = self
        self.pipController?.canStartPictureInPictureAutomaticallyFromInline = false
        self.pipController?.requiresLinearPlayback = true
        
        gameView.renderMode = .sampleBufferLayer(self.sampleBufferLayer)
        gameView.layoutIfNeeded() // Make sure sampleBufferLayer has correct frame before animating transition.
        self.gameView = gameView
        
        self.sampleBufferLayer.requestMediaDataWhenReady(on: .main) { [weak self] in
            guard let self = self else { return }

            self.render()
            
            self.sampleBufferLayer.stopRequestingMediaData()
            self.pipController?.startPictureInPicture()

            self.displayLink.add(to: .main, forMode: .common)
        }
    }
    
    @MainActor
    public func stop()
    {
        guard self.isActive else { return }
        self.isActive = false
        
        self.ignoreStopCallback = true
        
        self.pipController?.stopPictureInPicture()
        self.pipController = nil // AVPictureInPictureController indirectly retains self via ContentSource, so manually break reference cycle.
        
        self.gameView?.renderMode = .openGLES
        self.gameView = nil
        
        self.displayLink.remove(from: .main, forMode: .common)
    }
}

@available(iOS 15, *)
private extension PictureInPictureController
{
    func update()
    {
        switch self.emulatorCore?.state
        {
        case .running: self.displayLink.isPaused = false
        case .paused, .stopped, nil: self.displayLink.isPaused = true
        }
        
        Task { @MainActor in
            self.pipController?.invalidatePlaybackState()
        }
    }
    
    func reset()
    {
        guard let error = self.sampleBufferLayer.error else { return }
        
        print("[DeltaCore] PiP Error:", error)
        
        self.sampleBufferLayer.flush() // Flush layer so it can display frames again.
        self.render()
        
        self.emulatorCore?.pause()
    }
    
    func render()
    {
        guard let videoManager = self.emulatorCore?.videoManager, self.sampleBufferLayer.status != .failed else { return }
        
        let viewport = videoManager.surface.viewport ?? CGRect(x: 0, y: 0, width: videoManager.videoFormat.dimensions.width, height: videoManager.videoFormat.dimensions.height)
        let needsRender = videoManager.surface.isYAxisFlipped || viewport != CGRect(origin: .zero, size: videoManager.videoFormat.dimensions)
        
        if self.renderDestination?.size != viewport.size
        {
            if needsRender
            {
                let attributes = [kCVPixelBufferIOSurfacePropertiesKey: NSDictionary()]
                guard CVPixelBufferCreate(nil, Int(viewport.width), Int(viewport.height), videoManager.surface.pixelFormat, attributes as CFDictionary, &self.pixelBuffer) == kCVReturnSuccess else { return }
            }
            else
            {
                var pixelBuffer: Unmanaged<CVPixelBuffer>?
                guard CVPixelBufferCreateWithIOSurface(nil, videoManager.surface, nil, &pixelBuffer) == kCVReturnSuccess else { return }
                
                self.pixelBuffer = pixelBuffer!.takeRetainedValue()
            }
            
            self.renderDestination = self.pixelBuffer.map { CIRenderDestination(pixelBuffer: $0) }
        }
        
        guard let pixelBuffer = self.pixelBuffer, let renderDestination = self.renderDestination else { return }
        
        if needsRender
        {
            guard let outputImage = videoManager.processedImage else { return }
            
            do
            {
                // Render frame asynchronously.
                try self.context.startTask(toRender: outputImage, from: outputImage.extent, to: renderDestination, at: .zero)
            }
            catch
            {
                print("[DeltaCore] PiP rendering error:", error)
            }
        }

        var videoFormatDescription: CMVideoFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixelBuffer, formatDescriptionOut: &videoFormatDescription) == noErr, let formatDescription = videoFormatDescription else { return }
        
        var timingInfo = CMSampleTimingInfo()
        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: pixelBuffer, formatDescription: formatDescription, sampleTiming: &timingInfo, sampleBufferOut: &sampleBuffer)
        
        if let sampleBuffer = sampleBuffer
        {
            sampleBuffer.setAttachments([kCMSampleAttachmentKey_DisplayImmediately as String: kCFBooleanTrue!])
            self.sampleBufferLayer.enqueue(sampleBuffer)
        }
    }
}

@available(iOS 15, *) @objc
extension PictureInPictureController: AVPictureInPictureControllerDelegate
{
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error)
    {
        print("[DeltaCore] Error starting PIP:", error)
        
        self.pictureInPictureDidStop()
    }
    
    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController)
    {
        self.pictureInPictureDidStop()
    }
    
    private func pictureInPictureDidStop()
    {
        defer { self.ignoreStopCallback = false }
        guard !self.ignoreStopCallback else { return }
        
        Task { @MainActor in
            self.stop()
            self.cancellationHandler?()
        }
    }
}

@available(iOS 15, *) @objc
extension PictureInPictureController: AVPictureInPictureSampleBufferPlaybackDelegate
{
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool)
    {
        guard self.emulatorCore?.state != .stopped else { return }
        
        if playing
        {
            self.emulatorCore?.resume()
        }
        else
        {
            self.emulatorCore?.pause()
        }
    }
    
    public func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange
    {
        return CMTimeRange(start: .zero, duration: CMTime.positiveInfinity)
    }
    
    public func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool
    {
        return self.emulatorCore?.state == .paused
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions)
    {
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void)
    {
    }
}
