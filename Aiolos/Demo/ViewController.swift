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

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(handleTogglePanelPress))
    }
}

// MARK: - Private

private extension ViewController {

    func makePanelController() -> PanelViewController {
        let configuration = Panel.Configuration.default
        let panelController = PanelViewController(configuration: configuration)

        panelController.contentViewController = PanelContentViewController(color: .red)
        panelController.configuration.position = self.traitCollection.userInterfaceIdiom == .pad ? .leadingBottom : .bottom
        panelController.configuration.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

        return panelController
    }

    @objc
    func handleTogglePanelPress() {
        if self.panelController.isVisible {
            self.panelController.removeFromParent()
        } else {
            self.panelController.add(to: self)
        }
    }

}
