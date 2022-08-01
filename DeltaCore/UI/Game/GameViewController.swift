//
//  GameViewController.swift
//  DeltaCore
//
//  Created by Riley Testut on 7/4/16.
//  Happy 4th of July, Everyone! 🎉
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit
import AVFoundation

fileprivate extension NSLayoutConstraint
{
    class func constraints(aspectFitting view1: UIView, to view2: UIView) -> [NSLayoutConstraint]
    {
        let boundingWidthConstraint = view1.widthAnchor.constraint(lessThanOrEqualTo: view2.widthAnchor, multiplier: 1.0)
        let boundingHeightConstraint = view1.heightAnchor.constraint(lessThanOrEqualTo: view2.heightAnchor, multiplier: 1.0)
        
        let widthConstraint = view1.widthAnchor.constraint(equalTo: view2.widthAnchor)
        widthConstraint.priority = .defaultHigh
        
        let heightConstraint = view1.heightAnchor.constraint(equalTo: view2.heightAnchor)
        heightConstraint.priority = .defaultHigh
        
        return [boundingWidthConstraint, boundingHeightConstraint, widthConstraint, heightConstraint]
    }
}

public protocol GameViewControllerDelegate: class
{
    func gameViewControllerShouldPauseEmulation(_ gameViewController: GameViewController) -> Bool
    func gameViewControllerShouldResumeEmulation(_ gameViewController: GameViewController) -> Bool
    
    func gameViewController(_ gameViewController: GameViewController, handleMenuInputFrom gameController: GameController)
    
    func gameViewControllerDidUpdate(_ gameViewController: GameViewController)
}

public extension GameViewControllerDelegate
{
    func gameViewControllerShouldPauseEmulation(_ gameViewController: GameViewController) -> Bool { return true }
    func gameViewControllerShouldResumeEmulation(_ gameViewController: GameViewController) -> Bool { return true }
    
    func gameViewController(_ gameViewController: GameViewController, handleMenuInputFrom gameController: GameController) {}
    
    func gameViewControllerDidUpdate(_ gameViewController: GameViewController) {}
}

private var kvoContext = 0

open class GameViewController: UIViewController, GameControllerReceiver
{
    open var game: GameProtocol?
    {
        didSet
        {
            if let game = self.game
            {
                self.emulatorCore = EmulatorCore(game: game)
            }
            else
            {
                self.emulatorCore = nil
            }
        }
    }
    
    open private(set) var emulatorCore: EmulatorCore?
    {
        didSet
        {
            oldValue?.stop()
            
            self.emulatorCore?.updateHandler = { [weak self] core in
                guard let strongSelf = self else { return }
                strongSelf.delegate?.gameViewControllerDidUpdate(strongSelf)
            }
            
            self.prepareForGame()
        }
    }
    
    open weak var delegate: GameViewControllerDelegate?
    
    public var gameView: GameView! {
        return self.gameViews.first
    }
    public private(set) var gameViews: [GameView] = []
        
    open private(set) var controllerView: ControllerView!
    private var splitViewInputViewHeight: CGFloat = 0
    
    private let emulatorCoreQueue = DispatchQueue(label: "com.rileytestut.DeltaCore.GameViewController.emulatorCoreQueue", qos: .userInitiated)
    
    private var _previousControllerSkin: ControllerSkinProtocol?
    private var _previousControllerSkinTraits: ControllerSkin.Traits?
    
    /// UIViewController
    open override var prefersStatusBarHidden: Bool {
        return true
    }
    
    public required init()
    {
        super.init(nibName: nil, bundle: nil)
        
        self.initialize()
    }
    
