//
//  Delta.swift
//  DeltaCore
//
//  Created by Riley Testut on 7/22/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import Foundation

extension GameType: CustomStringConvertible
{
    public var description: String {
        return self.rawValue
    }
}

public extension GameType
{
    public static let unknown = GameType("com.rileytestut.delta.game.unknown")
}

public struct Delta
{
    public private(set) static var registeredCores = [GameType: DeltaCoreProtocol]()
    
    private init()
    {
    }
    
    public static func register(_ core: DeltaCoreProtocol?, for gameTypes: Set<GameType>? = nil)
    {
        let gameTypes = gameTypes ?? core?.supportedGameTypes ?? []
        
        for gameType in gameTypes
        {
            if let core = core, !core.supportedGameTypes.contains(gameType)
            {
                // Core doesn't support this gameType, so we ignore it
                continue
            }
            
            self.registeredCores[gameType] = core
        }
    }
    
    public static func core(for gameType: GameType) -> DeltaCoreProtocol?
    {
        return self.registeredCores[gameType]
    }
}
