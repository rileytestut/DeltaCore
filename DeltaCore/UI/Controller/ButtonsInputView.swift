//
//  ButtonsInputView.swift
//  DeltaCore
//
//  Created by Riley Testut on 8/4/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import CoreImage.CIFilterBuiltins

class ButtonsInputView: UIView
{
    var isHapticFeedbackEnabled = true
    
    var items: [ControllerSkin.Item]?
    
    var activateInputsHandler: ((Set<AnyInput>) -> Void)?
    var deactivateInputsHandler: ((Set<AnyInput>) -> Void)?
    
    var activateItemsHandler: ((Set<ControllerSkin.Item>) -> Void)?
    var deactivateItemsHandler: ((Set<ControllerSkin.Item>) -> Void)?
    
    var image: UIImage? {
        didSet {
            self.ciImage = self.image.flatMap { CIImage(image: $0) }
            self.imageView.image = self.image
        }
    }
    
    var pressedImage: UIImage? {
        didSet {
            self.pressedCIImage = self.pressedImage.flatMap { CIImage(image: $0) }
        }
    }
    
    private var ciImage: CIImage?
    private var pressedCIImage: CIImage?
    
    private let imageView = UIImageView(frame: .zero)
    
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    private var touchInputsMappingDictionary: [UITouch: Set<AnyInput>] = [:]
    private var previousTouchInputs = Set<AnyInput>()
    private var touchInputs: Set<AnyInput> {
        return self.touchInputsMappingDictionary.values.reduce(Set<AnyInput>(), { $0.union($1) })
    }
    
    private var activeTouchItems = Set<ControllerSkin.Item>()
    
    override var intrinsicContentSize: CGSize {
        return self.imageView.intrinsicContentSize
    }
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        self.isMultipleTouchEnabled = true
        
        self.feedbackGenerator.prepare()
        
        self.imageView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.imageView)
        
        NSLayoutConstraint.activate([self.imageView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                                     self.imageView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                                     self.imageView.topAnchor.constraint(equalTo: self.topAnchor),
                                     self.imageView.bottomAnchor.constraint(equalTo: self.bottomAnchor)])
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        for touch in touches
        {
            self.touchInputsMappingDictionary[touch] = []
        }
        
        self.updateInputs(for: touches)
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        self.updateInputs(for: touches)
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        for touch in touches
        {
            self.touchInputsMappingDictionary[touch] = nil
        }
        
        self.updateInputs(for: touches)
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        return self.touchesEnded(touches, with: event)
    }
}

extension ButtonsInputView
{
    func items(at point: CGPoint) -> [ControllerSkin.Item]?
    {
        guard let allItems = self.items else { return nil }
        
        var point = point
        point.x /= self.bounds.width
        point.y /= self.bounds.height
        
        let items = allItems.filter { $0.extendedFrame.contains(point) }
        return items
    }
    
    func inputs(at point: CGPoint) -> [Input]?
    {
        guard let items = self.items(at: point) else { return nil }
        
        var point = point
        point.x /= self.bounds.width
        point.y /= self.bounds.height
        
        var inputs: [Input] = []
        
        for item in items
        {
            switch item.inputs
            {
            // Don't return inputs for thumbsticks or touch screens since they're handled separately.
            case .directional where item.kind == .thumbstick: break
            case .touch: break
                
            case .standard(let itemInputs):
                inputs.append(contentsOf: itemInputs)
            
            case let .directional(up, down, left, right):

                let divisor: CGFloat
                if case .thumbstick = item.kind
                {
                    divisor = 2.0
                }
                else
                {
                    divisor = 3.0
                }
                
                let topRect = CGRect(x: item.extendedFrame.minX, y: item.extendedFrame.minY, width: item.extendedFrame.width, height: (item.frame.height / divisor) + (item.frame.minY - item.extendedFrame.minY))
                let bottomRect = CGRect(x: item.extendedFrame.minX, y: item.frame.maxY - item.frame.height / divisor, width: item.extendedFrame.width, height: (item.frame.height / divisor) + (item.extendedFrame.maxY - item.frame.maxY))
                let leftRect = CGRect(x: item.extendedFrame.minX, y: item.extendedFrame.minY, width: (item.frame.width / divisor) + (item.frame.minX - item.extendedFrame.minX), height: item.extendedFrame.height)
                let rightRect = CGRect(x: item.frame.maxX - item.frame.width / divisor, y: item.extendedFrame.minY, width: (item.frame.width / divisor) + (item.extendedFrame.maxX - item.frame.maxX), height: item.extendedFrame.height)
                
                if topRect.contains(point)
                {
                    inputs.append(up)
                }
                
                if bottomRect.contains(point)
                {
                    inputs.append(down)
                }
                
                if leftRect.contains(point)
                {
                    inputs.append(left)
                }
                
                if rightRect.contains(point)
                {
                    inputs.append(right)
                }
            }
        }
        
        return inputs
    }
}

