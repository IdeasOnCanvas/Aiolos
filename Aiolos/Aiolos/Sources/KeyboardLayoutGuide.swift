//
//  KeyboardLayoutGuide.swift
//  Aiolos
//
//  Created by Matthias Tretter on 14/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

#if canImport(UIKit)

import UIKit

/// Used to create a layout guide that pins to the top of the keyboard
public final class KeyboardLayoutGuide {

    private static var lastKnownCoveredHeight: CGFloat = 0.0
    private let bottomConstraint: NSLayoutConstraint

    // MARK: - Properties

    public let topGuide: UILayoutGuide

    // MARK: - Lifecycle

    public init(parentView: UIView) {
        self.topGuide = UILayoutGuide()
        self.topGuide.identifier = "Keyboard Layout Guide"
        parentView.addLayoutGuide(self.topGuide)

        self.bottomConstraint = parentView.bottomAnchor.constraint(equalTo: self.topGuide.bottomAnchor, constant: Self.lastKnownCoveredHeight)
        NSLayoutConstraint.activate([
            self.topGuide.heightAnchor.constraint(equalToConstant: 1.0),
            parentView.leadingAnchor.constraint(equalTo: self.topGuide.leadingAnchor),
            parentView.trailingAnchor.constraint(equalTo: self.topGuide.trailingAnchor),
            self.bottomConstraint])

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillOrDidHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillOrDidHide), name: UIResponder.keyboardDidHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    }
}

// MARK: - Private

private extension KeyboardLayoutGuide {

    @objc
    func keyboardWillChangeFrame(_ notification: Notification) {
        guard let owningView = self.topGuide.owningView else { return }
        guard let window = owningView.window else { return }
        guard let keyboardInfo = KeyboardInfo(userInfo: notification.userInfo) else { return }
        guard keyboardInfo.didChangeFrame else { return }

        // we only adjust the Panel frame, if the current first responder is a subview of the owning view
        if let firstResponder = UIResponder.currentFirstResponder() as? UIView {
            guard firstResponder.isDescendant(of: owningView) else { return }
        }

        // ignore any transient changes when switching from a different app with keyboard visible on iPhone
        if window.traitCollection.userInterfaceIdiom == .phone {
            guard keyboardInfo.isLocal else { return }
        }

        let coveredHeight: CGFloat
        if keyboardInfo.isFloatingKeyboard {
            coveredHeight = 0.0
        } else {
            // convert own frame to window coordinates
            let owningViewFrame = window.convert(owningView.frame, from: owningView.superview)
            // calculate the area of own frame that is covered by keyboard
            let coveredFrame = owningViewFrame.intersection(keyboardInfo.endFrame(in: window))
            // now this might be rotated, so convert it back
            coveredHeight = window.convert(coveredFrame, to: owningView.superview).height
        }

        guard coveredHeight != self.bottomConstraint.constant else { return }

        UIView.performWithoutAnimation {
            owningView.layoutIfNeeded()
        }

        keyboardInfo.animateAlongsideKeyboard {
            self.updateBottomCoveredHeight(to: coveredHeight)
            owningView.layoutIfNeeded()
        }
    }

    @objc
    func keyboardWillOrDidHide(_ notification: Notification) {
        guard self.bottomConstraint.constant != 0.0 else { return }
        if let keyboardInfo = KeyboardInfo(userInfo: notification.userInfo) {
            guard keyboardInfo.didChangeFrame else { return }
        }

        self.updateBottomCoveredHeight(to: 0.0)
        self.topGuide.owningView?.layoutIfNeeded()
    }

    @objc
    func applicationWillResignActive(_ notification: Notification) {
        // as there is no guaranteed way to get notified about keyboard appearance/disappearance in the background,
        // we take the safe route here and reset the last known state s.t. we don't end up with keyboard-avoiding
        // panels without any keyboard
        Self.lastKnownCoveredHeight = 0.0
    }

    func updateBottomCoveredHeight(to height: CGFloat) {
        self.bottomConstraint.constant = height
        Self.lastKnownCoveredHeight = height
    }
}

private struct KeyboardInfo {

    private let beginFrame: CGRect?
    private let endFrame: CGRect
    let animationCurve: UIView.AnimationCurve
    let animationDuration: TimeInterval
    let isLocal: Bool

    var isFloatingKeyboard: Bool {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return false }
        guard self.isLocal else { return false }

        return self.beginFrame?.size == .zero || self.endFrame.size == .zero
    }

    var didChangeFrame: Bool {
        return self.beginFrame != nil && self.beginFrame != self.endFrame
    }

    init?(userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo else { return nil }
        guard let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return nil }

        self.beginFrame = userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as? CGRect
        self.endFrame = endFrame
        self.isLocal = (userInfo[UIResponder.keyboardIsLocalUserInfoKey] as? NSNumber)?.boolValue ?? true

        if let animationCurve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int {
            self.animationCurve = UIView.AnimationCurve(rawValue: animationCurve) ?? .easeInOut
        } else {
            self.animationCurve = .easeInOut
        }

        if let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double {
            self.animationDuration = animationDuration
        } else {
            self.animationDuration = 0.25
        }
    }

    func endFrame(in window: UIWindow) -> CGRect {
        var frame = window.convert(self.endFrame, from: UIScreen.main.coordinateSpace)
        if self.isFloatingKeyboard == false {
            frame.origin.x = 0.0 // fix for stage manager computation
        }
        return frame
    }

    func animateAlongsideKeyboard(_ animations: @escaping () -> Void) {
        UIViewPropertyAnimator(duration: self.animationDuration, curve: self.animationCurve, animations: animations).startAnimation()
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

#endif
