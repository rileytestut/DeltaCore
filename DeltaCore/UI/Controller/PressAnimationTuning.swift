//
//  PressAnimationTuning.swift
//  DeltaCore
//
//  Created by Caroline Moore on 7/9/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//
//  DEBUG: live-tuning surface for press animations. Removed before merge.
//

import UIKit

public struct PressAnimationParameter
{
    public let name: String
    public let range: ClosedRange<CGFloat>

    // Whether changing this parameter requires regenerating patch bitmaps.
    public let rebuildsPatches: Bool

    fileprivate let keyPath: WritableKeyPath<ButtonPatchLayer.Tuning, CGFloat>

    public var value: CGFloat {
        get { ButtonPatchLayer.Tuning.shared[keyPath: self.keyPath] }
        nonmutating set { ButtonPatchLayer.Tuning.shared[keyPath: self.keyPath] = newValue }
    }
}

public enum PressAnimationTuning
{
    public static let parameters: [PressAnimationParameter] = [
        PressAnimationParameter(name: "Tilt Angle (°)", range: 0...12, rebuildsPatches: false, keyPath: \.tiltDegrees),
        PressAnimationParameter(name: "Perspective Distance", range: 100...2000, rebuildsPatches: false, keyPath: \.perspectiveDistance),
        PressAnimationParameter(name: "Press Depth (pt)", range: 0...6, rebuildsPatches: false, keyPath: \.pressDepth),
        PressAnimationParameter(name: "Pressed Scale", range: 1.0...1.05, rebuildsPatches: false, keyPath: \.pressedScale),
        PressAnimationParameter(name: "Tilt Deadzone", range: 0...0.3, rebuildsPatches: false, keyPath: \.tiltDeadzone),

        PressAnimationParameter(name: "Min Darken", range: 0...0.3, rebuildsPatches: true, keyPath: \.minimumDarkenAlpha),
        PressAnimationParameter(name: "Max Darken", range: 0...0.4, rebuildsPatches: true, keyPath: \.maximumDarkenAlpha),
        PressAnimationParameter(name: "Occlusion Ratio", range: 0...3, rebuildsPatches: true, keyPath: \.occlusionAlphaRatio),
        PressAnimationParameter(name: "Occlusion Height", range: 0...1, rebuildsPatches: true, keyPath: \.occlusionHeight),
        PressAnimationParameter(name: "Shade Feather", range: 0...0.6, rebuildsPatches: true, keyPath: \.shadeFeather),

        PressAnimationParameter(name: "Patch Margin Ratio", range: 0...0.4, rebuildsPatches: true, keyPath: \.patchMarginRatio),
        PressAnimationParameter(name: "Min Patch Margin (pt)", range: 0...20, rebuildsPatches: true, keyPath: \.minimumPatchMargin),
        PressAnimationParameter(name: "Feather Ratio", range: 0...1.5, rebuildsPatches: true, keyPath: \.featherRatio),

        PressAnimationParameter(name: "Button Release Duration", range: 0.05...0.6, rebuildsPatches: false, keyPath: \.buttonReleaseDuration),
        PressAnimationParameter(name: "Button Release Bounce", range: 0...0.5, rebuildsPatches: false, keyPath: \.buttonReleaseBounce),
        PressAnimationParameter(name: "D-Pad Release Duration", range: 0.05...0.6, rebuildsPatches: false, keyPath: \.dPadReleaseDuration),
        PressAnimationParameter(name: "D-Pad Release Bounce", range: 0...0.5, rebuildsPatches: false, keyPath: \.dPadReleaseBounce),

        PressAnimationParameter(name: "Release Haptic Intensity", range: 0...1, rebuildsPatches: false, keyPath: \.releaseHapticIntensity),
    ]

    public static func reset()
    {
        ButtonPatchLayer.Tuning.shared = ButtonPatchLayer.Tuning()
    }
}
