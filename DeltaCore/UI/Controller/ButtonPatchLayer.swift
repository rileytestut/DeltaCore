//
//  ButtonPatchLayer.swift
//  DeltaCore
//
//  Created by Caroline Moore on 7/9/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import UIKit
import CoreImage.CIFilterBuiltins

extension ButtonPatchLayer
{
    // Every constant that affects how presses look and feel, in one place.
    // Mutable via `shared` so a debug tuning UI can adjust values live on device.
    struct Tuning
    {
        static var shared = Tuning()

        // D-pad tilt
        var tiltDegrees = 10.0 as CGFloat
        var perspectiveDistance = 500.0 as CGFloat
        var pressDepth = 2.5 as CGFloat
        var pressedScale = 1.01 as CGFloat // Patch mode only — slight overscan hides seams while tilting.
        var dPadPressedScale = 0.99 as CGFloat
        var tiltDeadzone = 0.08 as CGFloat
        var dPadRollDuration = 0.12 as CGFloat // Easing between committed tilt poses while rolling.
        var dPadDeadzone = 0.2 as CGFloat // Neutral radius around the pivot, as a fraction of the d-pad's half-size.
        var dPadCardinalHalfAngle = 30.0 as CGFloat // Degrees each side of a cardinal direction; the rest is diagonal territory.

        // Generated pressed shading
        var minimumDarkenAlpha = 0.06 as CGFloat
        var maximumDarkenAlpha = 0.17 as CGFloat
        var occlusionAlphaRatio = 2.0 as CGFloat
        var occlusionHeight = 0.25 as CGFloat
        var shadeFeather = 0.2 as CGFloat

        // Patch geometry
        var patchMarginRatio = 0.15 as CGFloat
        var minimumPatchMargin = 8.0 as CGFloat
        var featherRatio = 0.75 as CGFloat

        // Caps (layered skins)
        var capTravel = 1.5 as CGFloat
        var generatedCapTravel = 1.0 as CGFloat // Baked into the generated pressed scene, along with...
        var generatedCapPressedScale = 0.96 as CGFloat // ...a scale-down, reading as a top-down press.
        var capHighlightCompression = 0.5 as CGFloat
        var capShadowOpacity = 0.0 as CGFloat // Runtime shadows disabled for now.
        var capShadowRadius = 3.0 as CGFloat
        var capShadowOffset = 2.0 as CGFloat
        var pressedShadowOpacityRatio = 0.35 as CGFloat
        var pressedShadowScale = 0.94 as CGFloat

        // Release springs (0 = discrete, no animation)
        var buttonReleaseDuration = 0.0 as CGFloat
        var buttonReleaseBounce = 0.15 as CGFloat
        var dPadReleaseDuration = 0.0 as CGFloat
        var dPadReleaseBounce = 0.28 as CGFloat

        // Haptics
        var releaseHapticIntensity = 0.5 as CGFloat
    }

    struct Geometry
    {
        // All rects are normalized [0, 1] in skin image space.
        var patchRect: CGRect
        var itemRect: CGRect

        var featherFraction: CGSize // Feather band width as fraction of patch width/height.
        var featheredEdges: UIRectEdge // Edges that weren't clamped to the view's bounds.
    }

    // Pre-rendered bitmaps for a layered skin's cap.
    struct CapContents
    {
        var image: CGImage

        // The complete pressed scene for buttons — well + pressed artwork with its travel
        // baked in — crossfaded over the resting cap as a single static layer, so the
        // transition is a clean morph between two complete pictures. nil for d-pads,
        // whose press is a live tilt instead.
        var pressedSceneImage: CGImage?
        var pressedScenePadding: CGFloat // Points the scene extends beyond the cap on each side.

        var shadowImage: CGImage?
        var shadowPadding: CGFloat // Points the shadow bitmap extends beyond the cap on each side.
        var shadowOpacity: CGFloat
    }
}

// A layer animating the "pressed" appearance for a single controller skin item.
//
// Patch mode (flattened skins): contents are a crop of the skin image with a pressed
// appearance, feathered at the edges and shown on top of the identical background.
// The unpressed appearance is the skin image showing through, so pressing = opacity 1
// (+ tilt for d-pads), releasing = spring back to 0.
//
// Cap mode (layered skins): contents are the item's own "cap" artwork, always visible
// over a background with the cap removed. The cap physically travels/tilts, its runtime
// drop shadow tightens, and a pressed appearance crossfades in.
class ButtonPatchLayer: CALayer
{
    let item: ControllerSkin.Item

