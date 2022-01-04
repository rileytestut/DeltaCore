//
//  AdaptableEmulatorBridge.swift
//  DeltaCore
//
//  Created by Riley Testut on 1/3/22.
//  Copyright © 2022 Riley Testut. All rights reserved.
//

import Foundation

@objc(DLTAAdaptableEmulatorBridge)
open class AdaptableDeltaBridge: NSObject, EmulatorBridging
{
    open var adapter: EmulatorBridging { fatalError() }
    private lazy var _adapter: EmulatorBridging = self.adapter
    
    //TODO: Figure out another way to retrieve app window...
    public var emulatorCore: EmulatorCore?
    
    public private(set) var gameURL: URL?
    
    public var audioRenderer: AudioRendering?
    public var videoRenderer: VideoRendering?
    public var saveUpdateHandler: (() -> Void)?
        
    public var frameDuration: TimeInterval { self._adapter.frameDuration }
    
    open func start(withGameURL gameURL: URL)
    {
        self._adapter.audioRenderer = self.audioRenderer
        self._adapter.videoRenderer = self.videoRenderer
        self._adapter.saveUpdateHandler = self.saveUpdateHandler
        
        self._adapter.start(withGameURL: gameURL)
        
        self.gameURL = gameURL
    }
    
    open func stop() { self._adapter.stop() }
    open func pause() { self._adapter.pause() }
    open func resume() { self._adapter.resume() }
    
    open func runFrame(processVideo: Bool) { self._adapter.runFrame(processVideo: processVideo) }
    
    open func activateInput(_ input: Int, value: Double) { self._adapter.activateInput(input, value: value) }
    open func deactivateInput(_ input: Int) { self._adapter.deactivateInput(input) }
    open func resetInputs() { self._adapter.resetInputs() }
    
    open func saveSaveState(to url: URL) { self._adapter.saveSaveState(to: url) }
    open func loadSaveState(from url: URL) { self._adapter.loadSaveState(from: url) }
    
    open func saveGameSave(to url: URL) { self._adapter.saveGameSave(to: url) }
    open func loadGameSave(from url: URL) { self._adapter.loadGameSave(from: url) }
        
    open func addCheatCode(_ cheatCode: String, type: String) -> Bool { self._adapter.addCheatCode(cheatCode, type: type) }
    open func resetCheats() { self._adapter.resetCheats() }
    open func updateCheats() { self._adapter.updateCheats() }
}
