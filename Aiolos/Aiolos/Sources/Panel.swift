//
//  Panel.swift
//  Aiolos
//
//  Created by Matthias Tretter on 11/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import UIKit


/// A floating Panel inspired by the iOS 11 Maps.app UI
@objc
public final class Panel: UIViewController {

    private var shadowView: ShadowView? { return self.viewIfLoaded as? ShadowView }
    private var containerView: ContainerView? { return self.viewIfLoaded?.subviews.first as? ContainerView }
    private lazy var separatorView: SeparatorView = self.makeSeparatorView()

    private lazy var gestures: PanelGestures = self.makeGestures()
    private(set) lazy var constraints: PanelConstraints = self.makeConstraints()
    private(set) lazy var animator: PanelAnimator = self.makeAnimator()
    private var _configuration: Configuration {
        didSet {
            self.handleConfigurationChange(from: oldValue, to: self.configuration)
        }
    }

    // MARK: - Properties

    @objc private(set) public lazy var panelView: PanelView = self.makePanelView()
    @objc private(set) public lazy var resizeHandle: ResizeHandle = self.makeResizeHandle()
    @objc public var isVisible: Bool { return self.parent != nil && self.animator.isMovingFromParent == false }
    @objc public var isResizing: Bool { return self.gestures.isVerticalPanActive }
    public weak var sizeDelegate: PanelSizeDelegate?
    public weak var resizeDelegate: PanelResizeDelegate?
    public weak var repositionDelegate: PanelRepositionDelegate?
    public weak var gestureDelegate: UIGestureRecognizerDelegate?
    public weak var accessibilityDelegate: PanelAccessibilityDelegate? {
        didSet {
            guard self.accessibilityDelegate !== oldValue else { return }

            self.updateAccessibility(for: self.configuration.mode)
        }
    }

    public var configuration: Configuration {
        get { return self._configuration }
        set { self._configuration = newValue.validated() }
    }

    @objc public var contentViewController: UIViewController? {
        didSet {
            self.exchangeContentViewController(oldValue, with: self.contentViewController)
            self.view.setNeedsLayout()
            self.fixLayoutMargins()
        }
    }

    // MARK: - Lifecycle

    public init(configuration: Configuration) {
        self._configuration = configuration.validated()
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

    override var shouldAutomaticallyForwardAppearanceMethods: Bool {
        return false
    }

    override var isMovingToParent: Bool {
        return self.animator.isMovingToParent
    }

    override var isMovingFromParent: Bool {
        return self.animator.isMovingFromParent
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

        switch configuration.appearance.resizeHandle {
        case .hidden:
            self.resizeHandle.frame = .null
            self.separatorView.frame = .null
            self.panelView.frame = self.view.bounds

        case .visible:
            let (resizeFrame, panelFrame) = self.view.bounds.divided(atDistance: ResizeHandle.Constants.height, from: .minYEdge)
            self.resizeHandle.frame = resizeFrame
            self.panelView.frame = panelFrame

            var dividerFrame: CGRect {
                let lineWidth = 1.0 / UIScreen.main.scale
                var frame = panelFrame.insetBy(dx: lineWidth, dy: 0.0)
                frame.size.height = lineWidth
                frame.origin.y -= frame.size.height / 2.0
                return frame
            }
            self.separatorView.frame = dividerFrame
        }

        self.contentViewController?.view.frame = self.panelView.contentView.bounds
        self.fixLayoutMargins()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        self.contentViewController?.viewWillTransition(to: size, with: coordinator)
    }

    override func overrideTraitCollection(forChild childViewController: UIViewController) -> UITraitCollection? {
        let horizontalTraits = UITraitCollection(horizontalSizeClass: .compact)
        let verticalTraits = UITraitCollection(verticalSizeClass: .compact)

        return UITraitCollection(traitsFrom: [horizontalTraits, verticalTraits])
    }
}

// MARK: - Panel

public extension Panel {

    func add(to parent: UIViewController, transition: Transition = .none, completion: (() -> Void)? = nil) {
        let topIndex = view.subviews.count
        insert(to: parent, at: topIndex, transition: transition, completion: completion)
    }
    
