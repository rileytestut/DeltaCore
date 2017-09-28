//
//  ExtensibleEnums.swift
//  DeltaCore
//
//  Created by Riley Testut on 7/26/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation

// Codable conformance cannot be provided via protocol extension.
// As such, we need to manually implement required methods for each NS_TYPED_EXTENSIBLE_ENUM.

extension GameType: Codable
{
    public init(from decoder: Decoder) throws
    {
        let container = try decoder.singleValueContainer()
        
        let rawValue = try container.decode(String.self)
        self.init(rawValue: rawValue)
    }
    
    public func encode(to encoder: Encoder) throws
    {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

extension CheatType: Codable
{
    public init(from decoder: Decoder) throws
    {
        let container = try decoder.singleValueContainer()
        
        let rawValue = try container.decode(String.self)
        self.init(rawValue: rawValue)
    }
    
    public func encode(to encoder: Encoder) throws
    {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

extension GameControllerInputType: Codable
{
    public init(from decoder: Decoder) throws
    {
        let container = try decoder.singleValueContainer()
        
        let rawValue = try container.decode(String.self)
        self.init(rawValue: rawValue)
    }
    
    public func encode(to encoder: Encoder) throws
    {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

