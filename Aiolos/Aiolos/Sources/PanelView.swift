//
//  PanelView.swift
//  Aiolos
//
//  Created by Matthias Tretter on 11/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Foundation


/// The view of the Panel
public final class PanelView: UIVisualEffectView {

    // MARK: - Lifecycle

    public init(configuration: Panel.Configuration) {
        super.init(effect: configuration.visualEffect)

        self.clipsToBounds = true
        self.configure(with: configuration)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - PanelView

    func configure(with configuration: Panel.Configuration) {
        self.effect = configuration.visualEffect
        self.layer.cornerRadius = configuration.cornerRadius
        self.layer.maskedCorners = configuration.maskedCorners
    }
}
