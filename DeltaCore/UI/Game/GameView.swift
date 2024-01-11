//
//  GameView.swift
//  DeltaCore
//
//  Created by Riley Testut on 3/16/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import UIKit
import CoreImage
import AVFoundation
import Metal

public enum SamplerMode
{
    case linear
    case nearestNeighbor
}

public class GameView: UIView
{
    public var isEnabled: Bool = true
    
    @NSCopying public var inputImage: CIImage? {
        didSet {
            if self.inputImage?.extent != oldValue?.extent
            {
                DispatchQueue.main.async {
                    self.setNeedsLayout()
                }
            }
            
            self.update()
        }
    }
    
    @NSCopying public var filter: CIFilter? {
        didSet {
            guard self.filter != oldValue else { return }
            self.update()
        }
    }
    
    public var samplerMode: SamplerMode = .nearestNeighbor {
        didSet {
            self.update()
        }
    }
    
    public var outputImage: CIImage? {
        guard let inputImage = self.inputImage else { return nil }
        
        var image: CIImage?
        
        switch self.samplerMode
        {
        case .linear: image = inputImage.samplingLinear()
        case .nearestNeighbor: image = inputImage.samplingNearest()
        }
                
        if let filter = self.filter
        {
            filter.setValue(image, forKey: kCIInputImageKey)
            image = filter.outputImage
        }
        
        return image
    }
    
    private lazy var context: CIContext = self.makeContext()
    
    private let metalLayer = CAMetalLayer()
    private let metalDevice = MTLCreateSystemDefaultDevice()!
    private lazy var metalCommandQueue = self.metalDevice.makeCommandQueue()!
    
    private var lock = os_unfair_lock()
    private var didLayoutSubviews = false
    
    public override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        self.initialize()
    }
    
    public required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        self.initialize()
    }
    
    private func initialize()
    {
        self.metalLayer.device = self.metalDevice
        self.metalLayer.frame = self.bounds
        self.metalLayer.framebufferOnly = false // Required for rendering
        self.layer.addSublayer(self.metalLayer)
    }
    
    public override func didMoveToWindow()
    {
        if let window = self.window
        {
            self.metalLayer.contentsScale = window.contentScaleFactor
            self.update()
        }
    }
    
    public override func layoutSubviews()
    {
        super.layoutSubviews()
        
        self.metalLayer.isHidden = (self.outputImage == nil)
        self.metalLayer.frame = CGRect(origin: .zero, size: self.bounds.size)
        
        self.didLayoutSubviews = true
    }
}

public extension GameView
{
    func snapshot() -> UIImage?
    {
        // Unfortunately, rendering CIImages doesn't always work when backed by an OpenGLES texture.
        // As a workaround, we simply render the view itself into a graphics context the same size
        // as our output image.
        //
        // let cgImage = self.context.createCGImage(outputImage, from: outputImage.extent)
        
        guard let outputImage = self.outputImage else { return nil }

        let rect = CGRect(origin: .zero, size: outputImage.extent.size)
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        
        let renderer = UIGraphicsImageRenderer(size: rect.size, format: format)
        
        let snapshot = renderer.image { (context) in
            self.drawHierarchy(in: rect, afterScreenUpdates: false)
        }
        
        return snapshot
    }
    
    func update(for screen: ControllerSkin.Screen)
    {
        var filters = [CIFilter]()
        
        if let inputFrame = screen.inputFrame
        {
            let cropFilter = CIFilter(name: "CICrop", parameters: ["inputRectangle": CIVector(cgRect: inputFrame)])!
            filters.append(cropFilter)
        }
        
        if let screenFilters = screen.filters
        {
            filters.append(contentsOf: screenFilters)
        }
        
        // Always use FilterChain since it has additional logic for chained filters.
        let filterChain = filters.isEmpty ? nil : FilterChain(filters: filters)
        self.filter = filterChain
    }
}

private extension GameView
{
    func makeContext() -> CIContext
    {
        let context = CIContext(mtlCommandQueue: self.metalCommandQueue, options: [.workingColorSpace: NSNull()])
        return context
    }
    
    func update()
    {
        // Calling display when outputImage is nil may crash for OpenGLES-based rendering.
        guard self.isEnabled && self.outputImage != nil else { return }
        
        os_unfair_lock_lock(&self.lock)
        defer { os_unfair_lock_unlock(&self.lock) }
        
        // layoutSubviews() must be called after setting self.eaglContext before we can display anything.
        // Otherwise, the app may crash due to race conditions when creating framebuffer from background thread.
        guard self.didLayoutSubviews else { return }

        self.draw(in: self.metalLayer)
    }
}

private extension GameView
{
    func draw(in layer: CAMetalLayer)
    {
        autoreleasepool {
            
            guard let image = self.outputImage,
                  let commandBuffer = self.metalCommandQueue.makeCommandBuffer(),
                  let currentDrawable = layer.nextDrawable()
            else {
                return
            }
            
            let scaleX = layer.drawableSize.width / image.extent.width
            let scaleY = layer.drawableSize.height / image.extent.height
            let outputImage = image.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            
            do
            {
                let destination = CIRenderDestination(width: Int(layer.drawableSize.width),
                                                      height: Int(layer.drawableSize.height),
                                                      pixelFormat: layer.pixelFormat,
                                                      commandBuffer: nil) { [unowned currentDrawable] () -> MTLTexture in
                    // Lazily return texture to prevent hangs due to waiting for previous command to finish
                    let texture = currentDrawable.texture
                    return texture
                }
                
                try self.context.startTask(toRender: outputImage, from: outputImage.extent, to: destination, at: .zero)
                
                commandBuffer.present(currentDrawable)
                commandBuffer.commit()
            }
            catch
            {
                print("Failed to render:", error)
            }
        }
    }
}
