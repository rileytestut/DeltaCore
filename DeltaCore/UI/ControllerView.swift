//
//  ControllerView.swift
//  DeltaCore
//
//  Created by Riley Testut on 5/3/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import UIKit

private struct ControllerViewInputMapping: GameControllerInputMappingProtocol
{
    let controllerView: ControllerView
    
    var name: String {
        return self.controllerView.name
    }
    
    var gameControllerInputType: GameControllerInputType {
        return self.controllerView.inputType
    }
    
    func input(forControllerInput controllerInput: Input) -> Input?
    {
        guard let gameType = self.controllerView.controllerSkin?.gameType, let deltaCore = Delta.core(for: gameType) else { return nil }
        
        if let gameInput = deltaCore.gameInputType.init(stringValue: controllerInput.stringValue)
        {
            return gameInput
        }
        
        if let standardInput = StandardGameControllerInput(stringValue: controllerInput.stringValue)
        {
            return standardInput
        }
        
        return nil
    }
}

public class ControllerView: UIView, GameController
{
    //MARK: - Properties -
    /** Properties **/
    public var controllerSkin: ControllerSkinProtocol? {
        didSet {
            self.updateControllerSkin()
        }
    }
    
    public var controllerSkinTraits: ControllerSkin.Traits? {
        if let traits = self.overrideControllerSkinTraits
        {
            return traits
        }
        
        guard let window = self.window else { return nil }
        
        let traits = ControllerSkin.Traits.defaults(for: window)
        
        guard let controllerSkin = self.controllerSkin else { return traits }
        
        guard let supportedTraits = controllerSkin.supportedTraits(for: traits) else { return traits }
        return supportedTraits
    }

    public var controllerSkinSize: ControllerSkin.Size! {
        let size = self.overrideControllerSkinSize ?? UIScreen.main.defaultControllerSkinSize
        return size
    }
    
    public var overrideControllerSkinTraits: ControllerSkin.Traits?
    public var overrideControllerSkinSize: ControllerSkin.Size?
    
    public var translucentControllerSkinOpacity: CGFloat = 0.7
    
    //MARK: - <GameControllerType>
    /// <GameControllerType>
    public var name: String {
        return self.controllerSkin?.name ?? NSLocalizedString("Game Controller", comment: "")
    }
    
    public var playerIndex: Int? {
        didSet {
            self.reloadInputViews()
        }
    }
    
    public let inputType: GameControllerInputType = .controllerSkin
    
    public lazy var defaultInputMapping: GameControllerInputMappingProtocol? = ControllerViewInputMapping(controllerView: self)
    
    internal var isControllerInputView = false
    
    //MARK: - Private Properties
    private let imageView = UIImageView(frame: CGRect.zero)
    private var transitionImageView: UIImageView? = nil
    private let controllerDebugView = ControllerDebugView()
    
    private var feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    private var _performedInitialLayout = false
    
    private var touchInputsMappingDictionary: [UITouch: Set<AnyInput>] = [:]
    private var previousTouchInputs = Set<AnyInput>()
    private var touchInputs: Set<AnyInput> {
        return self.touchInputsMappingDictionary.values.reduce(Set<AnyInput>(), { $0.union($1) })
    }
    
    private var controllerInputView: ControllerInputView?
    
    // Becoming first responder doesn't steal keyboard focus from other apps in split view unless the first responder is a text control.
    // As a workaround, we first make a hidden text field become first responder to steal focus, then become first responder ourselves.
    private let forceFirstResponderTextField = UITextField(frame: .zero)
    
    public override var intrinsicContentSize: CGSize {
        return self.imageView.intrinsicContentSize
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
        self.addSubview(self.imageView)
        
        self.controllerDebugView.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
        self.controllerDebugView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(self.controllerDebugView)
        
        self.isMultipleTouchEnabled = true
        
        self.feedbackGenerator.prepare()
        
        self.forceFirstResponderTextField.isHidden = true
        self.forceFirstResponderTextField.autocorrectionType = .no
        self.forceFirstResponderTextField.inputView = UIView(frame: .zero)
        self.forceFirstResponderTextField.inputAssistantItem.leadingBarButtonGroups = []
        self.forceFirstResponderTextField.inputAssistantItem.trailingBarButtonGroups = []
        self.addSubview(self.forceFirstResponderTextField)
    }
    
    //MARK: - UIView
    /// UIView
    public override func layoutSubviews()
    {
        super.layoutSubviews()
        
        self._performedInitialLayout = true
        
        self.updateControllerSkin()
    }
    
    //MARK: - <UITraitEnvironment>
    /// <UITraitEnvironment>
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        super.traitCollectionDidChange(previousTraitCollection)
        
        self.setNeedsLayout()
    }
}

//MARK: - UIResponder -
/// UIResponder
extension ControllerView
{
    public override var canBecomeFirstResponder: Bool {
        return true
    }
    
    public override var next: UIResponder? {
        return KeyboardResponder(nextResponder: super.next)
    }
    
    public override var inputView: UIView? {
        guard self.playerIndex != nil else { return nil }
        
        return self.controllerInputView
    }
    
