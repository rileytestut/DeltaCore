//
//  GameControllerStateManager.swift
//  DeltaCore
//
//  Created by Riley Testut on 5/29/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation

internal class GameControllerStateManager
{
    let gameController: GameController
    
    fileprivate(set) var activatedInputs = Set<AnyInput>()
    fileprivate(set) var sustainedInputs = Set<AnyInput>()
    
    var receivers: [GameControllerReceiver] {
        var objects: [GameControllerReceiver]!
        
        self.dispatchQueue.sync {
            objects = self._receivers.keyEnumerator().allObjects as! [GameControllerReceiver]
        }
        
        return objects
    }

    fileprivate let _receivers = NSMapTable<AnyObject, AnyObject>.weakToStrongObjects()
    
    // Used to synchronize access to _receivers to prevent race conditions (yay ObjC)
    fileprivate let dispatchQueue = DispatchQueue(label: "com.rileytestut.Delta.GameControllerStateManager.dispatchQueue")
    
    
    init(gameController: GameController)
    {
        self.gameController = gameController
    }
}

extension GameControllerStateManager
{
    func addReceiver(_ receiver: GameControllerReceiver, inputMapping: GameControllerInputMappingProtocol?)
    {
        self.dispatchQueue.sync {
            self._receivers.setObject(inputMapping as AnyObject, forKey: receiver)
        }
    }
    
    func removeReceiver(_ receiver: GameControllerReceiver)
    {
        self.dispatchQueue.sync {
            self._receivers.removeObject(forKey: receiver)
        }
    }
}

extension GameControllerStateManager
{
    func activate(_ input: Input)
    {
        precondition(input.type == .controller(self.gameController.inputType), "input.type must match self.gameController.inputType")
        
        // An input may be "activated" multiple times, such as by pressing different buttons that map to same input, or moving an analog stick.
        
        self.activatedInputs.insert(AnyInput(input))
        
        for receiver in self.receivers
        {
            if let mappedInput = self.mappedInput(for: input, receiver: receiver)
            {
                receiver.gameController(self.gameController, didActivate: mappedInput)
            }
        }
    }
    
    func deactivate(_ input: Input)
    {
        precondition(input.type == .controller(self.gameController.inputType), "input.type must match self.gameController.inputType")
        
        // Cannot deactivate a sustained input.
        guard !self.sustainedInputs.contains(AnyInput(input)) else { return }
        
        // Unlike activate(_:), we don't allow an input to be deactivated multiple times.
        guard self.activatedInputs.contains(AnyInput(input)) else { return }
        
        self.activatedInputs.remove(AnyInput(input))
        
        for receiver in self.receivers
        {
            if let mappedInput = self.mappedInput(for: input, receiver: receiver)
            {
                let hasActivatedMappedControllerInputs = self.activatedInputs.contains() {
                    guard let input = self.mappedInput(for: $0, receiver: receiver) else { return false }
                    return input == mappedInput
                }
                
                if !hasActivatedMappedControllerInputs
                {
                    // All controller inputs that map to this input have been deactivated, so we can deactivate the mapped input.
                    receiver.gameController(self.gameController, didDeactivate: mappedInput)
                }
            }
        }
    }
    
    func sustain(_ input: Input)
    {
        precondition(input.type == .controller(self.gameController.inputType), "input.type must match self.gameController.inputType")
        
        if !self.activatedInputs.contains(AnyInput(input))
        {
            self.activate(input)
        }
        
        self.sustainedInputs.insert(AnyInput(input))
    }
    
    // Technically not a word, but no good alternative, so ¯\_(ツ)_/¯
    func unsustain(_ input: Input)
    {
        precondition(input.type == .controller(self.gameController.inputType), "input.type must match self.gameController.inputType")
        
        self.sustainedInputs.remove(AnyInput(input))
        
        self.deactivate(AnyInput(input))
    }
    
    private func mappedInput(for input: Input, receiver: GameControllerReceiver) -> Input?
    {
        guard let inputMapping = self._receivers.object(forKey: receiver) as? GameControllerInputMappingProtocol else { return input }
        
        let mappedInput = inputMapping.input(forControllerInput: input)
        return mappedInput
    }
}
