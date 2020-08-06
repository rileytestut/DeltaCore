//
//  EmulatorBridging.swift
//  DeltaCore
//
//  Created by Riley Testut on 6/29/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation
import Metal

@available(iOS 13.0, *)
@objc(DLTAEmulatorBridgingPrivate)
public protocol EmulatorBridgingPrivate: EmulatorBridging
{
    var textureHandle: MTLSharedTextureHandle? { get set }
}

@objc(DLTAEmulatorBridging)
public protocol EmulatorBridging: NSObjectProtocol
{
    /// State
    var gameURL: URL? { get }
    
    /// System
    var frameDuration: TimeInterval { get }
    
    /// Audio
    var audioRenderer: AudioRendering? { get set }
    
    /// Video
    var surface: IOSurface? { get set }
    var surfaceID: IOSurfaceID { get set }
    var xpcSurface: XPCSurface? { get set }
    var port: UInt32 { get set }
    var videoRenderer: VideoRendering? { get set }
    
    /// Saves
    var saveUpdateHandler: (() -> Void)? { get set }
    
    
    /// Emulation State
    func start(withGameURL gameURL: URL)
    func stop()
    func pause()
    func resume()
    
    /// Game Loop
    @objc(runFrameAndProcessVideo:) func runFrame(processVideo: Bool)
    
    /// Inputs
    func activateInput(_ input: Int, value: Double)
    func deactivateInput(_ input: Int)
    func resetInputs()
    
    /// Save States
    @objc(saveSaveStateToURL:) func saveSaveState(to url: URL)
    @objc(loadSaveStateFromURL:) func loadSaveState(from url: URL)
    
    /// Game Games
    @objc(saveGameSaveToURL:) func saveGameSave(to url: URL)
    @objc(loadGameSaveFromURL:) func loadGameSave(from url: URL)
    
    /// Cheats
    @discardableResult func addCheatCode(_ cheatCode: String, type: String) -> Bool
    func resetCheats()
    func updateCheats()
}
