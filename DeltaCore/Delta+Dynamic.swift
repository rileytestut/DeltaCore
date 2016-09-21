//
//  Delta+Runtime.swift
//  DeltaCore
//
//  Created by Riley Testut on 6/30/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation

public extension Delta
{
    class RegistrationResponse: NSObject
    {
        public let handler: ((DeltaCoreProtocol) -> Void)
        
        fileprivate init(handler: @escaping ((DeltaCoreProtocol) -> Void))
        {
            self.handler = handler
            
            super.init()
        }
    }
    
    static func registerAllLoadedCores()
    {
        let response = RegistrationResponse { (core) in
            Delta.register(core)
        }
        
        NotificationCenter.default.post(name: .DeltaRegistrationRequest, object: response)
    }
}
