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
    private var originalConfiguration: PanelGestures.Configuration?

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

    struct Configuration {
        let mode: Panel.Configuration.Mode
        let size: CGSize
    }

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

        let configuration = PanelGestures.Configuration(mode: self.panel.configuration.mode, size: self.panel.view.frame.size)
        // remember initial state
        self.originalConfiguration = configuration
        // the normal height constraint for .fullHeight can have a higher constant, but the actual height is constrained by the safeAreaInsets
        heightConstraint.constant = configuration.size.height
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
        let targetMode = self.targetMode(for: pan)
        let initialVelocity = self.initialVelocity(for: pan, targetMode: targetMode)

        UIView.animate(withDuration: PanelAnimator.Constants.Animation.duration,
                       delay: 0.0,
                       usingSpringWithDamping: PanelAnimator.Constants.Animation.damping,
                       initialSpringVelocity: initialVelocity,
                       options: [.curveLinear],
                       animations: {
                         self.panel.constraints.updateSizeConstraints(for: targetMode)
                       }, completion: { _ in
                         self.panel.configuration.mode = targetMode
        })

        self.cleanup()
    }

    func handlePanCanceled(_ pan: UIPanGestureRecognizer) {
        guard let originalMode = self.originalConfiguration?.mode else { return }

        self.panel.constraints.updateSizeConstraints(for: originalMode)
        self.cleanup()
    }

    func targetMode(for pan: UIPanGestureRecognizer) -> Panel.Configuration.Mode {
        guard let originalConfiguration = self.originalConfiguration else { return .expanded }
        guard let heightConstraint = self.panel.constraints.heightConstraint else { return originalConfiguration.mode }

        let minVelocity: CGFloat = 20.0
        let velocity = pan.velocity(in: self.panel.view).y
        let heightExpanded = self.panel.size(for: .expanded).height
        let currentHeight = heightConstraint.constant

        let isMovingUpwards = velocity < -minVelocity
        let isMovingDownwards = velocity > minVelocity

        // moving upwards + current size > .expanded -> grow to .fullHeight
        if currentHeight >= heightExpanded && isMovingUpwards { return .fullHeight }
        // moving downwards + current size < .expanded -> shrink to .collapsed
        if currentHeight <= heightExpanded && isMovingDownwards { return .collapsed }
        // moving upwards + current size < .expanded -> grow to .expanded
        if currentHeight <= heightExpanded && isMovingUpwards { return .expanded }
        // moving downwards + current size > .expanded -> shrink to .expanded
        if currentHeight >= heightExpanded && isMovingDownwards { return .expanded }

        // velocity was too small to count as "movement"
        assert(isMovingUpwards == false && isMovingDownwards == false)
        // -> check distance from .expanded mode
        let diffToExpanded = currentHeight - heightExpanded

        if diffToExpanded > 100.0 {
            return .fullHeight
        } else if diffToExpanded < -100.0 {
            return .collapsed
        } else {
            return .expanded
        }
    }

    func initialVelocity(for pan: UIPanGestureRecognizer, targetMode: Panel.Configuration.Mode) -> CGFloat {
        guard let heightConstraint = self.panel.constraints.heightConstraint else { return 0.0 }

        let velocity = pan.velocity(in: self.panel.view).y
        let currentHeight = heightConstraint.constant
        let targetHeight = self.panel.size(for: targetMode).height

        let distance = targetHeight - currentHeight
        let relativeDistance = velocity / distance
        return relativeDistance / CGFloat(PanelAnimator.Constants.Animation.duration)
    }

    func cleanup() {
        self.originalConfiguration = nil
    }
}
