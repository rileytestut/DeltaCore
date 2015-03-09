//
//  Game.swift
//  DeltaCore
//
//  Created by Riley Testut on 3/8/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import Foundation

public class Game: NSObject
{
    public let name: String
    public let URL: NSURL
    
    private static var registeredSubclasses: [String: Game.Type] = ["com.rileytestut.delta.game": Game.self]
    
    public class func gameWithURL(URL: NSURL) -> Game?
    {
        let identifier = "com.rileytestut.delta.game"
        
        let game: Game?
        
        if let GameClass = self.registeredSubclasses[identifier]
        {
            game = GameClass(URL: URL)
        }
        else
        {
            game = Game(URL: URL)
        }
        
        return game
    }
    
    public class func registerSubclass(subclass: Game.Type, forUTI UTI: String)
    {
        self.registeredSubclasses[UTI] = subclass
    }
    
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