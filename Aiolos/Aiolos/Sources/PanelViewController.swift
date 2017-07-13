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
    private lazy var constraints: PanelConstraints = self.makeConstraints()

    // MARK: - Properties

    public var isVisible: Bool { return self.parent != nil }
    public var animateChanges: Bool = true
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
}

// MARK: - PanelViewController

public extension PanelViewController {

    func add(to parent: UIViewController) {
        parent.addChildViewController(self)
        parent.view.addSubview(self.view)
        self.didMove(toParentViewController: parent)

        let size = self.size(for: self.configuration.mode)
        self.performWithoutAnimation {
            self.constraints.activateSizeConstraints(for: size)
            self.constraints.updatePositionConstraints(for: self.configuration.position, margins: self.configuration.margins)
        }
    }

    func removeFromParent() {
        guard self.parent != nil else { return }

        self.willMove(toParentViewController: nil)
        self.view.removeFromSuperview()
        self.removeFromParentViewController()
        self.constraints.deactivatePositionConstraints()
    }
}

// MARK: - Internal

internal extension PanelViewController {

    func size(for mode: Panel.Configuration.Mode) -> CGSize {
        guard let sizeDelegate = self.sizeDelegate else { return .zero }
        guard let parent = self.parent else { return .zero }

        let delegateSize = sizeDelegate.panel(self, sizeForMode: mode)
        let maxSize = parent.view.bounds.insetBy(parent.view.safeAreaInsets).size

        // we overwrite the height in .fullHeight mode
        let height = mode == .fullHeight ? maxSize.height : delegateSize.height
        return CGSize(width: min(delegateSize.width, maxSize.width), height: min(height, maxSize.height))
    }

    func animateIfNeeded(_ changes: () -> Void) {
        guard self.animateChanges && self.isVisible else {
            changes()
            return
        }

        withoutActuallyEscaping(changes) { changes in
            self.parent?.view.layoutIfNeeded()
            UIView.animate(withDuration: 0.42,
                           delay: 0.0,
                           usingSpringWithDamping: 0.8,
                           initialSpringVelocity: 1.0,
                           options: [.beginFromCurrentState],
                           animations: {
                            changes()
                            self.parent?.view.layoutIfNeeded()
            })
        }
    }

    func performWithoutAnimation(_ changes: () -> Void) {
        let animateBefore = self.animateChanges
        self.animateChanges = false
        defer { self.animateChanges = animateBefore }

        changes()
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

        // create view hierachy
        view.frame = container.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(view)
        container.translatesAutoresizingMaskIntoConstraints = false

        return container
    }

    func makeConstraints() -> PanelConstraints {
        return PanelConstraints(panel: self)
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
        self.containerView?.configure(with: newConfiguration)

        if oldConfiguration.mode != newConfiguration.mode {
            self.constraints.updateSizeConstraints(for: newConfiguration.mode)
        }

        if oldConfiguration.position != newConfiguration.position {
            self.constraints.updatePositionConstraints(for: newConfiguration.position, margins: newConfiguration.margins)
        }
    }
}

// MARK: - CGRect

private extension CGRect {

    func insetBy(_ edgeInsets: UIEdgeInsets) -> CGRect {
        return UIEdgeInsetsInsetRect(self, edgeInsets)
    }
}
