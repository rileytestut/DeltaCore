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

private extension VideoBufferInfo.Format
{
    var nativeCIFormat: CIFormat? {
        switch self
        {
        case .rgb565: return nil
        case .bgra8: return kCIFormatBGRA8
        case .rgba8: return kCIFormatRGBA8
        }
    }
}

public class VideoManager: NSObject, VideoRendering
{
    public fileprivate(set) var gameViews = [GameView]()
    
    public var isEnabled = true
    
    public let bufferInfo: VideoBufferInfo
    public let videoBuffer: UnsafeMutablePointer<UInt8>
    
    fileprivate let outputBufferInfo: VideoBufferInfo
    fileprivate let outputVideoBuffer: UnsafeMutablePointer<UInt8>
    
    public init(bufferInfo: VideoBufferInfo)
    {
        self.bufferInfo = bufferInfo
        
        switch self.bufferInfo.format
        {
        case .rgb565: self.outputBufferInfo = VideoBufferInfo(format: .bgra8, dimensions: self.bufferInfo.dimensions)
        case .bgra8, .rgba8: self.outputBufferInfo = self.bufferInfo
        }
        
        self.videoBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.bufferInfo.size)
        self.outputVideoBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.outputBufferInfo.size)
        
        super.init()
    }
    
    deinit
    {
        self.videoBuffer.deallocate(capacity: self.bufferInfo.size)
        self.outputVideoBuffer.deallocate(capacity: self.outputBufferInfo.size)
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
        
        guard let ciFormat = self.outputBufferInfo.format.nativeCIFormat else {
            print("VideoManager output format is not supported.")
            return
        }
        
        autoreleasepool {
            
            var inputVImageBuffer = vImage_Buffer(data: self.videoBuffer, height: vImagePixelCount(self.bufferInfo.dimensions.height), width: vImagePixelCount(self.bufferInfo.dimensions.width), rowBytes: self.bufferInfo.format.bytesPerPixel * Int(self.bufferInfo.dimensions.width))
            var outputVImageBuffer = vImage_Buffer(data: self.outputVideoBuffer, height: vImagePixelCount(self.outputBufferInfo.dimensions.height), width: vImagePixelCount(self.outputBufferInfo.dimensions.width), rowBytes: self.outputBufferInfo.format.bytesPerPixel * Int(self.outputBufferInfo.dimensions.width))
            
            switch self.bufferInfo.format
            {
            case .rgb565: vImageConvert_RGB565toBGRA8888(255, &inputVImageBuffer, &outputVImageBuffer, 0)
            case .bgra8, .rgba8:
                // Ensure alpha value is 255, not 0.
                // 0x1 refers to the Blue channel in ARGB, which corresponds to the Alpha channel in BGRA and RGBA.
                vImageOverwriteChannelsWithScalar_ARGB8888(255, &inputVImageBuffer, &outputVImageBuffer, 0x1, vImage_Flags(kvImageNoFlags))
            }
            
            let bitmapData = Data(bytes: self.outputVideoBuffer, count: self.outputBufferInfo.size)
            
            let image = CIImage(bitmapData: bitmapData, bytesPerRow: self.outputBufferInfo.format.bytesPerPixel * Int(self.outputBufferInfo.dimensions.width), size: self.outputBufferInfo.dimensions, format: ciFormat, colorSpace: nil)
            
            for gameView in self.gameViews
            {
                gameView.inputImage = image
            }
        }
    }
}
