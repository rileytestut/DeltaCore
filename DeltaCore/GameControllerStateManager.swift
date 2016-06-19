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
        
        self.dispatchQueue.sync {
            objects = self._receivers.allObjects
        }
        
        return objects.map({ $0 as! GameControllerReceiverProtocol })
    }

    private let _receivers = HashTable<AnyObject>.weakObjects()
    
    // Used to synchronize access to _receivers to prevent race conditions (yay ObjC)
    private let dispatchQueue = DispatchQueue(label: "com.rileytestut.Delta.GameControllerStateManager.dispatchQueue", attributes: DispatchQueueAttributes.serial)
}

public extension GameControllerStateManager
{
    func addReceiver(_ receiver: GameControllerReceiverProtocol)
    {
        self.dispatchQueue.sync {
            self._receivers.add(receiver)
        }
    }
    
    func removeReceiver(_ receiver: GameControllerReceiverProtocol)
    {
        self.dispatchQueue.sync {
            self._receivers.remove(receiver)
        }
    }
}
