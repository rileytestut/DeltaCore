//
//  ControllerSkin.swift
//  DeltaCore
//
//  Created by Riley Testut on 5/5/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit
import ZipZap

public let kUTTypeDeltaControllerSkin: CFString = "com.rileytestut.delta.skin" as CFString

private typealias RepresentationDictionary = [String: [String: AnyObject]]

extension ControllerSkin
{
    public struct Item
    {
        public let keys: Set<String>
        public let frame: CGRect
        public let extendedFrame: CGRect
        
        fileprivate init?(dictionary: [String: AnyObject], extendedEdges: ExtendedEdges, mappingSize: CGSize)
        {
            guard
                let keys = dictionary["keys"] as? [String],
                let frameDictionary = dictionary["frame"] as? [String: CGFloat], let frame = CGRect(dictionary: frameDictionary)
            else { return nil }
            
            self.keys = Set(keys)
            
            let overrideExtendedEdges = ExtendedEdges(dictionary: dictionary["extendedEdges"] as? [String: CGFloat])
            
            var extendedEdges = extendedEdges
            extendedEdges.top = overrideExtendedEdges.top ?? extendedEdges.top
            extendedEdges.bottom = overrideExtendedEdges.bottom ?? extendedEdges.bottom
            extendedEdges.left = overrideExtendedEdges.left ?? extendedEdges.left
            extendedEdges.right = overrideExtendedEdges.right ?? extendedEdges.right
            
            var extendedFrame = frame
            extendedFrame.origin.x -= extendedEdges.left ?? 0
            extendedFrame.origin.y -= extendedEdges.top ?? 0
            extendedFrame.size.width += (extendedEdges.left ?? 0) + (extendedEdges.right ?? 0)
            extendedFrame.size.height += (extendedEdges.top ?? 0) + (extendedEdges.bottom ?? 0)
            
            // Convert frames to relative values.
            let scaleTransform = CGAffineTransform(scaleX: 1.0 / mappingSize.width, y: 1.0 / mappingSize.height)
            self.frame = frame.applying(scaleTransform)
            self.extendedFrame = extendedFrame.applying(scaleTransform)
        }
    }
}

public struct ControllerSkin: ControllerSkinProtocol
{
    public let name: String
    public let identifier: String
    public let gameType: GameType
    public let isDebugModeEnabled: Bool
    
    public let fileURL: URL
    
    fileprivate let representations: [Traits: Representation]
    fileprivate let imageCache = NSCache<NSString, UIImage>()
    
    public init?(fileURL: URL)
    {
        self.fileURL = fileURL
        
        var info = [String: AnyObject]()
        
        do
        {
            let archive = try ZZArchive(url: self.fileURL)
            
            if let index = archive.entries.index(where: { $0.fileName == "info.json" })
            {
                let entry = archive.entries[index]
                let data = try entry.newData()
                
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: AnyObject]
                {
                    info = json
                }
            }
        }
        catch let error as NSError
        {
            print("\(error) \(error.userInfo)")
        }
        
        guard
            let name = info["name"] as? String,
            let identifier = info["identifier"] as? String,
            let gameType = info["gameTypeIdentifier"] as? GameType,
            let isDebugModeEnabled = info["debug"] as? Bool,
            let representationsDictionary = info["representations"] as? RepresentationDictionary
        else { return nil }
        
        self.name = name
        self.identifier = identifier
        self.gameType = gameType
        self.isDebugModeEnabled = isDebugModeEnabled
        
        let representationsSet = ControllerSkin.parsedRepresentations(from: representationsDictionary)
        
        var representations = [Traits: Representation]()
        for representation in representationsSet
        {
            representations[representation.traits] = representation
        }
        self.representations = representations
        
