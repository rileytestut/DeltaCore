//
//  VideoBufferInfo.swift
//  DeltaCore
//
//  Created by Riley Testut on 4/18/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import CoreGraphics
import CoreImage
import CoreMedia

extension VideoFormat
{
    public enum Format: Equatable
    {
        case bitmap(PixelFormat)
        case openGLES
        
        var pixelFormat: PixelFormat {
            switch self
            {
            case .bitmap(let format): return format
            case .openGLES: return .bgra8
            }
        }
    }
    
    public enum PixelFormat: Equatable
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
        
        public var nativePixelFormat: CMPixelFormatType {
            switch self
            {
            case .rgb565: return kCMPixelFormat_16LE565
            case .bgra8: return kCMPixelFormat_32BGRA
            case .rgba8: return kCVPixelFormatType_32RGBA
            }
        }
    }
}

public struct VideoFormat: Equatable
{
    public var format: Format
    public var dimensions: CGSize
    
    public init(format: Format, dimensions: CGSize)
    {
        self.format = format
        self.dimensions = dimensions
    }
}
