//
//  PanelConstraints.swift
//  Aiolos
//
//  Created by Matthias Tretter on 13/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Foundation


/// Internal class used for managing NSLayoutConstraints of the Panel
final class PanelConstraints {

    private unowned let panel: Panel
    private var isPanning: Bool = false
    private lazy var keyboardLayoutGuide: KeyboardLayoutGuide = self.makeKeyboardLayoutGuide()
    private var topConstraint: NSLayoutConstraint?
    private var widthConstraint: NSLayoutConstraint?
    private var positionConstraints: [NSLayoutConstraint] = []
    private(set) var heightConstraint: NSLayoutConstraint?

    // MARK: - Lifecycle

    init(panel: Panel) {
        self.panel = panel
    }

    // MARK: - PanelConstraints

    func updateSizeConstraints(for size: CGSize) {
        guard self.isPanning == false else { return }
        guard let widthConstraint = self.widthConstraint, let heightConstraint = self.heightConstraint else {
            self.activateSizeConstraints(for: size)
            return
        }

        self.panel.animator.animateIfNeeded {
            widthConstraint.constant = size.width
            heightConstraint.constant = size.height
        }
    }

    func updatePositionConstraints(for position: Panel.Configuration.Position, margins: NSDirectionalEdgeInsets) {
        guard self.isPanning == false else { return }
        guard let view = self.panel.view else { return }
        guard let parentView = self.panel.parent?.view else { return }

        let guide: AnchorOwner = self.panel.configuration.positionLogic == .respectSafeArea ? parentView.safeAreaLayoutGuide : parentView
        let topConstraint = view.topAnchor.constraint(greaterThanOrEqualTo: guide.topAnchor, constant: margins.top).withIdentifier("Panel Top")
        var positionConstraints = [
            view.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -margins.bottom).configure { $0.priority = .defaultHigh; $0.identifier = "Panel Bottom" },
            view.bottomAnchor.constraint(lessThanOrEqualTo: guide.bottomAnchor, constant: -margins.bottom).withIdentifier("Panel Bottom <="),
            view.bottomAnchor.constraint(lessThanOrEqualTo: self.keyboardLayoutGuide.topGuide.bottomAnchor, constant: -margins.bottom).withIdentifier("Keyboard Bottom"),
            topConstraint
        ]

        switch position {
        case .bottom:
            positionConstraints += [
                view.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: margins.leading).withIdentifier("Panel Leading"),
                view.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -margins.trailing).withIdentifier("Panel Trailing")
            ]

        case .leadingBottom:
            positionConstraints += [
                view.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: margins.leading).withIdentifier("Panel Leading"),
                view.trailingAnchor.constraint(lessThanOrEqualTo: guide.trailingAnchor, constant: -margins.trailing).withIdentifier("Panel Trailing")
            ]

        case .trailingBottom:
            positionConstraints += [
                view.leadingAnchor.constraint(greaterThanOrEqualTo: guide.leadingAnchor, constant: margins.leading).withIdentifier("Panel Leading"),
                view.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -margins.trailing).withIdentifier("Panel Trailing")
            ]
        }

        self.panel.animator.animateIfNeeded {
            NSLayoutConstraint.deactivate(self.positionConstraints)
            self.topConstraint = topConstraint
            self.positionConstraints = positionConstraints
            NSLayoutConstraint.activate(self.positionConstraints)
        }
    }
}

// MARK: - Internal (Dragging Support)

internal extension PanelConstraints {

    var maxHeight: CGFloat {
        guard let parentView = self.panel.parent?.view else { return 0.0 }

        let safeArea: CGRect
        switch self.panel.configuration.positionLogic {
        case .ignoreSafeArea:
            safeArea = parentView.bounds
        case .respectSafeArea:
            safeArea = UIEdgeInsetsInsetRect(parentView.bounds, parentView.safeAreaInsets)
        }

        return self.panel.view.frame.maxY - safeArea.minY
    }

    func updateForPanStart(with currentSize: CGSize) {
        // the normal height constraint for .fullHeight can have a higher constant, but the actual height is constrained by the safeAreaInsets
        // this fixes this discrepancy by setting the heightConstraint's constant to the actual current height of the panel, when a drag starts
        self.heightConstraint?.constant = currentSize.height
        // we don't want to limit the height by the safeAreaInsets during dragging
        self.topConstraint?.isActive = false
    }

    func updateForPan(with yOffset: CGFloat) {
        self.isPanning = true
        self.heightConstraint?.constant -= yOffset
    }

    func updateForPanEnd() {
        self.topConstraint?.isActive = true
        self.isPanning = false
    }

    func prepareForPanEndAnimation() {
        self.isPanning = true
    }

    func updateForPanEndAnimation(to height: CGFloat) {
        self.heightConstraint?.constant = height
        self.panel.parent?.view.layoutIfNeeded()
        self.isPanning = false
    }

    func updateForPanCancelled(with targetSize: CGSize) {
        self.topConstraint?.isActive = true
        self.isPanning = false
        self.updateSizeConstraints(for: targetSize)
    }
}

// MARK: - Private

private extension PanelConstraints {

    func makeKeyboardLayoutGuide() -> KeyboardLayoutGuide {
        guard let parentView = self.panel.parent?.view else { fatalError("Must have a parent by now") }

        return KeyboardLayoutGuide(parentView: parentView)
    }

    func activateSizeConstraints(for size: CGSize) {
        let widthConstraint = self.panel.view.widthAnchor.constraint(equalToConstant: size.width).configure { constraint in
            constraint.identifier = "Panel Width"
            constraint.priority = .defaultHigh
        }

        let minHeightConstraint = self.panel.view.heightAnchor.constraint(greaterThanOrEqualToConstant: ResizeHandle.Constants.height).withIdentifier("Panel Min Height")
        let heightConstraint = self.panel.view.heightAnchor.constraint(equalToConstant: size.height).configure { constraint in
            constraint.identifier = "Panel Height"
            constraint.priority = .defaultHigh
        }

        self.widthConstraint = widthConstraint
        self.heightConstraint = heightConstraint
        NSLayoutConstraint.activate([widthConstraint, heightConstraint, minHeightConstraint])
    }
}

// MARK: - NSLayoutConstraint

private extension NSLayoutConstraint {

    func configure(_ configuration: (NSLayoutConstraint) -> Void) -> NSLayoutConstraint {
        configuration(self)
        return self
    }

    func withIdentifier(_ identifier: String) -> NSLayoutConstraint {
        return self.configure { constraint in
            constraint.identifier = identifier
        }
    }
}

// Compiler doesn't allow me to make this private…
protocol AnchorOwner {

    var leadingAnchor: NSLayoutXAxisAnchor { get }
    var trailingAnchor: NSLayoutXAxisAnchor { get }
    var leftAnchor: NSLayoutXAxisAnchor { get }
    var rightAnchor: NSLayoutXAxisAnchor { get }
    var topAnchor: NSLayoutYAxisAnchor { get }
    var bottomAnchor: NSLayoutYAxisAnchor { get }
    var widthAnchor: NSLayoutDimension { get }
    var heightAnchor: NSLayoutDimension { get }
    var centerXAnchor: NSLayoutXAxisAnchor { get }
    var centerYAnchor: NSLayoutYAxisAnchor { get }
}

extension UIView: AnchorOwner { }
extension UILayoutGuide: AnchorOwner { }
