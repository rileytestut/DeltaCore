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
    public var screenPredicate: ((ControllerSkin.Screen) -> Bool)?
    
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
            let screens = self.screens(for: traits), let touchScreen = screens.first(where: { $0.isTouchScreen }),
            let outputFrame = touchScreen.outputFrame
        else { return nil }
        
        // For now, we assume touchScreenItem completely covers the touch screen.
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
        guard let screens = self.controllerSkin.screens(for: traits) else { return nil }
        
        // Filter screens first so we can use filteredScreens.count in calculations.
        let filteredScreens = screens.filter(self.screenPredicate ?? { _ in true })
                
        let updatedScreens = filteredScreens.enumerated().map { (index, screen) -> ControllerSkin.Screen in
            let length = 1.0 / CGFloat(filteredScreens.count)
            
            var screen = screen
            screen.placement = .app
            
            switch self.screenLayoutAxis
            {
            case .horizontal: screen.outputFrame = CGRect(x: length * CGFloat(index), y: 0, width: length, height: 1.0)
            case .vertical: screen.outputFrame = CGRect(x: 0, y: length * CGFloat(index), width: 1.0, height: length)
            }
            
            return screen
        }
        
        return updatedScreens
    }
    
    public func aspectRatio(for traits: ControllerSkin.Traits) -> CGSize?
    {
        return self.controllerSkin.aspectRatio(for: traits)
    }
    
    public func contentSize(for traits: ControllerSkin.Traits) -> CGSize?
    {
        guard let screens = self.screens(for: traits) else { return nil }
        
        let compositeScreenSize = screens.reduce(into: CGSize.zero) { (size, screen) in
            guard let inputFrame = screen.inputFrame else { return }
            
            switch self.screenLayoutAxis
            {
            case .horizontal:
                size.width += inputFrame.width
                size.height = max(inputFrame.height, size.height)
                
            case .vertical:
                size.width = max(inputFrame.width, size.width)
                size.height += inputFrame.height
            }
        }
        
        return compositeScreenSize
    }
}
