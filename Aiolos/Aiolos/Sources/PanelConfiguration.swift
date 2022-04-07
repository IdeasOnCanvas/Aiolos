//
//  PanelConfiguration.swift
//  Aiolos
//
//  Created by Matthias Tretter on 11/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import UIKit


/// Allows to configure the appearance of the floating panel
public extension Panel {

    enum Constants {
        public enum Animation {
            public static let duration: TimeInterval = 0.42
        }
    }

    struct Configuration {
        public typealias Mode = _PanelMode
        public typealias Edge = _PanelEdge
        public typealias Position = _PanelPosition
        public typealias PositionLogic = _PanelPositionLogic
        public typealias KeyboardBehaviour = _PanelKeyboardBehaviour

        public struct GestureResizingMode: OptionSet {
            public let rawValue: Int

            public init(rawValue: Int) {
                self.rawValue = rawValue
            }

            public static let handle = GestureResizingMode(rawValue: 1 << 0)
            public static let content = GestureResizingMode(rawValue: 1 << 1)
            public static let byTouch = GestureResizingMode(rawValue: 1 << 2)
            public static let byPointerScroll = GestureResizingMode(rawValue: 1 << 3)
        }

        public enum ResizeHandleMode {
            case hidden
            case visible(foregroundColor: UIColor, backgroundColor: UIColor, adjustAppearanceWhileResizing: Bool = true)
        }

        public struct Appearance {
            public var visualEffect: UIVisualEffect?
            public var borderColor: UIColor
            public var separatorColor: UIColor
            public var cornerRadius: CGFloat
            public var maskedCorners: CACornerMask
            public var shadowColor: UIColor
            public var shadowOpacity: Float
            public var shadowOffset: UIOffset
            public var shadowRadius: CGFloat
            public var resizeHandle: ResizeHandleMode
        }

        public var position: Position
        public var positionLogic: [Edge: PositionLogic]
        public var supportedPositions: Set<Position>
        public var margins: NSDirectionalEdgeInsets
        public var mode: Mode
        public var supportedModes: Set<Mode>
        public var gestureResizingMode: GestureResizingMode
        public var keyboardBehaviour: KeyboardBehaviour
        public var appearance: Appearance
    }
}

public extension Panel.Configuration {

    static var `default`: Panel.Configuration {
        let appearance = Appearance(visualEffect: UIBlurEffect(style: .extraLight),
                                    borderColor: UIColor.gray.withAlphaComponent(0.5),
                                    separatorColor: UIColor.gray.withAlphaComponent(0.5),
                                    cornerRadius: 10.0,
                                    maskedCorners: [.layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner],
                                    shadowColor: .black,
                                    shadowOpacity: 0.15,
                                    shadowOffset: UIOffset(horizontal: 0.0, vertical: 1.0),
                                    shadowRadius: 3.0,
                                    resizeHandle: .visible(foregroundColor: UIColor.gray.withAlphaComponent(0.3), backgroundColor: .white))

        return Panel.Configuration(position: .bottom,
                                   positionLogic: PositionLogic.respectAllSafeAreas,
                                   supportedPositions: [.bottom],
                                   margins: NSDirectionalEdgeInsets(top: 10.0, leading: 10.0, bottom: 0.0, trailing: 10.0),
                                   mode: .compact,
                                   supportedModes: [.compact, .expanded, .fullHeight],
                                   gestureResizingMode: .includingContent,
                                   keyboardBehaviour: .avoiding,
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

        // position must be included in `supportedPositions`
        validated.supportedPositions.insert(validated.position)

        // positionLogic must be defined for every edge
        for edge in [Edge.top, .leading, .bottom, .trailing] where validated.positionLogic[edge] == nil {
            validated.positionLogic[edge] = .respectSafeArea
        }

        return validated
    }
}

// MARK: - Inner Types

// swiftlint:disable type_name

// we define these types here and use a typealias inside the Panel, to make them visible to ObjC and Swift
@objc(PanelMode)
public enum _PanelMode: Int {
    case minimal
    case compact
    case expanded
    case fullHeight
}

@objc(PanelEdge)
public enum _PanelEdge: Int {
    case top
    case leading
    case bottom
    case trailing
}

@objc(PanelPosition)
public enum _PanelPosition: Int {
    case bottom
    case leadingBottom
    case trailingBottom
}

@objc(PanelPositionLogic)
public enum _PanelPositionLogic: Int {
    case respectSafeArea
    case ignoreSafeArea

    public static var respectAllSafeAreas: [Panel.Configuration.Edge: Panel.Configuration.PositionLogic] {
        return [.top: .respectSafeArea, .leading: .respectSafeArea, .bottom: .respectSafeArea, .trailing: .respectSafeArea]
    }

    public static var ignoreAllSafeAreas: [Panel.Configuration.Edge: Panel.Configuration.PositionLogic] {
        return [.top: .ignoreSafeArea, .leading: .ignoreSafeArea, .bottom: .ignoreSafeArea, .trailing: .ignoreSafeArea]
    }
}

@objc(PanelKeyboardBehaviour)
public enum _PanelKeyboardBehaviour: Int {
    /// the panel automatically adjusts its frame s.t. it doesn't overlap the software keyboard
    case avoiding
    /// the panel ignores any keyboard appearance and keeps its frame independent
    case ignoring
}

extension _PanelPositionLogic {

    func applyingInsets(of view: UIView, to insets: NSDirectionalEdgeInsets, edge: Panel.Configuration.Edge) -> NSDirectionalEdgeInsets {
        var insets = insets

        switch (self, edge) {
        case (.ignoreSafeArea, _):
            break

        case (.respectSafeArea, .top):
            insets.top = view.safeAreaInsets.top
        case (.respectSafeArea, .leading):
            insets.leading = view.isRTL ? view.safeAreaInsets.right : view.safeAreaInsets.left
        case (.respectSafeArea, .bottom):
            insets.bottom = view.safeAreaInsets.bottom
        case (.respectSafeArea, .trailing):
            insets.trailing = view.isRTL ? view.safeAreaInsets.left : view.safeAreaInsets.right
        }

        return insets
    }
}

extension Panel.Configuration.GestureResizingMode {

    public static let includingContent: Self = [.handle, .content, .byTouch, .byPointerScroll]
    public static let excludingContent: Self = [.handle, .byTouch, .byPointerScroll]
    var isPanningByTouchEnabled: Bool { self.contains(.byTouch) && (self.contains(.content) || self.contains(.handle)) }
    var isScrollingByPointerEnabled: Bool { self.contains(.byPointerScroll) && (self.contains(.content) || self.contains(.handle)) }
}
