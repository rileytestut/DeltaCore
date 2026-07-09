//
//  ButtonPatchLayer.swift
//  DeltaCore
//
//  Created by Caroline Moore on 7/9/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import UIKit

extension ButtonPatchLayer
{
    // Every constant that affects how presses look and feel, in one place.
    // Mutable via `shared` so a debug tuning UI can adjust values live on device.
    struct Tuning
    {
        static var shared = Tuning()

        // D-pad tilt
        var tiltDegrees = 5.0 as CGFloat
        var perspectiveDistance = 500.0 as CGFloat
        var pressDepth = 1.5 as CGFloat
        var pressedScale = 1.01 as CGFloat
        var tiltDeadzone = 0.08 as CGFloat

        // Generated pressed shading
        var minimumDarkenAlpha = 0.06 as CGFloat
        var maximumDarkenAlpha = 0.17 as CGFloat
        var occlusionAlphaRatio = 1.5 as CGFloat
        var occlusionHeight = 0.35 as CGFloat
        var shadeFeather = 0.2 as CGFloat

        // Patch geometry
        var patchMarginRatio = 0.15 as CGFloat
        var minimumPatchMargin = 8.0 as CGFloat
        var featherRatio = 0.75 as CGFloat

        // Release springs
        var buttonReleaseDuration = 0.22
        var buttonReleaseBounce = 0.15 as CGFloat
        var dPadReleaseDuration = 0.3
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
}

// A layer showing the "pressed" appearance for a single controller skin item,
// positioned exactly on top of that item in the skin image.
//
// The unpressed appearance is just the skin image itself showing through,
// so pressing = opacity 1 (+ tilt for d-pads), releasing = spring back to 0.
class ButtonPatchLayer: CALayer
{
    let item: ControllerSkin.Item

    private(set) var isPressed = false

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

    override init(layer: Any)
    {
        let layer = layer as! ButtonPatchLayer
        self.item = layer.item
        self.isPressed = layer.isPressed

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
        // Cancel any in-flight release spring — a new press snaps immediately.
        self.removeAllAnimations()

        self.opacity = 1.0

        if self.item.kind == .dPad
        {
            self.transform = ButtonPatchLayer.tiltTransform(for: tilt)
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

        if self.item.kind == .dPad
        {
            self.addSpringAnimation(keyPath: "transform", to: CATransform3DIdentity, duration: duration, bounce: bounce)
        }

        self.addSpringAnimation(keyPath: "opacity", to: 0.0 as Float, duration: duration, bounce: bounce)
    }
}

private extension ButtonPatchLayer
{
    func addSpringAnimation(keyPath: String, to value: Any, duration: TimeInterval, bounce: CGFloat)
    {
        // Start from the presentation value so repeated/interrupted releases don't pop.
        let fromValue = self.presentation()?.value(forKeyPath: keyPath) ?? self.value(forKeyPath: keyPath)

        let animation = CASpringAnimation(perceptualDuration: duration, bounce: bounce)
        animation.keyPath = keyPath
        animation.fromValue = fromValue
        animation.toValue = value
        animation.duration = animation.settlingDuration

        self.setValue(value, forKeyPath: keyPath)
        self.add(animation, forKey: keyPath)
    }
}

extension ButtonPatchLayer
{
    static func tiltTransform(for tilt: CGPoint) -> CATransform3D
    {
        let tuning = Tuning.shared

        var transform = CATransform3DIdentity
        transform.m34 = -1.0 / tuning.perspectiveDistance
        transform = CATransform3DTranslate(transform, 0, 0, -tuning.pressDepth)
        transform = CATransform3DScale(transform, tuning.pressedScale, tuning.pressedScale, 1.0)

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
