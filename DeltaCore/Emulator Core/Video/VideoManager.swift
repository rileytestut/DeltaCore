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

protocol VideoProcessor: VideoRendering
{
    var videoFormat: VideoFormat { get }
    var surface: IOSurface { get }
}

public class VideoManager: NSObject
{
    public let videoFormat: VideoFormat
    
    public private(set) var gameViews = [GameView]()
    
    public var isEnabled = true {
        didSet {
            guard !self.isEnabled else { return }
            
            // Cache snapshot so that even if IOSurface changes underneath us,
            // we'll continue using the same snapshot image.
            if let snapshot = self.snapshot()
            {
                self.processedImage = CIImage(image: snapshot)
            }
        }
    }
    
    public var surface: IOSurface {
        return self.processor.surface
    }
    
    let processor: VideoProcessor
    
    private let ciContext: CIContext
    @NSCopying private var processedImage: CIImage?
    
    private var previousSurfaceSeed: UInt32?
    
    private lazy var renderThread = RenderThread(action: { [weak self] in
        self?._render()
    })
    
    public init(videoFormat: VideoFormat)
    {
        self.videoFormat = videoFormat
        self.ciContext = CIContext(options: [.workingColorSpace: NSNull()])
        
        switch videoFormat.format
        {
        case .bitmap: self.processor = BitmapProcessor(videoFormat: videoFormat)
        case .openGLES: self.processor = OpenGLESProcessor(videoFormat: videoFormat)
        }
        
        super.init()
        
        self.renderThread.start()
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
    func render()
    {
        guard self.isEnabled else { return }
                
        guard self.surface.seed != self.previousSurfaceSeed else { return }
        self.previousSurfaceSeed = self.surface.seed
        
        // Skip frame if previous frame is not finished rendering.
        guard self.renderThread.wait(timeout: .now()) == .success else { return }
        
        autoreleasepool {
            self.processedImage = self.processFrame()
        }
        
        self.renderThread.run()
    }
    
    func snapshot() -> UIImage?
    {
        guard let processedImage = self.processedImage else { return nil }
        
        let imageWidth = Int(processedImage.extent.width)
        let imageHeight = Int(processedImage.extent.height)
        let capacity = imageWidth * imageHeight * 4
        
        let imageBuffer = UnsafeMutableRawBufferPointer.allocate(byteCount: capacity, alignment: 1)
        defer { imageBuffer.deallocate() }
        
        guard let baseAddress = imageBuffer.baseAddress, let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        
        // Must render to raw buffer first so we can set CGImageAlphaInfo.noneSkipLast flag when creating CGImage.
        // Otherwise, some parts of images may incorrectly be transparent.
        self.ciContext.render(processedImage, toBitmap: baseAddress, rowBytes: imageWidth * 4, bounds: processedImage.extent, format: .RGBA8, colorSpace: colorSpace)
        
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
    func processFrame() -> CIImage
    {
        var processedImage = CIImage(ioSurface: self.surface)
        
        if self.surface.isYAxisFlipped
        {
            processedImage = processedImage.transformed(by: processedImage.orientationTransform(for: .downMirrored))
            processedImage = processedImage.transformed(by: .identity.translatedBy(x: -processedImage.extent.origin.x, y: -processedImage.extent.origin.y))
        }
        
        if var viewport = self.surface.viewport
        {
            if !self.surface.isYAxisFlipped
            {
                // Viewport origin is top-left but Core Image's origin is bottom-left,
                // so convert between the two.
                viewport.origin.y = self.videoFormat.dimensions.height - viewport.height
            }

            processedImage = processedImage.cropped(to: viewport)
        }
        
        return processedImage
    }
    
    func _render()
    {
        for gameView in self.gameViews
        {
            gameView.inputImage = self.processedImage
        }
    }
}
