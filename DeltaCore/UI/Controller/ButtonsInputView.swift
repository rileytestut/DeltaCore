//
//  ButtonsInputView.swift
//  DeltaCore
//
//  Created by Riley Testut on 8/4/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import simd

class ButtonsInputView: UIView
{
    var isHapticFeedbackEnabled = true

    var isPressAnimationEnabled = false {
        didSet {
            self.setNeedsRebuildPatchLayers()
        }
    }

    var items: [ControllerSkin.Item]? {
        didSet {
            self.setNeedsRebuildPatchLayers()
        }
    }

    var activateInputsHandler: ((Set<AnyInput>) -> Void)?
    var deactivateInputsHandler: ((Set<AnyInput>) -> Void)?

    var image: UIImage? {
        get {
            return self.imageView.image
        }
        set {
            self.imageView.image = newValue
            self.setNeedsRebuildPatchLayers()
        }
    }

    var pressedImage: UIImage? {
        didSet {
            self.setNeedsRebuildPatchLayers()
        }
    }

    // Per-item cap artwork for layered skins. Items with caps get physically
    // animated cap layers; items without fall back to pressed-appearance patches.
    var caps = [ControllerSkin.Item.ID: ControllerSkin.Cap]() {
        didSet {
            self.setNeedsRebuildPatchLayers()
        }
    }

    private let imageView = UIImageView(frame: .zero)

    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let pressFeedbackGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let releaseFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    private let detentFeedbackGenerator = UISelectionFeedbackGenerator()

    private var touchInputsMappingDictionary: [UITouch: Set<AnyInput>] = [:]
    private var previousTouchInputs = Set<AnyInput>()
    private var touchInputs: Set<AnyInput> {
        return self.touchInputsMappingDictionary.values.reduce(Set<AnyInput>(), { $0.union($1) })
    }

    // Layers showing pressed appearances on top of the skin image.
    private let patchesLayer = CALayer()
    private var patchLayers = [ControllerSkin.Item.ID: ButtonPatchLayer]()
    private var previousDPadInputs = [ControllerSkin.Item.ID: Set<AnyInput>]()

    private var needsRebuildPatchLayers = false
    private var lastPatchLayoutSize = CGSize.zero

    private static let menuInput = AnyInput(stringValue: StandardGameControllerInput.menu.stringValue, intValue: nil, type: .controller(.controllerSkin))

    override var intrinsicContentSize: CGSize {
        return self.imageView.intrinsicContentSize
    }
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        self.isMultipleTouchEnabled = true
        
        self.feedbackGenerator.prepare()
        
        self.imageView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.imageView)
        
        NSLayoutConstraint.activate([self.imageView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                                     self.imageView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                                     self.imageView.topAnchor.constraint(equalTo: self.topAnchor),
                                     self.imageView.bottomAnchor.constraint(equalTo: self.bottomAnchor)])

        // Added after imageView so patches composite on top of the skin image.
        self.layer.addSublayer(self.patchesLayer)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews()
    {
        super.layoutSubviews()

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        self.patchesLayer.frame = self.bounds

        if self.needsRebuildPatchLayers || self.bounds.size != self.lastPatchLayoutSize
        {
            self.rebuildPatchLayers()
        }

        CATransaction.commit()
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        for touch in touches
        {
            self.touchInputsMappingDictionary[touch] = []
        }

        if self.isPressAnimationEnabled && self.isHapticFeedbackEnabled
        {
            self.pressFeedbackGenerator.prepare()
            self.releaseFeedbackGenerator.prepare()
            self.detentFeedbackGenerator.prepare()
        }

        self.updateInputs(for: touches)
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        self.updateInputs(for: touches)
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        for touch in touches
        {
            self.touchInputsMappingDictionary[touch] = nil
        }
        
        self.updateInputs(for: touches)
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        return self.touchesEnded(touches, with: event)
    }
}

extension ButtonsInputView
{
    func inputs(at point: CGPoint) -> [Input]?
    {
        guard let items = self.items else { return nil }
        
        var point = point
        point.x /= self.bounds.width
        point.y /= self.bounds.height
        
        var inputs: [Input] = []
        
        for item in items
        {
            guard item.extendedFrame.contains(point) else { continue }
            
            switch item.inputs
            {
            // Don't return inputs for thumbsticks or touch screens since they're handled separately.
            case .directional where item.kind == .thumbstick: break
            case .touch: break

            case .standard(let itemInputs):
                inputs.append(contentsOf: itemInputs)

            case let .directional(up, down, left, right):

                // D-pads use angle-based zones like real hardware: each cardinal owns a
                // wide sector from the pivot, so wiggling along an arm stays that direction.
                // Diagonals only engage in the corner sectors between them.
                let delta = self.normalizedOffset(of: point, in: item)

                if simd_length(delta) > ButtonPatchLayer.Tuning.shared.dPadDeadzone
                {
                    let direction = self.sectorDirection(for: delta)

                    if direction.y < 0 { inputs.append(up) }
                    if direction.y > 0 { inputs.append(down) }
                    if direction.x < 0 { inputs.append(left) }
                    if direction.x > 0 { inputs.append(right) }
                }
            }
        }
        
        return inputs
    }
}

