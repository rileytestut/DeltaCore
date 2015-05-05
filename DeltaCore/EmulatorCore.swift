//
//  EmulatorCore.swift
//  DeltaCore
//
//  Created by Riley Testut on 3/11/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

public protocol GameInput
{
    // Used by subclasses to declare appropriate form of representing game inputs
}

public extension EmulatorCore
{
    //MARK: Game Views
    
    func addGameView(gameView: GameView)
    {
        self.gameViews.append(gameView)
    }
    
    func removeGameView(gameView: GameView)
    {
        if let index = find(self.gameViews, gameView)
        {
            self.gameViews.removeAtIndex(index);
        }
    }
    
    //MARK: Controllers
    
    func setGameController(gameController: GameController?, atIndex index: Int) -> GameController?
    {
        let previousGameController = self.gameControllerAtIndex(index)
        previousGameController?.playerIndex = nil
        
        gameController?.playerIndex = index
        self.gameControllersDictionary[index] = gameController
        
        return previousGameController
    }
    
    func gameControllerAtIndex(index: Int) -> GameController?
    {
        return self.gameControllersDictionary[index]
    }
}

public class EmulatorCore: DynamicObject, GameControllerReceiver
{
    public let game: Game
    public private(set) var gameViews: [GameView] = []
    public var gameControllers: [GameController] {
        get
        {
            return self.gameControllersDictionary.values.array
        }
    }
    
    private var gameControllersDictionary: [Int: GameController] = [:]

    public required init(game: Game)
    {
        self.game = game
        
        super.init(dynamicIdentifier: game.UTI, initSelector: Selector("initWithGame:"), initParameters: [game])
    }
    
    //MARK: GameControllerReceiver
    
    public func gameController(gameController: GameController, didActivateInput input: GameInput)
    {
        // Implemented by subclasses
    }
    
    public func gameController(gameController: GameController, didDeactivateInput input: GameInput)
    {
        // Implemented by subclasses
    }
}

