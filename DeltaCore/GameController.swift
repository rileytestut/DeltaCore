//
//  GameController.swift
//  DeltaCore
//
//  Created by Riley Testut on 5/3/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

public enum EmulatorInput: GameInput
{
    case Menu
    case Sustain
}

public protocol GameControllerReceiver
{
    // Equivalent to pressing a button, or moving an analog stick
    func gameController(gameController: GameController, didActivateInput input: GameInput)
    
    // Equivalent to releasing a button or an analog stick
    func gameController(gameController: GameController, didDeactivateInput input: GameInput)
}

public protocol GameController: class
{
    var playerIndex: Int? { get set }
    
    var receiver: GameControllerReceiver? { get set }
}