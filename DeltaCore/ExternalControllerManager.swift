//
//  ExternalControllerManager.swift
//  DeltaCore
//
//  Created by Riley Testut on 8/20/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import Foundation
import GameController

public extension Notification.Name
{
    public static let externalControllerDidConnect = "ExternalControllerDidConnectNotification" as Notification.Name
    public static let externalControllerDidDisconnect = "ExternalControllerDidDisconnectNotification" as Notification.Name
}

public class ExternalControllerManager
{
    public static let shared = ExternalControllerManager()
    
    //MARK: - Properties -
    /** Properties **/
    public fileprivate(set) var connectedControllers: [ExternalController] = []
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
            self.add(externalController)
        }
                
        NotificationCenter.default.addObserver(self, selector: #selector(ExternalControllerManager.controllerDidConnect(_:)), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ExternalControllerManager.controllerDidDisconnect(_:)), name: .GCControllerDidDisconnect, object: nil)
    }
    
    func stopMonitoringExternalControllers()
    {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.GCControllerDidConnect, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.GCControllerDidDisconnect, object: nil)
        
        self.connectedControllers.removeAll()
    }
    
    func startWirelessControllerPairing(withCompletionHandler completionHandler: (() -> Void)?)
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
    @objc func controllerDidConnect(_ notification: Notification)
    {        
        guard let controller = notification.object as? GCController else { return }
        
        let externalController = MFiExternalController(controller: controller)
        self.add(externalController)
    }
    
    @objc func controllerDidDisconnect(_ notification: Notification)
    {
        guard let controller = notification.object as? GCController else { return }
        
        for externalController in self.connectedControllers where externalController is MFiExternalController
        {
            if (externalController as! MFiExternalController).controller == controller
            {
                self.remove(externalController)
            }
        }
    }
    
    func add(_ controller: ExternalController)
    {
        if let playerIndex = controller.playerIndex, self.connectedControllers.contains(where: { $0.playerIndex == playerIndex })
        {
            // Reset the player index if there is another connected controller with the same player index
            controller.playerIndex = nil
        }
        
        self.connectedControllers.append(controller)
        
        NotificationCenter.default.post(name: .externalControllerDidConnect, object: controller)
    }
    
    func remove(_ controller: ExternalController)
    {
        if let index = self.connectedControllers.index(of: controller)
        {
            self.connectedControllers.remove(at: index)
            
            NotificationCenter.default.post(name: .externalControllerDidDisconnect, object: controller)
        }
    }
}