    private(set) var isPressed = false

    private var isCap = false
    private var idleShadowOpacity = 0.0 as CGFloat

    // Cap mode sublayers. Only capContainerLayer transforms (d-pad tilt);
    // the shadow and pressed scene stay on the chassis plane.
    private let shadowLayer = CALayer()
    private let capContainerLayer = CALayer()
    private let capLayer = CALayer()
    private let pressedLayer = CALayer()

    init(item: ControllerSkin.Item, contents: CGImage, frame: CGRect, anchorPoint: CGPoint)
    {
        self.item = item

        super.init()

        self.contents = contents
        self.contentsGravity = .resize
        self.opacity = 0.0

        // Set anchorPoint before frame so the frame setter derives the correct position.
        self.anchorPoint = anchorPoint
        self.frame = frame

        self.allowsEdgeAntialiasing = true
    }

    init(item: ControllerSkin.Item, capContents: CapContents, frame: CGRect)
    {
        self.item = item
        self.isCap = true

        super.init()

        self.frame = frame

        let disabledActions = ["contents": NSNull(), "opacity": NSNull(), "transform": NSNull(), "position": NSNull(), "bounds": NSNull()]

        self.idleShadowOpacity = capContents.shadowOpacity

        if let shadowImage = capContents.shadowImage
        {
            self.shadowLayer.contents = shadowImage
            self.shadowLayer.contentsGravity = .resize
            self.shadowLayer.frame = self.bounds.insetBy(dx: -capContents.shadowPadding, dy: -capContents.shadowPadding)
            self.shadowLayer.opacity = Float(capContents.shadowOpacity)
            self.shadowLayer.actions = disabledActions
            self.addSublayer(self.shadowLayer)
        }

        self.capContainerLayer.frame = self.bounds
        self.capContainerLayer.allowsEdgeAntialiasing = true
        self.capContainerLayer.actions = disabledActions
        self.addSublayer(self.capContainerLayer)

        self.capLayer.contents = capContents.image
        self.capLayer.contentsGravity = .resize
        self.capLayer.frame = self.capContainerLayer.bounds
        self.capLayer.actions = disabledActions
        self.capContainerLayer.addSublayer(self.capLayer)

        // The pressed scene crossfades in as a single static layer above the resting cap.
        if let pressedSceneImage = capContents.pressedSceneImage
        {
            self.pressedLayer.contents = pressedSceneImage
            self.pressedLayer.contentsGravity = .resize
            self.pressedLayer.frame = self.bounds.insetBy(dx: -capContents.pressedScenePadding, dy: -capContents.pressedScenePadding)
            self.pressedLayer.opacity = 0.0
            self.pressedLayer.actions = disabledActions
            self.addSublayer(self.pressedLayer)
        }
    }

    override init(layer: Any)
    {
        let layer = layer as! ButtonPatchLayer
        self.item = layer.item
        self.isPressed = layer.isPressed
        self.isCap = layer.isCap
        self.idleShadowOpacity = layer.idleShadowOpacity

        super.init(layer: layer)
    }

    required init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }

    override func action(forKey event: String) -> CAAction?
    {
        // Disable all implicit animations. Press-in must be instantaneous,
        // and releases are explicit spring animations we add ourselves.
        return NSNull()
    }
}

extension ButtonPatchLayer
{
    func press(tilt: CGPoint = .zero)
    {
        let tuning = Tuning.shared

        // Cancel any in-flight release fades — a new press snaps immediately.
        // (Transforms are handled per-path below so direction rolls stay continuous.)
        self.removeAnimation(forKey: "opacity")
        self.shadowLayer.removeAllAnimations()
        self.capLayer.removeAllAnimations()
        self.pressedLayer.removeAllAnimations()

        if self.isCap
        {
            // Buttons' press motion is baked into the pressed scene; d-pads tilt live.
            self.pressedLayer.opacity = 1.0
            self.shadowLayer.opacity = Float(self.idleShadowOpacity * tuning.pressedShadowOpacityRatio)
            self.shadowLayer.transform = CATransform3DMakeScale(tuning.pressedShadowScale, tuning.pressedShadowScale, 1.0)

            if self.item.kind == .dPad
            {
                self.tilt(self.capContainerLayer, to: ButtonPatchLayer.tiltTransform(for: tilt, scale: tuning.dPadPressedScale))
            }
        }
        else
        {
            self.opacity = 1.0

            if self.item.kind == .dPad
            {
                self.tilt(self, to: ButtonPatchLayer.tiltTransform(for: tilt, scale: tuning.pressedScale))
            }
        }

        self.isPressed = true
    }

