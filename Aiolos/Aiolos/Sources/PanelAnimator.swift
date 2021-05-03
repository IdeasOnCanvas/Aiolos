//
//  PanelAnimator.swift
//  Aiolos
//
//  Created by Matthias Tretter on 13/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import UIKit


/// Internal class used to drive animations of the Panel
final class PanelAnimator {

    private unowned let panel: Panel
    private var animator: UIViewPropertyAnimator?

    var animateChanges: Bool = true
    var transitionCoordinatorQueuedAnimations: [PanelTransitionCoordinator.Animation] = []
    var isMovingToParent: Bool = false
    var isMovingFromParent: Bool = false

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
        self.performChanges({ UIView.performWithoutAnimation(changes) }, animated: false, timing: UISpringTimingParameters())
    }

    func stopCurrentAnimation() {
        defer { self.animator = nil }
        guard let animator = self.animator else { return }
        guard animator.state == .active else { return }

        animator.pauseAnimation()
        animator.fractionComplete = 1.0
        animator.stopAnimation(false)
        animator.finishAnimation(at: .end)
    }

    func notifyDelegateOfResizing() {
        guard let resizeDelegate = self.panel.resizeDelegate else { return }
        guard self.panel.isVisible else { return }

        resizeDelegate.panelDidStartResizing(self.panel)
    }

    func notifyDelegateOfTransition(to size: CGSize) {
        guard let resizeDelegate = self.panel.resizeDelegate else { return }
        guard self.panel.isVisible else { return }

        resizeDelegate.panel(self.panel, willResizeTo: size)
        if let contentViewController = self.panel.contentViewController as? PanelResizeDelegate {
            contentViewController.panel(self.panel, willResizeTo: size)
        }
    }

    func notifyDelegateOfTransition(from oldMode: Panel.Configuration.Mode?, to newMode: Panel.Configuration.Mode) {
        guard let resizeDelegate = self.panel.resizeDelegate else { return }
        guard self.panel.isVisible else { return }

        let transitionCoordinator = PanelTransitionCoordinator(animator: self, direction: .vertical)
        resizeDelegate.panel(self.panel, willTransitionFrom: oldMode, to: newMode, with: transitionCoordinator)
        if let contentViewController = self.panel.contentViewController as? PanelResizeDelegate {
            contentViewController.panel(self.panel, willTransitionFrom: oldMode, to: newMode, with: transitionCoordinator)
        }
    }

    func askDelegateAboutStartOfMove() -> Bool {
        guard let repositionDelegate = self.panel.repositionDelegate else { return false }
        guard self.panel.isVisible else { return false }

        return repositionDelegate.panelCanStartMoving(self.panel)
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

    func addToParent(with size: CGSize, transition: Panel.Transition, completion: @escaping () -> Void) {
        guard self.isMovingToParent == false else { return }

        self.isMovingToParent = true
        self.stopCurrentAnimation()
        self.prepare(for: transition, size: size)
        self.performWithoutAnimation {
            self.panel.constraints.updateSizeConstraints(for: size)
            self.panel.constraints.updatePositionConstraints(for: self.panel.configuration.position, margins: self.panel.configuration.margins)
        }

        self.notifyDelegateOfTransition(to: size)
        self.notifyDelegateOfTransition(from: nil, to: self.panel.configuration.mode)
        self.finalizeTransition(transition) {
            self.isMovingToParent = false
            completion()
        }
    }

    func removeFromParent(transition: Panel.Transition, completion: @escaping () -> Void) {
        guard self.isMovingFromParent == false else { return }

        self.isMovingFromParent = true
        self.stopCurrentAnimation()

        let animator = UIViewPropertyAnimator(duration: Panel.Constants.Animation.duration, timingParameters: UISpringTimingParameters())

        func finish() {
            self.resetPanel()
            self.panel.constraints.updateForPanEndAnimation(to: self.panel.view.bounds.height)
            self.panel.constraints.updateForPanEnd()
            self.isMovingFromParent = false
            completion()
        }

        switch transition {
        case .none:
            finish()
            return

        case .fade:
            animator.addAnimations {
                // this constraints the height during removal transition
                // fixes a visual glitch when the panel is .fullHeight and status bar is hidden as well
                self.panel.constraints.updateForPanStart(with: self.panel.view.frame.size)
                self.panel.view.alpha = 0.0
            }

        case .slide(let edge):
            animator.addAnimations {
                self.panel.constraints.updateForPanStart(with: self.panel.view.frame.size)
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

    func performChanges(_ changes: @escaping () -> Void, animated: Bool, timing: UITimingCurveProvider, completion: (() -> Void)? = nil) {
        guard let parentView = self.panel.parent?.view else { return }

        let changesAndLayout = {
            changes()
            parentView.layoutIfNeeded()
            self.panel.fixLayoutMargins()
        }

        self.stopCurrentAnimation()

        if animated {
            parentView.layoutIfNeeded()

            let animator = UIViewPropertyAnimator(duration: Panel.Constants.Animation.duration, timingParameters: timing)
            animator.addAnimations(changesAndLayout)
            if let completion = completion {
                animator.addCompletion { _ in completion() }
            }

            // we might have enqueued animations from a transition coordinator, perform them along the main changes
            self.addQueuedAnimations(to: animator)

            animator.startAnimation()
            self.animator = animator
        } else {
            // if we don't want to animate, perform changes directly and manually call alongside-"animations" and completion
            changesAndLayout()
            self.manuallyCallQueuedAnimations()
            completion?()
        }
    }

    func manuallyCallQueuedAnimations() {
        let queuedAnimations = self.transitionCoordinatorQueuedAnimations
        // reset the queued animations immediately, in case any queued block has side-effects
        // that trigger animations again
        self.transitionCoordinatorQueuedAnimations = []

        // first call animation blocks
        queuedAnimations.forEach { $0.animations() }
        // then completion blocks
        queuedAnimations.forEach { $0.completion?(.end) }
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
        self.animateChanges = transition.isAnimated

        switch transition {
        case .none:
            self.resetPanel()
        case .fade:
            self.panel.view.alpha = 0.0
        case .slide(let direction):
            self.panel.view.transform = self.transform(for: direction, size: size)
        }
    }

    func resetPanel() {
        self.panel.view.alpha = 1.0
        self.panel.view.transform = .identity
        self.panel.fixLayoutMargins()
        // Hack on top of a hack: delaying to the next run-loop fixes a glitch,
        // when adding the panel to a parent animated within an unsafe area
        DispatchQueue.main.async { [weak self] in
            self?.panel.fixLayoutMargins()
        }
    }

    func finalizeTransition(_ transition: Panel.Transition, completion: @escaping () -> Void) {
        switch transition {
        case .none:
            self.animator = nil
            self.resetPanel()
            self.manuallyCallQueuedAnimations()
            completion()
        case .fade, .slide:
            let animator = UIViewPropertyAnimator(duration: Panel.Constants.Animation.duration, timingParameters: UISpringTimingParameters())
            animator.addAnimations(self.resetPanel)
            animator.addCompletion { _ in completion() }
            self.addQueuedAnimations(to: animator)

            animator.startAnimation()
            self.animator = animator
        }

        self.animateChanges = true
    }
}