private extension ButtonsInputView
{
    func updateInputs(for touches: Set<UITouch>)
    {
        // Don't add the touches if it has been removed in touchesEnded:/touchesCancelled:
        for touch in touches where self.touchInputsMappingDictionary[touch] != nil
        {
            guard touch.view == self else { continue }
            
            let point = touch.location(in: self)
            let inputs = Set((self.inputs(at: point) ?? []).map { AnyInput($0) })

            let menuInput = ButtonsInputView.menuInput
            if inputs.contains(menuInput)
            {
                // If the menu button is located at this position, ignore all other inputs that might be overlapping.
                self.touchInputsMappingDictionary[touch] = [menuInput]
            }
            else
            {
                self.touchInputsMappingDictionary[touch] = Set(inputs)
            }
        }
        
        let activatedInputs = self.touchInputs.subtracting(self.previousTouchInputs)
        let deactivatedInputs = self.previousTouchInputs.subtracting(self.touchInputs)
        
        // We must update previousTouchInputs *before* calling activate() and deactivate().
        // Otherwise, race conditions that cause duplicate touches from activate() or deactivate() calls can result in various bugs.
        self.previousTouchInputs = self.touchInputs
        
        if !activatedInputs.isEmpty
        {
            self.activateInputsHandler?(activatedInputs)

            // When press animations are active, haptics fire per-item alongside the visuals instead.
            if self.isHapticFeedbackEnabled && self.patchLayers.isEmpty
            {
                switch UIDevice.current.feedbackSupportLevel
                {
                case .feedbackGenerator: self.feedbackGenerator.impactOccurred()
                case .basic, .unsupported: UIDevice.current.vibrate()
                }
            }
        }

        if !deactivatedInputs.isEmpty
        {
            self.deactivateInputsHandler?(deactivatedInputs)
        }

        self.updatePressedPatchLayers()
    }
}

private extension ButtonsInputView
{
    func setNeedsRebuildPatchLayers()
    {
        self.needsRebuildPatchLayers = true
        self.setNeedsLayout()
    }

    func rebuildPatchLayers()
    {
        self.needsRebuildPatchLayers = false
        self.lastPatchLayoutSize = self.bounds.size

        for patchLayer in self.patchLayers.values
        {
            patchLayer.removeFromSuperlayer()
        }

        self.patchLayers = [:]
        self.previousDPadInputs = [:]

        guard self.isPressAnimationEnabled, !self.bounds.isEmpty, let image = self.image, let items = self.items else { return }

        let tuning = ButtonPatchLayer.Tuning.shared

        for item in items
        {
            guard item.placement == .controller, item.kind == .button || item.kind == .dPad else { continue }

            if let cap = self.caps[item.id]
            {
                // Tilting is enough press feedback for a d-pad — a shading overlay on top reads as a gray film.
                guard let capContents = ButtonPatchLayer.makeCapContents(from: cap, background: image, pressedSkinImage: self.pressedImage, generatesPressedAppearance: item.kind != .dPad) else { continue }

                let patchLayer = ButtonPatchLayer(item: item, capContents: capContents, frame: cap.frame.scaled(to: self.bounds))

                self.patchesLayer.addSublayer(patchLayer)
                self.patchLayers[item.id] = patchLayer

                continue
            }

            let itemSize = CGSize(width: item.frame.width * self.bounds.width, height: item.frame.height * self.bounds.height)
            guard itemSize.width > 0, itemSize.height > 0 else { continue }

            // The margin gives the feather band room outside the item's artwork,
            // and gives a tilting d-pad extra coverage over the base image.
            let margin = max(tuning.minimumPatchMargin, tuning.patchMarginRatio * min(itemSize.width, itemSize.height))

            var patchRect = item.frame.insetBy(dx: -margin / self.bounds.width, dy: -margin / self.bounds.height)

            // Only feather edges that aren't clamped to the skin's bounds,
            // so patches at the screen edge don't fade out actual artwork.
            var featheredEdges = UIRectEdge()
            if patchRect.minX >= 0 { featheredEdges.insert(.left) }
            if patchRect.maxX <= 1 { featheredEdges.insert(.right) }
            if patchRect.minY >= 0 { featheredEdges.insert(.top) }
            if patchRect.maxY <= 1 { featheredEdges.insert(.bottom) }

            patchRect = patchRect.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
            guard !patchRect.isEmpty else { continue }

            let feather = tuning.featherRatio * margin
            let featherFraction = CGSize(width: feather / (patchRect.width * self.bounds.width),
                                         height: feather / (patchRect.height * self.bounds.height))

            let geometry = ButtonPatchLayer.Geometry(patchRect: patchRect, itemRect: item.frame, featherFraction: featherFraction, featheredEdges: featheredEdges)

            // With an authored pressed image we show its artwork directly.
            // Otherwise we generate a pressed appearance from the base image.
            let contents: CGImage?
            if let pressedImage = self.pressedImage
            {
                contents = ButtonPatchLayer.makeContents(from: pressedImage, geometry: geometry, addsGeneratedShading: false)
            }
            else
            {
                contents = ButtonPatchLayer.makeContents(from: image, geometry: geometry, addsGeneratedShading: true)
            }

            guard let contents else { continue }

            // Anchor on the item's visual center (not the patch's), so an
            // edge-clamped d-pad still tilts around its actual pivot.
            let anchorPoint = CGPoint(x: (item.frame.midX - patchRect.minX) / patchRect.width,
                                      y: (item.frame.midY - patchRect.minY) / patchRect.height)

            let patchLayer = ButtonPatchLayer(item: item, contents: contents, frame: patchRect.scaled(to: self.bounds), anchorPoint: anchorPoint)

            self.patchesLayer.addSublayer(patchLayer)
            self.patchLayers[item.id] = patchLayer
        }

        // DEBUG: keep the screenshot-verification demo state applied across rebuilds. Removed before merge.
        if let demo = UserDefaults.standard.string(forKey: "DemoPressState"), !self.patchLayers.isEmpty
        {
            self.performPressDemo(demo)
        }
    }

