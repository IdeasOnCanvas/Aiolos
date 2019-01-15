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
    private lazy var horizontalPan: PanGestureRecognizer = self.makeHorizontalPanGestureRecognizer()
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

    private var isPanningVertically: Bool {
        let states: Set<UIGestureRecognizer.State> = [.began, .changed]
        return states.contains(self.verticalPan.state)
    }
    
    private var isPanningHorizontally: Bool {
        let states: Set<UIGestureRecognizer.State> = [.began, .changed]
        return states.contains(self.horizontalPan.state)
    }
    
    // MARK: - Properties

    var isPanning: Bool {
        return isPanningHorizontally || isPanningVertically
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
        self.isHorizontalPanEnabled = configuration.gesturePositioningMode != .disabled
    }

    func cancel() {
        self.horizontalPan.cancel()
        self.verticalPan.cancel()
    }
}

extension PanelGestures: UIGestureRecognizerDelegate {

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let contentViewController = self.panel.contentViewController else { return true }

        return self.verticalHandler.gestureRecognizer(gestureRecognizer, isWithinContentAreaOf: contentViewController) == false ||
            self.verticalHandler.gestureRecognizer(gestureRecognizer, isAllowedToStartByContentOf: contentViewController)
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

    final class HorizontalHandler: NSObject {
        
        private unowned let gestures: PanelGestures
        private var panel: Panel { return gestures.panel }
        private weak var middleLine: UIView? // TODO: Delete once the implementation is finished
        
        init(gestures: PanelGestures) {
            self.gestures = gestures
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
            self.gestures.updateResizeHandle()
            
            // TODO: Debug
            guard let superview = self.panel.view.superview else { return }
            let midScreen = superview.bounds.midX
            self.debugShowMiddleLine(at: midScreen)
        }
        
        func handlePanChanged(_ pan: PanGestureRecognizer) {
            guard let superview = self.panel.view.superview else { return }
            
            func dragOffset(for translation: CGPoint) -> CGFloat {
                // TODO: Avoid the panel being dragged over the edge of the screen (if not allowed - ask the delegate)
                return translation.x
            }
            
            let translation = pan.translation(in: superview)
            let xOffset = dragOffset(for: translation)
            guard xOffset != 0.0 else { return }
            
            self.panel.animator.performWithoutAnimation { self.panel.view.transform = CGAffineTransform(translationX: xOffset, y: 0) }
            self.panel.animator.notifyDelegateOfWillMove(to: self.panel.view.frame)
            
            // TODO: Debug
            let midScreen = superview.bounds.midX
            /// Calculate how large xOffset must be to reach the middle of the screen from the closer edge
            /// - NOTE: The view is being transformed, thus the frame changes while dragging, hence the correction
            let originalFrame = self.panel.view.frame.applying(self.panel.view.transform.inverted())
            let threshold = min(abs(midScreen - originalFrame.maxX), abs(midScreen - originalFrame.minX))
            self.debugUpdateMiddleLine(withOffset: xOffset, threshold: threshold)
        }
        
        func handlePanEnded(_ pan: PanGestureRecognizer) {
            // The view is being transformed, thus the frame changes while dragging, hence the correction
            let originalFrame = self.panel.view.frame.applying(self.panel.view.transform.inverted())
            
            self.panel.animator.notifyDelegateOfDidMove(from: originalFrame, to: self.panel.view.frame, pan: pan)
            
            self.panel.animator.animateIfNeeded {
                self.panel.view.transform = .identity
            }
            
            self.cleanUpAfterHorizontalPan(pan)
        }
        
        func handlePanCancelled(_ pan: PanGestureRecognizer) {
            self.panel.animator.animateIfNeeded {
                self.panel.view.transform = .identity
            }
            
            cleanUpAfterHorizontalPan(pan)
        }
        
        func cleanUpAfterHorizontalPan(_ pan: PanGestureRecognizer) {
            self.gestures.updateResizeHandle()
            
            // TODO: Debug
            self.middleLine?.removeFromSuperview()
        }
    }
    
    final class VerticalHandler: NSObject {
        
        private unowned let gestures: PanelGestures
        private var panel: Panel { return gestures.panel }
        private var originalConfiguration: PanelGestures.Configuration?
        
        init(gestures: PanelGestures) {
            self.gestures = gestures
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
                if self.gestureRecognizer(pan, isWithinContentAreaOf: contentViewController), let scrollView = self.verticallyScrollableView(of: contentViewController, interactingWith: pan) {
                    pan.startMode = .onVerticallyScrollableArea(competingScrollView: scrollView)
                } else {
                    pan.startMode = .onFixedArea
                }
            }
        }
        
