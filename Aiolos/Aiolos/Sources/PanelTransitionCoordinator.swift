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
        private let pan: PanGestureRecognizer
        private let originalFrame: CGRect
        
        // MARK: - Lifecycle
        
        init(panel: Panel, pan: PanGestureRecognizer, originalFrame: CGRect) {
            self.panel = panel
            self.pan = pan
            self.originalFrame = originalFrame
        }
        
        // MARK: - HorizontalTransitionContext
        
        public func projectedDelta(in view: UIView) -> CGFloat {
            let projectedOffset = self.projectedOffset(in: view)
            let delta = abs(projectedOffset)
            return delta
        }
        
        public func horizontalThreshold(in view: UIView) -> CGFloat {
            let midScreen = view.bounds.minX
            return min(abs(midScreen - self.originalFrame.maxX), abs(midScreen - self.originalFrame.minX))
        }
        
        public func rightEdgeThreshold(in view: UIView) -> CGFloat {
            return view.bounds.maxX + self.originalFrame.width/3
        }
        
        public func leftEdgeThreshold(in view: UIView) -> CGFloat {
            return view.bounds.minX - self.originalFrame.width/3
        }
        
        public func projectedOffset(in view: UIView) -> CGFloat {
            let velocity = self.pan.velocity(in: view)
            let translation = self.pan.translation(in: view)
            
            return project(velocity.x, onto: translation.x)
        }
        
        public func isMovingTowardsLeadingEdge(in view: UIView) -> Bool {
            let projectedOffset = self.projectedOffset(in: view)
            let normalizedProjectedOffset = (view.isRTL ? -1 : 1) * projectedOffset
            
            return normalizedProjectedOffset < 0
        }
        
        public func isMovingTowardsTrailingEdge(in view: UIView) -> Bool {
            let projectedOffset = self.projectedOffset(in: view)
            let normalizedProjectedOffset = (view.isRTL ? -1 : 1) * projectedOffset
            
            return normalizedProjectedOffset > 0
        }
        
        public func targetPosition(in view: UIView) -> Panel.Configuration.Position {
            let supportedPositions = panel.configuration.supportedPositions
            let originalPosition = panel.configuration.position
            
            if isMovingTowardsLeadingEdge(in: view) && supportedPositions.contains(.leadingBottom) {
                return .leadingBottom
            }
            
            if isMovingTowardsTrailingEdge(in: view) && supportedPositions.contains(.trailingBottom) {
                return .trailingBottom
            }
            
            return originalPosition
        }
        
        public func isMovingPastLeadingEdge(in view: UIView) -> Bool {
            guard self.panel.configuration.position == .leadingBottom else { return false }
            return self.destinationFrame.minX < leftEdgeThreshold(in: view)
        }
        
        public func isMovingPastTrailingEdge(in view: UIView) -> Bool {
            guard self.panel.configuration.position == .trailingBottom else { return false }
            return self.destinationFrame.maxX > rightEdgeThreshold(in: view)
        }
    }
}

// MARK: - Private

private extension PanelTransitionCoordinator.HorizontalTransitionContext {
    
    var destinationFrame: CGRect {
        return self.panel.view.frame
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
