//
//  EmulatorCoreConfiguration.swift
//  DeltaCore
//
//  Created by Riley Testut on 6/20/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation

public class EmulatorCoreConfiguration: DynamicObject
{
    public var bridge: DLTAEmulatorBridge { fatalError("To be implemented by subclasses.") }
    
    public var gameInputType: InputProtocol.Type { fatalError("To be implemented by subclasses.") }
    
    public var audioBufferInfo: AudioManager.BufferInfo { fatalError("To be implemented by subclasses.") }
    
    public var videoBufferInfo: VideoManager.BufferInfo { fatalError("To be implemented by subclasses.") }
    
    public var supportedCheatFormats: [CheatFormat] { fatalError("To be implemented by subclasses.") }
    
    public var supportedRates: ClosedRange<Double> { fatalError("To be implemented by subclasses.") }
    
    public init(gameType: GameType)
    {
        super.init(dynamicIdentifier: gameType.rawValue, initSelector: #selector(EmulatorCoreConfiguration.init(gameType:)), initParameters: [gameType])
    }
    
    public func gameSaveURL(for game: GameProtocol) -> URL?
    {
        fatalError("To be implemented by subclasses.")
    }
    
    public func inputs(for controller: MFiExternalController, input: InputProtocol) -> [InputProtocol]
    {
        fatalError("To be implemented by subclasses.")
    }
}
