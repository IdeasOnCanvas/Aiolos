//
//  PanelConfiguration.swift
//  Aiolos
//
//  Created by Matthias Tretter on 11/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Foundation


/// Allows to configure the appearance of the floating panel
public extension Panel {

    public struct Configuration {

        public enum Position: Int {
            case bottom
            case leadingBottom
            case trailingBottom
        }

        public enum Mode: Int {
            case compact
            case expanded
            case fullHeight
        }

        public var position: Position
        public var mode: Mode
        public var visualEffect: UIVisualEffect?
        public var margins: UIEdgeInsets
        public var cornerRadius: CGFloat
        public var maskedCorners: CACornerMask
        public var borderColor: UIColor
        public var resizeHandleColor: UIColor
        public var resizeHandleBackgroundColor: UIColor
        public var separatorColor: UIColor
        public var isGestureBasedResizingEnabled: Bool
    }
}

public extension Panel.Configuration {

    static var `default`: Panel.Configuration {
        return Panel.Configuration(position: .bottom,
                                   mode: .compact,
                                   visualEffect: UIBlurEffect(style: .extraLight),
                                   margins: UIEdgeInsets(top: 10.0, left: 10.0, bottom: 0.0, right: 10.0),
                                   cornerRadius: 10.0,
                                   maskedCorners: [.layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner],
                                   borderColor: UIColor.gray.withAlphaComponent(0.5),
                                   resizeHandleColor: UIColor.gray.withAlphaComponent(0.3),
                                   resizeHandleBackgroundColor: .white,
                                   separatorColor: UIColor.gray.withAlphaComponent(0.5),
                                   isGestureBasedResizingEnabled: false)
    }
}
