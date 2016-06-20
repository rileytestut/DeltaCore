//
//  GameControllerProtocol.swift
//  DeltaCore
//
//  Created by Riley Testut on 5/3/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

public enum ControllerInput: Int, InputProtocol
{
    case menu
}

//MARK: - GameControllerReceiverType
public protocol GameControllerReceiverProtocol: class
{
    /// Equivalent to pressing a button, or moving an analog stick
    func gameController(_ gameController: GameControllerProtocol, didActivateInput input: InputProtocol)
    
    /// Equivalent to releasing a button or an analog stick
    func gameController(_ gameController: GameControllerProtocol, didDeactivateInput input: InputProtocol)
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
    
    var inputTransformationHandler: ((GameControllerProtocol, InputProtocol) -> ([InputProtocol]))? { get set }
    
    var _stateManager: GameControllerStateManager { get }
    
    func addReceiver(_ receiver: GameControllerReceiverProtocol)
    func removeReceiver(_ receiver: GameControllerReceiverProtocol)
    
    func isInputActivated(_ input: InputProtocol) -> Bool
    
    func activate(_ input: InputProtocol)
    func deactivate(_ input: InputProtocol)
}

public extension GameControllerProtocol
{
    var receivers: [GameControllerReceiverProtocol] {
        return self._stateManager.receivers
    }
    
    func addReceiver(_ receiver: GameControllerReceiverProtocol)
    {
        self._stateManager.addReceiver(receiver)
    }
    
    func removeReceiver(_ receiver: GameControllerReceiverProtocol)
    {
        self._stateManager.removeReceiver(receiver)
    }
    
    func isInputActivated(_ input: InputProtocol) -> Bool
    {
        let box = InputBox(input: input)
        return self._stateManager.activatedInputs.contains(box)
    }
    
    func activate(_ input: InputProtocol)
    {
        let box = InputBox(input: input)
        self._stateManager.activatedInputs.insert(box)
        
        for receiver in self.receivers
        {
            receiver.gameController(self, didActivateInput: input)
        }
    }
    
    func deactivate(_ input: InputProtocol)
    {
        // Unlike activate(_:), we don't allow an input to be deactivated multiple times
        guard self.isInputActivated(input) else { return }
        
        let box = InputBox(input: input)
        self._stateManager.activatedInputs.remove(box)
        
        for receiver in self.receivers
        {
            receiver.gameController(self, didDeactivateInput: input)
        }
    }
}
