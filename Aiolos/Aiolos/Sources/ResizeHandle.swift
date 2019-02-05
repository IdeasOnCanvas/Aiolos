//
//  ResizeHandle.swift
//  Aiolos
//
//  Created by Matthias Tretter on 18/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Foundation


/// View that is used to display the resize handle
public final class ResizeHandle: UIView {

    public struct Constants {
        public static let height: CGFloat = 20.0
    }

    private lazy var resizeHandle: CAShapeLayer = self.makeResizeHandle()

    // MARK: - Properties

    var handleColor: UIColor = .lightGray {
        didSet {
            self.updateResizeHandleColor()
        }
    }

    var isResizing = false {
        didSet {
            guard oldValue != self.isResizing else { return }

            self.updateResizeHandlePath(animated: true)
            self.updateResizeHandleColor()
        }
    }

    var accessibilityActivateAction: (() -> Bool)? {
        didSet {
            self.isAccessibilityElement = self.accessibilityActivateAction != nil
        }
    }

    // MARK: - Lifecycle

    init(configuration: Panel.Configuration) {
        super.init(frame: .zero)

        self.clipsToBounds = false
        self.isOpaque = false
        self.backgroundColor = .clear
        self.layer.addSublayer(self.resizeHandle)
        self.configure(with: configuration)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - ResizeHandle

    func configure(with configuration: Panel.Configuration) {
        guard case .visible(let foregroundColor, let backgroundColor) = configuration.appearance.resizeHandle else { return }
        
        self.handleColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.resizeHandle.opacity = configuration.gestureResizingMode != .disabled && configuration.supportedModes.count > 1 ? 1.0 : 0.2
    }
}

// MARK: - UIAccessibility

extension ResizeHandle {

    override public func accessibilityActivate() -> Bool {
        return self.accessibilityActivateAction?() ?? false
    }
}

// MARK: - UIView

extension ResizeHandle {

    override public func layoutSubviews() {
        super.layoutSubviews()

        self.resizeHandle.frame = self.bounds
        self.updateResizeHandlePath()
    }
}

// MARK: - Private

private extension ResizeHandle {

    func makeResizeHandle() -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.contentsScale = UIScreen.main.scale
        layer.backgroundColor = UIColor.clear.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = 5.0
        layer.lineCap = CAShapeLayerLineCap.round
        return layer
    }

    func updateResizeHandleColor() {
        let baseColor = self.handleColor
        self.resizeHandle.strokeColor = self.isResizing ? baseColor.darkened().cgColor : baseColor.cgColor
    }

    func updateResizeHandlePath(animated: Bool = false) {
        let path = UIBezierPath()
        let width: CGFloat = self.isResizing ? 38.0 : 32.0

        let r = self.bounds.divided(atDistance: 13.0, from: .maxYEdge).slice
        let centerX = r.width / 2.0
        let y = r.minY + self.resizeHandle.lineWidth / 2.0

        path.move(to: CGPoint(x: centerX - width / 2.0, y: y))
        path.addLine(to: CGPoint(x: centerX + width / 2.0, y: y))

        if animated {
            self.addAnimation(to: self.resizeHandle)
        }
        self.resizeHandle.path = path.cgPath
    }

    func addAnimation(to layer: CAShapeLayer) {
        let animationKey = "pathAnimation"
        let animation = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.path))
        animation.duration = 0.3
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)

        layer.removeAnimation(forKey: animationKey)
        layer.add(animation, forKey: animationKey)
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
