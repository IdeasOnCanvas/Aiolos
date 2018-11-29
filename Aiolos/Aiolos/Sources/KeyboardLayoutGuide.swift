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

    let topGuide: UILayoutGuide

    // MARK: - Lifecycle

    init(parentView: UIView, notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        self.topGuide = UILayoutGuide()
        self.topGuide.identifier = "Keyboard Layout Guide"
        parentView.addLayoutGuide(self.topGuide)

        self.bottomConstraint = parentView.bottomAnchor.constraint(equalTo: self.topGuide.bottomAnchor)
        NSLayoutConstraint.activate([
            self.topGuide.heightAnchor.constraint(equalToConstant: 1.0),
            parentView.leadingAnchor.constraint(equalTo: self.topGuide.leadingAnchor),
            parentView.trailingAnchor.constraint(equalTo: self.topGuide.trailingAnchor),
            self.bottomConstraint])

        notificationCenter.addObserver(self, selector: #selector(keyboardWillChangeFrame), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    deinit {
        self.notificationCenter.removeObserver(self)
    }
}

// MARK: - Private

private extension KeyboardLayoutGuide {

    @objc
    func keyboardWillChangeFrame(_ notification: Notification) {
        guard let owningView = self.topGuide.owningView else { return }
        guard let window = owningView.window else { return }
        guard let keyboardInfo = KeyboardInfo(userInfo: notification.userInfo) else { return }

        // we only adjust the Panel frame, if the current first responder is a subview of the owning view
        if let firstResponder = UIResponder.currentFirstResponder() as? UIView {
            guard firstResponder.isDescendant(of: owningView) else { return }
        }

        let coveredHeight: CGFloat

        if keyboardInfo.isFloatingKeyboard {
            coveredHeight = 0.0
        } else {
            // convert own frame to window coordinates
            let owningViewFrame = window.convert(owningView.frame, from: owningView.superview)
            // calculate the area of own frame that is covered by keyboard
            let coveredFrame = owningViewFrame.intersection(keyboardInfo.endFrame)
            // now this might be rotated, so convert it back
            coveredHeight = window.convert(coveredFrame, to: owningView.superview).height
        }

        keyboardInfo.animateAlongsideKeyboard {
            self.bottomConstraint.constant = coveredHeight
            owningView.layoutIfNeeded()
        }
    }

    @objc
    func keyboardWillHide(_ notification: Notification) {
        self.bottomConstraint.constant = 0.0
        self.topGuide.owningView?.layoutIfNeeded()
    }
}

private struct KeyboardInfo {

    let endFrame: CGRect
    let animationOptions: UIView.AnimationOptions
    let animationDuration: TimeInterval
    let isLocal: Bool

    var isFloatingKeyboard: Bool {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return false }
        guard self.isLocal else { return false }
        guard self.endFrame.size != .zero else { return true }

        let parentBounds = UIApplication.shared.keyWindow?.bounds ?? UIScreen.main.bounds
        return self.endFrame.maxY < parentBounds.height
    }

    init?(userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo else { return nil }
        guard let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return nil }

        self.endFrame = endFrame
        self.isLocal = (userInfo[UIResponder.keyboardIsLocalUserInfoKey] as? NSNumber)?.boolValue ?? true

        // UIViewAnimationOption is shifted by 16 bit from UIViewAnimationCurve, which we get here:
        // http://stackoverflow.com/questions/18870447/how-to-use-the-default-ios7-uianimation-curve
        if let animationCurve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt {
            self.animationOptions = UIView.AnimationOptions(rawValue: animationCurve << 16)
        } else {
            self.animationOptions = .curveEaseInOut
        }

        if let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double {
            self.animationDuration = animationDuration
        } else {
            self.animationDuration = 0.25
        }
    }

    func animateAlongsideKeyboard(_ animations: @escaping () -> Void) {
        UIView.animate(withDuration: self.animationDuration, delay: 0.0, options: self.animationOptions, animations: animations)
    }
}


private extension UIResponder {

    static weak var _firstResponder: AnyObject?

    static func currentFirstResponder() -> AnyObject? {
        UIResponder._firstResponder = nil
        // sending to nil sends the action to the first responder
        UIApplication.shared.sendAction(#selector(_findFirstResponder), to: nil, from: nil, for: nil)
        return UIResponder._firstResponder
    }

    @objc
    func _findFirstResponder() {
        UIResponder._firstResponder = self
    }
}