    func release()
    {
        guard self.isPressed else { return }
        self.isPressed = false

        let tuning = Tuning.shared

        let duration = (self.item.kind == .dPad) ? tuning.dPadReleaseDuration : tuning.buttonReleaseDuration
        let bounce = (self.item.kind == .dPad) ? tuning.dPadReleaseBounce : tuning.buttonReleaseBounce

        if self.isCap
        {
            self.addSpringAnimation(keyPath: "opacity", to: 0.0 as Float, layer: self.pressedLayer, duration: duration, bounce: bounce)
            self.addSpringAnimation(keyPath: "opacity", to: Float(self.idleShadowOpacity), layer: self.shadowLayer, duration: duration, bounce: bounce)
            self.addSpringAnimation(keyPath: "transform", to: CATransform3DIdentity, layer: self.shadowLayer, duration: duration, bounce: bounce)
            self.addSpringAnimation(keyPath: "transform", to: CATransform3DIdentity, layer: self.capContainerLayer, duration: duration, bounce: bounce)
        }
        else
        {
            if self.item.kind == .dPad
            {
                self.addSpringAnimation(keyPath: "transform", to: CATransform3DIdentity, layer: self, duration: duration, bounce: bounce)
            }

            self.addSpringAnimation(keyPath: "opacity", to: 0.0 as Float, layer: self, duration: duration, bounce: bounce)
        }
    }
}

private extension ButtonPatchLayer
{
    // Initial press-in tilts instantly, but rolling between committed poses eases
    // briefly — snapping from pose to pose reads as glitchy.
    func tilt(_ layer: CALayer, to transform: CATransform3D)
    {
        if self.isPressed
        {
            self.addSpringAnimation(keyPath: "transform", to: transform, layer: layer, duration: Tuning.shared.dPadRollDuration, bounce: 0)
        }
        else
        {
            layer.removeAnimation(forKey: "transform")
            layer.transform = transform
        }
    }

    func addSpringAnimation(keyPath: String, to value: Any, layer: CALayer, duration: CGFloat, bounce: CGFloat)
    {
        // Duration 0 = discrete state change, no animation.
        guard duration > 0.01 else {
            layer.removeAnimation(forKey: keyPath)
            layer.setValue(value, forKeyPath: keyPath)
            return
        }

        // Start from the presentation value so repeated/interrupted releases don't pop.
        let fromValue = layer.presentation()?.value(forKeyPath: keyPath) ?? layer.value(forKeyPath: keyPath)

        let animation = CASpringAnimation(perceptualDuration: duration, bounce: bounce)
        animation.keyPath = keyPath
        animation.fromValue = fromValue
        animation.toValue = value
        animation.duration = animation.settlingDuration

        layer.setValue(value, forKeyPath: keyPath)
        layer.add(animation, forKey: keyPath)
    }
}

extension ButtonPatchLayer
{
    static func tiltTransform(for tilt: CGPoint, scale: CGFloat) -> CATransform3D
    {
        let tuning = Tuning.shared

        var transform = CATransform3DIdentity
        transform.m34 = -1.0 / tuning.perspectiveDistance
        transform = CATransform3DTranslate(transform, 0, 0, -tuning.pressDepth)
        transform = CATransform3DScale(transform, scale, scale, 1.0)

        let magnitude = min(hypot(tilt.x, tilt.y), 1.0)
        guard magnitude > tuning.tiltDeadzone else {
            // Dead-center press: the whole d-pad pushes straight in.
            return transform
        }

        // Rotate around the axis perpendicular to the press direction,
        // signed so the pressed side goes into the screen.
        let angle = tuning.tiltDegrees * .pi / 180.0 * magnitude
        transform = CATransform3DRotate(transform, angle, -tilt.y / magnitude, tilt.x / magnitude, 0)

        return transform
    }
}

//MARK: - Bitmap generation -

