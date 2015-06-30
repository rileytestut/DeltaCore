//
//  ControllerSkin.swift
//  DeltaCore
//
//  Created by Riley Testut on 5/5/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import UIKit
import MobileCoreServices

typealias TraitCollectionDictionary = [String: [String: [String: AnyObject]]]

public extension ControllerSkin
{
    public func supportsTraitCollection(traitCollection: UITraitCollection) -> Bool
    {
        let imagesDictionary = self.infoDictionary["images"] as! TraitCollectionDictionary
        let dictionary = self.filteredResultForDictionary(imagesDictionary, withTraitCollection: traitCollection)
        
        if let deviceKey = self.deviceKeyForCurrentDevice() where (dictionary?[deviceKey] as? String) ?? (dictionary?["resizable"] as? String) != nil
        {
            return true
        }
        
        return false
    }
    
    public func imageForTraitCollection(traitCollection: UITraitCollection) -> UIImage?
    {
        let imagesDictionary = self.infoDictionary["images"] as! TraitCollectionDictionary
        let dictionary = self.filteredResultForDictionary(imagesDictionary, withTraitCollection: traitCollection)
        
        if let deviceKey = self.deviceKeyForCurrentDevice(),
            imageName = (dictionary?[deviceKey] as? String) ?? (dictionary?["resizable"] as? String),
            path = self.URL.URLByAppendingPathComponent(imageName).path
        {
            if let image = self.imageCache.objectForKey(path) as? UIImage
            {
                return image
            }
            
            if let data = NSData(contentsOfFile: path), image = UIImage(data: data, scale: UIScreen.mainScreen().scale)
            {
                self.imageCache.setObject(image, forKey: path)
                return image
            }
        }
        
        return nil
    }
}

public class ControllerSkin: DynamicObject
{
    public let name: String
    public let identifier: String
    public let debug: Bool
    
    @NSCopying public var URL: NSURL
    
    public var displaySize: CGSize = CGSizeZero
    
    public override var description: String {
        return self.name + " (" + self.identifier + ")"
    }
    
    private let infoDictionary: [String: AnyObject]
    private let imageCache: NSCache
    
    public required init?(URL: NSURL)
    {
        self.URL = URL
        
        let infoDictionaryURL = self.URL.URLByAppendingPathComponent("info.json")
        let data = NSData(contentsOfURL: infoDictionaryURL) ?? NSData()
        
        do
        {
            self.infoDictionary = try NSJSONSerialization.JSONObjectWithData(data, options: []) as? [String: AnyObject] ?? [:]
        }
        catch let error as NSError
        {
            self.infoDictionary = [:]
            
            print("\(error) \(error.userInfo)")
        }
        
        self.name = self.infoDictionary["name"] as? String ?? ""
        self.identifier = self.infoDictionary["identifier"] as? String ?? ""
        self.debug = (self.infoDictionary["debug"] as? NSNumber)?.boolValue ?? false
        
        let dynamicIdentifier = self.infoDictionary["gameUTI"] as? String ?? ""
        
        self.imageCache = NSCache()
        
        super.init(dynamicIdentifier: dynamicIdentifier, initSelector: Selector("initWithURL:"), initParameters: [URL])
        
        if self.infoDictionary.isEmpty || self.name == "" || self.identifier == "" || dynamicIdentifier == ""
        {
            return nil
        }
    }
        
    //MARK: Inputs
    
    public func inputForPoint(point: CGPoint) -> GameInput
    {
        return EmulatorInput.Menu
    }
}

private extension ControllerSkin
{
    func filteredResultForDictionary(dictionary: TraitCollectionDictionary, withTraitCollection traitCollection: UITraitCollection) -> [String: AnyObject]?
    {
        let deviceIdiom: String

        switch traitCollection.userInterfaceIdiom
        {
        case .Phone:
            deviceIdiom = "phone"
        case .Pad:
            deviceIdiom = "pad"
        case .Unspecified:
            deviceIdiom = ""
        }
        
        let verticalSizeClass: String
        
        switch traitCollection.verticalSizeClass
        {
        case .Compact:
            verticalSizeClass = "compact"
        case .Regular:
            verticalSizeClass = "regular"
        case .Unspecified:
            verticalSizeClass = ""
        }
        
        let filteredResult = dictionary[deviceIdiom]?[verticalSizeClass]
        return filteredResult
    }
    
    func deviceKeyForCurrentDevice() -> String?
    {
        let deviceKey: String?
        
        if UIDevice.currentDevice().userInterfaceIdiom == .Phone
        {
            switch UIScreen.mainScreen().nativeBounds.height
            {
            case 960:
                deviceKey = "3.5\""
                
            case 1136:
                deviceKey = "4.0\""
                
            case 1334:
                deviceKey = "4.7\""
                
            case 2208:
                deviceKey = "5.5\""
                
            default:
                deviceKey = nil
            }
            
        }
        else if UIDevice.currentDevice().userInterfaceIdiom == .Pad
        {
            if UIScreen.mainScreen().scale == 1.0
            {
                deviceKey = "nonretina"
            }
            else
            {
                deviceKey = "retina"
            }
        }
        else
        {
            deviceKey = nil
        }
        
        return deviceKey
    }
}
