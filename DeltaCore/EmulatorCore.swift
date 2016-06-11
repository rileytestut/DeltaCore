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
        case Stopped
        case Running
        case Paused
    }
    
    enum CheatError: ErrorType
    {
        case invalid
    }
    
    enum SaveStateError: ErrorType
    {
        case doesNotExist
    }
}

public class EmulatorCore: DynamicObject
{
    //MARK: - Properties -
    /** Properties **/
    public let game: GameType
    public private(set) var gameViews: [GameView] = []
    public var gameControllers: [GameControllerProtocol] {
        get
        {
            return Array(self.gameControllersDictionary.values)
        }
    }
    
    public var updateHandler: (EmulatorCore -> Void)?
    
    public private(set) lazy var audioManager: AudioManager = AudioManager(bufferInfo: self.audioBufferInfo)
    public private(set) lazy var videoManager: VideoManager = VideoManager(bufferInfo: self.videoBufferInfo)
    
    /// Used for converting timestamps to human-readable strings (such as for names of Save States)
    /// Can be customized to provide different default formatting
    public var timestampDateFormatter: NSDateFormatter
    
    // KVO-Compliant
    public private(set) dynamic var state = State.Stopped
    public dynamic var rate = 1.0
    {
        didSet
        {
            if !self.supportedRates.contains(self.rate)
            {
                self.rate = min(max(self.rate, self.supportedRates.start), self.supportedRates.end)
            }
            
            self.audioManager.rate = self.rate
        }
    }
    
    /** Subclass Properties **/
    
    public var bridge: DLTAEmulatorBridge {
        fatalError("To be implemented by subclasses.")
    }
    
    public var gameInputType: InputType.Type {
        fatalError("To be implemented by subclasses.")
    }
    
