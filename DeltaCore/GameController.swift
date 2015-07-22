//
//  GameController.swift
//  DeltaCore
//
//  Created by Riley Testut on 5/3/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

public enum ControllerInput: InputType
{
    case Menu
}

//MARK: - GameControllerReceiverType
public protocol GameControllerReceiverType
{
    /// Equivalent to pressing a button, or moving an analog stick
    func gameController(gameController: GameControllerType, didActivateInput input: InputType)
    
    /// Equivalent to releasing a button or an analog stick
    func gameController(gameController: GameControllerType, didDeactivateInput input: InputType)
    
    /// Used internally to store references to each receiver and compare them
    /// Same method signature as NSObjectProtocol's isEqual method, so all subclasses of NSObject will inherit a basic implementation for free
    func isEqual(object: AnyObject?) -> Bool
}

public func ==(x: GameControllerReceiverType, y: GameControllerReceiverType) -> Bool
{
    if let y = y as? AnyObject
    {
        return x.isEqual(y)
    }
    
    return false
}

//MARK: - GameControllerType -
public protocol GameControllerType: class
{
    var playerIndex: Int? { get set }
    var receivers: [GameControllerReceiverType] { get }
    
    func addReceiver(receiver: GameControllerReceiverType)
    func removeReceiver(receiver: GameControllerReceiverType)
}