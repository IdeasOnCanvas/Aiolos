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

    private lazy var panelView: PanelView = self.makePanelView()
    private var containerView: UIView { return self.view }

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

// MARK: - UIViewController

public extension PanelViewController {

    override func loadView() {
        self.view = self.makeContainer(for: self.panelView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()


    }
}

// MARK: - PanelViewController

public extension PanelViewController {

    func addTo(parent: UIViewController) {
        parent.addChildViewController(self)
        parent.view.addSubview(self.view)
        self.didMove(toParentViewController: parent)
    }
}

// MARK: - Private

private extension PanelViewController {

    func makePanelView() -> PanelView {
        return PanelView(configuration: self.configuration)
    }

    func makeContainer(for view: UIView) -> UIView {
        let container = UIView()

        // create view hierachy
        view.frame = container.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(view)

        // configure shadow
        container.layer.shadowOpacity = 0.2
        container.layer.shadowOffset = .zero

        // configure border
        container.layer.cornerRadius = self.configuration.cornerRadius
        container.layer.borderColor = self.configuration.borderColor.cgColor
        container.layer.borderWidth = 1.0 / UIScreen.main.scale

        return container
    }

    func handleConfigurationChange() {
        print("Configuration was changed, need to reload stuff")
    }
}