    public var gameSaveURL: NSURL {
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
    
    public var supportedRates: ClosedInterval<Double> {
        return 1...4
    }
    
    //MARK: - Private Properties
    private let emulationSemaphore = dispatch_semaphore_create(0)
    private var gameControllersDictionary = [Int: GameControllerProtocol]()
    private var cheatCodes = [String: CheatType]()
    
    private var previousState = State.Stopped
    private var previousRate: Double? = nil
    
    //MARK: - Initializers -
    /** Initializers **/
    public required init(game: GameType)
    {
        self.game = game
        
        self.timestampDateFormatter = NSDateFormatter()
        self.timestampDateFormatter.timeStyle = .ShortStyle
        self.timestampDateFormatter.dateStyle = .LongStyle
        
        super.init(dynamicIdentifier: game.typeIdentifier, initSelector: #selector(EmulatorCore.init(game:)), initParameters: [game])
        
        self.rate = self.supportedRates.start
    }
    
    /** Subclass Methods **/
    /** Contained within main class declaration because of a Swift limitation where non-ObjC compatible extension methods cannot be overridden **/

    //MARK: - Input Transformation -
    /// Input Transformation
    public func inputsForMFiExternalController(controller: GameControllerProtocol, input: InputType) -> [InputType]
    {
        return []
    }
    
    //MARK: - Game Views -
    /// Game Views
    public func addGameView(gameView: GameView)
    {
        self.gameViews.append(gameView)
        
        self.videoManager.addGameView(gameView)
    }
    
    public func removeGameView(gameView: GameView)
    {
        if let index = self.gameViews.indexOf(gameView)
        {
            self.gameViews.removeAtIndex(index)
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
        guard self.state == .Stopped else { return false }
        
        self.state = .Running
        self.audioManager.start()
        
        self.bridge.emulatorCore = self
        self.bridge.audioRenderer = self.audioManager
        self.bridge.videoRenderer = self.videoManager
        
        self.bridge.startWithGameURL(self.game.fileURL)
        self.bridge.loadGameSaveFromURL(self.gameSaveURL)
        
        self.runGameLoop()
        
        dispatch_semaphore_wait(self.emulationSemaphore, DISPATCH_TIME_FOREVER)
        
        return true
    }
    
    func stopEmulation() -> Bool
    {
        guard self.state != .Stopped else { return false }
        
        let isRunning = self.state == .Running
        
        self.state = .Stopped
        
        if isRunning
        {
            dispatch_semaphore_wait(self.emulationSemaphore, DISPATCH_TIME_FOREVER)
        }
        
        self.bridge.saveGameSaveToURL(self.gameSaveURL)
        
        self.audioManager.stop()
        self.bridge.stop()
        
        return true
    }
    
    func pauseEmulation() -> Bool
    {
        guard self.state == .Running else { return false }
        
        self.state = .Paused
        
        dispatch_semaphore_wait(self.emulationSemaphore, DISPATCH_TIME_FOREVER)
        
        self.bridge.saveGameSaveToURL(self.gameSaveURL)
        
        self.audioManager.enabled = false
        self.bridge.pause()
        
        return true
    }
    
    func resumeEmulation() -> Bool
    {
        guard self.state == .Paused else { return false }
        
        self.state = .Running
        
        self.runGameLoop()
        
        dispatch_semaphore_wait(self.emulationSemaphore, DISPATCH_TIME_FOREVER)
        
        self.audioManager.enabled = true
        self.bridge.resume()
        
        return true
    }
}

//MARK: - Save States -
/// Save States
public extension EmulatorCore
{
    func saveSaveState(completion: (SaveStateType -> Void))
    {
        NSFileManager.defaultManager().prepareTemporaryURL { URL in
            
            self.bridge.saveSaveStateToURL(URL)
            
            let name = self.timestampDateFormatter.stringFromDate(NSDate())
            let saveState = SaveState(name: name, fileURL: URL)
            completion(saveState)
        }
    }
    
    func loadSaveState(saveState: SaveStateType) throws
    {
        guard let path = saveState.fileURL.path where NSFileManager.defaultManager().fileExistsAtPath(path) else { throw SaveStateError.doesNotExist }
        
        self.bridge.loadSaveStateFromURL(saveState.fileURL)
    }
}

//MARK: - Cheats -
/// Cheats
public extension EmulatorCore
{
    func activateCheat(cheat: CheatProtocol) throws
    {
        var success = true
        
        let codes = cheat.code.characters.split("\n")
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
            let codes = cheatCode.characters.split("\n")
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
    func setGameController(gameController: GameControllerProtocol?, atIndex index: Int) -> GameControllerProtocol?
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
    
    func gameControllerAtIndex(index: Int) -> GameControllerProtocol?
    {
        return self.gameControllersDictionary[index]
    }
}

extension EmulatorCore: GameControllerReceiverProtocol
{
    public func gameController(gameController: GameControllerProtocol, didActivateInput input: InputType)
    {
        guard input.dynamicType == self.gameInputType else { return }
        
        self.bridge.activateInput(input.rawValue)
    }
    
    public func gameController(gameController: GameControllerProtocol, didDeactivateInput input: InputType)
    {
        guard input.dynamicType == self.gameInputType else { return }
        
        self.bridge.deactivateInput(input.rawValue)
    }
}

extension EmulatorCore: DLTAEmulating
{
    public func didUpdateGameSave()
    {
        self.bridge.saveGameSaveToURL(self.gameSaveURL)
    }
}

private extension EmulatorCore
{
    func runGameLoop()
    {
        let emulationQueue = dispatch_queue_create("com.rileytestut.DeltaCore.emulationQueue", DISPATCH_QUEUE_SERIAL)
        dispatch_async(emulationQueue) {
            
            let screenRefreshRate = 1.0 / 60.0
            
            var emulationTime = NSThread.absoluteTime()
            var counter = 0.0
            
            while true
            {
                let frameDuration = 1.0 / (self.rate * 60.0)
                
                if self.rate != self.previousRate
                {
                    NSThread.setRealTimePriorityWithPeriod(frameDuration)
                    
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
                
                let currentTime = NSThread.absoluteTime()
                
                // The number of frames we need to skip to keep in sync
                let framesToSkip = Int((currentTime - emulationTime) / frameDuration)
                
                if framesToSkip > 0
                {
                    // Only actually skip frames if we're running at normal speed
                    if self.rate == self.supportedRates.start
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
                    dispatch_semaphore_signal(self.emulationSemaphore)
                    
                    self.previousState = state
                }
                
                if state != .Running
                {
                    break
                }
                
                NSThread.realTimeWaitUntil(emulationTime)
            }
            
        }
    }
    
    func runFrame(renderGraphics renderGraphics: Bool)
    {
        self.bridge.runFrame()
        
        if renderGraphics
        {
            self.videoManager.didUpdateVideoBuffer()
        }
        
        self.updateHandler?(self)
    }
}

