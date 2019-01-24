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

    private unowned let panel: Panel
    
    private lazy var verticalPan: PanGestureRecognizer = self.makeVerticalPanGestureRecognizer()
    private lazy var horizontalPan: UIPanGestureRecognizer = self.makeHorizontalPanGestureRecognizer()
    private lazy var verticalHandler: VerticalHandler = VerticalHandler(gestures: self)
    private lazy var horizontalHandler: HorizontalHandler = HorizontalHandler(gestures: self)
    
    private var isVerticalPanEnabled: Bool {
        get { return self.verticalPan.isEnabled }
        set { self.verticalPan.isEnabled = newValue }
    }
    
    private var isHorizontalPanEnabled: Bool {
        get { return self.horizontalPan.isEnabled }
        set { self.horizontalPan.isEnabled = newValue }
    }

    // MARK: - Lifecycle

    init(panel: Panel) {
        self.panel = panel
    }

    // MARK: - PanelGestures

    func install() {
        self.panel.view.addGestureRecognizer(self.verticalPan)
        // Limit the horizontal gesture to only trigger, when it is started on top of the resize handle
        self.panel.resizeHandle.addGestureRecognizer(self.horizontalPan)
    }

    func configure(with configuration: Panel.Configuration) {
        self.cancel()
        self.isVerticalPanEnabled = configuration.gestureResizingMode != .disabled
        self.isHorizontalPanEnabled = configuration.horizontalPositioningEnabled
    }

    func cancel() {
        self.horizontalPan.cancel()
        self.verticalPan.cancel()
    }
}

// MARK: - UIGestureRecognizerDelegate

extension PanelGestures: UIGestureRecognizerDelegate {

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        switch gestureRecognizer {
        case self.horizontalPan:
            // The vertical PanGestureRecognizer starts without any delay so we need to ensure
            // it hasn't changed before allowing the horizontal gesture recognizer to start.
            guard self.verticalPan.state != .changed else { return false }
            
            return self.horizontalHandler.shouldStartPan(self.horizontalPan)
        case self.verticalPan:
            return self.verticalHandler.shouldStartPan(self.verticalPan)
        default:
            return true
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // fail for built-in drag gesture recognizers 🤷‍♂️
        let className = String(describing: type(of: otherGestureRecognizer))
        return className.contains("UIDrag")
    }
}

// MARK: - Private

private extension PanelGestures {

    // MARK: - HorizontalHandler

    final class HorizontalHandler {
        
        private unowned let gestures: PanelGestures
        private var panel: Panel { return gestures.panel }
        
        init(gestures: PanelGestures) {
            self.gestures = gestures
        }
        
        func shouldStartPan(_ pan: UIPanGestureRecognizer) -> Bool {
            let velocity = pan.velocity(in: self.panel.view)
            return abs(velocity.x) > abs(velocity.y)
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
                self.handlePanCancelled(pan)
            default:
                break
            }
        }
        
        private func handlePanStarted(_ pan: UIPanGestureRecognizer) {
            self.gestures.updateResizeHandle()
        }
        
        private func handlePanChanged(_ pan: UIPanGestureRecognizer) {
            guard let parentView = self.panel.parent?.view else { return }
            
            func dragOffset(for translation: CGPoint, moveAllowed: Bool) -> CGFloat {
                let dragCoefficient: CGFloat = 1/5 // TODO: revise
                return moveAllowed ? translation.x : translation.x * dragCoefficient
            }
            
            let translation = pan.translation(in: parentView)
            let transformation = CGAffineTransform(translationX: translation.x, y: 0)
            let targetFrame = self.panel.view.frame.applying(transformation)
            let moveAllowed = self.panel.animator.askDelegateAboutMove(to: targetFrame)
            let xOffset = dragOffset(for: translation, moveAllowed: moveAllowed)
            guard xOffset != 0.0 else { return }
            
            self.panel.animator.performWithoutAnimation { self.panel.view.transform = CGAffineTransform(translationX: xOffset, y: 0) }
        }
        