private extension ButtonsInputView
{
    func updateInputs(for touches: Set<UITouch>)
    {
        var activeTouchItems = Set<ControllerSkin.Item>()
        
        // Don't add the touches if it has been removed in touchesEnded:/touchesCancelled:
        for touch in touches where self.touchInputsMappingDictionary[touch] != nil
        {
            guard touch.view == self else { continue }
            
            let point = touch.location(in: self)
            let inputs = Set((self.inputs(at: point) ?? []).map { AnyInput($0) })
            
            let menuInput = AnyInput(stringValue: StandardGameControllerInput.menu.stringValue, intValue: nil, type: .controller(.controllerSkin))
            if inputs.contains(menuInput)
            {
                // If the menu button is located at this position, ignore all other inputs that might be overlapping.
                self.touchInputsMappingDictionary[touch] = [menuInput]
            }
            else
            {
                self.touchInputsMappingDictionary[touch] = Set(inputs)
            }
        }
        
        for (touch, _) in self.touchInputsMappingDictionary
        {
            guard touch.view == self else { continue }
            
            let point = touch.location(in: self)
            
            if let items = self.items(at: point)
            {
                activeTouchItems.formUnion(items)
            }
        }
        
        let shouldUpdateImage = (activeTouchItems != self.activeTouchItems)
        
        let activatedInputs = self.touchInputs.subtracting(self.previousTouchInputs)
        let deactivatedInputs = self.previousTouchInputs.subtracting(self.touchInputs)
        
        let previousActiveTouchItems = self.activeTouchItems.filter { $0.kind != .dPad } // D-pad reports continuous changes, so exclude from previous active touches so we can "activate" it again
        let activatedItems = activeTouchItems.subtracting(previousActiveTouchItems)
        let deactivatedItems = self.activeTouchItems.subtracting(activeTouchItems)
        
        // We must update previousTouchInputs *before* calling activate() and deactivate().
        // Otherwise, race conditions that cause duplicate touches from activate() or deactivate() calls can result in various bugs.
        self.previousTouchInputs = self.touchInputs
        
        if !activatedInputs.isEmpty
        {
            self.activateInputsHandler?(activatedInputs)
            
            if self.isHapticFeedbackEnabled
            {
                switch UIDevice.current.feedbackSupportLevel
                {
                case .feedbackGenerator: self.feedbackGenerator.impactOccurred()
                case .basic, .unsupported: UIDevice.current.vibrate()
                }
            }
        }
        
        if !deactivatedInputs.isEmpty
        {
            self.deactivateInputsHandler?(deactivatedInputs)
        }
        
        if !activatedItems.isEmpty
        {
            self.activateItemsHandler?(activatedItems)
        }
        
        if !deactivatedItems.isEmpty
        {
            self.deactivateItemsHandler?(deactivatedItems)
        }
        
        // Update image
        
        if shouldUpdateImage, var backgroundImage = self.ciImage, var foregroundImage = self.pressedCIImage
        {
            // We use a mask to selectively replace contents of background image (default image) with foreground image (pressed image).
            
            backgroundImage = backgroundImage.transformed(by: .init(translationX: -backgroundImage.extent.origin.x, y: -backgroundImage.extent.origin.y)) // Move origin to (0,0)
            
            // Scale foreground image to match background image scale
            let scaleX = backgroundImage.extent.width / foregroundImage.extent.width
            let scaleY = backgroundImage.extent.height / foregroundImage.extent.height
            foregroundImage = foregroundImage.transformed(by: .init(scaleX: scaleX, y: scaleY))
            foregroundImage = foregroundImage.transformed(by: .init(translationX: -foregroundImage.extent.origin.x, y: -foregroundImage.extent.origin.y)) // Move origin to (0,0)
            
            var ciimage = backgroundImage
            let clearImage = CIImage(color: .clear).cropped(to: backgroundImage.extent)
            
            // Loop over active items, iteratively mask in inputs from pressed image.
            for activeItem in activeTouchItems
            {
                // Define the rectangle to mask out (i.e. make transparent)
                var itemFrame = activeItem.frame.applying(.init(scaleX: ciimage.extent.width, y: ciimage.extent.height))
                itemFrame.origin.y = ciimage.extent.height - itemFrame.origin.y - itemFrame.height // Invert coordinates
                itemFrame.origin.x += ciimage.extent.origin.x
                itemFrame.origin.y += ciimage.extent.origin.y
                
                let shapeImage: CIImage
                
                switch activeItem.mask
                {
                case .rectangle:
                    shapeImage = CIImage(color: .white).cropped(to: itemFrame)
                    
                case .circle:
                    let center = CGPoint(x: itemFrame.midX, y: itemFrame.midY)
                    let radius = Float(itemFrame.width / 2.0)
                    
                    let radialGradient = CIFilter.radialGradient()
                    radialGradient.center = center
                    radialGradient.radius0 = radius
                    radialGradient.radius1 = radius + 1
                    radialGradient.color0 = .white
                    radialGradient.color1 = .clear
                    
                    shapeImage = radialGradient.outputImage!.cropped(to: ciimage.extent)
                }
                
                let maskImage = shapeImage.composited(over: clearImage)
                
                let filter = CIFilter.blendWithAlphaMask()
                filter.inputImage = foregroundImage
                filter.backgroundImage = ciimage
                filter.maskImage = maskImage
                
                guard let maskedImage = filter.outputImage else { break }
                ciimage = maskedImage
            }
            
            let uiimage = UIImage(ciImage: ciimage)
            self.imageView.image = uiimage
        }
        
        self.activeTouchItems = activeTouchItems
    }
    
//    func updateItems()
//    {
//        guard let controllerSkin else { return }
//        
//        var buttonImageViews: [ControllerSkin.Item.ID: UIImageView] = [:]
//        var previousButtonImageViews = self.buttonImageViews
//        
//        for item in self.items ?? []
//        {
//            switch item.kind
//            {
//            case .button:
//                guard let image = controllerSkin.image(for: item, traits: tra, preferredSize: <#T##ControllerSkin.Size#>)
//                
//                let imageView: UIImageView
//                
//                if let previousImageView = previousButtonImageViews[item.id]
//                {
//                    imageView = previousImageView
//                    previousButtonImageViews[item.id] = nil
//                }
//                else
//                {
//                    imageView = UIImageView(frame: .zero)
//                    self.addSubview(imageView)
//                }
//                
//                //                thumbstickView.valueChangedHandler = { [weak self] (xAxis, yAxis) in
//                //                    self?.updateThumbstickValues(item: item, xAxis: xAxis, yAxis: yAxis)
//                //                }
//                
//                // Calculate correct `thumbstickSize` in layoutSubviews().
//                //                thumbstickView.thumbstickSize = nil
//                //
//                //                thumbstickView.isHapticFeedbackEnabled = self.isThumbstickHapticFeedbackEnabled
//                
//                buttonImageViews[item.id] = imageView
//                
//            case .dPad: break
//            case .thumbstick: break
//            case .touchScreen: break
//            }
//        }
//        
//        previousButtonImageViews.values.forEach { $0.removeFromSuperview() }
//        self.buttonImageViews = buttonImageViews
//        
//        self.setNeedsLayout()
//    }
}
