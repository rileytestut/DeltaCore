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
    
    //MARK: - <GameController>
    /// <GameController>
    public var playerIndex: Int?
    public private(set) var receivers: [GameControllerReceiverType] = []
    
    public var activatedInputs: [InputType]
    {
        return self.activatedInputBoxes.map({ (box) -> InputType in
            return box.input
        })
    }
    
    //MARK: - Private Properties
    private let imageView: UIImageView = UIImageView(frame: CGRectZero)
    private var transitionImageView: UIImageView? = nil
    
    private var touchesInputsMappingDictionary: [UITouch: Set<InputTypeBox>] = [:]
    private var previousActivatedInputs: Set<InputTypeBox> = []
    
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
        let image = self.controllerSkin?.imageForTraitCollection(self.traitCollection)
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
        self.receivers.append(receiver)
    }
    
    public func removeReceiver(receiver: GameControllerReceiverType)
    {
        if let index = self.receivers.indexOf({ $0 == receiver })
        {
            self.receivers.removeAtIndex(index)
        }
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
            let point = touch.locationInView(self)
            let inputs = controllerSkin.inputsForPoint(point, traitCollection: self.traitCollection).map({ InputTypeBox(input: $0) })
            
            self.touchesInputsMappingDictionary[touch] = Set(inputs)
        }
        
        let currentActivatedInputs = self.activatedInputBoxes
        
        let activatedInputs = currentActivatedInputs.subtract(self.previousActivatedInputs)
        for inputBox in activatedInputs
        {
            for receiver in self.receivers
            {
                receiver.gameController(self, didActivateInput: inputBox.input)
            }
        }
        
        let deactivatedInputs = self.previousActivatedInputs.subtract(currentActivatedInputs)
        for inputBox in deactivatedInputs
        {
            for receiver in self.receivers
            {
                receiver.gameController(self, didDeactivateInput: inputBox.input)
            }
        }
        
        self.previousActivatedInputs = currentActivatedInputs
    }
}