        guard self.representations.count > 0 else { return nil }
    }
    
    // Sometimes, recursion really is the best solution ¯\_(ツ)_/¯
    private static func parsedRepresentations(from representationsDictionary: RepresentationDictionary, deviceType: DeviceType? = nil, displayMode: DisplayMode? = nil, orientation: Orientation? = nil) -> Set<Representation>
    {
        var representations = Set<Representation>()
        
        for (key, dictionary) in representationsDictionary
        {
            if deviceType == nil
            {
                guard let deviceType = DeviceType(rawValue: key), let dictionary = dictionary as? RepresentationDictionary else { continue }
                
                representations.formUnion(self.parsedRepresentations(from: dictionary, deviceType: deviceType))
            }
            else if displayMode == nil
            {
                if let displayMode = DisplayMode(rawValue: key), let dictionary = dictionary as? RepresentationDictionary
                {
                    representations.formUnion(self.parsedRepresentations(from: dictionary, deviceType: deviceType, displayMode: displayMode))
                }
                else
                {
                    // Key doesn't exist, so we continue with the same dictionary we're currently iterating, but pass in .fullScreen for displayMode
                    representations.formUnion(self.parsedRepresentations(from: representationsDictionary, deviceType: deviceType, displayMode: .fullScreen))
                    
                    // Return early to prevent us from repeating the above step multiple times
                    return representations
                }
            }
            else if orientation == nil
            {
                guard
                    let deviceType = deviceType,
                    let displayMode = displayMode,
                    let orientation = Orientation(rawValue: key)
                    else { continue }
                
                let traits = Traits(deviceType: deviceType, displayMode: displayMode, orientation: orientation)
                if let representation = Representation(traits: traits, dictionary: dictionary)
                {
                    representations.insert(representation)
                }
            }
        }
        
        return representations
    }
}

public extension ControllerSkin
{
    static func standardControllerSkin(for gameType: GameType) -> ControllerSkin?
    {
        guard
            let deltaCore = Delta.core(for: gameType),
            let bundle = Bundle(identifier: deltaCore.bundleIdentifier),
            let fileURL = bundle.url(forResource: "Standard", withExtension: "deltaskin")
        else { return nil }
        
        let controllerSkin = ControllerSkin(fileURL: fileURL)
        return controllerSkin
    }
}

public extension ControllerSkin
{
    func supports(_ traits: Traits) -> Bool
    {
        let representation = self.representations[traits]
        return representation != nil
    }
    
    func image(for traits: Traits, preferredSize: Size) -> UIImage?
    {
        guard let representation = self.representations[traits] else { return nil }
        
        let cacheKey = self.cacheKey(for: traits, size: preferredSize)
        
        if let image = self.imageCache.object(forKey: cacheKey as NSString)
        {
            return image
        }
        
        var returnedImage: UIImage? = nil
        
        switch preferredSize
        {
        case .small:
            if let image = self.image(for: representation, assetSize: AssetSize(size: .small)) { returnedImage = image }
            else if let image = self.image(for: representation, assetSize: AssetSize(size: .small, resizable: true)) { returnedImage = image }
            else if let image = self.image(for: representation, assetSize: AssetSize(size: .medium)) { returnedImage = image }
            else if let image = self.image(for: representation, assetSize: AssetSize(size: .large)) { returnedImage = image }
            
        case .medium:
            // First, attempt to load a medium image
            if let image = self.image(for: representation, assetSize: AssetSize(size: .medium)) { returnedImage = image }
                
                // If a medium image doesn't exist, fallback to trying to load a medium resizable image
            else if let image = self.image(for: representation, assetSize: AssetSize(size: .medium, resizable: true)) { returnedImage = image }
                
                // If neither medium nor resizable exists, check for a large image (because downscaling large is better than upscaling small)
            else if let image = self.image(for: representation, assetSize: AssetSize(size: .large)) { returnedImage = image }
                
                // If still no images exist, finally check the small image size
            else if let image = self.image(for: representation, assetSize: AssetSize(size: .small)) { returnedImage = image }
            
        case .large:
            if let image = self.image(for: representation, assetSize: AssetSize(size: .large)) { returnedImage = image }
            else if let image = self.image(for: representation, assetSize: AssetSize(size: .large, resizable: true)) { returnedImage = image }
            else if let image = self.image(for: representation, assetSize: AssetSize(size: .medium)) { returnedImage = image }
            else if let image = self.image(for: representation, assetSize: AssetSize(size: .small)) { returnedImage = image }
            
        }
        
        if let image = returnedImage
        {
            self.imageCache.setObject(image, forKey: cacheKey as NSString)
        }
        
        return returnedImage
    }
    
