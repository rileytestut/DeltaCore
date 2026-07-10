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
        PressAnimationParameter(name: "D-Pad Pressed Scale", range: 0.88...1.0, rebuildsPatches: false, keyPath: \.dPadPressedScale),
        PressAnimationParameter(name: "Tilt Deadzone", range: 0...0.3, rebuildsPatches: false, keyPath: \.tiltDeadzone),

        PressAnimationParameter(name: "Min Darken", range: 0...0.3, rebuildsPatches: true, keyPath: \.minimumDarkenAlpha),
        PressAnimationParameter(name: "Max Darken", range: 0...0.4, rebuildsPatches: true, keyPath: \.maximumDarkenAlpha),
        PressAnimationParameter(name: "Occlusion Ratio", range: 0...3, rebuildsPatches: true, keyPath: \.occlusionAlphaRatio),
        PressAnimationParameter(name: "Occlusion Height", range: 0...1, rebuildsPatches: true, keyPath: \.occlusionHeight),
        PressAnimationParameter(name: "Shade Feather", range: 0...0.6, rebuildsPatches: true, keyPath: \.shadeFeather),

        PressAnimationParameter(name: "Patch Margin Ratio", range: 0...0.4, rebuildsPatches: true, keyPath: \.patchMarginRatio),
        PressAnimationParameter(name: "Min Patch Margin (pt)", range: 0...20, rebuildsPatches: true, keyPath: \.minimumPatchMargin),
        PressAnimationParameter(name: "Feather Ratio", range: 0...1.5, rebuildsPatches: true, keyPath: \.featherRatio),

        PressAnimationParameter(name: "Cap Travel (pt)", range: 0...6, rebuildsPatches: true, keyPath: \.capTravel),
        PressAnimationParameter(name: "Generated Cap Travel (pt)", range: 0...6, rebuildsPatches: true, keyPath: \.generatedCapTravel),
        PressAnimationParameter(name: "Generated Cap Scale", range: 0.88...1.0, rebuildsPatches: true, keyPath: \.generatedCapPressedScale),
        PressAnimationParameter(name: "D-Pad Saturation", range: 0.25...0.9, rebuildsPatches: false, keyPath: \.dPadSaturation),
        PressAnimationParameter(name: "D-Pad Deadzone", range: 0...0.5, rebuildsPatches: false, keyPath: \.dPadDeadzone),
        PressAnimationParameter(name: "D-Pad Cardinal Angle (±°)", range: 22.5...40, rebuildsPatches: false, keyPath: \.dPadCardinalHalfAngle),
        PressAnimationParameter(name: "Cap Shadow Opacity", range: 0...1, rebuildsPatches: true, keyPath: \.capShadowOpacity),
        PressAnimationParameter(name: "Cap Shadow Radius (pt)", range: 0...10, rebuildsPatches: true, keyPath: \.capShadowRadius),
        PressAnimationParameter(name: "Cap Shadow Offset (pt)", range: 0...8, rebuildsPatches: true, keyPath: \.capShadowOffset),
        PressAnimationParameter(name: "Pressed Shadow Opacity ×", range: 0...1, rebuildsPatches: false, keyPath: \.pressedShadowOpacityRatio),
        PressAnimationParameter(name: "Pressed Shadow Scale", range: 0.85...1.0, rebuildsPatches: false, keyPath: \.pressedShadowScale),

        PressAnimationParameter(name: "Button Release Duration", range: 0...0.6, rebuildsPatches: false, keyPath: \.buttonReleaseDuration),
        PressAnimationParameter(name: "Button Release Bounce", range: 0...0.5, rebuildsPatches: false, keyPath: \.buttonReleaseBounce),
        PressAnimationParameter(name: "D-Pad Release Duration", range: 0...0.6, rebuildsPatches: false, keyPath: \.dPadReleaseDuration),
        PressAnimationParameter(name: "D-Pad Release Bounce", range: 0...0.5, rebuildsPatches: false, keyPath: \.dPadReleaseBounce),

        PressAnimationParameter(name: "Release Haptic Intensity", range: 0...1, rebuildsPatches: false, keyPath: \.releaseHapticIntensity),
    ]

    public static func reset()
    {
        ButtonPatchLayer.Tuning.shared = ButtonPatchLayer.Tuning()
    }
}

// DEBUG: screenshot-verification hook. Removed with this file before merge.
public extension ControllerView
{
    func performPressDemo(_ demo: String)
    {
        func buttonsInputView(in view: UIView) -> ButtonsInputView?
        {
            for subview in view.subviews
            {
                if let buttonsView = subview as? ButtonsInputView { return buttonsView }
                if let buttonsView = buttonsInputView(in: subview) { return buttonsView }
            }

            return nil
        }

        buttonsInputView(in: self)?.performPressDemo(demo)
    }
}
