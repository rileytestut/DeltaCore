//
//  JSCoreAdapter.swift
//  DeltaCore
//
//  Created by Riley Testut on 12/8/21.
//  Copyright © 2022 Riley Testut. All rights reserved.
//

import Foundation
import WebKit

extension JSCoreAdapter
{
    private enum MessageType: String
    {
        case ready
        case audio
        case video
        case save
    }
}

public class JSCoreAdapter: NSObject, EmulatorBridging
{
    public private(set) var scriptURL: URL
    
    public private(set) var gameURL: URL?
    
    //TODO: Figure out another way to retrieve main window...
    public weak var emulatorCore: EmulatorCore?
    
    public var audioRenderer: AudioRendering?
    public var videoRenderer: VideoRendering?
    
    public var saveUpdateHandler: (() -> Void)?
    
    public private(set) var frameDuration: TimeInterval = 0.0
    
    private let prefix: String
    
    private var webView: WKWebView!
    private var initialNavigation: WKNavigation?
    
    private var isReady: Bool = false
    private let readySemaphore = DispatchSemaphore(value: 0)
    private let frameSemaphore = DispatchSemaphore(value: 1)
    
    public init(prefix: String, fileURL: URL)
    {
        self.prefix = prefix
        self.scriptURL = fileURL
        
        super.init()
        
        DispatchQueue.main.async {
            let configuration = WKWebViewConfiguration()
            configuration.userContentController.add(self, name: "DLTAEmulatorBridge")
            
            self.webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 100, height: 100), configuration: configuration)
            self.webView.navigationDelegate = self
        }
    }
}

public extension JSCoreAdapter
{
    func start(withGameURL gameURL: URL)
    {
        do
        {
            if !self.isReady
            {
                DispatchQueue.main.sync {
                    if let window = self.emulatorCore?.gameViews.first?.window, self.initialNavigation == nil
                    {
                        window.addSubview(self.webView)
                        
                        let directoryURL = self.scriptURL.deletingLastPathComponent()
                        self.initialNavigation = self.webView.loadFileURL(self.scriptURL, allowingReadAccessTo: directoryURL)
                        
    //                    self.initialNavigation = self.webView.load(URLRequest(url: URL(string: "http://192.168.86.30:8080/vbam.html")!))
                        
    //                    self.initialNavigation = self.webView.loadHTMLString("<!doctype html></html>", baseURL: nil)
                    }
                }
                
                self.readySemaphore.wait()
            }
            
            let path = gameURL.lastPathComponent
            try self.importFile(at: gameURL, to: path)
            
            let script = "Module.ccall('\(self.prefix)StartEmulation', null, ['string'], ['\(path)'])"
            let result = try self.webView.evaluateJavaScriptSynchronously(script) as! Bool
            
            print("Start game result:", result)
            
            guard result else {
                print("Error launching game at", gameURL)
                return
            }
            
            self.gameURL = gameURL
            
            // Cache frame duration so we don't need to evaluate each frame.
            let frameDuration = try self.webView.evaluateJavaScriptSynchronously("_\(self.prefix)FrameDuration()") as! TimeInterval
            self.frameDuration = frameDuration
        }
        catch
        {
            print("[JSCoreAdapter] Error starting game:", error)
        }
    }
    
    func pause()
    {
        do
        {
            try self.webView.evaluateJavaScriptSynchronously("_\(self.prefix)PauseEmulation()")
        }
        catch
        {
            print("[JSCoreAdapter] Error pausing game:", error)
        }
    }
    
    func resume()
    {
        do
        {
            try self.webView.evaluateJavaScriptSynchronously("_\(self.prefix)ResumeEmulation()")
        }
        catch
        {
            print("[JSCoreAdapter] Error resuming game:", error)
        }
    }
    
    func stop()
    {
        do
        {
            try self.webView.evaluateJavaScriptSynchronously("_\(self.prefix)StopEmulation()")
        }
        catch
        {
            print("[JSCoreAdapter] Error stopping game:", error)
        }
    }
    
    func runFrame(processVideo: Bool)
    {
//        self.frameSemaphore.wait()
        
        do
        {
            try self.webView.evaluateJavaScriptSynchronously("_\(self.prefix)RunFrame(\(processVideo))")
        }
        catch
        {
            print("[JSCoreAdapter] Error running frame:", error)
        }
                
//        DispatchQueue.main.async {
//
//            self.webView.evaluateJavaScript("_\(self.prefix)RunFrame(\(processVideo))") { (result, error) in
//                if let error = error
//                {
//                    print("Error running frame:", error)
//                }
//
//                self.frameSemaphore.signal()
//            }
//        }
    }
    
    func activateInput(_ input: Int, value: Double)
    {
        do
        {
            try self.webView.evaluateJavaScriptSynchronously("_\(self.prefix)ActivateInput(\(input))")
        }
        catch
        {
            print("Error activating input: \(input).", error)
        }
    }
    
    func deactivateInput(_ input: Int)
    {
        do
        {
            try self.webView.evaluateJavaScriptSynchronously("_\(self.prefix)DeactivateInput(\(input))")
        }
        catch
        {
            print("Error deactivating input: \(input).", error)
        }
    }
    
    func resetInputs()
    {
    }
    
