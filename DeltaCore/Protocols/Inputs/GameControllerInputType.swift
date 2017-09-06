//
//  GameControllerInputType.swift
//  DeltaCore
//
//  Created by Riley Testut on 7/26/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation

public struct GameControllerInputType: RawRepresentable, Codable
{
    public let rawValue: String
    
    public init(rawValue: String)
    {
        self.rawValue = rawValue
    }
    
    public init(_ rawValue: String)
    {
        self.init(rawValue: rawValue)
    }
}

extension GameControllerInputType: Hashable
{
    public var hashValue: Int {
        return self.rawValue.hashValue
    }
}
