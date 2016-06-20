//
//  Game.swift
//  DeltaCore
//
//  Created by Riley Testut on 6/20/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation

public class Game: NSObject, GameProtocol
{
    public var fileURL: URL
    public var typeIdentifier: GameType
    
    public init(fileURL: URL, typeIdentifier: GameType)
    {
        self.fileURL = fileURL
        self.typeIdentifier = typeIdentifier
    }
}
