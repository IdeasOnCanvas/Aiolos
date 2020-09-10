//
//  PanelRepositionContext.swift
//  Aiolos
//
//  Created by Tom Kraina on 13/02/2019.
//  Copyright © 2019 Matthias Tretter. All rights reserved.
//

import UIKit


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
        guard self.normalized(self.offset) < 0.0 else { return false }

        return self.normalized(self.projectedOffset) < -self.hidingTreshold
    }

    public var isMovingPastTrailingEdge: Bool {
        guard self.panel.configuration.position == .trailingBottom else { return false }
        guard self.normalized(self.offset) > 0.0 else { return false }

        return self.normalized(self.projectedOffset) > self.hidingTreshold
    }
}

// MARK: - Private

private extension PanelRepositionContext {

    func normalized(_ value: CGFloat) -> CGFloat {
        return (self.parentView.isRTL ? -1.0 : 1.0) * value
    }

    var projectedOffset: CGFloat {
        // Inspired by: https://medium.com/ios-os-x-development/gestures-in-fluid-interfaces-on-intent-and-projection-36d158db7395
        func project(_ velocity: CGFloat, onto position: CGFloat, decelerationRate: UIScrollView.DecelerationRate = .normal) -> CGFloat {
            let factor = -1.0 / (1000.0 * log(decelerationRate.rawValue))
            return position + factor * velocity
        }

        return project(self.velocity, onto: self.offset)
    }

    var isMovingTowardsLeadingEdge: Bool {
        let normalizedProjectedOffset = self.normalized(self.projectedOffset)
        return normalizedProjectedOffset < -self.repositioningThreshold
    }

    var isMovingTowardsTrailingEdge: Bool {
        let normalizedProjectedOffset = self.normalized(self.projectedOffset)
        return normalizedProjectedOffset > self.repositioningThreshold
    }

    var repositioningThreshold: CGFloat {
        // An approximation of how the Slide Over mode on iPad switches the panel to the other side:
        // - First edge of the panel is over the middle of the screen (landscape mode)
        // - The panel is moved at least 1/2 of it width (portrait mode)
        let midScreen = self.parentView.bounds.midX
        let midScreenDistance = min(abs(midScreen - self.originalFrame.maxX), abs(midScreen - self.originalFrame.minX))
        let minValue = self.originalFrame.width / 2.0
        let maxValue = self.parentView.bounds.width / 2.0

        return min(max(midScreenDistance, minValue), maxValue)
    }

    var hidingTreshold: CGFloat {
        // An approximation of how the Slide Over mode on iPad hides the panel:
        // - The panel is moved at least 1/3 of its width towards the edge of the screen
        return self.originalFrame.width / 3.0
    }
}
