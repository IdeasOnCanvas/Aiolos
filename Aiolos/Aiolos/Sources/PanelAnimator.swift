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

    private unowned let panel: PanelViewController

    var animateChanges: Bool = true
    var transitionCoordinatorQueuedAnimation: PanelTransitionCoordinator.Animation?

    // MARK: - Lifecycle

    init(panel: PanelViewController) {
        self.panel = panel
    }

    // MARK: - PanelAnimator

    func animateIfNeeded(_ changes: @escaping () -> Void) {
        let shouldAnimate = self.animateChanges && self.panel.isVisible
        let duration = shouldAnimate ? 0.42 : 0.0
        let parentView = self.panel.parent?.view
        parentView?.layoutIfNeeded()

        // we might have enqueued animations from a transition coordinator, perform them along the main changes
        let queuedAnimation = self.transitionCoordinatorQueuedAnimation?.animations
        let wrappedChanges = {
            changes()
            queuedAnimation?()
            parentView?.layoutIfNeeded()
        }

        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 0.8, animations: {
            if shouldAnimate {
                wrappedChanges()
            } else {
                UIView.performWithoutAnimation(wrappedChanges)
            }
        })

        if let completion = self.transitionCoordinatorQueuedAnimation?.completion {
            animator.addCompletion(completion)
        }

        self.transitionCoordinatorQueuedAnimation = nil
        animator.startAnimation()
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
