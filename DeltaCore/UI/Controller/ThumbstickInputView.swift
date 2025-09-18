//
//  ThumbstickInputView.swift
//  DeltaCore
//
//  Created by Riley Testut on 4/18/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import simd

class ThumbstickInputView: UIView
{
    var isHapticFeedbackEnabled = true
    
    var valueChangedHandler: ((Double, Double) -> Void)?
    
    var thumbstickImage: UIImage? {
        didSet {
            self.update()
        }
    }
    
    var thumbstickSize: CGSize? {
        didSet {
            self.update()
        }
    }
    
    private let imageView = UIImageView(image: nil)
    private let panGestureRecognizer = ImmediatePanGestureRecognizer(target: nil, action: nil)
    
    private let lightFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    private let rigidFeedbackGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let softFeedbackGenerator = UIImpactFeedbackGenerator(style: .soft)
    
    private var wasActivated = false
    private var wasAtEdge = false
    
    private var trackingOrigin: CGPoint?
    private var previousOctant: Int?
    
    private var isTracking: Bool {
        return self.trackingOrigin != nil
    }
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        self.panGestureRecognizer.addTarget(self, action: #selector(ThumbstickInputView.handlePanGesture(_:)))
        self.panGestureRecognizer.delaysTouchesBegan = true
        self.panGestureRecognizer.cancelsTouchesInView = true
        self.addGestureRecognizer(self.panGestureRecognizer)
        
        self.addSubview(self.imageView)
        
        self.update()
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews()
    {
        super.layoutSubviews()
        
        self.update()
    }
}

private extension ThumbstickInputView
{
    @objc func handlePanGesture(_ gestureRecognizer: UIPanGestureRecognizer)
    {
        switch gestureRecognizer.state
        {
        case .began:
            let location = gestureRecognizer.location(in: self)
            self.trackingOrigin = location
            
            if self.isHapticFeedbackEnabled
            {
                self.lightFeedbackGenerator.prepare()
                self.rigidFeedbackGenerator.prepare()
                self.softFeedbackGenerator.prepare()
            }
            
            self.update()
            
        case .changed:
            // When initially tracking the gesture, we calculate the translation
            // relative to where the user began the pan gesture.
            // This works well, but becomes weird once we leave the bounds then return later,
            // since it's more obvious at that point if the thumbstick position doesn't match the user's finger.
            //
            // To compensate, once we've left the bounds (and have reached maximum translation),
            // we reset the origin we're using for calculation to 0.
            // This won't change the visual position of the thumbstick since it's snapped to the edge,
            // but will correctly track user's finger upon re-entering the bounds.
            
            guard var origin = self.trackingOrigin else { break }

            let location = gestureRecognizer.location(in: self)
            let translationX = location.x - origin.x
            let translationY = location.y - origin.y

            let x = origin.x + translationX
            let y = origin.y + translationY
            
            let horizontalRange = self.bounds.minX...self.bounds.maxX
            let verticalRange = self.bounds.minY...self.bounds.maxY
            
            if !horizontalRange.contains(x) && abs(translationX) >= self.bounds.midX
            {
                origin.x = self.bounds.midX
            }

            if !verticalRange.contains(y) && abs(translationY) >= self.bounds.midY
            {
                origin.y = self.bounds.midY
            }

            let translation = CGPoint(x: translationX, y: translationY)
            self.update(translation)
            
            self.trackingOrigin = origin
            
        case .ended, .cancelled:
            
            if self.isHapticFeedbackEnabled
            {
                self.lightFeedbackGenerator.impactOccurred()
            }
            
            self.update()
            
            self.trackingOrigin = nil
            self.wasActivated = false
            self.previousOctant = nil
            
        default: break
        }
    }
    