        private func handlePanEnded(_ pan: UIPanGestureRecognizer) {
            guard let parentView = self.panel.parent?.view else { return }
            
            // The view is being transformed, thus the frame changes while dragging, hence the correction
            let originalFrame = self.panel.view.frame.applying(self.panel.view.transform.inverted())
            let offset = pan.translation(in: parentView).x
            let velocity = pan.velocity(in: parentView).x
            let context = PanelTransitionCoordinator.HorizontalTransitionContext(panel: self.panel, parentView: parentView, originalFrame: originalFrame, offset: offset, velocity: velocity)
            self.panel.animator.notifyDelegateOfMove(from: originalFrame, to: self.panel.view.frame, context: context)

            let initialVelocity = self.initialVelocity(with: context)
            let timing = Animation.overdamped.makeTiming(with: initialVelocity)
            self.panel.animator.animateWithTiming(timing, animations: {
                self.panel.view.transform = .identity
            })
            
            self.cleanUp(pan: pan)
        }
        
        private func handlePanCancelled(_ pan: UIPanGestureRecognizer) {
            self.panel.animator.animateIfNeeded {
                self.panel.view.transform = .identity
            }
            
            self.cleanUp(pan: pan)
        }
        
        private func cleanUp(pan: UIPanGestureRecognizer) {
            self.gestures.updateResizeHandle()
        }
        
        private func initialVelocity(with context: PanelTransitionCoordinator.HorizontalTransitionContext) -> CGFloat {
            // FIXME: We assume that the delegate will move the panel to the other side based on the 'context.targetPosition' property
            let originalPosition = self.panel.configuration.position
            let targetPosition = context.targetPosition
            
            let distance: CGFloat
            if originalPosition != targetPosition {
                // Let's assume that the panel is moving across the bounds of the parent view
                distance = context.parentView.bounds.width - abs(context.offset)
            } else {
                distance = context.offset
            }
            
            return abs(context.velocity / distance)
        }
    }
}

private extension PanelGestures {

    // MARK: - VerticalHandler
    
    final class VerticalHandler {
        
        private unowned let gestures: PanelGestures
        private var panel: Panel { return gestures.panel }
        private var originalConfiguration: PanelGestures.Configuration?
        
        init(gestures: PanelGestures) {
            self.gestures = gestures
        }
        
