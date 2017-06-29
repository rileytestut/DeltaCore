//
//  MFiGameController.swift
//  DeltaCore
//
//  Created by Riley Testut on 7/22/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import GameController

extension MFiGameController
{
    public enum Input: DeltaCore.Input
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
        
        public var identifier: Int {
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
}

public class MFiGameController: GameController
{
    //MARK: - Properties -
    /** Properties **/
    public let controller: GCController
    
    public var name: String {
        return self.controller.vendorName ?? NSLocalizedString("MFi Controller", comment: "")
    }
    
    public var playerIndex: Int? {
        get {
            switch self.controller.playerIndex
            {
            case .indexUnset: return nil
            case .index1: return 0
            case .index2: return 1
            case .index3: return 2
            case .index4: return 3
            }
        }
        set {
            switch newValue
            {
            case .some(0): self.controller.playerIndex = .index1
            case .some(1): self.controller.playerIndex = .index2
            case .some(2): self.controller.playerIndex = .index3
            case .some(3): self.controller.playerIndex = .index4
            default: self.controller.playerIndex = .indexUnset
            }
        }
    }
    
    public var inputTransformationHandler: ((DeltaCore.Input) -> [DeltaCore.Input])?
    
    public let _stateManager = GameControllerStateManager()
    
    fileprivate var previousDPadInput: MFiGameController.Input? = nil
    fileprivate var previousLeftThumbstickInput: MFiGameController.Input?
    fileprivate var previousRightThumbstickInput: MFiGameController.Input?
    
    //MARK: - Initializers -
    /** Initializers **/
    public init(controller: GCController)
    {
        self.controller = controller
        self.controller.controllerPausedHandler = { [unowned self] controller in
            self.activate(ControllerInput.menu)
        }
        
        let buttonInputPressedChangedHandler: (_ input: MFiGameController.Input, _ pressed: Bool) -> Void = { [unowned self] (input, pressed) in
            
            if pressed
            {
                self.activate(input)
            }
            else
            {
                self.deactivate(input)
            }
        }
        
        // Standard Buttons
        let gamepad = self.controller.gamepad
        
        gamepad?.buttonA.pressedChangedHandler =  { (button, value, pressed) in buttonInputPressedChangedHandler(.a, pressed) }
        gamepad?.buttonB.pressedChangedHandler =  { (button, value, pressed) in buttonInputPressedChangedHandler(.b, pressed) }
        gamepad?.buttonX.pressedChangedHandler =  { (button, value, pressed) in buttonInputPressedChangedHandler(.x, pressed) }
        gamepad?.buttonY.pressedChangedHandler =  { (button, value, pressed) in buttonInputPressedChangedHandler(.y, pressed) }
        gamepad?.leftShoulder.pressedChangedHandler =  { (button, value, pressed) in buttonInputPressedChangedHandler(.l, pressed) }
        gamepad?.rightShoulder.pressedChangedHandler =  { (button, value, pressed) in buttonInputPressedChangedHandler(.r, pressed) }
        
        gamepad?.dpad.valueChangedHandler = { [unowned self] (button, value, pressed) in
            
            let input = MFiGameController.Input.dPad(xAxis: button.xAxis.value, yAxis: button.yAxis.value)
            
            if let previousInput = self.previousDPadInput
            {
                // Deactivate previous inputs that aren't activated any more
                if case let MFiGameController.Input.dPad(xAxis: xAxis, yAxis: yAxis) = previousInput
                {
                    let invertedXAxis = (button.xAxis.value == 0) ? xAxis : 0
                    let invertedYAxis = (button.yAxis.value == 0) ? yAxis : 0
                    
                    let invertedDPad = MFiGameController.Input.dPad(xAxis: invertedXAxis, yAxis: invertedYAxis)
                    self.deactivate(invertedDPad)
                }
            }
            
            self.activate(input)
            
            self.previousDPadInput = input
        }
        
        let extendedGamepad = self.controller.extendedGamepad
        
        extendedGamepad?.leftTrigger.pressedChangedHandler =  { (button, value, pressed) in buttonInputPressedChangedHandler(.leftTrigger, pressed) }
        extendedGamepad?.rightTrigger.pressedChangedHandler =  { (button, value, pressed) in buttonInputPressedChangedHandler(.rightTrigger, pressed) }
        
        extendedGamepad?.leftThumbstick.valueChangedHandler = { [unowned self] (button, value, pressed) in
            
            let input = MFiGameController.Input.leftThumbstick(xAxis: button.xAxis.value, yAxis: button.yAxis.value)
            
            if let previousInput = self.previousLeftThumbstickInput
            {
                // Deactivate previous inputs that aren't activated any more
                if case let MFiGameController.Input.leftThumbstick(xAxis: xAxis, yAxis: yAxis) = previousInput
                {
                    let invertedXAxis = (button.xAxis.value == 0) ? xAxis : 0
                    let invertedYAxis = (button.yAxis.value == 0) ? yAxis : 0
                    
                    let invertedDPad = MFiGameController.Input.leftThumbstick(xAxis: invertedXAxis, yAxis: invertedYAxis)
                    self.deactivate(invertedDPad)
                }
            }
            
            self.activate(input)
            
            self.previousLeftThumbstickInput = input
        }
        
        extendedGamepad?.rightThumbstick.valueChangedHandler = { [unowned self] (button, value, pressed) in
            
            let input = MFiGameController.Input.rightThumbstick(xAxis: button.xAxis.value, yAxis: button.yAxis.value)
            
            if let previousInput = self.previousRightThumbstickInput
            {
                // Deactivate previous inputs that aren't activated any more
                if case let MFiGameController.Input.rightThumbstick(xAxis: xAxis, yAxis: yAxis) = previousInput
                {
                    let invertedXAxis = (button.xAxis.value == 0) ? xAxis : 0
                    let invertedYAxis = (button.yAxis.value == 0) ? yAxis : 0
                    
                    let invertedDPad = MFiGameController.Input.rightThumbstick(xAxis: invertedXAxis, yAxis: invertedYAxis)
                    self.deactivate(invertedDPad)
                }
            }
            
            self.activate(input)
            
            self.previousRightThumbstickInput = input
        }

    }
}
