//
//  GameView.swift
//  DeltaCore
//
//  Created by Riley Testut on 3/16/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import UIKit
import CoreImage
//import GLKit
import MetalKit
import AVFoundation

//import GLKit
//import OpenGL

// Create wrapper class to prevent exposing GLKView (and its annoying deprecation warnings) to clients.
//private class GameViewGLKViewDelegate: NSObject, GLKViewDelegate
//{
//    weak var gameView: GameView?
//
//    init(gameView: GameView)
//    {
//        self.gameView = gameView
//    }
//
//    func glkView(_ view: GLKView, drawIn rect: CGRect)
//    {
//        self.gameView?.glkView(view, drawIn: rect)
//    }
//}

public enum SamplerMode
{
    case linear
    case nearestNeighbor
}

public class GameView: UIView
{
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
    
//    internal var eaglContext: CAOpenGLLayer!
    
//    internal var eaglContext: EAGLContext {
//        get { return self.glkView.context }
//        set {
//            // For some reason, if we don't explicitly set current EAGLContext to nil, assigning
//            // to self.glkView may crash if we've already rendered to a game view.
//            EAGLContext.setCurrent(nil)
//
//            self.glkView.context = EAGLContext(api: .openGLES2, sharegroup: newValue.sharegroup)!
//            self.context = self.makeContext()
//        }
//    }
    private lazy var context: CIContext = self.makeContext()
        
//    private let glkView: GLKView
//    private lazy var glkViewDelegate = GameViewGLKViewDelegate(gameView: self)
    
    private let mtkView: MTKView
    public lazy var metalDevice = MTLCreateSystemDefaultDevice()!
    private var metalCommandQueue: MTLCommandQueue!
    
    var surface: IOSurface? {
        didSet {
            self.layer.contents = self.surface
        }
    }
    
    public override init(frame: CGRect)
    {
//        let eaglContext = EAGLContext(api: .openGLES2)!
//        self.glkView = GLKView(frame: CGRect.zero, context: eaglContext)
        
        self.mtkView = MTKView()
        
        super.init(frame: frame)
        
        self.initialize()
    }
    
    public required init?(coder aDecoder: NSCoder)
    {
//        let eaglContext = EAGLContext(api: .openGLES2)!
//        self.glkView = GLKView(frame: CGRect.zero, context: eaglContext)
        
        self.mtkView = MTKView()
        
        super.init(coder: aDecoder)
        
        self.initialize()
    }
    
    private func initialize()
    {
//        self.glkView.frame = self.bounds
//        self.glkView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//        self.glkView.delegate = self.glkViewDelegate
//        self.glkView.enableSetNeedsDisplay = false
//        self.addSubview(self.glkView)
                
        self.mtkView.device = self.metalDevice
        self.mtkView.framebufferOnly = false
        self.mtkView.frame = self.bounds
        self.mtkView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.mtkView.delegate = self
        self.mtkView.enableSetNeedsDisplay = false
        self.mtkView.isPaused = true
        self.addSubview(self.mtkView)
        
        self.metalCommandQueue = self.metalDevice.makeCommandQueue()
    }
    
    public override func didMoveToWindow()
    {
        if let window = self.window
        {
//            self.glkView.contentScaleFactor = window.screen.scale
//            self.mtkView.contentScaleFactor = window.screen.scale
            self.update()
        }
    }
    
    public override func layoutSubviews()
    {
        super.layoutSubviews()
        
//        self.glkView.isHidden = (self.outputImage == nil)
        self.mtkView.isHidden = (self.outputImage == nil)
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
//            self.glkView.drawHierarchy(in: rect, afterScreenUpdates: false)
            self.mtkView.drawHierarchy(in: rect, afterScreenUpdates: false)
        }
        
        return snapshot
    }
}

public extension GameView
{
    func makeContext() -> CIContext
    {
//        let context = CIContext(eaglContext: self.glkView.context, options: [.workingColorSpace: NSNull()])
        let context: CIContext
        
        if #available(iOS 13.0, *)
        {
            context = CIContext(mtlCommandQueue: self.metalCommandQueue, options: [.workingColorSpace: NSNull()])
        }
        else
        {
            // Fallback on earlier versions
            context = CIContext(mtlDevice: self.metalDevice, options: [.workingColorSpace: NSNull()])
        }
        
        return context
    }
    
    func update()
    {
        // Calling display when outputImage is nil may crash for OpenGLES-based rendering.
        //guard self.outputImage != nil else { return }
                
//        self.glkView.display()
        self.mtkView.draw()
        
//        DispatchQueue.main.async {
//            self.surface?.lock(options: [.readOnly], seed: nil)
//            self.layer.contents = self.surface
//            self.surface?.unlock(options: [.readOnly], seed: nil)
//        }
    }
}

//private extension GameView
//{
//    func glkView(_ view: GLKView, drawIn rect: CGRect)
//    {
//        glClearColor(0.0, 0.0, 0.0, 1.0)
//        glClear(UInt32(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
//
//        if let outputImage = self.outputImage
//        {
//            let bounds = CGRect(x: 0, y: 0, width: self.glkView.drawableWidth, height: self.glkView.drawableHeight)
//            self.context.draw(outputImage, in: bounds, from: outputImage.extent)
//        }
//    }
//}

extension GameView: MTKViewDelegate
{
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize)
    {
//        print("Changing GameView size to:", size)
    }
    
    public func draw(in view: MTKView)
    {
        guard let image = self.outputImage,
              let currentDrawable = view.currentDrawable,
              let commandBuffer = self.metalCommandQueue.makeCommandBuffer()
        else { return }
        
        let scaleX = view.drawableSize.width / image.extent.width
        let scaleY = view.drawableSize.height / image.extent.height
        let outputImage = image.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        let bounds = CGRect(origin: .zero, size: view.drawableSize)
        self.context.render(outputImage, to: currentDrawable.texture, commandBuffer: commandBuffer, bounds: bounds, colorSpace: CGColorSpaceCreateDeviceRGB())
        
//        print("Output Size:", view.drawableSize)

//        let destination = CIRenderDestination(width: Int(view.drawableSize.width * 2),
//                                              height: Int(view.drawableSize.height * 2),
//                                              pixelFormat: view.colorPixelFormat,
//                                              commandBuffer: commandBuffer) { () -> MTLTexture in
//            return currentDrawable.texture
//        }
//
//        do
//        {
//            try self.context.startTask(toRender: outputImage, from: outputImage.extent, to: destination, at: .zero)
////            try self.context.startTask(toRender: outputImage, to: destination)
//        }
//        catch
//        {
//            print("Failed to render:", error)
//        }
        
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
}