    public required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        self.initialize()
    }
    
    private func initialize()
    {
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.keyboardWillShow(with:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.keyboardWillChangeFrame(with:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.keyboardWillHide(with:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        if #available(iOS 13, *)
        {
            NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.willResignActive(with:)), name: UIScene.willDeactivateNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.didBecomeActive(with:)), name: UIScene.didActivateNotification, object: nil)

            NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.sceneKeyboardFocusDidChange(_:)), name: UIScene.keyboardFocusDidChangeNotification, object: nil)
        }
        else
        {
            NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.willResignActive(with:)), name: UIApplication.willResignActiveNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.didBecomeActive(with:)), name: UIApplication.didBecomeActiveNotification, object: nil)
        }
    }
    
    deinit
    {
        // controllerView might not be initialized by the time deinit is called.
        self.controllerView?.removeObserver(self, forKeyPath: #keyPath(ControllerView.isHidden), context: &kvoContext)
        
        self.emulatorCore?.stop()
    }
    
    // MARK: - UIViewController -
    /// UIViewController
    // These would normally be overridden in a public extension, but overriding these methods in subclasses of GameViewController segfaults compiler if so
    
    open override var prefersHomeIndicatorAutoHidden: Bool
    {
        let prefersHomeIndicatorAutoHidden = self.view.bounds.width > self.view.bounds.height
        return prefersHomeIndicatorAutoHidden
    }
    
    open dynamic override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.black
        
        let gameView = GameView(frame: CGRect.zero)
        self.view.addSubview(gameView)
        self.gameViews.append(gameView)
        
        self.controllerView = ControllerView(frame: CGRect.zero)
        self.view.addSubview(self.controllerView)
        
        self.controllerView.addObserver(self, forKeyPath: #keyPath(ControllerView.isHidden), options: [.old, .new], context: &kvoContext)
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.updateGameViews), name: ControllerView.controllerViewDidChangeControllerSkinNotification, object: self.controllerView)
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(GameViewController.resumeEmulationIfNeeded))
        self.view.addGestureRecognizer(tapGestureRecognizer)
        
        self.prepareForGame()
    }
    
    open dynamic override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        self.emulatorCoreQueue.async {
            _ = self._startEmulation()
        }
    }
    
    open dynamic override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        UIApplication.delta_shared?.isIdleTimerDisabled = true
        
        self.controllerView.becomeFirstResponder()
        
        if #available(iOS 13, *)
        {
            if let scene = self.view.window?.windowScene
            {
                scene.startTrackingKeyboardFocus()
            }
        }
    }
    
    open dynamic override func viewDidDisappear(_ animated: Bool)
    {
        super.viewDidDisappear(animated)
        
        UIApplication.delta_shared?.isIdleTimerDisabled = false
        
        self.emulatorCoreQueue.async {
            _ = self._pauseEmulation()
        }
    }
    
    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator)
    {
        super.viewWillTransition(to: size, with: coordinator)
        
        self.controllerView.beginAnimatingUpdateControllerSkin()
        
        // Disable VideoManager temporarily to prevent random Metal crashes due to rendering while adjusting layout.
        let isVideoManagerEnabled = self.emulatorCore?.videoManager.isEnabled ?? true
        self.emulatorCore?.videoManager.isEnabled = false
        
        // As of iOS 11, the keyboard NSNotifications may return incorrect values for split view controller input view when rotating device.
        // As a workaround, we explicitly resign controllerView as first responder, then restore first responder status after rotation.
        let isControllerViewFirstResponder = self.controllerView.isFirstResponder
        self.controllerView.resignFirstResponder()
        
        self.view.setNeedsUpdateConstraints()
        
        coordinator.animate(alongsideTransition: { (context) in
            self.updateGameViews()
        }) { (context) in
            self.controllerView.finishAnimatingUpdateControllerSkin()
            
            if isControllerViewFirstResponder
            {
                self.controllerView.becomeFirstResponder()
            }
            
            // Re-enable VideoManager if necessary.
            self.emulatorCore?.videoManager.isEnabled = isVideoManagerEnabled
        }
    }
    
    open override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        let screenAspectRatio = self.emulatorCore?.preferredRenderingSize ?? CGSize(width: 1, height: 1)
        
        let controllerViewFrame: CGRect
        let availableGameFrame: CGRect
        
        /* Controller View */
        switch self.controllerView.controllerSkinTraits
        {
        case let traits? where traits.displayType == .splitView:
            // Split-View:
            // - Controller View is pinned to bottom and spans width of device as keyboard input view.
            // - Game View should be vertically centered between top of screen and input view.
            
            controllerViewFrame = CGRect(x: 0, y: self.view.bounds.maxY, width: self.view.bounds.width, height: 0)
            (_, availableGameFrame) = self.view.bounds.divided(atDistance: self.splitViewInputViewHeight, from: .maxYEdge)
            
        case .none: fallthrough
        case _? where self.controllerView.isHidden:
            // Controller View Hidden:
            // - Controller View should have a height of 0.
            // - Game View should be centered in self.view.
             
            (controllerViewFrame, availableGameFrame) = self.view.bounds.divided(atDistance: 0, from: .maxYEdge)
            
        case let traits? where traits.orientation == .portrait && self.controllerView.controllerSkin?.screens(for: traits) == nil:
            // Portrait (no custom screens):
            // - Controller View should be pinned to bottom of self.view and centered horizontally.
            // - Game View should be vertically centered between top of screen and controller view.
            
            let intrinsicContentSize = self.controllerView.intrinsicContentSize
            if intrinsicContentSize.height != UIView.noIntrinsicMetric && intrinsicContentSize.width != UIView.noIntrinsicMetric
            {
                let controllerViewHeight = (self.view.bounds.width / intrinsicContentSize.width) * intrinsicContentSize.height
                (controllerViewFrame, availableGameFrame) = self.view.bounds.divided(atDistance: controllerViewHeight, from: .maxYEdge)
            }
            else
            {
                controllerViewFrame = self.view.bounds
                availableGameFrame = self.view.bounds
            }
            
        case _?:
            // Landscape (or Portrait with custom screens):
            // - Controller View should be centered vertically in view (though most of the time its height will == self.view height).
            // - Game View should be centered in self.view.
                        
            let intrinsicContentSize = self.controllerView.intrinsicContentSize
            if intrinsicContentSize.height != UIView.noIntrinsicMetric && intrinsicContentSize.width != UIView.noIntrinsicMetric
            {
                controllerViewFrame = AVMakeRect(aspectRatio: intrinsicContentSize, insideRect: self.view.bounds)
            }
            else
            {
                controllerViewFrame = self.view.bounds
            }
            
            availableGameFrame = self.view.bounds
        }
        
        self.controllerView.frame = controllerViewFrame
        
        /* Game View */
        if
            let controllerSkin = self.controllerView.controllerSkin,
            let traits = self.controllerView.controllerSkinTraits,
            let screens = controllerSkin.screens(for: traits),
            let aspectRatio = controllerSkin.aspectRatio(for: traits),
            !self.controllerView.isHidden
        {
            for (screen, gameView) in zip(screens, self.gameViews)
            {
                let containerFrame = AVMakeRect(aspectRatio: aspectRatio, insideRect: controllerViewFrame)
                
                var outputFrame = screen.outputFrame.applying(.init(scaleX: containerFrame.width, y: containerFrame.height))
                outputFrame.origin.x += containerFrame.minX
                outputFrame.origin.y += containerFrame.minY
                gameView.frame = outputFrame
            }
        }
        else
        {
            let gameViewFrame = AVMakeRect(aspectRatio: screenAspectRatio, insideRect: availableGameFrame)
            self.gameView.frame = gameViewFrame
        }
        
        if self.emulatorCore?.state != .running
        {
            // WORKAROUND
            // Sometimes, iOS will cache the rendered image (such as when covered by a UIVisualEffectView), and as a result the game view might appear skewed
            // To compensate, we manually "refresh" the game screen
            self.gameView.inputImage = self.gameView.outputImage
        }
        
        self.setNeedsUpdateOfHomeIndicatorAutoHidden()
    }
    
    // MARK: - KVO -
    /// KVO
    open dynamic override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?)
    {        
        guard context == &kvoContext else { return super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context) }

        // Ensures the value is actually different, or else we might potentially run into an infinite loop if subclasses hide/show controllerView in viewDidLayoutSubviews()
        guard (change?[.newKey] as? Bool) != (change?[.oldKey] as? Bool) else { return }
        
        self.view.setNeedsLayout()
        self.view.layoutIfNeeded()
    }
    
    // MARK: - GameControllerReceiver -
    /// GameControllerReceiver
    // These would normally be declared in an extension, but non-ObjC compatible methods cannot be overridden if declared in extension :(
    open func gameController(_ gameController: GameController, didActivate input: Input, value: Double)
    {
        // This method intentionally left blank
    }
    
    open func gameController(_ gameController: GameController, didDeactivate input: Input)
    {
        // Wait until menu button is released before calling handleMenuInputFrom:
        // Fixes potentially missing key-up inputs due to showing pause menu.
        guard let standardInput = StandardGameControllerInput(input: input), standardInput == .menu else { return }
        self.delegate?.gameViewController(self, handleMenuInputFrom: gameController)
    }
}

