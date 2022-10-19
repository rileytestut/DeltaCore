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

extension ControllerView
{
    public static let controllerViewDidChangeControllerSkinNotification = Notification.Name("controllerViewDidChangeControllerSkinNotification")
    public static let controllerViewDidUpdateGameViewsNotification = Notification.Name("controllerViewDidUpdateGameViewsNotification")
    
    public enum NotificationKey: String
    {
        case addedGameViews
        case removedGameViews
    }
}

public class ControllerView: UIView, GameController
{
    //MARK: - Properties -
    /** Properties **/
    public var controllerSkin: ControllerSkinProtocol? {
        didSet {
            self.updateControllerSkin()
            NotificationCenter.default.post(name: ControllerView.controllerViewDidChangeControllerSkinNotification, object: self)
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
    
    public var isButtonHapticFeedbackEnabled = true {
        didSet {
            self.buttonsView.isHapticFeedbackEnabled = self.isButtonHapticFeedbackEnabled
        }
    }
    
    public var isThumbstickHapticFeedbackEnabled = true {
        didSet {
            self.thumbstickViews.values.forEach { $0.isHapticFeedbackEnabled = self.isThumbstickHapticFeedbackEnabled }
        }
    }
    
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
    
    internal weak var appPlacementLayoutGuide: UILayoutGuide? {
        didSet {
            self.controllerDebugView.appPlacementLayoutGuide = self.appPlacementLayoutGuide
        }
    }
    
    internal var isControllerInputView = false
    internal var gameViews: [GameView] {
        var sortedGameViews = self.gameViewsByScreenID.lazy.sorted { $0.key < $1.key }.map { $0.value }
        
        if let controllerView = self.controllerInputView?.controllerView
        {
            // Include controllerInputView's gameViews, if there are any.
            let gameViews = controllerView.gameViews
            sortedGameViews.append(contentsOf: gameViews)
        }
        
        return sortedGameViews
    }
    private var gameViewsByScreenID = [ControllerSkin.Screen.ID: GameView]()
    
    //MARK: - Private Properties
    private let contentView = UIView(frame: .zero)
    private var transitionSnapshotView: UIView? = nil
    private let controllerDebugView = ControllerDebugView()
    
    private let buttonsView = ButtonsInputView(frame: CGRect.zero)
    private var thumbstickViews = [ControllerSkin.Item.ID: ThumbstickInputView]()
    private var touchViews = [ControllerSkin.Item.ID: TouchInputView]()
    
    private var _performedInitialLayout = false
    private var _delayedUpdatingControllerSkin = false
    
    private var controllerInputView: ControllerInputView?
    
    private(set) var imageCache = NSCache<NSString, NSCache<NSString, UIImage>>()
    
    public override var intrinsicContentSize: CGSize {
        return self.buttonsView.intrinsicContentSize
    }
    
    private let keyboardResponder = KeyboardResponder(nextResponder: nil)
    
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
        
        self.contentView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.contentView)
        
        self.buttonsView.translatesAutoresizingMaskIntoConstraints = false
        self.buttonsView.activateInputsHandler = { [weak self] (inputs) in
            self?.activateButtonInputs(inputs)
        }
        self.buttonsView.deactivateInputsHandler = { [weak self] (inputs) in
            self?.deactivateButtonInputs(inputs)
        }
        self.contentView.addSubview(self.buttonsView)
        
        self.controllerDebugView.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(self.controllerDebugView)
        
        self.isMultipleTouchEnabled = true
        
        // Remove shortcuts from shortcuts bar so it doesn't appear when using external keyboard as input.
        self.inputAssistantItem.leadingBarButtonGroups = []
        self.inputAssistantItem.trailingBarButtonGroups = []
        
        NotificationCenter.default.addObserver(self, selector: #selector(ControllerView.keyboardDidDisconnect(_:)), name: .externalKeyboardDidDisconnect, object: nil)
        
        NSLayoutConstraint.activate([self.contentView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                                     self.contentView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                                     self.contentView.topAnchor.constraint(equalTo: self.topAnchor),
                                     self.contentView.bottomAnchor.constraint(equalTo: self.bottomAnchor)])
        
        NSLayoutConstraint.activate([self.buttonsView.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor),
                                     self.buttonsView.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor),
                                     self.buttonsView.topAnchor.constraint(equalTo: self.contentView.topAnchor),
                                     self.buttonsView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor)])
        
        NSLayoutConstraint.activate([self.controllerDebugView.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor),
                                     self.controllerDebugView.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor),
                                     self.controllerDebugView.topAnchor.constraint(equalTo: self.contentView.topAnchor),
                                     self.controllerDebugView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor)])
    }
    
    //MARK: - UIView
    /// UIView
    public override func layoutSubviews()
    {
        self.controllerDebugView.setNeedsLayout()
        
        super.layoutSubviews()
        
        _performedInitialLayout = true
        
        guard !_delayedUpdatingControllerSkin else {
            _delayedUpdatingControllerSkin = false
            self.updateControllerSkin()
            return
        }
        
        // updateControllerSkin() calls layoutSubviews(), so don't call again to avoid infinite loop.
        // self.updateControllerSkin()
        
        guard let traits = self.controllerSkinTraits, let controllerSkin = self.controllerSkin, let items = controllerSkin.items(for: traits) else { return }
        
        for item in items
        {
            var containingFrame = self.bounds
            if let layoutGuide = self.appPlacementLayoutGuide, item.placement == .app
            {
                containingFrame = layoutGuide.layoutFrame
            }
            
            let frame = item.frame.scaled(to: containingFrame)
            
            switch item.kind
            {
            case .button, .dPad: break
            case .thumbstick:
                guard let thumbstickView = self.thumbstickViews[item.id] else { continue }
                thumbstickView.frame = frame
                
            case .touchScreen:
                guard let touchView = self.touchViews[item.id] else { continue }
                touchView.frame = frame
            }
        }
        
        if let screens = controllerSkin.screens(for: traits)
        {
            for screen in screens where screen.placement == .controller
            {
                guard let normalizedFrame = screen.outputFrame, let gameView = self.gameViewsByScreenID[screen.id] else { continue }
                
                let frame = normalizedFrame.scaled(to: self.bounds)
                gameView.frame = frame
            }
        }
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView?
    {
        guard self.bounds.contains(point) else { return super.hitTest(point, with: event) }
        
        for (_, thumbstickView) in self.thumbstickViews
        {
            guard thumbstickView.frame.contains(point) else { continue }
            return thumbstickView
        }

        for (_, touchView) in self.touchViews
        {
            guard touchView.frame.contains(point) else { continue }

            if let inputs = self.buttonsView.inputs(at: point)
            {
                // No other inputs at this position, so return touchView.
                if inputs.isEmpty
                {
                    return touchView
                }
            }
        }
        
        return self.buttonsView
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
        // "canBecomeFirstResponder" = "should display keyboard controller view" OR "should receive hardware keyboard events"
        // In latter case, we return a nil inputView to prevent software keyboard from appearing.
        
        guard let controllerSkin = self.controllerSkin, let traits = self.controllerSkinTraits else { return false }
        
        if let keyboardController = ExternalGameControllerManager.shared.keyboardController, keyboardController.playerIndex != nil
        {
            // Keyboard is connected and has non-nil player index, so return true to receive keyboard presses.
            return true
        }
        
        guard !(controllerSkin is TouchControllerSkin) else {
            // Unless keyboard is connected, we never want to become first responder with
            // TouchControllerSkin because that will make the software keyboard appear.
            return false
        }
        
        guard self.playerIndex != nil else {
            // Only show keyboard controller if we've been assigned a playerIndex.
            return false
        }
        
        // Finally, only show keyboard controller if we're in Split View and the controller skin supports it.
        let canBecomeFirstResponder = traits.displayType == .splitView && controllerSkin.supports(traits)
        return canBecomeFirstResponder
    }
    
    public override var next: UIResponder? {
        if #available(iOS 15, *)
        {
            return super.next
        }
        else
        {
            return KeyboardResponder(nextResponder: super.next)
        }
    }
    
    public override var inputView: UIView? {
        if let keyboardController = ExternalGameControllerManager.shared.keyboardController, keyboardController.playerIndex != nil
        {
            // Don't display any inputView if keyboard is connected and has non-nil player index.
            return nil
        }
        
        return self.controllerInputView
    }
    
    @discardableResult public override func becomeFirstResponder() -> Bool
    {
        guard super.becomeFirstResponder() else { return false }
        
        self.reloadInputViews()
        
        return self.isFirstResponder
    }
    
    internal override func _keyCommand(for event: UIEvent, target: UnsafeMutablePointer<UIResponder>) -> UIKeyCommand?
    {
        let keyCommand = super._keyCommand(for: event, target: target)
        
        if #available(iOS 15, *)
        {
            _ = self.keyboardResponder._keyCommand(for: event, target: target)
        }
        
        return keyCommand
    }
}

