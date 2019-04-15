//
//  VideoManager.swift
//  DeltaCore
//
//  Created by Riley Testut on 3/16/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation
import Accelerate
import CoreImage
import GLKit

protocol VideoProcessor
{
    var videoBuffer: UnsafeMutablePointer<UInt8>? { get }
    
    func prepare()
    func processFrame() -> CIImage?
}

public class VideoManager: NSObject, VideoRendering
{
    public internal(set) var videoFormat: VideoFormat {
        didSet {
            self.updateProcessor()
        }
    }
    
    public private(set) var gameViews = [GameView]()
    
    public var isEnabled = true
    
    private let context: EAGLContext
    
    private var processor: VideoProcessor
    private var processedImage: CIImage?
    
    public init(videoFormat: VideoFormat)
    {
        self.videoFormat = videoFormat
        self.context = EAGLContext(api: .openGLES2)!
        
        switch videoFormat.format
        {
        case .bitmap: self.processor = BitmapProcessor(videoFormat: videoFormat)
        case .openGLES: self.processor = OpenGLESProcessor(videoFormat: videoFormat, context: self.context)
        }
        
        super.init()
    }
    
    private func updateProcessor()
    {
        switch self.videoFormat.format
        {
        case .bitmap:
            self.processor = BitmapProcessor(videoFormat: self.videoFormat)
            
        case .openGLES:
            guard let processor = self.processor as? OpenGLESProcessor else { return }
            processor.videoFormat = self.videoFormat
        }
    }
}

public extension VideoManager
{
    func add(_ gameView: GameView)
    {
        gameView.eaglContext = self.context
        self.gameViews.append(gameView)
    }
    
    func remove(_ gameView: GameView)
    {
        if let index = self.gameViews.firstIndex(of: gameView)
        {
            self.gameViews.remove(at: index)
        }
    }
}

public extension VideoManager
{
    var videoBuffer: UnsafeMutablePointer<UInt8>? {
        return self.processor.videoBuffer
    }
    
    func prepare()
    {
        self.processor.prepare()
    }
    
    func processFrame()
    {
        guard self.isEnabled else { return }
        
        self.processedImage = self.processor.processFrame()
    }
    
    func render()
    {
        guard self.isEnabled else { return }
        
        guard let image = self.processedImage else { return }
        
        for gameView in self.gameViews
        {
            gameView.inputImage = image
        }
    }
}