// MARK: - Layout -
/// Layout
extension GameViewController
{
    @objc func updateGameViews()
    {
        var previousGameViews = Array(self.gameViews.reversed())
        var gameViews = [GameView]()
        
        if
            let controllerSkin = self.controllerView.controllerSkin,
            let traits = self.controllerView.controllerSkinTraits,
            let screens = controllerSkin.screens(for: traits),
            !self.controllerView.isHidden
        {
            for screen in screens
            {
                let gameView = previousGameViews.popLast() ?? GameView(frame: .zero)
                
                var filters = [CIFilter]()
                
                if let inputFrame = screen.inputFrame
                {
                    let cropFilter = CIFilter(name: "CICrop", parameters: ["inputRectangle": CIVector(cgRect: inputFrame)])!
                    filters.append(cropFilter)
                }
                
                if let screenFilters = screen.filters
                {
                    filters.append(contentsOf: screenFilters)
                }
                
                if filters.isEmpty
                {
                    gameView.filter = nil
                }
                else
                {
                    // Always use FilterChain since it has additional logic for chained filters.
                    let filterChain = FilterChain(filters: filters)
                    gameView.filter = filterChain
                }
                
                let outputFrame = screen.outputFrame.applying(.init(scaleX: self.view.bounds.width, y: self.view.bounds.height))
                gameView.frame = outputFrame
                
                gameViews.append(gameView)
            }
        }
        else
        {
            for gameView in self.gameViews
            {
                gameView.filter = nil
            }
            
            gameViews.append(self.gameView)
        }
        
        for gameView in gameViews
        {
            guard !self.gameViews.contains(gameView) else { continue }
            
            self.view.insertSubview(gameView, aboveSubview: self.gameView)
            self.emulatorCore?.add(gameView)
        }
        
        for gameView in previousGameViews
        {
            guard !gameViews.contains(gameView) else { continue }
            
            gameView.removeFromSuperview()
            self.emulatorCore?.remove(gameView)
        }
        
        self.gameViews = gameViews
        self.view.setNeedsLayout()
    }
}