//MARK: - Update Skins -
/// Update Skins
public extension ControllerView
{
    func beginAnimatingUpdateControllerSkin()
    {
        guard self.transitionSnapshotView == nil else { return }
        
        guard let transitionSnapshotView = self.contentView.snapshotView(afterScreenUpdates: false) else { return }
        transitionSnapshotView.frame = self.contentView.frame
        transitionSnapshotView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        transitionSnapshotView.alpha = self.contentView.alpha
        self.addSubview(transitionSnapshotView)
        
        self.transitionSnapshotView = transitionSnapshotView
        
        self.contentView.alpha = 0.0
    }
    
    func updateControllerSkin()
    {
        guard _performedInitialLayout else {
            _delayedUpdatingControllerSkin = true
            return
        }

        if let isDebugModeEnabled = self.controllerSkin?.isDebugModeEnabled
        {
            self.controllerDebugView.isHidden = !isDebugModeEnabled
        }
        
        var isTranslucent = false
        
        if let traits = self.controllerSkinTraits
        {
            var items = self.controllerSkin?.items(for: traits)
       
            if traits.displayType == .splitView
            {
                if self.isControllerInputView
                {
                    // Filter out all items without `controller` placement.
                    items = items?.filter { $0.placement == .controller }
                }
                else
                {
                    // Filter out all items without `app` placement.
                    items = items?.filter { $0.placement == .app }
                }
            }
            
            if traits.displayType == .splitView && !self.isControllerInputView
            {
                self.buttonsView.image = nil
            }
            else
            {
                let image: UIImage?
                
                if let controllerSkin = self.controllerSkin
                {
                    let cacheKey = String(describing: traits) + "-" + String(describing: self.controllerSkinSize)
                    
                    if
                        let cache = self.imageCache.object(forKey: controllerSkin.identifier as NSString),
                        let cachedImage = cache.object(forKey: cacheKey as NSString)
                    {
                        image = cachedImage
                    }
                    else
                    {
                        image = controllerSkin.image(for: traits, preferredSize: self.controllerSkinSize)
                    }
                    
                    if let image = image
                    {
                        let cache = self.imageCache.object(forKey: controllerSkin.identifier as NSString) ?? NSCache<NSString, UIImage>()
                        cache.setObject(image, forKey: cacheKey as NSString)
                        self.imageCache.setObject(cache, forKey: controllerSkin.identifier as NSString)
                    }
                }
                else
                {
                    image = nil
                }
                
                self.buttonsView.image = image
            }
            
            self.buttonsView.items = items
            self.controllerDebugView.items = items
            
            isTranslucent = self.controllerSkin?.isTranslucent(for: traits) ?? false
            
            var thumbstickViews = [ControllerSkin.Item.ID: ThumbstickInputView]()
            var previousThumbstickViews = self.thumbstickViews
            
            var touchViews = [ControllerSkin.Item.ID: TouchInputView]()
            var previousTouchViews = self.touchViews
            
            for item in items ?? []
            {
                switch item.kind
                {
                case .button, .dPad: break
                case .thumbstick:
                    let thumbstickView: ThumbstickInputView
                    
                    if let previousThumbstickView = previousThumbstickViews[item.id]
                    {
                        thumbstickView = previousThumbstickView
                        previousThumbstickViews[item.id] = nil
                    }
                    else
                    {
                        thumbstickView = ThumbstickInputView(frame: .zero)
                        self.contentView.addSubview(thumbstickView)
                    }
                    
                    thumbstickView.valueChangedHandler = { [weak self] (xAxis, yAxis) in
                        self?.updateThumbstickValues(item: item, xAxis: xAxis, yAxis: yAxis)
                    }
                    
                    if let (image, size) = self.controllerSkin?.thumbstick(for: item, traits: traits, preferredSize: self.controllerSkinSize)
                    {
                        let size = CGSize(width: size.width * self.bounds.width, height: size.height * self.bounds.height)
                        thumbstickView.thumbstickImage = image
                        thumbstickView.thumbstickSize = size
                    }
                    
                    thumbstickView.isHapticFeedbackEnabled = self.isThumbstickHapticFeedbackEnabled
                    
                    thumbstickViews[item.id] = thumbstickView
                    
                case .touchScreen:
                    let touchView: TouchInputView
                    
                    if let previousTouchView = previousTouchViews[item.id]
                    {
                        touchView = previousTouchView
                        previousTouchViews[item.id] = nil
                    }
                    else
                    {
                        touchView = TouchInputView(frame: .zero)
                        self.contentView.addSubview(touchView)
                    }
                    
                    touchView.valueChangedHandler = { [weak self] (point) in
                        self?.updateTouchValues(item: item, point: point)
                    }
                    
                    touchViews[item.id] = touchView
                }
            }
            
            previousThumbstickViews.values.forEach { $0.removeFromSuperview() }
            self.thumbstickViews = thumbstickViews
            
            previousTouchViews.values.forEach { $0.removeFromSuperview() }
            self.touchViews = touchViews
        }
        else
        {
            self.buttonsView.items = nil
            self.controllerDebugView.items = nil
            
            self.thumbstickViews.values.forEach { $0.removeFromSuperview() }
            self.thumbstickViews = [:]
            
            self.touchViews.values.forEach { $0.removeFromSuperview() }
            self.touchViews = [:]
        }
        
        self.updateGameViews()
        
        if self.transitionSnapshotView != nil
        {
            // Wrap in an animation closure to ensure it actually animates correctly
            // As of iOS 8.3, calling this within transition coordinator animation closure without wrapping
            // in this animation closure causes the change to be instantaneous
            UIView.animate(withDuration: 0.0) {
                self.contentView.alpha = isTranslucent ? self.translucentControllerSkinOpacity : 1.0
            }
        }
        else
        {
            self.contentView.alpha = isTranslucent ? self.translucentControllerSkinOpacity : 1.0
        }
        
        self.transitionSnapshotView?.alpha = 0.0
        
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
        self.setNeedsLayout()
        
        self.reloadInputViews()
    }
    
