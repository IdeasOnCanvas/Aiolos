//
//  PanelGestures.swift
//  Aiolos
//
//  Created by Matthias Tretter on 14/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Foundation


/// Manages Gestures added to the Panel
final class PanelGestures {

    private let panel: PanelViewController

    // MARK: - Lifecycle

    init(panel: PanelViewController) {
        self.panel = panel
    }

    // MARK: - PanelGestures

    func install() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        self.panel.view.addGestureRecognizer(pan)
    }
}

// MARK: - Private

private extension PanelGestures {

    @objc
    func handlePan(_ pan: UIPanGestureRecognizer) {

    }
}
