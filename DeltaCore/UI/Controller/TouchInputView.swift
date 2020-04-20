//
//  TouchInputView.swift
//  DeltaCore
//
//  Created by Riley Testut on 8/4/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit

class TouchInputView: UIView
{
    var valueChangedHandler: ((CGPoint?) -> Void)?
    
    private let panGestureRecognizer = ImmediatePanGestureRecognizer(target: nil, action: nil)
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        self.panGestureRecognizer.addTarget(self, action: #selector(TouchInputView.handlePanGesture(_:)))
        self.panGestureRecognizer.delaysTouchesBegan = true
        self.panGestureRecognizer.cancelsTouchesInView = true
        self.addGestureRecognizer(self.panGestureRecognizer)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension TouchInputView
{
    @objc func handlePanGesture(_ gestureRecognizer: UIPanGestureRecognizer)
    {
        switch gestureRecognizer.state
        {
        case .began, .changed:
            let location = gestureRecognizer.location(in: self)
            
            var adjustedLocation = CGPoint(x: location.x / self.bounds.width, y: location.y / self.bounds.height)
            adjustedLocation.x = min(max(adjustedLocation.x, 0), 1)
            adjustedLocation.y = min(max(adjustedLocation.y, 0), 1)
            
            self.valueChangedHandler?(adjustedLocation)
            
        case .ended, .cancelled:
            self.valueChangedHandler?(nil)
            
        default: break
        }
    }
}