extension ButtonPatchLayer
{
    static func makeCapContents(from cap: ControllerSkin.Cap, background: UIImage?, pressedSkinImage: UIImage? = nil, generatesPressedAppearance: Bool = true) -> CapContents?
    {
        guard let capImage = cap.image.cgImage else { return nil }

        let tuning = Tuning.shared
        let scale = max(cap.image.scale, 1.0)

        var pressedSceneImage: CGImage? = nil
        var pressedScenePadding = 0.0 as CGFloat

        // Generous padding so the region includes the pressed state's entire shadow ring,
        // with its boundary landing on flat chassis that matches the background.
        let pressedSkinImagePadding = ceil(16.0 * scale)

        if generatesPressedAppearance, cap.pressedImage != nil, let (sceneImage, sceneRect) = self.wellImage(behind: cap, in: pressedSkinImage, outsetByPixels: pressedSkinImagePadding)
        {
            // The skin provides a full pressed image: the item's pressed scene is simply
            // its region of that image, exactly as the designer composed it — no motion.
            let canvasSize = CGSize(width: CGFloat(capImage.width) + pressedSkinImagePadding * 2.0,
                                    height: CGFloat(capImage.height) + pressedSkinImagePadding * 2.0)

            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            format.opaque = false

            let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
            pressedSceneImage = renderer.image { _ in
                UIImage(cgImage: sceneImage).draw(in: sceneRect)
            }.cgImage

            pressedScenePadding = pressedSkinImagePadding / scale
        }
        else if generatesPressedAppearance
        {
            let pressedArt: CGImage?
            let travel: CGFloat
            let pressedScale: CGFloat

            if let authoredPressedImage = cap.pressedImage?.cgImage
            {
                pressedArt = authoredPressedImage
                travel = tuning.capTravel
                pressedScale = 1.0
            }
            else
            {
                // Without authored pressed artwork, scaling down + slight travel reads as
                // a top-down press — geometry only, no generated shading.
                pressedArt = capImage
                travel = tuning.generatedCapTravel
                pressedScale = tuning.generatedCapPressedScale
            }

            let padding = ceil(travel * scale)

            if let pressedArt, let (wellImage, wellRect) = self.wellImage(behind: cap, in: background, outsetByPixels: padding)
            {
                // Bake the complete pressed scene: the (static) well and its surroundings
                // filling the whole canvas — any transparent gap would resample into a
                // hairline seam — with the pressed artwork drawn at its traveled position.
                let capSize = CGSize(width: capImage.width, height: capImage.height)
                let canvasSize = CGSize(width: capSize.width + padding * 2.0, height: capSize.height + padding * 2.0)
                let capRect = CGRect(x: padding, y: padding, width: capSize.width, height: capSize.height)

                let format = UIGraphicsImageRendererFormat()
                format.scale = 1.0
                format.opaque = false

                var artRect = capRect.offsetBy(dx: 0, dy: travel * scale)
                artRect = artRect.insetBy(dx: artRect.width * (1.0 - pressedScale) / 2.0, dy: artRect.height * (1.0 - pressedScale) / 2.0)

                let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
                pressedSceneImage = renderer.image { _ in
                    UIImage(cgImage: wellImage).draw(in: wellRect)
                    UIImage(cgImage: pressedArt).draw(in: artRect)
                }.cgImage

                pressedScenePadding = padding / scale
            }
        }

        // Prefer the skin's authored shadow parameters (normalized to the full skin image);
        // otherwise fall back to a generic downward shadow.
        let shadowOffset: CGSize
        let shadowBlur: CGFloat
        let shadowOpacity: CGFloat

        if let shadow = cap.shadow, cap.frame.width > 0, cap.frame.height > 0
        {
            let skinImageWidth = CGFloat(capImage.width) / cap.frame.width
            let skinImageHeight = CGFloat(capImage.height) / cap.frame.height

            shadowOffset = CGSize(width: shadow.offset.width * skinImageWidth, height: shadow.offset.height * skinImageHeight)
            shadowBlur = shadow.blur * skinImageWidth
            shadowOpacity = shadow.opacity
        }
        else
        {
            shadowOffset = CGSize(width: 0, height: tuning.capShadowOffset * scale)
            shadowBlur = tuning.capShadowRadius * scale
            shadowOpacity = tuning.capShadowOpacity
        }

        var shadowImage: CGImage? = nil
        var shadowPadding = 0.0 as CGFloat

        if shadowOpacity > 0, let (image, padding) = self.makeCapShadow(from: cap.image, offset: shadowOffset, blur: shadowBlur, scale: scale)
        {
            shadowImage = image
            shadowPadding = padding
        }

        return CapContents(image: capImage, pressedSceneImage: pressedSceneImage, pressedScenePadding: pressedScenePadding, shadowImage: shadowImage, shadowPadding: shadowPadding, shadowOpacity: shadowOpacity)
    }

