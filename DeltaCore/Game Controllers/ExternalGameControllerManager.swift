//
//  ExternalGameControllerManager.swift
//  DeltaCore
//
//  Created by Riley Testut on 8/20/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import Foundation
import GameController

public extension Notification.Name
{
    public static let externalGameControllerDidConnect = Notification.Name("ExternalGameControllerDidConnectNotification")
    public static let externalGameControllerDidDisconnect = Notification.Name("ExternalGameControllerDidDisconnectNotification")
}

public class ExternalGameControllerManager
{
    public static let shared = ExternalGameControllerManager()
    
    //MARK: - Properties -
    /** Properties **/
    public fileprivate(set) var connectedControllers: [GameController] = []
}

//MARK: - Discovery -
/** Discovery **/
public extension ExternalGameControllerManager
{
    func startMonitoring()
    {
        for controller in GCController.controllers()
        {
            let externalController = MFiGameController(controller: controller)
            self.add(externalController)
        }
                
        NotificationCenter.default.addObserver(self, selector: #selector(ExternalGameControllerManager.mfiGameControllerDidConnect(_:)), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ExternalGameControllerManager.mfiGameControllerDidDisconnect(_:)), name: .GCControllerDidDisconnect, object: nil)
    }
    
    func stopMonitoring()
    {
        NotificationCenter.default.removeObserver(self, name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.removeObserver(self, name: .GCControllerDidDisconnect, object: nil)
        
        self.connectedControllers.removeAll()
    }
    
    func startWirelessControllerDiscovery(withCompletionHandler completionHandler: (() -> Void)?)
    {
        GCController.startWirelessControllerDiscovery(completionHandler: completionHandler)
    }
    
    func stopWirelessControllerDiscovery()
    {
        GCController.stopWirelessControllerDiscovery()
    }
}

//MARK: - Managing Controllers -
private extension ExternalGameControllerManager
{
    @objc func mfiGameControllerDidConnect(_ notification: Notification)
    {        
        guard let controller = notification.object as? GCController else { return }
        
        let externalController = MFiGameController(controller: controller)
        self.add(externalController)
    }
    
    @objc func mfiGameControllerDidDisconnect(_ notification: Notification)
    {
        guard let controller = notification.object as? GCController else { return }
        
        for externalController in self.connectedControllers
        {
            guard let mfiController = externalController as? MFiGameController else { continue }
            
            if mfiController.controller == controller
            {
                self.remove(externalController)
            }
        }
    }
    
    func add(_ controller: GameController)
    {
        if let playerIndex = controller.playerIndex, self.connectedControllers.contains(where: { $0.playerIndex == playerIndex })
        {
            // Reset the player index if there is another connected controller with the same player index
            controller.playerIndex = nil
        }
        
        self.connectedControllers.append(controller)
        
        NotificationCenter.default.post(name: .externalGameControllerDidConnect, object: controller)
    }
    
    func remove(_ controller: GameController)
    {
        guard let index = self.connectedControllers.index(where: { $0.isEqual(controller) }) else { return }
        
        self.connectedControllers.remove(at: index)
        
        NotificationCenter.default.post(name: .externalGameControllerDidDisconnect, object: controller)
    }
}
