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
    private var animator: UIViewPropertyAnimator?

    var animateChanges: Bool = true
    var transitionCoordinatorQueuedAnimations: [PanelTransitionCoordinator.Animation] = []

    // MARK: - Lifecycle

    init(panel: Panel) {
        self.panel = panel
    }

    // MARK: - PanelAnimator

    func animateIfNeeded(_ changes: @escaping () -> Void) {
        let shouldAnimate = self.animateChanges && self.panel.isVisible
        let timing = UISpringTimingParameters()

        self.performChanges(changes, animated: shouldAnimate, timing: timing)
    }

    func animateWithTiming(_ timing: UITimingCurveProvider, animations: @escaping () -> Void, completion: (() -> Void)? = nil) {
        self.performChanges(animations, animated: true, timing: timing, completion: completion)
    }

    func performWithoutAnimation(_ changes: @escaping () -> Void) {
        let animateBefore = self.animateChanges
        self.animateChanges = false
        defer { self.animateChanges = animateBefore }

        self.animateIfNeeded {
            UIView.performWithoutAnimation {
                changes()
                self.panel.parent?.view?.layoutIfNeeded()
            }
        }
    }

    func notifyDelegateOfTransition(to size: CGSize) {
        guard let animationDelegate = self.panel.animationDelegate else { return }
        guard self.panel.isVisible else { return }

        animationDelegate.panel(self.panel, willTransitionTo: size)
        if let contentViewController = self.panel.contentViewController as? PanelAnimationDelegate {
            contentViewController.panel(self.panel, willTransitionTo: size)
        }
    }

    func notifyDelegateOfTransition(from oldMode: Panel.Configuration.Mode?, to newMode: Panel.Configuration.Mode) {
        guard let animationDelegate = self.panel.animationDelegate else { return }
        guard self.panel.isVisible else { return }

        let transitionCoordinator = PanelTransitionCoordinator(animator: self)
        animationDelegate.panel(self.panel, willTransitionFrom: oldMode, to: newMode, with: transitionCoordinator)
        if let contentViewController = self.panel.contentViewController as? PanelAnimationDelegate {
            contentViewController.panel(self.panel, willTransitionFrom: oldMode, to: newMode, with: transitionCoordinator)
        }
    }
}

// MARK: - Transitions

extension PanelAnimator {

    func transitionToParent(with size: CGSize, transition: Panel.Transition, completion: @escaping () -> Void) {
        self.stopCurrentAnimation()
        self.prepare(for: transition, size: size)
        self.performWithoutAnimation {
            self.panel.constraints.updateSizeConstraints(for: size)
            self.panel.constraints.updatePositionConstraints(for: self.panel.configuration.position, margins: self.panel.configuration.margins)
        }

        self.notifyDelegateOfTransition(to: size)
        self.notifyDelegateOfTransition(from: nil, to: self.panel.configuration.mode)
        self.finalizeTransition(transition, completion: completion)
    }

    func removeFromParent(transition: Panel.Transition, completion: @escaping () -> Void) {
        self.stopCurrentAnimation()

        let animator = UIViewPropertyAnimator(duration: Constants.Animation.duration, timingParameters: UISpringTimingParameters())

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
            self.resetPanel()
        }

        animator.startAnimation()
    }
}

// MARK: - Private

private extension PanelAnimator {

    struct Constants {
        struct Animation {
            static let duration: TimeInterval = 0.42
        }
    }

    func stopCurrentAnimation() {
        defer { self.animator = nil }
        guard let animator = self.animator else { return }
        guard animator.state == .active else { return }

        animator.stopAnimation(true)
    }

    func performChanges(_ changes: @escaping () -> Void, animated: Bool, timing: UITimingCurveProvider, completion: (() -> Void)? = nil) {
        guard let parentView = self.panel.parent?.view else { return }

        self.stopCurrentAnimation()
        if animated == false {
            parentView.layoutIfNeeded()
        }

        let animator = UIViewPropertyAnimator(duration: Constants.Animation.duration, timingParameters: timing)
        animator.addAnimations {
            changes()
            parentView.layoutIfNeeded()
        }
        if let completion = completion {
            animator.addCompletion { _ in completion() }
        }

        // we might have enqueued animations from a transition coordinator, perform them along the main changes
        self.addQueuedAnimations(to: animator)

        // if we don't want to animate, perform changes directly by setting the completion state to 100 %
        if animated == false {
            animator.fractionComplete = 1.0
        }

        animator.startAnimation()
        self.animator = animator
    }

    func addQueuedAnimations(to animator: UIViewPropertyAnimator) {
        self.transitionCoordinatorQueuedAnimations.forEach {
            animator.addAnimations($0.animations)
            if let completion = $0.completion {
                animator.addCompletion(completion)
            }
        }

        self.transitionCoordinatorQueuedAnimations = []
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

    func resetPanel() {
        self.panel.view.alpha = 1.0
        self.panel.view.transform = .identity
    }

    func finalizeTransition(_ transition: Panel.Transition, completion: @escaping () -> Void) {
        let animator = UIViewPropertyAnimator(duration: Constants.Animation.duration, timingParameters: UISpringTimingParameters())
        animator.addAnimations(self.resetPanel)
        animator.addCompletion { _ in completion() }
        self.addQueuedAnimations(to: animator)

        if case .none = transition {
            animator.fractionComplete = 1.0
        }

        animator.startAnimation()
    }

    func transform(for direction: Panel.Direction, size: CGSize) -> CGAffineTransform {
        let isRTL = self.panel.view.effectiveUserInterfaceLayoutDirection == .rightToLeft
        let position = self.panel.configuration.position
        let margins = self.panel.configuration.margins
        let animateToLeft = isRTL != (position == .leadingBottom)

        switch direction {
        case .horizontal:
            let translationX = animateToLeft ? -(size.width + margins.leading) : size.width + margins.trailing
            return CGAffineTransform(translationX: translationX, y: 0.0)
        case .vertical:
            return CGAffineTransform(translationX: 0.0, y: size.height + margins.bottom)
        }
    }
}
