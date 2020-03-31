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

        fileprivate static let defaultWidth: CGFloat = 32.0
        fileprivate static let resizeWidth: CGFloat = 38.0
        fileprivate static let pointerWidth: CGFloat = 62.0
        fileprivate static let handleHeight: CGFloat = 5.0
    }

    private lazy var resizeHandle: CAShapeLayer = self.makeResizeHandle()

    // MARK: - Properties

    var handleColor: UIColor = .lightGray {
        didSet {
            self.updateResizeHandleColor()
        }
    }

    var isResizing: Bool = false {
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

        if #available(iOS 13.4, *) {
            let pointerInteraction = UIPointerInteraction(delegate: self)
            self.addInteraction(pointerInteraction)
        }
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

// MARK: - UIPointerInteractionDelegate

@available(iOS 13.4, *)
extension ResizeHandle: UIPointerInteractionDelegate {

    public func pointerInteraction(_ interaction: UIPointerInteraction, regionFor request: UIPointerRegionRequest, defaultRegion: UIPointerRegion) -> UIPointerRegion? {
        let pointerRect = CGRect(center: CGPoint(x: self.bounds.width / 2.0, y: self.bounds.height / 2.0),
                                 size: CGSize(width: Constants.pointerWidth, height: Constants.handleHeight + 12.0))

        return UIPointerRegion(rect: pointerRect)
    }

    public func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
        return UIPointerStyle(effect: .automatic(.init(view: self)))
    }
}

// MARK: - Private

private extension ResizeHandle {

    func makeResizeHandle() -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.contentsScale = UIScreen.main.scale
        layer.backgroundColor = UIColor.clear.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = Constants.handleHeight
        layer.lineCap = .round
        return layer
    }

    func updateResizeHandleColor() {
        let baseColor = self.handleColor
        self.resizeHandle.strokeColor = self.isResizing ? baseColor.darkened().cgColor : baseColor.cgColor
    }

    func updateResizeHandlePath(animated: Bool = false) {
        func makeHandlePath(width: CGFloat) -> UIBezierPath {
            let r = self.bounds.divided(atDistance: 13.0, from: .maxYEdge).slice
            let y = r.minY + Constants.handleHeight / 2.0

            let boundingRect = CGRect(center: .init(x: r.width / 2.0, y: y), size: .init(width: width, height: 0.0))
            let path = UIBezierPath()
            path.move(to: boundingRect.minXmidY)
            path.addLine(to: boundingRect.maxXmidY)
            return path
        }

        let path = makeHandlePath(width: self.isResizing ? Constants.resizeWidth : Constants.defaultWidth)

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


private extension CGRect {

    var minXmidY: CGPoint { .init(x: self.minX, y: self.midY) }
    var maxXmidY: CGPoint { .init(x: self.maxX, y: self.midY) }

    init(center: CGPoint, size: CGSize) {
        self.init(x: center.x - size.width / 2.0, y: center.y - size.height / 2.0, width: size.width, height: size.height)
    }
}
