//
//  EmulatorProcess.swift
//  DeltaMac
//
//  Created by Riley Testut on 7/8/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import Foundation
import Combine
import CoreServices
import IOSurface

let CFMessagePortHandler: CFMessagePortCallBack = { (port, msgid, data, info) in
    return nil
}

@objc(RSTXPCSurface) @objcMembers
public class XPCSurface: NSObject, NSSecureCoding
{
    public let name: String
    public let surface: IOSurface
        
    public init(surface: IOSurface)
    {
        self.surface = surface
        self.name = "Riley Testut"
    }
    
    public static var supportsSecureCoding: Bool {
        return true
    }
    
    public required init?(coder: NSCoder)
    {
        guard let name = coder.decodeObject(of: [NSString.self], forKey: "name") as? NSString else { return nil }
        self.name = name as String
        
        if let coder = coder as? NSXPCCoder
        {
//            let constant = coder.decodeInt64(forKey: "constant")
//            let xpcType = UnsafeMutableRawPointer(bitPattern: Int(constant))
            
//            #if !targetEnvironment(macCatalyst)
//            guard let surfaceObject = coder.decodeXPCObject(ofType: xpcType, forKey: "surface") else { return nil }
////            guard let surfaceObject = coder.decodeObject(forKey: "name") else { return nil }
//            guard let surface = IOSurfaceLookupFromXPCObject(surfaceObject) else {
//                return nil
//            }
//            #else
//            guard let surfaceObject = coder.decodeXPCObject(ofType: unsafeBitCast(xpcType, to: xpc_type_t.self), forKey: "surface") else { return nil }
////            guard let surfaceObject = coder.decodeObject(forKey: "name") else { return nil }
//            guard let surface = IOSurfaceLookupFromXPCObject(surfaceObject) else {
//                return nil
//            }
//            #endif
            
//            guard let dictionary = coder.decodeXPCObject(ofType: RSTXPCDictionaryType(), forKey: "surface") else {
//                return nil
//            }
            
//            let port_value = xpc_dictionary_get_value(dictionary, "port");
//            let machPort = xpc_mach_send_get_right(port_value);
//
//            guard let surface = IOSurfaceLookupFromMachPort(machPort) else {
//                return nil
//            }
//
//            self.surface = unsafeBitCast(surface, to: IOSurface.self)
//            self.surface = surface.takeUnretainedValue()
            
            self.surface = IOSurface()
        }
        else
        {
            self.surface = IOSurface()
        }
    }
    
    public func encode(with coder: NSCoder)
    {
        coder.encode(self.name as NSString, forKey: "name")
        
        if let coder = coder as? NSXPCCoder
        {
//            let surface = IOSurfaceCreateXPCObject(unsafeBitCast(self.surface, to: IOSurfaceRef.self))
            let machPort = IOSurfaceCreateMachPort(unsafeBitCast(self.surface, to: IOSurfaceRef.self))
            
            let portName = "group.com.rileytestut.Delta.Testut"
            
            var bootstrapPort: mach_port_t = 0
            #if !targetEnvironment(macCatalyst)
            task_get_special_port(mach_task_self(), TASK_BOOTSTRAP_PORT, &bootstrapPort)
            #else
            task_get_special_port(mach_task_self_, TASK_BOOTSTRAP_PORT, &bootstrapPort)
            #endif
    //
            
//            let machPort = IOSurfaceCreateMachPort(unsafeBitCast(self.videoManager.surface, to: IOSurfaceRef.self))
            
            var cName = (portName as NSString).utf8String
            let result = bootstrap_register(bootstrapPort, UnsafeMutablePointer(mutating: cName), machPort)
            
            var receivePort: mach_port_t = 0
            let result2 = bootstrap_look_up(bootstrapPort, cName, &receivePort)
            
//            #if !targetEnvironment(macCatalyst)
//            let myType = xpc_get_type(surface)!
//            #else
//            let myType = xpc_get_type(surface)
            
            let dictionary = xpc_dictionary_create(nil, nil, 0)
            //                xpc_dictionary_set_uint64(dictionary, "type", 7);
            //                xpc_dictionary_set_uint64(dictionary, "handle", 0);
            xpc_dictionary_set_string(dictionary, "name", "delta")
            //                xpc_dictionary_set_int64(dictionary, "targetpid", 0);
            //                xpc_dictionary_set_uint64(dictionary, "flags", 0);
            //                xpc_dictionary_set_uint64(dictionary, "subsystem", 5);
            //                xpc_dictionary_set_uint64(dictionary, "routine", 207);
            // Add a NULL port so that the slot in the dictionary is already
            // allocated.
            xpc_dictionary_set_mach_send(dictionary, "port", machPort);
            
            coder.encodeXPCObject(dictionary, forKey: "surface")
            
//            #endif
//            print(myType)
            
//            let address = Int(bitPattern: myType)
//            coder.encode(address, forKey: "constant")
//
////            coder.encode(surface, forKey: "surface")
//            coder.encodeXPCObject(surface, forKey: "surface")
        }
        else
        {
            print("Not XPC coder...")
        }
    }
}

