//
//  PanelAnimator.swift
//  Aiolos
//
//  Created by Matthias Tretter on 13/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Foundation


/// Internal class used to drive animations of the Panel
final class PanelAnimator {

    private unowned let panel: PanelViewController

    var animateChanges: Bool = true

    // MARK: - Lifecycle

    init(panel: PanelViewController) {
        self.panel = panel
    }

    // MARK: - PanelAnimator

    func animateIfNeeded(_ changes: @escaping () -> Void) {
        guard self.animateChanges && self.panel.isVisible else {
            self.performWithoutAnimation(changes)
            return
        }

        let parentView = self.panel.parent?.view
        parentView?.layoutIfNeeded()

        let animator = UIViewPropertyAnimator(duration: 0.42, dampingRatio: 0.8, animations: {
            changes()
            parentView?.layoutIfNeeded()
        })

        animator.startAnimation()
    }

    func performWithoutAnimation(_ changes: () -> Void) {
        let animateBefore = self.animateChanges
        self.animateChanges = false
        defer { self.animateChanges = animateBefore }

        UIView.performWithoutAnimation(changes)
    }
}
