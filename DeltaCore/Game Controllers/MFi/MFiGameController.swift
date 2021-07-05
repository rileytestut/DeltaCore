//
//  MFiGameController.swift
//  DeltaCore
//
//  Created by Riley Testut on 7/22/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import GameController

public extension GameControllerInputType
{
    static let mfi = GameControllerInputType("mfi")
}

extension MFiGameController
{
    public enum Input: String, Codable
    {
        case menu
        case options
        case home
        
        case up
        case down
        case left
        case right
        
        case leftThumbstickUp
        case leftThumbstickDown
        case leftThumbstickLeft
        case leftThumbstickRight
        
        case rightThumbstickUp
        case rightThumbstickDown
        case rightThumbstickLeft
        case rightThumbstickRight
        
        case a
        case b
        case x
        case y
        
        case leftShoulder
        case leftTrigger
        case leftThumbstickButton
        
        case rightShoulder
        case rightTrigger
        case rightThumbstickButton
        
        // specific to GCDualShockGamepad/GCDualSenseGamepad
        case psTouchpadButton
        
        // specific to GCXboxGamepad
        case xboxPaddleButton1
        case xboxPaddleButton2
        case xboxPaddleButton3
        case xboxPaddleButton4
    }
}

extension MFiGameController.Input: Input
{
    public var type: InputType {
        return .controller(.mfi)
    }
    
    public var isContinuous: Bool {
        switch self
        {
        case .leftThumbstickUp, .leftThumbstickDown, .leftThumbstickLeft, .leftThumbstickRight: return true
        case .rightThumbstickUp, .rightThumbstickDown, .rightThumbstickLeft, .rightThumbstickRight: return true
        default: return false
        }
    }
}

public class MFiGameController: NSObject, GameController
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
            @unknown default: return nil
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
    
    public let inputType: GameControllerInputType = .mfi
        
    public private(set) lazy var defaultInputMapping: GameControllerInputMappingProtocol? = {
        guard let fileURL = Bundle.resources.url(forResource: "MFiGameController", withExtension: "deltamapping") else {
            fatalError("MFiGameController.deltamapping does not exist.")
        }
        
        do
        {
            let inputMapping = try GameControllerInputMapping(fileURL: fileURL)
            return inputMapping
        }
        catch
        {
            print(error)
            fatalError("MFiGameController.deltamapping does not exist.")
        }
    }()
    
    //MARK: - Initializers -
    /** Initializers **/
    public init(controller: GCController)
    {
        self.controller = controller
        
        super.init()
        
        self.controller.controllerPausedHandler = { [unowned self] controller in
            self.activate(Input.menu)
            self.deactivate(Input.menu)
        }
        
        let inputChangedHandler: (_ input: MFiGameController.Input, _ pressed: Bool) -> Void = { [unowned self] (input, pressed) in
            if pressed
            {
                self.activate(input)
            }
            else
            {
                self.deactivate(input)
            }
        }
        
        let thumbstickChangedHandler: (_ input1: MFiGameController.Input, _ input2: MFiGameController.Input, _ value: Float) -> Void = { [unowned self] (input1, input2, value) in
            
            switch value
            {
            case ..<0:
                self.activate(input1, value: Double(-value))
                self.deactivate(input2)
                
            case 0:
                self.deactivate(input1)
                self.deactivate(input2)
                
            default:
                self.deactivate(input1)
                self.activate(input2, value: Double(value))
            }
        }
        
        if let extendedGamepad = self.controller.extendedGamepad
        {
            
            extendedGamepad.buttonA.pressedChangedHandler =  { (button, value, pressed) in inputChangedHandler(.a, pressed) }
            extendedGamepad.buttonB.pressedChangedHandler =  { (button, value, pressed) in inputChangedHandler(.b, pressed) }
            extendedGamepad.buttonX.pressedChangedHandler =  { (button, value, pressed) in inputChangedHandler(.x, pressed) }
            extendedGamepad.buttonY.pressedChangedHandler =  { (button, value, pressed) in inputChangedHandler(.y, pressed) }
            extendedGamepad.leftShoulder.pressedChangedHandler =  { (button, value, pressed) in inputChangedHandler(.leftShoulder, pressed) }
            extendedGamepad.rightShoulder.pressedChangedHandler =  { (button, value, pressed) in inputChangedHandler(.rightShoulder, pressed) }
            
            extendedGamepad.dpad.up.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.up, pressed) }
            extendedGamepad.dpad.down.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.down, pressed) }
            extendedGamepad.dpad.left.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.left, pressed) }
            extendedGamepad.dpad.right.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.right, pressed) }
            
            extendedGamepad.leftTrigger.pressedChangedHandler =  { (button, value, pressed) in inputChangedHandler(.leftTrigger, pressed) }
            extendedGamepad.rightTrigger.pressedChangedHandler =  { (button, value, pressed) in inputChangedHandler(.rightTrigger, pressed) }
            
            extendedGamepad.leftThumbstick.xAxis.valueChangedHandler = { (axis, value) in
                thumbstickChangedHandler(.leftThumbstickLeft, .leftThumbstickRight, value)
            }
            extendedGamepad.leftThumbstick.yAxis.valueChangedHandler = { (axis, value) in
                thumbstickChangedHandler(.leftThumbstickDown, .leftThumbstickUp, value)
            }
            extendedGamepad.rightThumbstick.xAxis.valueChangedHandler = { (axis, value) in
                thumbstickChangedHandler(.rightThumbstickLeft, .rightThumbstickRight, value)
            }
            extendedGamepad.rightThumbstick.yAxis.valueChangedHandler = { (axis, value) in
                thumbstickChangedHandler(.rightThumbstickDown, .rightThumbstickUp, value)
            }
            
            if #available(iOS 12.1, *)
            {
                extendedGamepad.leftThumbstickButton?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.leftThumbstickButton, pressed) }
                extendedGamepad.rightThumbstickButton?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.rightThumbstickButton, pressed) }
            }
            
            if #available(iOS 13, *)
            {
                extendedGamepad.buttonOptions?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.options, pressed) }
            }
            
            if #available(iOS 14, *)
            {
                extendedGamepad.buttonHome?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.home, pressed) }
                
                if let dualShockGamepad = extendedGamepad as? GCDualShockGamepad
                {
                    dualShockGamepad.touchpadButton.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.psTouchpadButton, pressed) }
                }
                
                if let xboxGamepad = extendedGamepad as? GCXboxGamepad
                {
                    xboxGamepad.paddleButton1?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.xboxPaddleButton1, pressed) }
                    xboxGamepad.paddleButton2?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.xboxPaddleButton2, pressed) }
                    xboxGamepad.paddleButton3?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.xboxPaddleButton3, pressed) }
                    xboxGamepad.paddleButton4?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.xboxPaddleButton4, pressed) }
                }
            }
            
            if #available(iOS 14.5, *)
            {
                if let dualSenseGamepad = extendedGamepad as? GCDualSenseGamepad
                {
                    dualSenseGamepad.touchpadButton.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.psTouchpadButton, pressed) }
                }
            }
        }
    }
}
