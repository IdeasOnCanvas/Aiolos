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

// MARK: - Transitions

extension PanelAnimator {

    func transitionToParent(with size: CGSize, transition: Panel.Transition) {
        self.prepare(for: transition, size: size)
        self.performWithoutAnimation {
            self.notifyDelegateOfTransition(to: size)
            self.notifyDelegateOfTransition(to: self.panel.configuration.mode)
            self.panel.constraints.updateSizeConstraints(for: size)
            self.panel.constraints.updatePositionConstraints(for: self.panel.configuration.position, margins: self.panel.configuration.margins)
        }
        self.finalizeTransition(transition)
    }

    func removeFromParent(transition: Panel.Transition, completion: @escaping () -> Void) {
        let animator = UIViewPropertyAnimator(duration: Constants.Animation.duration, dampingRatio: Constants.Animation.damping)

        switch transition {
        case .none:
            completion()
            return

        case .fade:
            animator.addAnimations {
                self.panel.view.alpha = 0.0
            }

        case .slide(let edge):
            animator.addAnimations {
                self.panel.view.transform = self.transform(for: edge, size: self.panel.view.frame.size)
            }
        }

        animator.addCompletion { _ in
            completion()
            // reset values to normal values
            self.finalizeTransition(.none)
        }

        animator.startAnimation()
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

    func prepare(for transition: Panel.Transition, size: CGSize) {
        switch transition {
        case .none:
            break
        case .fade:
            self.panel.view.alpha = 0.0
        case .slide(let direction):
            self.panel.view.transform = self.transform(for: direction, size: size)
            break
        }
    }

    func finalizeTransition(_ transition: Panel.Transition) {
        let changes = {
            self.panel.view.alpha = 1.0
            self.panel.view.transform = .identity
        }

        switch transition {
        case .none:
            changes()

        case .fade:
            fallthrough
        case .slide(_):
            let animator = UIViewPropertyAnimator(duration: Constants.Animation.duration, dampingRatio: Constants.Animation.damping, animations: changes)
            animator.startAnimation()
        }
    }

    func transform(for direction: Panel.Direction, size: CGSize) -> CGAffineTransform {
        let isRTL = self.panel.view.effectiveUserInterfaceLayoutDirection == .rightToLeft
        let position = self.panel.configuration.position
        let margins = self.panel.configuration.margins
        let animateToLeft = isRTL != (position == .leadingBottom)

        switch direction {
        case .horizontal:
            let translationX = animateToLeft ? -(size.width + margins.left) : size.width + margins.right
            return CGAffineTransform(translationX: translationX, y: 0.0)
        case .vertical:
            return CGAffineTransform(translationX: 0.0, y: size.height + margins.bottom)
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
