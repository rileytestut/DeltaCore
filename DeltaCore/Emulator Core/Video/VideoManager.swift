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

public class VideoManager: NSObject, VideoRendering
{
    public private(set) var gameViews = [GameView]()
    
    public var isEnabled = true
    
    public let videoFormat: VideoFormat
    public let videoBuffer: UnsafeMutablePointer<UInt8>
    
    private let outputVideoFormat: VideoFormat
    private let outputVideoBuffer: UnsafeMutablePointer<UInt8>
    
    public init(videoFormat: VideoFormat)
    {
        self.videoFormat = videoFormat
        
        switch self.videoFormat.pixelFormat
        {
        case .rgb565: self.outputVideoFormat = VideoFormat(pixelFormat: .bgra8, dimensions: self.videoFormat.dimensions)
        case .bgra8, .rgba8: self.outputVideoFormat = self.videoFormat
        }
        
        self.videoBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.videoFormat.bufferSize)
        self.outputVideoBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.outputVideoFormat.bufferSize)
        
        super.init()
    }
    
    deinit
    {
        self.videoBuffer.deallocate()
        self.outputVideoBuffer.deallocate()
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
        if let index = self.gameViews.index(of: gameView)
        {
            self.gameViews.remove(at: index)
        }
    }
}

private let colorSpace = CGColorSpaceCreateDeviceRGB()

internal extension VideoManager
{
    func didUpdateVideoBuffer()
    {
        guard self.isEnabled else { return }
        
        guard let ciFormat = self.outputVideoFormat.pixelFormat.nativeCIFormat else {
            print("VideoManager output format is not supported.")
            return
        }
        
        autoreleasepool {
            
            var inputVImageBuffer = vImage_Buffer(data: self.videoBuffer, height: vImagePixelCount(self.videoFormat.dimensions.height), width: vImagePixelCount(self.videoFormat.dimensions.width), rowBytes: self.videoFormat.pixelFormat.bytesPerPixel * Int(self.videoFormat.dimensions.width))
            var outputVImageBuffer = vImage_Buffer(data: self.outputVideoBuffer, height: vImagePixelCount(self.outputVideoFormat.dimensions.height), width: vImagePixelCount(self.outputVideoFormat.dimensions.width), rowBytes: self.outputVideoFormat.pixelFormat.bytesPerPixel * Int(self.outputVideoFormat.dimensions.width))
            
            switch self.videoFormat.pixelFormat
            {
            case .rgb565: vImageConvert_RGB565toBGRA8888(255, &inputVImageBuffer, &outputVImageBuffer, 0)
            case .bgra8, .rgba8:
                // Ensure alpha value is 255, not 0.
                // 0x1 refers to the Blue channel in ARGB, which corresponds to the Alpha channel in BGRA and RGBA.
                vImageOverwriteChannelsWithScalar_ARGB8888(255, &inputVImageBuffer, &outputVImageBuffer, 0x1, vImage_Flags(kvImageNoFlags))
            }
            
            let bitmapData = Data(bytes: self.outputVideoBuffer, count: self.outputVideoFormat.bufferSize)
            
            let image = CIImage(bitmapData: bitmapData, bytesPerRow: self.outputVideoFormat.pixelFormat.bytesPerPixel * Int(self.outputVideoFormat.dimensions.width), size: self.outputVideoFormat.dimensions, format: ciFormat, colorSpace: nil)
            
            for gameView in self.gameViews
            {
                gameView.inputImage = image
            }
        }
    }
}