    func updatePressedPatchLayers()
    {
        guard self.isPressAnimationEnabled, !self.patchLayers.isEmpty else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for patchLayer in self.patchLayers.values
        {
            switch patchLayer.item.kind
            {
            case .dPad: self.updateDPadPatchLayer(patchLayer)
            default: self.updateButtonPatchLayer(patchLayer)
            }
        }

        CATransaction.commit()
    }

    func updateButtonPatchLayer(_ patchLayer: ButtonPatchLayer)
    {
        let itemInputs = Set(patchLayer.item.inputs.allInputs.map { AnyInput($0) })
        let isPressed = !self.touchInputs.isDisjoint(with: itemInputs)

        if isPressed && !patchLayer.isPressed
        {
            patchLayer.press()
            self.performPressHaptic()
        }
        else if !isPressed && patchLayer.isPressed
        {
            patchLayer.release()
            self.performReleaseHaptic()
        }
    }

    func updateDPadPatchLayer(_ patchLayer: ButtonPatchLayer)
    {
        let item = patchLayer.item

        // Like the physical part: past the saturation radius the cap is bottomed out in
        // its committed sector pose (a discrete state), while near the pivot it floats —
        // tracking the finger continuously and settling into the pose as it approaches
        // the edge of the float zone.
        if let point = self.trackedDPadTouchLocation(for: item)
        {
            let tuning = ButtonPatchLayer.Tuning.shared

            let delta = self.normalizedOffset(of: point, in: item)
            let distance = simd_length(delta)

            var tilt = CGPoint.zero

            if distance > tuning.tiltDeadzone
            {
                let progress = min((distance - tuning.tiltDeadzone) / max(tuning.dPadSaturation - tuning.tiltDeadzone, 0.01), 1.0)

                // The raw and sector directions are always within 90° of each other, so the mix can't vanish.
                let direction = simd_normalize(simd_mix(delta / distance, self.sectorDirection(for: delta), SIMD2(repeating: progress)))

                tilt = CGPoint(x: direction.x * progress, y: direction.y * progress)
            }

            let wasPressed = patchLayer.isPressed
            patchLayer.press(tilt: tilt)

            let itemInputs = Set(item.inputs.allInputs.map { AnyInput($0) })
            let activeInputs = self.touchInputs.intersection(itemInputs)

            if !wasPressed
            {
                self.performPressHaptic()
            }
            else if let previousInputs = self.previousDPadInputs[item.id], previousInputs != activeInputs
            {
                // Rolling to a different direction clicks like a detent.
                self.performDetentHaptic()
            }

            self.previousDPadInputs[item.id] = activeInputs
        }
        else if patchLayer.isPressed
        {
            patchLayer.release()
            self.performReleaseHaptic()

            self.previousDPadInputs[item.id] = nil
        }
    }

