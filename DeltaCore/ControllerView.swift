//
//  ControllerView.swift
//  DeltaCore
//
//  Created by Riley Testut on 5/3/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import UIKit

public class ControllerView: UIView
{
    //MARK: - Properties -
    /** Properties **/
    public var controllerSkin: ControllerSkin? {
        didSet
        {
            self.updateControllerSkin()
        }
    }
    public var activatedInputs: [InputType] {
        return self.activatedInputBoxes.map({ $0.input })
    }
    public var currentConfiguration: ControllerSkinConfiguration {
        return ControllerSkinConfiguration(traitCollection: self.traitCollection, containerSize: self.containerView?.bounds.size ?? self.superview?.bounds.size ?? CGSizeZero)
    }
    
    public var containerView: UIView?
    
    //MARK: - <GameControllerType>
    /// <GameControllerType>
    public var playerIndex: Int?
    public var inputTransformationHandler: (InputType -> [InputType])?
    
    public var receivers: [GameControllerReceiverType] {
        return self.privateReceivers.allObjects.map({ $0 as! GameControllerReceiverType })
    }
    
    //MARK: - Private Properties
    private let imageView: UIImageView = UIImageView(frame: CGRectZero)
    private var transitionImageView: UIImageView? = nil
    private let controllerDebugView = ControllerDebugView()
    
    private var touchesInputsMappingDictionary: [UITouch: Set<InputTypeBox>] = [:]
    private var previousActivatedInputs: Set<InputTypeBox> = []
    
    // Should only be used for modifying receivers. Otherwise, use `receivers`
    private let privateReceivers = NSHashTable.weakObjectsHashTable()
    
    private var activatedInputBoxes: Set<InputTypeBox> {
        var activatedInputs: Set<InputTypeBox> = []
        for inputs in self.touchesInputsMappingDictionary.values
        {
            activatedInputs.unionInPlace(inputs)
        }
        
        return activatedInputs
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
    
    //MARK: - UIResponder
    /// UIResponder
    public override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        for touch in touches
        {
            self.touchesInputsMappingDictionary[touch] = []
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
            self.touchesInputsMappingDictionary[touch] = nil
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
        
        self.updateControllerSkin()
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

//MARK: - <GameController> -
/// <GameController>
extension ControllerView: GameControllerType
{
    public func addReceiver(receiver: GameControllerReceiverType)
    {
        self.privateReceivers.addObject(receiver)
    }
    
    public func removeReceiver(receiver: GameControllerReceiverType)
    {
        self.privateReceivers.removeObject(receiver)
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
        for touch in touches where self.touchesInputsMappingDictionary[touch] != nil
        {
            var point = touch.locationInView(self)
            point.x /= self.bounds.width
            point.y /= self.bounds.height
            
            let inputs = controllerSkin.inputsForPoint(point, configuration: self.currentConfiguration) ?? []
            
            var boxedInputs: Set<InputTypeBox> = []
            for input in inputs
            {
                let transformedInputs = self.inputTransformationHandler?(input) ?? [input]
                
                for transformedInput in transformedInputs
                {
                    let boxedInput = InputTypeBox(input: transformedInput)
                    boxedInputs.insert(boxedInput)
                }
            }
            
            self.touchesInputsMappingDictionary[touch] = boxedInputs
        }
        
        let currentActivatedInputs = self.activatedInputBoxes
        
        let receivers = self.receivers
        
        let activatedInputs = currentActivatedInputs.subtract(self.previousActivatedInputs)
        for inputBox in activatedInputs
        {
            for receiver in receivers
            {
                receiver.gameController(self, didActivateInput: inputBox.input)
            }
        }
        
        let deactivatedInputs = self.previousActivatedInputs.subtract(currentActivatedInputs)
        for inputBox in deactivatedInputs
        {
            for receiver in receivers
            {
                receiver.gameController(self, didDeactivateInput: inputBox.input)
            }
        }
        
        self.previousActivatedInputs = currentActivatedInputs
    }
}