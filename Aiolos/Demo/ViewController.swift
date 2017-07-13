//
//  ViewController.swift
//  Aiolos
//
//  Created by Matthias Tretter on 11/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import UIKit
import Aiolos


final class ViewController: UIViewController {

    private lazy var panelController: PanelViewController = self.makePanelController()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Aiolos Demo"
        self.view.backgroundColor = .white

        self.navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(handleToggleVisibilityPress)),
            UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(handleToggleModePress))
        ]

        self.panelController.add(to: self)
    }
}

// MARK: - PanelSizeDelegate

extension ViewController: PanelSizeDelegate {

    func panel(_ panel: PanelViewController, sizeForMode mode: Panel.Configuration.Mode) -> CGSize {
        let width = self.traitCollection.userInterfaceIdiom == .pad ? 320.0 : 0.0
        switch mode {
        case .collapsed:
            return CGSize(width: width, height: 64.0)
        case .expanded:
            return CGSize(width: width, height: 250.0)
        case .fullHeight:
            return CGSize(width: width, height: 0.0)
        }
    }
}

// MARK: - PanelAnimationDelegate

extension ViewController: PanelAnimationDelegate {

    func panel(_ panel: PanelViewController, willTransitionTo mode: Panel.Configuration.Mode, with coordinator: PanelTransitionCoordinator) {
        print("Will transition to \(mode)")
        coordinator.animateAlongsideTransition({
            print("Animating along")
        }) { position in
            print("Completed animation at \(position)")
        }
    }
}

// MARK: - Private

private extension ViewController {

    func makePanelController() -> PanelViewController {
        let configuration = Panel.Configuration.default
        let panelController = PanelViewController(configuration: configuration)

        panelController.sizeDelegate = self
        panelController.animationDelegate = self
        panelController.contentViewController = PanelContentViewController(color: .clear)

        if self.traitCollection.userInterfaceIdiom == .pad {
            panelController.configuration.position = .trailingBottom
            panelController.configuration.margins = UIEdgeInsets(top: 20.0, left: 20.0, bottom: 20.0, right: 20.0)
            panelController.configuration.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        } else {
            panelController.configuration.position = .bottom
            panelController.configuration.margins = UIEdgeInsets(top: 20.0, left: 0.0, bottom: 0.0, right: 0.0)
            panelController.configuration.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        }

        return panelController
    }

    @objc
    func handleToggleVisibilityPress() {
        if self.panelController.isVisible {
            self.panelController.removeFromParent()
        } else {
            self.panelController.add(to: self)
        }
    }

    @objc
    func handleToggleModePress() {
        let nextModeMapping: [Panel.Configuration.Mode: Panel.Configuration.Mode] = [ .collapsed: .expanded,
                                                                                      .expanded: .fullHeight,
                                                                                      .fullHeight: .collapsed ]
        guard let nextMode = nextModeMapping[self.panelController.configuration.mode] else { return }

        self.panelController.configuration.mode = nextMode
    }
}
