//
//  PanelDelegate.swift
//  Aiolos
//
//  Created by Matthias Tretter on 11/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Foundation


/// The various delegates of a Panel are informed about relevant events

protocol PanelAnimationDelegate: class {

    /// Tells the delegate that the `panel` is transitioning to a specific position
    func panel(_ panel: PanelViewController, willTransitionTo position: Panel.Configuration.Position, with coordinator: PanelTransitionCoordinator)
}
