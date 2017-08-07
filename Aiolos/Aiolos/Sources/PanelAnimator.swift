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

    private unowned let panel: Panel

    var animateChanges: Bool = true
    var transitionCoordinatorQueuedAnimations: [PanelTransitionCoordinator.Animation] = []

    // MARK: - Lifecycle

    init(panel: Panel) {
        self.panel = panel
    }

    // MARK: - PanelAnimator

    func animateIfNeeded(_ changes: @escaping () -> Void) {
        guard let parentView = self.panel.parent?.view else { return }

        parentView.layoutIfNeeded()

        let shouldAnimate = self.animateChanges && self.panel.isVisible
        let animator = UIViewPropertyAnimator(duration: Constants.Animation.duration, dampingRatio: Constants.Animation.damping, animations: {
            UIView.performWithoutAnimation(if: shouldAnimate == false) {
                changes()
                parentView.layoutIfNeeded()
            }
        })

        // we might have enqueued animations from a transition coordinator, perform them along the main changes
        self.transitionCoordinatorQueuedAnimations.forEach {
            animator.addAnimations($0.animations)
            if let completion = $0.completion {
                animator.addCompletion(completion)
            }
        }
        self.transitionCoordinatorQueuedAnimations = []

        // if we don't want to animate, perform changes directly by setting the completion state to 100 %
        if shouldAnimate == false {
            animator.fractionComplete = 1.0
        }

        animator.startAnimation()
    }

    func performWithoutAnimation(_ changes: @escaping () -> Void) {
        let animateBefore = self.animateChanges
        self.animateChanges = false
        defer { self.animateChanges = animateBefore }

        self.animateIfNeeded(changes)
    }

    func notifyDelegateOfTransition(to size: CGSize) {
        guard let animationDelegate = self.panel.animationDelegate else { return }

        let transitionCoordinator = PanelTransitionCoordinator(animator: self)
        animationDelegate.panel(self.panel, willTransitionTo: size, with: transitionCoordinator)
    }

    func notifyDelegateOfTransition(to mode: Panel.Configuration.Mode) {
        guard let animationDelegate = self.panel.animationDelegate else { return }

        let transitionCoordinator = PanelTransitionCoordinator(animator: self)
        animationDelegate.panel(self.panel, willTransitionTo: mode, with: transitionCoordinator)
    }
}

// MARK: - Private

private extension PanelAnimator {

    struct Constants {
        struct Animation {
            static let duration: TimeInterval = 0.42
            static let damping: CGFloat = 0.8
        }
    }
}

private extension UIView {

    static func performWithoutAnimation(`if` preventAnimation: Bool, animations: () -> Void) {
        if preventAnimation {
            UIView.performWithoutAnimation(animations)
        } else {
            animations()
        }
    }
}
