//
//  EmulatorCore.swift
//  DeltaCore
//
//  Created by Riley Testut on 3/11/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import AVFoundation

public extension EmulatorCore
{
    @objc enum State: Int
    {
        case stopped
        case running
        case paused
    }
    
    enum CheatError: ErrorProtocol
    {
        case invalid
    }
    
    enum SaveStateError: ErrorProtocol
    {
        case doesNotExist
    }
}

public final class EmulatorCore
{
    //MARK: - Properties -
    /** Properties **/
    public let game: GameProtocol
    public private(set) var gameViews: [GameView] = []
    public var gameControllers: [GameControllerProtocol] {
        return Array(self.gameControllersDictionary.values)
    }
    
    public var updateHandler: ((EmulatorCore) -> Void)?
    
    public private(set) lazy var audioManager: AudioManager = AudioManager(bufferInfo: self.configuration.audioBufferInfo)
    public private(set) lazy var videoManager: VideoManager = VideoManager(bufferInfo: self.configuration.videoBufferInfo)
    
    // KVO-Compliant
    public private(set) dynamic var state = State.stopped
    public dynamic var rate = 1.0
    {
        didSet
        {
            if !self.supportedRates.contains(self.rate)
            {
                self.rate = min(max(self.rate, self.supportedRates.lowerBound), self.supportedRates.upperBound)
            }
            
            self.audioManager.rate = self.rate
        }
    }
    
    /// Configuration
    public var supportedRates: ClosedRange<Double> { return self.configuration.supportedRates }
    public var supportedCheatFormats: [CheatFormat] { return self.configuration.supportedCheatFormats }
    
    public var preferredRenderingSize: CGSize { return self.configuration.videoBufferInfo.outputDimensions }
    
    //MARK: - Private Properties
    private let configuration: EmulatorCoreConfiguration
    
    private let emulationSemaphore = DispatchSemaphore(value: 0)
    private var gameControllersDictionary = [Int: GameControllerProtocol]()
    private var cheatCodes = [String: CheatType]()
    
    private var previousState = State.stopped
    private var previousRate: Double? = nil
    
    //MARK: - Initializers -
    /** Initializers **/
    public required init(game: GameProtocol)
    {
        self.game = game
        self.configuration = EmulatorCoreConfiguration(gameType: game.type)
        self.rate = self.supportedRates.lowerBound
    }
}

//MARK: - Emulation -
/// Emulation
public extension EmulatorCore
{
    @discardableResult func start() -> Bool
    {
        guard self.state == .stopped else { return false }
        
        self.state = .running
        self.audioManager.start()
        
        self.configuration.bridge.audioRenderer = self.audioManager
        self.configuration.bridge.videoRenderer = self.videoManager
        self.configuration.bridge.saveUpdateHandler = { [unowned self] in
            self.configuration.bridge.saveGameSave(to: self.configuration.gameSaveURL)
        }
        
        self.configuration.bridge.start(withGameURL: self.game.fileURL)
        self.configuration.bridge.loadGameSave(from: self.configuration.gameSaveURL)
        
        self.runGameLoop()
        
        self.emulationSemaphore.wait()
        
        return true
    }
    
    @discardableResult func stop() -> Bool
    {
        guard self.state != .stopped else { return false }
        
        let isRunning = self.state == .running
        
        self.state = .stopped
        
        if isRunning
        {
            self.emulationSemaphore.wait()
        }
        
        self.configuration.bridge.saveGameSave(to: self.configuration.gameSaveURL)
        
        self.audioManager.stop()
        self.configuration.bridge.stop()
        
        return true
    }
    
    @discardableResult func pause() -> Bool
    {
        guard self.state == .running else { return false }
        
        self.state = .paused
        
        self.emulationSemaphore.wait()
        
        self.configuration.bridge.saveGameSave(to: self.configuration.gameSaveURL)
        
        self.audioManager.enabled = false
        self.configuration.bridge.pause()
        
        return true
    }
    
