//
//  FilterChain.swift
//  DeltaCore
//
//  Created by Riley Testut on 4/13/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import CoreImage

@objcMembers
public class FilterChain: CIFilter
{
    public var inputFilters = [CIFilter]()
    
    public var inputImage: CIImage?
    
    public override var outputImage: CIImage? {
        return self.inputFilters.reduce(self.inputImage, { (image, filter) -> CIImage? in
            guard let image = image else { return nil }
            filter.setValue(image, forKey: kCIInputImageKey)
            return filter.outputImage
        })
    }
    
    public init(filters: [CIFilter])
    {
        self.inputFilters = filters
        super.init()
    }
    
    public required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
    }
}
