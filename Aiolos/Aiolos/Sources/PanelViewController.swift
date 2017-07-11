//
//  PanelViewController.swift
//  Aiolos
//
//  Created by Matthias Tretter on 11/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Foundation


/// A floating Panel mimicing the iOS 11 Maps.app UI
public final class PanelViewController: UIViewController {

    private var configuration: Panel.Configuration {
        didSet {
            self.handleConfigurationChange()
        }
    }

    // MARK: - Lifecycle

    public init(configuration: Panel.Configuration = .default) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


// MARK: - Private

private extension PanelViewController {

    func handleConfigurationChange() {

    }
}
