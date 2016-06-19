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
                
        NotificationCenter.default().addObserver(self, selector: #selector(ExternalControllerManager.controllerDidConnect(_:)), name: NSNotification.Name.GCControllerDidConnect, object: nil)
        NotificationCenter.default().addObserver(self, selector: #selector(ExternalControllerManager.controllerDidDisconnect(_:)), name: NSNotification.Name.GCControllerDidDisconnect, object: nil)
    }
    
    func stopMonitoringExternalControllers()
    {
        NotificationCenter.default().removeObserver(self, name: NSNotification.Name.GCControllerDidConnect, object: nil)
        NotificationCenter.default().removeObserver(self, name: NSNotification.Name.GCControllerDidDisconnect, object: nil)
        
        self.connectedControllers.removeAll()
    }
    
    func startWirelessControllerPairingWithCompletionHandler(_ completionHandler: (() -> Void)?)
    {
        GCController.startWirelessControllerDiscovery(completionHandler: completionHandler)
    }
    
    func stopWirelessControllerPairing()
    {
        GCController.stopWirelessControllerDiscovery()
    }
}

//MARK: - Managing Controllers -
private extension ExternalControllerManager
{
    dynamic func controllerDidConnect(_ notification: Notification)
    {        
        guard let controller = notification.object as? GCController else { return }
        
        let externalController = MFiExternalController(controller: controller)
        self.addExternalController(externalController)
    }
    
    dynamic func controllerDidDisconnect(_ notification: Notification)
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
    
    func addExternalController(_ controller: ExternalController)
    {
        if let playerIndex = controller.playerIndex where self.connectedControllers.contains({ $0.playerIndex == playerIndex })
        {
            // Reset the player index if there is another connected controller with the same player index
            controller.playerIndex = nil
        }
        
        self.connectedControllers.append(controller)
        
        NotificationCenter.default().post(name: Notification.Name(rawValue: ExternalControllerDidConnectNotification), object: controller)
    }
    
    func removeExternalController(_ controller: ExternalController)
    {
        if let index = self.connectedControllers.index(of: controller)
        {
            self.connectedControllers.remove(at: index)
            
            NotificationCenter.default().post(name: Notification.Name(rawValue: ExternalControllerDidDisconnectNotification), object: controller)
        }
    }
}
