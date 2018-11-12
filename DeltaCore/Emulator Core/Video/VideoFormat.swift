//
//  VideoBufferInfo.swift
//  DeltaCore
//
//  Created by Riley Testut on 4/18/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import CoreGraphics
import CoreImage

extension VideoFormat
{
    public enum PixelFormat
    {
        case rgb565
        case bgra8
        case rgba8
        
        public var bytesPerPixel: Int {
            switch self
            {
            case .rgb565: return 2
            case .bgra8: return 4
            case .rgba8: return 4
            }
        }
        
        internal var nativeCIFormat: CIFormat? {
            switch self
            {
            case .rgb565: return nil
            case .bgra8: return .BGRA8
            case .rgba8: return .RGBA8
            }
        }
    }
}

public struct VideoFormat
{
    public let pixelFormat: PixelFormat
    public let dimensions: CGSize
    
    public var bufferSize: Int {
        return Int(self.dimensions.width * self.dimensions.height) * self.pixelFormat.bytesPerPixel
    }
    
    public init(pixelFormat: PixelFormat, dimensions: CGSize)
    {
        self.pixelFormat = pixelFormat
        self.dimensions = dimensions
    }
}
