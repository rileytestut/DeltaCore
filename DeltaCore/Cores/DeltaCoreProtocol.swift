//
//  DeltaCoreProtocol.swift
//  DeltaCore
//
//  Created by Riley Testut on 6/29/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import AVFoundation

public protocol DeltaCoreProtocol: CustomStringConvertible
{
    var gameType: GameType { get }
    
    var bundleIdentifier: String { get }
    
    var gameSaveFileExtension: String { get }
    
    var frameDuration: TimeInterval { get }
        
    var supportedCheatFormats: [CheatFormat] { get }
    
    var audioFormat: AVAudioFormat { get }
    
    var videoFormat: VideoFormat { get }
    
    var emulatorBridge: EmulatorBridging { get }
    
    var inputTransformer: InputTransforming { get }
}

public extension DeltaCoreProtocol
{
    var description: String {
        return self.bundleIdentifier
    }
}

public func ==(lhs: DeltaCoreProtocol, rhs: DeltaCoreProtocol) -> Bool
{
    return lhs.bundleIdentifier == rhs.bundleIdentifier
}
