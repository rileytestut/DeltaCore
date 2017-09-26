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
        var objects: [AnyObject]!
        
        self.dispatchQueue.sync {
            objects = self._receivers.allObjects
        }
        
        return objects as! [GameControllerReceiver]
    }

    fileprivate let _receivers = NSHashTable<AnyObject>.weakObjects()
    
    // Used to synchronize access to _receivers to prevent race conditions (yay ObjC)
    fileprivate let dispatchQueue = DispatchQueue(label: "com.rileytestut.Delta.GameControllerStateManager.dispatchQueue")
    
    
    init(gameController: GameController)
    {
        self.gameController = gameController
    }
}

extension GameControllerStateManager
{
    func addReceiver(_ receiver: GameControllerReceiver)
    {
        self.dispatchQueue.sync {
            self._receivers.add(receiver)
        }
    }
    
    func removeReceiver(_ receiver: GameControllerReceiver)
    {
        self.dispatchQueue.sync {
            self._receivers.remove(receiver)
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
        
        if let mappedInput = self.mappedInput(for: input)
        {            
            for receiver in self.receivers
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
        
        if let mappedInput = self.mappedInput(for: input)
        {
            let activatedMappedControllerInputs = self.activatedInputs.filter {
                guard let input = self.mappedInput(for: $0) else { return false }
                return input == mappedInput
            }
            
            if activatedMappedControllerInputs.count == 0
            {
                // All controller inputs that map to this input have been deactivated, so we can deactivate the mapped input.
                
                for receiver in self.receivers
                {
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
    
    private func mappedInput(for input: Input) -> Input?
    {
        guard let inputMapping = self.gameController.inputMapping else { return input }
        
        let mappedInput = inputMapping.input(forControllerInput: input)
        return mappedInput
    }
}