@available(iOS 13, *)
extension EmulatorProcess
{
    public enum Status
    {
        case stopped
        case running(EmulatorBridging)
        case paused
    }
    
    public enum ProcessError: Swift.Error
    {
        case crashed
        case noConnection
        case xpcServiceNotFound
    }
}

@available(iOS 13, *)
public class EmulatorProcess: NSObject, ObservableObject
{
    public let gameType: GameType
    public let surface: IOSurface
    
    public var status: Status { self.statusSubject.value }
    public var statusPublisher: AnyPublisher<Status, Error> { self.statusSubject.eraseToAnyPublisher() }
    private let statusSubject = CurrentValueSubject<Status, Error>(.stopped)
    
    private let listener = NSXPCListener.anonymous()
    private var remoteExtension: NSExtension?
    private var xpcConnection: NSXPCConnection?
    private var remoteExtensionUUID: UUID?
    
    var remoteObject: RemoteProcessProtocol?
    private var machPort: NSMachPort?
    
    init(gameType: GameType, surface: IOSurface)
    {
        self.gameType = gameType
        self.surface = surface
        
        super.init()
        
        self.listener.delegate = self
    }
    
    deinit
    {
        self.stop()
    }
    
    func stop()
    {
//        if let uuid = self.remoteExtensionUUID
//        {
//            self.remoteExtension?.cancelRequest(withIdentifier: uuid)
//        }
//
        self.remoteObject?.stopProcess()
    }
    
    func start()
    {
        let extensionURL = Bundle.main.builtInPlugInsURL!.appendingPathComponent("DeltaXPC.appex")
        
        NSExtension.extension(with: extensionURL) { (remoteExtension, error) in
            if let remoteExtension = remoteExtension
            {
                remoteExtension.setRequestCancellationBlock { (uuid, error) in
                    print("Operation \(uuid) cancelled:", error)
                }
                remoteExtension.setRequestInterruptionBlock { (uuid) in
                    print("Operation \(uuid) interrupted :(")
                    self.statusSubject.send(completion: .failure(ProcessError.crashed))
                }
                
                remoteExtension.setRequestCompletionBlock { (uuid, extensionItems) in
                    self.statusSubject.send(completion: .finished)
//                    guard let item = extensionItems.first as? NSExtensionItem else { return }
//                    guard let itemProvider = item.attachments?.first else { return }
//
//                    itemProvider.loadItem(forTypeIdentifier: kUTTypePropertyList as String, options: nil) { (response, error) in
//                        print("Response:", response)
//                    }
                }
                
                self.startXPC(to: remoteExtension)
            }
            else if let error = error
            {
                print("Error connecting to extension:", error)
                self.statusSubject.send(completion: .failure(error))
            }
        }
    }
    
