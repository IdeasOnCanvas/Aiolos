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

// MARK: - PanelTransitionCoordinator.Direction

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

// MARK: - PanelTransitionCoordinator.Animation

extension PanelTransitionCoordinator {

    struct Animation {
        let animations: () -> Void
        let completion: ((UIViewAnimatingPosition) -> Void)?
    }
}

// MARK: - PanelTransitionCoordinator.HorizontalTransitionContext

public extension PanelTransitionCoordinator {
    
    final class HorizontalTransitionContext {
        
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
        
        // MARK: HorizontalTransitionContext
        
        public var targetPosition: Panel.Configuration.Position {
            let supportedPositions = self.panel.configuration.supportedPositions
            let originalPosition = self.panel.configuration.position
            
            guard abs(self.projectedOffset) > self.horizontalThreshold else { return originalPosition }
            
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

            if self.parentView.isRTL {
                guard offset > 0 else { return false }

                return self.leadingEdge + projectedOffset > self.leadingEdgeThreshold
            } else {
                guard offset < 0 else { return false }

                return self.leadingEdge + projectedOffset < self.leadingEdgeThreshold
            }
        }
        
        public var isMovingPastTrailingEdge: Bool {
            guard self.panel.configuration.position == .trailingBottom else { return false }

            if self.parentView.isRTL {
                guard offset < 0 else { return false }

                return self.trailingEdge + projectedOffset < self.trailingEdgeThreshold
            } else {
                guard offset > 0 else { return false }

                return self.trailingEdge + projectedOffset > self.trailingEdgeThreshold
            }
        }
    }
}

// MARK: - Private

private extension PanelTransitionCoordinator.HorizontalTransitionContext {
    
    var projectedOffset: CGFloat {
        // Inspired by: https://medium.com/ios-os-x-development/gestures-in-fluid-interfaces-on-intent-and-projection-36d158db7395
        func project(_ velocity: CGFloat, onto position: CGFloat, decelerationRate: UIScrollView.DecelerationRate = .normal) -> CGFloat {
            let factor = -1.0 / (1000.0 * log(decelerationRate.rawValue))
            return position + factor * velocity
        }

        return project(self.velocity, onto: self.offset)
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
        let minValue = self.originalFrame.width / 2.0
        let maxValue = self.parentView.bounds.width / 2.0

        return min(max(midScreenDistance, minValue), maxValue)
    }
    
    var trailingEdgeThreshold: CGFloat {
        let trailingEdge = (self.parentView.isRTL ? self.parentView.bounds.minX : self.parentView.bounds.maxX)
        let directionMultiplier: CGFloat = self.parentView.isRTL ? -1 : 1
        return trailingEdge + (directionMultiplier * self.originalFrame.width / 3.0)
    }
    
    var leadingEdgeThreshold: CGFloat {
        let leadingEdge = (self.parentView.isRTL ? self.parentView.bounds.maxX : self.parentView.bounds.minX)
        let directionMultiplier: CGFloat = self.parentView.isRTL ? -1 : 1
        return leadingEdge - (directionMultiplier * self.originalFrame.width / 3.0)
    }
    
    var trailingEdge: CGFloat {
        return self.parentView.isRTL ? self.originalFrame.minX : self.originalFrame.maxX
    }
    
    var leadingEdge: CGFloat {
        return self.parentView.isRTL ? self.originalFrame.maxX : self.originalFrame.minX
    }
}

private extension UIView {

    var isRTL: Bool {
        return self.effectiveUserInterfaceLayoutDirection == .rightToLeft
    }
}
