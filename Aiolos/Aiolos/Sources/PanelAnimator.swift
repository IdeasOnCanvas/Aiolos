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

    func animateIfNeeded(_ changes: () -> Void) {
        guard self.animateChanges && self.panel.isVisible else {
            changes()
            return
        }

        let parentView = self.panel.parent?.view
        withoutActuallyEscaping(changes) { changes in
            parentView?.layoutIfNeeded()
            UIView.animate(withDuration: 0.42,
                           delay: 0.0,
                           usingSpringWithDamping: 0.8,
                           initialSpringVelocity: 1.0,
                           options: [.beginFromCurrentState],
                           animations: {
                            changes()
                            parentView?.layoutIfNeeded()
            })
        }
    }

    func performWithoutAnimation(_ changes: () -> Void) {
        let animateBefore = self.animateChanges
        self.animateChanges = false
        defer { self.animateChanges = animateBefore }

        changes()
    }
}
