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
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.willResignActive(with:)), name: .UIApplicationWillResignActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GameViewController.didBecomeActive(with:)), name: .UIApplicationDidBecomeActive, object: nil)
    }
    
    deinit
    {
        self.controllerView.removeObserver(self, forKeyPath: #keyPath(ControllerView.isHidden), context: &kvoContext)
        self.emulatorCore?.stop()
    }
    
    // MARK: - UIViewController -
    /// UIViewController
    // These would normally be overridden in a public extension, but overriding these methods in subclasses of GameViewController segfaults compiler if so
    
    open override func prefersHomeIndicatorAutoHidden() -> Bool
    {
        let prefersHomeIndicatorAutoHidden = self.view.bounds.width > self.view.bounds.height
        return prefersHomeIndicatorAutoHidden
    }
    
    open dynamic override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.black
        
        self.gameViewContainerView = UIView(frame: CGRect.zero)
        self.view.addSubview(self.gameViewContainerView)
        
        self.gameView = GameView(frame: CGRect.zero)
        self.gameViewContainerView.addSubview(self.gameView)
        
        self.controllerView = ControllerView(frame: CGRect.zero)
        self.view.addSubview(self.controllerView)
        
        self.controllerView.addObserver(self, forKeyPath: #keyPath(ControllerView.isHidden), options: [.old, .new], context: &kvoContext)
        
        self.prepareForGame()
    }
    
    open dynamic override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        self.startEmulation()
    }
    
    open dynamic override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        UIApplication.delta_shared?.isIdleTimerDisabled = true
        
        self.becomeFirstResponder()
    }
    
    open dynamic override func viewDidDisappear(_ animated: Bool)
    {
        super.viewDidDisappear(animated)
        
        UIApplication.delta_shared?.isIdleTimerDisabled = false
        
        if let emulatorCore = self.emulatorCore
        {
            self.emulatorCoreQueue.async {
                emulatorCore.pause()
            }
        }
    }
    
    open dynamic override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator)
    {
        super.viewWillTransition(to: size, with: coordinator)
        
        self.controllerView.beginAnimatingUpdateControllerSkin()
        
        coordinator.animate(alongsideTransition: nil) { (context) in
            self.controllerView.finishAnimatingUpdateControllerSkin()
        }
    }
    
    open dynamic override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        let viewBounds = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height)
        
        
        // Layout ControllerView
        if
            let controllerSkin = self.controllerView.controllerSkin,
            let traits = self.controllerView.controllerSkinTraits,
            let aspectRatio = controllerSkin.aspectRatio(for: traits)
        {
            var frame = AVMakeRect(aspectRatio: aspectRatio, insideRect: viewBounds)
            
            if self.view.bounds.height > self.view.bounds.width
            {
                // The CGRect returned by AVMakeRect is centered inside the parent frame.
                // This is fine for landscape, but when in portrait, we want controllerView to be pinned to the bottom of the parent frame instead.
                frame.origin.y = self.view.bounds.height - frame.height
                
                if #available(iOS 11.0, *)
                {
                    if let window = self.view.window, traits.device == .iphone, self.controllerView.overrideControllerSkinTraits == nil
                    {
                        let defaultTraits = ControllerSkin.Traits.defaults(for: window)
                        if defaultTraits.displayType == .edgeToEdge && traits.displayType == .standard
                        {
                            // This is a device with an edge-to-edge screen, but controllerView's controllerSkinTraits are for standard display types.
                            // This means that the controller skin we are using doesn't include edge-to-edge assets, and we're falling back to standard assets.
                            // As a result, we need to ensure controllerView respects safe area, otherwise we may have unwanted cutoffs due to rounded corners.
                            
                            frame.origin.y -= self.view.safeAreaInsets.bottom
                        }
                    }
                }
            }
            
            self.controllerView.frame = frame
        }
        else
        {
            self.controllerView.frame = CGRect.zero
        }
        
        
        // Layout GameViewContainerView
        if self.controllerView.isHidden || self.controllerView.frame.isEmpty
        {
            // controllerView is hidden, so gameViewContainerView should match bounds of parent view.
            self.gameViewContainerView.frame = viewBounds
        }
        else
        {
            if
                let controllerSkin = self.controllerView.controllerSkin,
                let traits = self.controllerView.controllerSkinTraits,
                let gameScreenFrame = controllerSkin.gameScreenFrame(for: traits)
            {
                // controllerSkin specifies a specific frame for the game screen, so we'll use that to position gameViewContainerView.
                
                let scaleTransform = CGAffineTransform(scaleX: self.controllerView.bounds.width, y: self.controllerView.bounds.height)
                
                var frame = gameScreenFrame.applying(scaleTransform)
                frame.origin.x += self.controllerView.frame.minX
                frame.origin.y += self.controllerView.frame.minY
                
                self.gameViewContainerView.frame = frame
            }
            else
            {
                // controllerSkin doesn't specify a specific frame for the game screen, so we'll use the default frames.
                
                var frame: CGRect
                
                if self.view.bounds.height > self.view.bounds.width
                {
                    // Portrait. Frame is the area above controllerSkin.
                    frame = CGRect(x: 0, y: 0, width: viewBounds.width, height: viewBounds.height - self.controllerView.bounds.height)
                }
                else
                {
                    // Landscape. Frame is equal to viewBounds.
                    frame = viewBounds
                }
                
                self.gameViewContainerView.frame = frame
            }
        }
        
        
        // Layout GameView
        let preferredRenderingSize = self.emulatorCore?.preferredRenderingSize ?? CGSize(width: 256, height: 224)
        let containerBounds = CGRect(x: 0, y: 0, width: self.gameViewContainerView.bounds.width, height: self.gameViewContainerView.bounds.height)
        
        let frame = AVMakeRect(aspectRatio: preferredRenderingSize, insideRect:containerBounds)
        self.gameView.frame = frame
        
        
        if self.emulatorCore?.state != .running
        {
            // WORKAROUND
            // Sometimes, iOS will cache the rendered image (such as when covered by a UIVisualEffectView), and as a result the game view might appear skewed
            // To compensate, we manually "refresh" the game screen
            self.gameView.inputImage = self.gameView.outputImage
        }
        
        if #available(iOS 11.0, *)
        {
            self.setNeedsUpdateOfHomeIndicatorAutoHidden()
        }
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
    open func gameController(_ gameController: GameController, didActivate input: Input)
    {
        guard let standardInput = StandardGameControllerInput(input: input), standardInput == .menu else { return }
        self.delegate?.gameViewController(self, handleMenuInputFrom: gameController)
    }
    
    open func gameController(_ gameController: GameController, didDeactivate input: Input)
    {
        // This method intentionally left blank
    }
}

