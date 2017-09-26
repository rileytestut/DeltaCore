//
//  GameController.swift
//  DeltaCore
//
//  Created by Riley Testut on 5/3/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import ObjectiveC

private var gameControllerStateManagerKey = 0

//MARK: - GameControllerReceiver -
public protocol GameControllerReceiver: class
{
    /// Equivalent to pressing a button, or moving an analog stick
    func gameController(_ gameController: GameController, didActivate input: Input)
    
    /// Equivalent to releasing a button or an analog stick
    func gameController(_ gameController: GameController, didDeactivate input: Input)
}

//MARK: - GameController -
public protocol GameController: NSObjectProtocol
{
    var name: String { get }
        
    var playerIndex: Int? { get set }
    
    var inputType: GameControllerInputType { get }
    
    var inputMapping: GameControllerInputMappingProtocol? { get set }
}

public extension GameController
{
    private var stateManager: GameControllerStateManager {
        var stateManager = objc_getAssociatedObject(self, &gameControllerStateManagerKey) as? GameControllerStateManager
        
        if stateManager == nil
        {
            stateManager = GameControllerStateManager()
            objc_setAssociatedObject(self, &gameControllerStateManagerKey, stateManager, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
        return stateManager!
    }
    
    var receivers: [GameControllerReceiver] {
        return self.stateManager.receivers
    }
    
    func addReceiver(_ receiver: GameControllerReceiver)
    {
        self.stateManager.addReceiver(receiver)
    }
    
    func removeReceiver(_ receiver: GameControllerReceiver)
    {
        self.stateManager.removeReceiver(receiver)
    }
    
    func isInputActivated(_ input: Input) -> Bool
    {
        return self.stateManager.activatedInputs.contains(AnyInput(input))
    }
    
    func activate(_ input: Input)
    {
        precondition(input.type == .controller(self.inputType), "input.type must match GameController.inputType")
        
        // An input may be "activated" multiple times, such as by pressing different buttons that map to same input, or moving an analog stick.
        
        self.stateManager.activatedInputs.insert(AnyInput(input))
        
        if let mappedInput = self.mappedInput(for: input)
        {
            self.stateManager.activatedMappedInputs.add(AnyInput(input))
            
            for receiver in self.receivers
            {
                receiver.gameController(self, didActivate: mappedInput)
            }
        }
    }
    
    func deactivate(_ input: Input)
    {
        precondition(input.type == .controller(self.inputType), "input.type must match GameController.inputType")
        
        // Unlike activate(_:), we don't allow an input to be deactivated multiple times.
        guard self.isInputActivated(input) else { return }
        
        self.stateManager.activatedInputs.remove(AnyInput(input))
        
        if let mappedInput = self.mappedInput(for: input)
        {
            self.stateManager.activatedMappedInputs.remove(AnyInput(input))
            
            if self.stateManager.activatedMappedInputs.count(for: AnyInput(input)) == 0
            {
                for receiver in self.receivers
                {
                    receiver.gameController(self, didDeactivate: mappedInput)
                }
            }
        }
    }
    
    private func mappedInput(for input: Input) -> Input?
    {
        guard let inputMapping = self.inputMapping else { return input }
        
        let mappedInput = inputMapping.input(forControllerInput: input)
        return mappedInput
    }
}

public func ==(lhs: GameController, rhs: GameController) -> Bool
{
    return lhs.isEqual(rhs)
}

public func !=(lhs: GameController, rhs: GameController) -> Bool
{
    return !(lhs == rhs)
}

public func ~=(pattern: GameController, value: GameController) -> Bool
{
    return pattern == value
}
