//
//  SaveState.swift
//  DeltaCore
//
//  Created by Riley Testut on 1/31/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation

public struct SaveState: SaveStateProtocol
{
    public var fileURL: URL
    public var gameType: GameType
}