// MARK: - Emulation -
/// Emulation
public extension GameViewController
{
    @discardableResult func startEmulation() -> Bool
    {
        return self.emulatorCoreQueue.sync {
            return self._startEmulation()
        }
    }
    
    @discardableResult func pauseEmulation() -> Bool
    {
        return self.emulatorCoreQueue.sync {
            return self._pauseEmulation()
        }
    }
    
    @discardableResult func resumeEmulation() -> Bool
    {
        return self.emulatorCoreQueue.sync {
            self._resumeEmulation()
        }
    }
}

private extension GameViewController
{
    func _startEmulation() -> Bool
    {
        guard let emulatorCore = self.emulatorCore else { return false }
        
        // Toggle audioManager.enabled to reset the audio buffer and ensure the audio isn't delayed from the beginning
        // This is especially noticeable when peeking a game
        emulatorCore.audioManager.isEnabled = false
        emulatorCore.audioManager.isEnabled = true
        
        return self._resumeEmulation()
    }
    
    private func _pauseEmulation() -> Bool
    {
        guard let emulatorCore = self.emulatorCore, self.delegate?.gameViewControllerShouldPauseEmulation(self) ?? true else { return false }
        
        let result = emulatorCore.pause()
        return result
    }
    
    private func _resumeEmulation() -> Bool
    {
        guard let emulatorCore = self.emulatorCore, self.delegate?.gameViewControllerShouldResumeEmulation(self) ?? true else { return false }
        
        DispatchQueue.main.async {
            if self.view.window != nil
            {
                self.controllerView.becomeFirstResponder()
            }
        }
        
        let result: Bool
        
        switch emulatorCore.state
        {
        case .stopped: result = emulatorCore.start()
        case .paused: result = emulatorCore.resume()
        case .running: result = true
        }
        
        return result
    }
}

// MARK: - Preparation -
private extension GameViewController
{
    func prepareForGame()
    {
        guard
            let controllerView = self.controllerView,
            let emulatorCore = self.emulatorCore,
            let game = self.game
        else { return }
        
        for gameView in self.gameViews
        {
            emulatorCore.add(gameView)
        }
        
        controllerView.addReceiver(self)
        controllerView.addReceiver(emulatorCore)
        
        let controllerSkin = ControllerSkin.standardControllerSkin(for: game.type)
        controllerView.controllerSkin = controllerSkin
        
        self.view.setNeedsUpdateConstraints()
    }
    
