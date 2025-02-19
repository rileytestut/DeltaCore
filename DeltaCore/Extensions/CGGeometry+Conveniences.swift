//
//  CGGeometry+Conveniences.swift
//  DeltaCore
//
//  Created by Riley Testut on 12/19/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit

internal extension CGRect
{
    init?(dictionary: [String: CGFloat])
    {
        guard
            let x = dictionary["x"],
            let y = dictionary["y"],
            let width = dictionary["width"],
            let height = dictionary["height"]
        else { return nil }
        
        self = CGRect(x: x, y: y, width: width, height: height)
    }
    
    func rounded() -> CGRect
    {
        var frame = self
        frame.origin.x.round()
        frame.origin.y.round()
        frame.size.width.round()
        frame.size.height.round()
        
        return frame
    }
    
    func scaled(to containingFrame: CGRect) -> CGRect
    {
        var frame = self.applying(.init(scaleX: containingFrame.width, y: containingFrame.height))
        frame.origin.x += containingFrame.minX
        frame.origin.y += containingFrame.minY
        
        return frame
    }
}

internal extension CGSize
{
    init?(dictionary: [String: CGFloat])
    {
        guard
            let width = dictionary["width"],
            let height = dictionary["height"]
        else { return nil }
        
        self = CGSize(width: width, height: height)
    }
}

internal extension UIEdgeInsets
{
    init?(dictionary: [String: CGFloat])
    {
        let top = dictionary["top"]
        let bottom = dictionary["bottom"]
        let left = dictionary["left"]
        let right = dictionary["right"]
        
        // Make sure it contains at least one valid value.
        guard top != nil || bottom != nil || left != nil || right != nil else { return nil }
        
        self = UIEdgeInsets(top: top ?? 0, left: left ?? 0, bottom: bottom ?? 0, right: right ?? 0)
    }
}

