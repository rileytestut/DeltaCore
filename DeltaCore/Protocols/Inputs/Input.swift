//
//  Input.swift
//  DeltaCore
//
//  Created by Riley Testut on 7/4/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

public protocol Input
{
    var identifier: Int { get }
}

extension Input where Self: RawRepresentable, Self.RawValue == Int
{
    public var identifier: Int {
        return self.rawValue
    }
}

struct AnyInput
{
    let input: Input
    
    init(_ input: Input)
    {
        self.input = input
    }
}

extension AnyInput: Hashable
{
    var hashValue: Int {
        return self.input.identifier
    }
    
    static func ==(lhs: AnyInput, rhs: AnyInput) -> Bool
    {
        return type(of: lhs.input) == type(of: rhs.input) && lhs.input.identifier == rhs.input.identifier
    }
}
