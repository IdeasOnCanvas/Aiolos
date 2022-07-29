//
//  PanelTransition.swift
//  Aiolos
//
//  Created by Matthias Tretter on 08/08/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import UIKit


public extension Panel {

    enum Direction {
        case horizontal
        case vertical
    }

    /// Declares the panel's initial appearance/disappearance transition
    enum Transition {
        /// without animation
        case none
        /// fades in the panel from alpha 0
        case fade
        /// fades and scales in the panel from the provided initial values
        case fadeAndScale(initialAlpha: CGFloat, initialScale: CGFloat)
        /// slides in the panel from the provided direction
        case slide(direction: Direction)

        public var isAnimated: Bool {
            switch self {
            case .none:
                return false
            default:
                return true
            }
        }
    }
}

// MARK: - Equatable

extension Panel.Transition: Equatable {

    public static func == (lhs: Panel.Transition, rhs: Panel.Transition) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.fade, .fade):
            return true
        case (.fadeAndScale, .fadeAndScale): // we ignore the scale factor intentially
            return true
        case (.slide, .slide): // we ignore the direction intentionally
            return true
        default:
            return false
        }
    }
}
