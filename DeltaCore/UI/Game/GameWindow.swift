//
//  GameWindow.swift
//  DeltaCore
//
//  Created by Riley Testut on 8/11/22.
//  Copyright © 2022 Riley Testut. All rights reserved.
//

import UIKit

public class GameWindow: UIWindow
{
    override open func _restoreFirstResponder()
    {
        guard #available(iOS 16, *), let firstResponder = self._lastFirstResponder else { return super._restoreFirstResponder() }
                
        if firstResponder is ControllerView
        {
            // HACK: iOS 16 beta 5 aggressively tries to restore ControllerView as first responder, even when we've explicitly resigned it as first responder.
            // This can result in the keyboard controller randomly appearing even when user is using another app in the foreground with Stage Manager.
            // As a workaround, we just ignore _restoreFirstResponder() calls when ControllerView was the last first responder and manage it ourselves.
            return
        }
        
        return super._restoreFirstResponder()
    }
}
