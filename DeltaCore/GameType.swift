//
//  Game.swift
//  DeltaCore
//
//  Created by Riley Testut on 3/8/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import Foundation

@objc public protocol GameType: NSObjectProtocol
{
    var name: String { get }
    var fileURL: URL { get }
    var typeIdentifier: String { get }
}