    static func makeContents(from image: UIImage, geometry: Geometry, addsGeneratedShading: Bool) -> CGImage?
    {
        guard let cgImage = image.cgImage else { return nil }

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

        // Crop against this image's own pixel dimensions — the base and pressed
        // images may have different sizes, but normalized coordinates hold for both.
        let pixelRect = CGRect(x: geometry.patchRect.minX * imageSize.width,
                               y: geometry.patchRect.minY * imageSize.height,
                               width: geometry.patchRect.width * imageSize.width,
                               height: geometry.patchRect.height * imageSize.height).integral
        guard !pixelRect.isEmpty, let croppedImage = cgImage.cropping(to: pixelRect) else { return nil }

        let itemFrame = CGRect(x: geometry.itemRect.minX * imageSize.width - pixelRect.minX,
                               y: geometry.itemRect.minY * imageSize.height - pixelRect.minY,
                               width: geometry.itemRect.width * imageSize.width,
                               height: geometry.itemRect.height * imageSize.height)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: pixelRect.size, format: format)
        let patchImage = renderer.image { (rendererContext) in
            let context = rendererContext.cgContext

            UIImage(cgImage: croppedImage).draw(in: CGRect(origin: .zero, size: pixelRect.size))

            if addsGeneratedShading
            {
                self.drawGeneratedShading(in: context, croppedImage: croppedImage, itemFrame: itemFrame)
            }

            self.applyFeather(to: context, size: pixelRect.size, geometry: geometry)
        }

        return patchImage.cgImage
    }
}

private extension ButtonPatchLayer
{
    static let ciContext = CIContext()

    // Returns the background behind the cap plus `outsetByPixels` on each side, along with
    // the rect it occupies in the padded scene canvas (differs at skin edges, where the
    // outset gets clamped to the background's bounds).
    static func wellImage(behind cap: ControllerSkin.Cap, in background: UIImage?, outsetByPixels padding: CGFloat) -> (CGImage, CGRect)?
    {
        guard let backgroundImage = background?.cgImage else { return nil }

        let capRect = CGRect(x: cap.frame.minX * CGFloat(backgroundImage.width),
                             y: cap.frame.minY * CGFloat(backgroundImage.height),
                             width: cap.frame.width * CGFloat(backgroundImage.width),
                             height: cap.frame.height * CGFloat(backgroundImage.height)).integral

        let outsetRect = capRect.insetBy(dx: -padding, dy: -padding)
        let clampedRect = outsetRect.intersection(CGRect(x: 0, y: 0, width: backgroundImage.width, height: backgroundImage.height)).integral

        guard !clampedRect.isEmpty, let wellImage = backgroundImage.cropping(to: clampedRect) else { return nil }

        let canvasRect = CGRect(x: clampedRect.minX - outsetRect.minX,
                                y: clampedRect.minY - outsetRect.minY,
                                width: clampedRect.width,
                                height: clampedRect.height)

        return (wellImage, canvasRect)
    }

    // Approximates hand-authored pressed artwork: compress the specular highlights,
    // darken adaptively to the artwork's brightness, and occlude the top edge —
    // all confined to the cap's own alpha.
    static func makeGeneratedPressedCap(from image: UIImage) -> CGImage?
    {
        guard var cgImage = image.cgImage else { return nil }

        let tuning = Tuning.shared

        // Highlight compression — the dome catches less light when it sits deeper in the well.
        if tuning.capHighlightCompression < 1.0
        {
            let inputImage = CIImage(cgImage: cgImage)

            let filter = CIFilter.highlightShadowAdjust()
            filter.inputImage = inputImage
            filter.highlightAmount = Float(tuning.capHighlightCompression)
            filter.shadowAmount = 0.0

            // Crop to the input's extent — the filter blurs internally, which pads its
            // output extent and would misalign the pressed artwork over the regular cap.
            if let outputImage = filter.outputImage, let filteredImage = self.ciContext.createCGImage(outputImage, from: inputImage.extent)
            {
                cgImage = filteredImage
            }
        }

        let size = CGSize(width: cgImage.width, height: cgImage.height)
        let luminance = self.averageLuminance(of: cgImage, in: CGRect(origin: .zero, size: size))
        let darkenAlpha = tuning.minimumDarkenAlpha + (tuning.maximumDarkenAlpha - tuning.minimumDarkenAlpha) * (1.0 - luminance)
        let occlusionAlpha = min(darkenAlpha * tuning.occlusionAlphaRatio, 1.0)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let pressedImage = renderer.image { (rendererContext) in
            let context = rendererContext.cgContext

            UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: size))