        func shouldStartPan(_ pan: PanGestureRecognizer) -> Bool {
            guard let contentViewController = self.panel.contentViewController else { return true }
            
            return self.gestureRecognizer(pan, isWithinContentAreaOf: contentViewController) == false ||
                self.gestureRecognizer(pan, isAllowedToStartByContentOf: contentViewController)
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
        
        private func handlePanStarted(_ pan: PanGestureRecognizer) {
            let configuration = PanelGestures.Configuration(mode: self.panel.configuration.mode, animateChanges: self.panel.animator.animateChanges)
            // remember initial state
            self.originalConfiguration = configuration
            
            if let contentViewController = self.panel.contentViewController {
                if self.gestureRecognizer(pan, isWithinContentAreaOf: contentViewController), let scrollView = self.verticallyScrollableView(of: contentViewController, interactingWith: pan) {
                    pan.startMode = .onVerticallyScrollableArea(competingScrollView: scrollView)
                } else {
                    pan.startMode = .onFixedArea
                }
            }
        }
        
        private func handlePanDragStart(_ pan: PanGestureRecognizer) -> Bool {
            self.panel.animator.animateChanges = false
            self.panel.animator.performWithoutAnimation {
                self.panel.constraints.updateForPanStart(with: self.panel.view.frame.size)
            }
            
            pan.cancelsTouchesInView = true
            self.gestures.updateResizeHandle()
            
            let velocity = pan.velocity(in: self.panel.view)
            
            if case .onVerticallyScrollableArea(let scrollView) = pan.startMode {
                if velocity.y < 0.0 {
                    // if the gesture scrolls the content, cancel the resizing gesture itself
                    self.gestures.cancelVerticalPan()
                    return false
                } else if velocity.y > 0.0 {
                    // if the gesture would shrink the panel, cancel all gestures on the competing scrollView
                    scrollView.gestureRecognizers?.forEach {
                        $0.cancel()
                    }
                }
            }
            
            return true
        }
        
        private func handlePanChanged(_ pan: PanGestureRecognizer) {
            guard let parentView = self.panel.parent?.view else { return }
            
            func dragOffset(for translation: CGPoint) -> CGFloat {
                let fudgeFactor: CGFloat = 60.0
                let minHeight = self.height(for: .compact) + fudgeFactor
                let maxHeight = self.panel.constraints.maxHeight - fudgeFactor
                let currentHeight = self.currentPanelHeight
                
                // slow down resizing if the current height exceeds certain limits
                let isNearingEdge = (currentHeight < minHeight && translation.y > 0.0) || (currentHeight > maxHeight && translation.y < 0.0)
                let isShrinkingOnScrollView = pan.startMode != .onFixedArea && translation.y > 0.0
                if isNearingEdge || isShrinkingOnScrollView {
                    return translation.y / 3.0
                } else {
                    return translation.y
                }
            }
            
            let translation = pan.translation(in: self.panel.view)
            let yOffset = dragOffset(for: translation)
            guard yOffset != 0.0 else { return }
            
            pan.setTranslation(.zero, in: self.panel.view)
            if pan.didPan && pan.cancelsTouchesInView == false {
                guard self.handlePanDragStart(pan) else { return }
            }
            
            self.panel.animator.performWithoutAnimation { self.panel.constraints.updateForPan(with: yOffset) }
            self.panel.animator.notifyDelegateOfTransition(to: CGSize(width: self.panel.view.frame.width, height: self.currentPanelHeight))
        }
        
        private func handlePanEnded(_ pan: PanGestureRecognizer) {
            guard let originalMode = self.originalConfiguration?.mode else { return }
            
            self.panel.constraints.updateForPanEnd()
            guard pan.didPan || originalMode == .minimal else {
                self.handlePanCancelled(pan)
                return
            }
            
            let targetMode = self.targetMode(for: pan)
            let initialVelocity = self.initialVelocity(for: pan, targetMode: targetMode)
            
            self.animate(to: targetMode, initialVelocity: initialVelocity)
            self.cleanUp(pan: pan)
        }
        
        private func handlePanCancelled(_ pan: PanGestureRecognizer) {
            guard let originalMode = self.originalConfiguration?.mode else { return }
            
            let currentHeight = self.currentPanelHeight
            self.cleanUp(pan: pan)
            
            let size = self.panel.size(for: originalMode)
            self.panel.animator.notifyDelegateOfTransition(from: originalMode, to: originalMode)
            self.panel.constraints.updateForPanCancelled(with: size)
            if currentHeight != size.height {
                self.panel.animator.notifyDelegateOfTransition(to: size)
            }
        }
        
        // swiftlint:disable cyclomatic_complexity
        private func targetMode(for pan: PanGestureRecognizer) -> Panel.Configuration.Mode {
            let supportedModes = self.panel.configuration.supportedModes
            guard let originalConfiguration = self.originalConfiguration else { return supportedModes.first! }
            
            let offset: CGFloat = 100.0
            let minVelocity: CGFloat = 20.0
            let velocity = pan.velocity(in: self.panel.view).y
            let heightCompact = self.height(for: .compact)
            let heightExpanded = self.height(for: .expanded)
            let currentHeight = self.currentPanelHeight
            
            let isMovingUpwards = velocity < -minVelocity
            let isMovingDownwards = velocity > minVelocity
            
            // expand to .compact if we "tap" on .minimal
            if isMovingUpwards == false && isMovingDownwards == false && originalConfiguration.mode == .minimal && currentHeight < heightCompact && supportedModes.contains(.compact) {
                return .compact
            }
            // .minimal is only allowed when moving downwards from .compact
            if isMovingDownwards && originalConfiguration.mode == .compact && currentHeight < heightCompact && supportedModes.contains(.minimal) {
                return .minimal
            }
            // if we move up from .minimal we have a higher threshold for .expanded and prefer .compact
            if isMovingUpwards && originalConfiguration.mode == .minimal && currentHeight < heightCompact + 40.0 && supportedModes.contains(.compact) {
                return .compact
            }
            // moving upwards + current size > .expanded -> grow to .fullHeight
            if currentHeight >= heightExpanded && isMovingUpwards && supportedModes.contains(.fullHeight) {
                return .fullHeight
            }
            // moving downwards + current size < .expanded -> shrink to .collapsed
            if currentHeight <= heightExpanded && isMovingDownwards && supportedModes.contains(.compact) {
                return .compact
            }
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
                return originalConfiguration.mode
            }
        }
        // swiftlint:enable cyclomatic_complexity
        