    func updateGameViews()
    {
        guard self.isControllerInputView else { return }
        
        var previousGameViews = self.gameViewsByScreenID
        var gameViews = [ControllerSkin.Screen.ID: GameView]()
        
        if let controllerSkin = self.controllerSkin,
           let traits = self.controllerSkinTraits,
           let screens = controllerSkin.screens(for: traits)
        {
            for screen in screens where screen.placement == .controller
            {
                // Only manage screens with explicit outputFrames.
                guard screen.outputFrame != nil else { continue }
                
                let gameView = previousGameViews[screen.id] ?? GameView(frame: .zero)
                gameView.update(for: screen)

                previousGameViews[screen.id] = nil
                gameViews[screen.id] = gameView
            }
        }
        else
        {
            for (_, gameView) in previousGameViews
            {
                gameView.filter = nil
            }
            
            gameViews = [:]
        }
        
        var addedGameViews = Set<GameView>()
        var removedGameViews = Set<GameView>()
        
        // Sort them in controller skin order, so that early screens can be covered by later ones.
        let sortedGameViews = gameViews.lazy.sorted { $0.key < $1.key }.map { $0.value }
        for gameView in sortedGameViews
        {
            guard !self.gameViewsByScreenID.values.contains(gameView) else { continue }
            
            self.contentView.insertSubview(gameView, belowSubview: self.buttonsView)
            addedGameViews.insert(gameView)
        }
        
        for gameView in previousGameViews.values
        {
            gameView.removeFromSuperview()
            removedGameViews.insert(gameView)
        }
        
        self.gameViewsByScreenID = gameViews
        
        // Use destination controllerView as Notification object, since that is what client expects.
        let controllerView = self.receivers.lazy.compactMap { $0 as? ControllerView }.first ?? self
        
        NotificationCenter.default.post(name: ControllerView.controllerViewDidUpdateGameViewsNotification, object: controllerView, userInfo: [
            ControllerView.NotificationKey.addedGameViews: addedGameViews,
            ControllerView.NotificationKey.removedGameViews: removedGameViews
        ])
    }
    
