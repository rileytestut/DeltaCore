//
//  EmulatorCore.swift
//  DeltaCore
//
//  Created by Riley Testut on 3/11/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import AVFoundation
import Roxas

public extension EmulatorCore
{
    @objc enum State: Int
    {
        case stopped
        case running
        case paused
    }
    
    enum CheatError: Error
    {
        case invalid
    }
    
    enum SaveStateError: Error
    {
        case doesNotExist
    }
}

public final class EmulatorCore: NSObject
{
    //MARK: - Properties -
    /** Properties **/
    public let game: GameProtocol
    public fileprivate(set) var gameViews: [GameView] = []
    public var gameControllers: [GameController] {
        return Array(self.gameControllersDictionary.values)
    }
    
    public var updateHandler: ((EmulatorCore) -> Void)?
    
    public fileprivate(set) lazy var audioManager: AudioManager = AudioManager(audioFormat: self.deltaCore.audioFormat, frameDuration: self.deltaCore.frameDuration)
    public fileprivate(set) lazy var videoManager: VideoManager = VideoManager(videoFormat: self.deltaCore.videoFormat)
    
    // KVO-Compliant
    public fileprivate(set) dynamic var state = State.stopped
    public dynamic var rate = 1.0 {
        didSet {
            self.audioManager.rate = self.rate
        }
    }
    
    public let deltaCore: DeltaCoreProtocol
    public var preferredRenderingSize: CGSize { return self.deltaCore.videoFormat.dimensions }
    
    //MARK: - Private Properties
    
    // We privately set this first to clean up before setting self.state, which notifies KVO observers
    fileprivate var _state = State.stopped
    
    fileprivate let gameType: GameType
    
    fileprivate let emulationSemaphore = DispatchSemaphore(value: 0)
    fileprivate var gameControllersDictionary = [Int: GameController]()
    fileprivate var cheatCodes = [String: CheatType]()
    
    fileprivate var previousState = State.stopped
    fileprivate var previousRate: Double? = nil
    
    fileprivate var gameSaveURL: URL {
        let gameURL = self.game.fileURL.deletingPathExtension()
        let gameSaveURL = gameURL.appendingPathExtension(self.deltaCore.gameSaveFileExtension)
        return gameSaveURL
    }
    
    //MARK: - Initializers -
    /** Initializers **/
    public required init?(game: GameProtocol)
    {
        // These MUST be set in start(), because it's possible the same emulator core might be stopped, another one started, and then resumed back to this one
        // AKA, these need to always be set at start to ensure it points to the correct managers
        // self.configuration.bridge.audioRenderer = self.audioManager
        // self.configuration.bridge.videoRenderer = self.videoManager
        
        guard let deltaCore = Delta.core(for: game.type) else {
            print(game.type.rawValue + " is not a supported game type.")
            return nil
        }
        
        self.deltaCore = deltaCore
        
        self.game = game
        
        // Stored separately in case self.game is an NSManagedObject subclass, and we need to access .type on a different thread than its NSManagedObjectContext
        self.gameType = self.game.type
        
        super.init()
    }
}

//MARK: - Emulation -
/// Emulation
public extension EmulatorCore
{
    @discardableResult func start() -> Bool
    {
        guard self._state == .stopped else { return false }
        
        self._state = .running
        defer { self.state = self._state }
        
        self.audioManager.start()
        
        self.deltaCore.emulatorBridge.audioRenderer = self.audioManager
        self.deltaCore.emulatorBridge.videoRenderer = self.videoManager
        self.deltaCore.emulatorBridge.saveUpdateHandler = { [unowned self] in
            self.deltaCore.emulatorBridge.saveGameSave(to: self.gameSaveURL)
        }
        
        self.deltaCore.emulatorBridge.start(withGameURL: self.game.fileURL)
        self.deltaCore.emulatorBridge.loadGameSave(from: self.gameSaveURL)
        
        self.runGameLoop()
        
        self.emulationSemaphore.wait()
        
        return true
    }
    
    @discardableResult func stop() -> Bool
    {
        guard self._state != .stopped else { return false }
        
        let isRunning = self.state == .running
        
        self._state = .stopped
        defer { self.state = self._state }
        
        if isRunning
        {
            self.emulationSemaphore.wait()
        }
        
        self.deltaCore.emulatorBridge.saveGameSave(to: self.gameSaveURL)
        
        self.audioManager.stop()
        self.deltaCore.emulatorBridge.stop()
        
        return true
    }
    
    @discardableResult func pause() -> Bool
    {
        guard self._state == .running else { return false }
        
        self._state = .paused
        defer { self.state = self._state }
        
        self.emulationSemaphore.wait()
        
        self.deltaCore.emulatorBridge.saveGameSave(to: self.gameSaveURL)
        
        self.audioManager.isEnabled = false
        self.deltaCore.emulatorBridge.pause()
        
        return true
    }
    
    @discardableResult func resume() -> Bool
    {
        guard self._state == .paused else { return false }
        
        self._state = .running
        defer { self.state = self._state }
        
        self.audioManager.isEnabled = true
        self.deltaCore.emulatorBridge.resume()
        
        self.runGameLoop()
        
        self.emulationSemaphore.wait()
        
        return true
    }
}

//MARK: - Game Views -
/// Game Views
public extension EmulatorCore
{
    public func add(_ gameView: GameView)
    {
        self.gameViews.append(gameView)
        
        self.videoManager.add(gameView)
    }
    
    public func remove(_ gameView: GameView)
    {
        if let index = self.gameViews.index(of: gameView)
        {
            self.gameViews.remove(at: index)
        }
        
        self.videoManager.remove(gameView)
    }
}

