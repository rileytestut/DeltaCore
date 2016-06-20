//
//  Game.swift
//  DeltaCore
//
//  Created by Riley Testut on 6/19/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation

// Must be subclass of NSObject to allow it to be used in EmulatorCore initializer
public class Game: NSObject, GameType
{
    public var name: String
    public var fileURL: URL
    public var typeIdentifier: String
    
    public init(name: String, fileURL: URL, typeIdentifier: String)
    {
        self.name = name
        self.fileURL = fileURL
        self.typeIdentifier = typeIdentifier
    }
}
