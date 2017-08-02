//
//  PanGestureRecognizer.swift
//  Aiolos
//
//  Created by Matthias Tretter on 18/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Foundation
import UIKit
import UIKit.UIGestureRecognizerSubclass


/// GestureRecognizer that recognizes a pan gesture without any delay
public final class PanGestureRecognizer: UIGestureRecognizer {

    private var firstPoint: CGPoint?
    private var lastPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var initialTimestamp: TimeInterval?
    private var currentVelocity: CGPoint = .zero
    private var lastKnownTouches: Set<UITouch>?
    private var holdTimer: Timer? {
        willSet {
            self.holdTimer?.invalidate()
        }
    }

    // MARK: - Properties

    public var requiresHold: Bool = false
    public var holdDelay: TimeInterval = 0.25
    public var imitatesTapWhenHoldDelayIsNotReached: Bool = true

    public private(set) var didPan: Bool = false
    public var touchType: UITouchType? { return self.lastKnownTouches?.first?.type }
    public var durationSinceStart: TimeInterval? {
        guard let initialTimestamp = self.initialTimestamp else { return nil }
        guard let touch = self.lastKnownTouches?.first else { return nil }

        return touch.timestamp - initialTimestamp
    }
}

// MARK: - UIGestureRecognizer+Subclass

public extension PanGestureRecognizer {

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        self.lastKnownTouches = touches

        // we only handle single-touch
        guard touches.count == 1 else {
            if self.state == .possible {
                self.state = .failed
                return
            }

            touches.forEach { self.ignore($0, for: event) }
            return
        }

        self.currentVelocity = .zero
        self.didPan = false

        guard let touch = touches.first else { return }

        let location = touch.location(in: self.view?.window)
        self.lastPoint = location
        self.currentPoint = location
        self.firstPoint = location
        self.initialTimestamp = touch.timestamp

        // we decrease the hold delay to a minimum, when interacting with the Pencil
        let holdDelay = touch.type == .stylus || self.requiresHold == false ? 0.01 : self.holdDelay
        self.holdTimer = Timer.scheduledTimer(timeInterval: holdDelay, target: self, selector: #selector(holdTimerDidFire), userInfo: nil, repeats: false)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        self.lastKnownTouches = touches

        guard let touch = touches.first else { return }
        guard let firstPoint = self.firstPoint else { return }
        guard let initialTimestamp = self.initialTimestamp else { return }

        let currentPoint = touch.location(in: self.view?.window)
        self.currentPoint = currentPoint

        let currentLocation = touch.location(in: self.view)
        let previousLocation = touch.previousLocation(in: self.view)
        let translation = CGVector(dx: currentLocation.x - previousLocation.x, dy: currentLocation.y - previousLocation.y)
        let timeInterval = touch.timestamp - initialTimestamp
        self.currentVelocity = CGPoint(x: Double(translation.dx) / timeInterval, y: Double(translation.dy) / timeInterval)

        let distanceMoved_2: CGFloat = {
            let dX = currentPoint.x - firstPoint.x
            let dY = currentPoint.y - firstPoint.y
            return dX * dX + dY * dY
        }()

        if distanceMoved_2 >= Constants.hysteresisDistance_2 {
            self.didPan = true
        }

        if self.holdTimer != nil {
            if self.didPan {
                self.holdTimer = nil
                self.state = .failed
            }
            return
        }

        if self.state == .possible {
            self.state = .began
        } else if self.state == .began || self.state == .changed {
            self.state = .changed
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        self.lastKnownTouches = touches

        guard let firstPoint = self.firstPoint else { return }
        guard let currentPoint = self.currentPoint else { return }
        guard let initialTimestamp = self.initialTimestamp else { return }

        let totalTranslationVector = CGVector(dx: currentPoint.x - firstPoint.x, dy: currentPoint.y - firstPoint.y)
        let totalTranslation_2 = totalTranslationVector.dx * totalTranslationVector.dx + totalTranslationVector.dy * totalTranslationVector.dy
        let timeInterval = ProcessInfo.processInfo.systemUptime - initialTimestamp

        if totalTranslation_2 < Constants.hysteresisDistance_2 && timeInterval < self.holdDelay {
            self.didPan = false
        }

        self.state = self.imitatesTapWhenHoldDelayIsNotReached || self.holdTimer == nil ? .ended : .cancelled
        self.holdTimer = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        self.lastKnownTouches = touches

        self.holdTimer = nil
        self.state = .cancelled
    }

    override func reset() {
        super.reset()

        self.holdTimer = nil
        self.lastKnownTouches = nil
    }
}

// MARK: - PanGestureRecognizer

extension PanGestureRecognizer {

    func translation(in view: UIView) -> CGPoint {
        guard let window = self.view?.window else { return .zero }
        guard let lastPoint = self.lastPoint else { return .zero }
        guard let currentPoint = self.currentPoint else { return .zero }

        let lastPointInView = window.convert(lastPoint, to: view)
        let currentPointInView = window.convert(currentPoint, to: view)

        return CGPoint(x: currentPointInView.x - lastPointInView.x, y: currentPointInView.y - lastPointInView.y)
    }

    func setTranslation(_ translation: CGPoint, in view: UIView) {
        guard let currentPoint = self.currentPoint else { return }

        self.lastPoint = currentPoint.applying(.init(translationX: -translation.x, y: -translation.y))
    }

    func velocity(in view: UIView) -> CGPoint {
        return self.currentVelocity
    }
}

// MARK: - Private

private extension PanGestureRecognizer {

    struct Constants {
        static let hysteresisDistance_2: CGFloat = 5.0 * 5.0
    }

    @objc
    func holdTimerDidFire(_ timer: Timer) {
        self.holdTimer = nil

        // don't start the gesture, if we force-touch
        // the behavior, that touchesMoved: is now called when only the force changes, was changed in iOS 10
        // it is documented here: https://developer.apple.com/videos/play/wwdc2016/220/ (starting at 22:08)
        if self.view?.traitCollection.forceTouchCapability == .available, let touch = self.lastKnownTouches?.first {
            let relativeForce = touch.force / touch.maximumPossibleForce
            if relativeForce >= 0.3 {
                return;
            }
        }

        if self.state == .possible {
            self.state = .began
        }
    }
}
