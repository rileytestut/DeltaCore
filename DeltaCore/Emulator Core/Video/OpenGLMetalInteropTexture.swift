//
//  Dummy.swift
//  DeltaCoreOpenGL
//
//  Created by Riley Testut on 7/2/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import Metal
//import AppKit
import OpenGLES
//import GLKit
import CoreVideo
//import OpenGL

private let GL_BGRA_EXT: GLuint = 0x80E1

struct AAPLTextureFormatInfo
{
    var cvPixelFormat: Int
    var mtlFormat: MTLPixelFormat
    var glInternalFormat: GLuint
    var glFormat: GLuint
    var glType: GLuint
}
//
//public class RSTOpenGLESTextureCache: NSObject
//{
//
//}
//
//@_silgen_name("CVOpenGLESTextureCacheCreate")
//public func RSTCVOpenGLESTextureCacheCreate(_ allocator: CFAllocator?, _ cacheAttributes: CFDictionary?, _ eaglContext: EAGLContext, _ textureAttributes: CFDictionary?, _ cacheOut: UnsafeMutablePointer<RSTOpenGLESTextureCache?>) -> CVReturn

class OpenGLMetalInteropTexture
{
    let metalDevice: MTLDevice
    let openGLContext: EAGLContext
    let metalPixelFormat: MTLPixelFormat
    let size: CGSize
    
    let openGLTexture: GLuint
    let metalTexture: MTLTexture
    
    private let formatInfo: AAPLTextureFormatInfo
    var pixelBuffer: CVPixelBuffer?
    
    private var cvOpenGLTextureCache: CVOpenGLTextureCache?
    private var cvOpenGLTexture: CVOpenGLTexture?
//
    private var cvMetalTextureCache: CVMetalTextureCache?
    private var cvMetalTexture: CVMetalTexture?
    
    init(metalDevice: MTLDevice, openGLContext: EAGLContext, metalPixelFormat: MTLPixelFormat, size: CGSize)
    {
        self.metalDevice = metalDevice
        self.openGLContext = openGLContext
        self.metalPixelFormat = metalPixelFormat
        self.size = size
                
        self.formatInfo = AAPLTextureFormatInfo(cvPixelFormat: Int(kCVPixelFormatType_32BGRA), mtlFormat: .bgra8Unorm, glInternalFormat: GLuint(GL_RGBA), glFormat: GL_BGRA_EXT, glType: GLuint(0 /*GL_UNSIGNED_INT_8_8_8_8_REV*/))
        
        let ioSurface = IOSurface(properties: <#T##[IOSurfacePropertyKey : Any]#>)
        
        let options = [kCVPixelBufferOpenGLCompatibilityKey: true, kCVPixelBufferMetalCompatibilityKey: true]
        var result = CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height),
                                         OSType(self.formatInfo.cvPixelFormat), options as CFDictionary, &self.pixelBuffer)
        
//        var result =
        
        // OpenGL texture
        openGLContext.texImageIOSurface(<#T##ioSurface: IOSurfaceRef##IOSurfaceRef#>, target: <#T##Int#>, internalFormat: <#T##Int#>, width: <#T##UInt32#>, height: <#T##UInt32#>, format: <#T##Int#>, type: <#T##Int#>, plane: <#T##UInt32#>)
        
        result = openGLContext.texImageIOSurface(<#T##ioSurface: IOSurfaceRef##IOSurfaceRef#>, target: <#T##Int#>, internalFormat: <#T##Int#>, width: <#T##UInt32#>, height: <#T##UInt32#>, format: <#T##Int#>, type: <#T##Int#>, plane: <#T##UInt32#>)
        
//        CVOpenGLESTextureCacheCreateTextureFromImage
        
//        result = RSTCVOpenGLESTextureCacheCreate(kCFAllocatorDefault, nil, openGLContext, nil, &self.cvOpenGLTextureCache)
//        result = CVOpenGLES
        result = CVOpenGLTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.cvOpenGLTextureCache!, self.pixelBuffer!, nil, &self.cvOpenGLTexture)
//        result = CVOpenGLESTextureCacheCreate
//        self.openGLTexture = CVOpenGLTextureGetName(self.cvOpenGLTexture!)
//
//        result = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, self.metalDevice, nil, &self.cvMetalTextureCache)
//        result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.cvMetalTextureCache!, self.pixelBuffer!, nil, self.formatInfo.mtlFormat, Int(size.width), Int(size.height), 0, &self.cvMetalTexture)
//        self.metalTexture = CVMetalTextureGetTexture(self.cvMetalTexture!)!
    }
}
