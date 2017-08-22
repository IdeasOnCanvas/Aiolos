//
//  Panel.swift
//  Aiolos
//
//  Created by Matthias Tretter on 11/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Foundation


/// A floating Panel inspired by the iOS 11 Maps.app UI
@objc
public final class Panel: UIViewController {

    private(set) lazy var resizeHandle: ResizeHandle = self.makeResizeHandle()
    private var shadowView: ShadowView? { return self.viewIfLoaded as? ShadowView }
    private var containerView: ContainerView? { return self.viewIfLoaded?.subviews.first as? ContainerView }
    private lazy var dimmingView: UIView = self.makeDimmingView()
    private lazy var separatorView: SeparatorView = self.makeSeparatorView()

    private lazy var gestures: PanelGestures = self.makeGestures()
    private(set) lazy var constraints: PanelConstraints = self.makeConstraints()
    private(set) lazy var animator: PanelAnimator = self.makeAnimator()
    private var isTransitioningFromParent: Bool = false

    // MARK: - Properties

    @objc private(set) public lazy var panelView: PanelView = self.makePanelView()
    @objc public var isVisible: Bool { return self.parent != nil && self.isTransitioningFromParent == false }
    public weak var sizeDelegate: PanelSizeDelegate?
    public weak var animationDelegate: PanelAnimationDelegate?

    public var configuration: Configuration {
        didSet {
            self.handleConfigurationChange(from: oldValue, to: self.configuration)
        }
    }

    @objc public var contentViewController: UIViewController? {
        didSet {
            self.updateContentViewControllerFrame(of: self.contentViewController)
            self.exchangeContentViewController(oldValue, with: self.contentViewController)
        }
    }

    // MARK: - Lifecycle

    public init(configuration: Configuration) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    @objc
    public convenience init() {
        self.init(configuration: .default)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - UIViewController

public extension Panel {

    public override var shouldAutomaticallyForwardAppearanceMethods: Bool {
        return false
    }

    override func loadView() {
        self.view = self.makeShadowView(for: self.panelView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.gestures.install()
        self.containerView?.insertSubview(self.resizeHandle, at: 0)
        self.containerView?.addSubview(self.separatorView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let (resizeFrame, panelFrame) = self.view.bounds.divided(atDistance: ResizeHandle.Constants.height, from: .minYEdge)
        self.resizeHandle.frame = resizeFrame
        self.panelView.frame = panelFrame

        let lineWidth = 1.0 / UIScreen.main.scale
        var dividerFrame = panelFrame.insetBy(dx: lineWidth, dy: 0.0)
        dividerFrame.size.height = lineWidth
        dividerFrame.origin.y -= dividerFrame.size.height / 2.0
        self.separatorView.frame = dividerFrame
    }

    override public func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        self.gestures.cancel()
        super.willTransition(to: newCollection, with: coordinator)
    }
}

// MARK: - Panel

public extension Panel {

    func add(to parent: UIViewController, transition: Transition = .none) {
        guard self.parent !== parent else { return }

        self.contentViewController?.beginAppearanceTransition(true, animated: transition.isAnimated)
        parent.addChildViewController(self)
        parent.view.addSubview(self.view)
        self.didMove(toParentViewController: parent)

        let size = self.size(for: self.configuration.mode)
        self.animator.transitionToParent(with: size, transition: transition) {
            self.contentViewController?.endAppearanceTransition()
        }
    }

    func removeFromParent(transition: Transition = .none) {
        guard self.parent != nil else { return }

        self.isTransitioningFromParent = true
        self.contentViewController?.beginAppearanceTransition(false, animated: transition.isAnimated)
        self.willMove(toParentViewController: nil)
        self.animator.removeFromParent(transition: transition) {
            self.contentViewController?.endAppearanceTransition()
            self.view.removeFromSuperview()
            self.removeFromParentViewController()
            self.isTransitioningFromParent = false
        }
    }

    func performWithoutAnimation(_ changes: () -> Void) {
        let animateChanges = self.animator.animateChanges
        self.animator.animateChanges = false
        defer { self.animator.animateChanges = animateChanges }

        changes()
    }
}

// MARK: - Internal

internal extension Panel {

    func size(for mode: Configuration.Mode) -> CGSize {
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

private extension Panel {

    func makePanelView() -> PanelView {
        return PanelView(configuration: self.configuration)
    }

    func makeShadowView(for view: UIView) -> UIView {
        let shadowView = ShadowView(configuration: self.configuration)
        let container = ContainerView(frame: shadowView.bounds, configuration: self.configuration)

        shadowView.translatesAutoresizingMaskIntoConstraints = false
        shadowView.addSubview(container)
        container.addSubview(view)

        return shadowView
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

    func makeSeparatorView() -> SeparatorView {
        return SeparatorView(configuration: self.configuration)
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

private extension Panel {

    func updateContentViewControllerFrame(of contentViewController: UIViewController?) {
        guard let contentViewController = contentViewController else { return }

        contentViewController.view.frame = self.panelView.contentView.bounds
        contentViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    func exchangeContentViewController(_ oldContentViewController: UIViewController?, with newContentViewController: UIViewController?) {
        // remove old contentViewController
        if let oldContentViewController = oldContentViewController {
            oldContentViewController.beginAppearanceTransition(false, animated: false)
            oldContentViewController.willMove(toParentViewController: nil)
            oldContentViewController.view.removeFromSuperview()
            oldContentViewController.removeFromParentViewController()
            oldContentViewController.endAppearanceTransition()
        }

        // add new contentViewController
        if let newContentViewController = newContentViewController {
            newContentViewController.beginAppearanceTransition(true, animated: false)
            self.addChildViewController(newContentViewController)
            self.panelView.contentView.addSubview(newContentViewController.view)
            newContentViewController.didMove(toParentViewController: self)
            newContentViewController.endAppearanceTransition()

            let horizontalTraits = UITraitCollection(horizontalSizeClass: .compact)
            let verticalTraits = UITraitCollection(verticalSizeClass: .compact)
            self.setOverrideTraitCollection(UITraitCollection(traitsFrom: [horizontalTraits, verticalTraits]), forChildViewController: newContentViewController)
        }
    }

    func handleConfigurationChange(from oldConfiguration: Configuration, to newConfiguration: Configuration) {
        self.shadowView?.configure(with: newConfiguration)
        self.containerView?.configure(with: newConfiguration)
        self.panelView.configure(with: newConfiguration)
        self.resizeHandle.configure(with: newConfiguration)
        self.separatorView.configure(with: newConfiguration)
        self.gestures.isEnabled = newConfiguration.isGestureBasedResizingEnabled

        let modeChanged = oldConfiguration.mode != newConfiguration.mode
        let positionChanged = oldConfiguration.position != newConfiguration.position

        if modeChanged || positionChanged {
            let size = self.size(for: newConfiguration.mode)

            if modeChanged { self.animator.notifyDelegateOfTransition(to: newConfiguration.mode) }
            self.animator.notifyDelegateOfTransition(to: size)
            self.constraints.updateSizeConstraints(for: size)
        }

        if positionChanged {
            self.constraints.updatePositionConstraints(for: newConfiguration.position, margins: newConfiguration.margins)
        }
    }
}
