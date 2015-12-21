//
//  ControllerSkin.swift
//  DeltaCore
//
//  Created by Riley Testut on 5/5/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit

import ZipZap

public struct ControllerSkinConfiguration
{
    // Trait Collection
    public var horizontalSizeClass = UIUserInterfaceSizeClass.Compact
    public var verticalSizeClass = UIUserInterfaceSizeClass.Compact
    public var displayScale: CGFloat
    
    // Misc.
    public var containerSize: CGSize
    public var splitViewActivated = false
    
    public init(traitCollection: UITraitCollection, containerSize: CGSize)
    {
        self.horizontalSizeClass = (traitCollection.horizontalSizeClass != .Unspecified) ? traitCollection.horizontalSizeClass : .Compact
        self.verticalSizeClass = (traitCollection.verticalSizeClass != .Unspecified) ? traitCollection.verticalSizeClass : .Compact
        self.displayScale = traitCollection.displayScale
        
        self.containerSize = containerSize
    }
}

public class ControllerSkin: DynamicObject
{
    //MARK: - Properties -
    /** Properties **/
    
    // Metadata
    public let name: String
    public let identifier: String
    public let gameTypeIdentifier: String
    public let debugModeEnabled: Bool
    
    public let URL: NSURL
    
    /// <CustomStringConvertible>
    public override var description: String {
        return self.name + " (" + self.identifier + ")"
    }
    
    private let representations: [String: Representation]
    
    private let imageCache = NSCache()
    
    //MARK: - Initializers -
    /** Initializers **/
    public required init?(URL: NSURL)
    {
        self.URL = URL
        
        let info: [String: AnyObject]
        
        do
        {
            let archive = try ZZArchive(URL: self.URL)
            let entry = (archive.entries as! [ZZArchiveEntry]).filter { $0.fileName == "info.json" }.first ?? ZZArchiveEntry()
            let data = try entry.newData()
            
            info = try NSJSONSerialization.JSONObjectWithData(data, options: []) as? [String: AnyObject] ?? [:]
        }
        catch let error as NSError
        {
            print("\(error) \(error.userInfo)")
            
            info = [:]
        }
        
        self.name = info["name"] as? String ?? ""
        self.identifier = info["identifier"] as? String ?? ""
        self.gameTypeIdentifier = info["gameTypeIdentifier"] as? String ?? ""
        self.debugModeEnabled = info["debug"] as? Bool ?? false
        
        var representations = [String: Representation]()
        
        if let representationsDictionary = info["representations"] as? [String: [String: AnyObject]]
        {
            for (key, dictionary) in representationsDictionary
            {
                if let representation = Representation(dictionary: dictionary)
                {
                    representations[key] = representation
                }
            }
        }
        
        self.representations = representations
        
        super.init(dynamicIdentifier: self.gameTypeIdentifier, initSelector: Selector("initWithURL:"), initParameters: [URL])
        
        if info.isEmpty || self.name == "" || self.identifier == "" || self.gameTypeIdentifier == ""
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
    
    //MARK: - Subclass Methods -
    /** Subclass Methods **/
    /** These methods should never be called directly **/
    
    public func inputsForItem(item: Item, point: CGPoint) -> [InputType]
    {
        fatalError("ControllerSkin subclass must implement defaultControllerSkinForGameUTI:")
    }
}

public extension ControllerSkin
{
    func supportsConfiguration(configuration: ControllerSkinConfiguration) -> Bool
    {
        return (self.representationForConfiguration(configuration) != nil)
    }
    
    /// Provided point should be normalized [0,1] for both axies
    func inputsForPoint(point: CGPoint, configuration: ControllerSkinConfiguration) -> [InputType]?
    {
        guard let representation = self.representationForConfiguration(configuration) else { return nil }
        
        var inputs: [InputType] = []
        for item in representation.items
        {
            guard CGRectContainsPoint(item.extendedFrame, point) else { continue }
            
            for input in self.inputsForItem(item, point: point)
            {
                inputs.append(input)
            }
        }
        
        return inputs
    }
    
    func gameScreenFrameForConfiguration(configuration: ControllerSkinConfiguration) -> CGRect?
    {
        let representation = self.representationForConfiguration(configuration)
        return representation?.gameScreenFrame
    }
    
