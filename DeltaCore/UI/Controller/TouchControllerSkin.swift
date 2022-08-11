//
//  TouchControllerSkin.swift
//  DeltaCore
//
//  Created by Riley Testut on 12/1/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import UIKit
import AVFoundation

extension TouchControllerSkin
{
    public enum LayoutAxis
    {
        case vertical
        case horizontal
    }
}

public struct TouchControllerSkin
{
    public var name: String { "TouchControllerSkin" }
    public var identifier: String { "com.delta.TouchControllerSkin" }
    public var gameType: GameType { self.controllerSkin.gameType }
    public var isDebugModeEnabled: Bool { false }
    
    public var screenLayoutAxis: LayoutAxis = .vertical
    
    private let controllerSkin: ControllerSkin
    
    public init(controllerSkin: ControllerSkin)
    {
        self.controllerSkin = controllerSkin
    }
}

extension TouchControllerSkin: ControllerSkinProtocol
{
    public func supports(_ traits: ControllerSkin.Traits) -> Bool
    {
        return true
    }
    
    public func image(for traits: ControllerSkin.Traits, preferredSize: ControllerSkin.Size) -> UIImage?
    {
        return nil
    }
    
    public func thumbstick(for item: ControllerSkin.Item, traits: ControllerSkin.Traits, preferredSize: ControllerSkin.Size) -> (UIImage, CGSize)?
    {
        return nil
    }
    
    public func items(for traits: ControllerSkin.Traits) -> [ControllerSkin.Item]?
    {
        guard
            var touchScreenItem = self.controllerSkin.items(for: traits)?.first(where: { $0.kind == .touchScreen }),
            let screens = self.screens(for: traits), screens.count > 1,
            let outputFrame = screens[1].outputFrame
        else { return nil }
        
        // For now, we assume the touch screen is always the second screen, and that touchScreenItem should completely cover it.
        
        touchScreenItem.placement = .app
        touchScreenItem.frame = outputFrame
        touchScreenItem.extendedFrame = outputFrame
        return [touchScreenItem]
    }
    
    public func isTranslucent(for traits: ControllerSkin.Traits) -> Bool?
    {
        return false
    }

    public func screens(for traits: ControllerSkin.Traits) -> [ControllerSkin.Screen]?
    {
        let screensCount = CGFloat(self.controllerSkin.screens(for: traits)?.count ?? 0)
        
        let screens = self.controllerSkin.screens(for: traits)?.enumerated().map { (index, screen) -> ControllerSkin.Screen in
            let length = 1.0 / screensCount
            
            var screen = screen
            screen.placement = .app
            
            switch self.screenLayoutAxis
            {
            case .horizontal: screen.outputFrame = CGRect(x: length * CGFloat(index), y: 0, width: 0.5, height: 1.0)
            case .vertical: screen.outputFrame = CGRect(x: 0, y: length * CGFloat(index), width: 1.0, height: 0.5)
            }
            
            return screen
        }
        
        return screens
    }
    
    public func aspectRatio(for traits: ControllerSkin.Traits) -> CGSize?
    {
        return self.controllerSkin.aspectRatio(for: traits)
    }
}