        private func cleanUp(pan: PanGestureRecognizer) {
            pan.cancelsTouchesInView = false
            
            guard let originalConfiguration = self.originalConfiguration else { return }
            
            self.gestures.updateResizeHandle()
            self.panel.animator.animateChanges = originalConfiguration.animateChanges
            self.originalConfiguration = nil
        }
        
        private func height(for mode: Panel.Configuration.Mode) -> CGFloat {
            if mode == .fullHeight {
                return self.panel.constraints.maxHeight
            } else {
                return self.panel.size(for: mode).height
            }
        }
        
        private func initialVelocity(for pan: PanGestureRecognizer, targetMode: Panel.Configuration.Mode) -> CGFloat {
            let velocity = pan.velocity(in: self.panel.view).y
            let currentHeight = self.currentPanelHeight
            let targetHeight = self.height(for: targetMode)
            
            let distance = targetHeight - currentHeight
            return abs(velocity / distance)
        }
        
        private func timing(for initialVelocity: CGFloat) -> UITimingCurveProvider {
            let springTiming = Animation.springy.makeTiming(with: initialVelocity)
            guard let originalConfiguration = self.originalConfiguration else { return springTiming }
            
            if originalConfiguration.mode == .minimal || initialVelocity < 13.0 {
                return Animation.overdamped.makeTiming(with: initialVelocity)
            } else {
                return springTiming
            }
        }
        
        private func animate(to targetMode: Panel.Configuration.Mode, initialVelocity: CGFloat) {
            let height = self.height(for: targetMode)
            let size = self.panel.size(for: targetMode)
            let timing = self.timing(for: initialVelocity)
            
            self.panel.constraints.prepareForPanEndAnimation()
            self.panel.configuration.mode = targetMode
            self.panel.animator.animateWithTiming(timing, animations: {
                self.panel.constraints.updateForPanEndAnimation(to: height)
                self.panel.animator.notifyDelegateOfTransition(to: size)
                self.panel.fixNavigationBarLayoutMargins()
            }, completion: {
                self.panel.constraints.updateSizeConstraints(for: size)
            })
        }
        
        // allow pan gestures to be triggered within non-safe area on top (UINavigationBar)
        private func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, isWithinContentAreaOf contentViewController: UIViewController) -> Bool {
            let offset: CGFloat = 10.0
            let safeAreaTop: CGFloat
            if let navigationController = contentViewController as? UINavigationController {
                safeAreaTop = navigationController.navigationBar.frame.maxY + offset
            } else {
                safeAreaTop = offset
            }
            
            let location = gestureRecognizer.location(in: self.panel.panelView)
            return location.y >= safeAreaTop
        }
        