    func startXPC(to remoteExtension: NSExtension)
    {
        self.startServer()
        
        self.listener.resume()
        
        let parameters = ["type": "start-game",
                          "gameType": self.gameType,
                          "endpoint": ListenerEndpoint(endpoint: self.listener.endpoint, surface: surface)] as NSDictionary
        
        let itemProvider = NSItemProvider(item: parameters, typeIdentifier: kUTTypePropertyList as String)
        
        let extensionItem = NSExtensionItem()
        extensionItem.attachments = [itemProvider]
        
        remoteExtension.beginRequest(withInputItems: [extensionItem], completion: { (uuid) in
            self.remoteExtensionUUID = uuid
//
//
//
//
//            guard let xpcConnection = remoteExtension._extensionServiceConnections[uuid] as? NSXPCConnection else {
//                return self.statusSubject.send(completion: .failure(ProcessError.noConnection))
//            }
//
//            let completionSelectorString = "_completeRequestReturningItems:forExtensionContextWithUUID:completion:"
//            let completionSelector = Selector(completionSelectorString)
//
//            let existingClasses = xpcConnection.exportedInterface?.classes(for: completionSelector, argumentIndex: 0, ofReply: false) as NSSet? ?? NSSet()
//            let updatedClasses = NSSet(array: existingClasses.allObjects + [XPCContainer.self])
//            xpcConnection.exportedInterface?.setClasses(updatedClasses as! Set<AnyHashable>, for: completionSelector, argumentIndex: 0, ofReply: false)
            
            let pid = remoteExtension.pid(forRequestIdentifier: uuid)
            print("Started operation:", uuid, pid)
        })
        
        self.remoteExtension = remoteExtension
    }
    
//    func connect()
//    {
////        self.emulatorBridge = self.xpcConnection.remoteObjectProxyWithErrorHandler { (error) in
////            print("XPC Connection Failure:", error)
////        } as? EmulatorBridging
////
////        print("Bridge:", self.emulatorBridge)
//        
//        if self.remoteExtension == nil
//        {
//            self.listener.delegate = self
//            self.listener.resume()
//            
//            let extensionURL = Bundle.main.builtInPlugInsURL!.appendingPathComponent("DeltaXPC.appex")
//            NSExtension.extension(with: extensionURL) { (remoteExtension, error) in
//                if let remoteExtension = remoteExtension
//                {
//                    remoteExtension.setRequestCancellationBlock { (uuid, error) in
//                        print("Operation \(uuid) cancelled:", error)
//                    }
//                    remoteExtension.setRequestInterruptionBlock { (uuid) in
//                        print("Operation \(uuid) interrupted :(")
//                    }
//                    remoteExtension.setRequestCompletionBlock { (uuid, extensionItems) in
//                        guard let item = extensionItems.first as? NSExtensionItem else { return }
//                        guard let itemProvider = item.attachments?.first else { return }
//                        
//                        print("Completed operation \(uuid) with items:", extensionItems)
//                        
//                        itemProvider.loadItem(forTypeIdentifier: kUTTypePropertyList as String, options: nil) { (response, error) in
//                            print("Response:", response)
//                        }
//                    }
//                    
//                    self.remoteExtension = remoteExtension
//                    self.connect()
//                }
//                else
//                {
//                    print("Error connecting to extension:", error)
//                }
//            }
//            
//            return
//        }
//        
//        let itemProvider = NSItemProvider(item: ["value": "input string",
//                                                 "endpoint": MyItemProvider(name: "Riley Testut", endpoint: self.listener.endpoint)] as NSDictionary,
//                                          typeIdentifier: kUTTypePropertyList as String)
//        
//        let extensionItem = NSExtensionItem()
//        extensionItem.attachments = [itemProvider]
//        
//        self.remoteExtension?.beginRequest(withInputItems: [extensionItem], completion: { (uuid) in
//            if let xpcConnection = self.remoteExtension?._extensionServiceConnections[uuid] as? NSXPCConnection
//            {
//                let completionSelectorString = "_completeRequestReturningItems:forExtensionContextWithUUID:completion:"
//                let completionSelector = Selector(completionSelectorString)
//                
//                let existingClasses = xpcConnection.exportedInterface?.classes(for: completionSelector, argumentIndex: 0, ofReply: false) as NSSet? ?? NSSet()
//                let updatedClasses = NSSet(array: existingClasses.allObjects) as! Set<AnyHashable>
//                
//                xpcConnection.exportedInterface?.setClasses(updatedClasses, for: completionSelector, argumentIndex: 0, ofReply: false)
//            }
//            
//            print("Started operation:", uuid, self.remoteExtension?.pid(forRequestIdentifier: uuid))
//        })
//    }
    
