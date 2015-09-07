//
//  ExternalControllerManager.swift
//  DeltaCore
//
//  Created by Riley Testut on 8/20/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import Foundation
import GameController

public let ExternalControllerDidConnectNotification = "ExternalControllerDidConnectNotification"
public let ExternalControllerDidDisconnectNotification = "ExternalControllerDidDisconnectNotification"

public class ExternalControllerManager
{
    public static let sharedManager = ExternalControllerManager()
    
    //MARK: - Properties -
    /** Properties **/
    public var connectedControllers: [ExternalController] = []
}

//MARK: - Discovery -
/** Discovery **/
public extension ExternalControllerManager
{
    func startMonitoringExternalControllers()
    {
        for controller in GCController.controllers()
        {
            let externalController = MFiExternalController(controller: controller)
            self.addExternalController(externalController)
        }
                
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("controllerDidConnect:"), name: GCControllerDidConnectNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("controllerDidDisconnect:"), name: GCControllerDidDisconnectNotification, object: nil)
    }
    
    func stopMonitoringExternalControllers()
    {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: GCControllerDidConnectNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: GCControllerDidDisconnectNotification, object: nil)
        
        self.connectedControllers.removeAll()
    }
    
    func startWirelessControllerPairingWithCompletionHandler(completionHandler: (() -> Void)?)
    {
        GCController.startWirelessControllerDiscoveryWithCompletionHandler(completionHandler)
    }
    
    func stopWirelessControllerPairing()
    {
        GCController.stopWirelessControllerDiscovery()
    }
}

//MARK: - Managing Controllers -
private extension ExternalControllerManager
{
    dynamic func controllerDidConnect(notification: NSNotification)
    {        
        guard let controller = notification.object as? GCController else { return }
        
        let externalController = MFiExternalController(controller: controller)
        self.addExternalController(externalController)
    }
    
    dynamic func controllerDidDisconnect(notification: NSNotification)
    {
        guard let controller = notification.object as? GCController else { return }
        
        for externalController in self.connectedControllers where externalController is MFiExternalController
        {
            if (externalController as! MFiExternalController).controller == controller
            {
                self.removeExternalController(externalController)
            }
        }
    }
    
    func addExternalController(controller: ExternalController)
    {
        if let playerIndex = controller.playerIndex where self.connectedControllers.contains({ $0.playerIndex == playerIndex })
        {
            // Reset the player index if there is another connected controller with the same player index
            controller.playerIndex = nil
        }
        
        self.connectedControllers.append(controller)
        
        NSNotificationCenter.defaultCenter().postNotificationName(ExternalControllerDidConnectNotification, object: controller)
    }
    
    func removeExternalController(controller: ExternalController)
    {
        if let index = self.connectedControllers.indexOf(controller)
        {
            self.connectedControllers.removeAtIndex(index)
            
            NSNotificationCenter.defaultCenter().postNotificationName(ExternalControllerDidDisconnectNotification, object: controller)
        }
    }
}