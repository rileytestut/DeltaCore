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
        return self.filterChain.outputImage
    }
    
    fileprivate let filterChain = FilterChain(filters: [])
    fileprivate let samplerFilter = SamplerFilter()
    
    fileprivate let glkView: GLKView
    fileprivate let context: CIContext
    
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
        self.glkView.enableSetNeedsDisplay = false
        self.addSubview(self.glkView)
    }
    
    public override func didMoveToWindow()
    {
        if let window = self.window
        {
            self.glkView.contentScaleFactor = window.screen.scale
            self.update()
        }
    }
}

private extension GameView
{
    func updateFilterChain()
    {
        self.filterChain.inputImage = self.inputImage
        self.filterChain.inputFilters = [self.samplerFilter, self.filter].flatMap { $0 }
        self.update()
    }
    
    func update()
    {
        guard self.window != nil, !self.bounds.isEmpty else { return }
        
        self.glkView.display()
    }
}

extension GameView: GLKViewDelegate
{
    public func glkView(_ view: GLKView, drawIn rect: CGRect)
    {        
        guard let window = self.window, !self.bounds.isEmpty else { return }
        
        glClearColor(0.0, 0.0, 0.0, 1.0)
        glClear(UInt32(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        
        if let outputImage = self.outputImage
        {
            let bounds = CGRect(x: 0, y: 0, width: self.bounds.width * window.screen.scale, height: self.bounds.height * window.screen.scale)
            
            let rect = AVMakeRect(aspectRatio: outputImage.extent.size, insideRect: bounds)
            self.context.draw(outputImage, in: rect, from: outputImage.extent)
        }
    }
}
