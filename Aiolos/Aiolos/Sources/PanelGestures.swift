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

    private let panel: Panel
    private var originalConfiguration: PanelGestures.Configuration?
    private lazy var pan: PanGestureRecognizer = self.makePanGestureRecognizer()
    private var isEnabled: Bool {
        get { return self.pan.isEnabled }
        set { self.pan.isEnabled = newValue }
    }

    // MARK: - Lifecycle

    init(panel: Panel) {
        self.panel = panel
    }

    // MARK: - PanelGestures

    func install() {
        self.panel.view.addGestureRecognizer(self.pan)
    }

    func configure(with configuration: Panel.Configuration) {
        self.isEnabled = configuration.isGestureBasedResizingEnabled
    }

    func cancel() {
        guard self.pan.isEnabled else { return }

        self.pan.isEnabled = false
        self.pan.isEnabled = true
    }
}

extension PanelGestures: UIGestureRecognizerDelegate {

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let contentViewController = self.panel.contentViewController else { return true }

        return self.gestureRecognizer(gestureRecognizer, isWithinContentAreaOf: contentViewController) == false ||
            self.gestureRecognizer(gestureRecognizer, isAllowedToStartByContentOf: contentViewController)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

// MARK: - Private

private extension PanelGestures {

    struct Configuration {
        let mode: Panel.Configuration.Mode
        let animateChanges: Bool
    }

    struct Constants {
        struct Animation {
            static let mass: CGFloat = 9.0
            static let stiffness: CGFloat = 2400.0
            static let damping: CGFloat = 190.0
        }
    }

    func makePanGestureRecognizer() -> PanGestureRecognizer {
        let pan = PanGestureRecognizer(target: self, action: #selector(handlePan))
        pan.delegate = self
        pan.cancelsTouchesInView = false
        return pan
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
            self.handlePanCancelled(pan)
        default:
            break
        }
    }

    func handlePanStarted(_ pan: PanGestureRecognizer) {
        let configuration = PanelGestures.Configuration(mode: self.panel.configuration.mode,
                                                        animateChanges: self.panel.animator.animateChanges)
        // remember initial state
        self.originalConfiguration = configuration

        if let contentViewController = self.panel.contentViewController {
            pan.didStartOnScrollableArea =
                self.gestureRecognizer(pan, isWithinContentAreaOf: contentViewController) &&
                self.contentIsScrollableVertically(of: contentViewController, at: pan.location(in: self.panel.view))
        }
    }

    func handlePanDragStart(_ pan: PanGestureRecognizer) {
        self.panel.animator.animateChanges = false
        self.panel.animator.performWithoutAnimation {
            self.panel.constraints.updateForPanStart(with: self.panel.view.frame.size)
        }

        pan.cancelsTouchesInView = true
        self.panel.resizeHandle.isResizing = true
    }

    func handlePanChanged(_ pan: PanGestureRecognizer) {
        guard let parentView = self.panel.parent?.view else { return }

        func dragOffset(for translation: CGPoint) -> CGFloat {
            let fudgeFactor: CGFloat = 60.0
            let minHeight = self.height(for: .compact) + fudgeFactor
            let maxHeight = self.panel.constraints.maxHeight - fudgeFactor
            let currentHeight = self.currentPanelHeight

            // slow down resizing if the current height exceeds certain limits
            if (currentHeight < minHeight && translation.y > 0.0) || (currentHeight > maxHeight && translation.y < 0.0) {
                return translation.y / 2.5
            } else {
                return translation.y
            }
        }

        let translation = pan.translation(in: self.panel.view)
        let yOffset = dragOffset(for: translation)

        // cancel pan if it was started on the content/safeArea and it's used to grow the panel in height
        if translation.y < 0.0 && pan.didStartOnScrollableArea {
            self.cancel()
            return
        }

        pan.setTranslation(.zero, in: self.panel.view)
        if pan.didPan && pan.cancelsTouchesInView == false {
            self.handlePanDragStart(pan)
        }

        self.panel.animator.performWithoutAnimation {
            self.panel.constraints.updateForPan(with: yOffset)
        }
        self.panel.animator.notifyDelegateOfTransition(to: CGSize(width: self.panel.view.frame.width, height: self.currentPanelHeight))
    }

    func handlePanEnded(_ pan: PanGestureRecognizer) {
        self.panel.constraints.updateForPanEnd()
        guard pan.didPan else {
            self.handlePanCancelled(pan)
            return
        }

        let targetMode = self.targetMode(for: pan)
        let initialVelocity = self.initialVelocity(for: pan, targetMode: targetMode)

        self.cleanUp(pan: pan)
        self.animate(to: targetMode, initialVelocity: initialVelocity)
    }

    func handlePanCancelled(_ pan: PanGestureRecognizer) {
        guard let mode = self.originalConfiguration?.mode else { return }

        self.cleanUp(pan: pan)

        let size = self.panel.size(for: mode)
        self.panel.constraints.updateForPanCancelled(with: size)
        self.panel.animator.notifyDelegateOfTransition(to: size)
    }

