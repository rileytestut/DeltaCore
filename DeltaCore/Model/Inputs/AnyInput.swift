//
//  AnyInput.swift
//  DeltaCore
//
//  Created by Riley Testut on 7/24/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation

public struct AnyInput: Input, Codable
{
    public let stringValue: String
    public let intValue: Int?
    
    public let type: InputType
    
    public init(_ input: Input)
    {
        self.init(stringValue: input.stringValue, intValue: input.intValue, type: input.type)
    }
    
    public init(stringValue: String, intValue: Int?, type: InputType)
    {
        self.stringValue = stringValue
        self.intValue = intValue
        
        self.type = type
    }
}

public extension AnyInput
{
    init?(stringValue: String)
    {
        return nil
    }

    init?(intValue: Int)
    {
        return nil
    }
}

public extension AnyInput
{
    private enum CodingKeys: String, CodingKey
    {
        case stringValue = "identifier"
        case type
    }
    
    public init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let stringValue = try container.decode(String.self, forKey: .stringValue)
        let type = try container.decode(InputType.self, forKey: .type)
        
        let intValue: Int?
        
        switch type
        {
        case .controller: intValue = nil
        case .game(let gameType):
            guard let deltaCore = Delta.core(for: gameType), let input = deltaCore.gameInputType.init(stringValue: stringValue) else {
                throw DecodingError.dataCorruptedError(forKey: .stringValue, in: container, debugDescription: "The Input game type \(gameType) is unsupported.")
            }
            
            intValue = input.intValue
        }
        
        self.init(stringValue: stringValue, intValue: intValue, type: type)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.stringValue, forKey: .stringValue)
        try container.encode(self.type, forKey: .type)
    }
}

extension AnyInput: Hashable
{
    public var hashValue: Int {
        return self.stringValue.hashValue
    }
    
    public static func ==(lhs: AnyInput, rhs: AnyInput) -> Bool
    {
        return lhs.type == rhs.type && lhs.stringValue == rhs.stringValue
    }
}
