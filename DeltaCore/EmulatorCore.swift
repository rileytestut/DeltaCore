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

public class EmulatorCore: DynamicObject
{
    public let game: Game
    public private(set) var gameViews: [GameView] = []

    public required init(game: Game)
    {
        self.game = game
        
        super.init(dynamicIdentifier: game.UTI, initSelector: Selector("initWithGame:"), initParameters: [game])
    }
}

