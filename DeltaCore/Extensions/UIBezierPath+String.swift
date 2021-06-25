//
//  UIBezierPath+String.swift
//  DeltaCore
//
//  Created by Riley Testut on 6/18/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import UIKit

@available(iOS 15, *)
extension UIBezierPath
{
    convenience init?(string: String)
    {
        let font: UIFont
        
        let systemFont = UIFont.systemFont(ofSize: 10, weight: .semibold)
        if let descriptor = systemFont.fontDescriptor.withDesign(.rounded)
        {
            font = UIFont(descriptor: descriptor, size: 10)
        }
        else
        {
            font = systemFont
        }
        
        var characters: [UniChar] = string.flatMap { $0.utf16 }
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)
        
        guard CTFontGetGlyphsForCharacters(font, &characters, &glyphs, characters.count) else { return nil }
        
        self.init()
        self.usesEvenOddFillRule = true
        
        for glyph in glyphs
        {
            guard let cgPath = CTFontCreatePathForGlyph(font, glyph, nil) else { return nil }
            
            let path = UIBezierPath(cgPath: cgPath)
                        
            if self.bounds.origin.x == .infinity
            {
                // Origin defaults to infinity, which messes up calculations.
                let midpoint = CGPoint(x: path.bounds.midX, y: path.bounds.midY)
                self.move(to: midpoint)
            }
            else
            {
                let difference = path.bounds.midX - self.bounds.origin.x
                path.apply(.identity.translatedBy(x: (-difference + self.bounds.width + path.bounds.midX + 1), y: 0))
            }
            
            self.append(path)
        }
        
        var rect = CGRect.zero
        
        if self.bounds.width > self.bounds.height
        {
            let difference = self.bounds.width - self.bounds.height
            rect = self.bounds.insetBy(dx: -5, dy: -(difference/2 + 5))
        }
        else
        {
            let difference = self.bounds.height - self.bounds.width
            rect = self.bounds.insetBy(dx: -(difference/2 + 5), dy: -5)
        }
        
        let borderPath = UIBezierPath(ovalIn: rect)
        self.append(borderPath)
        
        let transform = CGAffineTransform.identity.translatedBy(x: -self.bounds.midX, y: -self.bounds.midY)
        self.apply(transform)
    }
}
