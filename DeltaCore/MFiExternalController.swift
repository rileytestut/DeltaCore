//
//  MFiExternalController.swift
//  DeltaCore
//
//  Created by Riley Testut on 7/22/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import GameController

public enum MFiExternalControllerInput: InputProtocol, Hashable
{
    case dPad(xAxis: Float, yAxis: Float)
    case leftThumbstick(xAxis: Float, yAxis: Float)
    case rightThumbstick(xAxis: Float, yAxis: Float)
    case a
    case b
    case x
    case y
    case l
    case r
    case leftTrigger
    case rightTrigger
    
    public var rawValue: Int
    {
        return self.hashValue
    }
    
    public var hashValue: Int
    {
        switch self
        {
        case .dPad(xAxis: _, yAxis: _): return 0
        case .leftThumbstick(xAxis: _, yAxis: _): return 1
        case .rightThumbstick(xAxis: _, yAxis: _): return 2
        case .a: return 3
        case .b: return 4
        case .x: return 5
        case .y: return 6
        case .l: return 7
        case .r: return 8
        case .leftTrigger: return 9
        case .rightTrigger: return 10
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
            case .some(0): self.controller.playerIndex = .index1
            case .some(1): self.controller.playerIndex = .index2
            case .some(2): self.controller.playerIndex = .index3
            case .some(3): self.controller.playerIndex = .index4
            default: self.controller.playerIndex = .indexUnset
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
        case .indexUnset: self.playerIndex = nil
        case .index1: self.playerIndex = 0
        case .index2: self.playerIndex = 1
        case .index3: self.playerIndex = 2
        case .index4: self.playerIndex = 3
        }
        
        self.controller.controllerPausedHandler = { controller in
            
            for receiver in self.receivers
            {
                receiver.gameController(self, didActivateInput: ControllerInput.menu)
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
                
        gamepad?.buttonA.pressedChangedHandler =  { (button, value, pressed) in buttonInputPressedChangedHandler(input: MFiExternalControllerInput.a, pressed: pressed) }
        gamepad?.buttonB.pressedChangedHandler =  { (button, value, pressed) in buttonInputPressedChangedHandler(input: MFiExternalControllerInput.b, pressed: pressed) }
        gamepad?.buttonX.pressedChangedHandler =  { (button, value, pressed) in buttonInputPressedChangedHandler(input: MFiExternalControllerInput.x, pressed: pressed) }
        gamepad?.buttonY.pressedChangedHandler =  { (button, value, pressed) in buttonInputPressedChangedHandler(input: MFiExternalControllerInput.y, pressed: pressed) }
        gamepad?.leftShoulder.pressedChangedHandler =  { (button, value, pressed) in buttonInputPressedChangedHandler(input: MFiExternalControllerInput.l, pressed: pressed) }
        gamepad?.rightShoulder.pressedChangedHandler =  { (button, value, pressed) in buttonInputPressedChangedHandler(input: MFiExternalControllerInput.r, pressed: pressed) }
        
        gamepad?.dpad.valueChangedHandler = { (button, value, pressed) in
            
            let input = MFiExternalControllerInput.dPad(xAxis: button.xAxis.value, yAxis: button.yAxis.value)
            
            if let previousInput = self.previousDPadInput
            {
                // Deactivate previous inputs that aren't activated any more
                if case let MFiExternalControllerInput.dPad(xAxis: xAxis, yAxis: yAxis) = previousInput
                {
                    let invertedXAxis = (button.xAxis.value == 0) ? xAxis : 0
                    let invertedYAxis = (button.yAxis.value == 0) ? yAxis : 0
                    
                    let invertedDPad = MFiExternalControllerInput.dPad(xAxis: invertedXAxis, yAxis: invertedYAxis)
                    self.updateReceiversForDeactivatedInput(invertedDPad)
                }
            }
            
            self.updateReceiversForActivatedInput(input)
            
            self.previousDPadInput = input
        }
        
        let extendedGamepad = self.controller.extendedGamepad
        
        extendedGamepad?.leftTrigger.pressedChangedHandler =  { (button, value, pressed) in buttonInputPressedChangedHandler(input: MFiExternalControllerInput.leftTrigger, pressed: pressed) }
        extendedGamepad?.rightTrigger.pressedChangedHandler =  { (button, value, pressed) in buttonInputPressedChangedHandler(input: MFiExternalControllerInput.rightTrigger, pressed: pressed) }
        
        extendedGamepad?.leftThumbstick.valueChangedHandler = { (button, value, pressed) in
            
            let input = MFiExternalControllerInput.leftThumbstick(xAxis: button.xAxis.value, yAxis: button.yAxis.value)
            
            if let previousInput = self.previousLeftThumbstickInput
            {
                // Deactivate previous inputs that aren't activated any more
                if case let MFiExternalControllerInput.leftThumbstick(xAxis: xAxis, yAxis: yAxis) = previousInput
                {
                    let invertedXAxis = (button.xAxis.value == 0) ? xAxis : 0
                    let invertedYAxis = (button.yAxis.value == 0) ? yAxis : 0
                    
                    let invertedDPad = MFiExternalControllerInput.leftThumbstick(xAxis: invertedXAxis, yAxis: invertedYAxis)
                    self.updateReceiversForDeactivatedInput(invertedDPad)
                }
            }
            
            self.updateReceiversForActivatedInput(input)
            
            self.previousLeftThumbstickInput = input
        }
        
        extendedGamepad?.rightThumbstick.valueChangedHandler = { (button, value, pressed) in
            
            let input = MFiExternalControllerInput.rightThumbstick(xAxis: button.xAxis.value, yAxis: button.yAxis.value)
            
            if let previousInput = self.previousRightThumbstickInput
            {
                // Deactivate previous inputs that aren't activated any more
                if case let MFiExternalControllerInput.rightThumbstick(xAxis: xAxis, yAxis: yAxis) = previousInput
                {
                    let invertedXAxis = (button.xAxis.value == 0) ? xAxis : 0
                    let invertedYAxis = (button.yAxis.value == 0) ? yAxis : 0
                    
                    let invertedDPad = MFiExternalControllerInput.rightThumbstick(xAxis: invertedXAxis, yAxis: invertedYAxis)
                    self.updateReceiversForDeactivatedInput(invertedDPad)
                }
            }
            
            self.updateReceiversForActivatedInput(input)
            
            self.previousRightThumbstickInput = input
        }

    }
}
