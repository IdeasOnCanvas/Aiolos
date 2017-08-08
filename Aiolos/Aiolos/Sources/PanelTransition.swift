//
//  PanelTransition.swift
//  Aiolos
//
//  Created by Matthias Tretter on 08/08/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Foundation


/// Enum that can be used to modify the panel's initial appearance/disappearance transition
public extension Panel {

    public enum Direction {
        case horizontal
        case vertical
    }

    public enum Transition {
        case none
        case fade
        case slide(direction: Direction)
    }
}
