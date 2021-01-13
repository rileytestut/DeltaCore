//
//  RenderThread.swift
//  DeltaCore
//
//  Created by Riley Testut on 1/12/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation

class RenderThread: Thread
{
    var action: () -> Void
    
    private let startRenderSemaphore = DispatchSemaphore(value: 0)
    private let finishedRenderSemaphore = DispatchSemaphore(value: 0)
        
    init(action: @escaping () -> Void)
    {
        self.action = action
        self.finishedRenderSemaphore.signal()
        
        super.init()
        
        self.name = "Delta - Rendering"
        self.qualityOfService = .userInitiated
    }
    
    override func main()
    {
        while !self.isCancelled
        {
            autoreleasepool {
                self.startRenderSemaphore.wait()
                defer { self.finishedRenderSemaphore.signal() }
                
                guard !self.isCancelled else { return }
                
                self.action()
            }
        }
    }
    
    override func cancel()
    {
        super.cancel()
        
        // We're probably waiting on startRenderSemaphore in main(),
        // so explicitly signal it so thread can finish.
        self.startRenderSemaphore.signal()
    }
}

extension RenderThread
{
    func run()
    {
        self.startRenderSemaphore.signal()
    }
    
    @discardableResult
    func wait(timeout: DispatchTime = .distantFuture) -> DispatchTimeoutResult
    {
        return self.finishedRenderSemaphore.wait(timeout: timeout)
    }
}
