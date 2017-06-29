//
//  GameController.swift
//  DeltaCore
//
//  Created by Riley Testut on 5/3/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

public enum ControllerInput: Int, Input
{
    case menu
}

//MARK: - GameControllerReceiver -
public protocol GameControllerReceiver: class
{
    /// Equivalent to pressing a button, or moving an analog stick
    func gameController(_ gameController: GameController, didActivate input: Input)
    
    /// Equivalent to releasing a button or an analog stick
    func gameController(_ gameController: GameController, didDeactivate input: Input)
}

//MARK: - GameController -
public protocol GameController: class
{
    var playerIndex: Int? { get set }
    var receivers: [GameControllerReceiver] { get }
    
    var inputTransformationHandler: ((Input) -> [Input])? { get set }
    
    var _stateManager: GameControllerStateManager { get }
    
    func addReceiver(_ receiver: GameControllerReceiver)
    func removeReceiver(_ receiver: GameControllerReceiver)
    
    func isInputActivated(_ input: Input) -> Bool
    
    func activate(_ input: Input)
    func deactivate(_ input: Input)
}

extension GameController
{
    func isEqual<T>(to gameController: T) -> Bool
    {
        guard let gameController = gameController as? Self else { return false }
        
        return self === gameController
    }
}

public extension GameController
{
    var receivers: [GameControllerReceiver] {
        return self._stateManager.receivers
    }
    
    func addReceiver(_ receiver: GameControllerReceiver)
    {
        self._stateManager.addReceiver(receiver)
    }
    
    func removeReceiver(_ receiver: GameControllerReceiver)
    {
        self._stateManager.removeReceiver(receiver)
    }
    
    func isInputActivated(_ input: Input) -> Bool
    {
        let box = AnyInput(input)
        return self._stateManager.activatedInputs.contains(box)
    }
    
    func activate(_ input: Input)
    {
        let box = AnyInput(input)
        self._stateManager.activatedInputs.insert(box)
        
        for receiver in self.receivers
        {
            receiver.gameController(self, didActivate: input)
        }
    }
    
    func deactivate(_ input: Input)
    {
        // Unlike activate(_:), we don't allow an input to be deactivated multiple times
        guard self.isInputActivated(input) else { return }
        
        let box = AnyInput(input)
        self._stateManager.activatedInputs.remove(box)
        
        for receiver in self.receivers
        {
            receiver.gameController(self, didDeactivate: input)
        }
    }
}
