//
//  EmulatorCore.swift
//  DeltaCore
//
//  Created by Riley Testut on 3/11/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import UIKit

public extension EmulatorCore
{
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
}

public class EmulatorCore: NSObject
{
    public let game: Game
    public private(set) var gameViews: [GameView] = []
    
    private static var registeredSubclasses: [String: EmulatorCore.Type] = [NSStringFromClass(Game.self): EmulatorCore.self]
    
    public class func registerSubclass(subclass: EmulatorCore.Type, forGameType gameType: Game.Type)
    {
        let className = NSStringFromClass(gameType)
        self.registeredSubclasses[className] = subclass
    }
    
    public class func emulatorCoreWithGame(game: Game) -> EmulatorCore
    {
        let emulatorCore: EmulatorCore
        
        if let EmulatorCoreClass = self.registeredSubclasses[NSStringFromClass(game.dynamicType)]
        {
            emulatorCore = EmulatorCoreClass(game: game)
        }
        else
        {
            emulatorCore = EmulatorCore(game: game)
        }
        
        return emulatorCore
    }
    
    public required init(game: Game)
    {
        self.game = game
        
        super.init()
    }
}
