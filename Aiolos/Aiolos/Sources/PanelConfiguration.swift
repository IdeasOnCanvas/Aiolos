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

        public enum PositionLogic: Int {
            case respectSafeArea
            case ignoreSafeArea
        }

        public enum Mode: Int {
            case minimal
            case compact
            case expanded
            case fullHeight
        }

        public enum GestureResizingMode: Int {
            case disabled
            case excludingContent
            case includingContent
        }

        public struct Appearance {
            public var visualEffect: UIVisualEffect?
            public var borderColor: UIColor
            public var resizeHandleColor: UIColor
            public var resizeHandleBackgroundColor: UIColor
            public var separatorColor: UIColor
            public var cornerRadius: CGFloat
            public var maskedCorners: CACornerMask
            public var shadowColor: UIColor
            public var shadowOpacity: Float
            public var shadowOffset: UIOffset
        }

        public var position: Position
        public var positionLogic: PositionLogic
        public var margins: NSDirectionalEdgeInsets
        public var mode: Mode
        public var supportedModes: Set<Mode>
        public var gestureResizingMode: GestureResizingMode
        public var appearance: Appearance
    }
}

public extension Panel.Configuration {

    static var `default`: Panel.Configuration {
        let appearance = Appearance(visualEffect: UIBlurEffect(style: .extraLight),
                                    borderColor: UIColor.gray.withAlphaComponent(0.5),
                                    resizeHandleColor: UIColor.gray.withAlphaComponent(0.3),
                                    resizeHandleBackgroundColor: .white,
                                    separatorColor: UIColor.gray.withAlphaComponent(0.5),
                                    cornerRadius: 10.0,
                                    maskedCorners: [.layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner],
                                    shadowColor: .black,
                                    shadowOpacity: 0.15,
                                    shadowOffset: UIOffset(horizontal: 0.0, vertical: 1.0))

        return Panel.Configuration(position: .bottom,
                                   positionLogic: .respectSafeArea,
                                   margins: NSDirectionalEdgeInsets(top: 10.0, leading: 10.0, bottom: 0.0, trailing: 10.0),
                                   mode: .compact,
                                   supportedModes: [.compact, .expanded, .fullHeight],
                                   gestureResizingMode: .includingContent,
                                   appearance: appearance)
    }
}

extension Panel.Configuration {

    /// Makes sure that all specified values of the Panel are correct
    func validated() -> Panel.Configuration {
        var validated = self

        if validated.supportedModes.isEmpty {
            // can't have an empty `supportedModes` array
            validated.supportedModes.insert(validated.mode)
        } else {
            // mode must be included in `supportedModes`
            if validated.supportedModes.contains(validated.mode) == false {
                let fallbackModes: [Mode: Mode] = [
                    .minimal: .compact,
                    .compact: .minimal,
                    .expanded: .fullHeight,
                    .fullHeight: .expanded
                ]

                if let fallbackMode = fallbackModes[validated.mode], validated.supportedModes.contains(fallbackMode) {
                    validated.mode = fallbackMode
                } else {
                    validated.mode = validated.supportedModes.first!
                }
            }
        }

        return validated
    }
}