    func inputs(for traits: Traits,  point: CGPoint) -> [Input]?
    {
        guard let representation = self.representations[traits], let core = Delta.core(for: self.gameType) else { return nil }
        
        var inputs: [Input] = []
        for item in representation.items
        {
            guard item.extendedFrame.contains(point) else { continue }
            
            for input in core.inputTransformer.inputs(for: self, item: item, point: point)
            {
                inputs.append(input)
            }
        }
        
        return inputs
    }
    
    func items(for traits: Traits) -> [Item]?
    {
        guard let representation = self.representations[traits] else { return nil }
        return representation.items
    }
    
    func isTranslucent(for traits: Traits) -> Bool?
    {
        guard let representation = self.representations[traits] else { return nil }
        return representation.isTranslucent
    }
    
    func gameScreenFrame(for traits: Traits) -> CGRect?
    {
        guard let representation = self.representations[traits] else { return nil }
        return representation.gameScreenFrame
    }
    
    public func aspectRatio(for traits: ControllerSkin.Traits) -> CGSize?
    {
        guard let representation = self.representations[traits] else { return nil }
        return representation.aspectRatio
    }
}

private extension ControllerSkin
{
    func image(for representation: Representation, assetSize: AssetSize) -> UIImage?
    {
        guard let filename = representation.assets[assetSize], let entry = self.archiveEntry(forFilename: filename) else { return nil }
        
        do
        {
            let data = try entry.newData()
            
            let image: UIImage?
            
            switch assetSize
            {
            case .small, .medium, .large:
                guard let imageScale = assetSize.imageScale(for: representation.traits) else { return nil }
                image = UIImage(data: data, scale: imageScale)
                
            case .resizable:
                guard let targetSize = assetSize.targetSize(for: representation.traits) else { return nil }
                image = UIImage.image(withPDFData: data, targetSize: targetSize)
            }
            
            return image
        }
        catch let error as NSError
        {
            print("\(error) \(error.userInfo)")
        }
        
        return nil
    }
    
    func archiveEntry(forFilename filename: String) -> ZZArchiveEntry?
    {
        guard
            let archive = try? ZZArchive(url: self.fileURL),
            let index = archive.entries.index(where: { $0.fileName == filename })
        else { return nil }
        
        let entry = archive.entries[index]
        return entry
    }
    
    func cacheKey(for traits: Traits, size: Size) -> String
    {
        return String(describing: traits) + "-" + String(describing: size)
    }
}

private extension ControllerSkin
{
    struct ExtendedEdges
    {
        var top: CGFloat?
        var bottom: CGFloat?
        var left: CGFloat?
        var right: CGFloat?
        
        init(dictionary: [String: CGFloat]?)
        {
            self.top = dictionary?["top"]
            self.bottom = dictionary?["bottom"]
            self.left = dictionary?["left"]
            self.right = dictionary?["right"]
        }
    }
    
    enum AssetSize: RawRepresentable, Hashable
    {
        case small
        case medium
        case large
        indirect case resizable(assetSize: AssetSize?)
        
        // If we're resizable, return our associated AssetSize
        // Otherwise, we just return self
        var unwrapped: AssetSize?
        {
            if case .resizable(let size) = self
            {
                if let size = size
                {
                    return size
                }
                else
                {
                    return nil
                }
            }
            else
            {
                return self
            }
        }
        
        /// Hashable
        var hashValue: Int {
            return self.rawValue.hashValue
        }
        
        /// RawRepresentable
        typealias RawValue = String
        
        var rawValue: String {
            switch self
            {
            case .small:     return "small"
            case .medium:    return "medium"
            case .large:     return "large"
            case .resizable: return "resizable"
            }
        }
        
        init?(rawValue: String)
        {
            switch rawValue
            {
            case "small":     self = .small
            case "medium":    self = .medium
            case "large":     self = .large
            case "resizable": self = .resizable(assetSize: nil)
            default:          return nil
            }
        }
        
