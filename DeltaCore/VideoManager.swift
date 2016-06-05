//
//  VideoManager.swift
//  DeltaCore
//
//  Created by Riley Testut on 3/16/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation
import Accelerate

public extension VideoManager
{
    public struct BufferInfo
    {
        public let inputFormat: Format
        public let outputFormat: Format
        
        public let inputDimensions: CGSize
        public let outputDimensions: CGSize
        
        public var inputBufferSize: Int {
            return Int(self.inputDimensions.width * self.inputDimensions.height) * self.inputFormat.bytesPerPixel
        }
        public var outputBufferSize: Int {
            return Int(self.inputDimensions.width * self.inputDimensions.height) * self.outputFormat.bytesPerPixel
        }
        
        public init(inputFormat: Format, inputDimensions: CGSize, outputDimensions: CGSize)
        {
            self.inputFormat = inputFormat
            self.inputDimensions = inputDimensions
            
            self.outputFormat = .BGRA8
            self.outputDimensions = outputDimensions
        }
    }
}

public extension VideoManager.BufferInfo
{
    public enum Format
    {
        case RGB565
        case BGRA8

        public var bytesPerPixel: Int {
            switch self
            {
            case .RGB565: return 2
            case .BGRA8: return 4
            }
        }
    }
}

public class VideoManager: NSObject, DLTAVideoRendering
{
    public private(set) var gameViews = [GameView]()
    
    public var enabled = true
    
    public let bufferInfo: BufferInfo
    
    public let videoBuffer: UnsafeMutablePointer<UInt8>
    private let convertedVideoBuffer: UnsafeMutablePointer<UInt8>
    
    public init(bufferInfo: BufferInfo)
    {
        self.bufferInfo = bufferInfo
        
        self.videoBuffer = UnsafeMutablePointer<UInt8>.alloc(self.bufferInfo.inputBufferSize)
        self.convertedVideoBuffer = UnsafeMutablePointer<UInt8>.alloc(self.bufferInfo.outputBufferSize)
        
        super.init()
    }
    
    deinit
    {
        self.videoBuffer.dealloc(self.bufferInfo.inputBufferSize)
        self.convertedVideoBuffer.dealloc(self.bufferInfo.outputBufferSize)
    }
}

public extension VideoManager
{
    func addGameView(gameView: GameView)
    {
        self.gameViews.append(gameView)
    }
    
    func removeGameView(gameView: GameView)
    {
        if let index = self.gameViews.indexOf(gameView)
        {
            self.gameViews.removeAtIndex(index)
        }
    }
}

internal extension VideoManager
{
    func didUpdateVideoBuffer()
    {
        guard self.enabled else { return }
        
        autoreleasepool {
            
            var inputVImageBuffer = vImage_Buffer(data: self.videoBuffer, height: vImagePixelCount(self.bufferInfo.inputDimensions.height), width: vImagePixelCount(self.bufferInfo.inputDimensions.width), rowBytes: self.bufferInfo.inputFormat.bytesPerPixel * Int(self.bufferInfo.inputDimensions.width))
            
            let bitmapBuffer: UnsafeMutablePointer<UInt8>
            var convertedVImageBuffer: vImage_Buffer
            
            if self.bufferInfo.inputFormat == .BGRA8
            {
                bitmapBuffer = self.videoBuffer
                convertedVImageBuffer = inputVImageBuffer
            }
            else
            {
                bitmapBuffer = self.convertedVideoBuffer
                convertedVImageBuffer = vImage_Buffer(data: self.convertedVideoBuffer, height: vImagePixelCount(self.bufferInfo.inputDimensions.height), width: vImagePixelCount(self.bufferInfo.inputDimensions.width), rowBytes: self.bufferInfo.outputFormat.bytesPerPixel * Int(self.bufferInfo.inputDimensions.width))
            }
                        
            switch self.bufferInfo.inputFormat
            {
            case .RGB565: vImageConvert_RGB565toBGRA8888(255, &inputVImageBuffer, &convertedVImageBuffer, 0)
            case .BGRA8: break
            }
            
            let bitmapData = NSData(bytes: bitmapBuffer, length: self.bufferInfo.outputBufferSize)
            let image = CIImage(bitmapData: bitmapData, bytesPerRow: self.bufferInfo.outputFormat.bytesPerPixel * Int(self.bufferInfo.inputDimensions.width), size: self.bufferInfo.outputDimensions, format: kCIFormatBGRA8, colorSpace: nil)
            
            for gameView in self.gameViews
            {
                gameView.inputImage = image
            }
            
        }
    }
}