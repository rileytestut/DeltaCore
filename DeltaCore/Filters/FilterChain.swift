//
//  FilterChain.swift
//  DeltaCore
//
//  Created by Riley Testut on 4/13/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import CoreImage

private extension CIImage
{
    func flippingYAxis() -> CIImage
    {
        let transform = CGAffineTransform(scaleX: 1, y: -1)
        let flippedImage = self.applyingFilter("CIAffineTransform", parameters: ["inputTransform": NSValue(cgAffineTransform: transform)])
        
        let translation = CGAffineTransform(translationX: 0, y: self.extent.height)
        let translatedImage = flippedImage.applyingFilter("CIAffineTransform", parameters: ["inputTransform": NSValue(cgAffineTransform: translation)])
        
        return translatedImage
    }
}

private extension CIFilter
{
    struct Values: Hashable
    {
        var name: String
        var inputValues: NSDictionary
        
        static func ==(lhs: Values, rhs: Values) -> Bool
        {
            return lhs.name == rhs.name && lhs.inputValues.isEqual(rhs.inputValues)
        }
        
        func hash(into hasher: inout Hasher)
        {
            hasher.combine(self.name)
            hasher.combine(self.inputValues)
        }
    }
    
    func values() -> Values
    {
        let inputValues = self.inputKeys.compactMap { (key) -> (String, Any)? in
            // Ignore inputImage value, since that shouldn't affect CIFilter equality.
            // Filters with same inputKeys + values should always be equal, even with different inputImages.
            guard let value = self.value(forKey: key), key != kCIInputImageKey else { return nil }
            return (key, value)
        }
        
        let dictionary = inputValues.reduce(into: [:]) { $0[$1.0] = $1.1 }
        
        let values = Values(name: self.name, inputValues: dictionary as NSDictionary)
        return values
    }
}

@objcMembers
public class FilterChain: CIFilter
{
    public var inputFilters = [CIFilter]()
    
    public var inputImage: CIImage?
    
    public override var outputImage: CIImage? {
        return self.inputFilters.reduce(self.inputImage, { (image, filter) -> CIImage? in
            guard let image = image else { return nil }
            
            let flippedImage = image.flippingYAxis()
                        
            var outputImage: CIImage?
            
            if filter.inputKeys.contains(kCIInputImageKey)
            {
                filter.setValue(flippedImage, forKey: kCIInputImageKey)
                outputImage = filter.outputImage
            }
            else
            {
                guard var filterImage = filter.outputImage else { return image }
                
                if filterImage.extent.isInfinite
                {
                    filterImage = filterImage.cropped(to: flippedImage.extent)
                }
                
                // Filter is already "flipped", so no need to flip it again.
                // filterImage = filterImage.flippingYAxis()
                          
                outputImage = filterImage.composited(over: flippedImage)
            }
            
            outputImage = outputImage?.flippingYAxis()
            
            if let image = outputImage, image.extent.origin != .zero
            {
                // Always translate CIImage back to origin so later calculations are correct.
                let translation = CGAffineTransform(translationX: -image.extent.origin.x, y: -image.extent.origin.y)
                outputImage = image.applyingFilter("CIAffineTransform", parameters: ["inputTransform": NSValue(cgAffineTransform: translation)])
            }
            
            return outputImage
        })
    }
    
    public override var hash: Int {
        return self.inputFiltersValues.hashValue
    }
    
    private var inputFiltersValues: [CIFilter.Values] {
        let values = self.inputFilters.map { $0.values() }
        return values
    }
    
    public override init()
    {
        // Must be declared or else we'll get "Use of unimplemented initializer FilterChain.init()" runtime exception.
        super.init()
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
    
    public override func isEqual(_ object: Any?) -> Bool
    {
        guard let filterChain = object as? FilterChain else { return false }
                
        let isEqual = self.inputFiltersValues == filterChain.inputFiltersValues
        return isEqual
    }
}
