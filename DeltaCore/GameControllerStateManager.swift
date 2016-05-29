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
    internal let receivers = NSHashTable.weakObjectsHashTable()
}