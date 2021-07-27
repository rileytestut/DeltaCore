//
//  IOSurface+VideoRendering.swift
//  IOSurface+VideoRendering
//
//  Created by Riley Testut on 7/26/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation
import IOSurface
import CoreGraphics

extension IOSurface
{
    var isYAxisFlipped: Bool {
        get {
            guard let isYAxisFlipped = self.attachment(forKey: "delta_isYAxisFlipped") as? Bool else { return false }
            return isYAxisFlipped
        }
        set {
            self.setAttachment(newValue, forKey: "delta_isYAxisFlipped")
        }
    }
    
    var viewport: CGRect? {
        get {
            guard let string = self.attachment(forKey: "delta_viewport") as? String else { return nil }
            
            let cgRect = NSCoder.cgRect(for: string)
            return cgRect
        }
        set {
            let string = newValue.map { NSCoder.string(for: $0) }
            self.setAttachment(string as Any, forKey: "delta_viewport")
        }
    }
}
