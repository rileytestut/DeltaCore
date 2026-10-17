//
//  Delta.swift
//  DeltaCore
//
//  Created by Riley Testut on 7/22/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import Foundation

#if SWIFT_PACKAGE
@_exported import CDeltaCore
#endif

extension GameType: CustomStringConvertible
{
    public var description: String {
        return self.rawValue
    }
}

public extension GameType
{
    static let unknown = GameType("com.rileytestut.delta.game.unknown")
}

public struct Delta
{
    public private(set) static var registeredCores = [GameType: DeltaCoreProtocol]()
    
    private init()
    {
    }
    
    public static func register(_ core: DeltaCoreProtocol)
    {
        self.registeredCores[core.gameType] = core
    }
    
    public static func unregister(_ core: DeltaCoreProtocol)
    {
        // Ensure another core has not been registered for core.gameType.
        guard let registeredCore = self.registeredCores[core.gameType], registeredCore == core else { return }
        self.registeredCores[core.gameType] = nil
    }
    
    public static func core(for gameType: GameType) -> DeltaCoreProtocol?
    {
        return self.registeredCores[gameType]
    }
    
    public static var coresDirectoryURL: URL = {
        #if os(tvOS)
        let baseURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        #else
        let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        #endif
        let coresDirectoryURL = baseURL.appendingPathComponent("Cores", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: coresDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        
        return coresDirectoryURL
    }()
}