        init(size: Size, resizable: Bool = false)
        {
            switch size
            {
            case .small:  self = .small
            case .medium: self = .medium
            case .large:  self = .large
            }
            
            if resizable
            {
                self = .resizable(assetSize: self)
            }
        }
        
        // Should always be used over the associated value for .resizable because it handles orientation
        func targetSize(for traits: ControllerSkin.Traits) -> CGSize?
        {
            guard let assetSize = self.unwrapped else { return nil }
            
            var targetSize: CGSize
            
            switch (traits.deviceType, assetSize)
            {
            case (.iphone, .small): targetSize = CGSize(width: 320, height: 568)
            case (.iphone, .medium): targetSize = CGSize(width: 375, height: 667)
            case (.iphone, .large): targetSize = CGSize(width: 414, height: 736)
                
            case (.ipad, .small): fallthrough
            case (.ipad, .medium): targetSize = CGSize(width: 768, height: 1024)
            case (.ipad, .large): targetSize = CGSize(width: 1024, height: 1366)
                
            case (_, .resizable): return nil
            }
            
            switch traits.orientation
            {
            case .portrait: break
            case .landscape: targetSize = CGSize(width: targetSize.height, height: targetSize.width)
            }
            
            return targetSize
        }
        
        func imageScale(for traits: ControllerSkin.Traits) -> CGFloat?
        {
            guard let assetSize = self.unwrapped else { return nil }
            
            switch (assetSize, traits.deviceType)
            {
            case (.small, _): return 2.0
            case (.medium, _): return 2.0
            case (.large, .ipad): return 2.0
            case (.large, .iphone): return 3.0
            case (.resizable, _): return nil
            }
        }
    }
    
    struct Representation: Hashable, CustomStringConvertible
    {
        let traits: Traits
        
        let assets: [AssetSize: String]
        let isTranslucent: Bool
        let gameScreenFrame: CGRect?
        let aspectRatio: CGSize
        
        let items: [Item]
        
        /// Hashable
        var hashValue: Int {
            return self.traits.hashValue
        }
        
        /// CustomStringConvertible
        var description: String {
            return self.traits.description
        }
        
        init?(traits: Traits, dictionary: [String: AnyObject])
        {
            guard
                let mappingSizeDictionary = dictionary["mappingSize"] as? [String: CGFloat], let mappingSize = CGSize(dictionary: mappingSizeDictionary),
                let itemsArray = dictionary["items"] as? [[String: AnyObject]],
                let assetsDictionary = dictionary["assets"] as? [String: String]
            else { return nil }
            
            self.aspectRatio = mappingSize
            
            self.traits = traits
            
            let extendedEdges = ExtendedEdges(dictionary: dictionary["extendedEdges"] as? [String: CGFloat])
            
            var items = [Item]()
            for dictionary in itemsArray
            {
                if let item = Item(dictionary: dictionary, extendedEdges: extendedEdges, mappingSize: mappingSize)
                {
                    items.append(item)
                }
            }
            self.items = items
            
            var assets = [AssetSize: String]()
            for (key, value) in assetsDictionary
            {
                if let size = AssetSize(rawValue: key)
                {
                    assets[size] = value
                }
            }
            self.assets = assets
            
            guard self.assets.count > 0 else { return nil }
            
            self.isTranslucent = dictionary["translucent"] as? Bool ?? false
            
            if
                let gameScreenFrameDictionary = dictionary["gameScreenFrame"] as? [String: CGFloat],
                let gameScreenFrame = CGRect(dictionary: gameScreenFrameDictionary)
            {
                let scaleTransform = CGAffineTransform(scaleX: 1.0 / mappingSize.width, y: 1.0 / mappingSize.height)
                self.gameScreenFrame = gameScreenFrame.applying(scaleTransform)
            }
            else
            {
                self.gameScreenFrame = nil
            }
        }
    }
}

private func ==(lhs: ControllerSkin.Representation, rhs: ControllerSkin.Representation) -> Bool
{
    return lhs.traits == rhs.traits
}