    func insert(to parent: UIViewController, at position: Int, transition: Transition = .none, completion: (() -> Void)? = nil) {
        guard self.parent !== parent || self.animator.isMovingFromParent else { return }

        if self.animator.isMovingFromParent {
            self.animator.stopCurrentAnimation()
        }

        let contentViewController = self.contentViewController
        contentViewController?.beginAppearanceTransition(true, animated: transition.isAnimated)
        parent.addChild(self)
        parent.view.insertSubview(self.view, at: position)
        self.didMove(toParent: parent)

        let size = self.size(for: self.configuration.mode)
        self.animator.addToParent(with: size, transition: transition) {
            contentViewController?.endAppearanceTransition()
            self.updateAccessibility(for: self.configuration.mode)
            self.fixLayoutMargins()
            completion?()
        }
    }

    func removeFromParent(transition: Transition = .none, completion: (() -> Void)? = nil) {
        guard self.parent != nil || self.animator.isMovingToParent else { return }

        if let repositionDelegate = self.repositionDelegate {
            guard repositionDelegate.panelCanBeDismissed(self) else { return }
        }

        if self.animator.isMovingToParent {
            self.animator.stopCurrentAnimation()
        }

        let contentViewController = self.contentViewController
        contentViewController?.beginAppearanceTransition(false, animated: transition.isAnimated)
        self.willMove(toParent: nil)
        self.animator.removeFromParent(transition: transition) {
            contentViewController?.endAppearanceTransition()
            self.view.removeFromSuperview()
            self.removeFromParent()
            completion?()
        }
    }

    func performWithoutAnimation(_ changes: () -> Void) {
        let animateChanges = self.animator.animateChanges
        self.animator.animateChanges = false
        defer { self.animator.animateChanges = animateChanges }

        changes()
    }

    func reloadSize() {
        let size = self.size(for: self.configuration.mode)

        self.animator.notifyDelegateOfTransition(to: size)
        self.constraints.updateSizeConstraints(for: size)
    }
}

// MARK: - ObjC Compatibility

public extension Panel {

    @objc(isInMode:)
    @available(swift, obsoleted: 1.0)
    func isInMode(_ mode: Configuration.Mode) -> Bool {
        return self.configuration.mode == mode
    }
}

// MARK: - Internal

internal extension Panel {

    func size(for mode: Configuration.Mode) -> CGSize {
        guard let sizeDelegate = self.sizeDelegate else { return .zero }
        guard let parent = self.parent else { return .zero }

        let delegateSize = sizeDelegate.panel(self, sizeForMode: mode)

        // we overwrite the width in .bottom position
        let width: CGFloat
        switch self.configuration.position {
        case .bottom:
            width = parent.view.frame.width
        default:
            width = delegateSize.width
        }

        // we overwrite the height in .minimal/.fullHeight mode
        let height: CGFloat
        switch mode {
        case .minimal:
            height = 0.0
        case .fullHeight:
            let screen = parent.view.window?.screen ?? UIScreen.main
            height = screen.fixedCoordinateSpace.bounds.height
        default:
            height = delegateSize.height
        }

        return CGSize(width: width, height: height)
    }

    func horizontalOffset(at position: Panel.Configuration.Position) -> CGFloat {
        let originalPosition = self.configuration.position
        guard originalPosition != position else { return 0 }

        let distance = self.constraints.effectiveBounds.width - self.view.frame.width
        switch position {
        case .leadingBottom:
            return self.view.isRTL ? distance : -distance
        case .trailingBottom:
            return self.view.isRTL ? -distance : distance
        default:
            return 0.0
        }
    }

    // this is a workaround for a layout bug, when the panel is placed within non-safe areas.
    // the navigationBar automatically inherits the safeAreaInsets of the device, but we don't want that.
    // the panel itself takes care that the contentViewController is fully visible so all its children
    // should have no safeAreaInsets set
    func fixLayoutMargins() {
        func visit(_ view: UIView) {
            view.insetsLayoutMarginsFromSafeArea = false
            view.subviews.forEach(visit(_:))

            if view.superview is UINavigationBar {
                let safeAreaConstraints = view.constraints.filter { constraint in
                    guard let identifier = constraint.identifier else { return false }

                    return identifier.hasPrefix("UIView" + "SafeAre" + "aLayout" + "Guide") || identifier.hasSuffix("-guide" + "-constraint")
                }

                for constraint in safeAreaConstraints {
                    constraint.constant = 0.0
                }
            }
        }

        if let view = self.contentViewController?.view {
            visit(view)
        }
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
        let container = ContainerView(configuration: self.configuration)

        container.translatesAutoresizingMaskIntoConstraints = false
        shadowView.translatesAutoresizingMaskIntoConstraints = false
        shadowView.addSubview(container)
        container.addSubview(view)

        NSLayoutConstraint.activate([
            shadowView.topAnchor.constraint(equalTo: container.topAnchor),
            shadowView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            shadowView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            shadowView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
            ])

        return shadowView
    }

