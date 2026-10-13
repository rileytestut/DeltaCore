//
//  UIDevice+Duo.swift
//  DeltaCore
//
//  Created by Riley Testut on 10/12/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import UIKit

extension UIDevice
{
    @_spi(Internal)
    public var isDuo: Bool {
        guard #available(iOS 27.1, *) else { return false }
        guard self.userInterfaceIdiom == .phone else { return false }
        
        // TODO: Replace with better check
        let screen = UIScreen.main.nativeBounds
        return screen.width > 1350
    }
}
