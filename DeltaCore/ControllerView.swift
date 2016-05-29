//
//  ControllerView.swift
//  DeltaCore
//
//  Created by Riley Testut on 5/3/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import UIKit

public class ControllerView: UIView, GameControllerProtocol
{
    //MARK: - Properties -
    /** Properties **/
    public var controllerSkin: ControllerSkin? {
        didSet
        {
            self.setNeedsLayout()
        }
    }
    
    public var currentConfiguration: ControllerSkinConfiguration {
        return ControllerSkinConfiguration(traitCollection: self.traitCollection, containerSize: self.containerView?.bounds.size ?? self.superview?.bounds.size ?? CGSizeZero, targetWidth: self.bounds.width)
    }
    
    public var containerView: UIView?
    
    //MARK: - <GameControllerType>
    /// <GameControllerType>
    public var playerIndex: Int?
    public var inputTransformationHandler: ((GameControllerProtocol, InputType) -> [InputType])?
    public var _stateManager = GameControllerStateManager()
    
    //MARK: - Private Properties
    private let imageView: UIImageView = UIImageView(frame: CGRectZero)
    private var transitionImageView: UIImageView? = nil
    private let controllerDebugView = ControllerDebugView()
    
    private var _performedInitialLayout = false
    
    private var touchInputsMappingDictionary: [UITouch: Set<InputTypeBox>] = [:]
    private var previousTouchInputs = Set<InputTypeBox>()
    private var touchInputs: Set<InputTypeBox> {
        return self.touchInputsMappingDictionary.values.reduce(Set<InputTypeBox>(), combine: { $0.union($1) })
    }
    
    //MARK: - Initializers -
    /** Initializers **/
    public override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        self.initialize()
    }
    
    public required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        self.initialize()
    }
    
    private func initialize()
    {
        self.backgroundColor = UIColor.clearColor()
        
        self.imageView.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
        self.imageView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.imageView.contentMode = .ScaleAspectFit
        self.addSubview(self.imageView)
        
        self.controllerDebugView.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
        self.controllerDebugView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.addSubview(self.controllerDebugView)
        
        self.multipleTouchEnabled = true
    }
    
    //MARK: - Overrides -
    /** Overrides **/
    
    //MARK: - UIView
    /// UIView
    public override func intrinsicContentSize() -> CGSize
    {
        return self.imageView.intrinsicContentSize()
    }
    
    public override func layoutSubviews()
    {
        super.layoutSubviews()
        
        self._performedInitialLayout = true
        
        self.updateControllerSkin()
    }
    
    //MARK: - UIResponder
    /// UIResponder
    public override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        for touch in touches
        {
            self.touchInputsMappingDictionary[touch] = []
        }
        
        self.updateInputsForTouches(touches)
    }
    
    public override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        self.updateInputsForTouches(touches)
    }
    
    public override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        for touch in touches
        {
            self.touchInputsMappingDictionary[touch] = nil
        }
        
        self.updateInputsForTouches(touches)
    }
    
    public override func touchesCancelled(touches: Set<UITouch>?, withEvent event: UIEvent?)
    {
        if let touches = touches
        {
            return self.touchesEnded(touches, withEvent: event)
        }
    }
    
    //MARK: - <UITraitEnvironment>
    /// <UITraitEnvironment>
    public override func traitCollectionDidChange(previousTraitCollection: UITraitCollection?)
    {
        super.traitCollectionDidChange(previousTraitCollection)
        
        self.setNeedsLayout()
    }
}

//MARK: - Update Skins -
/// Update Skins
public extension ControllerView
{
    func beginAnimatingUpdateControllerSkin()
    {
        if self.transitionImageView != nil
        {
            return
        }
        
        let transitionImageView = UIImageView(image: self.imageView.image)
        transitionImageView.frame = self.imageView.frame
        transitionImageView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        transitionImageView.contentMode = .ScaleAspectFit
        transitionImageView.alpha = 1.0
        self.addSubview(transitionImageView)
        
        self.transitionImageView = transitionImageView
        
        self.imageView.alpha = 0.0
    }
    
    func updateControllerSkin()
    {
        guard self._performedInitialLayout else { return }
        
        if let debugModeEnabled = self.controllerSkin?.debugModeEnabled
        {
            self.controllerDebugView.hidden = !debugModeEnabled
        }
        
        self.controllerDebugView.items = self.controllerSkin?.itemsForConfiguration(self.currentConfiguration)
        
        let image = self.controllerSkin?.imageForConfiguration(self.currentConfiguration)
        self.imageView.image = image
        
        self.invalidateIntrinsicContentSize()
        
        if self.transitionImageView != nil
        {
            // Wrap in an animation closure to ensure it actually animates correctly
            // As of iOS 8.3, calling this within transition coordinator animation closure without wrapping
            // in this animation closure causes the change to be instantaneous
            UIView.animateWithDuration(0.0) {
                self.imageView.alpha = 1.0
            }
        }
        else
        {
            self.imageView.alpha = 1.0
        }
        
        self.transitionImageView?.alpha = 0.0
    }
    
    func finishAnimatingUpdateControllerSkin()
    {
        if let transitionImageView = self.transitionImageView
        {
            transitionImageView.removeFromSuperview()
            self.transitionImageView = nil
        }
        
        self.imageView.alpha = 1.0
    }
}

//MARK: - Private Methods -
private extension ControllerView
{
    //MARK: - Activating/Deactivating Inputs
    func updateInputsForTouches(touches: Set<UITouch>)
    {
        guard let controllerSkin = self.controllerSkin else { return }
        
        // Don't add the touches if it has been removed in touchesEnded:/touchesCancelled:
        for touch in touches where self.touchInputsMappingDictionary[touch] != nil
        {
            var point = touch.locationInView(self)
            point.x /= self.bounds.width
            point.y /= self.bounds.height
            
            let inputs = controllerSkin.inputsForPoint(point, configuration: self.currentConfiguration) ?? []
            let boxedInputs = inputs.lazy.flatMap { self.inputTransformationHandler?(self, $0) ?? [$0] }.map { InputTypeBox(input: $0) }
            
            self.touchInputsMappingDictionary[touch] = Set(boxedInputs)
        }
        
        let activatedInputs = self.touchInputs.subtract(self.previousTouchInputs)
        for inputBox in activatedInputs
        {
            self.activate(inputBox.input)
        }
        
        let deactivatedInputs = self.previousTouchInputs.subtract(self.touchInputs)
        for inputBox in deactivatedInputs
        {
            self.deactivate(inputBox.input)
        }
        
        self.previousTouchInputs = self.touchInputs
    }
}