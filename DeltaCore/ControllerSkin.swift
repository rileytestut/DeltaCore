//
//  ControllerSkin.swift
//  DeltaCore
//
//  Created by Riley Testut on 5/5/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import UIKit
import ZipZap

typealias ImagesDictionaryType = [String: [String: [String: String]]]
typealias MappingsDictionaryType = [String: [String: [String: AnyObject]]] // Cannot cast directly to [String: [String: [String: [String: [String: CGFloat]]]]] b/c of bug in compiler

public class ControllerSkin: DynamicObject
{
    //MARK: - Properties -
    /** Properties **/
    public let name: String
    public let identifier: String
    public let debug: Bool
    
    @NSCopying public var URL: NSURL
    
    /// <CustomStringConvertible>
    public override var description: String {
        return self.name + " (" + self.identifier + ")"
    }
    
    //MARK: - Private Properties
    private let infoDictionary: [String: AnyObject]
    private let imageCache: NSCache
    
    //MARK: - Initializers -
    /** Initializers **/
    public required init?(URL: NSURL)
    {
        self.URL = URL
        
        do
        {
            let archive = try ZZArchive(URL: self.URL)
            let entry = (archive.entries as! [ZZArchiveEntry]).filter { $0.fileName == "info.json" }.first ?? ZZArchiveEntry()
            let data = try entry.newData()
            
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
    
    /** Methods **/
    
    //MARK: - Convenience Methods -
    /// Convenience Methods
    public class func defaultControllerSkinForGameUTI(UTI: String) -> ControllerSkin?
    {
        guard self == ControllerSkin.self else { fatalError("ControllerSkin subclass must implement defaultControllerSkinForGameUTI:") }
        
        let subclass = ControllerSkin.self.subclassForDynamicIdentifier(UTI) as! ControllerSkin.Type
        return subclass.defaultControllerSkinForGameUTI(UTI)
    }
    
    //MARK: - Inputs
    /// Inputs
    public func inputsForPoint(point: CGPoint, traitCollection: UITraitCollection) -> [InputType]
    {
        let mappingsDictionary = self.infoDictionary["mappings"] as! MappingsDictionaryType
        
        guard let dictionary = self.filterDictionary(mappingsDictionary, forCurrentDeviceWithTraitCollection: traitCollection) as? [String: [String: CGFloat]] else { return []
        }
        
        var inputs: [InputType] = []
        for (key, mapping) in dictionary
        {
            let frame = CGRect(x: mapping["x"] ?? 0, y: mapping["y"] ?? 0, width: mapping["width"] ?? 0, height: mapping["height"] ?? 0)
            if !CGRectContainsPoint(frame, point)
            {
                continue
            }
            
            for input in self.inputsForPoint(point, inRect: frame, key: key)
            {
                inputs.append(input)
            }
        }
        
        return inputs
    }
    
    //MARK: - Subclass Methods -
    /** Subclass Methods **/
    /** These methods should never be called directly **/
    
    //MARK: - Inputs
    /// Inputs
    public func inputsForPoint(point: CGPoint, inRect rect: CGRect, key: String) -> [InputType]
    {
        fatalError("ControllerSkin subclass must implement defaultControllerSkinForGameUTI:")
    }
}

//MARK: - Trait Collections -
/// Trait Collections
public extension ControllerSkin
{
    public func supportsTraitCollection(traitCollection: UITraitCollection) -> Bool
    {
        let imagesDictionary = self.infoDictionary["images"] as! ImagesDictionaryType
        let imageName = self.filterDictionary(imagesDictionary, forCurrentDeviceWithTraitCollection: traitCollection)
        
        return imageName != nil
    }
    
    public func imageForTraitCollection(traitCollection: UITraitCollection) -> UIImage?
    {
        let imagesDictionary = self.infoDictionary["images"] as! ImagesDictionaryType
        
        guard let imageName = self.filterDictionary(imagesDictionary, forCurrentDeviceWithTraitCollection: traitCollection) else {
            return nil
        }
        
        guard let cacheKey = self.URL.URLByAppendingPathComponent(imageName).path else {
            return nil
        }
        
        if let image = self.imageCache.objectForKey(cacheKey) as? UIImage {
            return image
        }
        
        do
        {
            let archive = try ZZArchive(URL: self.URL)
            let entry = (archive.entries as! [ZZArchiveEntry]).filter { $0.fileName == imageName }.first ?? ZZArchiveEntry()
            let data = try entry.newData()
            
            if let image = UIImage(data: data, scale: UIScreen.mainScreen().scale)
            {
                self.imageCache.setObject(image, forKey: cacheKey)
                return image
            }
        }
        catch let error as NSError {
            print("\(error) \(error.userInfo)")
        }
        
        return nil
    }
}

private extension ControllerSkin
{
    func filterDictionary<T>(dictionary: [String: [String: [String: T]]], forCurrentDeviceWithTraitCollection traitCollection: UITraitCollection) -> T?
    {
        guard let deviceKey = self.deviceKeyForCurrentDevice() else { return nil }
        
        let deviceIdiom: String
        
        switch traitCollection.userInterfaceIdiom
        {
        case .Phone:
            deviceIdiom = "phone"
        case .Pad:
            deviceIdiom = "pad"
            
        case .TV: fallthrough
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
        
        let filteredDictionary = dictionary[deviceIdiom]?[verticalSizeClass]
        let result = filteredDictionary?[deviceKey] ?? filteredDictionary?["resizable"]
        
        return result
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
