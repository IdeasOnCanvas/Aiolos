//
//  ViewController.swift
//  Aiolos
//
//  Created by Matthias Tretter on 11/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Aiolos
import UIKit


/// The RootViewController of the Demo
final class ViewController: UIViewController {

    private lazy var panelController: Panel = self.makePanelController()

    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Aiolos Demo"
        self.view.backgroundColor = .white

        let safeAreaView = UIView()
        safeAreaView.translatesAutoresizingMaskIntoConstraints = false
        safeAreaView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
        self.view.addSubview(safeAreaView)
        NSLayoutConstraint.activate([
            safeAreaView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 8.0),
            safeAreaView.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 8.0),
            safeAreaView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -8.0),
            safeAreaView.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: -8.0)
        ])

        let textField = UITextField(frame: CGRect(x: 10.0, y: 74.0, width: 150.0, height: 44.0))
        textField.layer.borderWidth = 1.0
        textField.delegate = self
        self.view.addSubview(textField)

        self.navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(handleToggleVisibilityPress)),
            UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(handleToggleModePress))
        ]

        self.panelController.add(to: self, transition: .none)
    }

    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)

        var configuration = self.panelController.configuration
        configuration.position = self.panelPosition(for: newCollection)
        configuration.margins = self.panelMargins(for: newCollection)

        coordinator.animate(alongsideTransition: { _ in
            self.panelController.performWithoutAnimation {
                self.panelController.configuration = configuration
            }
        }, completion: nil)
    }

    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return [.bottom]
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

    func panel(_ panel: Panel, sizeForMode mode: Panel.Configuration.Mode) -> CGSize {
        let width = self.panelWidth(for: self.traitCollection, position: panel.configuration.position)
        switch mode {
        case .minimal:
            return CGSize(width: width, height: 0.0)
        case .compact:
            return CGSize(width: width, height: 64.0)
        case .expanded:
            let height: CGFloat = self.traitCollection.userInterfaceIdiom == .phone ? 270.0 : 320.0
            return CGSize(width: width, height: height)
        case .fullHeight:
            return CGSize(width: width, height: 0.0)
        }
    }
}

// MARK: - PanelAnimationDelegate

extension ViewController: PanelAnimationDelegate {

    func panel(_ panel: Panel, willTransitionTo size: CGSize) {
        print("Panel will transition to size \(size)")
    }

    func panel(_ panel: Panel, willTransitionFrom oldMode: Panel.Configuration.Mode?, to newMode: Panel.Configuration.Mode, with coordinator: PanelTransitionCoordinator) {
        print("Panel will transition from \(String(describing: oldMode)) to \(newMode)")

        // we can animate things along the way
        coordinator.animateAlongsideTransition({
            print("Animating alongside of panel transition")
        }, completion: { animationPosition in
            print("Completed panel transition to \(newMode)")
        })
    }
}

// MARK: - Private

private extension ViewController {

    func makePanelController() -> Panel {
        let configuration = Panel.Configuration.default
        let panelController = Panel(configuration: configuration)
        let contentNavigationController = UINavigationController(rootViewController: PanelContentViewController(color: UIColor.red.withAlphaComponent(0.4)))
        contentNavigationController.navigationBar.barTintColor = .white
        contentNavigationController.navigationBar.isTranslucent = false
        contentNavigationController.setToolbarHidden(false, animated: false)
        contentNavigationController.toolbar.barTintColor = .darkGray
        contentNavigationController.view.bringSubviewToFront(contentNavigationController.navigationBar)

        panelController.sizeDelegate = self
        panelController.animationDelegate = self
        panelController.contentViewController = contentNavigationController
        panelController.configuration.position = self.panelPosition(for: self.traitCollection)
        panelController.configuration.margins = self.panelMargins(for: self.traitCollection)
        panelController.configuration.appearance.separatorColor = .white

        if self.traitCollection.userInterfaceIdiom == .pad {
            panelController.configuration.appearance.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        } else {
            panelController.configuration.supportedModes = [.minimal, .compact, .expanded, .fullHeight]
            panelController.configuration.appearance.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        }

        return panelController
    }

    func panelWidth(for traitCollection: UITraitCollection, position: Panel.Configuration.Position) -> CGFloat {
        if position == .bottom { return 0.0 }

        return traitCollection.userInterfaceIdiom == .pad ? 320.0 : 270.0
    }

    func panelPosition(for traitCollection: UITraitCollection) -> Panel.Configuration.Position {
        if traitCollection.userInterfaceIdiom == .pad { return .trailingBottom }

        return traitCollection.verticalSizeClass == .compact ? .leadingBottom : .bottom
    }

    func panelMargins(for traitCollection: UITraitCollection) -> NSDirectionalEdgeInsets {
        if traitCollection.userInterfaceIdiom == .pad { return NSDirectionalEdgeInsets(top: 20.0, leading: 20.0, bottom: 20.0, trailing: 20.0) }

        let horizontalMargin: CGFloat = traitCollection.verticalSizeClass == .compact ? 20.0 : 0.0
        return NSDirectionalEdgeInsets(top: 20.0, leading: horizontalMargin, bottom: 0.0, trailing: horizontalMargin)
    }

    @objc
    func handleToggleVisibilityPress() {
        if self.panelController.isVisible {
            self.panelController.removeFromParent(transition: .slide(direction: .vertical))
        } else {
            self.panelController.add(to: self, transition: .slide(direction: .vertical))
        }
    }

    @objc
    func handleToggleModePress() {
        let nextModeMapping: [Panel.Configuration.Mode: Panel.Configuration.Mode] = [ .compact: .expanded,
                                                                                      .expanded: .fullHeight,
                                                                                      .fullHeight: .compact ]
        guard let nextMode = nextModeMapping[self.panelController.configuration.mode] else { return }

        self.panelController.configuration.mode = nextMode
    }
}