    func imageForConfiguration(configuration: ControllerSkinConfiguration) -> UIImage?
    {
        guard configuration.displayScale > 0.0 else { return nil }
        guard let representation = self.representationForConfiguration(configuration) else { return nil }

        let cacheKey = representation.assetFilename + "_" + String(configuration.containerSize)
        
        if let image = self.imageCache.objectForKey(cacheKey) as? UIImage { return image }
        
        if representation.assetFilename.lowercaseString.hasSuffix(".pdf")
        {
            // PDF
            //TODO: Implement PDF Rendering
        }
        else
        {
            // Image
            
            var archiveEntry: ZZArchiveEntry?

            switch configuration.displayScale
            {
                // >= 3.0 (iPhone 6 Plus)
            case 3.0...CGFloat.infinity:
                archiveEntry = self.imageArchiveEntryForRepresentation(representation, suffix: "@3x")
                
                // iPads
            case 2.0 where (configuration.horizontalSizeClass == .Regular && configuration.verticalSizeClass == .Regular):
                archiveEntry = self.imageArchiveEntryForRepresentation(representation, suffix: "@2x")
                
                // iPhone 6
            case 2.0 where (configuration.containerSize.height > 626 || configuration.containerSize.width > 626):
                archiveEntry = self.imageArchiveEntryForRepresentation(representation, suffix: "@2x")
                
                // iPhone 5
            case 2.0 where (configuration.containerSize.height > 520 || configuration.containerSize.width > 520):
                archiveEntry = self.imageArchiveEntryForRepresentation(representation, suffix: "@568h")
                
                // iPhone 4
            case 2.0:
                archiveEntry = self.imageArchiveEntryForRepresentation(representation, suffix: "@480h")
                
            default: break
                
            }
            
            if archiveEntry == nil
            {
                archiveEntry = self.imageArchiveEntryForRepresentation(representation)
            }
            
            do
            {
                if let data = try archiveEntry?.newData(), let image = UIImage(data: data, scale: configuration.displayScale)
                {
                    self.imageCache.setObject(image, forKey: cacheKey)
                    
                    return image
                }
            }
            catch let error as NSError {
                print("\(error) \(error.userInfo)")
            }
        }
        
        return nil
        
    }
    
    func itemsForConfiguration(configuration: ControllerSkinConfiguration) -> [ControllerSkin.Item]?
    {
        let representation = self.representationForConfiguration(configuration)
        return representation?.items
    }
}

extension ControllerSkin
{
    private struct Representation: CustomDebugStringConvertible
    {
        let assetFilename: String
        let translucent: Bool
        let items: [Item]
        let gameScreenFrame: CGRect?
        
        /// <CustomDebugStringConvertible>
        var debugDescription: String {
            return self.assetFilename + " " + String(self.items)
        }
        
        init?(dictionary: [String: AnyObject])
        {
            guard let assetFilename = dictionary["assetFilename"] as? String else { return nil }
            guard let itemsArray = dictionary["items"] as? [[String: AnyObject]] else { return nil }
            guard let mappingSize = CGSize(dictionary: (dictionary["mappingSize"] as? [String: CGFloat]) ?? [:]) else { return nil }
            
            // extendedEdges is not required
            var extendedEdges = UIEdgeInsets(dictionary: (dictionary["extendedEdges"] as? [String: CGFloat]) ?? [:]) ?? UIEdgeInsetsZero
            
            // Negate values (because a positive inset would technically be reducing the total size of the frame)
            extendedEdges.top *= -1;
            extendedEdges.bottom *= -1;
            extendedEdges.left *= -1;
            extendedEdges.right *= -1;
            
            self.assetFilename = assetFilename
            self.translucent = (dictionary["translucent"] as? Bool) ?? false
            
            var items = [Item]()
            
            for dictionary in itemsArray
            {
                if let item = Item(mappingSize: mappingSize, extendedEdges: extendedEdges, dictionary: dictionary)
                {
                    items.append(item)
                }
            }
            
            self.items = items
            
            self.gameScreenFrame = CGRect(dictionary: (dictionary["gameScreen"] as? [String: CGFloat]) ?? [:])
        }
    }
    
    public struct Item: CustomDebugStringConvertible
    {
        public let keys: [String]
        
        public let frame: CGRect
        public let extendedFrame: CGRect

        /// <CustomDebugStringConvertible>
        public var debugDescription: String {
            return String(self.keys) + " " + String(self.extendedFrame)
        }
        
