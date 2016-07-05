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
    }
}

public func ==(lhs: ControllerSkin.Traits, rhs: ControllerSkin.Traits) -> Bool
{
    return lhs.deviceType == rhs.deviceType && lhs.displayMode == rhs.displayMode && lhs.orientation == rhs.orientation
}
