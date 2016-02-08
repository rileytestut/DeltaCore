//
//  SaveStateType.swift
//  DeltaCore
//
//  Created by Riley Testut on 1/31/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation

public protocol SaveStateType
{
    var name: String? { get }
    var fileURL: NSURL { get }
}