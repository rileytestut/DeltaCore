//
//  VideoBufferInfo.swift
//  DeltaCore
//
//  Created by Riley Testut on 4/18/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation

extension VideoBufferInfo
{
    public enum Format
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
    }
}

public struct VideoBufferInfo
{
    public let format: Format
    public let dimensions: CGSize
    
    public var size: Int {
        return Int(self.dimensions.width * self.dimensions.height) * self.format.bytesPerPixel
    }
    
    public init(format: Format, dimensions: CGSize)
    {
        self.format = format
        self.dimensions = dimensions
    }
}
