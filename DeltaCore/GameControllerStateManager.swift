//
//  GameControllerStateManager.swift
//  DeltaCore
//
//  Created by Riley Testut on 5/29/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation

public class GameControllerStateManager
{
    internal var activatedInputs = Set<InputTypeBox>()
    
    internal var receivers: [GameControllerReceiverProtocol]
    {
        var objects: [AnyObject]!
        
        dispatch_sync(self.dispatchQueue) {
            objects = self._receivers.allObjects
        }
        
        return objects.map({ $0 as! GameControllerReceiverProtocol })
    }

    private let _receivers = NSHashTable.weakObjectsHashTable()
    
    // Used to synchronize access to _receivers to prevent race conditions (yay ObjC)
    private let dispatchQueue = dispatch_queue_create("com.rileytestut.Delta.GameControllerStateManager.dispatchQueue", DISPATCH_QUEUE_SERIAL)
}

public extension GameControllerStateManager
{
    func addReceiver(receiver: GameControllerReceiverProtocol)
    {
        dispatch_sync(self.dispatchQueue) {
            self._receivers.addObject(receiver)
        }
    }
    
    func removeReceiver(receiver: GameControllerReceiverProtocol)
    {
        dispatch_sync(self.dispatchQueue) {
            self._receivers.removeObject(receiver)
        }
    }
}