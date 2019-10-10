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
            guard oldValue?.fileURL != self.game?.fileURL else { return }
            
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
    
    open private(set) var gameView: GameView!
    open private(set) var controllerView: ControllerView!
    
    private var gameViewContainerView: UIView!
    
    private let emulatorCoreQueue = DispatchQueue(label: "com.rileytestut.DeltaCore.GameViewController.emulatorCoreQueue", qos: .userInitiated)
    
    private var gameViewContainerViewLayoutConstraints = [NSLayoutConstraint]()
    
    private var controllerViewCenterYConstraint: NSLayoutConstraint!
    
    private var controllerViewBottomConstraint: NSLayoutConstraint!
    private var controllerViewBottomSafeAreaConstraint: NSLayoutConstraint!
    private lazy var controllerViewBottomConstraints = [self.controllerViewBottomConstraint!, self.controllerViewBottomSafeAreaConstraint!]
    
    private var gameViewContainerViewBottomConstraint: NSLayoutConstraint!
    private var gameViewContainerViewControllerViewConstraint: NSLayoutConstraint!
    
    private var gameViewAspectRatioConstraint: NSLayoutConstraint! {
        didSet {
            oldValue?.isActive = false
        }
    }
    
    private var controllerViewAspectRatioConstraint: NSLayoutConstraint! {
        didSet {
            oldValue?.isActive = false
        }
    }
    
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
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.willResignActive(with:)), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.didBecomeActive(with:)), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.keyboardWillShow(with:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.keyboardWillChangeFrame(with:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.keyboardWillHide(with:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    deinit
    {
        self.controllerView.removeObserver(self, forKeyPath: #keyPath(ControllerView.isHidden), context: &kvoContext)
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
        
        self.gameViewContainerView = UIView(frame: CGRect.zero)
        self.gameViewContainerView.translatesAutoresizingMaskIntoConstraints = false
        self.gameViewContainerView.isUserInteractionEnabled = false
        self.view.addSubview(self.gameViewContainerView)
        
        self.gameView = GameView(frame: CGRect.zero)
        self.gameView.translatesAutoresizingMaskIntoConstraints = false
        self.gameViewContainerView.addSubview(self.gameView)
        
        self.controllerView = ControllerView(frame: CGRect.zero)
        self.controllerView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.controllerView)
        
        self.controllerView.addObserver(self, forKeyPath: #keyPath(ControllerView.isHidden), options: [.old, .new], context: &kvoContext)
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self.controllerView, action: #selector(ControllerView.becomeFirstResponder))
        self.view.addGestureRecognizer(tapGestureRecognizer)
        
        self.prepareConstraints()
        
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
        
        // As of iOS 11, the keyboard NSNotifications may return incorrect values for split view controller input view when rotating device.
        // As a workaround, we explicitly resign controllerView as first responder, then restore first responder status after rotation.
        let isControllerViewFirstResponder = self.controllerView.isFirstResponder
        self.controllerView.resignFirstResponder()
        
        self.view.setNeedsUpdateConstraints()
        
        coordinator.animate(alongsideTransition: nil) { (context) in
            self.controllerView.finishAnimatingUpdateControllerSkin()
            
            if isControllerViewFirstResponder
            {
                self.controllerView.becomeFirstResponder()
            }
        }
    }
    
    open override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        for constraint in self.gameViewContainerViewLayoutConstraints + [self.gameViewContainerViewBottomConstraint!]
        {
            func setConstraintConstant(_ constant: CGFloat)
            {
                guard constraint.constant != constant else { return }
                constraint.constant = constant
            }
            
            if
                let controllerSkin = self.controllerView.controllerSkin,
                let traits = self.controllerView.controllerSkinTraits,
                let gameScreenFrame = controllerSkin.gameScreenFrame(for: traits),
                !self.controllerView.isHidden, traits.displayType != .splitView
            {
                // The controller skin has specified a custom game screen frame, so we manually update the layout constraint constants appropriately.
                
                let scaleTransform = CGAffineTransform(scaleX: self.controllerView.bounds.width, y: self.controllerView.bounds.height)
                
                var frame = gameScreenFrame.applying(scaleTransform)
                frame.origin.x += self.controllerView.frame.minX
                frame.origin.y += self.controllerView.frame.minY
                
                switch constraint.firstAttribute
                {
                case .top: setConstraintConstant(frame.minY)
                case .bottom: setConstraintConstant(-(self.view.bounds.height - frame.maxY))
                case .left: setConstraintConstant(frame.minX)
                case .right: setConstraintConstant(-(self.view.bounds.width - frame.maxX))
                default: break
                }
            }
            else
            {
                // No custom game screen frame, so reset constants to 0.
                
                switch constraint.firstAttribute
                {
                case .top, .left, .right: setConstraintConstant(0)
                case .bottom:
                    guard self.controllerView.controllerSkinTraits?.displayType != .splitView else { break }
                    setConstraintConstant(0)
                    
                default: break
                }
            }
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
        
        self.view.setNeedsUpdateConstraints()
        self.view.setNeedsLayout()
        
        self.view.layoutIfNeeded()
    }
    
    // MARK: - GameControllerReceiver -
    /// GameControllerReceiver
    // These would normally be declared in an extension, but non-ObjC compatible methods cannot be overridden if declared in extension :(
    open func gameController(_ gameController: GameController, didActivate input: Input, value: Double)
    {
        guard let standardInput = StandardGameControllerInput(input: input), standardInput == .menu else { return }
        self.delegate?.gameViewController(self, handleMenuInputFrom: gameController)
    }
    
    open func gameController(_ gameController: GameController, didDeactivate input: Input)
    {
        // This method intentionally left blank
    }
}

// MARK: - Layout -
/// Layout
extension GameViewController
{
    private var preferredControllerViewBottomLayoutConstraint: NSLayoutConstraint {
        guard let traits = self.controllerView.controllerSkinTraits else { return self.controllerViewBottomConstraint }
        
        if let window = self.view.window, traits.device == .iphone, self.controllerView.overrideControllerSkinTraits == nil
        {
            let defaultTraits = ControllerSkin.Traits.defaults(for: window)
            if defaultTraits.displayType == .edgeToEdge && traits.displayType == .standard
            {
                // This is a device with an edge-to-edge screen, but controllerView's controllerSkinTraits are for standard display types.
                // This means that the controller skin we are using doesn't include edge-to-edge assets, and we're falling back to standard assets.
                // As a result, we need to ensure controllerView respects safe area, otherwise we may have unwanted cutoffs due to rounded corners.
                
                return self.controllerViewBottomSafeAreaConstraint
            }
        }
        
        return self.controllerViewBottomConstraint
    }
    
    private func prepareConstraints()
    {
        // ControllerView
        let controllerViewConstraints = NSLayoutConstraint.constraints(aspectFitting: self.controllerView, to: self.view) + [self.controllerView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor)]
        self.controllerViewCenterYConstraint = self.controllerView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor)
        
        self.controllerViewBottomConstraint = self.controllerView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        
        self.controllerViewBottomSafeAreaConstraint = self.controllerView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor)
        
        self.controllerViewAspectRatioConstraint = self.controllerView.heightAnchor.constraint(equalToConstant: 0)
        
        // GameView
        let gameViewConstraints = {
            NSLayoutConstraint.constraints(aspectFitting: self.gameView, to: self.gameViewContainerView) + [self.gameView.centerXAnchor.constraint(equalTo: self.gameViewContainerView.centerXAnchor),
                                                                                                                  self.gameView.centerYAnchor.constraint(equalTo: self.gameViewContainerView.centerYAnchor)]
        }()
        
        self.gameViewAspectRatioConstraint = self.gameView.heightAnchor.constraint(equalTo: self.gameView.widthAnchor)
        
        // GameView Container View
        self.gameViewContainerViewLayoutConstraints = [self.gameViewContainerView.topAnchor.constraint(equalTo: self.view.topAnchor),
                                                       self.gameViewContainerView.leftAnchor.constraint(equalTo: self.view.leftAnchor),
                                                       self.gameViewContainerView.rightAnchor.constraint(equalTo: self.view.rightAnchor)]
        
        self.gameViewContainerViewBottomConstraint = self.gameViewContainerView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        self.gameViewContainerViewControllerViewConstraint = self.gameViewContainerView.bottomAnchor.constraint(equalTo: self.controllerView.topAnchor)
        
        NSLayoutConstraint.activate(controllerViewConstraints + gameViewConstraints + self.gameViewContainerViewLayoutConstraints)
        NSLayoutConstraint.activate([self.controllerViewAspectRatioConstraint, self.gameViewAspectRatioConstraint])
        
        self.view.setNeedsUpdateConstraints()
    }
    
    open override func updateViewConstraints()
    {
        super.updateViewConstraints()
        
        var activatedLayoutConstraints = [NSLayoutConstraint]()
        var deactivatedLayoutConstraints = [NSLayoutConstraint]()
        
        func activate(_ constraint: NSLayoutConstraint)
        {
            guard !constraint.isActive else { return }
            activatedLayoutConstraints.append(constraint)
        }
        
        func deactivate(_ constraint: NSLayoutConstraint)
        {
            guard constraint.isActive else { return }
            deactivatedLayoutConstraints.append(constraint)
        }
        
        defer
        {
            // Must deactivate first to prevent conflicting constraint errors.
            NSLayoutConstraint.deactivate(deactivatedLayoutConstraints)
            NSLayoutConstraint.activate(activatedLayoutConstraints)
        }
        
        defer
        {
            self._previousControllerSkin = self.controllerView.controllerSkin
            self._previousControllerSkinTraits = self.controllerView.controllerSkinTraits
        }
        
        switch (self.controllerView.controllerSkinTraits)
        {
        case let traits? where traits.displayType == .splitView: fallthrough
        case .none: fallthrough
        case _ where self.controllerView.controllerSkin == nil:
            // - Controller View should be hidden.
            // - Game View should be centered.
            
            activate(self.controllerViewBottomConstraint)
            activate(self.gameViewContainerViewBottomConstraint)
            
            deactivate(self.controllerViewCenterYConstraint)
            deactivate(self.controllerViewBottomSafeAreaConstraint)
            deactivate(self.gameViewContainerViewControllerViewConstraint)
            
        case _? where self.view.bounds.height >= self.view.bounds.width:
            // Portrait:
            // - Controller View should be pinned to bottom of self.view and centered horizontally.
            // - Game View container view should fill space above controller view to top of self.view.
            
            let controllerViewBottomLayoutConstraint = self.preferredControllerViewBottomLayoutConstraint
            activate(controllerViewBottomLayoutConstraint)
            
            for constraint in self.controllerViewBottomConstraints where constraint != controllerViewBottomLayoutConstraint
            {
                deactivate(constraint)
            }
            
            if
                let controllerSkin = self.controllerView.controllerSkin,
                let traits = self.controllerView.controllerSkinTraits,
                controllerSkin.gameScreenFrame(for: traits) != nil
            {
                // Custom game frame
                
                activate(self.gameViewContainerViewBottomConstraint)
                deactivate(self.gameViewContainerViewControllerViewConstraint)
            }
            else
            {
                // Standard game frame
                
                activate(self.gameViewContainerViewControllerViewConstraint)
                deactivate(self.gameViewContainerViewBottomConstraint)
            }
            
            deactivate(self.controllerViewCenterYConstraint)
            
        case _?:
            // Landscape:
            // - Controller View should be centered vertically in view (though most of the time its height will == self.view height).
            // - Game View container view should match bounds of self.view.
            
            activate(self.controllerViewCenterYConstraint)
            activate(self.gameViewContainerViewBottomConstraint)
            
            deactivate(self.controllerViewBottomConstraint)
            deactivate(self.controllerViewBottomSafeAreaConstraint)
            deactivate(self.gameViewContainerViewControllerViewConstraint)
        }
        
        self.updateControllerSkinAspectRatioConstraint()
    }
    
    private func updateControllerSkinAspectRatioConstraint()
    {
        var updatedAspectRatioConstraint: NSLayoutConstraint?
        
        // Update controller view aspect ratio constraint.
        if !self.controllerView.isHidden, let traits = self.controllerView.controllerSkinTraits, let aspectRatio = self.controllerView.controllerSkin?.aspectRatio(for: traits)
        {
            let multiplier = aspectRatio.height / aspectRatio.width
            
            // Update constraint only if multiplier has changed or the current constraint is a constant height constraint.
            if multiplier != self.controllerViewAspectRatioConstraint.multiplier || self.controllerViewAspectRatioConstraint.secondItem == nil
            {
                updatedAspectRatioConstraint = self.controllerView.heightAnchor.constraint(equalTo: self.controllerView.widthAnchor, multiplier: multiplier)
            }
        }
        else
        {
            // Update constraint only if current constraint is not already a constant height constraint.
            if self.controllerViewAspectRatioConstraint.secondItem != nil
            {
                updatedAspectRatioConstraint = self.controllerView.heightAnchor.constraint(equalToConstant: 0)
            }
        }
        
        if let constraint = updatedAspectRatioConstraint
        {
            self.controllerViewAspectRatioConstraint = constraint
            self.controllerViewAspectRatioConstraint.isActive = true
        }
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
            let gameView = self.gameView,
            let controllerView = self.controllerView,
            let emulatorCore = self.emulatorCore,
            let game = self.game
        else { return }
        
        emulatorCore.add(gameView)
        
        controllerView.addReceiver(self)
        controllerView.addReceiver(emulatorCore)
        
        let controllerSkin = ControllerSkin.standardControllerSkin(for: game.type)
        controllerView.controllerSkin = controllerSkin
        
        let multiplier = emulatorCore.preferredRenderingSize.height / emulatorCore.preferredRenderingSize.width
        self.gameViewAspectRatioConstraint = self.gameView.heightAnchor.constraint(equalTo: self.gameView.widthAnchor, multiplier: multiplier)
        
        self.view.setNeedsUpdateConstraints()
    }
}

// MARK: - Notifications - 
private extension GameViewController
{
    @objc func willResignActive(with notification: Notification)
    {
        self.emulatorCoreQueue.sync {
            _ = self._pauseEmulation()
        }
    }
    
    @objc func didBecomeActive(with notification: Notification)
    {
        self.emulatorCoreQueue.sync {
            _ = self._resumeEmulation()
        }
    }
    
    @objc func keyboardWillShow(with notification: Notification)
    {
        guard let traits = self.controllerView.controllerSkinTraits, traits.displayType == .splitView else { return }
        
        let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as! CGRect
        guard keyboardFrame.height > 0 else { return }
        
        self.gameViewContainerViewBottomConstraint.constant = -keyboardFrame.height
        
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as! TimeInterval
        
        let rawAnimationCurve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as! Int
        let animationCurve = UIView.AnimationCurve(rawValue: rawAnimationCurve)!
        
        let animator = UIViewPropertyAnimator(duration: duration, curve: animationCurve) {
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
        
        self.gameViewContainerViewBottomConstraint.constant = 0
        
        let animator = UIViewPropertyAnimator(duration: duration, curve: animationCurve) {
            self.view.layoutIfNeeded()
        }
        animator.startAnimation()
    }
}
