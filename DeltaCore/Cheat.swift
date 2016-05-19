//
//  Cheat.swift
//  DeltaCore
//
//  Created by Riley Testut on 5/19/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation

public struct Cheat: CheatProtocol
{
    public var name: String?
    public var code: String
    public var type: CheatType
    
    public init(name: String?, code: String, type: CheatType)
    {
        self.name = name
        self.code = code
        self.type = type
    }
}