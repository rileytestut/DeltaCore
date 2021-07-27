//
//  OpenGLESProcessor.swift
//  DeltaCore
//
//  Created by Riley Testut on 4/8/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import CoreImage
import GLKit

#if os(iOS)
private let GL_UNSIGNED_INT_8_8_8_8_REV = 0x8367
#endif

class OpenGLESProcessor: NSObject, VideoProcessor
{
    let videoFormat: VideoFormat
    let surface: IOSurface    
    
    var viewport: CGRect {
        get { self.surface.viewport ?? .zero }
        set { self.surface.viewport = newValue }
    }
    
    private let context: EAGLContext
    
    private var framebuffer: GLuint = 0
    private var texture: GLuint = 0
    
    private let cvPixelBuffer: CVPixelBuffer
    private let cvTextureCache: CVOpenGLESTextureCache
    private var cvOpenGLESTexture: CVOpenGLESTexture?
    
    init(videoFormat: VideoFormat)
    {
        self.videoFormat = videoFormat
        self.context = EAGLContext(api: .openGLES2)!
        
        let properties: [IOSurfacePropertyKey : Any] = [
            .width: videoFormat.dimensions.width,
            .height: videoFormat.dimensions.height,
            .pixelFormat: videoFormat.format.pixelFormat.nativePixelFormat,
            .bytesPerElement: videoFormat.format.pixelFormat.bytesPerPixel,
            .bytesPerRow: videoFormat.format.pixelFormat.bytesPerPixel * Int(videoFormat.dimensions.width) // Necessary or else games will have distorted video
        ]
        
        let cvBufferProperties = [
            kCVPixelBufferOpenGLCompatibilityKey: true,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: properties
        ] as [CFString : Any]
        
        var pixelBuffer: CVPixelBuffer?
        var result = CVPixelBufferCreate(kCFAllocatorDefault, Int(videoFormat.dimensions.width), Int(videoFormat.dimensions.height), kCVPixelFormatType_32BGRA, cvBufferProperties as CFDictionary, &pixelBuffer)
        guard let cvPixelBuffer = pixelBuffer, result == kCVReturnSuccess else { fatalError() }
        self.cvPixelBuffer = cvPixelBuffer
        
        var textureCache: CVOpenGLESTextureCache?
        result = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, nil, self.context, nil, &textureCache)
        guard let cvTextureCache = textureCache, result == kCVReturnSuccess else { fatalError() }
        self.cvTextureCache = cvTextureCache
        
        let surface: IOSurface = CVPixelBufferGetIOSurface(cvPixelBuffer)!.takeUnretainedValue()
        surface.isYAxisFlipped = true
        self.surface = surface
    }
    
    deinit
    {
        if self.texture > 0
        {
            glDeleteTextures(1, &self.texture)
        }
        
        if self.framebuffer > 0
        {
            glDeleteFramebuffers(1, &self.framebuffer)
        }
    }
}

extension OpenGLESProcessor
{
    var videoBuffer: UnsafeMutablePointer<UInt8>? {
        return nil
    }
    
    func prepare()
    {
        EAGLContext.setCurrent(self.context)
        
        // Framebuffer
        if self.framebuffer == 0
        {
            glGenFramebuffers(1, &self.framebuffer)
            glBindFramebuffer(GLenum(GL_FRAMEBUFFER), self.framebuffer)
        }
        
        // Texture
        if self.texture == 0
        {
            let glInternalFormat = GL_RGBA
            let glFormat = GL_BGRA_EXT
            let glType = GL_UNSIGNED_INT_8_8_8_8_REV
            
            let result = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                      self.cvTextureCache,
                                                                      self.cvPixelBuffer,
                                                                      nil,
                                                                      GLenum(GL_TEXTURE_2D),
                                                                      glInternalFormat,
                                                                      GLsizei(self.videoFormat.dimensions.width),
                                                                      GLsizei(self.videoFormat.dimensions.height),
                                                                      GLenum(glFormat),
                                                                      GLenum(glType),
                                                                      0,
                                                                      &self.cvOpenGLESTexture)
            guard let cvOpenGLESTexture = self.cvOpenGLESTexture, result == kCVReturnSuccess else { return }
            self.texture = CVOpenGLESTextureGetName(cvOpenGLESTexture)
            
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLint(GL_CLAMP_TO_EDGE))
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLint(GL_CLAMP_TO_EDGE))
            glFramebufferTexture2D(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_TEXTURE_2D), self.texture, 0)
        }
    }
    
    func processFrame()
    {
        glFlush()
        
        // IOSurface is now updated to match texture.
    }
}