        // allow pan gesture to be triggered when a) there's no scrollView or b) the scrollView can't be scrolled downwards
        private func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, isAllowedToStartByContentOf contentViewController: UIViewController) -> Bool {
            guard self.panel.configuration.gestureResizingMode == .includingContent else { return false }
            
            guard let enclosingScrollView = self.verticallyScrollableView(of: contentViewController, interactingWith: gestureRecognizer) else { return true }
            // don't allow resizing gesture if textView is currently text editing
            if let textView = enclosingScrollView as? UITextView, textView.isFirstResponder {
                return false
            }
            
            return enclosingScrollView.isScrolledToTop
        }
        
        private func verticallyScrollableView(of contentViewController: UIViewController, interactingWith gestureRecognizer: UIGestureRecognizer) -> UIScrollView? {
            let location = gestureRecognizer.location(in: contentViewController.view)
            guard let hitView = contentViewController.view.hitTest(location, with: nil) else { return nil }
            
            return hitView.findFirstSuperview(ofClass: UIScrollView.self, where: { $0.scrollsVertically })
        }
        
        private var currentPanelHeight: CGFloat {
            return self.panel.constraints.heightConstraint!.constant
        }
    }
}

private extension PanelGestures {
    
    struct Configuration {
        let mode: Panel.Configuration.Mode
        let animateChanges: Bool
    }

    struct Animation {
        let mass: CGFloat
        let stiffness: CGFloat
        let damping: CGFloat

        static let springy: Animation = Animation(mass: 6.0, stiffness: 2400.0, damping: 195.0)
        static let overdamped: Animation = Animation(mass: 6.0, stiffness: 2400.0, damping: 250.0)

        func makeTiming(with velocity: CGFloat) -> UISpringTimingParameters {
            return UISpringTimingParameters(mass: self.mass, stiffness: self.stiffness, damping: self.damping, initialVelocity: CGVector(dx: velocity, dy: velocity))
        }
    }

    func makeVerticalPanGestureRecognizer() -> PanGestureRecognizer {
        let pan = PanGestureRecognizer(target: self.verticalHandler, action: #selector(VerticalHandler.handlePan))
        pan.delegate = self
        pan.cancelsTouchesInView = false
        return pan
    }
    
    func makeHorizontalPanGestureRecognizer() -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer(target: self.horizontalHandler, action: #selector(HorizontalHandler.handlePan))
        pan.delegate = self
        pan.cancelsTouchesInView = true
        return pan
    }

    func cancelVerticalPan() {
        self.verticalPan.cancel()
    }
    
    func updateResizeHandle() {
        var isPanning: Bool {
            let states: Set<UIGestureRecognizer.State> = [.began, .changed]
            let isPanningVertically = states.contains(self.verticalPan.state)
            let isPanningHorizontally = states.contains(self.horizontalPan.state)

            return isPanningVertically || isPanningHorizontally
        }

        self.panel.resizeHandle.isResizing = isPanning
    }
}

private extension UIView {

    func findFirstSuperview<T>(ofClass viewClass: T.Type, where predicate: (T) -> Bool) -> T? where T: UIView {
        var view: UIView? = self
        while view != nil {
            if let typedView = view as? T, predicate(typedView) {
                break
            }

            view = view?.superview
        }

        return view as? T
    }
}

private extension UIScrollView {

    var isScrolledToTop: Bool {
        return self.contentOffset.y <= -self.contentInset.top
    }

    var scrollsVertically: Bool {
        guard self.isScrollEnabled && self.isUserInteractionEnabled else { return false }

        let visibleHeight = self.bounds.height - self.adjustedContentInset.top - self.adjustedContentInset.bottom
        return self.alwaysBounceVertical || self.contentSize.height > visibleHeight
    }
}

private extension UIGestureRecognizer {

    func cancel() {
        guard self.isEnabled else { return }

        self.isEnabled = false
        self.isEnabled = true
    }
}
