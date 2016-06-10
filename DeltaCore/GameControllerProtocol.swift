//
//  GameControllerProtocol.swift
//  DeltaCore
//
//  Created by Riley Testut on 5/3/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

public enum ControllerInput: Int, InputType
{
    case Menu
}

//MARK: - GameControllerReceiverType
public protocol GameControllerReceiverProtocol: class
{
    /// Equivalent to pressing a button, or moving an analog stick
    func gameController(gameController: GameControllerProtocol, didActivateInput input: InputType)
    
    /// Equivalent to releasing a button or an analog stick
    func gameController(gameController: GameControllerProtocol, didDeactivateInput input: InputType)
}

public func ==(x: GameControllerReceiverProtocol, y: GameControllerReceiverProtocol) -> Bool
{
    return x === y
}

//MARK: - GameControllerProtocol -
public protocol GameControllerProtocol: class
{
    var playerIndex: Int? { get set }
    var receivers: [GameControllerReceiverProtocol] { get }
    
    var inputTransformationHandler: ((GameControllerProtocol, InputType) -> ([InputType]))? { get set }
    
    var _stateManager: GameControllerStateManager { get }
    
    func addReceiver(receiver: GameControllerReceiverProtocol)
    func removeReceiver(receiver: GameControllerReceiverProtocol)
    
    func isInputActivated(input: InputType) -> Bool
    
    func activate(input: InputType)
    func deactivate(input: InputType)
}

public extension GameControllerProtocol
{
    var receivers: [GameControllerReceiverProtocol] {
        return self._stateManager.receivers
    }
    
    func addReceiver(receiver: GameControllerReceiverProtocol)
    {
        self._stateManager.addReceiver(receiver)
    }
    
    func removeReceiver(receiver: GameControllerReceiverProtocol)
    {
        self._stateManager.removeReceiver(receiver)
    }
    
    func isInputActivated(input: InputType) -> Bool
    {
        let box = InputTypeBox(input: input)
        return self._stateManager.activatedInputs.contains(box)
    }
    
    func activate(input: InputType)
    {
        let box = InputTypeBox(input: input)
        self._stateManager.activatedInputs.insert(box)
        
        for receiver in self.receivers
        {
            receiver.gameController(self, didActivateInput: input)
        }
    }
    
    func deactivate(input: InputType)
    {
        // Unlike activate(_:), we don't allow an input to be deactivated multiple times
        guard self.isInputActivated(input) else { return }
        
        let box = InputTypeBox(input: input)
        self._stateManager.activatedInputs.remove(box)
        
        for receiver in self.receivers
        {
            receiver.gameController(self, didDeactivateInput: input)
        }
    }
}