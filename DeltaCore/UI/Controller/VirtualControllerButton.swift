//
//  VirtualControllerButton.swift
//  DeltaCore
//
//  Created by Riley Testut on 6/22/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import UIKit
import SwiftUI

@available(iOS 15, *)
class VirtualControllerButton: UIButton
{
    init(title: String, primaryAction: UIAction?)
    {
        let fontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .callout).withDesign(.rounded)!.withSymbolicTraits(.traitBold)!
        let font = UIFont(descriptor: fontDescriptor, size: 0)
        
        var attributedString = AttributedString(title)
        attributedString.font = font
        
        var configuration = UIButton.Configuration.plain()
        configuration.attributedTitle = attributedString
        configuration.cornerStyle = .capsule
        configuration.buttonSize = .medium
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15)
        configuration.baseBackgroundColor = nil
        configuration.baseForegroundColor = UIColor(white: 0.1, alpha: 1.0)
        
        var backgroundConfiguration = UIBackgroundConfiguration.clear()
        backgroundConfiguration.visualEffect = UIBlurEffect(style: .light)
        backgroundConfiguration.strokeWidth = 5
        backgroundConfiguration.strokeColor = UIColor(white: 0.1, alpha: 1.0)
        
//        let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
//
//        let vibrancyView = UIVisualEffectView(effect: UIVibrancyEffect(blurEffect: UIBlurEffect(style: .dark), style: .fill))
//        vibrancyView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//        vibrancyView.contentView.backgroundColor = .white
//        visualEffectView.contentView.addSubview(vibrancyView)
//
//        backgroundConfiguration.customView = visualEffectView
        
        configuration.background = backgroundConfiguration
        
        super.init(frame: .zero)
        
        self.configuration = configuration
        
        if let action = primaryAction
        {
            self.addAction(action, for: .primaryActionTriggered)
        }
    }
    
    required init?(coder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateConfiguration()
    {
        super.updateConfiguration()
        
//        if self.isHighlighted
//        {
//            self.configuration?.background.customView?.backgroundColor = .white.withAlphaComponent(0.5)
//        }
//        else
//        {
//            self.configuration?.background.customView?.backgroundColor = .white.withAlphaComponent(0.2)
//        }
        
        if self.isHighlighted
        {
            self.configuration?.background.backgroundColor = .white.withAlphaComponent(0.3)
        }
        else
        {
            self.configuration?.background.backgroundColor = .clear
        }
    }
}

@available(iOS 15, *)
struct ContentView: View
{
    let title: String
    
    var body: some View {
        ButtonAdapter(title: self.title)
            .fixedSize()
            .padding()
            .background(Color.red)
    }
}

@available(iOS 15, *)
struct ButtonAdapter: UIViewRepresentable
{
    let title: String
    
    typealias UIViewType = VirtualControllerButton
    
    func makeUIView(context: Context) -> VirtualControllerButton {
        let button = VirtualControllerButton(title: self.title, primaryAction: nil)
        return button
    }
    
    func updateUIView(_ uiView: VirtualControllerButton, context: Context) {
        uiView.setNeedsLayout()
    }
}

@available(iOS 15, *)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(title: "Menu")
            .fixedSize()
            .previewLayout(.sizeThatFits)
    }
}
