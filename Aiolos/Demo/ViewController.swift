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

        self.view.backgroundColor = .white
        self.panelController.add(to: self)
    }
}

// MARK: - Private

private extension ViewController {

    func makePanelController() -> PanelViewController {
        var configuration = Panel.Configuration.default
        configuration.position = self.traitCollection.userInterfaceIdiom == .pad ? .leadingBottom : .bottom
        configuration.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

        let panelController = PanelViewController(configuration: configuration)
        panelController.contentViewController = PanelContentViewController(color: .clear)

        return panelController
    }
}
