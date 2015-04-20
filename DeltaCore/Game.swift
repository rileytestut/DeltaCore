//
//  Game.swift
//  DeltaCore
//
//  Created by Riley Testut on 3/8/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import Foundation
import MobileCoreServices

public class Game: NSObject
{
    public let name: String
    public let URL: NSURL
    public let UTI: String
    
    public required init?(URL: NSURL)
    {
        self.URL = URL
        
        if let name = URL.lastPathComponent?.stringByDeletingPathExtension
        {
            self.name = name
        }
        else
        {
            self.name = ""
        }
                
        if let pathExtension = URL.pathExtension
        {
            let UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension, nil).takeRetainedValue() as String
            
            if UTI.hasPrefix("dyn.")
            {
                self.UTI = kUTTypeDeltaGame as String
            }
            else
            {
                self.UTI = UTI
            }
        }
        else
        {
            self.UTI = kUTTypeDeltaGame as String
        }
                
        super.init()
        
        if URL.path == nil
        {
            return nil
        }
        
        var isDirectory: ObjCBool = false
        let fileExists = NSFileManager.defaultManager().fileExistsAtPath(URL.path!, isDirectory: &isDirectory)
        
        if !fileExists || isDirectory
        {
            return nil
        }
    }
}

public func ==(lhs: Game, rhs: Game) -> Bool
{
    return lhs.URL == rhs.URL
}