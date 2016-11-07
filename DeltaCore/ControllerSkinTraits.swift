//
//  ControllerSkinTraits.swift
//  DeltaCore
//
//  Created by Riley Testut on 7/4/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation

extension ControllerSkin
{
    public enum DeviceType: String
    {
        // Naming conventions? I treat the "P" as the capital letter, so since it's a value (not a type) I've opted to lowercase it
        case iphone
        case ipad
    }
    
    public enum DisplayMode: String
    {
        case fullScreen
        case splitView
    }
    
    public enum Orientation: String
    {
        case portrait
        case landscape
    }
    
    public enum Size: String
    {
        case small
        case medium
        case large
    }
    
    public struct Traits: Hashable, CustomStringConvertible
    {
        public var deviceType: DeviceType
        public var displayMode: DisplayMode
        public var orientation: Orientation
        
        /// Hashable
        public var hashValue: Int {
            return self.description.hashValue
        }
        
        /// CustomStringConvertible
        public var description: String {
            return self.deviceType.rawValue + "-" + self.displayMode.rawValue + "-" + self.orientation.rawValue
        }
        
        public init(deviceType: DeviceType, displayMode: DisplayMode, orientation: Orientation)
        {
            self.deviceType = deviceType
            self.displayMode = displayMode
            self.orientation = orientation
        }
        
        public static func defaults(for view: UIView) -> ControllerSkin.Traits
        {
            var traits = ControllerSkin.Traits(deviceType: .iphone, displayMode: .fullScreen, orientation: .portrait)
            
            // Use trait collection to determine device because our container app may be containing us in an "iPhone" trait collection despite being on iPad
            // 99% of the time, won't make a difference ¯\_(ツ)_/¯
            traits.deviceType = (view.traitCollection.userInterfaceIdiom == .pad) ? .ipad : .iphone
            
            if traits.deviceType == .ipad, let window = view.window, !window.bounds.equalTo(window.screen.bounds)
            {
                // Use screen bounds because in split view window bounds might be portrait, but device is actually landscape (and we want landscape skin)
                traits.orientation = (window.screen.bounds.width > window.screen.bounds.height) ? .landscape : .portrait
                
                traits.displayMode = .splitView
            }
            else
            {
                traits.orientation = (view.bounds.width > view.bounds.height) ? .landscape : .portrait
            }
            
            return traits
        }
    }
}

public func ==(lhs: ControllerSkin.Traits, rhs: ControllerSkin.Traits) -> Bool
{
    return lhs.deviceType == rhs.deviceType && lhs.displayMode == rhs.displayMode && lhs.orientation == rhs.orientation
}
