//
//  EAGLContext+BestAvailable.swift
//  DeltaCore
//
//  Created by David Chavez on 22.05.22.
//  Copyright © 2022 Riley Testut. All rights reserved.
//

import GLKit

extension EAGLContext {
    static func createUsingBestAvailableAPI(sharegroup: EAGLSharegroup? = nil) -> EAGLContext {
        if let sharegroup = sharegroup {
            var context = EAGLContext(api: .openGLES3, sharegroup: sharegroup)
            if context == nil {
                context = EAGLContext(api: .openGLES2, sharegroup: sharegroup)
                if context == nil {
                    context = EAGLContext(api: .openGLES1, sharegroup: sharegroup)
                }
            }

            return context!
        }

        var context = EAGLContext(api: .openGLES3)
        if context == nil {
            context = EAGLContext(api: .openGLES2)
            if context == nil {
                context = EAGLContext(api: .openGLES1)
            }
        }

        return context!
    }
}
