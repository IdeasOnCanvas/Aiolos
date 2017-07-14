//
//  KeyboardLayoutGuide.swift
//  Aiolos
//
//  Created by Matthias Tretter on 14/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Foundation

/// Used to create a layout guide that pins to the top of the keyboard
final class KeyboardLayoutGuide {

    private let notificationCenter: NotificationCenter
    private let bottomConstraint: NSLayoutConstraint

    // MARK: - Properties

    let layoutGuide: UILayoutGuide

    // MARK: - Lifecycle

    init(parentView: UIView, notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        self.layoutGuide = UILayoutGuide()
        self.layoutGuide.identifier = "Keyboard Layout Guide"
        parentView.addLayoutGuide(self.layoutGuide)

        self.bottomConstraint = parentView.bottomAnchor.constraint(equalTo: self.layoutGuide.bottomAnchor)
        NSLayoutConstraint.activate([
            self.layoutGuide.heightAnchor.constraint(equalToConstant: 1.0),
            parentView.leadingAnchor.constraint(equalTo: self.layoutGuide.leadingAnchor),
            parentView.trailingAnchor.constraint(equalTo: self.layoutGuide.trailingAnchor),
            self.bottomConstraint])

        notificationCenter.addObserver(self, selector: #selector(keyboardWillChangeFrame), name: .UIKeyboardWillChangeFrame, object: nil)
        notificationCenter.addObserver(self, selector: #selector(keyboardWillHide), name: .UIKeyboardWillHide, object: nil)
    }

    deinit {
        self.notificationCenter.removeObserver(self)
    }
}

// MARK: - Private

private extension KeyboardLayoutGuide {

    @objc
    func keyboardWillChangeFrame(_ notification: Notification) {
        guard let owningView = self.layoutGuide.owningView else { return }
        guard let window = owningView.window else { return }
        guard let keyboardFrame = notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? CGRect else { return }

        // convert own frame to window coordinates, frame is in superview's coordinates
        let owningViewFrame = window.convert(owningView.frame, from: owningView.superview)
        // calculate the area of own frame that is covered by keyboard
        var coveredFrame = owningViewFrame.intersection(keyboardFrame)
        // now this might be rotated, so convert it back
        coveredFrame = window.convert(coveredFrame, to: owningView.superview)

        self.bottomConstraint.constant = coveredFrame.height
        owningView.layoutIfNeeded()
    }

    @objc
    func keyboardWillHide(_ notification: Notification) {
        self.bottomConstraint.constant = 0.0
        self.layoutGuide.owningView?.layoutIfNeeded()
    }
}