// MARK: - Emulation -
/// Emulation
public extension GameViewController
{
    @discardableResult func pauseEmulation() -> Bool
    {
        guard let emulatorCore = self.emulatorCore, self.delegate?.gameViewControllerShouldPauseEmulation(self) ?? true else { return false }
        
        var result = false
        
        self.emulatorCoreQueue.sync {
            result = emulatorCore.pause()
        }
        
        return result
    }
    
    @discardableResult func resumeEmulation() -> Bool
    {
        guard let emulatorCore = self.emulatorCore, self.delegate?.gameViewControllerShouldResumeEmulation(self) ?? true else { return false }
        
        var result = false
        
        self.emulatorCoreQueue.sync {
            switch emulatorCore.state
            {
            case .stopped: result = emulatorCore.start()
            case .paused: result = emulatorCore.resume()
            case .running: result = true
            }
        }
        
        return result
    }
}

// MARK: - UIResponder
extension GameViewController
{
    open override var canBecomeFirstResponder: Bool {
        return true
    }
    
    open override var next: UIResponder? {
        let keyboardResponder = KeyboardResponder(nextResponder: super.next)
        return keyboardResponder
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
    }
    
    func startEmulation()
    {
        guard let emulatorCore = self.emulatorCore else { return }
        
        // Toggle audioManager.enabled to reset the audio buffer and ensure the audio isn't delayed from the beginning
        // This is especially noticeable when peeking a game
        emulatorCore.audioManager.isEnabled = false
        emulatorCore.audioManager.isEnabled = true
        
        self.resumeEmulation()
    }
}

// MARK: - Notifications - 
private extension GameViewController
{
    @objc func willResignActive(with notification: Notification)
    {
        self.pauseEmulation()
    }
    
    @objc func didBecomeActive(with notification: Notification)
    {
        self.resumeEmulation()
    }
}
