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
    private var isTransitioning: Bool = false
    private lazy var keyboardLayoutGuide: KeyboardLayoutGuide = self.makeKeyboardLayoutGuide()
    private var topConstraint: NSLayoutConstraint?
    private var topConstraintMargin: CGFloat = 0.0
    private var widthConstraint: NSLayoutConstraint?
    private var positionConstraints: [NSLayoutConstraint] = []
    private(set) var heightConstraint: NSLayoutConstraint?

    // MARK: - Lifecycle

    init(panel: Panel) {
        self.panel = panel
    }

    // MARK: - PanelConstraints

    func updateSizeConstraints(for size: CGSize) {
        guard self.isTransitioning == false else { return }
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
        guard self.isTransitioning == false else { return }
        guard let view = self.panel.view else { return }
        guard let parentView = self.panel.parent?.view else { return }

        let anchors = self.guides(of: parentView, for: self.panel.configuration.positionLogic)
        let topConstraint = view.topAnchor.constraint(greaterThanOrEqualTo: anchors.top, constant: margins.top).withIdentifier("Panel Top")
        var positionConstraints = [
            view.bottomAnchor.constraint(equalTo: anchors.bottom, constant: -margins.bottom).configure { $0.priority = .defaultHigh; $0.identifier = "Panel Bottom" },
            view.bottomAnchor.constraint(lessThanOrEqualTo: anchors.bottom, constant: -margins.bottom).withIdentifier("Panel Bottom <="),
            view.bottomAnchor.constraint(lessThanOrEqualTo: self.keyboardLayoutGuide.topGuide.bottomAnchor, constant: -margins.bottom).withIdentifier("Keyboard Bottom"),
            topConstraint
        ]

        switch position {
        case .bottom:
            positionConstraints += [
                view.leadingAnchor.constraint(equalTo: anchors.leading, constant: margins.leading).withIdentifier("Panel Leading"),
                view.trailingAnchor.constraint(equalTo: anchors.trailing, constant: -margins.trailing).withIdentifier("Panel Trailing")
            ]

        case .leadingBottom:
            positionConstraints += [
                view.leadingAnchor.constraint(equalTo: anchors.leading, constant: margins.leading).withIdentifier("Panel Leading"),
                view.trailingAnchor.constraint(lessThanOrEqualTo: anchors.trailing, constant: -margins.trailing).withIdentifier("Panel Trailing")
            ]

        case .trailingBottom:
            positionConstraints += [
                view.leadingAnchor.constraint(greaterThanOrEqualTo: anchors.leading, constant: margins.leading).withIdentifier("Panel Leading"),
                view.trailingAnchor.constraint(equalTo: anchors.trailing, constant: -margins.trailing).withIdentifier("Panel Trailing")
            ]
        }

        self.topConstraintMargin = topConstraint.constant
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

    var safeArea: CGRect {
        guard let parentView = self.panel.parent?.view else { return .zero }
        
        var insets: NSDirectionalEdgeInsets = .zero
        for (edge, positionLogic) in self.panel.configuration.positionLogic {
            insets = positionLogic.applyingInsets(of: parentView, to: insets, edge: edge)
        }
        
        return parentView.bounds.inset(by: UIEdgeInsets(directionalEdgeInsets: insets, isRTL: parentView.isRTL))
    }

    var effectiveBounds: CGRect {
        guard let parentView = self.panel.parent?.view else { return .zero }
        
        let insets = self.panel.configuration.margins
        return self.safeArea.inset(by: UIEdgeInsets(directionalEdgeInsets: insets, isRTL: parentView.isRTL))
    }

    var maxHeight: CGFloat {
        return self.panel.view.frame.maxY - self.safeArea.minY
    }

    func updateForPanStart(with currentSize: CGSize) {
        // the normal height constraint for .fullHeight can have a higher constant, but the actual height is constrained by the safeAreaInsets
        // this fixes this discrepancy by setting the heightConstraint's constant to the actual current height of the panel, when a drag starts
        self.heightConstraint?.constant = currentSize.height
        // we don't want to limit the height by the safeAreaInsets during dragging
        self.setTopConstraintIsRelaxed(true)
    }

    func updateForPan(with yOffset: CGFloat) {
        self.isTransitioning = true
        self.heightConstraint?.constant -= yOffset
    }

    func updateForPanEnd() {
        self.setTopConstraintIsRelaxed(false)
        self.isTransitioning = false
    }

    func prepareForPanEndAnimation() {
        self.isTransitioning = true
    }

    func updateForPanEndAnimation(to height: CGFloat) {
        self.heightConstraint?.constant = height
        self.panel.parent?.view.layoutIfNeeded()
        self.isTransitioning = false
    }

    func updateForPanCancelled(with targetSize: CGSize) {
        self.setTopConstraintIsRelaxed(false)
        self.isTransitioning = false
        self.updateSizeConstraints(for: targetSize)
    }

    func prepareForHorizontalPanEndAnimation() {
        self.isTransitioning = true
    }

    func updateForHorizontalPanEndAnimationCompleted() {
        self.isTransitioning = false
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

    func guides(of view: UIView, for positionLogic: [Panel.Configuration.Edge: Panel.Configuration.PositionLogic]) -> (top: NSLayoutYAxisAnchor, leading: NSLayoutXAxisAnchor, bottom: NSLayoutYAxisAnchor, trailing: NSLayoutXAxisAnchor) {
        let top = positionLogic[.top] == .respectSafeArea ? view.safeAreaLayoutGuide.topAnchor : view.topAnchor
        let leading = positionLogic[.leading] == .respectSafeArea ? view.safeAreaLayoutGuide.leadingAnchor : view.leadingAnchor
        let bottom = positionLogic[.bottom] == .respectSafeArea ? view.safeAreaLayoutGuide.bottomAnchor : view.bottomAnchor
        let trailing = positionLogic[.trailing] == .respectSafeArea ? view.safeAreaLayoutGuide.trailingAnchor : view.trailingAnchor

        return (top, leading, bottom, trailing)
    }

    func setTopConstraintIsRelaxed(_ relaxed: Bool) {
        guard let topConstraint = self.topConstraint else { return }

        if relaxed {
            topConstraint.constant = -50.0 // arbitrary number to let panel be dragged beyond the top
        } else {
            topConstraint.constant = self.topConstraintMargin
        }
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

// MARK: - UIEdgeInsets

private extension UIEdgeInsets {

    init(directionalEdgeInsets: NSDirectionalEdgeInsets, isRTL: Bool) {
        let left = isRTL ? directionalEdgeInsets.trailing : directionalEdgeInsets.leading
        let right = isRTL ? directionalEdgeInsets.leading : directionalEdgeInsets.trailing

        self.init(top: directionalEdgeInsets.top, left: left, bottom: directionalEdgeInsets.bottom, right: right)
    }
}
