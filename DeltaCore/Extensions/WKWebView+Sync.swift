//
//  WKWebView+Sync.swift
//  DeltaCore
//
//  Created by Riley Testut on 1/3/22.
//  Copyright © 2022 Riley Testut. All rights reserved.
//

import WebKit

private extension RunLoop
{
    func run(until condition: () -> Bool)
    {
        while !condition()
        {
            self.run(mode: RunLoop.Mode.default, before: .distantFuture)
        }
    }
}

extension WKWebView
{
    @discardableResult func evaluateJavaScriptSynchronously(_ javaScriptString: String) throws -> Any?
    {
        var finished = false
        
        var finishedResult: Any?
        var finishedError: Error?
        
        func evaluate()
        {
            self.evaluateJavaScript(javaScriptString) { (result, error) in
                finishedResult = result
                finishedError = error
                
                finished = true
            }
            
            RunLoop.current.run(until: { finished })
        }
        
        if Thread.isMainThread
        {
            evaluate()
        }
        else
        {
            DispatchQueue.main.sync {
                evaluate()
            }
        }
        
        if let error = finishedError
        {
            throw error
        }
        
        return finishedResult
    }
}