    @discardableResult func resume() -> Bool
    {
        guard self.state == .paused else { return false }
        
        self.state = .running
        
        self.runGameLoop()
        
        self.emulationSemaphore.wait()
        
        self.audioManager.enabled = true
        self.configuration.bridge.resume()
        
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
    func save(withCompletion completion: ((SaveStateProtocol) -> Void))
    {
        FileManager.default().prepareTemporaryURL { URL in
            
            self.configuration.bridge.saveSaveState(to: URL)
            
            let saveState = SaveState(fileURL: URL, gameType: self.game.type)
            completion(saveState)
        }
    }
    
    func load(_ saveState: SaveStateProtocol) throws
    {
        guard let path = saveState.fileURL.path where FileManager.default().fileExists(atPath: path) else { throw SaveStateError.doesNotExist }
        
        self.configuration.bridge.loadSaveState(from: saveState.fileURL)
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
            if !self.configuration.bridge.addCheatCode(String(code), type: cheat.type.rawValue)
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
    
    private func updateCheats()
    {
        self.configuration.bridge.resetCheats()
        
        for (cheatCode, type) in self.cheatCodes
        {
            let codes = cheatCode.characters.split(separator: "\n")
            for code in codes
            {
                self.configuration.bridge.addCheatCode(String(code), type: type.rawValue)
            }
        }
        
        self.configuration.bridge.updateCheats()
    }
}

//MARK: - Controllers -
/// Controllers
public extension EmulatorCore
{
    @discardableResult func setGameController(_ gameController: GameControllerProtocol?, at index: Int) -> GameControllerProtocol?
    {
        let previousGameController = self.gameController(at: index)
        previousGameController?.playerIndex = nil
        
        gameController?.playerIndex = index
        gameController?.addReceiver(self)
        self.gameControllersDictionary[index] = gameController
        
        if let gameController = gameController as? MFiExternalController where gameController.inputTransformationHandler == nil
        {
            gameController.inputTransformationHandler = { (gameController, input) in
                return self.configuration.inputs(for: gameController as! MFiExternalController, input: input)
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
    
    func gameController(at index: Int) -> GameControllerProtocol?
    {
        return self.gameControllersDictionary[index]
    }
}

extension EmulatorCore: GameControllerReceiverProtocol
{
    public func gameController(_ gameController: GameControllerProtocol, didActivate input: InputProtocol)
    {
        guard input.dynamicType == self.configuration.gameInputType else { return }
        
        self.configuration.bridge.activateInput(input.rawValue)
    }
    
    public func gameController(_ gameController: GameControllerProtocol, didDeactivate input: InputProtocol)
    {
        guard input.dynamicType == self.configuration.gameInputType else { return }
        
        self.configuration.bridge.deactivateInput(input.rawValue)
    }
}

private extension EmulatorCore
{
    func runGameLoop()
    {
        let emulationQueue = DispatchQueue(label: "com.rileytestut.DeltaCore.emulationQueue", attributes: [.serial, .qosUserInitiated])
        emulationQueue.async {
            
            let screenRefreshRate = 1.0 / 60.0
            
            var emulationTime = Thread.absoluteTime
            var counter = 0.0
            
            while true
            {
                let frameDuration = 1.0 / (self.rate * 60.0)
                
                if self.rate != self.previousRate
                {
                    Thread.setRealTimePriorityWithPeriod(frameDuration)
                    
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
                
                let currentTime = Thread.absoluteTime
                
                // The number of frames we need to skip to keep in sync
                let framesToSkip = Int((currentTime - emulationTime) / frameDuration)
                
                if framesToSkip > 0
                {
                    // Only actually skip frames if we're running at normal speed
                    if self.rate == self.supportedRates.lowerBound
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
                let state = self.state
                
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
        self.configuration.bridge.runFrame()
        
        if renderGraphics
        {
            self.videoManager.didUpdateVideoBuffer()
        }
        
        self.updateHandler?(self)
    }
}
