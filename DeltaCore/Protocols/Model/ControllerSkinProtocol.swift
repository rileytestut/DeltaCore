//
//  ControllerSkinProtocol.swift
//  DeltaCore
//
//  Created by Riley Testut on 10/13/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

public protocol ControllerSkinProtocol
{
    var name: String { get }
    var identifier: String { get }
    var gameType: GameType { get }
    var isDebugModeEnabled: Bool { get }
    
    func supports(_ traits: ControllerSkin.Traits) -> Bool
    
    func image(for traits: ControllerSkin.Traits, preferredSize: ControllerSkin.Size) -> UIImage?
    func pressedImage(for traits: ControllerSkin.Traits, preferredSize: ControllerSkin.Size) -> UIImage?
    
    func image(for item: ControllerSkin.Item, traits: ControllerSkin.Traits, preferredSize: ControllerSkin.Size) -> (UIImage, CGSize)?
    
    func items(for traits: ControllerSkin.Traits) -> [ControllerSkin.Item]?
    
    func isTranslucent(for traits: ControllerSkin.Traits) -> Bool?
    
    func gameScreenFrame(for traits: ControllerSkin.Traits) -> CGRect?
    func screens(for traits: ControllerSkin.Traits) -> [ControllerSkin.Screen]?
    
    func aspectRatio(for traits: ControllerSkin.Traits) -> CGSize?
    func contentSize(for traits: ControllerSkin.Traits) -> CGSize?
    
    func menuInsets(for traits: ControllerSkin.Traits) -> UIEdgeInsets?
    
    func supportedTraits(for traits: ControllerSkin.Traits) -> ControllerSkin.Traits?
}

public extension ControllerSkinProtocol
{
    func supportedTraits(for traits: ControllerSkin.Traits) -> ControllerSkin.Traits?
    {
        let maximumFallbackAttempts = 10
        var numberOfAttempts = 0
        
        var traits = traits
        
        while !self.supports(traits)
        {
            numberOfAttempts += 1
            
            // Sanity check to ensure this never results in (1) Infinite Loop.
            guard numberOfAttempts <= maximumFallbackAttempts else {
                assertionFailure("ControllerSkinProtocol.supportedTraits(for:) reached max number of fallback attempts. This is most likely due to programmer error.")
                return nil
            }
            
            if traits.device == .iphone
            {
                switch traits.displayType
                {
                case .edgeToEdge:
                    // Fall back to standard representations from edgeToEdge.
                    traits.displayType = .standard
                    
                case .inner:
                    // First, check if skin supports outer display, which has same aspect ratio.
                    traits.displayType = .outer
                    if self.supports(traits)
                    {
                        // Outer display representation exists, so use these traits.
                        return traits
                    }
                    
                    // Next, because display is iPad-like, try iPad representation, before falling back to iPhone edgeToEdge (handled below).
                    traits.device = .ipad
                    traits.displayType = .standard
                    
                case .outer:
                    // iPhone-like, but very short so skip edgeToEdge and only try standard.
                    traits.displayType = .standard
                    
                case .splitView:
                    // Fall back to iPad split view
                    traits.device = .ipad
                    
                case .standard, .cover: return nil
                }
            }
            else if traits.device == .ipad
            {
                switch traits.displayType
                {
                case .standard, .edgeToEdge:
                    // Fall back to iPhone edgeToEdge skins (followed by standard skins, as handled above)
                    traits.device = .iphone
                    traits.displayType = .edgeToEdge
                    
                case .outer, .inner, .splitView, .cover: return nil
                }
            }
            else
            {
                return nil
            }
        }
        
        return traits
    }
    
    func gameScreenFrame(for traits: DeltaCore.ControllerSkin.Traits) -> CGRect?
    {
        return self.screens(for: traits)?.first?.outputFrame
    }
}

public func ==(lhs: ControllerSkinProtocol?, rhs: ControllerSkinProtocol?) -> Bool
{
    return lhs?.identifier == rhs?.identifier
}

public func !=(lhs: ControllerSkinProtocol?, rhs: ControllerSkinProtocol?) -> Bool
{
    return !(lhs == rhs)
}

public func ~=(pattern: ControllerSkinProtocol?, value: ControllerSkinProtocol?) -> Bool
{
    return pattern == value
}