    func saveSaveState(to fileURL: URL)
    {
        do
        {
            let script = "Module.ccall('\(self.prefix)SaveSaveState', null, ['string'], ['\(fileURL.lastPathComponent)'])"
            try self.webView.evaluateJavaScriptSynchronously(script)
            
            try self.exportFile(at: fileURL.lastPathComponent, to: fileURL)
        }
        catch
        {
            print("Error saving save state:", error)
        }
    }
    
    func loadSaveState(from fileURL: URL)
    {
        do
        {
            try self.importFile(at: fileURL, to: fileURL.lastPathComponent)

            let script = "Module.ccall('\(self.prefix)LoadSaveState', null, ['string'], ['\(fileURL.lastPathComponent)'])"
            try self.webView.evaluateJavaScriptSynchronously(script)
        }
        catch
        {
            print("Error loading save state:", error)
        }
    }
    
    func saveGameSave(to fileURL: URL)
    {
        do
        {
            let script = "Module.ccall('\(self.prefix)SaveGameSave', null, ['string'], ['\(fileURL.lastPathComponent)'])"
            try self.webView.evaluateJavaScriptSynchronously(script)

            try self.exportFile(at: fileURL.lastPathComponent, to: fileURL)
        }
        catch
        {
            print("Error saving game save:", error)
        }
    }
    
    func loadGameSave(from fileURL: URL)
    {
//        do
//        {
//            try self.importFile(at: fileURL, to: fileURL.lastPathComponent)
//
//            let script = "Module.ccall('\(self.prefix)LoadGameSave', null, ['string'], ['\(fileURL.lastPathComponent)'])"
//            try self.webView.evaluateJavaScriptSynchronously(script)
//        }
//        catch
//        {
//            print("Error loading game save:", error)
//        }
    }
    
    func addCheatCode(_ cheatCode: String, type: String) -> Bool
    {
        do
        {
            let script = "Module.ccall('\(self.prefix)AddCheatCode', null, ['string'], ['\(cheatCode)'])"
            try self.webView.evaluateJavaScriptSynchronously(script)
            
            return true
        }
        catch
        {
            print("Error adding cheat code: \(cheatCode).", error)
            
            return false
        }
    }
    
    func resetCheats()
    {
        do
        {
            try self.webView.evaluateJavaScriptSynchronously("_\(self.prefix)ResetCheats()")
        }
        catch
        {
            print("Error resetting cheats:", error)
        }
    }
    
    func updateCheats()
    {
    }
}

private extension JSCoreAdapter
{
    func importFile(at fileURL: URL, to path: String) throws
    {
        let data = try Data(contentsOf: fileURL)
        let bytes = data.map { $0 }
        
        let script = """
        var data = Uint8Array.from(\(bytes));
        FS.writeFile('\(path)', data);
        """
        
        try self.webView.evaluateJavaScriptSynchronously(script)
    }
    
    func exportFile(at path: String, to fileURL: URL) throws
    {
        let script = """
        var bytes = FS.readFile('\(path)');
        Array.from(bytes);
        """
        
        let bytes = try self.webView.evaluateJavaScriptSynchronously(script) as! [UInt8]
        
        let data = Data(bytes)
        try data.write(to: fileURL)
    }
}

extension JSCoreAdapter: WKNavigationDelegate
{
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!)
    {
        guard navigation == self.initialNavigation else { return }
        
//        let scriptURL = self.scriptURL
//
//        do
//        {
//            let scriptData = try Data(contentsOf: scriptURL)
//            let script = String(data: scriptData, encoding: .utf8)!
//
//            self.webView.evaluateJavaScript(script) { (result, error) in
//                if let error = error
//                {
//                    print(error)
//                }
//            }
//        }
//        catch
//        {
//            print(error)
//        }
        
        self.initialNavigation = nil
    }
}

extension JSCoreAdapter: WKScriptMessageHandler
{
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage)
    {
        guard let payload = message.body as? [String: Any],
              let rawMessageType = payload["type"] as? String,
              let messageType = MessageType(rawValue: rawMessageType)
        else { return }
        
        switch messageType
        {
        case .ready:
            self.isReady = true
            self.readySemaphore.signal()
            
        case .audio:
            guard let bytes = payload["data"] as? [UInt8] else { return }
            self.audioRenderer?.audioBuffer.write(bytes, size: bytes.count)
            
//            guard let string = payload["data"] as? String else { return }
//
//            let array = Array(string.utf16)
//            array.withUnsafeBytes { (pointer) in
//                let bytes = pointer.bindMemory(to: UInt8.self)
//                self.audioRenderer?.audioBuffer.write(bytes.baseAddress!, size: bytes.count)
//            }
           

        case .video:
//            guard let allBytes = payload["data"] as? [String] else { return }
//            let bytes = allBytes.joined()
//            _ = memcpy(self.videoRenderer?.videoBuffer, bytes, bytes.count * 2)
//            self.videoRenderer?.processFrame()
            
            guard let string = payload["data"] as? String else { return }

            let array = Array(string.utf16)
            array.withUnsafeBytes { (pointer) in
                let bytes = pointer.bindMemory(to: UInt8.self)
                _ = memcpy(self.videoRenderer?.videoBuffer, bytes.baseAddress!, bytes.count)
                self.videoRenderer?.processFrame()
            }
            
        case .save: self.saveUpdateHandler?()
        }
    }
}
