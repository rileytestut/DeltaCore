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
    private enum ProductCategory: String
    {
        case mfi = "MFi"
        
        case joyConL = "Nintendo Switch Joy-Con (L)"
        case joyConR = "Nintendo Switch Joy-Con (R)"
        case joyConsCombined = "Nintendo Switch Joy-Con (L/R)"
        
        case switchPro = "Switch Pro Controller"
        case switchOnlineNES = "Switch NES Controller"
        case switchOnlineSNES = "Switch SNES Controller"
    }
}

extension MFiGameController
{
    public enum Input: String, Codable
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
        
        case start
        case select
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
        
        let profile = self.controller.physicalInputProfile
        profile.buttons[GCInputButtonA]?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.a, pressed) }
        profile.buttons[GCInputButtonB]?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.b, pressed) }
        profile.buttons[GCInputButtonX]?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.x, pressed) }
        profile.buttons[GCInputButtonY]?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.y, pressed) }
        
        profile.buttons[GCInputLeftShoulder]?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.leftShoulder, pressed) }
        profile.buttons[GCInputLeftTrigger]?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.leftTrigger, pressed) }
        profile.buttons[GCInputRightShoulder]?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.rightShoulder, pressed) }
        profile.buttons[GCInputRightTrigger]?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.rightTrigger, pressed) }
        
        // Menu = Primary menu button (Start/+/Menu)
        let menuButton = profile.buttons[GCInputButtonMenu]
        menuButton?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.menu, pressed) }
        
        // Options = Secondary menu button (Select/-)
        if let optionsButton = profile.buttons[GCInputButtonOptions]
        {
            optionsButton.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.select, pressed) }
            
            // .alwaysReceive == asking permission to record screen every time button is pressed as of iOS 16.3 (annoying).
            // optionsButton.preferredSystemGestureState = .alwaysReceive
        }
        
        if let dPad = profile.dpads[GCInputDirectionPad]
        {
            dPad.up.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.up, pressed) }
            dPad.down.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.down, pressed) }
            dPad.left.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.left, pressed) }
            dPad.right.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.right, pressed) }
        }

        if let leftThumbstick = profile.dpads[GCInputLeftThumbstick]
        {
            leftThumbstick.xAxis.valueChangedHandler = { (axis, value) in
                thumbstickChangedHandler(.leftThumbstickLeft, .leftThumbstickRight, value)
            }
            leftThumbstick.yAxis.valueChangedHandler = { (axis, value) in
                thumbstickChangedHandler(.leftThumbstickDown, .leftThumbstickUp, value)
            }
        }
        
        if let rightThumbstick = profile.dpads[GCInputRightThumbstick]
        {
            rightThumbstick.xAxis.valueChangedHandler = { (axis, value) in
                thumbstickChangedHandler(.rightThumbstickLeft, .rightThumbstickRight, value)
            }
            rightThumbstick.yAxis.valueChangedHandler = { (axis, value) in
                thumbstickChangedHandler(.rightThumbstickDown, .rightThumbstickUp, value)
            }
        }
        
        let productCategory = ProductCategory(rawValue: self.controller.productCategory)
        switch productCategory
        {
        case .mfi:
            // MFi controllers typically only have one Menu button, so no need to re-map it.
            // menuButton?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.menu, pressed) }
            break
            
        case .joyConL, .joyConR:
            // Rotate single Joy-Con inputs 90º
            profile.buttons[GCInputButtonA]?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.b, pressed) }
            profile.buttons[GCInputButtonB]?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.y, pressed) }
            profile.buttons[GCInputButtonX]?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.a, pressed) }
            profile.buttons[GCInputButtonY]?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.x, pressed) }
            
            // For some reason, iOS treats the analog stick as a digital dPad input (as of iOS 16.3).
            // Re-map to .leftThumbstick instead to work as expected with N64 games.
            guard let dPad = profile.dpads[GCInputDirectionPad] else { break }
            dPad.xAxis.valueChangedHandler = { (axis, value) in
                thumbstickChangedHandler(.leftThumbstickLeft, .leftThumbstickRight, value)
            }
            dPad.yAxis.valueChangedHandler = { (axis, value) in
                thumbstickChangedHandler(.leftThumbstickDown, .leftThumbstickUp, value)
            }
            
            // Remove existing dPad change handlers to avoid duplicate inputs.
            dPad.up.pressedChangedHandler = nil
            dPad.down.pressedChangedHandler = nil
            dPad.left.pressedChangedHandler = nil
            dPad.right.pressedChangedHandler = nil
            
        case .switchOnlineNES, .switchOnlineSNES:
            guard var defaultMapping = self.defaultInputMapping as? GameControllerInputMapping else { break }
            
            // Re-map ZL and ZR buttons to Menu so we can treat Start as regular input.
            if productCategory == .switchOnlineNES
            {
                defaultMapping.set(StandardGameControllerInput.menu, forControllerInput: Input.leftShoulder)
                defaultMapping.set(StandardGameControllerInput.menu, forControllerInput: Input.rightShoulder)
            }
            else
            {
                defaultMapping.set(StandardGameControllerInput.menu, forControllerInput: Input.leftTrigger)
                defaultMapping.set(StandardGameControllerInput.menu, forControllerInput: Input.rightTrigger)
            }
            
            self.defaultInputMapping = defaultMapping
            
            // Re-map Start button to...Start
            menuButton?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.start, pressed) }
                        
        default:
            // Home = Home/"Logo" button
            guard let homeButton = profile.buttons[GCInputButtonHome] else { break }
            
            // If controller has Home button, and isn't MFi controller, treat it as Menu button instead.
            // e.g. Switch Pro, PlayStation, and Xbox controllers
            homeButton.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.menu, pressed) }
            
            // Disable "Show Game Center" gesture
            homeButton.preferredSystemGestureState = .disabled
            
            // Re-map Menu button to Start
            menuButton?.pressedChangedHandler = { (button, value, pressed) in inputChangedHandler(.start, pressed) }
        }
    }
}
