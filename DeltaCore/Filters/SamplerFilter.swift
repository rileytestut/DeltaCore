//
//  SamplerFilter.swift
//  DeltaCore
//
//  Created by Riley Testut on 4/13/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import CoreImage

public enum SamplerMode
{
    case linear
    case nearestNeighbor
}

extension SamplerMode: RawRepresentable
{
    public var rawValue: String {
        switch self
        {
        case .linear: return kCISamplerFilterLinear
        case .nearestNeighbor: return kCISamplerFilterNearest
        }
    }
    
    public init?(rawValue: String)
    {
        switch rawValue
        {
        case kCISamplerFilterLinear: self = .linear
        case kCISamplerFilterNearest: self = .nearestNeighbor
        default: return nil
        }
    }
}

@objcMembers
internal class SamplerFilter: CIFilter
{
    internal var inputMode: SamplerMode = .nearestNeighbor
    internal var inputImage: CIImage?
    
    internal override var outputImage: CIImage? {
        guard let inputImage = self.value(forKey: kCIInputImageKey) as? CIImage else { return nil }
        
        let sampler = CISampler(image: inputImage, options: [kCISamplerFilterMode: self.inputMode.rawValue])
        
        let outputImage = self.kernel.apply(extent: inputImage.extent, arguments: [sampler])
        return outputImage
    }
    
    private let kernel: CIColorKernel
    
    internal override init()
    {
        let code = "kernel vec4 do_nothing(__sample s) { return s.rgba; }"
        self.kernel = CIColorKernel(source: code)!
        
        super.init()
    }
    
    internal required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
}
