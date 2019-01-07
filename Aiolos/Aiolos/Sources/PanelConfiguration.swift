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

        public enum Edge: Int {
            case top
            case leading
            case bottom
            case trailing
        }

        public enum Position: Int {
            case bottom
            case leadingBottom
            case trailingBottom
        }

        public enum PositionLogic: Int {
            case respectSafeArea
            case ignoreSafeArea

            public static var respectAllSafeAreas: [Edge: PositionLogic] {
                return [.top: .respectSafeArea, .leading: .respectSafeArea, .bottom: .respectSafeArea, .trailing: .respectSafeArea]
            }

            public static var ignoreAllSafeAreas: [Edge: PositionLogic] {
                return [.top: .ignoreSafeArea, .leading: .ignoreSafeArea, .bottom: .ignoreSafeArea, .trailing: .ignoreSafeArea]
            }
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
        
        // TODO: Review the naming and cases
        public enum GesturePositioningMode: Int {
            case disabled
            case enabled
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
        public var positionLogic: [Edge: PositionLogic]
        public var supportedPositions: Set<Position>
        public var margins: NSDirectionalEdgeInsets
        public var mode: Mode
        public var supportedModes: Set<Mode>
        public var gestureResizingMode: GestureResizingMode
        public var appearance: Appearance
        public var gesturePositioningMode: GesturePositioningMode
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
                                   positionLogic: PositionLogic.respectAllSafeAreas,
                                   supportedPositions: [.bottom, .leadingBottom, .trailingBottom],
                                   margins: NSDirectionalEdgeInsets(top: 10.0, leading: 10.0, bottom: 0.0, trailing: 10.0),
                                   mode: .compact,
                                   supportedModes: [.compact, .expanded, .fullHeight],
                                   gestureResizingMode: .includingContent,
                                   appearance: appearance,
                                   gesturePositioningMode: .enabled)
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
        
        if validated.supportedPositions.isEmpty {
            // can't have an empty `supportedPositions` array
            validated.supportedPositions.insert(validated.position)
        } else {
            // position must be included in `supportedPositions`
            if validated.supportedPositions.contains(validated.position) == false {
                let fallbackPositions: [Position: Position] = [
                    .leadingBottom: .bottom,
                    .trailingBottom: .bottom,
                    .bottom: .leadingBottom,
                ]
                
                if let fallbackPosition = fallbackPositions[validated.position], validated.supportedPositions.contains(fallbackPosition) {
                    validated.position = fallbackPosition
                } else {
                    validated.position = validated.supportedPositions.first!
                }
            }
        }

        for edge in [Edge.top, .leading, .bottom, .trailing] where validated.positionLogic[edge] == nil {
            validated.positionLogic[edge] = .respectSafeArea
        }

        return validated
    }
}

extension Panel.Configuration.PositionLogic {

    func applyingInsets(of view: UIView, to insets: NSDirectionalEdgeInsets, edge: Panel.Configuration.Edge) -> NSDirectionalEdgeInsets {
        var insets = insets
        let isRTL = view.effectiveUserInterfaceLayoutDirection == .rightToLeft

        switch (self, edge) {
        case (.ignoreSafeArea, _):
            break

        case (.respectSafeArea, .top):
            insets.top = view.safeAreaInsets.top
        case (.respectSafeArea, .leading):
            insets.leading = isRTL ? view.safeAreaInsets.right : view.safeAreaInsets.left
        case (.respectSafeArea, .bottom):
            insets.bottom = view.safeAreaInsets.bottom
        case (.respectSafeArea, .trailing):
            insets.trailing = isRTL ? view.safeAreaInsets.left : view.safeAreaInsets.right
        }

        return insets
    }
}