//MARK: - Save States -
/// Save States
public extension EmulatorCore
{
    @discardableResult func saveSaveState(to url: URL) -> SaveStateProtocol
    {
        self.deltaCore.emulatorBridge.saveSaveState(to: url)
        
        let saveState = SaveState(fileURL: url, gameType: self.gameType)
        return saveState
    }
    
    func load(_ saveState: SaveStateProtocol) throws
    {
        guard FileManager.default.fileExists(atPath: saveState.fileURL.path) else { throw SaveStateError.doesNotExist }
        
        self.deltaCore.emulatorBridge.loadSaveState(from: saveState.fileURL)
        
        self.updateCheats()
        self.deltaCore.emulatorBridge.resetInputs()
    }
}

//MARK: - Cheats -
/// Cheats
public extension EmulatorCore
{
    func activate(_ cheat: CheatProtocol) throws
    {
        var success = true
        
        let codes = cheat.code.characters.split(separator: "\n")
        for code in codes
        {
            if !self.deltaCore.emulatorBridge.addCheatCode(String(code), type: cheat.type)
            {
                success = false
                break
            }
        }
        
        if success
        {
            self.cheatCodes[cheat.code] = cheat.type
        }
        
        // Ensures correct state, especially if attempted cheat was invalid
        self.updateCheats()
        
        if !success
        {
            throw CheatError.invalid
        }
    }
    
    func deactivate(_ cheat: CheatProtocol)
    {
        guard self.cheatCodes[cheat.code] != nil else { return }
        
        self.cheatCodes[cheat.code] = nil
        
        self.updateCheats()
    }
    
    fileprivate func updateCheats()
    {
        self.deltaCore.emulatorBridge.resetCheats()
        
        for (cheatCode, type) in self.cheatCodes
        {
            let codes = cheatCode.characters.split(separator: "\n")
            for code in codes
            {
                self.deltaCore.emulatorBridge.addCheatCode(String(code), type: type)
            }
        }
        
        self.deltaCore.emulatorBridge.updateCheats()
    }
}

//MARK: - Controllers -
/// Controllers
public extension EmulatorCore
{
    @discardableResult func setGameController(_ gameController: GameController?, at index: Int) -> GameController?
    {
        let previousGameController = self.gameController(at: index)
        previousGameController?.playerIndex = nil
        
        gameController?.playerIndex = index
        gameController?.addReceiver(self)
        self.gameControllersDictionary[index] = gameController
        
        if let gameController = gameController as? MFiGameController
        {
            gameController.inputTransformationHandler = { [unowned gameController] (input) in
                return self.deltaCore.inputTransformer.inputs(for: gameController, input: input as! MFiGameController.Input)
            }
        }
        
        return previousGameController
    }
    
    func removeAllGameControllers()
    {
        for controller in self.gameControllers
        {
            if let index = controller.playerIndex
            {
                self.setGameController(nil, at: index)
            }
        }
    }
    
    func gameController(at index: Int) -> GameController?
    {
        return self.gameControllersDictionary[index]
    }
}

extension EmulatorCore: GameControllerReceiver
{
    public func gameController(_ gameController: GameController, didActivate input: Input)
    {
        guard type(of: input) == self.deltaCore.inputTransformer.gameInputType else { return }
        
        self.deltaCore.emulatorBridge.activateInput(input.identifier)
    }
    
    public func gameController(_ gameController: GameController, didDeactivate input: Input)
    {
        guard type(of: input) == self.deltaCore.inputTransformer.gameInputType else { return }
        
        self.deltaCore.emulatorBridge.deactivateInput(input.identifier)
    }
}

private extension EmulatorCore
{
    func runGameLoop()
    {
        let emulationQueue = DispatchQueue(label: "com.rileytestut.DeltaCore.emulationQueue", qos: .userInitiated)
        emulationQueue.async {
            
            let screenRefreshRate = 1.0 / 60.0
            
            var emulationTime = Thread.absoluteSystemTime
            var counter = 0.0
            
            while true
            {
                let frameDuration = self.deltaCore.frameDuration / self.rate
                
                if self.rate != self.previousRate
                {
                    Thread.setRealTimePriority(withPeriod: frameDuration)
                    
                    self.previousRate = self.rate
                    
                    // Reset counter
                    counter = 0
                }
                
                if counter >= screenRefreshRate
                {
                    self.runFrame(renderGraphics: true)
                    
                    // Reset counter
                    counter = 0
                }
                else
                {
                    // No need to render graphics more than once per screen refresh rate
                    self.runFrame(renderGraphics: false)
                }
                
                counter += frameDuration
                emulationTime += frameDuration
                
                let currentTime = Thread.absoluteSystemTime
                
                // The number of frames we need to skip to keep in sync
                let framesToSkip = Int((currentTime - emulationTime) / frameDuration)
                
                if framesToSkip > 0
                {
                    // Only actually skip frames if we're running at normal speed
                    if self.rate == 1.0
                    {
                        for _ in 0 ..< framesToSkip
                        {
                            // "Skip" frames by running them without rendering graphics
                            self.runFrame(renderGraphics: false)
                        }
                    }
                    
                    emulationTime = currentTime
                }
                
                // Prevent race conditions
                let state = self._state
                
                if self.previousState != state
                {
                    self.emulationSemaphore.signal()
                    
                    self.previousState = state
                }
                
                if state != .running
                {
                    break
                }
                
                Thread.realTimeWait(until: emulationTime)
            }
            
        }
    }
    
    func runFrame(renderGraphics: Bool)
    {
        self.deltaCore.emulatorBridge.runFrame()
        
        if renderGraphics
        {
            self.videoManager.didUpdateVideoBuffer()
        }
        
        self.updateHandler?(self)
    }
}