            // .sourceAtop confines the shading to the cap's alpha without thinning its edges.
            context.setBlendMode(.sourceAtop)

            let colorSpace = CGColorSpaceCreateDeviceRGB()

            // Center-weighted darkening, fading toward the rim — a uniform fill reads
            // as a hard tonal step at the cap's edge.
            let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            let outerRadius = hypot(size.width, size.height) / 2.0 * 1.05

            let darkenColors = [UIColor.black.withAlphaComponent(darkenAlpha).cgColor,
                                UIColor.black.withAlphaComponent(darkenAlpha).cgColor,
                                UIColor.black.withAlphaComponent(0).cgColor]

            if let gradient = CGGradient(colorsSpace: colorSpace, colors: darkenColors as CFArray, locations: [0, 0.55, 1])
            {
                context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: outerRadius, options: [])
            }

            let occlusionColors = [UIColor.black.withAlphaComponent(occlusionAlpha).cgColor,
                                   UIColor.black.withAlphaComponent(0).cgColor]

            if let gradient = CGGradient(colorsSpace: colorSpace, colors: occlusionColors as CFArray, locations: [0, 1])
            {
                context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height * tuning.occlusionHeight), options: [])
            }

            context.setBlendMode(.normal)
        }

        return pressedImage.cgImage
    }

    // A drop shadow rendered from the cap's silhouette, so it can tighten as the cap descends.
    // Offset and blur are in cap-image pixels.
    static func makeCapShadow(from image: UIImage, offset: CGSize, blur: CGFloat, scale: CGFloat) -> (CGImage, CGFloat)?
    {
        guard let cgImage = image.cgImage else { return nil }

        let padding = ceil(blur * 2.0 + max(abs(offset.width), abs(offset.height)))

        let capSize = CGSize(width: cgImage.width, height: cgImage.height)
        let canvasSize = CGSize(width: capSize.width + padding * 2.0, height: capSize.height + padding * 2.0)
        let capRect = CGRect(x: padding, y: padding, width: capSize.width, height: capSize.height)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        let shadowImage = renderer.image { (rendererContext) in
            let context = rendererContext.cgContext

            // Draw the cap far below the canvas so only its shadow lands in frame —
            // no hard clipping edges, just the blur's own falloff everywhere.
            //
            // Shadow offsets ignore the context's flipped coordinate system (they're in
            // base space, y-up), so the vertical compensation is displacement - offset
            // rather than displacement + offset.
            let displacement = canvasSize.height + capSize.height

            context.setShadow(offset: CGSize(width: offset.width, height: displacement - offset.height),
                              blur: blur,
                              color: UIColor.black.cgColor)

            UIImage(cgImage: cgImage).draw(in: capRect.offsetBy(dx: 0, dy: displacement))
        }

        guard let shadowCGImage = shadowImage.cgImage else { return nil }
        return (shadowCGImage, padding / scale)
    }

    static func drawGeneratedShading(in context: CGContext, croppedImage: CGImage, itemFrame: CGRect)
    {
        let tuning = Tuning.shared

        // Scale the shading with the artwork's brightness — a fixed darken that
        // reads clearly on light buttons is nearly invisible on dark ones.
        let luminance = self.averageLuminance(of: croppedImage, in: itemFrame)
        let darkenAlpha = tuning.minimumDarkenAlpha + (tuning.maximumDarkenAlpha - tuning.minimumDarkenAlpha) * (1.0 - luminance)
        let occlusionAlpha = min(darkenAlpha * tuning.occlusionAlphaRatio, 1.0)

        let colorSpace = CGColorSpaceCreateDeviceRGB()

        // Overall darkening, fading out past the item's edges so the spill onto
        // the surrounding background reads as a finger-contact shadow.
        let center = CGPoint(x: itemFrame.midX, y: itemFrame.midY)
        let innerRadius = min(itemFrame.width, itemFrame.height) / 2.0
        let outerRadius = hypot(itemFrame.width, itemFrame.height) / 2.0 * (1.0 + tuning.shadeFeather)

        let darkenColors = [UIColor.black.withAlphaComponent(darkenAlpha).cgColor,
                            UIColor.black.withAlphaComponent(darkenAlpha).cgColor,
                            UIColor.black.withAlphaComponent(0).cgColor]

        if let gradient = CGGradient(colorsSpace: colorSpace, colors: darkenColors as CFArray, locations: [0, innerRadius / outerRadius, 1])
        {
            context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: outerRadius, options: [])
        }

        // Occlusion from the bezel's top edge — an elliptical shadow centered on
        // the item's top, reaching occlusionHeight of the way down.
        let occlusionColors = [UIColor.black.withAlphaComponent(occlusionAlpha).cgColor,
                               UIColor.black.withAlphaComponent(0).cgColor]

        if let gradient = CGGradient(colorsSpace: colorSpace, colors: occlusionColors as CFArray, locations: [0, 1])
        {
            let horizontalRadius = itemFrame.width / 2.0
            let verticalRadius = tuning.occlusionHeight * itemFrame.height

            context.saveGState()
            context.translateBy(x: itemFrame.midX, y: itemFrame.minY)
            context.scaleBy(x: 1.0, y: verticalRadius / horizontalRadius)
            context.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: horizontalRadius, options: [])
            context.restoreGState()
        }
    }

    // Fade the patch's alpha to zero at its edges so it blends invisibly into the
    // skin image beneath, even while transformed. Baked into the bitmap because a
    // runtime CALayer.mask would force an offscreen pass on every frame.
    static func applyFeather(to context: CGContext, size: CGSize, geometry: Geometry)
    {
        let featherWidth = geometry.featherFraction.width * size.width
        let featherHeight = geometry.featherFraction.height * size.height

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.cgColor]
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0, 1]) else { return }

        context.setBlendMode(.destinationIn)

        if geometry.featheredEdges.contains(.top)
        {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: featherHeight), options: [])
        }

        if geometry.featheredEdges.contains(.bottom)
        {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: 0, y: size.height - featherHeight), options: [])
        }

        if geometry.featheredEdges.contains(.left)
        {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: featherWidth, y: 0), options: [])
        }

        if geometry.featheredEdges.contains(.right)
        {
            context.drawLinearGradient(gradient, start: CGPoint(x: size.width, y: 0), end: CGPoint(x: size.width - featherWidth, y: 0), options: [])
        }

        context.setBlendMode(.normal)
    }

    static func averageLuminance(of image: CGImage, in rect: CGRect) -> CGFloat
    {
        let sampleRect = rect.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard !sampleRect.isEmpty, let sampleImage = image.cropping(to: sampleRect) else { return 0.5 }

        // Downsample to 4x4 and average — plenty accurate for choosing a shading strength.
        let dimension = 4
        var pixels = [UInt8](repeating: 0, count: dimension * dimension * 4)

        guard let context = CGContext(data: &pixels,
                                      width: dimension,
                                      height: dimension,
                                      bitsPerComponent: 8,
                                      bytesPerRow: dimension * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return 0.5 }

        context.interpolationQuality = .medium
        context.draw(sampleImage, in: CGRect(x: 0, y: 0, width: dimension, height: dimension))

        var totalLuminance = 0.0 as CGFloat
        var totalAlpha = 0.0 as CGFloat

        for index in stride(from: 0, to: pixels.count, by: 4)
        {
            let red = CGFloat(pixels[index]) / 255.0
            let green = CGFloat(pixels[index + 1]) / 255.0
            let blue = CGFloat(pixels[index + 2]) / 255.0
            let alpha = CGFloat(pixels[index + 3]) / 255.0

            // Premultiplied, so this weights each pixel's luminance by its alpha.
            totalLuminance += 0.2126 * red + 0.7152 * green + 0.0722 * blue
            totalAlpha += alpha
        }

        guard totalAlpha > 0 else { return 0.5 }
        return min(max(totalLuminance / totalAlpha, 0.0), 1.0)
    }
}
