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
    fileprivate var stateManager: GameControllerStateManager {
        var stateManager = objc_getAssociatedObject(self, &gameControllerStateManagerKey) as? GameControllerStateManager
        
        if stateManager == nil
        {
            stateManager = GameControllerStateManager(gameController: self)
            objc_setAssociatedObject(self, &gameControllerStateManagerKey, stateManager, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
        return stateManager!
    }
    
    var receivers: [GameControllerReceiver] {
        return self.stateManager.receivers
    }
    
    var activatedInputs: [Input] {
        return Array(self.stateManager.activatedInputs)
    }
    
    var sustainedInputs: [Input] {
        return Array(self.stateManager.sustainedInputs)
    }
}

public extension GameController
{
    func addReceiver(_ receiver: GameControllerReceiver)
    {
        self.stateManager.addReceiver(receiver)
    }
    
    func removeReceiver(_ receiver: GameControllerReceiver)
    {
        self.stateManager.removeReceiver(receiver)
    }
    
    func activate(_ input: Input)
    {
        self.stateManager.activate(input)
    }
    
    func deactivate(_ input: Input)
    {
        self.stateManager.deactivate(input)
    }
    
    func sustain(_ input: Input)
    {
        self.stateManager.sustain(input)
    }
    
    func unsustain(_ input: Input)
    {
        self.stateManager.unsustain(input)
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