    func update(_ translation: CGPoint = CGPoint(x: 0, y: 0))
    {
        let center = SIMD2(Double(self.bounds.midX), Double(self.bounds.midY))
        let point = SIMD2(Double(translation.x), Double(translation.y))
        
        self.imageView.image = self.thumbstickImage
        
        if let size = self.thumbstickSize
        {
            self.imageView.bounds.size = CGSize(width: size.width, height: size.height)
        }
        else
        {
            self.imageView.sizeToFit()
        }
        
        guard !self.bounds.isEmpty, self.isTracking else {
            self.imageView.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
            return
        }
        
        let maximumDistance = Double(self.bounds.midX)
        let distance = min(simd_length(point), maximumDistance)
        
        let angle = atan2(point.y, point.x)
        
        var adjustedX = distance * cos(angle)
        adjustedX += center.x
        
        var adjustedY = distance * sin(angle)
        adjustedY += center.y
        
        let innerDeadzone = 0.1
        let outerDeadzone = 0.99
        
        // Invert Y coordinate
        var xAxis = (adjustedX / maximumDistance) - 1
        var yAxis = ((adjustedY / maximumDistance) - 1) * -1
        
        // Keep within the bounds
        xAxis = getBoundedValue(xAxis)
        yAxis = getBoundedValue(yAxis)
        
        var magnitude = sqrt(xAxis * xAxis + yAxis * yAxis)
        
        // This should really always be bounded, but just in case
        magnitude = getBoundedValue(magnitude)
        
        let isActivated = magnitude > innerDeadzone
        let isAtEdge = magnitude > outerDeadzone
        
        // Compare against magnitude; inner deadzone should be a circle
        if !isActivated
        {
            xAxis = 0
            yAxis = 0
        }
        
        // Play haptics when:
        // - Stick is moved away from the deadzone (soft)
        // - Stick is returned to the deadzone (soft)
        // - Stick is released after being outside the deadzone (light)
        
        if (isActivated && !self.wasActivated)
        {
            self.softFeedbackGenerator.impactOccurred()
        }
        
        if (!isActivated && self.wasActivated)
        {
            if (magnitude > 0.001)
            {
                self.softFeedbackGenerator.impactOccurred()
            }
            else
            {
                self.lightFeedbackGenerator.impactOccurred()
            }
        }
        
        // Must covert angle, otherwise the bump between from octants 7 and 0 will have no haptic
        let theta = getTheta(angle)
        let octant = isActivated ? getOctant(theta) : nil
        let hasOctantChanged = self.previousOctant != nil && octant != nil && self.previousOctant != octant
        
        // Play haptics when:
        // - Stick is at edge but was not previously (rigid)
        // - Stick is "clicking" along the edge from one octant to another (rigid)
        // - Stick is "clicking" inside the edge from one octant to another (soft)
        
        if (isAtEdge && !self.wasAtEdge)
        {
            self.rigidFeedbackGenerator.impactOccurred()
        }
        
        if hasOctantChanged
        {
            if isAtEdge
            {
                self.rigidFeedbackGenerator.impactOccurred()
            }
            else
            {
                self.softFeedbackGenerator.impactOccurred()
            }
        }
        
        self.wasActivated = isActivated
        self.wasAtEdge = isAtEdge
        
        self.previousOctant = octant

        self.imageView.center = CGPoint(x: adjustedX, y: adjustedY)
        self.valueChangedHandler?(xAxis, yAxis)
    }
    
    // Bounds value from -1 to 1
    private func getBoundedValue(_ value: Double) -> Double
    {
        var boundedValue = max(value, -1)
        return min(boundedValue, 1)
    }
    
    // Converts angle bounded from (-pi, pi) to (0, 2pi)
    private func getTheta(_ angle: Double) -> Double
    {
        return angle < 0 ? angle + (2 * Double.pi) : angle
    }
    
    // Get octant where (0, theta/4) is octant 0
    private func getOctant(_ theta: Double) -> Int
    {
        return (Int) (4 / Double.pi * theta)
    }
}
