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
    return lhs.hashValue == rhs.hashValue
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
    
    private var previousDPadInput: MFiExternalControllerInput? = nil
    private var previousLeftThumbstickInput: MFiExternalControllerInput?
    private var previousRightThumbstickInput: MFiExternalControllerInput?
    
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
            
            if let previousInput = self.previousDPadInput
            {
                // Deactivate previous inputs that aren't activated any more
                if case let MFiExternalControllerInput.DPad(xAxis: xAxis, yAxis: yAxis) = previousInput
                {
                    let invertedXAxis = (button.xAxis.value == 0) ? xAxis : 0
                    let invertedYAxis = (button.yAxis.value == 0) ? yAxis : 0
                    
                    let invertedDPad = MFiExternalControllerInput.DPad(xAxis: invertedXAxis, yAxis: invertedYAxis)
                    self.updateReceiversForDeactivatedInput(invertedDPad)
                }
            }
            
            self.updateReceiversForActivatedInput(input)
            
            self.previousDPadInput = input
        }
        
        let extendedGamepad = self.controller.extendedGamepad
        
        extendedGamepad?.leftTrigger.pressedChangedHandler =  { (button, value, pressed) in buttonInputPressedChangedHandler(input: MFiExternalControllerInput.LeftTrigger, pressed: pressed) }
        extendedGamepad?.rightTrigger.pressedChangedHandler =  { (button, value, pressed) in buttonInputPressedChangedHandler(input: MFiExternalControllerInput.RightTrigger, pressed: pressed) }
        
        extendedGamepad?.leftThumbstick.valueChangedHandler = { (button, value, pressed) in
            
            let input = MFiExternalControllerInput.LeftThumbstick(xAxis: button.xAxis.value, yAxis: button.yAxis.value)
            
            if let previousInput = self.previousLeftThumbstickInput
            {
                // Deactivate previous inputs that aren't activated any more
                if case let MFiExternalControllerInput.LeftThumbstick(xAxis: xAxis, yAxis: yAxis) = previousInput
                {
                    let invertedXAxis = (button.xAxis.value == 0) ? xAxis : 0
                    let invertedYAxis = (button.yAxis.value == 0) ? yAxis : 0
                    
                    let invertedDPad = MFiExternalControllerInput.LeftThumbstick(xAxis: invertedXAxis, yAxis: invertedYAxis)
                    self.updateReceiversForDeactivatedInput(invertedDPad)
                }
            }
            
            self.updateReceiversForActivatedInput(input)
            
            self.previousLeftThumbstickInput = input
        }
        
        extendedGamepad?.rightThumbstick.valueChangedHandler = { (button, value, pressed) in
            
            let input = MFiExternalControllerInput.RightThumbstick(xAxis: button.xAxis.value, yAxis: button.yAxis.value)
            
            if let previousInput = self.previousRightThumbstickInput
            {
                // Deactivate previous inputs that aren't activated any more
                if case let MFiExternalControllerInput.RightThumbstick(xAxis: xAxis, yAxis: yAxis) = previousInput
                {
                    let invertedXAxis = (button.xAxis.value == 0) ? xAxis : 0
                    let invertedYAxis = (button.yAxis.value == 0) ? yAxis : 0
                    
                    let invertedDPad = MFiExternalControllerInput.RightThumbstick(xAxis: invertedXAxis, yAxis: invertedYAxis)
                    self.updateReceiversForDeactivatedInput(invertedDPad)
                }
            }
            
            self.updateReceiversForActivatedInput(input)
            
            self.previousRightThumbstickInput = input
        }

    }
}