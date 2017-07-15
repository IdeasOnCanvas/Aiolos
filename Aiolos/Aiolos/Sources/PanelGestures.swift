//
//  PanelGestures.swift
//  Aiolos
//
//  Created by Matthias Tretter on 14/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Foundation


/// Manages Gestures added to the Panel
final class PanelGestures {

    private let panel: PanelViewController
    private var modeWhenPanStarted: Panel.Configuration.Mode?

    // MARK: - Lifecycle

    init(panel: PanelViewController) {
        self.panel = panel
    }

    // MARK: - PanelGestures

    func install() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        self.panel.view.addGestureRecognizer(pan)
    }
}

// MARK: - Private

private extension PanelGestures {

    @objc
    func handlePan(_ pan: UIPanGestureRecognizer) {
        switch pan.state {
        case .began:
            self.handlePanStarted(pan)
        case .changed:
            self.handlePanChanged(pan)
        case .ended:
            self.handlePanEnded(pan)
        case .cancelled:
            self.handlePanCanceled(pan)
        default:
            break
        }
    }

    func handlePanStarted(_ pan: UIPanGestureRecognizer) {
        guard let heightConstraint = self.panel.constraints.heightConstraint else { return }

        // remember initial state
        self.modeWhenPanStarted = self.panel.configuration.mode
        // the normal height constraint for .fullHeight can have a higher constant, but the actual height is constrained by the safeAreaInsets
        heightConstraint.constant = self.panel.view.frame.height
    }

    func handlePanChanged(_ pan: UIPanGestureRecognizer) {
        guard let heightConstraint = self.panel.constraints.heightConstraint else { return }

        let translation = pan.translation(in: self.panel.view)
        pan.setTranslation(.zero, in: self.panel.view)

        // TODO: notify delegate during resizing
        heightConstraint.constant -= translation.y
        self.panel.parent?.view.layoutIfNeeded()
    }

    func handlePanEnded(_ pan: UIPanGestureRecognizer) {
//        let velocity = pan.velocity(in: self.panel.view)
//        let initialVelocity = CGVector(dx: velocity.x / 100.0, dy: velocity.y / 100.0)
//        let spring = UISpringTimingParameters(dampingRatio: 0.8, initialVelocity: initialVelocity)
//
//        self.panAnimator?.continueAnimation(withTimingParameters: spring, durationFactor: 1.0)

        // TODO: animate with correct springs
        let targetMode = self.targetMode(for: pan)
        self.panel.constraints.updateSizeConstraints(for: targetMode)
        self.panel.configuration.mode = targetMode

        self.cleanup()
    }

    func handlePanCanceled(_ pan: UIPanGestureRecognizer) {
        guard let modeWhenPanStarted = self.modeWhenPanStarted else { return }

        self.panel.constraints.updateSizeConstraints(for: modeWhenPanStarted)
        self.cleanup()
    }

    func targetMode(for pan: UIPanGestureRecognizer) -> Panel.Configuration.Mode {
        guard let heightConstraint = self.panel.constraints.heightConstraint else { return .expanded }

        // TODO: Take velocity + translation into account
        let currentHeight = heightConstraint.constant
        let heightCollapsed = self.panel.size(for: .collapsed).height
        let heightExpanded = self.panel.size(for: .expanded).height

        if abs(currentHeight - heightCollapsed) < 100.0 {
            return .collapsed
        } else if abs(currentHeight - heightExpanded) < 100.0 {
            return .expanded
        } else {
            return .fullHeight
        }
    }

    func cleanup() {
        self.modeWhenPanStarted = nil
    }
}