    func startServer()
    {
        
    }
}

@available(iOS 13, *)
extension EmulatorProcess: NSXPCListenerDelegate, RemoteProcessProtocol
{
    public func testMyFunction()
    {
        print("Hello My Function!")
        return;
        
        DispatchQueue.main.async {
            let portName = "group.com.rileytestut.Delta.Testut"
            
            //        guard let port = CFMessagePortCreateRemote(kCFAllocatorDefault, portName as CFString) else {
            //            return
            //        }
            
            var bootstrapPort: mach_port_t = 0
            #if !targetEnvironment(macCatalyst)
            task_get_special_port(mach_task_self(), TASK_BOOTSTRAP_PORT, &bootstrapPort)
            #else
            task_get_special_port(mach_task_self_, TASK_BOOTSTRAP_PORT, &bootstrapPort)
            #endif
            //            task_get_bootstrap_port(mach_task_self(), &bootstrapPort)
            
            var cName = (portName as NSString).utf8String
            
            var receivePort: mach_port_t = 0
            let result = bootstrap_look_up(bootstrapPort, cName, &receivePort)
            
            let nsMachPort = NSMachPort(machPort: receivePort)
            self.machPort = nsMachPort
            print(nsMachPort)
            
            let surfacePort = IOSurfaceCreateMachPort(unsafeBitCast(self.surface, to: IOSurfaceRef.self))
            let sendResult = RSTSendPort(receivePort, surfacePort)
            print(sendResult)
            
//            let data = "Hello Riley".data(using: .utf8)!
//            //
////            let message = NSPortMessage(send: nsMachPort, receive: nil, components: nil)
////            message.msgid = 616
////
//            let timeout = Date.init(timeIntervalSinceNow: 5)
////            if !message.send(before: timeout)
//            if !nsMachPort.send(before: timeout, msgid: 626, components: nil, from: nil, reserved: 0)
//            {
//                print("Failed")
//            }
//            else
//            {
//                print("Succeeded!")
//            }
        }
        
//        message.send(before: Date())
    }
    
    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool
    {
        guard self.xpcConnection == nil else { return false }
        
        let emulatorBridgeInterface = NSXPCInterface(with: EmulatorBridgingPrivate.self)
        emulatorBridgeInterface.setInterface(NSXPCInterface(with: AudioRendering.self), for: #selector(setter: EmulatorBridging.audioRenderer), argumentIndex: 0, ofReply: false)
        emulatorBridgeInterface.setInterface(NSXPCInterface(with: VideoRendering.self), for: #selector(setter: EmulatorBridging.videoRenderer), argumentIndex: 0, ofReply: false)
        
        let remoteInterface = NSXPCInterface(with: RemoteProcessProtocol.self)
        remoteInterface.setInterface(emulatorBridgeInterface, for: #selector(RemoteProcessProtocol.getEmulatorBridge(completion:)), argumentIndex: 0, ofReply: true)
        newConnection.remoteObjectInterface = remoteInterface
        
        newConnection.exportedInterface = NSXPCInterface(with: RemoteProcessProtocol.self)
        newConnection.exportedObject = self
        
        newConnection.resume()
        
        self.xpcConnection = newConnection
        
        guard let remoteObject = newConnection.remoteObjectProxyWithErrorHandler({ (error) in
            self.statusSubject.send(completion: .failure(error))
        }) as? RemoteProcessProtocol else { return false }
        
        remoteObject.getEmulatorBridge { (emulatorBridge) in
            self.statusSubject.send(.running(emulatorBridge))
        }
        
        self.remoteObject = remoteObject
                
        return true
    }
    
    @objc
    public func startProcess()
    {
        print("Received test signal!")
    }
    
    @objc
    public func stopProcess()
    {
        
    }
    
    public func getEmulatorBridge(completion: @escaping (EmulatorBridging) -> Void)
    {
    }
}

//@available(iOS 13, *)
//extension EmulatorProcess: PortDelegate
//{
//    public func handle(_ message: NSPortMessage)
//    {
//    }
//}
