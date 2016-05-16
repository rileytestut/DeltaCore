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
    enum State
    {
        case Stopped
        case Running
        case Paused
    }
}

public class EmulatorCore: DynamicObject, GameControllerReceiverType
{
    //MARK: - Properties -
    /** Properties **/
    public let game: GameType
    public private(set) var gameViews: [GameView] = []
    public var gameControllers: [GameControllerType] {
        get
        {
            return Array(self.gameControllersDictionary.values)
        }
    }
    
    public lazy var audioManager: AudioManager = AudioManager(bufferInfo: self.audioBufferInfo)
    public lazy var videoManager: VideoManager = VideoManager(bufferInfo: self.videoBufferInfo)
    
    /// Used for converting timestamps to human-readable strings (such as for names of Save States)
    /// Can be customized to provide different default formatting
    public let timestampDateFormatter: NSDateFormatter
    
    public private(set) var state = State.Stopped
    
    public var fastForwarding = false {
        didSet {
            self.audioManager.rate = self.fastForwarding ? self.fastForwardRate : 1.0
        }
    }
    
    //MARK: - Private Properties
    private var gameControllersDictionary: [Int: GameControllerType] = [:]

    //MARK: - Initializers -
    /** Initializers **/
    public required init(game: GameType)
    {
        self.game = game
        
        self.timestampDateFormatter = NSDateFormatter()
        self.timestampDateFormatter.timeStyle = .ShortStyle
        self.timestampDateFormatter.dateStyle = .LongStyle
        
        super.init(dynamicIdentifier: game.typeIdentifier, initSelector: Selector("initWithGame:"), initParameters: [game])
    }
    
    /** Subclass Methods **/
    /** Contained within main class declaration because of a Swift limitation where non-ObjC compatible extension methods cannot be overridden **/
    
    public var audioBufferInfo: AudioManager.BufferInfo {
        fatalError("To be implemented by subclasses.")
    }
    
    public var videoBufferInfo: VideoManager.BufferInfo {
        fatalError("To be implemented by subclasses.")
    }
    
    public var preferredRenderingSize: CGSize {
       fatalError("To be implemented by subclasses.")
    }
    
    public var fastForwardRate: Float {
        fatalError("To be implemented by subclasses.")
    }
    
    //MARK: - GameControllerReceiver -
    /// GameControllerReceiver
    public func gameController(gameController: GameControllerType, didActivateInput input: InputType)
    {
        // Implemented by subclasses
    }
    
    public func gameController(gameController: GameControllerType, didDeactivateInput input: InputType)
    {
        // Implemented by subclasses
    }
    
    //MARK: - Input Transformation -
    /// Input Transformation
    public func inputsForMFiExternalControllerInput(input: InputType) -> [InputType]
    {
        return []
    }
    
    //MARK: - Save States -
    /// Save States
    public func saveSaveState(completion: (SaveStateType -> Void)) -> Bool
    {
        guard self.state != .Stopped else { return false }
        
        return true
    }
    
    public func loadSaveState(saveState: SaveStateType) -> Bool
    {
        guard self.state != .Stopped else { return false }
        
        return true
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
        
        return true
    }
    
    func stopEmulation() -> Bool
    {
        guard self.state != .Stopped else { return false }
        
        self.state = .Stopped
        self.audioManager.stop()
        
        return true
    }
    
    func pauseEmulation() -> Bool
    {
        guard self.state == .Running else { return false }
        
        self.state = .Paused
        self.audioManager.enabled = false
        
        return true
    }
    
    func resumeEmulation() -> Bool
    {
        guard self.state == .Paused else { return false }
        
        self.state = .Running
        self.audioManager.enabled = true
        
        return true
    }
}

//MARK: - Controllers -
/// Controllers
public extension EmulatorCore
{
    func setGameController(gameController: GameControllerType?, atIndex index: Int) -> GameControllerType?
    {
        let previousGameController = self.gameControllerAtIndex(index)
        previousGameController?.playerIndex = nil
        
        gameController?.playerIndex = index
        gameController?.addReceiver(self)
        self.gameControllersDictionary[index] = gameController
        
        if let gameController = gameController as? MFiExternalController where gameController.inputTransformationHandler == nil
        {
            gameController.inputTransformationHandler = inputsForMFiExternalControllerInput
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
    
    func gameControllerAtIndex(index: Int) -> GameControllerType?
    {
        return self.gameControllersDictionary[index]
    }
}


