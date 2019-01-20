//
//  PanelTransitionCoordinator.swift
//  Aiolos
//
//  Created by Matthias Tretter on 11/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Foundation
import UIKit


/// This coordinator can be used to animate things alongside the movement of the Panel
public final class PanelTransitionCoordinator {

    public enum Direction {
        case horizontal(context: HorizontalTransitionContext)
        case vertical
    }
    
    private unowned let animator: PanelAnimator

    // MARK: - Properties

    public let direction: Direction
    public var isAnimated: Bool { return self.animator.animateChanges }
    
    // MARK: - Lifecycle

    init(animator: PanelAnimator, direction: Direction) {
        self.animator = animator
        self.direction = direction
    }

    // MARK: - PanelTransitionCoordinator

    public func animateAlongsideTransition(_ animations: @escaping () -> Void, completion: ((UIViewAnimatingPosition) -> Void)? = nil) {
        self.animator.transitionCoordinatorQueuedAnimations.append(Animation(animations: animations, completion: completion))
    }
}

extension PanelTransitionCoordinator.Direction {
    public var context: PanelTransitionCoordinator.HorizontalTransitionContext? {
        switch self {
        case .horizontal(let context):
            return context
        case .vertical:
            return nil
        }
    }
}

extension PanelTransitionCoordinator {

    struct Animation {
        let animations: () -> Void
        let completion: ((UIViewAnimatingPosition) -> Void)?
    }
}

// MARK: - HorizontalTransitionContext

public extension PanelTransitionCoordinator {
    
    final class HorizontalTransitionContext {
        
        private unowned let panel: Panel
        private unowned let parentView: UIView
        private let originalFrame: CGRect
        private let offset: CGFloat
        private let velocity: CGFloat
        
        // MARK: - Lifecycle
        
        init(panel: Panel, parentView: UIView, originalFrame: CGRect, offset: CGFloat, velocity: CGFloat) {
            self.panel = panel
            self.parentView = parentView
            self.originalFrame = originalFrame
            self.offset = offset
            self.velocity = velocity
        }
        
        // MARK: - HorizontalTransitionContext
        
        public func targetPosition(in view: UIView) -> Panel.Configuration.Position {
            let supportedPositions = self.panel.configuration.supportedPositions
            let originalPosition = self.panel.configuration.position
            
            guard self.projectedDelta > self.horizontalThreshold else { return originalPosition }
            
            if self.isMovingTowardsLeadingEdge && supportedPositions.contains(.leadingBottom) {
                return .leadingBottom
            }
            
            if self.isMovingTowardsTrailingEdge && supportedPositions.contains(.trailingBottom) {
                return .trailingBottom
            }
            
            return originalPosition
        }
        
        public var isMovingPastLeadingEdge: Bool {
            guard self.panel.configuration.position == .leadingBottom else { return false }
            return self.destinationFrame.minX < self.leftEdgeThreshold
        }
        
        public var isMovingPastTrailingEdge: Bool {
            guard self.panel.configuration.position == .trailingBottom else { return false }
            return self.destinationFrame.maxX > self.rightEdgeThreshold
        }
    }
}

// MARK: - Private

private extension PanelTransitionCoordinator.HorizontalTransitionContext {
    
    var destinationFrame: CGRect {
        return self.panel.view.frame
    }
    
    var projectedOffset: CGFloat {
        return project(velocity, onto: offset)
    }
    
    var projectedDelta: CGFloat {
        let projectedOffset = self.projectedOffset
        let delta = abs(projectedOffset)
        return delta
    }
    
    var isMovingTowardsLeadingEdge: Bool {
        let normalizedProjectedOffset = (self.parentView.isRTL ? -1 : 1) * self.projectedOffset
        
        return normalizedProjectedOffset < 0
    }
    
    var isMovingTowardsTrailingEdge: Bool {
        let normalizedProjectedOffset = (self.parentView.isRTL ? -1 : 1) * self.projectedOffset
        
        return normalizedProjectedOffset > 0
    }
    
    var horizontalThreshold: CGFloat {
        // An approximation of how the Slide Over mode on iPad switches the panel to the other side:
        // - First edge of the panel is over the middle of the screen (landscape mode)
        // - The panel is moved at least 1/2 of it width (portrait mode)
        let midScreen = self.parentView.bounds.midX
        let midScreenDistance = min(abs(midScreen - self.originalFrame.maxX), abs(midScreen - self.originalFrame.minX))
        let minValue = self.originalFrame.width/2
        let maxValue = self.parentView.bounds.width/2
        return min(max(midScreenDistance, minValue), maxValue)
    }
    
    var rightEdgeThreshold: CGFloat {
        return self.parentView.bounds.maxX + self.originalFrame.width/3
    }
    
    var leftEdgeThreshold: CGFloat {
        return self.parentView.bounds.minX - self.originalFrame.width/3
    }
}

private extension UIView {
    var isRTL: Bool {
        return self.effectiveUserInterfaceLayoutDirection == .rightToLeft
    }
}

// Inspired by: https://medium.com/ios-os-x-development/gestures-in-fluid-interfaces-on-intent-and-projection-36d158db7395
private func project(_ velocity: CGFloat, onto position: CGFloat, decelerationRate: UIScrollView.DecelerationRate = .normal) -> CGFloat {
    let factor = -1 / (1000 * log(decelerationRate.rawValue))
    return position + factor * velocity
}
