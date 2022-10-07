//
//  ResizeHandle.swift
//  Aiolos
//
//  Created by Matthias Tretter on 18/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import UIKit


/// View that is used to display the resize handle
public final class ResizeHandle: UIView {

    public struct Constants {
        public static let height: CGFloat = 20.0

        fileprivate static let handleHeight: CGFloat = 5.0
        fileprivate static let inactiveHandleWidth: CGFloat = 38.0
        fileprivate static let activeHandleWidth: CGFloat = 44.0
    }

    private lazy var resizeHandle: UIView = self.makeResizeHandle()
    private var adjustAppearanceWhileResizing: Bool = true
    private weak var pointerInteraction: UIInteraction?

    // MARK: - Properties

    var handleColor: UIColor = .lightGray {
        didSet {
            self.updateResizeHandleColor()
        }
    }

    var isResizing: Bool = false {
        didSet {
            guard oldValue != self.isResizing else { return }

            self.updateResizeHandleFrame(animated: true)
            self.updateResizeHandleColor()
            self.setNeedsLayout()
        }
    }

    var accessibilityActivateAction: (() -> Bool)? {
        didSet {
            self.isAccessibilityElement = self.accessibilityActivateAction != nil
        }
    }

    public var isPointerInteractionEnabled: Bool {
        get { self.pointerInteraction != nil }
        set {
            guard newValue != self.isPointerInteractionEnabled else { return }

            if let exitingInteraction = self.pointerInteraction {
                self.removeInteraction(exitingInteraction)
            }

            if newValue {
                self.installPointerInteraction()
            }
        }
    }

    // MARK: - Lifecycle

    public init(configuration: Panel.Configuration) {
        super.init(frame: .zero)

        self.clipsToBounds = false
        self.isOpaque = false
        self.backgroundColor = .clear
        self.addSubview(self.resizeHandle)
        self.configure(with: configuration)
        self.isPointerInteractionEnabled = true
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UIView

    override public func layoutSubviews() {
        super.layoutSubviews()
        self.updateResizeHandleFrame(animated: false)
    }

    // MARK: - ResizeHandle

    func configure(with configuration: Panel.Configuration) {
        guard case .visible(let foregroundColor, let backgroundColor, let adjustAppearanceWhileResizing) = configuration.appearance.resizeHandle else { return }

        self.handleColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.adjustAppearanceWhileResizing = adjustAppearanceWhileResizing
        self.resizeHandle.alpha = configuration.gestureResizingMode.contains(.handle) && configuration.supportedModes.count > 1 ? 1.0 : 0.2
    }
}

// MARK: - UIAccessibility

extension ResizeHandle {

    override public func accessibilityActivate() -> Bool {
        return self.accessibilityActivateAction?() ?? false
    }
}

// MARK: - UIPointerInteractionDelegate

@available(iOS 13.4, *)
extension ResizeHandle: UIPointerInteractionDelegate {

    public func pointerInteraction(_ interaction: UIPointerInteraction, regionFor request: UIPointerRegionRequest, defaultRegion: UIPointerRegion) -> UIPointerRegion? {
        return UIPointerRegion(rect: self.resizeHandle.frame.insetBy(dx: -24.0, dy: -12.0))
    }

    public func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
        return UIPointerStyle(effect: .automatic(UITargetedPreview(view: self.resizeHandle)))
    }

    public func pointerInteraction(_ interaction: UIPointerInteraction, willEnter region: UIPointerRegion, animator: UIPointerInteractionAnimating) {
        self.isResizing = true
    }

    public func pointerInteraction(_ interaction: UIPointerInteraction, willExit region: UIPointerRegion, animator: UIPointerInteractionAnimating) {
        self.isResizing = false
    }
}

// MARK: - Private

private extension ResizeHandle {

    var shouldAdjustAppearance: Bool { self.isResizing && self.adjustAppearanceWhileResizing }

    func makeResizeHandle() -> UIView {
        let handle = UIView(frame: .init(origin: .zero, size: .init(width: Constants.inactiveHandleWidth, height: Constants.handleHeight)))
        handle.backgroundColor = self.handleColor
        return handle
    }

    func updateResizeHandleColor() {
        let baseColor = self.handleColor
        self.resizeHandle.backgroundColor = self.shouldAdjustAppearance ? baseColor.darkened() : baseColor
    }

    func updateResizeHandleFrame(animated: Bool) {
        let width = self.shouldAdjustAppearance ? Constants.activeHandleWidth : Constants.inactiveHandleWidth

        func updateFrame() {
            let center = CGPoint(x: self.bounds.width / 2.0, y: self.bounds.height / 2.0 - 0.5)
            self.resizeHandle.frame = CGRect(center: center, size: .init(width: width, height: Constants.handleHeight))
            self.resizeHandle.layer.cornerRadius = self.resizeHandle.bounds.height / 2.0
        }

        if animated {
            UIView.animate(withDuration: 0.3,
                           delay: 0.0,
                           usingSpringWithDamping: 1.0,
                           initialSpringVelocity: 0.0,
                           options: .curveLinear,
                           animations: updateFrame)
        } else {
            updateFrame()
        }
    }

    private func installPointerInteraction() {
        guard #available(iOS 13.4, *), NSClassFromString("UIPointerInteraction") != nil else { return }

        let pointerInteraction = UIPointerInteraction(delegate: self)
        self.addInteraction(pointerInteraction)
        self.pointerInteraction = pointerInteraction
    }
}


private extension UIColor {

    func darkened() -> UIColor {
        var hue: CGFloat = 0.0
        var saturation: CGFloat = 0.0
        var brightness: CGFloat = 0.0
        var alpha: CGFloat = 0.0

        self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        return UIColor(hue: hue, saturation: saturation, brightness: brightness - 0.2, alpha: alpha + 0.2)
    }
}


private extension CGRect {

    init(center: CGPoint, size: CGSize) {
        self.init(x: center.x - size.width / 2.0, y: center.y - size.height / 2.0, width: size.width, height: size.height)
    }
}
