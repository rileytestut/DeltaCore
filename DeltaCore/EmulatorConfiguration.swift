//
//  EmulatorConfiguration.swift
//  DeltaCore
//
//  Created by Riley Testut on 6/20/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation

public protocol EmulatorConfiguration
{
    var gameSaveFileExtension: String { get }
    
    var audioBufferInfo: AudioManager.BufferInfo { get }
    
    var videoBufferInfo: VideoManager.BufferInfo { get }
    
    var supportedCheatFormats: [CheatFormat] { get }
    
    var supportedRates: ClosedRange<Double> { get }
}
