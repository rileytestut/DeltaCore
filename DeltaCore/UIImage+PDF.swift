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
    class func imageWithPDFData(_ data: Data, targetWidth: CGFloat) -> UIImage?
    {
        guard targetWidth > 0 else { return nil }
        
        let dataProvider = CGDataProvider(data: data as CFData)
        
        guard let document = CGPDFDocument(dataProvider!) else { return nil }
        
        let page = document.page(at: 1)
        let pageFrame = page?.getBoxRect(.cropBox)
        
        let targetSize = CGSize(width: targetWidth, height: ((pageFrame?.height)! / (pageFrame?.width)!) * targetWidth)
        
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
        
        let context = UIGraphicsGetCurrentContext()
        
        // Save state
        context?.saveGState()
        
        // Flip coordinate system to match Quartz system
        var transform = CGAffineTransform.identity
        transform = transform.scaleBy(x: 1.0, y: -1.0)
        transform = transform.translateBy(x: 0.0, y: -targetSize.height)
        context?.concatCTM(transform)
        
        // Calculate rendering frames
        var destinationFrame = CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height)
        destinationFrame = destinationFrame.apply(transform: transform)
    
        let aspectScale = min(destinationFrame.width / (pageFrame?.width)!, destinationFrame.height / (pageFrame?.height)!)
        
        // Ensure aspect ratio is preserved
        var drawingFrame = pageFrame?.apply(transform: CGAffineTransform(scaleX: aspectScale, y: aspectScale))
        drawingFrame?.origin.x = destinationFrame.midX - (drawingFrame!.width / 2.0)
        drawingFrame?.origin.y = destinationFrame.midY - (drawingFrame!.height / 2.0)
        
        // Scale the context
        context?.translate(x: destinationFrame.minX, y: destinationFrame.minY)
        context?.scale(x: aspectScale, y: aspectScale)
        
        // Render the PDF
        context?.drawPDFPage(page!)
        
        // Restore state
        context?.restoreGState()
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return image
    }
}
