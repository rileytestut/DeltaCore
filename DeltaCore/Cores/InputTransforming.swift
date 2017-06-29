//
//  InputTransforming.swift
//  DeltaCore
//
//  Created by Riley Testut on 6/29/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation

public protocol InputTransforming
{
    var gameInputType: Input.Type { get }
    
    func inputs(for controllerSkin: ControllerSkin, item: ControllerSkin.Item, point: CGPoint) -> [Input]
    func inputs(for controller: MFiGameController, input: MFiGameController.Input) -> [Input]
}
