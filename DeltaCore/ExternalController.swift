//
//  ExternalController.swift
//  DeltaCore
//
//  Created by Riley Testut on 7/22/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import Foundation
import GameController

public class ExternalController: GameControllerType, Hashable
{
    //MARK: - Properties -
    /** Properties **/
    
    public var name: String {
        return NSLocalizedString("External Controller", comment: "")
    }
    
    //MARK: <GameControllerType>
    /// <GameControllerType>
    public var playerIndex: Int?
    public private(set) var receivers: [GameControllerReceiverType] = []
    public var inputTransformationHandler: ((InputType) -> ([InputType]))?
    
    //MARK: <Hashable>
    /// <Hashable>
    public var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
    
    private var previousActivatedInputs: Set<InputTypeBox> = []
    
    public init()
    {
        
    }
}

public func ==(lhs: ExternalController, rhs: ExternalController) -> Bool
{
    return lhs.hashValue == rhs.hashValue
}

//MARK: - <GameController> -
/// <GameController>
extension ExternalController
{
    public func addReceiver(receiver: GameControllerReceiverType)
    {
        self.receivers.append(receiver)
    }
    
    public func removeReceiver(receiver: GameControllerReceiverType)
    {
        if let index = self.receivers.indexOf({ $0 == receiver })
        {
            self.receivers.removeAtIndex(index)
        }
    }
}

//MARK: - Private Methods -
internal extension ExternalController
{
    func updateReceiversForActivatedInput(input: InputType)
    {
        var activatedInputs = [input]
        
        if let inputs = self.inputTransformationHandler?(input)
        {
            activatedInputs = inputs
        }
        
        for receiver in self.receivers
        {
            for input in activatedInputs
            {
                let inputBox = InputTypeBox(input: input)
                if self.previousActivatedInputs.contains(inputBox)
                {
                    continue
                }
                
                receiver.gameController(self, didActivateInput: input)
                
                self.previousActivatedInputs.insert(inputBox)
            }
        }
    }
    
    func updateReceiversForDeactivatedInput(input: InputType)
    {
        var deactivatedInputs = [input]
        
        if let inputs = self.inputTransformationHandler?(input)
        {
            deactivatedInputs = inputs
        }
        
        for receiver in self.receivers
        {
            for input in deactivatedInputs
            {
                receiver.gameController(self, didDeactivateInput: input)
                
                let inputBox = InputTypeBox(input: input)
                self.previousActivatedInputs.remove(inputBox)
            }
        }
    }
}