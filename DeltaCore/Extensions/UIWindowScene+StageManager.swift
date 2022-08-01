//
//  UIWindowScene+StageManager.swift
//  DeltaCore
//
//  Created by Riley Testut on 8/1/22.
//  Copyright © 2022 Riley Testut. All rights reserved.
//

import UIKit

@objc private protocol UIWindowScenePrivate: NSObjectProtocol
{
    var _enhancedWindowingEnabled: Bool { get }
}

@available(iOS 16, *)
extension UIWindowScene
{
    var isStageManagerEnabled: Bool {
        guard self.responds(to: #selector(getter: UIWindowScenePrivate._enhancedWindowingEnabled)) else { return false }
        
        let windowScene = unsafeBitCast(self, to: UIWindowScenePrivate.self)
        let isStageManagerEnabled = windowScene._enhancedWindowingEnabled
        return isStageManagerEnabled
    }
}
