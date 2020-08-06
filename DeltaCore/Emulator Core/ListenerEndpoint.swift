//
//  ListenerEndpoint.swift
//  DeltaCore
//
//  Created by Riley Testut on 7/31/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import Foundation

private var allEndpoints = [UUID: NSXPCListenerEndpoint]()
private var allSurfaces = [UUID: IOSurface]()

@objc public protocol RemoteProcessProtocol: NSObjectProtocol
{
    func testMyFunction()
    
    func startProcess()
    func stopProcess()
    
    func getEmulatorBridge(completion: @escaping (EmulatorBridging) -> Void)
}

@_silgen_name("IOSurfaceCreateXPCObject")
func RSTIOSurfaceCreateXPCObject(_ aSurface: IOSurfaceRef) -> AnyObject

@_silgen_name("IOSurfaceLookupFromXPCObject")
func RSTIOSurfaceLookupFromXPCObject(_ xobj: AnyObject) -> IOSurfaceRef?

//extension NSXPCCoder
//{
//    @_silgen_name("IOSurfaceLookupFromXPCObject")
//    open func rst_encodeXPCObject(_ xpcObject: xpc_object_t, forKey key: String)
////
////
////    // This validates the type of the decoded object matches the type passed in. If they do not match, an exception is thrown (just like the rest of Secure Coding behaves). Note: This can return NULL, but calling an xpc function with NULL will crash. So make sure to do the right thing if you get back a NULL result.
////    @available(iOS 7.0, macCatalyst 13.0, *)
////    open func decodeXPCObject(ofType type: xpc_type_t, forKey key: String) -> xpc_object_t?
//}

@objc(ListenerEndpoint) @objcMembers
public class ListenerEndpoint: NSObject, NSSecureCoding
{
    let identifier: UUID
    public let endpoint: NSXPCListenerEndpoint
    let surface: IOSurface?
    
    public static var supportsSecureCoding: Bool {
        return true
    }
    
    public init(endpoint: NSXPCListenerEndpoint, surface: IOSurface)
    {
        self.endpoint = endpoint
        self.surface = surface
        
        self.identifier = UUID()
        
        super.init()
    }
    
    public required init?(coder: NSCoder)
    {
        guard let identifier = coder.decodeObject(forKey: "identifier") as? UUID else { return nil }
        self.identifier = identifier
        
        if let coder = coder as? NSXPCCoder
        {
            guard let endpoint = coder.decodeObject(forKey: "endpoint") as? NSXPCListenerEndpoint else { return nil }
//            guard let surfaceObject = coder.decodeObject(forKey: "surface") as? AnyObject else { return nil }
            
//            let surface = RSTIOSurfaceLookupFromXPCObject(surfaceObject)!
//
            self.endpoint = endpoint
            self.surface = nil
//            self.surface = unsafeBitCast(surface, to: IOSurface.self)
            
            allEndpoints[identifier] = endpoint
//            allSurfaces[identifier] = unsafeBitCast(surface, to: IOSurface.self)
        }
        else
        {
            guard let endpoint = allEndpoints[identifier] else { return nil }
//            guard let surface = allSurfaces[identifier] else { return nil }
            
            self.endpoint = endpoint
//            self.surface = surface
            self.surface = nil
            
            allEndpoints[identifier] = nil
            allSurfaces[identifier] = nil
        }
                
        super.init()
    }
    
    public func encode(with coder: NSCoder)
    {
        coder.encode(self.identifier, forKey: "identifier")
        
        if let coder = coder as? NSXPCCoder
        {
//            let object = RSTIOSurfaceCreateXPCObject(unsafeBitCast(self.surface, to: IOSurfaceRef.self))
//            coder.encode(object, forKey: "surface")
//            let object = RSTIOSurfaceLookupFromXPCObject(unsafeBitCast(self.surface, to: IOSurfaceRef.self))
//            coder.rst_encodeXPCObject(object, forKey: "surface")
            
//            coder.encode(self.surface, forKey: "surface")
            coder.encode(self.endpoint, forKey: "endpoint")
            
        }
        else
        {
            allEndpoints[self.identifier] = endpoint
            allSurfaces[self.identifier] = surface
        }
    }
}
