//
//  PanelTransition.swift
//  Aiolos
//
//  Created by Matthias Tretter on 08/08/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import UIKit


/// Enum that can be used to modify the panel's initial appearance/disappearance transition
public extension Panel {

    enum Direction {
        case horizontal
        case vertical
    }

    enum Transition {
        case none
        case fade
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
        case (.slide, .slide): // we ignore the direction intentionally
            return true
        default:
            return false
        }
    }
}
