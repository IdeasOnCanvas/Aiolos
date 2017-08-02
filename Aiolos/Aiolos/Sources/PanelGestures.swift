//
//  PanelGestures.swift
//  Aiolos
//
//  Created by Matthias Tretter on 14/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Foundation


/// Manages Gestures added to the Panel
final class PanelGestures: NSObject {

    private let panel: PanelViewController
    private var originalConfiguration: PanelGestures.Configuration?

    // MARK: - Lifecycle

    init(panel: PanelViewController) {
        self.panel = panel
    }

    // MARK: - PanelGestures

    func install() {
        let pan = PanGestureRecognizer(target: self, action: #selector(handlePan))
        pan.delegate = self
        self.panel.view.addGestureRecognizer(pan)
    }
}

extension PanelGestures: UIGestureRecognizerDelegate {

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let contentViewController = self.panel.contentViewController else { return true }

        // TODO: allow content pans, when scrolled to top
        // TODO: disallow pans on buttons?
        return self.gestureRecognizer(gestureRecognizer, isWithinNonSafeAreaOf: contentViewController)
    }
}

// MARK: - Private

private extension PanelGestures {

    struct Configuration {
        let mode: Panel.Configuration.Mode
        let size: CGSize
        let animateChanges: Bool
    }

    struct Constants {
        struct Animation {
            static let duration: TimeInterval = 0.25
            static let damping: CGFloat = 0.75
        }
    }

    var currentPanelHeight: CGFloat {
        return self.panel.constraints.heightConstraint!.constant
    }

    @objc
    func handlePan(_ pan: PanGestureRecognizer) {
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

    func handlePanStarted(_ pan: PanGestureRecognizer) {
        let configuration = PanelGestures.Configuration(mode: self.panel.configuration.mode,
                                                        size: self.panel.view.frame.size,
                                                        animateChanges: self.panel.animator.animateChanges)
        // remember initial state
        self.originalConfiguration = configuration

        self.panel.resizeHandle.isResizing = true
        self.panel.animator.animateChanges = false
        self.panel.animator.performWithoutAnimation {
            self.panel.constraints.updateForDragStart(with: configuration.size)
        }
    }

    func handlePanChanged(_ pan: PanGestureRecognizer) {
        guard let parentView = self.panel.parent?.view else { return }

        let translation = pan.translation(in: self.panel.view)
        pan.setTranslation(.zero, in: self.panel.view)

        func dragOffset(for translation: CGPoint) -> CGFloat {
            let fudgeFactor: CGFloat = 60.0
            let minHeight = self.panel.size(for: .compact).height + fudgeFactor
            let maxHeight = self.panel.constraints.maxHeight - fudgeFactor
            let currentHeight = self.currentPanelHeight

            // slow down resizing if the current height exceeds certain limits
            if (currentHeight < minHeight && translation.y > 0.0) || (currentHeight > maxHeight && translation.y < 0.0) {
                return translation.y / 2.5
            } else {
                return translation.y
            }
        }

        let dY = dragOffset(for: translation)
        self.panel.animator.animateIfNeeded {
            self.panel.constraints.updateForDrag(with: dY)
            self.panel.animator.notifyDelegateOfTransition(to: CGSize(width: self.panel.view.frame.width, height: self.currentPanelHeight))
        }
    }

    func handlePanEnded(_ pan: PanGestureRecognizer) {
        self.panel.constraints.updateForDragEnd()

        let targetMode = self.targetMode(for: pan)
        let size = self.panel.size(for: targetMode)
        let initialVelocity = self.initialVelocity(for: pan, targetMode: targetMode)

        self.cleanup()
        UIView.animate(withDuration: Constants.Animation.duration,
                       delay: 0.0,
                       usingSpringWithDamping: Constants.Animation.damping,
                       initialSpringVelocity: initialVelocity,
                       options: [.curveLinear],
                       animations: {
                        self.panel.constraints.updateSizeConstraints(for: size)
        }, completion: { _ in
            self.panel.configuration.mode = targetMode
        })
    }

    func handlePanCanceled(_ pan: PanGestureRecognizer) {
        guard let originalSize = self.originalConfiguration?.size else { return }

        self.cleanup()
        self.panel.constraints.updateSizeConstraints(for: originalSize)
    }

    func targetMode(for pan: PanGestureRecognizer) -> Panel.Configuration.Mode {
        let minVelocity: CGFloat = 20.0
        let velocity = pan.velocity(in: self.panel.view).y
        let heightExpanded = self.panel.size(for: .expanded).height
        let currentHeight = self.currentPanelHeight

        let isMovingUpwards = velocity < -minVelocity
        let isMovingDownwards = velocity > minVelocity

        // moving upwards + current size > .expanded -> grow to .fullHeight
        if currentHeight >= heightExpanded && isMovingUpwards { return .fullHeight }
        // moving downwards + current size < .expanded -> shrink to .collapsed
        if currentHeight <= heightExpanded && isMovingDownwards { return .compact }
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
            return .compact
        } else {
            return .expanded
        }
    }

    func initialVelocity(for pan: PanGestureRecognizer, targetMode: Panel.Configuration.Mode) -> CGFloat {
        let velocity = pan.velocity(in: self.panel.view).y
        let currentHeight = self.currentPanelHeight
        let targetHeight = self.panel.size(for: targetMode).height

        let distance = targetHeight - currentHeight
        let relativeDistance = velocity / distance
        return relativeDistance / CGFloat(Constants.Animation.duration)
    }

    func cleanup() {
        guard let originalConfiguration = self.originalConfiguration else { return }

        self.panel.resizeHandle.isResizing = false
        self.panel.animator.animateChanges = originalConfiguration.animateChanges
        self.originalConfiguration = nil
    }

    // allow pan gestures to be triggered within non-safe area on top (UINavigationBar)
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, isWithinNonSafeAreaOf contentViewController: UIViewController) -> Bool {
        let safeAreaTop: CGFloat
        if let navigationController = contentViewController as? UINavigationController, let topViewController = navigationController.topViewController {
            safeAreaTop = topViewController.view.safeAreaInsets.top
        } else {
            safeAreaTop = 0.0
        }

        let location = gestureRecognizer.location(in: self.panel.view)
        return location.y < safeAreaTop
    }
}
