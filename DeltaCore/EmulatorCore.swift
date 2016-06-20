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

public class EmulatorCore: DynamicObject
{
    //MARK: - Properties -
    /** Properties **/
    public let game: GameProtocol
    public private(set) var gameViews: [GameView] = []
    public var gameControllers: [GameControllerProtocol] {
        get
        {
            return Array(self.gameControllersDictionary.values)
        }
    }
    
    public var updateHandler: ((EmulatorCore) -> Void)?
    
    public private(set) lazy var audioManager: AudioManager = AudioManager(bufferInfo: self.audioBufferInfo)
    public private(set) lazy var videoManager: VideoManager = VideoManager(bufferInfo: self.videoBufferInfo)
    
    /// Used for converting timestamps to human-readable strings (such as for names of Save States)
    /// Can be customized to provide different default formatting
    public var timestampDateFormatter: DateFormatter
    
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
    
    /** Subclass Properties **/
    
    public var bridge: DLTAEmulatorBridge {
        fatalError("To be implemented by subclasses.")
    }
    
    public var gameInputType: InputProtocol.Type {
        fatalError("To be implemented by subclasses.")
    }
    
    public var gameSaveURL: URL {
        fatalError("To be implemented by subclasses.")
    }
    
    public var audioBufferInfo: AudioManager.BufferInfo {
        fatalError("To be implemented by subclasses.")
    }
    
    public var videoBufferInfo: VideoManager.BufferInfo {
        fatalError("To be implemented by subclasses.")
    }
    
    public var preferredRenderingSize: CGSize {
        return self.videoBufferInfo.outputDimensions
    }
    
    public var supportedCheatFormats: [CheatFormat] {
        fatalError("To be implemented by subclasses.")
    }
    
    public var supportedRates: ClosedRange<Double> {
        return 1...4
    }
    
    //MARK: - Private Properties
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
        
        self.timestampDateFormatter = DateFormatter()
        self.timestampDateFormatter.timeStyle = .shortStyle
        self.timestampDateFormatter.dateStyle = .longStyle
        
        super.init(dynamicIdentifier: game.typeIdentifier.rawValue, initSelector: #selector(EmulatorCore.init(game:)), initParameters: [game])
        
        self.rate = self.supportedRates.lowerBound
    }
    
    /** Subclass Methods **/
    /** Contained within main class declaration because of a Swift limitation where non-ObjC compatible extension methods cannot be overridden **/

    
    //MARK: - Input Transformation -
    /// Input Transformation
    public func inputsForMFiExternalController(_ controller: GameControllerProtocol, input: InputProtocol) -> [InputProtocol]
    {
        return []
    }
    
    //MARK: - Game Views -
    /// Game Views
    public func addGameView(_ gameView: GameView)
    {
        self.gameViews.append(gameView)
        
        self.videoManager.addGameView(gameView)
    }
    
    public func removeGameView(_ gameView: GameView)
    {
        if let index = self.gameViews.index(of: gameView)
        {
            self.gameViews.remove(at: index)
        }
        
        self.videoManager.removeGameView(gameView)
    }
}

//MARK: - Emulation -
/// Emulation
public extension EmulatorCore
{
    func startEmulation() -> Bool
    {
        guard self.state == .stopped else { return false }
        
        self.state = .running
        self.audioManager.start()
        
        self.bridge.emulatorCore = self
        self.bridge.audioRenderer = self.audioManager
        self.bridge.videoRenderer = self.videoManager
        
        self.bridge.start(withGameURL: self.game.fileURL)
        self.bridge.loadGameSave(from: self.gameSaveURL)
        
        self.runGameLoop()
        
        self.emulationSemaphore.wait()
        
        return true
    }
    
    func stopEmulation() -> Bool
    {
        guard self.state != .stopped else { return false }
        
        let isRunning = self.state == .running
        
        self.state = .stopped
        
        if isRunning
        {
            self.emulationSemaphore.wait()
        }
        
        self.bridge.saveGameSave(to: self.gameSaveURL)
        
        self.audioManager.stop()
        self.bridge.stop()
        
        return true
    }
    
    func pauseEmulation() -> Bool
    {
        guard self.state == .running else { return false }
        
        self.state = .paused
        
        self.emulationSemaphore.wait()
        
        self.bridge.saveGameSave(to: self.gameSaveURL)
        
        self.audioManager.enabled = false
        self.bridge.pause()
        
        return true
    }
    
