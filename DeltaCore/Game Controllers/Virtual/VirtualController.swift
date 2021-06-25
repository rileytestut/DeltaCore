//
//  VirtualController.swift
//  DeltaCore
//
//  Created by Riley Testut on 6/16/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import GameController

@available(iOS 15, *)
public class VirtualController: NSObject, GameController
{
    public var name: String {
        String(localized: "Virtual Controller")
    }
    
    public var playerIndex: Int? {
        get { return self.mfiController?.playerIndex }
        set { self.mfiController?.playerIndex = newValue }
    }
    
    public var inputType: GameControllerInputType { .mfi }
        
    public private(set) lazy var defaultInputMapping: GameControllerInputMappingProtocol? = {
        guard let fileURL = Bundle.resources.url(forResource: "MFiGameController", withExtension: "deltamapping") else {
            fatalError("MFiGameController.deltamapping does not exist.")
        }
        
        do
        {
            let inputMapping = try GameControllerInputMapping(fileURL: fileURL)
            return inputMapping
        }
        catch
        {
            print(error)
            fatalError("MFiGameController.deltamapping does not exist.")
        }
    }()
    
    public private(set) var isConnected = false
    
    var gcController: GCController? {
        return self.mfiController?.controller
    }
    
    private var inputMappings: [MFiGameController.Input: MFiGameController.Input] = [:]
    
    private var virtualController: GCVirtualController
    private var mfiController: MFiGameController?
    
    private var gameType: GameType?
        
    public override init()
    {
        let configuration = GCVirtualControllerConfiguration()
        self.virtualController = GCVirtualController(configuration: configuration)
        
        super.init()
    }
}

@available(iOS 15, *)
public extension VirtualController
{
    func configure(for gameType: GameType) async throws
    {
        guard gameType != self.gameType else { return }
        self.gameType = gameType
        
        let configuration = GCVirtualControllerConfiguration()
        
        var mappedInputs: Set<AnyInput> = []
        var remappedElementNames = [String: String]()
        
        self.inputMappings.removeAll()
        
        // StandardGameControllerInput is ordered by most -> least common buttons.
        // This means if multiple buttons map to same game input, only the most common one will be visible on the virtual controller.
        for input in StandardGameControllerInput.allCases
        {
            // Ignore if a more common input already maps to the same game input.
            guard let gameInput = input.input(for: gameType), !mappedInputs.contains(AnyInput(gameInput)) else { continue }
            
            let element: String

            switch input
            {
            case .up, .down, .left, .right: element = GCInputDirectionPad
            case .leftThumbstickUp, .leftThumbstickDown, .leftThumbstickRight, .leftThumbstickLeft: element = GCInputLeftThumbstick
            case .rightThumbstickUp, .rightThumbstickDown, .rightThumbstickLeft, .rightThumbstickRight: element = GCInputRightThumbstick
                
            case .a:
                element = GCInputButtonB
                self.inputMappings[.b] = .a
                
            case .b:
                element = GCInputButtonA
                self.inputMappings[.a] = .b
                
            case .x where gameInput.stringValue == input.stringValue:
                element = GCInputButtonY
                self.inputMappings[.y] = .x
                
            case .y where gameInput.stringValue == input.stringValue:
                element = GCInputButtonX
                self.inputMappings[.x] = .y
                
            case .x: element = GCInputButtonX
            case .y: element = GCInputButtonY
            case .l1: element = GCInputLeftShoulder
            case .l2: element = GCInputLeftTrigger
            case .l3: element = GCInputLeftThumbstickButton
            case .r1: element = GCInputRightShoulder
            case .r2: element = GCInputRightTrigger
            case .r3: element = GCInputRightThumbstickButton
            case .menu: element = GCInputButtonMenu
            case .start, .select: continue // No GCInput elements for start or select.
            }
            
            mappedInputs.insert(AnyInput(gameInput))
            remappedElementNames[element] = gameInput.stringValue
        }
        
        configuration.elements = Set(remappedElementNames.keys)
        
        if self.isConnected
        {
            // _disconnect() doesn't change isConnected state,
            // preventing other threads from simultaneously calling connect().
            await self._disconnect()
        }
                
        self.virtualController = GCVirtualController(configuration: configuration)
        
        for element in configuration.elements
        {
            self.virtualController.changeElement(element) { configuration in
                guard let remappedName = remappedElementNames[element]?.capitalized else { return configuration }
                configuration.path = UIBezierPath(string: remappedName)
                return configuration
            }
        }
        
        if self.isConnected
        {
            // _connect() doesn't check isConnected state.
            try await self._connect()
        }
    }
    
    func connect() async throws
    {
        guard !self.isConnected else { return }
        self.isConnected = true
        
        do
        {
            try await _connect()
        }
        catch
        {
            self.isConnected = false
            throw error
        }
    }
    
    func disconnect() async
    {
        guard self.isConnected else { return }
        self.isConnected = false
        
        await _disconnect()
    }
}

@available(iOS 15, *)
private extension VirtualController
{
    func _connect() async throws
    {
        try await self.virtualController.connect()
        
        guard let controller = self.virtualController.controller else { return }
                
        var inputMapping = GameControllerInputMapping(gameControllerInputType: .mfi, mappings: self.inputMappings)
        inputMapping.ignoresUnmappedInputs = false
        
        let mfiController = MFiGameController(controller: controller)
        mfiController.addReceiver(self, inputMapping: inputMapping)
        self.mfiController = mfiController
    }
    
    func _disconnect() async
    {
        self.virtualController.disconnect()
        
        _ = await NotificationCenter.default.notifications(named: .GCControllerDidDisconnect, object: self.gcController).first(where: { _ in true })
        
        self.mfiController = nil
    }
}

@available(iOS 15, *)
extension VirtualController: GameControllerReceiver
{
    public func gameController(_ gameController: GameController, didActivate input: Input, value: Double)
    {
        guard gameController == self.mfiController else { return }
        
        self.activate(input, value: value)
    }
    
    public func gameController(_ gameController: GameController, didDeactivate input: Input)
    {
        guard gameController == self.mfiController else { return }
        
        self.deactivate(input)
    }
}
