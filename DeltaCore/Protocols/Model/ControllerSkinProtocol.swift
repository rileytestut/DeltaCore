//
//  ControllerSkinProtocol.swift
//  DeltaCore
//
//  Created by Riley Testut on 10/13/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation

public protocol ControllerSkinProtocol
{
    var name: String { get }
    var identifier: String { get }
    var gameType: GameType { get }
    var isDebugModeEnabled: Bool { get }
    
    func supports(_ traits: ControllerSkin.Traits) -> Bool
    
    func image(for traits: ControllerSkin.Traits, preferredSize: ControllerSkin.Size) -> UIImage?
    
    /// Provided point should be normalized [0,1] for both axies.
    func inputs(for traits: ControllerSkin.Traits, at point: CGPoint) -> [Input]?
    
    func items(for traits: ControllerSkin.Traits) -> [ControllerSkin.Item]?
    
    func isTranslucent(for traits: ControllerSkin.Traits) -> Bool?
    
    func gameScreenFrame(for traits: ControllerSkin.Traits) -> CGRect?
    
    func aspectRatio(for traits: ControllerSkin.Traits) -> CGSize?
}