    func finishAnimatingUpdateControllerSkin()
    {
        if let transitionImageView = self.transitionSnapshotView
        {
            transitionImageView.removeFromSuperview()
            self.transitionSnapshotView = nil
        }
        
        self.contentView.alpha = 1.0
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
    func activateButtonInputs(_ inputs: Set<AnyInput>)
    {
        for input in inputs
        {
            self.activate(input)
        }
    }
    
    func deactivateButtonInputs(_ inputs: Set<AnyInput>)
    {
        for input in inputs
        {
            self.deactivate(input)
        }
    }
    
    func updateThumbstickValues(item: ControllerSkin.Item, xAxis: Double, yAxis: Double)
    {
        guard case .directional(let up, let down, let left, let right) = item.inputs else { return }
        
        switch xAxis
        {
        case ..<0:
            self.activate(left, value: -xAxis)
            self.deactivate(right)
            
        case 0:
            self.deactivate(left)
            self.deactivate(right)
            
        default:
            self.deactivate(left)
            self.activate(right, value: xAxis)
        }
        
        switch yAxis
        {
        case ..<0:
            self.activate(down, value: -yAxis)
            self.deactivate(up)
            
        case 0:
            self.deactivate(down)
            self.deactivate(up)
            
        default:
            self.deactivate(down)
            self.activate(up, value: yAxis)
        }
    }
    
    func updateTouchValues(item: ControllerSkin.Item, point: CGPoint?)
    {
        guard case .touch(let x, let y) = item.inputs else { return }
        
        if let point = point
        {
            self.activate(x, value: Double(point.x))
            self.activate(y, value: Double(point.y))
        }
        else
        {
            self.deactivate(x)
            self.deactivate(y)
        }
    }
}

private extension ControllerView
{
    @objc func keyboardDidDisconnect(_ notification: Notification)
    {
        guard self.isFirstResponder else { return }
        
        self.resignFirstResponder()
        
        if self.canBecomeFirstResponder
        {
            self.becomeFirstResponder()
        }
    }
}

//MARK: - GameControllerReceiver -
/// GameControllerReceiver
extension ControllerView: GameControllerReceiver
{
    public func gameController(_ gameController: GameController, didActivate input: Input, value: Double)
    {
        guard gameController == self.controllerInputView?.controllerView else { return }
        
        self.activate(input, value: value)
    }
    
    public func gameController(_ gameController: GameController, didDeactivate input: Input)
    {
        guard gameController == self.controllerInputView?.controllerView else { return }
        
        self.deactivate(input)
    }
}

//MARK: - UIKeyInput
/// UIKeyInput
// Becoming first responder doesn't steal keyboard focus from other apps in split view unless the first responder conforms to UIKeyInput.
// So, we conform ControllerView to UIKeyInput and provide stub method implementations.
extension ControllerView: UIKeyInput
{
    public var hasText: Bool {
        return false
    }
    
    public func insertText(_ text: String)
    {
    }
    
    public func deleteBackward()
    {
    }
}
