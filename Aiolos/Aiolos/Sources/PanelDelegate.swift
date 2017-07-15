//
//  PanelDelegate.swift
//  Aiolos
//
//  Created by Matthias Tretter on 11/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Foundation


/// The various delegates of a Panel are informed about relevant events

public protocol PanelSizeDelegate: class {

    /// Asks the delegate for the size of the panel in a specific mode. either width or height might be ignored, based on the mode
    func panel(_ panel: PanelViewController, sizeForMode mode: Panel.Configuration.Mode) -> CGSize
}

public protocol PanelAnimationDelegate: class {

    /// Tells the delegate that the `panel` is transitioning to a specific size
    func panel(_ panel: PanelViewController, willTransitionTo size: CGSize, with coordinator: PanelTransitionCoordinator)
}
