//
//  PanelRepositionContext.swift
//  Aiolos
//
//  Created by Tom Kraina on 13/02/2019.
//  Copyright © 2019 Matthias Tretter. All rights reserved.
//

import Foundation


public final class PanelRepositionContext {

    public enum Instruction {
        case updatePosition(_ newPosition: Panel.Configuration.Position)
        case hide
        case none
    }

    private unowned let panel: Panel
    private let originalFrame: CGRect

    // MARK: Properties

    unowned let parentView: UIView
    let offset: CGFloat
    let velocity: CGFloat

    // MARK: Lifecycle

    init(panel: Panel, parentView: UIView, originalFrame: CGRect, offset: CGFloat, velocity: CGFloat) {
        self.panel = panel
        self.parentView = parentView
        self.originalFrame = originalFrame
        self.offset = offset
        self.velocity = velocity
    }

    // MARK: PanelRepositionContext

    public var originalPosition: Panel.Configuration.Position {
        return self.panel.configuration.position
    }

    public var targetPosition: Panel.Configuration.Position {
        let supportedPositions = self.panel.configuration.supportedPositions

        guard abs(self.projectedOffset) > self.horizontalThreshold else { return self.originalPosition }

        if self.isMovingTowardsLeadingEdge && supportedPositions.contains(.leadingBottom) {
            return .leadingBottom
        }

        if self.isMovingTowardsTrailingEdge && supportedPositions.contains(.trailingBottom) {
            return .trailingBottom
        }

        return self.originalPosition
    }

    public var isMovingPastLeadingEdge: Bool {
        guard self.panel.configuration.position == .leadingBottom else { return false }

        if self.parentView.isRTL {
            guard self.offset > 0.0 else { return false }

            return self.leadingEdge + self.projectedOffset > self.leadingEdgeThreshold
        } else {
            guard self.offset < 0.0 else { return false }

            return self.leadingEdge + self.projectedOffset < self.leadingEdgeThreshold
        }
    }

    public var isMovingPastTrailingEdge: Bool {
        guard self.panel.configuration.position == .trailingBottom else { return false }

        if self.parentView.isRTL {
            guard self.offset < 0.0 else { return false }

            return self.trailingEdge + self.projectedOffset < self.trailingEdgeThreshold
        } else {
            guard self.offset > 0.0 else { return false }

            return self.trailingEdge + self.projectedOffset > self.trailingEdgeThreshold
        }
    }
}

// MARK: - Private

private extension PanelRepositionContext {

    var projectedOffset: CGFloat {
        // Inspired by: https://medium.com/ios-os-x-development/gestures-in-fluid-interfaces-on-intent-and-projection-36d158db7395
        func project(_ velocity: CGFloat, onto position: CGFloat, decelerationRate: UIScrollView.DecelerationRate = .normal) -> CGFloat {
            let factor = -1.0 / (1000.0 * log(decelerationRate.rawValue))
            return position + factor * velocity
        }

        return project(self.velocity, onto: self.offset)
    }

    var isMovingTowardsLeadingEdge: Bool {
        let normalizedOffset = (self.parentView.isRTL ? -1.0 : 1.0) * self.offset
        let normalizedVelocity = (self.parentView.isRTL ? -1.0 : 1.0) * self.velocity

        return normalizedOffset < 0.0 && normalizedVelocity < 0.0
    }

    var isMovingTowardsTrailingEdge: Bool {
        let normalizedOffset = (self.parentView.isRTL ? -1.0 : 1.0) * self.offset
        let normalizedVelocity = (self.parentView.isRTL ? -1.0 : 1.0) * self.velocity

        return normalizedOffset > 0.0 && normalizedVelocity > 0.0
    }

    var horizontalThreshold: CGFloat {
        // An approximation of how the Slide Over mode on iPad switches the panel to the other side:
        // - First edge of the panel is over the middle of the screen (landscape mode)
        // - The panel is moved at least 1/2 of it width (portrait mode)
        let midScreen = self.parentView.bounds.midX
        let midScreenDistance = min(abs(midScreen - self.originalFrame.maxX), abs(midScreen - self.originalFrame.minX))
        let minValue = self.originalFrame.width / 2.0
        let maxValue = self.parentView.bounds.width / 2.0

        return min(max(midScreenDistance, minValue), maxValue)
    }

    var trailingEdgeThreshold: CGFloat {
        let trailingEdge = (self.parentView.isRTL ? self.parentView.bounds.minX : self.parentView.bounds.maxX)
        let directionMultiplier: CGFloat = self.parentView.isRTL ? -1.0 : 1.0
        return trailingEdge + directionMultiplier * self.originalFrame.width
    }

    var leadingEdgeThreshold: CGFloat {
        let leadingEdge = (self.parentView.isRTL ? self.parentView.bounds.maxX : self.parentView.bounds.minX)
        let directionMultiplier: CGFloat = self.parentView.isRTL ? -1.0 : 1.0
        return leadingEdge - directionMultiplier * self.originalFrame.width
    }

    var trailingEdge: CGFloat {
        return self.parentView.isRTL ? self.originalFrame.minX : self.originalFrame.maxX
    }

    var leadingEdge: CGFloat {
        return self.parentView.isRTL ? self.originalFrame.maxX : self.originalFrame.minX
    }
}
