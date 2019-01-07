//
//  PanelDelegate.swift
//  Aiolos
//
//  Created by Matthias Tretter on 11/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Foundation


/// The various delegates of a Panel are informed about relevant events

public protocol PanelSizeDelegate: AnyObject {

    /// Asks the delegate for the size of the panel in a specific mode. either width or height might be ignored, based on the mode
    func panel(_ panel: Panel, sizeForMode mode: Panel.Configuration.Mode) -> CGSize
}

public protocol PanelAnimationDelegate: AnyObject {

    /// Tells the delegate that the `panel` is transitioning to a specific size
    func panel(_ panel: Panel, willTransitionTo size: CGSize)

    /// Tells the delegate that the `panel` is transitioning to a specific mode
    func panel(_ panel: Panel, willTransitionFrom oldMode: Panel.Configuration.Mode?, to newMode: Panel.Configuration.Mode, with coordinator: PanelTransitionCoordinator)
    
    /// Tells the delegate that the `panel` is moving to a specific frame
    func panel(_ panel: Panel, willMoveTo frame: CGRect)
    
    /// Tells the delegate that the `panel` is moving to a specific position
    func panel(_ panel: Panel, willMoveFrom oldPosition: Panel.Configuration.Position, to newPosition: Panel.Configuration.Position, with coordinator: PanelTransitionCoordinator)
}

public protocol PanelAccessibilityDelegate: AnyObject {

    /// Asks the delegate for the accessibility label of the resize handle
    func panel(_ panel: Panel, accessibilityLabelForResizeHandle resizeHandle: ResizeHandle) -> String

    /// Tells the delegate that the resize handle was activated with Voice Over
    func panel(_ panel: Panel, didActivateResizeHandle resizeHandle: ResizeHandle) -> Bool
}
