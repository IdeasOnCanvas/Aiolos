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

        let textField = UITextField(frame: CGRect(x: 50.0, y: 110.0, width: 150.0, height: 44.0))
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

        coordinator.animate(alongsideTransition: { _ in
            self.panelController.performWithoutAnimation {
                self.panelController.configuration = self.configuration(for: newCollection)
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
        func panelWidth(for position: Panel.Configuration.Position) -> CGFloat {
            if position == .bottom { return 0.0 }

            return self.traitCollection.userInterfaceIdiom == .pad ? 320.0 : 270.0
        }

        let width = panelWidth(for: panel.configuration.position)
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

// MARK: - PanelResizeDelegate

extension ViewController: PanelResizeDelegate {

    func panelDidStartResizing(_ panel: Panel) {
        print("Panel did start resizing")
    }

    func panel(_ panel: Panel, willResizeTo size: CGSize) {
        print("Panel will resize to size \(size)")
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

// MARK: - PanelRepositionDelegate

extension ViewController: PanelRepositionDelegate {

    func panelDidStartMoving(_ panel: Panel) {
        print("Panel did start moving")
    }

    func panel(_ panel: Panel, willMoveTo frame: CGRect) -> Bool {
        print("Panel will move to frame \(frame)")

        // we can prevent the panel from begin dragged
        // returning false will result in a rubber-band effect
        return true
    }

    func panel(_ panel: Panel, didStopMoving endFrame: CGRect, with context: PanelRepositionContext) -> PanelRepositionContext.Instruction {
        print("Panel did move to frame \(endFrame)")

        let panelShouldHide = context.isMovingPastLeadingEdge || context.isMovingPastTrailingEdge
        guard !panelShouldHide else { return .hide }

        return .updatePosition(context.targetPosition)
    }

    func panel(_ panel: Panel, willTransitionFrom oldPosition: Panel.Configuration.Position, to newPosition: Panel.Configuration.Position, with coordinator: PanelTransitionCoordinator) {
        print("Panel is transitioning from \(String(describing: oldPosition)) to position \(newPosition)")

        // we can animate things along the way
        coordinator.animateAlongsideTransition({
            print("Animating alongside of panel transition")
        }, completion: { animationPosition in
            print("Completed panel transition to \(newPosition)")
        })
    }

    func panelWillTransitionToHiddenState(_ panel: Panel, with coordinator: PanelTransitionCoordinator) {
        print("Panel is transitioning to hidden state")

        // we can animate things along the way
        coordinator.animateAlongsideTransition({
            print("Animating alongside of panel transition")
        }, completion: { animationPosition in
            print("Completed panel transition to hidden state")
        })
    }
}

// MARK: - UIGestureRecognizerDelegate

extension ViewController: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let contentNavigationController = self.panelController.contentViewController as? UINavigationController else { return true }
        guard let tableViewController = contentNavigationController.topViewController as? UITableViewController else { return true }

        // Prevent swipes on the table view being triggered as the panel is being dragged horizontally
        // More info: https://github.com/IdeasOnCanvas/Aiolos/issues/23
        return otherGestureRecognizer.view !== tableViewController.tableView
    }
}

// MARK: - Private

private extension ViewController {

    func makePanelController() -> Panel {
        let panelController = Panel(configuration: self.configuration(for: self.traitCollection))
        let contentNavigationController = UINavigationController(rootViewController: PanelContentViewController(color: UIColor.red.withAlphaComponent(0.4)))
        contentNavigationController.navigationBar.barTintColor = .white
        contentNavigationController.navigationBar.isTranslucent = false
        contentNavigationController.setToolbarHidden(false, animated: false)
        contentNavigationController.toolbar.barTintColor = .darkGray
        contentNavigationController.view.bringSubviewToFront(contentNavigationController.navigationBar)

        panelController.sizeDelegate = self
        panelController.resizeDelegate = self
        panelController.repositionDelegate = self
        panelController.gestureDelegate = self
        panelController.contentViewController = contentNavigationController

        return panelController
    }

    func configuration(for traitCollection: UITraitCollection) -> Panel.Configuration {
        var configuration = Panel.Configuration.default

        var panelPosition: Panel.Configuration.Position {
            if traitCollection.userInterfaceIdiom == .pad { return .trailingBottom }

            return traitCollection.verticalSizeClass == .compact ? .leadingBottom : .bottom
        }

        var panelMargins: NSDirectionalEdgeInsets {
            if traitCollection.userInterfaceIdiom == .pad  || traitCollection.hasNotch { return NSDirectionalEdgeInsets(top: 20.0, leading: 20.0, bottom: 20.0, trailing: 20.0) }

            let horizontalMargin: CGFloat = traitCollection.verticalSizeClass == .compact ? 20.0 : 0.0
            return NSDirectionalEdgeInsets(top: 20.0, leading: horizontalMargin, bottom: 0.0, trailing: horizontalMargin)
        }
        
        configuration.appearance.separatorColor = .white
        configuration.position = panelPosition
        configuration.margins = panelMargins

        if self.traitCollection.userInterfaceIdiom == .pad {
            configuration.supportedPositions = [.leadingBottom, .trailingBottom]
            configuration.isHorizontalPositioningEnabled = true
            configuration.appearance.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        } else {
            configuration.supportedModes = [.minimal, .compact, .expanded, .fullHeight]
            configuration.supportedPositions = [configuration.position]
            configuration.isHorizontalPositioningEnabled = false

            if traitCollection.hasNotch {
                configuration.appearance.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            } else {
                configuration.appearance.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            }
        }

        return configuration
    }

    @objc
    func handleToggleVisibilityPress() {
        let transition: Panel.Transition = self.traitCollection.userInterfaceIdiom == .pad ? .slide(direction: .horizontal) : .slide(direction: .vertical)

        if self.panelController.isVisible {
            self.panelController.removeFromParent(transition: transition)
        } else {
            self.panelController.add(to: self, transition: transition)
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

private extension UITraitCollection {

    var hasNotch: Bool {
        return UIApplication.shared.keyWindow!.safeAreaInsets.bottom > 0.0
    }
}
