//
//  PanGestureRecognizer.swift
//  Aiolos
//
//  Created by Matthias Tretter on 18/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import UIKit


/// Set of methods implemented by both UIPanGestureRecognizer and our own NoDelayPanGestureRecognizer
@objc
protocol PanGestureRecognizer: AnyObject {

    // We need the @objc annotations because of `typealias PanOrScrollGestureRecognizer = UIGestureRecognizer & PanGestureRecognizer` in PanelGestures
    // which makes the methods in our `NoDelayPanGestureRecognizer` to be called via objc bridging. If we don't have these annotations, we get crashes in runtime.
    @objc(translationInView:)
    func translation(in view: UIView?) -> CGPoint
    @objc(setTranslation:inView:)
    func setTranslation(_ translation: CGPoint, in view: UIView?)
    @objc(velocityInView:)
    func velocity(in view: UIView?) -> CGPoint
}

extension UIPanGestureRecognizer: PanGestureRecognizer { }


// MARK: - PointerScrollGestureRecognizer

/// A UIPanGestureRecognizer subclass that recognizes only pointer scroll gestures
/// We won't need this after UIGestureRecognizer subclasses will be able to detect pointer scrolls (FB7733482)
public final class PointerScrollGestureRecognizer: UIPanGestureRecognizer {

    // MARK: - Lifecycle

    /// As a non-failable initializer cannot be overwritten by a failable initializer, we mark this initializer as 'private' and use make() factory method from outside
    private override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
    }
}

public extension PointerScrollGestureRecognizer {

    static func make(withTarget target: Any?, action: Selector?) -> PointerScrollGestureRecognizer? {
        guard #available(iOS 13.4, *), NSClassFromString("UIPointerInteraction") != nil else { return nil }

        let gesture = PointerScrollGestureRecognizer(target: target, action: action)
        gesture.allowedScrollTypesMask = .continuous
        return gesture
    }
}

// MARK: - UIGestureRecognizer+Subclass

public extension PointerScrollGestureRecognizer {

    @available(iOS 13.4, *)
    override func shouldReceive(_ event: UIEvent) -> Bool {
        guard event.type == .scroll else { return false }

        return super.shouldReceive(event)
    }
}


// MARK: - NoDelayPanGestureRecognizer

/// A UIGestureRecognizer subclass that recognizes pan gestures without any delay but doesn't recognize scrolling with pointer
public final class NoDelayPanGestureRecognizer: UIGestureRecognizer {

    private lazy var panForVelocity: UIPanGestureRecognizer = self.makeVelocityPan()
    private var lastPoint: CGPoint?
    private var currentPoint: CGPoint?
}

// MARK: - UIGestureRecognizer+Subclass

public extension NoDelayPanGestureRecognizer {

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        self.panForVelocity.touchesBegan(touches, with: event)

        // we only handle single-touch
        guard touches.count == 1 else {
            if self.state == .possible {
                self.state = .failed
                return
            }

            touches.forEach { self.ignore($0, for: event) }
            return
        }

        guard let touch = touches.first else { return }

        let location = touch.location(in: self.view?.window)
        self.lastPoint = location
        self.currentPoint = location
        self.state = .began
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        self.panForVelocity.touchesMoved(touches, with: event)

        guard let touch = touches.first else { return }

        let currentPoint = touch.location(in: self.view?.window)
        self.currentPoint = currentPoint
        self.state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        self.panForVelocity.touchesEnded(touches, with: event)

        self.state = .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        self.panForVelocity.touchesCancelled(touches, with: event)

        self.state = .cancelled
    }

    override func reset() {
        super.reset()

        self.panForVelocity = self.makeVelocityPan()
    }
}

// MARK: - PanGestureRecognizer

extension NoDelayPanGestureRecognizer: PanGestureRecognizer {

    func translation(in view: UIView?) -> CGPoint {
        guard let lastPoint = self.lastPoint else { return .zero }
        guard let currentPoint = self.currentPoint else { return .zero }
        guard let view = view ?? self.view?.window else { return .zero }

        return self.translation(from: lastPoint, to: currentPoint, in: view)
    }

    func setTranslation(_ translation: CGPoint, in view: UIView?) {
        guard let currentPoint = self.currentPoint else { return }

        self.lastPoint = currentPoint.applying(.init(translationX: -translation.x, y: -translation.y))
    }

    func velocity(in view: UIView?) -> CGPoint {
        return self.panForVelocity.velocity(in: view)
    }
}

// MARK: - Private

private extension NoDelayPanGestureRecognizer {

    func makeVelocityPan() -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer(target: nil, action: nil)
        pan.cancelsTouchesInView = false
        pan.delaysTouchesBegan = false
        pan.delaysTouchesEnded = false
        return pan
    }

    func translation(from startPoint: CGPoint, to endPoint: CGPoint, in view: UIView) -> CGPoint {
        guard let window = view.window else { return .zero }

        let startPointInView = window.convert(startPoint, to: view)
        let endPointInView = window.convert(endPoint, to: view)

        return CGPoint(x: endPointInView.x - startPointInView.x, y: endPointInView.y - startPointInView.y)
    }
}
