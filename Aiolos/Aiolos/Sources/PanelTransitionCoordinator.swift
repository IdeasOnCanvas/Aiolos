//
//  PanelTransitionCoordinator.swift
//  Aiolos
//
//  Created by Matthias Tretter on 11/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Foundation
import UIKit


/// This coordinator can be used to animate things alongside the movement of the Panel
public final class PanelTransitionCoordinator {
    
    private unowned let animator: PanelAnimator

    // MARK: - Properties

    public let direction: Panel.Direction
    public var isAnimated: Bool { return self.animator.animateChanges }
    
    // MARK: - Lifecycle

    init(animator: PanelAnimator, direction: Panel.Direction) {
        self.animator = animator
        self.direction = direction
    }

    // MARK: - PanelTransitionCoordinator

    public func animateAlongsideTransition(_ animations: @escaping () -> Void, completion: ((UIViewAnimatingPosition) -> Void)? = nil) {
        self.animator.transitionCoordinatorQueuedAnimations.append(Animation(animations: animations, completion: completion))
    }
}

// MARK: - PanelTransitionCoordinator.Animation

extension PanelTransitionCoordinator {

    struct Animation {
        let animations: () -> Void
        let completion: ((UIViewAnimatingPosition) -> Void)?
    }
}
