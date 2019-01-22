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

    enum StartMode: Equatable {
        case onFixedArea
        case onVerticallyScrollableArea(competingScrollView: UIScrollView)
    }

    private lazy var panForVelocity: UIPanGestureRecognizer = self.makeVelocityPan()
    private var initialPoint: CGPoint?
    private var lastPoint: CGPoint?
    private var currentPoint: CGPoint?

    // MARK: Properties

    private(set) var didPan: Bool = false
    var startMode: StartMode = .onFixedArea
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
        self.initialPoint = location
        self.lastPoint = location
        self.currentPoint = location
        self.state = .began
        self.didPan = false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        self.panForVelocity.touchesMoved(touches, with: event)

        guard let touch = touches.first else { return }

        let currentPoint = touch.location(in: self.view?.window)
        self.currentPoint = currentPoint

        if self.totalTranslation.hypotenuse() > Constants.minTranslation && self.didPan == false {
            self.didPan = true

            // if we recognized a pan, make sure it can be considered a vertical pan
            guard self.totalTranslation.direction() == .vertical else {
                self.state = .cancelled
                return
            }
        }

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

        self.didPan = false
        self.startMode = .onFixedArea
        self.panForVelocity = self.makeVelocityPan()
    }
}

// MARK: - PanGestureRecognizer

extension PanGestureRecognizer {

    func translation(in view: UIView) -> CGPoint {
        guard let lastPoint = self.lastPoint else { return .zero }
        guard let currentPoint = self.currentPoint else { return .zero }

        return self.translation(from: lastPoint, to: currentPoint, in: view)
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

    struct Constants {
        static let minTranslation: CGFloat = 5.0
    }

    func makeVelocityPan() -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer(target: nil, action: nil)
        pan.cancelsTouchesInView = false
        pan.delaysTouchesBegan = false
        pan.delaysTouchesEnded = false
        return pan
    }

    var totalTranslation: CGPoint {
        guard let view = self.view else { return .zero }
        guard let initialPoint = self.initialPoint else { return .zero }
        guard let currentPoint = self.currentPoint else { return .zero }

        return self.translation(from: initialPoint, to: currentPoint, in: view)
    }

    func translation(from startPoint: CGPoint, to endPoint: CGPoint, in view: UIView) -> CGPoint {
        guard let window = self.view?.window else { return .zero }

        let startPointInView = window.convert(startPoint, to: view)
        let endPointInView = window.convert(endPoint, to: view)

        return CGPoint(x: endPointInView.x - startPointInView.x, y: endPointInView.y - startPointInView.y)
    }
}

private extension CGPoint {

    enum Direction {
        case horizontal
        case vertical
    }

    func hypotenuse() -> CGFloat {
        return sqrt(self.x * self.x + self.y * self.y)
    }

    func direction() -> Direction {
        let horizontalDiff = self.x * self.x
        let verticalDiff = self.y * self.y

        return horizontalDiff > verticalDiff ? .horizontal : .vertical
    }
}
