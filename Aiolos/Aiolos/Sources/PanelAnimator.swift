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
    var isTransitioningToParent: Bool = false
    var isTransitioningFromParent: Bool = false

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

    func stopCurrentAnimation() {
        defer { self.animator = nil }
        guard let animator = self.animator else { return }
        guard animator.state == .active else { return }

        animator.stopAnimation(false)
        animator.finishAnimation(at: .end)
    }

    func notifyDelegateOfResizing() {
        guard let resizeDelegate = self.panel.resizeDelegate else { return }
        guard self.panel.isVisible else { return }

        resizeDelegate.panelDidStartResizing(self.panel)
    }

    func notifyDelegateOfTransition(to size: CGSize) {
        guard let animationDelegate = self.panel.resizeDelegate else { return }
        guard self.panel.isVisible else { return }

        animationDelegate.panel(self.panel, willResizeTo: size)
        if let contentViewController = self.panel.contentViewController as? PanelResizeDelegate {
            contentViewController.panel(self.panel, willResizeTo: size)
        }
    }

    func notifyDelegateOfTransition(from oldMode: Panel.Configuration.Mode?, to newMode: Panel.Configuration.Mode) {
        guard let animationDelegate = self.panel.resizeDelegate else { return }
        guard self.panel.isVisible else { return }

        let transitionCoordinator = PanelTransitionCoordinator(animator: self, direction: .vertical)
        animationDelegate.panel(self.panel, willTransitionFrom: oldMode, to: newMode, with: transitionCoordinator)
        if let contentViewController = self.panel.contentViewController as? PanelResizeDelegate {
            contentViewController.panel(self.panel, willTransitionFrom: oldMode, to: newMode, with: transitionCoordinator)
        }
    }

    func notifyDelegateOfRepositioning() {
        guard let repositionDelegate = self.panel.repositionDelegate else { return }
        guard self.panel.isVisible else { return }

        repositionDelegate.panelDidStartMoving(self.panel)
    }

    func askDelegateAboutMove(to frame: CGRect) -> Bool {
        guard let repositionDelegate = self.panel.repositionDelegate else { return false }
        guard self.panel.isVisible else { return false }
        
        return repositionDelegate.panel(self.panel, willMoveTo: frame)
    }
    
    func notifyDelegateOfMove(to endFrame: CGRect, context: PanelRepositionContext) -> PanelRepositionContext.Instruction {
        guard let repositionDelegate = self.panel.repositionDelegate else { return .none }
        guard self.panel.isVisible else { return .none }

        return repositionDelegate.panel(self.panel, didStopMoving: endFrame, with: context)
    }

    func notifyDelegateOfMove(from oldPosition: Panel.Configuration.Position, to newPosition: Panel.Configuration.Position) {
        guard let repositionDelegate = self.panel.repositionDelegate else { return }
        guard self.panel.isVisible else { return }

        let transitionCoordinator = PanelTransitionCoordinator(animator: self, direction: .horizontal)
        repositionDelegate.panel(self.panel, willTransitionFrom: oldPosition, to: newPosition, with: transitionCoordinator)
    }

    func notifyDelegateOfHide() {
        guard let repositionDelegate = self.panel.repositionDelegate else { return }
        guard self.panel.isVisible else { return }

        let transitionCoordinator = PanelTransitionCoordinator(animator: self, direction: .horizontal)
        repositionDelegate.panelWillTransitionToHiddenState(self.panel, with: transitionCoordinator)
    }
}

// MARK: - Transitions

extension PanelAnimator {

    func transitionToParent(with size: CGSize, transition: Panel.Transition, completion: @escaping () -> Void) {
        guard self.isTransitioningToParent == false else { return }

        self.isTransitioningToParent = true
        self.stopCurrentAnimation()
        self.prepare(for: transition, size: size)
        self.performWithoutAnimation {
            self.panel.constraints.updateSizeConstraints(for: size)
            self.panel.constraints.updatePositionConstraints(for: self.panel.configuration.position, margins: self.panel.configuration.margins)
        }

        self.notifyDelegateOfTransition(to: size)
        self.notifyDelegateOfTransition(from: nil, to: self.panel.configuration.mode)
        self.finalizeTransition(transition) {
            self.isTransitioningToParent = false
            completion()
        }
    }

    func removeFromParent(transition: Panel.Transition, completion: @escaping () -> Void) {
        guard self.isTransitioningFromParent == false else { return }

        self.isTransitioningFromParent = true
        self.stopCurrentAnimation()

        let animator = UIViewPropertyAnimator(duration: Constants.Animation.duration, timingParameters: UISpringTimingParameters())

        func finish() {
            completion()
            self.resetPanel()
            self.isTransitioningFromParent = false
        }

        switch transition {
        case .none:
            finish()
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
            finish()
        }

        animator.startAnimation()
        self.animator = animator
    }

    func transform(for direction: Panel.Direction, size: CGSize) -> CGAffineTransform {
        guard let safeAreaInsets = self.panel.parent?.view.safeAreaInsets else { return .identity }

        let position = self.panel.configuration.position
        let margins = self.panel.configuration.margins
        let animateToLeft = self.panel.view.isRTL != (position == .leadingBottom)
        
        switch direction {
        case .horizontal:
            let translationX = animateToLeft ? -(size.width + margins.leading) : size.width + margins.trailing
            return CGAffineTransform(translationX: translationX, y: 0.0)
        case .vertical:
            return CGAffineTransform(translationX: 0.0, y: size.height + margins.bottom + safeAreaInsets.bottom)
        }
    }
}

// MARK: - Private

private extension PanelAnimator {

    struct Constants {
        struct Animation {
            static let duration: TimeInterval = 0.42
        }
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
            animator.stopAnimation(false)
            animator.finishAnimation(at: .end)
        } else {
            animator.startAnimation()
            self.animator = animator
        }
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
        self.animator = animator
    }
}