        public init?(mappingSize: CGSize, extendedEdges: UIEdgeInsets, dictionary: [String: AnyObject])
        {
            guard let frameDictionary = dictionary["frame"] as? [String: CGFloat], frame = CGRect(dictionary: frameDictionary) else { return nil }
            guard let keys = dictionary["keys"] as? [String] else { return nil }
            
            self.keys = keys
            
            var extendedEdges = extendedEdges
            
            if let adjustedExtendedEdges = dictionary["extendedEdges"] as? [String : CGFloat]
            {
                if let top = adjustedExtendedEdges["top"]
                {
                    extendedEdges.top = -top
                }
                
                if let bottom = adjustedExtendedEdges["bottom"]
                {
                    extendedEdges.bottom = -bottom
                }
                
                if let left = adjustedExtendedEdges["left"]
                {
                    extendedEdges.left = -left
                }
                
                if let right = adjustedExtendedEdges["right"]
                {
                    extendedEdges.right = -right
                }
            }
            
            let extendedFrame = CGRect(x: frame.minX + extendedEdges.left, y: frame.minY + extendedEdges.top,
                                       width: frame.width - extendedEdges.left - extendedEdges.right, height: frame.height - extendedEdges.top - extendedEdges.bottom)
            
            // Convert frames to relative values
            self.frame = CGRect(x: frame.minX / mappingSize.width, y: frame.minY / mappingSize.height, width: frame.width / mappingSize.width, height: frame.height / mappingSize.height)
            self.extendedFrame = CGRect(x: extendedFrame.minX / mappingSize.width, y: extendedFrame.minY / mappingSize.height, width: extendedFrame.width / mappingSize.width, height: extendedFrame.height / mappingSize.height)
        }
    }
}

private extension ControllerSkin
{
    func representationForConfiguration(configuration: ControllerSkinConfiguration) -> Representation?
    {
        switch configuration
        {
            // Split View
        case _ where configuration.splitViewActivated: return self.representations["splitView"]
            
            // Regular skins
        case _ where configuration.horizontalSizeClass == .Regular && configuration.verticalSizeClass == .Regular:
            
            if configuration.containerSize.width > configuration.containerSize.height
            {
                return self.representations["regularLandscape"]
            }
            else
            {
                return self.representations["regularPortrait"]
            }
            
            
            // Compact skins
        case _ where configuration.horizontalSizeClass == .Compact || configuration.verticalSizeClass == .Compact:
            
            let legacyAspectRatio: CGFloat = 3.0 / 2.0
            let widescreenAspectRatio: CGFloat = 16.0 / 9.0
            
            if configuration.containerSize.width > configuration.containerSize.height
            {
                let aspectRatio = configuration.containerSize.width / configuration.containerSize.height
                
                if abs(aspectRatio - legacyAspectRatio) < abs(aspectRatio - widescreenAspectRatio)
                {
                    // Closer to 3:2 aspect ratio
                    return self.representations["compactLegacyLandscape"]
                }
                else
                {
                    // Closer to 16:9 aspect ratio
                    return self.representations["compactLandscape"]
                }
            }
            else
            {
                let aspectRatio = configuration.containerSize.height / configuration.containerSize.width
                
                if abs(aspectRatio - legacyAspectRatio) < abs(aspectRatio - widescreenAspectRatio)
                {
                    // Closer to 3:2 aspect ratio
                    
                    // Unlike landscape, this is not required. So only return if it exists
                    if let representation = self.representations["compactLegacyPortrait"]
                    {
                        return representation
                    }
                }
                
                // Closer to 16:9 aspect ratio
                return self.representations["compactPortrait"]
            }
            
            
        default: return nil
        }
    }
    
    func imageArchiveEntryForRepresentation(representation: Representation, suffix: String = "") -> ZZArchiveEntry?
    {
        guard let insertionIndex = representation.assetFilename.characters.indexOf(".") else { return nil }
        
        var filename = representation.assetFilename
        filename.insertContentsOf(suffix.characters, at: insertionIndex)
        
        // Would be strange if this fails since it had to work to init ControllerSkin in the first place...
        if let archive = try? ZZArchive(URL: self.URL)
        {
            let entries = archive.entries as! [ZZArchiveEntry]
            if let index = entries.indexOf({ $0.fileName == filename })
            {
                return entries[index]
            }
        }
        
        return nil
    }
}
