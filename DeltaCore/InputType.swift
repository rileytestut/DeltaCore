//
//  InputType.swift
//  DeltaCore
//
//  Created by Riley Testut on 7/4/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

/// Used by subclasses to declare appropriate form of representing emulator inputs
public protocol InputType
{
    /// Used internally to conform to Hashable
    /// We cannot have InputType itself conform to Hashable due to the Self requirement of Equatable
    /// Implemented by the InputType protocol extension. Should not need to be overriden by conforming types.
    var _hashValue: Int { get }
    
    /// Convenience method used for implementing Equatable. Default implementation via protocol extension
    func isEqual<T>(_ input: T) -> Bool
    
    // So we can pass into generic Objective-C method
    var rawValue: Int { get }
}

/// Provide default implementatation for InputType.isEqual()
public extension InputType where Self: Hashable
{
    var _hashValue: Int {
        return self.hashValue
    }
    
    func isEqual<T>(_ input: T) -> Bool
    {
        if let input = input as? Self
        {
            return self == input
        }
        
        return false
    }
}

/// Workaround for current inability to declare Set values and Dictionary keys as EmulatorInput types
internal struct InputTypeBox: Hashable
{
    let input: InputType
    var hashValue: Int { return input._hashValue }
}

internal func ==(x: InputTypeBox, y: InputTypeBox) -> Bool
{
    return x.input.isEqual(y.input)
}



