//
//  UIImage+PDF.swift
//  DeltaCore
//
//  Created by Riley Testut on 12/21/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//
//  Based on Erica Sadun's UIImage+PDFUtility ( https://github.com/erica/useful-things/blob/master/useful%20pack/UIImage%2BPDF/UIImage%2BPDFUtility.m )
//

import UIKit
import CoreGraphics

internal extension UIImage
{
    class func imageWithPDFData(data: NSData, targetWidth: CGFloat) -> UIImage?
    {
        guard targetWidth > 0 else { return nil }
        
        let dataProvider = CGDataProviderCreateWithCFData(data as CFDataRef)
        
        guard let document = CGPDFDocumentCreateWithProvider(dataProvider) else { return nil }
        
        let page = CGPDFDocumentGetPage(document, 1)
        let pageFrame = CGPDFPageGetBoxRect(page, .CropBox)
        
        let targetSize = CGSize(width: targetWidth, height: (pageFrame.height / pageFrame.width) * targetWidth)
        
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
        
        let context = UIGraphicsGetCurrentContext()
        
        // Save state
        CGContextSaveGState(context)
        
        // Flip coordinate system to match Quartz system
        var transform = CGAffineTransformIdentity
        transform = CGAffineTransformScale(transform, 1.0, -1.0)
        transform = CGAffineTransformTranslate(transform, 0.0, -targetSize.height)
        CGContextConcatCTM(context, transform)
        
        // Calculate rendering frames
        var destinationFrame = CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height)
        destinationFrame = CGRectApplyAffineTransform(destinationFrame, transform)
    
        let aspectScale = min(destinationFrame.width / pageFrame.width, destinationFrame.height / pageFrame.height)
        
        // Ensure aspect ratio is preserved
        var drawingFrame = CGRectApplyAffineTransform(pageFrame, CGAffineTransformMakeScale(aspectScale, aspectScale))
        drawingFrame.origin.x = destinationFrame.midX - (drawingFrame.width / 2.0)
        drawingFrame.origin.y = destinationFrame.midY - (drawingFrame.height / 2.0)
        
        // Scale the context
        CGContextTranslateCTM(context, destinationFrame.minX, destinationFrame.minY)
        CGContextScaleCTM(context, aspectScale, aspectScale)
        
        // Render the PDF
        CGContextDrawPDFPage(context, page)
        
        // Restore state
        CGContextRestoreGState(context)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return image
    }
}
