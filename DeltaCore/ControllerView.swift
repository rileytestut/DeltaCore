//
//  ControllerView.swift
//  DeltaCore
//
//  Created by Riley Testut on 5/3/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import UIKit

public extension ControllerView
{
    func beginAnimatingUpdateControllerSkin()
    {
        if self.transitionImageView != nil
        {
            return
        }
        
        let transitionImageView = UIImageView(image: self.imageView.image)
        transitionImageView.frame = self.imageView.frame
        transitionImageView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        transitionImageView.contentMode = .ScaleAspectFit
        transitionImageView.alpha = 1.0
        self.addSubview(transitionImageView)
        
        self.transitionImageView = transitionImageView
        
        self.imageView.alpha = 0.0
    }
    
    func updateControllerSkin()
    {
        let image = self.controllerSkin?.imageForTraitCollection(self.traitCollection)
        self.imageView.image = image
        
        self.invalidateIntrinsicContentSize()
        
        if self.transitionImageView != nil
        {
            // Wrap in an animation closure to ensure it actually animates correctly
            // As of iOS 8.3, calling this within transition coordinator animation closure without wrapping
            // in this animation closure causes the change to be instantaneous
            UIView.animateWithDuration(0.0) {
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

public class ControllerView: UIView, GameController
{
    public var playerIndex: Int?
    public var receiver: GameControllerReceiver?
    
    public var controllerSkin: ControllerSkin? {
        didSet
        {
            self.updateControllerSkin()
        }
    }
    
    private let imageView: UIImageView = UIImageView(frame: CGRectZero)
    private var transitionImageView: UIImageView? = nil
    
    public override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        self.initialize()
    }
    
    public required init(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        self.initialize()
    }
    
    private func initialize()
    {
        self.backgroundColor = UIColor.clearColor()
        
        self.imageView.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
        self.imageView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.imageView.contentMode = .ScaleAspectFit
        self.addSubview(self.imageView)
    }
    
    //MARK: UIView
    
    public override func intrinsicContentSize() -> CGSize
    {
        return self.imageView.intrinsicContentSize()
    }
    
    //MARK: UITraitEnvironment
    
    public override func traitCollectionDidChange(previousTraitCollection: UITraitCollection?)
    {
        super.traitCollectionDidChange(previousTraitCollection)
        
        self.updateControllerSkin()
    }
}