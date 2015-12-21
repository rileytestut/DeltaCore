//
//  ControllerDebugView.swift
//  DeltaCore
//
//  Created by Riley Testut on 12/20/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit
import Foundation

internal class ControllerDebugView: UIView
{
    var items: [ControllerSkin.Item]? {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        self.initialize()
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        self.initialize()
    }
    
    private func initialize()
    {
        self.backgroundColor = UIColor.clearColor()
        self.userInteractionEnabled = false
    }
    
    override func drawRect(rect: CGRect)
    {
        guard let items = self.items else { return }
        
        for item in items
        {
            var frame = item.extendedFrame
            frame.origin.x *= self.bounds.width
            frame.origin.y *= self.bounds.height
            frame.size.width *= self.bounds.width
            frame.size.height *= self.bounds.height
            
            UIColor.redColor().colorWithAlphaComponent(0.75).setFill()
            UIRectFill(frame)
            
            var text = ""
            
            for key in item.keys
            {
                if text.isEmpty
                {
                    text = key
                }
                else
                {
                    text = text + "," + key
                }
            }
            
            let attributes = [NSForegroundColorAttributeName: UIColor.whiteColor(), NSFontAttributeName: UIFont.boldSystemFontOfSize(16)]
            let textSize = (text as NSString).sizeWithAttributes(attributes)
            
            let point = CGPoint(x: frame.midX - textSize.width / 2.0, y: frame.midY - textSize.height / 2.0)
            (text as NSString).drawAtPoint(point, withAttributes: attributes)
        }
    }
    
}