    func targetMode(for pan: PanGestureRecognizer) -> Panel.Configuration.Mode {
        let offset: CGFloat = 100.0
        let minVelocity: CGFloat = 20.0
        let velocity = pan.velocity(in: self.panel.view).y
        let heightExpanded = self.height(for: .expanded)
        let currentHeight = self.currentPanelHeight
        let supportedModes = self.panel.configuration.supportedModes

        let isMovingUpwards = velocity < -minVelocity
        let isMovingDownwards = velocity > minVelocity

        // moving upwards + current size > .expanded -> grow to .fullHeight
        if currentHeight >= heightExpanded && isMovingUpwards && supportedModes.contains(.fullHeight) { return .fullHeight }
        // moving downwards + current size < .expanded -> shrink to .collapsed
        if currentHeight <= heightExpanded && isMovingDownwards && supportedModes.contains(.compact) { return .compact }
        // moving upwards + current size < .expanded -> grow to .expanded
        if currentHeight <= heightExpanded && isMovingUpwards {
            if supportedModes.contains(.expanded) { return .expanded }
            if supportedModes.contains(.fullHeight) { return .fullHeight }
        }
        // moving downwards + current size > .expanded -> shrink to .expanded
        if currentHeight >= heightExpanded && isMovingDownwards {
            if supportedModes.contains(.expanded) { return .expanded }
            if supportedModes.contains(.compact) { return .compact }
        }

        // check distance from .expanded mode
        let diffToExpanded = currentHeight - heightExpanded

        if diffToExpanded > offset && supportedModes.contains(.fullHeight) {
            return .fullHeight
        } else if diffToExpanded < -offset && supportedModes.contains(.compact) {
            return .compact
        } else if supportedModes.contains(.expanded) {
            return .expanded
        } else {
            return supportedModes[0]
        }
    }

    func cleanUp(pan: PanGestureRecognizer) {
        pan.cancelsTouchesInView = false

        guard let originalConfiguration = self.originalConfiguration else { return }

        self.panel.resizeHandle.isResizing = false
        self.panel.animator.animateChanges = originalConfiguration.animateChanges
        self.originalConfiguration = nil
    }

    func height(for mode: Panel.Configuration.Mode) -> CGFloat {
        if mode == .fullHeight {
            return self.panel.constraints.maxHeight
        } else {
            return self.panel.size(for: mode).height
        }
    }

    func initialVelocity(for pan: PanGestureRecognizer, targetMode: Panel.Configuration.Mode) -> CGFloat {
        let velocity = pan.velocity(in: self.panel.view).y
        let currentHeight = self.currentPanelHeight
        let targetHeight = self.height(for: targetMode)

        let distance = targetHeight - currentHeight
        return abs(velocity / distance)
    }

    func animate(to targetMode: Panel.Configuration.Mode, initialVelocity: CGFloat) {
        let height = self.height(for: targetMode)
        let size = self.panel.size(for: targetMode)
        let timing = UISpringTimingParameters(mass: Constants.Animation.mass,
                                              stiffness: Constants.Animation.stiffness,
                                              damping: Constants.Animation.damping,
                                              initialVelocity: CGVector(dx: initialVelocity, dy: initialVelocity))

        self.panel.constraints.prepareForPanEndAnimation()
        self.panel.configuration.mode = targetMode
        self.panel.animator.animateWithTiming(timing, animations: {
            self.panel.constraints.updateForPanEndAnimation(to: height)
            self.panel.animator.notifyDelegateOfTransition(to: size)
        }, completion: {
            self.panel.constraints.updateSizeConstraints(for: size)
        })
    }

    // allow pan gestures to be triggered within non-safe area on top (UINavigationBar)
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, isWithinContentAreaOf contentViewController: UIViewController) -> Bool {
        let offset: CGFloat = 10.0
        let safeAreaTop: CGFloat
        if let navigationController = contentViewController as? UINavigationController, let topViewController = navigationController.topViewController {
            safeAreaTop = topViewController.view.safeAreaInsets.top + offset
        } else {
            safeAreaTop = offset
        }

        let location = gestureRecognizer.location(in: self.panel.panelView)
        return location.y >= safeAreaTop
    }

    // allow pan gesture to be triggered when a) there's no scrollView or b) the scrollView can't be scrolled downwards
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, isAllowedToStartByContentOf contentViewController: UIViewController) -> Bool {
        let location = gestureRecognizer.location(in: contentViewController.view)
        guard let hitView = contentViewController.view.hitTest(location, with: nil) else { return true }
        guard let enclosingScrollView = hitView.superview(with: UIScrollView.self) as? UIScrollView else { return true }
        guard (enclosingScrollView is UITextView) == false else { return false }

        return enclosingScrollView.isScrolledToTop || self.contentIsScrollableVertically(of: contentViewController, at: location) == false
    }

    func contentIsScrollableVertically(of contentViewController: UIViewController, at location: CGPoint) -> Bool {
        guard let hitView = contentViewController.view.hitTest(location, with: nil) else { return false }
        guard let enclosingScrollView = hitView.superview(with: UIScrollView.self) as? UIScrollView else { return false }

        return (enclosingScrollView.isScrollEnabled && enclosingScrollView.scrollsVertically) || enclosingScrollView.alwaysBounceVertical
    }
}

private extension UIView {

    func superview(with viewClass: AnyClass) -> UIView? {
        var view: UIView? = self
        while view != nil && view!.isKind(of: viewClass) == false {
            view = view?.superview
        }

        return view
    }
}

private extension UIScrollView {

    var isScrolledToTop: Bool {
        return self.contentOffset.y <= -self.contentInset.top
    }

    var scrollsVertically: Bool {
        return self.alwaysBounceVertical || self.contentSize.height > self.bounds.height
    }
}
