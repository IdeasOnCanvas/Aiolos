//
//  PanelViewController.swift
//  Aiolos
//
//  Created by Matthias Tretter on 11/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Foundation


/// A floating Panel inspired by the iOS 11 Maps.app UI
public final class PanelViewController: UIViewController {

    private lazy var panelView: PanelView = self.makePanelView()
    private var containerView: ContainerView? { return self.viewIfLoaded as? ContainerView }
    private lazy var dimmingView: UIView = self.makeDimmingView()
    lazy var resizeHandle: ResizeHandle = self.makeResizeHandle()

    private lazy var gestures: PanelGestures = self.makeGestures()
    lazy var constraints: PanelConstraints = self.makeConstraints()
    lazy var animator: PanelAnimator = self.makeAnimator()

    // MARK: - Properties

    public var isVisible: Bool { return self.parent != nil }
    public weak var sizeDelegate: PanelSizeDelegate?
    public weak var animationDelegate: PanelAnimationDelegate?

    public var configuration: Panel.Configuration {
        didSet {
            self.handleConfigurationChange(from: oldValue, to: self.configuration)
        }
    }

    public var contentViewController: UIViewController? {
        didSet {
            self.updateContentViewControllerFrame(of: self.contentViewController)
            self.exchangeContentViewController(oldValue, with: self.contentViewController)
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

        self.gestures.install()
        self.view.addSubview(self.resizeHandle)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        self.panelView.frame = self.view.bounds
        self.resizeHandle.frame = CGRect(x: 0.0, y: 0.0, width: self.view.frame.width, height: 10.0)
    }
}

// MARK: - PanelViewController

public extension PanelViewController {

    func add(to parent: UIViewController) {
        parent.addChildViewController(self)
        parent.view.addSubview(self.view)
        self.didMove(toParentViewController: parent)

        let size = self.size(for: self.configuration.mode)
        self.animator.performWithoutAnimation {
            self.animator.notifyDelegateOfTransition(to: size)
            self.constraints.updateSizeConstraints(for: size)
            self.constraints.updatePositionConstraints(for: self.configuration.position, margins: self.configuration.margins)
        }
    }

    func removeFromParent() {
        guard self.parent != nil else { return }

        self.willMove(toParentViewController: nil)
        self.view.removeFromSuperview()
        self.removeFromParentViewController()
    }
}

// MARK: - Internal

internal extension PanelViewController {

    func size(for mode: Panel.Configuration.Mode) -> CGSize {
        guard let sizeDelegate = self.sizeDelegate else { return .zero }
        guard let parent = self.parent else { return .zero }

        let delegateSize = sizeDelegate.panel(self, sizeForMode: mode)
        let screen = parent.view.window?.screen ?? UIScreen.main

        // we overwrite the height in .fullHeight mode
        let height = mode == .fullHeight ? screen.fixedCoordinateSpace.bounds.height : delegateSize.height
        return CGSize(width: delegateSize.width, height: height)
    }
}

// MARK: - Private

// MARK: - Factory

private extension PanelViewController {

    func makePanelView() -> PanelView {
        return PanelView(configuration: self.configuration)
    }

    func makeContainer(for view: UIView) -> UIView {
        let container = ContainerView(configuration: self.configuration)

        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)

        return container
    }

    func makeDimmingView() -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
        view.alpha = 0.0
        return view
    }

    func makeResizeHandle() -> ResizeHandle {
        return ResizeHandle(configuration: self.configuration)
    }

    func makeGestures() -> PanelGestures {
        return PanelGestures(panel: self)
    }

    func makeConstraints() -> PanelConstraints {
        return PanelConstraints(panel: self)
    }

    func makeAnimator() -> PanelAnimator {
        return PanelAnimator(panel: self)
    }
}

// MARK: - Layout

private extension PanelViewController {

    func updateContentViewControllerFrame(of contentViewController: UIViewController?) {
        guard let contentViewController = contentViewController else { return }

        contentViewController.view.frame = self.panelView.contentView.bounds
        contentViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    func exchangeContentViewController(_ oldContentViewController: UIViewController?, with newContentViewController: UIViewController?) {
        // remove old contentViewController
        if let oldContentViewController = oldContentViewController {
            oldContentViewController.willMove(toParentViewController: nil)
            oldContentViewController.view.removeFromSuperview()
            oldContentViewController.removeFromParentViewController()
        }

        // add new contentViewController
        if let newContentViewController = newContentViewController {
            self.addChildViewController(newContentViewController)
            self.panelView.contentView.addSubview(newContentViewController.view)
            newContentViewController.didMove(toParentViewController: self)
        }
    }

    func handleConfigurationChange(from oldConfiguration: Panel.Configuration, to newConfiguration: Panel.Configuration) {
        self.panelView.configure(with: newConfiguration)
        self.resizeHandle.configure(with: newConfiguration)
        self.containerView?.configure(with: newConfiguration)

        let modeChanged = oldConfiguration.mode != newConfiguration.mode
        let positionChanged = oldConfiguration.position != newConfiguration.position

        if modeChanged || positionChanged {
            let size = self.size(for: newConfiguration.mode)
            self.animator.notifyDelegateOfTransition(to: size)
            self.constraints.updateSizeConstraints(for: size)
        }

        if positionChanged {
            self.constraints.updatePositionConstraints(for: newConfiguration.position, margins: newConfiguration.margins)
        }
    }
}
