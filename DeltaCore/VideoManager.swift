//
//  VideoManager.swift
//  DeltaCore
//
//  Created by Riley Testut on 3/16/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation
import SpriteKit
//import Accelerate

public class GameView: NSObject
{
    
}

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
            
            self.outputFormat = .bgra8
            self.outputDimensions = outputDimensions
        }
    }
}

public extension VideoManager.BufferInfo
{
    public enum Format
    {
        case rgb565
        case bgra8

        public var bytesPerPixel: Int {
            switch self
            {
            case .rgb565: return 2
            case .bgra8: return 4
            }
        }
    }
}

public class VideoManager: NSObject, DLTAVideoRendering
{
    public var handler: (Data -> Void)?
    
    public private(set) var gameViews = [GameView]()
    
    public var enabled = true
    
    public let bufferInfo: BufferInfo
    
    public let videoBuffer: UnsafeMutablePointer<UInt8>
    private let convertedVideoBuffer: UnsafeMutablePointer<UInt8>
    
    public init(bufferInfo: BufferInfo)
    {
        self.bufferInfo = bufferInfo
        
        self.videoBuffer = UnsafeMutablePointer<UInt8>(allocatingCapacity: self.bufferInfo.inputBufferSize)
        self.convertedVideoBuffer = UnsafeMutablePointer<UInt8>(allocatingCapacity: self.bufferInfo.outputBufferSize)
        
        super.init()
    }
    
    deinit
    {
        self.videoBuffer.deallocateCapacity(self.bufferInfo.inputBufferSize)
        self.convertedVideoBuffer.deallocateCapacity(self.bufferInfo.outputBufferSize)
    }
}

public extension VideoManager
{
    func addGameView(_ gameView: GameView)
    {
        self.gameViews.append(gameView)
    }
    
    func removeGameView(_ gameView: GameView)
    {
        if let index = self.gameViews.index(of: gameView)
        {
            self.gameViews.remove(at: index)
        }
    }
}

internal extension VideoManager
{
    func didUpdateVideoBuffer()
    {
        guard self.enabled else { return }
        
        autoreleasepool {
            
            let bitmapBuffer = self.videoBuffer
            
//            void ConvertBetweenBGRAandRGBA(unsigned char* input, int pixel_width,
//                                           int pixel_height, unsigned char* output)
//            {
//                int offset = 0;
//                
//                for (int y = 0; y < pixel_height; y++) {
//                    for (int x = 0; x < pixel_width; x++) {
//                        output[offset] = input[offset + 2];
//                        output[offset + 1] = input[offset + 1];
//                        output[offset + 2] = input[offset];
//                        output[offset + 3] = input[offset + 3];
//                        
//                        offset += 4;
//                    }
//                }
//            }
//            
            
            var offset = 0
            
            for _ in 0...Int(self.bufferInfo.outputDimensions.height)
            {
                for _ in 0...Int(self.bufferInfo.outputDimensions.width)
                {
                    self.convertedVideoBuffer[offset] = bitmapBuffer[offset + 2];
                    self.convertedVideoBuffer[offset + 1] = bitmapBuffer[offset + 1];
                    self.convertedVideoBuffer[offset + 2] = bitmapBuffer[offset];
                    self.convertedVideoBuffer[offset + 3] = bitmapBuffer[offset + 3];
                    
                    offset += 4
                }
            }
            
            
            
            let bitmapData = Data(bytes: self.convertedVideoBuffer, count: self.bufferInfo.outputBufferSize)
            
            
            self.handler?(bitmapData)
            
//            var inputVImageBuffer = vImage_Buffer(data: self.videoBuffer, height: vImagePixelCount(self.bufferInfo.inputDimensions.height), width: vImagePixelCount(self.bufferInfo.inputDimensions.width), rowBytes: self.bufferInfo.inputFormat.bytesPerPixel * Int(self.bufferInfo.inputDimensions.width))
//            
//            let bitmapBuffer: UnsafeMutablePointer<UInt8>
//            var convertedVImageBuffer: vImage_Buffer
//            
//            if self.bufferInfo.inputFormat == .bgra8
//            {
//                bitmapBuffer = self.videoBuffer
//                convertedVImageBuffer = inputVImageBuffer
//            }
//            else
//            {
//                bitmapBuffer = self.convertedVideoBuffer
//                convertedVImageBuffer = vImage_Buffer(data: self.convertedVideoBuffer, height: vImagePixelCount(self.bufferInfo.inputDimensions.height), width: vImagePixelCount(self.bufferInfo.inputDimensions.width), rowBytes: self.bufferInfo.outputFormat.bytesPerPixel * Int(self.bufferInfo.inputDimensions.width))
//            }
//                        
//            switch self.bufferInfo.inputFormat
//            {
//            case .rgb565: vImageConvert_RGB565toBGRA8888(255, &inputVImageBuffer, &convertedVImageBuffer, 0)
//            case .bgra8: break
//            }
            
//            let bitmapData = Data(bytes: UnsafePointer<UInt8>(bitmapBuffer), count: self.bufferInfo.outputBufferSize)
//            let image = CIImage(bitmapData: bitmapData, bytesPerRow: self.bufferInfo.outputFormat.bytesPerPixel * Int(self.bufferInfo.inputDimensions.width), size: self.bufferInfo.outputDimensions, format: kCIFormatBGRA8, colorSpace: nil)
//            
//            for gameView in self.gameViews
//            {
//                gameView.inputImage = image
//            }
//            
        }
    }
}
