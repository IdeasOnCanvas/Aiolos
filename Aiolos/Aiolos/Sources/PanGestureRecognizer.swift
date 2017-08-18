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

    private lazy var panForVelocity: UIPanGestureRecognizer = self.makeVelocityPan()
    private var lastPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var initialTimestamp: TimeInterval?
    private var currentVelocity: CGPoint = .zero

    // MARK: Properties

    private(set) var didPan: Bool = false
    var didStartOnScrollableArea: Bool = false
}

// MARK: - UIGestureRecognizer+Subclass

public extension PanGestureRecognizer {

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
        self.currentVelocity = .zero
        self.lastPoint = location
        self.currentPoint = location
        self.initialTimestamp = touch.timestamp
        self.state = .began
        self.didPan = false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        self.panForVelocity.touchesMoved(touches, with: event)

        guard let touch = touches.first else { return }
        guard let initialTimestamp = self.initialTimestamp else { return }

        let currentPoint = touch.location(in: self.view?.window)
        self.currentPoint = currentPoint

        let currentLocation = touch.location(in: self.view)
        let previousLocation = touch.previousLocation(in: self.view)
        let translation = CGVector(dx: currentLocation.x - previousLocation.x, dy: currentLocation.y - previousLocation.y)
        let timeInterval = touch.timestamp - initialTimestamp
        self.currentVelocity = CGPoint(x: Double(translation.dx) / timeInterval, y: Double(translation.dy) / timeInterval)

        self.state = .changed
        self.didPan = true
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

        self.didPan = false
        self.didStartOnScrollableArea = false
        self.panForVelocity = self.makeVelocityPan()
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
        return self.panForVelocity.velocity(in: view)
    }
}

// MARK: - Private

private extension PanGestureRecognizer {

    func makeVelocityPan() -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer(target: nil, action: nil)
        pan.cancelsTouchesInView = false
        pan.delaysTouchesBegan = false
        pan.delaysTouchesEnded = false
        return pan
    }
}
