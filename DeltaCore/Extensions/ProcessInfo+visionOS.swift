//
//  ProcessInfo+visionOS.swift
//  Delta
//
//  Created by Riley Testut on 1/12/24.
//  Copyright © 2024 Riley Testut. All rights reserved.
//

#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

public extension ProcessInfo
{
    var isRunningOnVisionPro: Bool {
        return Self._isRunningOnVisionPro
    }
    
    // Somewhat expensive to calculate, which can result in dropped touch screen inputs unless we cache value.
    private static let _isRunningOnVisionPro: Bool = {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) // Sets .biometryType when called.
        
        // Can't reference `.opticID` due to bug with #available, so check if .biometryType isn't one of the other types instead.
        let isRunningOnVisionPro = (context.biometryType != .faceID && context.biometryType != .touchID && context.biometryType != .none)
        return isRunningOnVisionPro
        #else
        return false
        #endif
    }()
}
