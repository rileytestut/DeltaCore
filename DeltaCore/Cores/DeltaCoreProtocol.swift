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
    /* Game */
    var gameType: GameType { get }
    
    // Should be associated type, but Swift type system makes this difficult, so ¯\_(ツ)_/¯
    var gameInputType: Input.Type { get }
    
    var gameSaveFileExtension: String { get }
    
    /* Rendering */
    var frameDuration: TimeInterval { get }
    
    var audioFormat: AVAudioFormat { get }
    
    var videoFormat: VideoFormat { get }
    
    /* Cheats */
    var supportedCheatFormats: Set<CheatFormat> { get }
    
    /* Emulation */
    var emulatorBridge: EmulatorBridging { get }
}

public extension DeltaCoreProtocol
{
    var bundle: Bundle {
        #if FRAMEWORK
        let bundle = Bundle(for: type(of: self.emulatorBridge))
        #else
        let bundle = Bundle.main
        #endif
        return bundle
    }
}

public extension DeltaCoreProtocol
{
    var description: String {
        let description = self.bundle.bundleIdentifier ?? self.bundle.description
        return description
    }
}

public func ==(lhs: DeltaCoreProtocol, rhs: DeltaCoreProtocol) -> Bool
{
    return lhs.bundle == rhs.bundle
}
