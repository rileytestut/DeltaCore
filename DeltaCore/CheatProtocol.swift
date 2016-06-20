//
//  CheatProtocol.swift
//  DeltaCore
//
//  Created by Riley Testut on 5/19/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation

// Cannot nest type in Cheat namespace due to Swift bug :(
@objc public enum CheatType: Int
{
    case actionReplay
    case gameGenie
    case gameShark
    case codeBreaker
}

public protocol CheatProtocol
{
    var name: String? { get }
    var code: String { get }
    var type: CheatType { get }
}