    func resumeEmulation() -> Bool
    {
        guard self.state == .paused else { return false }
        
        self.state = .running
        
        self.runGameLoop()
        
        self.emulationSemaphore.wait()
        
        self.audioManager.enabled = true
        self.bridge.resume()
        
        return true
    }
}

//MARK: - Save States -
/// Save States
public extension EmulatorCore
{
    func saveSaveState(_ completion: ((SaveStateProtocol) -> Void))
    {
        FileManager.default().prepareTemporaryURL { URL in
            
            self.bridge.saveSaveState(to: URL)
            
            let name = self.timestampDateFormatter.string(from: Date())
            let saveState = SaveState(name: name, fileURL: URL)
            completion(saveState)
        }
    }
    
    func loadSaveState(_ saveState: SaveStateProtocol) throws
    {
        guard let path = saveState.fileURL.path where FileManager.default().fileExists(atPath: path) else { throw SaveStateError.doesNotExist }
        
        self.bridge.loadSaveState(from: saveState.fileURL as URL)
    }
}

//MARK: - Cheats -
/// Cheats
public extension EmulatorCore
{
    func activateCheat(cheat: CheatProtocol) throws
    {
        var success = true
        
        let codes = cheat.code.characters.split(separator: "\n")
        for code in codes
        {
            if !self.bridge.addCheatCode(String(code), type: cheat.type.rawValue)
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
    
    func deactivateCheat(cheat: CheatProtocol)
    {
        guard self.cheatCodes[cheat.code] != nil else { return }
        
        self.cheatCodes[cheat.code] = nil
        
        self.updateCheats()
    }
    
    private func updateCheats()
    {
        self.bridge.resetCheats()
        
        for (cheatCode, type) in self.cheatCodes
        {
            let codes = cheatCode.characters.split(separator: "\n")
            for code in codes
            {
                self.bridge.addCheatCode(String(code), type: type.rawValue)
            }
        }
        
        self.bridge.updateCheats()
    }
}

//MARK: - Controllers -
/// Controllers
public extension EmulatorCore
{
    @discardableResult func setGameController(_ gameController: GameControllerProtocol?, atIndex index: Int) -> GameControllerProtocol?
    {
        let previousGameController = self.gameControllerAtIndex(index)
        previousGameController?.playerIndex = nil
        
        gameController?.playerIndex = index
        gameController?.addReceiver(self)
        self.gameControllersDictionary[index] = gameController
        
        if let gameController = gameController as? MFiExternalController where gameController.inputTransformationHandler == nil
        {
            gameController.inputTransformationHandler = inputsForMFiExternalController
        }
        
        return previousGameController
    }
    
    func removeAllGameControllers()
    {
        for controller in self.gameControllers
        {
            if let index = controller.playerIndex
            {
                self.setGameController(nil, atIndex: index)
            }
        }
    }
    
    func gameControllerAtIndex(_ index: Int) -> GameControllerProtocol?
    {
        return self.gameControllersDictionary[index]
    }
}

extension EmulatorCore: GameControllerReceiverProtocol
{
    public func gameController(_ gameController: GameControllerProtocol, didActivate input: InputProtocol)
    {
        guard input.dynamicType == self.gameInputType else { return }
        
        self.bridge.activateInput(input.rawValue)
    }
    
    public func gameController(_ gameController: GameControllerProtocol, didDeactivate input: InputProtocol)
    {
        guard input.dynamicType == self.gameInputType else { return }
        
        self.bridge.deactivateInput(input.rawValue)
    }
}

extension EmulatorCore: DLTAEmulating
{
    public func didUpdateGameSave()
    {
        self.bridge.saveGameSave(to: self.gameSaveURL)
    }
}

private extension EmulatorCore
{
    func runGameLoop()
    {
        let emulationQueue = DispatchQueue(label: "com.rileytestut.DeltaCore.emulationQueue", attributes: DispatchQueueAttributes.serial)
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
        self.bridge.runFrame()
        
        if renderGraphics
        {
            self.videoManager.didUpdateVideoBuffer()
        }
        
        self.updateHandler?(self)
    }
}