    @discardableResult public override func becomeFirstResponder() -> Bool
    {
        guard self.forceFirstResponderTextField.becomeFirstResponder() else { return false }
        
        super.becomeFirstResponder()
        
        self.reloadInputViews()
        
        return self.isFirstResponder
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        for touch in touches
        {
            self.touchInputsMappingDictionary[touch] = []
        }
        
        self.updateInputs(for: touches)
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        self.updateInputs(for: touches)
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        for touch in touches
        {
            self.touchInputsMappingDictionary[touch] = nil
        }
        
        self.updateInputs(for: touches)
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        return self.touchesEnded(touches, with: event)
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
        transitionImageView.alpha = self.imageView.alpha
        self.addSubview(transitionImageView)
        
        self.transitionImageView = transitionImageView
        
        self.imageView.alpha = 0.0
    }
    
    func updateControllerSkin()
    {
        guard self._performedInitialLayout else { return }
        
        if let isDebugModeEnabled = self.controllerSkin?.isDebugModeEnabled
        {
            self.controllerDebugView.isHidden = !isDebugModeEnabled
        }
        
        var isTranslucent = false
        
        if let traits = self.controllerSkinTraits
        {
            let items = self.controllerSkin?.items(for: traits)
            self.controllerDebugView.items = items
            
            if traits.displayType == .splitView && !self.isControllerInputView
            {
                self.imageView.image = nil
                
                self.isUserInteractionEnabled = false
                self.controllerDebugView.alpha = 0.0
            }
            else
            {
                let image = self.controllerSkin?.image(for: traits, preferredSize: self.controllerSkinSize)
                self.imageView.image = image
                
                self.isUserInteractionEnabled = true
                self.controllerDebugView.alpha = 1.0
            }
            
            isTranslucent = self.controllerSkin?.isTranslucent(for: traits) ?? false
        }
        
        if self.transitionImageView != nil
        {
            // Wrap in an animation closure to ensure it actually animates correctly
            // As of iOS 8.3, calling this within transition coordinator animation closure without wrapping
            // in this animation closure causes the change to be instantaneous
            UIView.animate(withDuration: 0.0) {
                self.imageView.alpha = isTranslucent ? self.translucentControllerSkinOpacity : 1.0
            }
        }
        else
        {
            self.imageView.alpha = isTranslucent ? self.translucentControllerSkinOpacity : 1.0
        }
        
        self.transitionImageView?.alpha = 0.0
        
        if self.controllerSkinTraits?.displayType == .splitView
        {
            self.presentInputControllerView()
        }
        else
        {
            self.dismissInputControllerView()
        }
        
        self.controllerInputView?.controllerView.overrideControllerSkinTraits = self.controllerSkinTraits
        
        self.invalidateIntrinsicContentSize()
        self.setNeedsUpdateConstraints()
        
        self.reloadInputViews()
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

private extension ControllerView
{
    func presentInputControllerView()
    {
        guard !self.isControllerInputView else { return }

        guard let controllerSkin = self.controllerSkin, let traits = self.controllerSkinTraits else { return }

        if self.controllerInputView == nil
        {
            let inputControllerView = ControllerInputView(frame: CGRect(x: 0, y: 0, width: 1024, height: 300))
            inputControllerView.controllerView.addReceiver(self, inputMapping: nil)
            self.controllerInputView = inputControllerView
        }

        if controllerSkin.supports(traits)
        {
            self.controllerInputView?.controllerView.controllerSkin = controllerSkin
        }
        else
        {
            self.controllerInputView?.controllerView.controllerSkin = ControllerSkin.standardControllerSkin(for: controllerSkin.gameType)
        }
    }
    
    func dismissInputControllerView()
    {
        guard !self.isControllerInputView else { return }
        
        guard self.controllerInputView != nil else { return }
        
        self.controllerInputView = nil
    }
}

//MARK: - Activating/Deactivating Inputs -
/// Activating/Deactivating Inputs
private extension ControllerView
{
    func updateInputs(for touches: Set<UITouch>)
    {
        guard let controllerSkin = self.controllerSkin else { return }
        
        // Don't add the touches if it has been removed in touchesEnded:/touchesCancelled:
        for touch in touches where self.touchInputsMappingDictionary[touch] != nil
        {
            var point = touch.location(in: self)
            point.x /= self.bounds.width
            point.y /= self.bounds.height
            
            if let traits = self.controllerSkinTraits
            {
                let inputs = (controllerSkin.inputs(for: traits, at: point) ?? []).map { AnyInput($0) }
                self.touchInputsMappingDictionary[touch] = Set(inputs)
            }
        }
        
        let activatedInputs = self.touchInputs.subtracting(self.previousTouchInputs)
        let deactivatedInputs = self.previousTouchInputs.subtracting(self.touchInputs)
        
        // We must update previousTouchInputs *before* calling activate() and deactivate().
        // Otherwise, race conditions that cause duplicate touches from activate() or deactivate() calls can result in various bugs.
        self.previousTouchInputs = self.touchInputs
        
        for input in activatedInputs
        {
            self.activate(input)
        }
        
        for input in deactivatedInputs
        {
            self.deactivate(input)
        }
        
        if activatedInputs.count > 0
        {
            switch UIDevice.current.feedbackSupportLevel
            {
            case .feedbackGenerator: self.feedbackGenerator.impactOccurred()
            case .basic, .unsupported: UIDevice.current.vibrate()
            }
        }
    }
}

//MARK: - GameControllerReceiver -
/// GameControllerReceiver
extension ControllerView: GameControllerReceiver
{
    public func gameController(_ gameController: GameController, didActivate input: Input)
    {
        guard gameController == self.controllerInputView?.controllerView else { return }
        
        self.activate(input)
    }
    
    public func gameController(_ gameController: GameController, didDeactivate input: Input)
    {
        guard gameController == self.controllerInputView?.controllerView else { return }
        
        self.deactivate(input)
    }
}
