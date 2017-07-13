//
//  PanelConstraints.swift
//  Aiolos
//
//  Created by Matthias Tretter on 13/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Foundation


final class PanelConstraints {

    private unowned let panel: PanelViewController

    private var widthConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var positionConstraints: [NSLayoutConstraint] = []

    // MARK: - Lifecycle

    init(panel: PanelViewController) {
        self.panel = panel
    }

    // MARK: - PanelConstraints

    func activateSizeConstraints(for size: CGSize) {
        let widthConstraint = self.panel.view.widthAnchor.constraint(equalToConstant: size.width).configure { c in
            c.identifier = "Panel Width"
            c.priority = .defaultHigh
        }

        let heightConstraint = self.panel.view.heightAnchor.constraint(equalToConstant: size.height).configure { c in
            c.identifier = "Panel Height"
            c.priority = .defaultHigh
        }

        self.widthConstraint = widthConstraint
        self.heightConstraint = heightConstraint
        NSLayoutConstraint.activate([widthConstraint, heightConstraint])
    }

    func deactivatePositionConstraints() {
        NSLayoutConstraint.deactivate(self.positionConstraints)
        self.positionConstraints = []
    }

    func updateSizeConstraints(for mode: Panel.Configuration.Mode) {
        guard let widthConstraint = self.widthConstraint else { return }
        guard let heightConstraint = self.heightConstraint else { return }

        let size = self.panel.size(for: mode)
        self.panel.animateIfNeeded {
            widthConstraint.constant = size.width
            heightConstraint.constant = size.height
        }
    }

    func updatePositionConstraints(for position: Panel.Configuration.Position, margins: UIEdgeInsets) {
        guard let view = self.panel.view else { return }
        guard let parentView = self.panel.parent?.view else { return }

        let guide = parentView.safeAreaLayoutGuide
        var positionConstraints = [
            view.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -margins.bottom).withIdentifier("Panel Bottom"),
            view.topAnchor.constraint(greaterThanOrEqualTo: guide.topAnchor, constant: margins.top).withIdentifier("Panel Top")
        ]

        switch position {
        case .bottom:
            positionConstraints += [
                view.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: margins.left).withIdentifier("Panel Leading"),
                view.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -margins.right).withIdentifier("Panel Trailing")
            ]

        case .leadingBottom:
            positionConstraints += [
                view.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: margins.left).withIdentifier("Panel Leading")
            ]

        case .trailingBottom:
            positionConstraints += [
                view.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -margins.right).withIdentifier("Panel Trailing")
            ]
        }

        self.panel.animateIfNeeded {
            NSLayoutConstraint.deactivate(self.positionConstraints)
            self.positionConstraints = positionConstraints
            NSLayoutConstraint.activate(self.positionConstraints)
        }
    }
}

// MARK: - Private

// MARK: - NSLayoutConstraint

private extension NSLayoutConstraint {

    func configure(_ configuration: (NSLayoutConstraint) -> Void) -> NSLayoutConstraint {
        configuration(self)
        return self
    }

    func withIdentifier(_ identifier: String) -> NSLayoutConstraint {
        return self.configure { c in
            c.identifier = identifier
        }
    }
}
