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
    private lazy var lineView: UIView = self.makeLineView()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Aiolos Demo"
        self.view.backgroundColor = .white

        let textField = UITextField(frame: CGRect(x: 10.0, y: 74.0, width: 150.0, height: 44.0))
        textField.layer.borderWidth = 1.0
        textField.delegate = self
        self.view.addSubview(textField)
        self.view.addSubview(self.lineView)

        self.navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(handleToggleVisibilityPress)),
            UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(handleToggleModePress))
        ]

        self.panelController.add(to: self)
    }
}

// MARK: - UITextFieldDelegate

extension ViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
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

    func panel(_ panel: PanelViewController, willTransitionTo size: CGSize, with coordinator: PanelTransitionCoordinator) {
        print("Will transition to \(size), animated: \(coordinator.isAnimated)")
        coordinator.animateAlongsideTransition({
            self.lineView.center = CGPoint(x: panel.view.center.x, y: panel.view.frame.minY - 5.0)
        })
    }
}

// MARK: - Private

private extension ViewController {

    func makePanelController() -> PanelViewController {
        let configuration = Panel.Configuration.default
        let panelController = PanelViewController(configuration: configuration)
        let contentNavigationController = UINavigationController(rootViewController: PanelContentViewController(color: .clear))
        contentNavigationController.setToolbarHidden(false, animated: false)

        panelController.sizeDelegate = self
        panelController.animationDelegate = self
        panelController.contentViewController = contentNavigationController

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

    func makeLineView() -> UIView {
        let view = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 1.0))
        view.backgroundColor = .red
        return view
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
