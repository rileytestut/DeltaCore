//
//  MFiExternalController.swift
//  DeltaCore
//
//  Created by Riley Testut on 7/22/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import GameController

public enum MFiExternalControllerInput: InputType, Hashable
{
    case DPad(xAxis: Float, yAxis: Float)
    case LeftThumbstick(xAxis: Float, yAxis: Float)
    case RightThumbstick(xAxis: Float, yAxis: Float)
    case A
    case B
    case X
    case Y
    case L
    case R
    case LeftTrigger
    case RightTrigger
    
    public var hashValue: Int
    {
        switch self
        {
        case .DPad(xAxis: _, yAxis: _): return 0
        case .LeftThumbstick(xAxis: _, yAxis: _): return 1
        case .RightThumbstick(xAxis: _, yAxis: _): return 2
        case .A: return 3
        case .B: return 4
        case .X: return 5
        case .Y: return 6
        case .L: return 7
        case .R: return 8
        case .LeftTrigger: return 9
        case .RightTrigger: return 10
        }
    }
}

public func ==(lhs: MFiExternalControllerInput, rhs: MFiExternalControllerInput) -> Bool
{
    switch (lhs, rhs)
    {
    case let (.DPad(a1, b1), .DPad(a2, b2)) where a1 == a2 && b1 == b2: return true
    case let (.LeftThumbstick(a1, b1), .LeftThumbstick(a2, b2)) where a1 == a2 && b1 == b2: return true
    case let (.RightThumbstick(a1, b1), .RightThumbstick(a2, b2)) where a1 == a2 && b1 == b2: return true
    case (.A, .A): return true
    case (.B, .B): return true
    case (.X, .X): return true
    case (.Y, .Y): return true
    case (.L, .L): return true
    case (.R, .R): return true
    case (.LeftTrigger, .LeftTrigger): return true
    case (.RightTrigger, .RightTrigger): return true
        
    case (.DPad, _): return false
    case (.LeftThumbstick, _): return false
    case (.RightThumbstick, _): return false
    case (.A, _): return false
    case (.B, _): return false
    case (.X, _): return false
    case (.Y, _): return false
    case (.L, _): return false
    case (.R, _): return false
    case (.LeftTrigger, _): return false
    case (.RightTrigger, _): return false
    }
}

public class MFiExternalController: ExternalController
{
    //MARK: - Properties -
    /** Properties **/
    public let controller: GCController
    
    public override var name: String {
        return self.controller.vendorName ?? super.name
    }
    
    public override var playerIndex: Int? {
        didSet
        {
            switch self.playerIndex
            {
            case .Some(0): self.controller.playerIndex = .Index1
            case .Some(1): self.controller.playerIndex = .Index2
            case .Some(2): self.controller.playerIndex = .Index3
            case .Some(3): self.controller.playerIndex = .Index4
            default: self.controller.playerIndex = .IndexUnset
            }
        }
    }
    
    //MARK: - Initializers -
    /** Initializers **/
    public init(controller: GCController)
    {
        self.controller = controller
        
        super.init()
        
        switch controller.playerIndex
        {
        case .IndexUnset: self.playerIndex = nil
        case .Index1: self.playerIndex = 0
        case .Index2: self.playerIndex = 1
        case .Index3: self.playerIndex = 2
        case .Index4: self.playerIndex = 3
        }
        
        self.controller.controllerPausedHandler = { controller in
            
            for receiver in self.receivers
            {
                receiver.gameController(self, didActivateInput: ControllerInput.Menu)
            }
            
        }
        
        let buttonInputPressedChangedHandler: (input: MFiExternalControllerInput, pressed: Bool) -> Void = { (input, pressed) in
            
            if pressed
            {
                self.updateReceiversForActivatedInput(input)
            }
            else
            {
                self.updateReceiversForDeactivatedInput(input)
            }
        }
        
        // Standard Buttons
        let gamepad = self.controller.gamepad
                
        gamepad?.buttonA.pressedChangedHandler =  { (button, value, pressed) in buttonInputPressedChangedHandler(input: MFiExternalControllerInput.A, pressed: pressed) }
        gamepad?.buttonB.pressedChangedHandler =  { (button, value, pressed) in buttonInputPressedChangedHandler(input: MFiExternalControllerInput.B, pressed: pressed) }
        gamepad?.buttonX.pressedChangedHandler =  { (button, value, pressed) in buttonInputPressedChangedHandler(input: MFiExternalControllerInput.X, pressed: pressed) }
        gamepad?.buttonY.pressedChangedHandler =  { (button, value, pressed) in buttonInputPressedChangedHandler(input: MFiExternalControllerInput.Y, pressed: pressed) }
        gamepad?.leftShoulder.pressedChangedHandler =  { (button, value, pressed) in buttonInputPressedChangedHandler(input: MFiExternalControllerInput.L, pressed: pressed) }
        gamepad?.rightShoulder.pressedChangedHandler =  { (button, value, pressed) in buttonInputPressedChangedHandler(input: MFiExternalControllerInput.R, pressed: pressed) }
        
        gamepad?.dpad.valueChangedHandler = { (button, value, pressed) in
            let input = MFiExternalControllerInput.DPad(xAxis: button.xAxis.value, yAxis: button.yAxis.value)
            
            if button.xAxis.value != 0 || button.yAxis.value != 0
            {
                self.updateReceiversForActivatedInput(input)
            }
            else
            {
                self.updateReceiversForDeactivatedInput(input)
            }
            
        }
        
        let extendedGamepad = self.controller.extendedGamepad
        
        extendedGamepad?.leftShoulder.pressedChangedHandler =  { (button, value, pressed) in buttonInputPressedChangedHandler(input: MFiExternalControllerInput.LeftTrigger, pressed: pressed) }
        extendedGamepad?.rightShoulder.pressedChangedHandler =  { (button, value, pressed) in buttonInputPressedChangedHandler(input: MFiExternalControllerInput.RightTrigger, pressed: pressed) }
        
        extendedGamepad?.leftThumbstick.valueChangedHandler = { (button, value, pressed) in
            let input = MFiExternalControllerInput.LeftThumbstick(xAxis: button.xAxis.value, yAxis: button.yAxis.value)
            
            if button.xAxis.value != 0 || button.yAxis.value != 0
            {
                self.updateReceiversForActivatedInput(input)
            }
            else
            {
                self.updateReceiversForDeactivatedInput(input)
            }
            
        }
        
        extendedGamepad?.rightThumbstick.valueChangedHandler = { (button, value, pressed) in
            let input = MFiExternalControllerInput.RightThumbstick(xAxis: button.xAxis.value, yAxis: button.yAxis.value)
            
            if button.xAxis.value != 0 || button.yAxis.value != 0
            {
                self.updateReceiversForActivatedInput(input)
            }
            else
            {
                self.updateReceiversForDeactivatedInput(input)
            }
            
        }

    }
}

//MARK: - Private Methods -
private extension MFiExternalController
{
    func updateReceiversForActivatedInput(input: InputType)
    {
        for receiver in self.receivers
        {
            receiver.gameController(self, didActivateInput: input)
        }
    }
    
    func updateReceiversForDeactivatedInput(input: InputType)
    {
        for receiver in self.receivers
        {
            receiver.gameController(self, didDeactivateInput: input)
        }
    }
}