//
//  ControllerView.swift
//  DeltaCore
//
//  Created by Riley Testut on 5/3/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import UIKit

public class ControllerView: UIView, GameController
{
    //MARK: - Properties -
    /** Properties **/
    public var controllerSkin: ControllerSkin? {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    public var controllerSkinTraits: ControllerSkin.Traits!
    {
        set { self.overrideTraits = newValue }
        get
        {
            if let traits = self.overrideTraits
            {
                return traits
            }
            
            // Use screen bounds because in split view window bounds might be portrait, but device is actually landscape (and we want landscape skin)
            let orientation: ControllerSkin.Orientation = (UIScreen.main.bounds.width > UIScreen.main.bounds.height) ? .landscape : .portrait
            
            // Use trait collection to determine device because our container app may be containing us in an "iPhone" trait collection despite being on iPad
            // 99% of the time, won't make a difference ¯\_(ツ)_/¯
            let deviceType: ControllerSkin.DeviceType = (self.traitCollection.userInterfaceIdiom == .pad) ? .ipad : .iphone
            
            var traits = ControllerSkin.Traits(deviceType: deviceType, displayMode: .fullScreen, orientation: orientation)
            
            if let window = self.window
            {
                if deviceType == .iphone || window.bounds.equalTo(UIScreen.main.bounds)
                {
                    traits.displayMode = .fullScreen
                }
                else
                {
                    traits.displayMode = .splitView
                }
            }
            
            return traits
        }
    }
    
    public var controllerSkinSize: ControllerSkin.Size!
    {
        set { self.overrideSize = newValue }
        get
        {
            let size = self.overrideSize ?? UIScreen.main.defaultControllerSkinSize
            return size
        }
    }
    
    //MARK: - <GameControllerType>
    /// <GameControllerType>
    public var playerIndex: Int?
    public var inputTransformationHandler: ((GameController, Input) -> [Input])?
    public let _stateManager = GameControllerStateManager()
    
    //MARK: - Private Properties
    private let imageView = UIImageView(frame: CGRect.zero)
    private var transitionImageView: UIImageView? = nil
    private let controllerDebugView = ControllerDebugView()
    
    private var overrideTraits: ControllerSkin.Traits?
    private var overrideSize: ControllerSkin.Size?
    
    private var _performedInitialLayout = false
    
    private var touchInputsMappingDictionary: [UITouch: Set<InputBox>] = [:]
    private var previousTouchInputs = Set<InputBox>()
    private var touchInputs: Set<InputBox> {
        return self.touchInputsMappingDictionary.values.reduce(Set<InputBox>(), { $0.union($1) })
    }
    
    //MARK: - Initializers -
    /** Initializers **/
    public override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        self.initialize()
    }
    
    public required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        self.initialize()
    }
    
    private func initialize()
    {
        self.backgroundColor = UIColor.clear
        
        self.imageView.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
        self.imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.imageView.contentMode = .scaleAspectFit
        self.addSubview(self.imageView)
        
        self.controllerDebugView.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
        self.controllerDebugView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(self.controllerDebugView)
        
        self.isMultipleTouchEnabled = true
    }
    
    //MARK: - Overrides -
    /** Overrides **/
    
    //MARK: - UIView
    /// UIView
    public override func intrinsicContentSize() -> CGSize
    {
        return self.imageView.intrinsicContentSize
    }
    
    public override func layoutSubviews()
    {
        super.layoutSubviews()
        
        self._performedInitialLayout = true
        
        self.updateControllerSkin()
    }
    
    //MARK: - UIResponder
    /// UIResponder
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        for touch in touches
        {
            self.touchInputsMappingDictionary[touch] = []
        }
        
        self.updateInputs(forTouches: touches)
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        self.updateInputs(forTouches: touches)
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        for touch in touches
        {
            self.touchInputsMappingDictionary[touch] = nil
        }
        
        self.updateInputs(forTouches: touches)
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        return self.touchesEnded(touches, with: event)
    }
    
    //MARK: - <UITraitEnvironment>
    /// <UITraitEnvironment>
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        super.traitCollectionDidChange(previousTraitCollection)
        
        self.setNeedsLayout()
    }
}

//MARK: - Update Skins -
/// Update Skins
public extension ControllerView
{
    func beginAnimatingUpdateControllerSkin()
    {
        guard self.transitionImageView == nil else { return }
        
        let transitionImageView = UIImageView(image: self.imageView.image)
        transitionImageView.frame = self.imageView.frame
        transitionImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        transitionImageView.contentMode = .scaleAspectFit
        transitionImageView.alpha = 1.0
        self.addSubview(transitionImageView)
        
        self.transitionImageView = transitionImageView
        
        self.imageView.alpha = 0.0
    }
    
    func updateControllerSkin()
    {
        guard self._performedInitialLayout else { return }
        
        if let debugModeEnabled = self.controllerSkin?.debugModeEnabled
        {
            self.controllerDebugView.isHidden = !debugModeEnabled
        }
        
        self.controllerDebugView.items = self.controllerSkin?.items(for: self.controllerSkinTraits)
        
        let image = self.controllerSkin?.image(for: self.controllerSkinTraits, preferredSize: self.controllerSkinSize)
        self.imageView.image = image
        
        self.invalidateIntrinsicContentSize()
        
        if self.transitionImageView != nil
        {
            // Wrap in an animation closure to ensure it actually animates correctly
            // As of iOS 8.3, calling this within transition coordinator animation closure without wrapping
            // in this animation closure causes the change to be instantaneous
            UIView.animate(withDuration: 0.0) {
                self.imageView.alpha = 1.0
            }
        }
        else
        {
            self.imageView.alpha = 1.0
        }
        
        self.transitionImageView?.alpha = 0.0
    }
    
    func finishAnimatingUpdateControllerSkin()
    {
        if let transitionImageView = self.transitionImageView
        {
            transitionImageView.removeFromSuperview()
            self.transitionImageView = nil
        }
        
        self.imageView.alpha = 1.0
    }
}

//MARK: - Private Methods -
private extension ControllerView
{
    //MARK: - Activating/Deactivating Inputs
    func updateInputs(forTouches touches: Set<UITouch>)
    {
        guard let controllerSkin = self.controllerSkin else { return }
        
        // Don't add the touches if it has been removed in touchesEnded:/touchesCancelled:
        for touch in touches where self.touchInputsMappingDictionary[touch] != nil
        {
            var point = touch.location(in: self)
            point.x /= self.bounds.width
            point.y /= self.bounds.height
            
            let inputs = controllerSkin.inputs(for: self.controllerSkinTraits, point: point) ?? []
            let boxedInputs = inputs.lazy.flatMap { self.inputTransformationHandler?(self, $0) ?? [$0] }.map { InputBox(input: $0) }
            
            self.touchInputsMappingDictionary[touch] = Set(boxedInputs)
        }
        
        let activatedInputs = self.touchInputs.subtracting(self.previousTouchInputs)
        for inputBox in activatedInputs
        {
            self.activate(inputBox.input)
        }
        
        let deactivatedInputs = self.previousTouchInputs.subtracting(self.touchInputs)
        for inputBox in deactivatedInputs
        {
            self.deactivate(inputBox.input)
        }
        
        self.previousTouchInputs = self.touchInputs
    }
}
