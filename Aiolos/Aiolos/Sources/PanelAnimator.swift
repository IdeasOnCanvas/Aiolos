//
//  PanelAnimator.swift
//  Aiolos
//
//  Created by Matthias Tretter on 13/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Foundation


/// Internal class used to drive animations of the Panel
final class PanelAnimator {

    struct Constants {
        struct Animation {
            static let duration: TimeInterval = 0.42
            static let damping: CGFloat = 0.8
        }
    }

    private unowned let panel: PanelViewController

    var animateChanges: Bool = true
    var transitionCoordinatorQueuedAnimation: PanelTransitionCoordinator.Animation?

    // MARK: - Lifecycle

    init(panel: PanelViewController) {
        self.panel = panel
    }

    // MARK: - PanelAnimator

    func animateIfNeeded(_ changes: @escaping () -> Void) {
        let parentView = self.panel.parent?.view
        parentView?.layoutIfNeeded()

        let animator = UIViewPropertyAnimator(duration: Constants.Animation.duration, dampingRatio: Constants.Animation.damping, animations: {
            changes()
            parentView?.layoutIfNeeded()
        })

        // we might have enqueued animations from a transition coordinator, perform them along the main changes
        if let transitionCoordinatorQueuedAnimation = self.transitionCoordinatorQueuedAnimation {
            animator.addAnimations(transitionCoordinatorQueuedAnimation.animations)
            transitionCoordinatorQueuedAnimation.completion.map(animator.addCompletion)
            self.transitionCoordinatorQueuedAnimation = nil
        }

        animator.startAnimation()

        // if we don't want to animate, perform changes without directly
        let shouldAnimate = self.animateChanges && self.panel.isVisible
        if shouldAnimate == false {
            animator.fractionComplete = 1.0
        }
    }

    func performWithoutAnimation(_ changes: () -> Void) {
        let animateBefore = self.animateChanges
        self.animateChanges = false
        defer { self.animateChanges = animateBefore }

        UIView.performWithoutAnimation(changes)
    }

    func notifyDelegateOfTransition(to mode: Panel.Configuration.Mode) {
        guard let animationDelegate = self.panel.animationDelegate else { return }

        let transitionCoordinator = PanelTransitionCoordinator(animator: self)
        animationDelegate.panel(self.panel, willTransitionTo: mode, with: transitionCoordinator)
    }
}
