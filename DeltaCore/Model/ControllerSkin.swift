//
//  ControllerSkin.swift
//  DeltaCore
//
//  Created by Riley Testut on 5/5/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit

#if FRAMEWORK
import ZIPFoundation
#endif

public let kUTTypeDeltaControllerSkin: CFString = "com.rileytestut.delta.skin" as CFString

private typealias RepresentationDictionary = [String: [String: AnyObject]]

public extension GameControllerInputType
{
    static let controllerSkin = GameControllerInputType("controllerSkin")
}

extension ControllerSkin
{
    public struct Item
    {
        public enum Inputs
        {
            case standard([Input])
            case directional(up: Input, down: Input, left: Input, right: Input)
            
            public var allInputs: [Input] {
                switch self
                {
                case .standard(let inputs): return inputs
                case let .directional(up, down, left, right): return [up, down, left, right]
                }
            }
        }
        
        public let inputs: Inputs
        
        public let frame: CGRect
        public let extendedFrame: CGRect
        
        fileprivate init?(dictionary: [String: AnyObject], extendedEdges: ExtendedEdges, mappingSize: CGSize)
        {
            guard
                let frameDictionary = dictionary["frame"] as? [String: CGFloat], let frame = CGRect(dictionary: frameDictionary)
            else { return nil }
            
            if let inputs = dictionary["inputs"] as? [String]
            {
                self.inputs = .standard(inputs.map { AnyInput(stringValue: $0, intValue: nil, type: .controller(.controllerSkin)) })
            }
            else if let inputs = dictionary["inputs"] as? [String: String]
            {
                if let up = inputs["up"], let down = inputs["down"], let left = inputs["left"], let right = inputs["right"]
                {
                    self.inputs = .directional(up: AnyInput(stringValue: up, intValue: nil, type: .controller(.controllerSkin)),
                                               down: AnyInput(stringValue: down, intValue: nil, type: .controller(.controllerSkin)),
                                               left: AnyInput(stringValue: left, intValue: nil, type: .controller(.controllerSkin)),
                                               right: AnyInput(stringValue: right, intValue: nil, type: .controller(.controllerSkin)))
                }
                else
                {
                    return nil
                }
            }
            else
            {
                return nil
            }
            
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

private extension Archive
{
    func extract(_ entry: Entry) throws -> Data
    {
        var data = Data()
        _ = try self.extract(entry) { data.append($0) }
        
        return data
    }
}

public struct ControllerSkin: ControllerSkinProtocol
{
    public let name: String
    public let identifier: String
    public let gameType: GameType
    public let isDebugModeEnabled: Bool
    
    public let fileURL: URL
    
    private let representations: [Traits: Representation]
    private let imageCache = NSCache<NSString, UIImage>()
    
    private let archive: Archive
    
    public init?(fileURL: URL)
    {
        self.fileURL = fileURL
        
        guard let archive = Archive(url: fileURL, accessMode: .read) else { return nil }
        self.archive = archive
        
        guard let infoEntry = archive["info.json"] else { return nil }
        
        do
        {
            let infoData = try archive.extract(infoEntry)
            
            guard let info = try JSONSerialization.jsonObject(with: infoData) as? [String: AnyObject] else { return nil }
            
            guard
                let name = info["name"] as? String,
                let identifier = info["identifier"] as? String,
                let isDebugModeEnabled = info["debug"] as? Bool,
                let representationsDictionary = info["representations"] as? RepresentationDictionary
            else { return nil }
            
            #if FRAMEWORK
            guard let gameType = info["gameTypeIdentifier"] as? GameType else { return nil }
            #else
            guard let gameTypeString = info["gameTypeIdentifier"] as? String else { return nil }
            let gameType = GameType(gameTypeString)
            #endif
            
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
        catch let error as NSError
        {
            print("\(error) \(error.userInfo)")
            
            return nil
        }
    }
    
    // Sometimes, recursion really is the best solution ¯\_(ツ)_/¯
    private static func parsedRepresentations(from representationsDictionary: RepresentationDictionary, device: Device? = nil, displayType: DisplayType? = nil, orientation: Orientation? = nil) -> Set<Representation>
    {
        var representations = Set<Representation>()
        
        for (key, dictionary) in representationsDictionary
        {
            if device == nil
            {
                guard let device = Device(rawValue: key), let dictionary = dictionary as? RepresentationDictionary else { continue }
                
                representations.formUnion(self.parsedRepresentations(from: dictionary, device: device))
            }
            else if displayType == nil
            {
                if let displayType = DisplayType(rawValue: key), let dictionary = dictionary as? RepresentationDictionary
                {
                    representations.formUnion(self.parsedRepresentations(from: dictionary, device: device, displayType: displayType))
                }
                else
                {
                    // Key doesn't exist, so we continue with the same dictionary we're currently iterating, but pass in .standard for displayMode
                    representations.formUnion(self.parsedRepresentations(from: representationsDictionary, device: device, displayType: .standard))
                    
                    // Return early to prevent us from repeating the above step multiple times
                    return representations
                }
            }
            else if orientation == nil
            {
                guard
                    let device = device,
                    let displayType = displayType,
                    let orientation = Orientation(rawValue: key)
                else { continue }
                
                let traits = Traits(device: device, displayType: displayType, orientation: orientation)
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
            let fileURL = deltaCore.bundle.url(forResource: "Standard", withExtension: "deltaskin")
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
    
    func inputs(for traits: Traits, at point: CGPoint) -> [Input]?
    {
        guard let representation = self.representations[traits] else { return nil }
        
        var inputs: [Input] = []
        
        for item in representation.items
        {
            guard item.extendedFrame.contains(point) else { continue }
            
            switch item.inputs
            {
            case .standard(let itemInputs): inputs.append(contentsOf: itemInputs)
            case let .directional(up, down, left, right):
                let topRect = CGRect(x: item.extendedFrame.minX, y: item.extendedFrame.minY, width: item.extendedFrame.width, height: (item.frame.height / 3.0) + (item.frame.minY - item.extendedFrame.minY))
                let bottomRect = CGRect(x: item.extendedFrame.minX, y: item.frame.maxY - item.frame.height / 3.0, width: item.extendedFrame.width, height: (item.frame.height / 3.0) + (item.extendedFrame.maxY - item.frame.maxY))
                let leftRect = CGRect(x: item.extendedFrame.minX, y: item.extendedFrame.minY, width: (item.frame.width / 3.0) + (item.frame.minX - item.extendedFrame.minX), height: item.extendedFrame.height)
                let rightRect = CGRect(x: item.frame.maxX - item.frame.width / 3.0, y: item.extendedFrame.minY, width: (item.frame.width / 3.0) + (item.extendedFrame.maxX - item.frame.maxX), height: item.extendedFrame.height)
                
                if topRect.contains(point)
                {
                    inputs.append(up)
                }
                
                if bottomRect.contains(point)
                {
                    inputs.append(down)
                }
                
                if leftRect.contains(point)
                {
                    inputs.append(left)
                }
                
                if rightRect.contains(point)
                {
                    inputs.append(right)
                }
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
    
    func aspectRatio(for traits: ControllerSkin.Traits) -> CGSize?
    {
        guard let representation = self.representations[traits] else { return nil }
        return representation.aspectRatio
    }
}

private extension ControllerSkin
{
    func image(for representation: Representation, assetSize: AssetSize) -> UIImage?
    {
        guard let filename = representation.assets[assetSize], let entry = self.archive[filename] else { return nil }
        
        do
        {
            let data = try self.archive.extract(entry)
            
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
        catch
        {
            print(error)
            
            return nil
        }
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
            
            switch (traits.device, traits.displayType, assetSize)
            {
            case (.iphone, .standard, .small): targetSize = CGSize(width: 320, height: 568)
            case (.iphone, .standard, .medium): targetSize = CGSize(width: 375, height: 667)
            case (.iphone, .standard, .large): targetSize = CGSize(width: 414, height: 736)
                
            case (.iphone, .edgeToEdge, _): targetSize = CGSize(width: 375, height: 812)
            case (.iphone, .splitView, _): return nil
                
            case (.ipad, _,  .small): targetSize = CGSize(width: 768, height: 1024)
            case (.ipad, _, .medium): targetSize = CGSize(width: 834, height: 1112)
            case (.ipad, _, .large): targetSize = CGSize(width: 1024, height: 1366)
                
            case (_, _, .resizable): return nil
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
            
            switch (traits.device, traits.displayType, assetSize)
            {
            case (.iphone, .standard, .small): return 2.0
            case (.iphone, .standard, .medium): return 2.0
            case (.iphone, .standard, .large): return 3.0
                
            case (.iphone, .edgeToEdge, _): return 3.0
            case (.iphone, .splitView, _): return nil
                
            case (.ipad, .standard, _): return 2.0
            case (.ipad, .edgeToEdge, _): return nil
            case (.ipad, .splitView, _): return 2.0
                
            case (_, _, .resizable): return nil
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
