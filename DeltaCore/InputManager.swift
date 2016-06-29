//
//  InputManager.swift
//  DeltaCore
//
//  Created by Riley Testut on 6/29/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation

public protocol InputManager
{
    var gameInputType: InputProtocol.Type { get }
    
    func inputs(for controller: ControllerSkin, item: ControllerSkin.Item, point: CGPoint) -> [InputProtocol]
    func inputs(for controller: MFiExternalController, input: MFiExternalControllerInput) -> [InputProtocol]
}
