//
//  NativeCoreAdapter.swift
//  DeltaCore
//
//  Created by Riley Testut on 1/3/22.
//  Copyright © 2022 Riley Testut. All rights reserved.
//

import Foundation

private var _audioRenderer: AudioRendering?
private var _videoRenderer: VideoRendering?
private var _saveUpdateHandler: (() -> Void)?

private var DLTAAudioCallback: @convention(c) (UnsafePointer<UInt8>, Int32) -> Void = { (bytes, count) in
    _audioRenderer?.audioBuffer.write(bytes, size: Int(count))
}

private var DLTAVideoCallback: @convention(c) (UnsafePointer<UInt8>, Int32) -> Void = { (bytes, count) in
    guard let videoRenderer = _videoRenderer else { return }
    
    memcpy(videoRenderer.videoBuffer, bytes, Int(count))
    videoRenderer.processFrame()
}

private var DLTASaveCallback: @convention(c) () -> Void = {
    _saveUpdateHandler?()
}

public class NativeCoreAdapter: NSObject, EmulatorBridging
{
    public var gameURL: URL?
    
    public var audioRenderer: AudioRendering? {
        get { _audioRenderer }
        set { _audioRenderer = newValue }
    }
    public var videoRenderer: VideoRendering? {
        get { _videoRenderer }
        set { _videoRenderer = newValue }
    }
    public var saveUpdateHandler: (() -> Void)? {
        get { _saveUpdateHandler }
        set { _saveUpdateHandler = newValue }
    }
    
    public var frameDuration: Double { _frameDuration() }
    
    private var _frameDuration: @convention(c) () -> Double
    private var _start: @convention(c) (UnsafePointer<CChar>) -> Bool
    private var _stop: @convention(c) () -> Void
    private var _pause: @convention(c) () -> Void
    private var _resume: @convention(c) () -> Void
    private var _runFrame: @convention(c) (Bool) -> Void
    private var _activateInput: @convention(c) (Int32, Double) -> Void
    private var _deactivateInput: @convention(c) (Int32) -> Void
    private var _resetInputs: @convention(c) () -> Void
    private var _saveSaveState: @convention(c) (UnsafePointer<CChar>) -> Void
    private var _loadSaveState: @convention(c) (UnsafePointer<CChar>) -> Void
    private var _saveGameSave: @convention(c) (UnsafePointer<CChar>) -> Void
    private var _loadGameSave: @convention(c) (UnsafePointer<CChar>) -> Void
    private var _addCheatCode: @convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>) -> Bool
    private var _resetCheats: @convention(c) () -> Void
    private var _updateCheats: @convention(c) () -> Void
    
    public init(
        frameDuration: @escaping (@convention(c) () -> Double),
        start: @escaping (@convention(c) (UnsafePointer<CChar>) -> Bool),
        stop: @escaping (@convention(c) () -> Void),
        pause: @escaping (@convention(c) () -> Void),
        resume: @escaping (@convention(c) () -> Void),
        runFrame: @escaping (@convention(c) (Bool) -> Void),
        activateInput: @escaping (@convention(c) (Int32, Double) -> Void),
        deactivateInput: @escaping (@convention(c) (Int32) -> Void),
        resetInputs: @escaping (@convention(c) () -> Void),
        saveSaveState: @escaping (@convention(c) (UnsafePointer<CChar>) -> Void),
        loadSaveState: @escaping (@convention(c) (UnsafePointer<CChar>) -> Void),
        saveGameSave: @escaping (@convention(c) (UnsafePointer<CChar>) -> Void),
        loadGameSave: @escaping (@convention(c) (UnsafePointer<CChar>) -> Void),
        addCheatCode: @escaping (@convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>) -> Bool),
        resetCheats: @escaping (@convention(c) () -> Void),
        updateCheats: @escaping (@convention(c) () -> Void),
        setAudioCallback: @escaping (@convention(c) ((@convention(c) (UnsafePointer<UInt8>, Int32) -> Void)?) -> Void),
        setVideoCallback: @escaping (@convention(c) ((@convention(c) (UnsafePointer<UInt8>, Int32) -> Void)?) -> Void),
        setSaveCallback: @escaping (@convention(c) ((@convention(c) () -> Void)?) -> Void)
    )
    {
        self._frameDuration = frameDuration
        self._start = start
        self._stop = stop
        self._pause = pause
        self._resume = resume
        self._runFrame = runFrame
        self._activateInput = activateInput
        self._deactivateInput = deactivateInput
        self._resetInputs = resetInputs
        self._saveSaveState = saveSaveState
        self._loadSaveState = loadSaveState
        self._saveGameSave = saveGameSave
        self._loadGameSave = loadGameSave
        self._addCheatCode = addCheatCode
        self._resetCheats = resetCheats
        self._updateCheats = updateCheats
                
        setAudioCallback(DLTAAudioCallback)
        setVideoCallback(DLTAVideoCallback)
        setSaveCallback(DLTASaveCallback)
    }
    
    public func start(withGameURL gameURL: URL) { _ = _start(gameURL.path) }
    public func stop() { _stop() }
    public func pause() { _pause() }
    public func resume() { _resume() }
    
    public func runFrame(processVideo: Bool) { _runFrame(processVideo) }
    
    public func activateInput(_ input: Int, value: Double) { _activateInput(Int32(input), value) }
    public func deactivateInput(_ input: Int) { _deactivateInput(Int32(input)) }
    public func resetInputs() { _resetInputs() }
    
    public func saveSaveState(to url: URL) { url.withUnsafeFileSystemRepresentation { _saveSaveState($0!) } }
    public func loadSaveState(from url: URL) { url.withUnsafeFileSystemRepresentation { _loadSaveState($0!) } }
    
    public func saveGameSave(to url: URL) { url.withUnsafeFileSystemRepresentation { _saveGameSave($0!) } }
    public func loadGameSave(from url: URL) { url.withUnsafeFileSystemRepresentation { _loadGameSave($0!) } }
    
    public func addCheatCode(_ cheatCode: String, type: String) -> Bool { _addCheatCode(cheatCode, type) }
    public func resetCheats() { _resetCheats() }
    public func updateCheats() { _updateCheats() }
}
