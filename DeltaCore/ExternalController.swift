//
//  ExternalController.swift
//  DeltaCore
//
//  Created by Riley Testut on 7/22/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import Foundation
import GameController

open class ExternalController: GameController, Hashable
{
    //MARK: - Properties -
    /** Properties **/
    
    open var name: String {
        return NSLocalizedString("External Controller", comment: "")
    }
    
    //MARK: <GameControllerType>
    /// <GameControllerType>
    public var playerIndex: Int?
    public var inputTransformationHandler: ((GameController, Input) -> [Input])?
    public let _stateManager = GameControllerStateManager()
    
    //MARK: <Hashable>
    /// <Hashable>
    public var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
    
    public init()
    {
        
    }
}

public func ==(lhs: ExternalController, rhs: ExternalController) -> Bool
{
    return lhs === rhs
}

//MARK: - Private Methods -
internal extension ExternalController
{
    func updateReceivers(forActivatedInput input: Input)
    {
        let activatedInputs = [input].flatMap { self.inputTransformationHandler?(self, $0) ?? [$0] }

        for input in activatedInputs
        {
            self.activate(input)
        }
    }
    
    func updateReceivers(forDeactivatedInput input: Input)
    {
        let deactivatedInputs = [input].flatMap { self.inputTransformationHandler?(self, $0) ?? [$0] }
        
        for input in deactivatedInputs
        {
            self.deactivate(input)
        }
    }
}
