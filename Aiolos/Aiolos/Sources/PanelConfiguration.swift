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
        public var supportedModes: [Mode]
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
                                   supportedModes: [.compact, .expanded, .fullHeight],
                                   visualEffect: UIBlurEffect(style: .extraLight),
                                   margins: UIEdgeInsets(top: 10.0, left: 10.0, bottom: 0.0, right: 10.0),
                                   cornerRadius: 10.0,
                                   maskedCorners: [.layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner],
                                   borderColor: UIColor.gray.withAlphaComponent(0.5),
                                   resizeHandleColor: UIColor.gray.withAlphaComponent(0.3),
                                   resizeHandleBackgroundColor: .white,
                                   separatorColor: UIColor.gray.withAlphaComponent(0.5),
                                   isGestureBasedResizingEnabled: true)
    }
}

extension Panel.Configuration {

    /// Makes sure that all specified values of the Panel are correct
    func validated() -> Panel.Configuration {
        var validated = self

        if validated.supportedModes.isEmpty {
            // can't have an empty `supportedModes` array
            validated.supportedModes.append(validated.mode)
        } else {
            // mode must be included in `supportedModes`
            if validated.supportedModes.contains(validated.mode) == false {
                // if we try to set .expanded we prefer to fall back to .fullHeight rather than  .compact
                if validated.mode == .expanded && validated.supportedModes.contains(.fullHeight) {
                    validated.mode = .fullHeight
                } else {
                    validated.mode = validated.supportedModes[0]
                }
            }
        }

        return validated
    }
}