        func handlePanDragStart(_ pan: PanGestureRecognizer) -> Bool {
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
        
        func handlePanChanged(_ pan: PanGestureRecognizer) {
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
        
        func handlePanEnded(_ pan: PanGestureRecognizer) {
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
        
        func handlePanCancelled(_ pan: PanGestureRecognizer) {
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
        func targetMode(for pan: PanGestureRecognizer) -> Panel.Configuration.Mode {
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
        
        func cleanUp(pan: PanGestureRecognizer) {
            pan.cancelsTouchesInView = false
            
            guard let originalConfiguration = self.originalConfiguration else { return }
            
            self.gestures.updateResizeHandle()
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
        
        func timing(for initialVelocity: CGFloat) -> UITimingCurveProvider {
            let springTiming = Animation.springy.makeTiming(with: initialVelocity)
            guard let originalConfiguration = self.originalConfiguration else { return springTiming }
            
            if originalConfiguration.mode == .minimal || initialVelocity < 13.0 {
                return Animation.overdamped.makeTiming(with: initialVelocity)
            } else {
                return springTiming
            }
        }
        
        func animate(to targetMode: Panel.Configuration.Mode, initialVelocity: CGFloat) {
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
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, isWithinContentAreaOf contentViewController: UIViewController) -> Bool {
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
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, isAllowedToStartByContentOf contentViewController: UIViewController) -> Bool {
            guard self.panel.configuration.gestureResizingMode == .includingContent else { return false }
            
            guard let enclosingScrollView = self.verticallyScrollableView(of: contentViewController, interactingWith: gestureRecognizer) else { return true }
            // don't allow resizing gesture if textView is currently text editing
            if let textView = enclosingScrollView as? UITextView, textView.isFirstResponder {
                return false
            }
            
            return enclosingScrollView.isScrolledToTop
        }
        
        func verticallyScrollableView(of contentViewController: UIViewController, interactingWith gestureRecognizer: UIGestureRecognizer) -> UIScrollView? {
            let location = gestureRecognizer.location(in: contentViewController.view)
            guard let hitView = contentViewController.view.hitTest(location, with: nil) else { return nil }
            
            return hitView.findFirstSuperview(ofClass: UIScrollView.self, where: { $0.scrollsVertically })
        }
        
        var currentPanelHeight: CGFloat {
            return self.panel.constraints.heightConstraint!.constant
        }
    }
    
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
        pan.panDirection = .vertical
        pan.delegate = self
        pan.cancelsTouchesInView = false
        return pan
    }
    
    func makeHorizontalPanGestureRecognizer() -> PanGestureRecognizer {
        let pan = PanGestureRecognizer(target: self.horizontalHandler, action: #selector(HorizontalHandler.handlePan))
        pan.panDirection = .horizontal
        pan.delegate = self
        pan.cancelsTouchesInView = true
        return pan
    }

    func cancelVerticalPan() {
        self.verticalPan.cancel()
    }
    
    func cancelHorizontalPan() {
        self.horizontalPan.cancel()
    }
    
    func updateResizeHandle() {
        self.panel.resizeHandle.isResizing = self.isPanning
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

// Inspired by: https://medium.com/ios-os-x-development/gestures-in-fluid-interfaces-on-intent-and-projection-36d158db7395
private func project(_ velocity: CGFloat, onto position: CGFloat, decelerationRate: UIScrollView.DecelerationRate = .normal) -> CGFloat {
    let factor = -1 / (1000 * log(decelerationRate.rawValue))
    return position + factor * velocity
}

// TODO: Delete the debug code below once the implementation is finished

#if DEBUG
private let isDebug = true
#else
private let isDebug = false
#endif

private extension PanelGestures.HorizontalHandler {
    
    func debugShowMiddleLine(at xPosition: CGFloat) {
        guard isDebug else { return }
        
        if self.middleLine == nil {
            let verticalLine = UIView.init(frame: CGRect(x: xPosition, y: 0, width: 1, height: self.panel.parent!.view.bounds.height))
            verticalLine.backgroundColor = .red
            self.panel.parent!.view.addSubview(verticalLine)
            self.panel.parent!.view.bringSubviewToFront(verticalLine)
            self.middleLine = verticalLine
        }
    }
    
    func debugUpdateMiddleLine(withOffset xOffset: CGFloat, threshold: CGFloat) {
        if xOffset < -threshold {
            middleLine?.backgroundColor = .green
        } else if xOffset > threshold {
            middleLine?.backgroundColor = .green
        } else {
            middleLine?.backgroundColor = .red
        }
    }
    
    func debugShowProjectedView(projectedOffset: CGFloat) {
        guard isDebug else { return }
        
        var projectedFrame = self.panel.view.frame
        projectedFrame.origin.x += projectedOffset
        let projectedPanel = UIView(frame: projectedFrame)
        projectedPanel.backgroundColor = .clear
        projectedPanel.layer.borderColor = UIColor.gray.cgColor
        projectedPanel.layer.borderWidth = 1.0
        self.panel.view.superview!.addSubview(projectedPanel)
        self.panel.view.superview!.bringSubviewToFront(projectedPanel)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIView.animate(
                withDuration: 0.5,
                animations: { projectedPanel.alpha = 0.0 },
                completion: { _ in projectedPanel.removeFromSuperview() }
            )
        }
    }
}