    @objc func resumeEmulationIfNeeded()
    {
        self.controllerView.becomeFirstResponder()
        
        self.emulatorCoreQueue.async {
            guard self.emulatorCore?.state == .paused else { return }
            _ = self._resumeEmulation()
        }
    }
}

// MARK: - Notifications - 
private extension GameViewController
{
    @objc func willResignActive(with notification: Notification)
    {
        if #available(iOS 13, *)
        {
            guard let scene = notification.object as? UIScene, scene == self.view.window?.windowScene else { return }
        }
        
        self.emulatorCoreQueue.async {
            guard self.emulatorCore?.state == .running else { return }
            _ = self._pauseEmulation()
        }
    }
    
    @objc func didBecomeActive(with notification: Notification)
    {
        if #available(iOS 13, *)
        {
            // Make sure scene has keyboard focus before automatically resuming.
            guard let scene = notification.object as? UIWindowScene, scene == self.view.window?.windowScene, scene.hasKeyboardFocus else { return }
            
            if #available(iOS 16, *), scene.isStageManagerEnabled
            {
                // When Stage Manager is active, only resume emulation if self.controllerView is still the first responder.
                // This prevents us from automatically resuming emulation when we're not the frontmost app.
                guard self.controllerView.isFirstResponder else { return }
            }
        }
        
        self.emulatorCoreQueue.async {
            guard self.emulatorCore?.state == .paused else { return }
            _ = self._resumeEmulation()
        }
    }
    
    @objc func keyboardWillShow(with notification: Notification)
    {
        guard let window = self.view.window, let traits = self.controllerView.controllerSkinTraits, traits.displayType == .splitView else { return }
        
        let systemKeyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as! CGRect
        guard systemKeyboardFrame.height > 0 else { return }
        
        let sceneKeyboardFrame = self.view.convert(systemKeyboardFrame, from: window.screen.coordinateSpace)
        
        let relativeHeight = self.view.bounds.height - sceneKeyboardFrame.minY
        self.splitViewInputViewHeight = relativeHeight
        
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as! TimeInterval
        
        let rawAnimationCurve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as! Int
        let animationCurve = UIView.AnimationCurve(rawValue: rawAnimationCurve)!
        
        let animator = UIViewPropertyAnimator(duration: duration, curve: animationCurve) {
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
        animator.startAnimation()
    }
    
    @objc func keyboardWillChangeFrame(with notification: Notification)
    {
        self.keyboardWillShow(with: notification)
    }
    
    @objc func keyboardWillHide(with notification: Notification)
    {
        let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as! CGRect
        guard keyboardFrame.height > 0 else { return }
        
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as! TimeInterval
        
        let rawAnimationCurve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as! Int
        let animationCurve = UIView.AnimationCurve(rawValue: rawAnimationCurve)!
        
        self.splitViewInputViewHeight = 0
        
        let animator = UIViewPropertyAnimator(duration: duration, curve: animationCurve) {
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
        animator.startAnimation()
        
        let isLocalKeyboard = notification.userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? Bool ?? false
        if #available(iOS 13, *), let scene = self.view.window?.windowScene, scene.activationState == .foregroundInactive, isLocalKeyboard
        {
            // Explicitly resign first responder to prevent keyboard controller automatically appearing when not frontmost app.
            self.controllerView.resignFirstResponder()
        }
    }
    
    @available(iOS 13.0, *)
    @objc func sceneKeyboardFocusDidChange(_ notification: Notification)
    {
        guard let scene = notification.object as? UIScene, scene == self.view.window?.windowScene else { return }
        
        if !scene.hasKeyboardFocus && scene.activationState == .foregroundActive
        {
            // Explicitly resign first responder to prevent emulation resuming automatically when not frontmost app.
            self.controllerView.resignFirstResponder()
        }
        
        // Must run on emulatorCoreQueue to ensure emulatorCore state is accurate.
        self.emulatorCoreQueue.async {
            if scene.hasKeyboardFocus
            {
                guard self.emulatorCore?.state == .paused else { return }
                _ = self._resumeEmulation()
            }
            else
            {
                guard self.emulatorCore?.state == .running else { return }
                _ = self._pauseEmulation()
            }
        }
    }
}
