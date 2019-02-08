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

public protocol PanelResizeDelegate: AnyObject {

    /// Tells the delegate that the `panel` has started transitioning vertically
    func panelDidStartResizing(_ panel: Panel)

    /// Tells the delegate that the `panel` is transitioning to a specific size
    func panel(_ panel: Panel, willTransitionTo size: CGSize)

    /// Tells the delegate that the `panel` is transitioning to a specific mode
    func panel(_ panel: Panel, willTransitionFrom oldMode: Panel.Configuration.Mode?, to newMode: Panel.Configuration.Mode, with coordinator: PanelTransitionCoordinator)
}

public protocol PanelRepositionDelegate: AnyObject {

    /// Tells the delegate that the `panel` has started transitioning horizontally
    func panelDidStartMoving(_ panel: Panel)

    /// Asks the delegate if the `panel` can move to a specific frame
    func panel(_ panel: Panel, shouldMoveTo frame: CGRect) -> Bool

    /// Tells the delegate that the `panel` did move to a specific frame
    func panel(_ panel: Panel, didMoveFrom oldFrame: CGRect, to newFrame: CGRect, with coordinator: PanelTransitionCoordinator) -> PanelTransitionCoordinator.Instruction
}

public protocol PanelAccessibilityDelegate: AnyObject {

    /// Asks the delegate for the accessibility label of the resize handle
    func panel(_ panel: Panel, accessibilityLabelForResizeHandle resizeHandle: ResizeHandle) -> String

    /// Tells the delegate that the resize handle was activated with Voice Over
    func panel(_ panel: Panel, didActivateResizeHandle resizeHandle: ResizeHandle) -> Bool
}
