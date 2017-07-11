//
//  PanelView.swift
//  Aiolos
//
//  Created by Matthias Tretter on 11/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Foundation


/// The view of the PanelViewController
public final class PanelView: UIVisualEffectView {

    public init(configuration: Panel.Configuration) {
        super.init(effect: configuration.visualEffect)

        self.layer.cornerRadius = configuration.cornerRadius
        self.clipsToBounds = true
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