    // A normalized point's offset from the item's center, in units of its half-size.
    func normalizedOffset(of point: CGPoint, in item: ControllerSkin.Item) -> SIMD2<Double>
    {
        return SIMD2(Double((point.x - item.frame.midX) / (item.frame.width / 2.0)),
                     Double((point.y - item.frame.midY) / (item.frame.height / 2.0)))
    }

    // The committed pose's direction for a touch offset — the single source of truth
    // for sector geometry, shared by input zones and the tilt visual.
    func sectorDirection(for delta: SIMD2<Double>) -> SIMD2<Double>
    {
        let degrees = atan2(delta.y, delta.x) * 180.0 / .pi
        let cardinalHalfAngle = ButtonPatchLayer.Tuning.shared.dPadCardinalHalfAngle

        if abs(degrees + 90.0) <= cardinalHalfAngle { return SIMD2(0, -1) }
        if abs(degrees - 90.0) <= cardinalHalfAngle { return SIMD2(0, 1) }
        if abs(degrees) <= cardinalHalfAngle { return SIMD2(1, 0) }
        if 180.0 - abs(degrees) <= cardinalHalfAngle { return SIMD2(-1, 0) }

        return simd_normalize(SIMD2(delta.x < 0 ? -1 : 1, delta.y < 0 ? -1 : 1))
    }

    func trackedDPadTouchLocation(for item: ControllerSkin.Item) -> CGPoint?
    {
        var trackedTouch: (touch: UITouch, location: CGPoint)?

        for (touch, inputs) in self.touchInputsMappingDictionary
        {
            guard touch.view == self else { continue }

            // The menu button wins overlaps, so don't let its touches move the d-pad.
            guard !inputs.contains(ButtonsInputView.menuInput) else { continue }

            var point = touch.location(in: self)
            point.x /= self.bounds.width
            point.y /= self.bounds.height
            guard item.extendedFrame.contains(point) else { continue }

            // With multiple touches on the d-pad, the most recent one drives the tilt.
            if let previousTouch = trackedTouch, previousTouch.touch.timestamp > touch.timestamp { continue }
            trackedTouch = (touch, point)
        }

        return trackedTouch?.location
    }

    func performPressHaptic()
    {
        guard self.isHapticFeedbackEnabled else { return }

        switch UIDevice.current.feedbackSupportLevel
        {
        case .feedbackGenerator:
            self.pressFeedbackGenerator.impactOccurred()
            self.pressFeedbackGenerator.prepare()

        case .basic, .unsupported: UIDevice.current.vibrate()
        }
    }

    func performReleaseHaptic()
    {
        guard self.isHapticFeedbackEnabled, UIDevice.current.feedbackSupportLevel == .feedbackGenerator else { return }

        self.releaseFeedbackGenerator.impactOccurred(intensity: ButtonPatchLayer.Tuning.shared.releaseHapticIntensity)
        self.releaseFeedbackGenerator.prepare()
    }

    func performDetentHaptic()
    {
        guard self.isHapticFeedbackEnabled, UIDevice.current.feedbackSupportLevel == .feedbackGenerator else { return }

        self.detentFeedbackGenerator.selectionChanged()
        self.detentFeedbackGenerator.prepare()
    }
}

// DEBUG: applies pressed visuals directly so specific states can be screenshotted. Removed before merge.
// Demo format: "+"-separated components, e.g. "a", "b+a", "dpad:0,-1", "a+dpad:0.7,0.7". Anything else releases everything.
internal extension ButtonsInputView
{
    func performPressDemo(_ demo: String)
    {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        var pressedItemIDs = Set<String>()

        for component in demo.components(separatedBy: "+")
        {
            if component.hasPrefix("dpad")
            {
                let values = component.components(separatedBy: ":").last?.components(separatedBy: ",").compactMap { Double($0) } ?? []
                let tilt = (values.count == 2) ? CGPoint(x: values[0], y: values[1]) : CGPoint.zero

                for patchLayer in self.patchLayers.values where patchLayer.item.kind == .dPad
                {
                    patchLayer.press(tilt: tilt)
                    pressedItemIDs.insert(patchLayer.item.id)
                }
            }
            else
            {
                for patchLayer in self.patchLayers.values where patchLayer.item.kind == .button
                {
                    let inputs = patchLayer.item.inputs.allInputs.map { $0.stringValue }
                    if inputs.contains(component)
                    {
                        patchLayer.press()
                        pressedItemIDs.insert(patchLayer.item.id)
                    }
                }
            }
        }

        for patchLayer in self.patchLayers.values where !pressedItemIDs.contains(patchLayer.item.id)
        {
            patchLayer.release()
        }

        CATransaction.commit()
    }
}