    func makeResizeHandle() -> ResizeHandle {
        let handle = ResizeHandle(configuration: self.configuration)
        handle.accessibilityIdentifier = "Aiolos.ResizeHandle"
        handle.accessibilityActivateAction = { [weak self] in
            guard let self = self else { return false }

            return self.accessibilityDelegate?.panel(self, didActivateResizeHandle: self.resizeHandle) ?? false
        }

        return handle
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

    func exchangeContentViewController(_ oldContentViewController: UIViewController?, with newContentViewController: UIViewController?) {
        let callAppearanceMethods = self.isVisible || self.isMovingToParent

        // remove old contentViewController
        if let oldContentViewController = oldContentViewController {
            if callAppearanceMethods { oldContentViewController.beginAppearanceTransition(false, animated: false) }
            oldContentViewController.willMove(toParent: nil)
            oldContentViewController.view.removeFromSuperview()
            oldContentViewController.removeFromParent()
            if callAppearanceMethods { oldContentViewController.endAppearanceTransition() }
        }

        // add new contentViewController
        if let newContentViewController = newContentViewController {
            if callAppearanceMethods { newContentViewController.beginAppearanceTransition(true, animated: false) }
            self.addChild(newContentViewController)
            newContentViewController.view.translatesAutoresizingMaskIntoConstraints = true
            newContentViewController.view.frame = self.panelView.contentView.bounds
            self.panelView.contentView.addSubview(newContentViewController.view)
            newContentViewController.didMove(toParent: self)
            if callAppearanceMethods { newContentViewController.endAppearanceTransition() }
        }
    }

    func handleConfigurationChange(from oldConfiguration: Configuration, to newConfiguration: Configuration) {
        self.shadowView?.configure(with: newConfiguration)
        self.containerView?.configure(with: newConfiguration)
        self.panelView.configure(with: newConfiguration)
        self.resizeHandle.configure(with: newConfiguration)
        self.separatorView.configure(with: newConfiguration)
        self.gestures.configure(with: newConfiguration)

        guard self.isVisible else { return }

        let modeChanged = oldConfiguration.mode != newConfiguration.mode
        let positionChanged = oldConfiguration.position != newConfiguration.position
        let marginsChanged = oldConfiguration.margins != newConfiguration.margins
        let positionLogicChanged = oldConfiguration.positionLogic != newConfiguration.positionLogic
        let gestureResizingModeChanged = oldConfiguration.gestureResizingMode != newConfiguration.gestureResizingMode

        if modeChanged || positionChanged || marginsChanged || positionLogicChanged || gestureResizingModeChanged {
            self.gestures.cancel()
        }

        if modeChanged || positionChanged {
            let size = self.size(for: newConfiguration.mode)

            if modeChanged { self.animator.notifyDelegateOfTransition(from: oldConfiguration.mode, to: newConfiguration.mode) }
            self.animator.notifyDelegateOfTransition(to: size)
            self.constraints.updateSizeConstraints(for: size)
            self.updateAccessibility(for: newConfiguration.mode)
        }

        if positionChanged || positionLogicChanged || marginsChanged {
            self.constraints.updatePositionConstraints(for: newConfiguration.position, margins: newConfiguration.margins)
        }
    }

    func updateAccessibility(for mode: Configuration.Mode) {
        guard let contentView = self.contentViewController?.view else { return }

        if let accessibilityDelegate = self.accessibilityDelegate {
            self.resizeHandle.accessibilityLabel = accessibilityDelegate.panel(self, accessibilityLabelForResizeHandle: self.resizeHandle)
        }

        let elementsHidden = mode == .minimal || mode == .compact
        self.view.accessibilityViewIsModal = !elementsHidden
        guard elementsHidden != contentView.accessibilityElementsHidden else { return }

        contentView.accessibilityElementsHidden = elementsHidden
        UIAccessibility.post(notification: .screenChanged, argument: nil)
    }
}
