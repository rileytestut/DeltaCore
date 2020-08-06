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
//import OpenGLES

protocol VideoProcessor
{
    var videoBuffer: UnsafeMutablePointer<UInt8>? { get }
    
    func prepare()
    func processFrame() -> CIImage?
}

@available(iOS 13, *)
public class MetalStuff: NSObject
{
    public let device: MTLDevice
    public let sharedTexture: MTLTexture
    public let sharedHandle: MTLSharedTextureHandle
    
    init(device: MTLDevice, sharedTexture: MTLTexture, sharedHandle: MTLSharedTextureHandle)
    {
        self.device = device
        self.sharedTexture = sharedTexture
        self.sharedHandle = sharedHandle
    }
}

public class VideoManager: NSObject, VideoRendering
{
    public internal(set) var videoFormat: VideoFormat {
        didSet {
            self.updateProcessor()
        }
    }
    
    public private(set) var gameViews = [GameView]()
    
    public var isEnabled = true
    
//    private let context: EAGLContext
    private let ciContext: CIContext
    
    private var processor: VideoProcessor
    @NSCopying private var processedImage: CIImage?
    @NSCopying private var displayedImage: CIImage? // Can only accurately snapshot rendered images.
    
    public let surface: IOSurface
    
    @available(iOS 13, *)
    public lazy var metalStuff: MetalStuff? = nil
    
//    public let port: NSMachPort
    
    public init(videoFormat: VideoFormat)
    {
        self.videoFormat = videoFormat
//        self.context = EAGLContext(api: .openGLES2)!
        self.ciContext = CIContext(options: [.workingColorSpace: NSNull()])
                    
//        let props: [IOSurfacePropertyKey : Any] = [
//            .width: self.videoFormat.dimensions.width,
//            .height: self.videoFormat.dimensions.height,
//            .pixelFormat: self.videoFormat.format.pixelFormat.nativePixelFormat,
//            .bytesPerElement: self.videoFormat.format.pixelFormat.bytesPerPixel,
//            .bytesPerRow: self.videoFormat.format.pixelFormat.bytesPerPixel * Int(self.videoFormat.dimensions.width),
//            .allocSize: self.videoFormat.format.pixelFormat.bytesPerPixel * Int(self.videoFormat.dimensions.width) * Int(self.videoFormat.dimensions.height),
//            kIOSurfaceIsGlobal as IOSurfacePropertyKey: NSNumber(value: true)
//        ]
//
//        self.surface = IOSurface(properties: props)!
        
        
//
        
        
        guard #available(iOS 13.0, *) else { fatalError() }
        
        let device = MTLCreateSystemDefaultDevice()!
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(self.videoFormat.dimensions.width), height: Int(self.videoFormat.dimensions.height), mipmapped: false)
        descriptor.storageMode = .private
        
        let sharedTexture = device.makeSharedTexture(descriptor: descriptor)!
        
        let sharedHandle = sharedTexture.makeSharedTextureHandle()!
        
        let iosurface = sharedHandle.ioSurface()
        self.surface = unsafeBitCast(iosurface!, to: IOSurface.self)
                
        switch videoFormat.format
        {
        case .bitmap:
            let bitmapProcessor = BitmapProcessor(videoFormat: videoFormat)
            bitmapProcessor.surface = self.surface
            self.processor = bitmapProcessor
            
        case .openGLES: self.processor = BitmapProcessor(videoFormat: videoFormat)// OpenGLESProcessor(videoFormat: videoFormat, context: self.context)
        }
        
//        let xpcObject = IOSurfaceCreateXPCObject(unsafeBitCast(self.surface, to: IOSurfaceRef.self))
//        print(xpcObject)
        
//        let rawPort = IOSurfaceCreateMachPort(unsafeBitCast(self.surface, to: IOSurfaceRef.self))
//        self.port = NSMachPort(machPort: rawPort)
        
        
        
        super.init()
        
        self.metalStuff = MetalStuff(device: device, sharedTexture: sharedTexture, sharedHandle: sharedHandle)
    }
    
    private func updateProcessor()
    {
        switch self.videoFormat.format
        {
        case .bitmap:
            let bitmapProcessor = BitmapProcessor(videoFormat: self.videoFormat)
            bitmapProcessor.surface = self.surface
            self.processor = bitmapProcessor
            
        case .openGLES:
            self.processor = BitmapProcessor(videoFormat: self.videoFormat)
//            guard let processor = self.processor as? OpenGLESProcessor else { return }
//            processor.videoFormat = self.videoFormat
        }
    }
    
    public func getIOSurface(completion: @escaping (IOSurface) -> Void)
    {
        completion(self.surface)
    }
}

public extension VideoManager
{
    func add(_ gameView: GameView)
    {
//        gameView.eaglContext = self.context
        gameView.surface = self.surface
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
        
        // Autoreleasepool necessary to prevent leaking CIImages.
        autoreleasepool {
            for gameView in self.gameViews
            {
                gameView.inputImage = image
//                gameView.update()
            }

            self.displayedImage = image
        }
    }
 
    func snapshot() -> UIImage?
    {
        guard let displayedImage = self.displayedImage else { return nil }
        
        let imageWidth = Int(self.videoFormat.dimensions.width)
        let imageHeight = Int(self.videoFormat.dimensions.height)
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
