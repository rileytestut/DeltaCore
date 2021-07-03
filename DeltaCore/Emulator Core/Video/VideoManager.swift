//
//  VideoManager.swift
//  DeltaCore
//
//  Created by Riley Testut on 3/16/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation
import Accelerate
import CoreImage
import GLKit

protocol VideoProcessor
{
    var videoFormat: VideoFormat { get }
    var videoBuffer: UnsafeMutablePointer<UInt8>? { get }
    
    var viewport: CGRect { get set }
    
    func prepare()
    func processFrame() -> CIImage?
}

extension VideoProcessor
{
    var correctedViewport: CGRect? {
        guard self.viewport != .zero else { return nil }
        
        let viewport = CGRect(x: self.viewport.minX, y: self.videoFormat.dimensions.height - self.viewport.height,
                              width: self.viewport.width, height: self.viewport.height)
        return viewport
    }
}

public class VideoManager: NSObject, VideoRendering
{
    public internal(set) var videoFormat: VideoFormat {
        didSet {
            self.updateProcessor()
        }
    }
    
    public var viewport: CGRect = .zero {
        didSet {
            self.processor.viewport = self.viewport
        }
    }
    
    public private(set) var gameViews = [GameView]()
    
    public var isEnabled = true
    
    private let context: EAGLContext
    private let ciContext: CIContext
    
    private var processor: VideoProcessor
    @NSCopying private var processedImage: CIImage?
    @NSCopying private var displayedImage: CIImage? // Can only accurately snapshot rendered images.
    
    private lazy var renderThread = RenderThread(action: { [weak self] in
        self?._render()
    })
    
    public init(videoFormat: VideoFormat)
    {
        self.videoFormat = videoFormat
        self.context = EAGLContext(api: .openGLES2)!
        self.ciContext = CIContext(eaglContext: self.context, options: [.workingColorSpace: NSNull()])
        
        switch videoFormat.format
        {
        case .bitmap: self.processor = BitmapProcessor(videoFormat: videoFormat)
        case .openGLES: self.processor = OpenGLESProcessor(videoFormat: videoFormat, context: self.context)
        }
        
        super.init()
        
        self.renderThread.start()
    }
    
    private func updateProcessor()
    {
        switch self.videoFormat.format
        {
        case .bitmap:
            self.processor = BitmapProcessor(videoFormat: self.videoFormat)
            
        case .openGLES:
            guard let processor = self.processor as? OpenGLESProcessor else { return }
            processor.videoFormat = self.videoFormat
        }
        
        processor.viewport = self.viewport
    }
    
    deinit
    {
        self.renderThread.cancel()
    }
}

public extension VideoManager
{
    func add(_ gameView: GameView)
    {
        gameView.eaglContext = self.context
        self.gameViews.append(gameView)
    }
    
    func remove(_ gameView: GameView)
    {
        if let index = self.gameViews.firstIndex(of: gameView)
        {
            self.gameViews.remove(at: index)
        }
    }
}

public extension VideoManager
{
    var videoBuffer: UnsafeMutablePointer<UInt8>? {
        return self.processor.videoBuffer
    }
    
    func prepare()
    {
        self.processor.prepare()
    }
    
    func processFrame()
    {
        guard self.isEnabled else { return }
        
        autoreleasepool {
            self.processedImage = self.processor.processFrame()
        }
    }
    
    func render()
    {
        guard self.isEnabled else { return }
        
        guard let image = self.processedImage else { return }
        
        // Skip frame if previous frame is not finished rendering.
        guard self.renderThread.wait(timeout: .now()) == .success else { return }
        
        self.displayedImage = image
        
        self.renderThread.run()
    }
    
    func snapshot() -> UIImage?
    {
        guard let displayedImage = self.displayedImage else { return nil }
        
        let imageWidth = Int(displayedImage.extent.width)
        let imageHeight = Int(displayedImage.extent.height)
        let capacity = imageWidth * imageHeight * 4
        
        let imageBuffer = UnsafeMutableRawBufferPointer.allocate(byteCount: capacity, alignment: 1)
        defer { imageBuffer.deallocate() }
        
        guard let baseAddress = imageBuffer.baseAddress, let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        
        // Must render to raw buffer first so we can set CGImageAlphaInfo.noneSkipLast flag when creating CGImage.
        // Otherwise, some parts of images may incorrectly be transparent.
        self.ciContext.render(displayedImage, toBitmap: baseAddress, rowBytes: imageWidth * 4, bounds: displayedImage.extent, format: .RGBA8, colorSpace: colorSpace)
        
        let data = Data(bytes: baseAddress, count: imageBuffer.count)
        let bitmapInfo: CGBitmapInfo = [CGBitmapInfo.byteOrder32Big, CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)]
        
        guard
            let dataProvider = CGDataProvider(data: data as CFData),
            let cgImage = CGImage(width: imageWidth, height: imageHeight, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: imageWidth * 4, space: colorSpace, bitmapInfo: bitmapInfo, provider: dataProvider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return nil }
        
        let image = UIImage(cgImage: cgImage)
        return image
    }
}

private extension VideoManager
{
    func _render()
    {
        for gameView in self.gameViews
        {
            gameView.inputImage = self.displayedImage
        }
    }
}
