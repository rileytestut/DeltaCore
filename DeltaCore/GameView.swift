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

import Roxas

public class GameView: UIView
{
    @NSCopying public var filter: CIFilter? {
        didSet
        {
            self.filter?.setValue(self.inputImage, forKey: kCIInputImageKey)
            self.update()
        }
    }
    
    public var inputImage: CIImage? {
        didSet
        {
            self.filter?.setValue(self.inputImage, forKey: kCIInputImageKey)
            self.update()
        }
    }
    
    public var outputImage: CIImage? {
        let outputImage = self.filter?.outputImage ?? self.inputImage
        return outputImage
    }
    
    private let glkView: GLKView
    
    private let context: CIContext
    
    public override init(frame: CGRect)
    {
        let eaglContext = EAGLContext(API: .OpenGLES2)
        self.glkView = GLKView(frame: CGRectZero, context: eaglContext)
        self.context = CIContext(EAGLContext: eaglContext, options: [kCIContextWorkingColorSpace: NSNull()])
        
        super.init(frame: frame)
        
        self.initialize()
    }
    
    public required init?(coder aDecoder: NSCoder)
    {
        let eaglContext = EAGLContext(API: .OpenGLES2)
        self.glkView = GLKView(frame: CGRectZero, context: eaglContext)
        self.context = CIContext(EAGLContext: eaglContext, options: [kCIContextWorkingColorSpace: NSNull()])
        
        super.init(coder: aDecoder)
        
        self.initialize()
    }
    
    private func initialize()
    {        
        self.glkView.frame = self.bounds
        self.glkView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.glkView.delegate = self
        self.glkView.enableSetNeedsDisplay = false
        self.addSubview(self.glkView)
    }
    
    public override func didMoveToWindow()
    {
        if let window = self.window
        {
            self.glkView.contentScaleFactor = window.screen.scale
        }
    }
}

private extension GameView
{
    func update()
    {
        self.glkView.display()
    }
}

extension GameView: GLKViewDelegate
{
    public func glkView(view: GLKView, drawInRect rect: CGRect)
    {        
        guard let window = self.window where !CGRectIsEmpty(self.bounds) else { return }
        
        if let outputImage = self.outputImage
        {
            let bounds = CGRect(x: 0, y: 0, width: self.bounds.width * window.screen.scale, height: self.bounds.height * window.screen.scale)
            
            let rect = AVMakeRectWithAspectRatioInsideRect(outputImage.extent.size, bounds)
            self.context.drawImage(outputImage, inRect: rect, fromRect: outputImage.extent)
        }
    }
}