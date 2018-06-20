//
//  GameView.swift
//  DeltaCore
//
//  Created by Riley Testut on 3/16/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import UIKit
import CoreImage
import GLKit
import AVFoundation

public class GameView: UIView
{
    @NSCopying public var inputImage: CIImage? {
        didSet {
            self.updateFilterChain()
        }
    }
    
    @NSCopying public var filter: CIFilter? {
        didSet {
            self.updateFilterChain()
        }
    }
    
    public var samplerMode: SamplerMode {
        get { return self.samplerFilter.inputMode }
        set { self.samplerFilter.inputMode = newValue }
    }
    
    public var outputImage: CIImage? {
        guard let inputImage = self.inputImage else { return nil }
        return self.filterChain.outputImage?.cropped(to: inputImage.extent)
    }
    
    private let filterChain = FilterChain(filters: [])
    private let samplerFilter = SamplerFilter()
    
    private let glkView: GLKView
    private let context: CIContext
    
    // Cache these properties so we don't access UIKit methods when rendering on background thread.
    private var _screenScale: CGFloat?
    private var _bounds = CGRect.zero
    
    public override init(frame: CGRect)
    {
        let eaglContext = EAGLContext(api: .openGLES2)
        self.glkView = GLKView(frame: CGRect.zero, context: eaglContext!)
        self.context = CIContext(eaglContext: eaglContext!, options: [kCIContextWorkingColorSpace: NSNull()])
        
        super.init(frame: frame)
        
        self.initialize()
    }
    
    public required init?(coder aDecoder: NSCoder)
    {
        let eaglContext = EAGLContext(api: .openGLES2)
        self.glkView = GLKView(frame: CGRect.zero, context: eaglContext!)
        self.context = CIContext(eaglContext: eaglContext!, options: [kCIContextWorkingColorSpace: NSNull()])
        
        super.init(coder: aDecoder)
        
        self.initialize()
    }
    
    private func initialize()
    {        
        self.glkView.frame = self.bounds
        self.glkView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.glkView.delegate = self
        
        #if FRAMEWORK
        self.glkView.enableSetNeedsDisplay = false
        #else
        self.glkView.enableSetNeedsDisplay = true
        #endif
        
        self.addSubview(self.glkView)
    }
    
    public override func didMoveToWindow()
    {
        self._screenScale = self.window?.screen.scale
        
        if let window = self.window
        {
            self.glkView.contentScaleFactor = window.screen.scale
            self.update()
        }
    }
    
    public override func layoutSubviews()
    {
        super.layoutSubviews()
        
        self._bounds = self.bounds
    }
}

private extension GameView
{
    func updateFilterChain()
    {
        self.filterChain.inputImage = self.inputImage?.clampedToExtent()
        self.filterChain.inputFilters = [self.samplerFilter, self.filter].flatMap { $0 }
        self.update()
    }
    
    func update()
    {
        guard self._screenScale != nil, !self._bounds.isEmpty else { return }
        
        #if FRAMEWORK
        self.glkView.display()
        #else
        DispatchQueue.main.async {
            self.glkView.setNeedsDisplay()
        }
        #endif
    }
}

extension GameView: GLKViewDelegate
{
    public func glkView(_ view: GLKView, drawIn rect: CGRect)
    {        
        guard let scale = self._screenScale, !self._bounds.isEmpty else { return }
        
        glClearColor(0.0, 0.0, 0.0, 1.0)
        glClear(UInt32(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        
        if let outputImage = self.outputImage
        {
            let bounds = CGRect(x: 0, y: 0, width: self._bounds.width * scale, height: self._bounds.height * scale)
            
            let rect = AVMakeRect(aspectRatio: outputImage.extent.size, insideRect: bounds)
            self.context.draw(outputImage, in: rect, from: outputImage.extent)
        }
    }
}
