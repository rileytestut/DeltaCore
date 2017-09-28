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
    public enum Input: String
    {
        case menu
        
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
        
        case rightShoulder
        case rightTrigger
    }
}

extension MFiGameController.Input: DeltaCore.Input
{
    public var type: InputType {
        return .controller(.mfi)
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
        
    public lazy var defaultInputMapping: GameControllerInputMappingProtocol? = {
        guard let fileURL = Bundle(for: MFiGameController.self).url(forResource: "MFiGameController", withExtension: "deltamapping") else {
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
        
        if let gamepad = self.controller.gamepad
        {
            gamepad.buttonA.pressedChangedHandler =  { (button, value, pressed) in inputChangedHandler(.a, pressed) }
            gamepad.buttonB.pressedChangedHandler =  { (button, value, pressed) in inputChangedHandler(.b, pressed) }
            gamepad.buttonX.pressedChangedHandler =  { (button, value, pressed) in inputChangedHandler(.x, pressed) }
            gamepad.buttonY.pressedChangedHandler =  { (button, value, pressed) in inputChangedHandler(.y, pressed) }
            gamepad.leftShoulder.pressedChangedHandler =  { (button, value, pressed) in inputChangedHandler(.leftShoulder, pressed) }
            gamepad.rightShoulder.pressedChangedHandler =  { (button, value, pressed) in inputChangedHandler(.rightShoulder, pressed) }
            
            gamepad.dpad.up.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.up, pressed) }
            gamepad.dpad.down.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.down, pressed) }
            gamepad.dpad.left.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.left, pressed) }
            gamepad.dpad.right.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.right, pressed) }
        }
        
        if let extendedGamepad = self.controller.extendedGamepad
        {
            extendedGamepad.leftTrigger.pressedChangedHandler =  { (button, value, pressed) in inputChangedHandler(.leftTrigger, pressed) }
            extendedGamepad.rightTrigger.pressedChangedHandler =  { (button, value, pressed) in inputChangedHandler(.rightTrigger, pressed) }
            
            extendedGamepad.leftThumbstick.up.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.leftThumbstickUp, pressed) }
            extendedGamepad.leftThumbstick.down.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.leftThumbstickDown, pressed) }
            extendedGamepad.leftThumbstick.left.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.leftThumbstickLeft, pressed) }
            extendedGamepad.leftThumbstick.right.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.leftThumbstickRight, pressed) }
            
            extendedGamepad.rightThumbstick.up.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.rightThumbstickUp, pressed) }
            extendedGamepad.rightThumbstick.down.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.rightThumbstickDown, pressed) }
            extendedGamepad.rightThumbstick.left.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.rightThumbstickLeft, pressed) }
            extendedGamepad.rightThumbstick.right.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.rightThumbstickRight, pressed) }
        }
    }
}
