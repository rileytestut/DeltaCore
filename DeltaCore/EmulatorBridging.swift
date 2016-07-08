//
//  EmulatorBridging.swift
//  DeltaCore
//
//  Created by Riley Testut on 6/29/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation

@objc(DLTAEmulatorBridging)
public protocol EmulatorBridging: NSObjectProtocol
{
    /// State
    var gameURL: URL? { get }
    
    /// Audio
    var audioRenderer: AudioRendering? { get set }
    
    /// Video
    var videoRenderer: VideoRendering? { get set }
    
    /// Saves
    var saveUpdateHandler: ((Void) -> Void)? { get set }
    
    
    /// Emulation State
    func start(withGameURL gameURL: URL)
    func stop()
    func pause()
    func resume()
    
    /// Game Loop
    func runFrame()
    
    /// Inputs
    func activateInput(_ input: Int)
    func deactivateInput(_ input: Int)
    
    /// Save States
    @objc(saveSaveStateToURL:) func saveSaveState(to: URL)
    @objc(loadSaveStateFromURL:) func loadSaveState(from: URL)
    
    /// Game Games
    @objc(saveGameSaveToURL:) func saveGameSave(to: URL)
    @objc(loadGameSaveFromURL:) func loadGameSave(from: URL)
    
    /// Cheats
    @discardableResult func addCheatCode(_ cheatCode: String, type: String) -> Bool
    func resetCheats()
    func updateCheats()
}
